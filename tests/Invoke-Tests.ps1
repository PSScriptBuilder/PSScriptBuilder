using module '..\build\Output\PSScriptBuilder.psd1'

<#
.SYNOPSIS
    Runs the PSScriptBuilder test suite.
.DESCRIPTION
    Loads Pester 5, registers all custom matchers, and executes tests in a defined order:
    Custom Matcher self-tests always run first, followed by the selected suite.
.PARAMETER Suite
    The test suite to run. Defaults to 'All'.
.EXAMPLE
    .\Invoke-Tests.ps1
    Runs the full test suite.
.EXAMPLE
    .\Invoke-Tests.ps1 -Suite Unit
    Runs only Unit tests (Custom Matcher self-tests still run first).
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Unit', 'Integration')]
    [string] $Suite = 'All'
)

# 1. Import Pester
Import-Module -Name Pester -MinimumVersion 5.0 -Force

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
$config = [PesterConfiguration]::Default
$config.Run.Path         = $paths.ToArray()
$config.Run.PassThru     = $true
$config.Output.Verbosity = 'Detailed'

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

# Exit with 1 if any tests failed, 0 on full success
exit ([int]($result.FailedCount -gt 0))
