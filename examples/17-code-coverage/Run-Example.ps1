using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$templatePath  = Join-Path $PSScriptRoot 'build\Templates\HRTools.ps1.template'
$outputPath    = Join-Path $PSScriptRoot 'build\Output\HRTools.ps1'
$classesPath   = Join-Path $PSScriptRoot 'src\Classes'
$functionsPath = Join-Path $PSScriptRoot 'src\Functions'
$testsPath     = Join-Path $PSScriptRoot 'tests'

# ============================================================
# Build with -WriteSourceMap
# ============================================================
# A source map is required to translate the Pester coverage results, reported against the
# built output below, back to these per-source-file rows.

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

$result = Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     $templatePath `
    -OutputPath       $outputPath `
    -WriteSourceMap

Format-PSScriptBuilderBuildResult -BuildResult $result

Write-Host ''

# ============================================================
# Run the Pester test suite with CodeCoverage enabled
# ============================================================
# CodeCoverage.Path must point at the BUILT output, not at src\ - tests\HRTools.Tests.ps1
# dot-sources $outputPath in its own BeforeAll, so that is the only file Pester has any
# execution history for. The test suite is deliberately incomplete (see its own comment) to
# produce a realistic, mixed coverage report below.

Import-Module -Name Pester -MinimumVersion 5.0 -Force

$config = [PesterConfiguration]::Default
$config.Run.Path             = $testsPath
$config.Run.PassThru         = $true
$config.Output.Verbosity     = 'Detailed'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path    = $outputPath

# Pester always writes a coverage report file when CodeCoverage.Enabled is true - redirect it
# into build\Output\, which is already excluded from source control, instead of the example
# folder's root.
$config.CodeCoverage.OutputPath = Join-Path $PSScriptRoot 'build\Output\coverage.xml'

$pesterResult = Invoke-Pester -Configuration $config

# ============================================================
# Translate coverage back to the original source files
# ============================================================
# Get-PSScriptBuilderSourceCoverage reads the sidecar written above and maps the raw,
# output-line-based Pester result back to per-source-file aggregates. -Detailed additionally
# lists every distinct source line with a missed command.

Write-Host '=== Source coverage, by original file ===' -ForegroundColor Cyan

$result | Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
    Format-PSScriptBuilderSourceCoverage -Detailed
