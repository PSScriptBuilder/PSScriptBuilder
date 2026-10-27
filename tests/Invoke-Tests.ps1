using module '..\build\Output\PSScriptBuilder.psd1'

<#
.SYNOPSIS
    Runs the PSScriptBuilder test suite.
.DESCRIPTION
    Loads Pester 5, registers all custom matchers, and executes tests in a defined order:
    Custom Matcher self-tests always run first, followed by the selected suite.
.PARAMETER Suite
    The test suite to run. Defaults to 'All'.
.PARAMETER CodeCoverage
    Enables Pester code coverage against the built module
    (build\Output\PSScriptBuilder.psm1) and, after the test run, translates and displays the
    results per original source file via Get-PSScriptBuilderSourceCoverage and
    Format-PSScriptBuilderSourceCoverage. Requires a prior build with -WriteSourceMap
    (Build-Module.ps1 already sets this). Coverage translation failures (e.g. a missing or
    stale source map) are reported as a warning and never affect the exit code.
.EXAMPLE
    .\Invoke-Tests.ps1
    Runs the full test suite.
.EXAMPLE
    .\Invoke-Tests.ps1 -Suite Unit
    Runs only Unit tests (Custom Matcher self-tests still run first).
.EXAMPLE
    .\Invoke-Tests.ps1 -CodeCoverage
    Runs the full test suite with code coverage enabled against the built module and prints
    a per-source-file coverage table after the test summary.
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Unit', 'Integration')]
    [string] $Suite = 'All',

    [switch] $CodeCoverage
)

$ErrorActionPreference = 'Stop'

# 1. Import Pester
Get-Module -Name Pester -All | Remove-Module -Force -ErrorAction SilentlyContinue

$pesterModule = Get-Module -Name Pester -ListAvailable |
    Where-Object { $_.Version -ge [version] '5.7.1' -and $_.Version -lt [version] '6.0.0' } |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1

if (-not $pesterModule) {
    $message = 'Pester 5.7.1 or higher is not installed.'
    throw [InvalidOperationException]::new($message)
}

$resolvedPesterMessage = 'Resolved Pester: {0} at {1}' -f $pesterModule.Version, $pesterModule.Path
Write-Host $resolvedPesterMessage

$availablePesterModules = Get-Module -Name Pester -ListAvailable | Format-Table Name, Version, Path | Out-String
Write-Host 'All available Pester modules:'
Write-Host $availablePesterModules

$psVersionMessage = 'PSVersion: {0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
Write-Host $psVersionMessage

Import-Module -FullyQualifiedName @{ ModuleName = 'Pester'; ModuleVersion = $pesterModule.Version } -Force

$loadedPesterModules = Get-Module -Name Pester | Format-Table Name, Version, Path | Out-String
Write-Host 'Loaded Pester module(s):'
Write-Host $loadedPesterModules

$newPesterConfigurationCommand    = Get-Command -Module Pester -Name New-PesterConfiguration -ErrorAction SilentlyContinue
$newPesterConfigurationAvailable  = $null -ne $newPesterConfigurationCommand
$configAvailabilityMessage        = 'New-PesterConfiguration available: {0}' -f $newPesterConfigurationAvailable
Write-Host $configAvailabilityMessage

# 2. Custom Matchers — dot-source to register (each file calls Add-ShouldOperator itself)
Get-ChildItem -Path "$PSScriptRoot\CustomMatcher" -Filter '*.ps1' -File |
    ForEach-Object { . $_.FullName }

# 3. Collect all paths to run
$paths = [System.Collections.Generic.List[string]]::new()
$paths.Add("$PSScriptRoot\CustomMatcher\Test")

$folders = if ($Suite -eq 'All') { @('Unit', 'Integration') } else { @($Suite) }
foreach ($folder in $folders) {
    $path = Join-Path $PSScriptRoot $folder
    if (-not (Test-Path $path)) { continue }
    if (-not (Get-ChildItem -Path $path -Recurse -Filter '*.Tests.ps1' -File)) { continue }
    $paths.Add($path)
}

# 4. Single Pester invocation — one summary at the end
$moduleOutputPath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'build\Output\PSScriptBuilder.psm1'

$config = New-PesterConfiguration
$config.Run.Path         = $paths.ToArray()
$config.Run.PassThru     = $true
$config.Output.Verbosity = 'Normal' #'Detailed'

if ($CodeCoverage) {
    $config.CodeCoverage.Enabled    = $true
    $config.CodeCoverage.Path       = $moduleOutputPath

    # Pester always writes a coverage report file when CodeCoverage.Enabled is true - there
    # is no option to measure without writing one. Redirect it into tests\ (default would be
    # the current working directory, typically the repo root) so it doesn't need its own
    # top-level .gitignore entry alongside the other generated build/test artifacts.
    $config.CodeCoverage.OutputPath = Join-Path $PSScriptRoot 'coverage.xml'
}

$result = Invoke-Pester -Configuration $config

# Print a compact failure summary at the end so failed tests are always visible
if ($result.FailedCount -gt 0) {
    Write-Host ''
    $format = 'Failed Tests ({0}):'
    Write-Host ($format -f $result.FailedCount) -ForegroundColor Red
    foreach ($test in $result.Failed) {
        Write-Host ('  [-] {0}' -f $test.ExpandedName) -ForegroundColor Red
        Write-Host ('      {0}' -f $test.ErrorRecord.Exception.Message) -ForegroundColor Yellow
    }
    Write-Host ''
}

# Translate and display code coverage, if enabled. A failure here (e.g. missing or stale
# source map) is advisory only - it must never affect the exit code below.
if ($CodeCoverage) {
    try {
        # GetProjectRootedPath($moduleOutputPath) never triggers auto-discovery, since that
        # path is already absolute - and nothing else in this script sets the project root.
        # Without this, Format-PSScriptBuilderSourceCoverage falls back to displaying
        # SourceFile as a full absolute path instead of relative to the project root (its
        # GetProjectRelativePath fallback for an unset root, not a bug in that fallback).
        Set-PSScriptBuilderProjectRoot -Path (Split-Path -Path $PSScriptRoot -Parent)

        Get-PSScriptBuilderSourceCoverage -OutputPath $moduleOutputPath -CodeCoverage $result.CodeCoverage -Verbose |
            Format-PSScriptBuilderSourceCoverage -Detailed
    }
    catch {
        Write-Warning "Failed to translate code coverage: $($_.Exception.Message)"
    }
}

# Exit with 1 if any tests failed, 0 on full success
exit ([int]($result.FailedCount -gt 0))
