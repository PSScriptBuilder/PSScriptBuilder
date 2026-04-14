<#
.SYNOPSIS
    Runs PSScriptAnalyzer on the built PSScriptBuilder module.
.DESCRIPTION
    Installs and imports PSScriptAnalyzer if not available, then analyzes the
    built module file. Warnings are reported but do not fail the script.
    Errors cause the script to terminate.
.EXAMPLE
    .\analyze.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot     = Split-Path $PSScriptRoot -Parent
$psm1Path     = Join-Path $repoRoot 'build\Output\PSScriptBuilder.psm1'
$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'

#region Prerequisites
Write-Host "Checking prerequisites..."

# 1. .psm1
if (-not (Test-Path $psm1Path -PathType Leaf)) {
    throw [InvalidOperationException]::new("Module file not found: $psm1Path")
}
Write-Host "  Module file found."

# 2. Settings file
if (-not (Test-Path $settingsPath -PathType Leaf)) {
    throw [InvalidOperationException]::new("PSScriptAnalyzer settings file not found: $settingsPath")
}
Write-Host "  Settings file found."

# 3. PSScriptAnalyzer available and imported
Write-Host "Preparing PSScriptAnalyzer..."
if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
    Write-Host "  Installing PSScriptAnalyzer..."
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
}

Import-Module -Name PSScriptAnalyzer

if (-not (Get-Module -Name PSScriptAnalyzer)) {
    throw [InvalidOperationException]::new("Failed to import module: PSScriptAnalyzer")
}
Write-Host "  PSScriptAnalyzer imported."

Write-Host "All prerequisites met."
#endregion Prerequisites

#region Analyze
Write-Host "Running PSScriptAnalyzer..."
$results  = Invoke-ScriptAnalyzer -Path $psm1Path -Settings $settingsPath -Severity Warning
$warnings = @($results | Where-Object { $_.Severity -eq 'Warning' })
$errors   = @($results | Where-Object { $_.Severity -eq 'Error'   })

if ($warnings.Count -gt 0) {
    Write-Host "  Warnings ($($warnings.Count)):"
    $warnings | ForEach-Object { Write-Host "    [$($_.RuleName)] $($_.Message) (Line $($_.Line))" }
}
else {
    Write-Host "  No warnings."
}

if ($errors.Count -gt 0) {
    $message = "PSScriptAnalyzer found {0} error(s):`n{1}" -f $errors.Count, ($errors | Out-String)
    throw [InvalidOperationException]::new($message)
}

Write-Host "Analysis complete."
#endregion Analyze
