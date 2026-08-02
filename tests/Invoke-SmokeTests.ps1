#Requires -Version 5.1
<#
.SYNOPSIS
    Smoke test script for PSScriptBuilder — verifies all analysis cmdlets are callable.
.DESCRIPTION
    Runs all analysis cmdlets against the PSScriptBuilder project itself and reports
    pass/fail for each check. Intended to be run after a successful build.
.EXAMPLE
    .\tests\Invoke-SmokeTests.ps1
    Runs all smoke test checks and displays a pass/fail summary.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#region Helper
$script:Results = @{ Passed = 0; Failed = 0 }

function Write-SectionHeader {
    param([string] $Title)
    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "  $([string]::new([char]0x2500, $Title.Length))" -ForegroundColor DarkGray
}

function Invoke-Check {
    param([string] $Label, [scriptblock] $Action)
    try {
        $ErrorActionPreference = 'Stop'
        & $Action | Out-Null
        Write-Host '  [' -NoNewline
        Write-Host ([char]0x2713) -ForegroundColor Green -NoNewline
        Write-Host "] $Label"
        $script:Results.Passed++
    }
    catch {
        Write-Host '  [' -NoNewline
        Write-Host ([char] 0x2717) -ForegroundColor Red -NoNewline
        Write-Host "] $Label" -NoNewline
        Write-Host "  ->  $($_.Exception.Message)" -ForegroundColor DarkGray
        $script:Results.Failed++
    }
}
#endregion Helper

#region Setup
$ProjectRoot      = Resolve-Path "$PSScriptRoot\.."
$ModulePath       = Join-Path $ProjectRoot 'build\Output\PSScriptBuilder.psd1'
$SourceDir        = Join-Path $ProjectRoot 'src'
$SourceEnumsDir   = Join-Path $ProjectRoot 'src\Enums'
$SourceClassesDir = Join-Path $ProjectRoot 'src\Classes'
$SourcePrivateDir = Join-Path $ProjectRoot 'src\Private'
$SourcePublicDir  = Join-Path $ProjectRoot 'src\Public'
$TemplatePath     = Join-Path $ProjectRoot 'build\Templates\PSScriptBuilder.psm1.template'

Write-Host ''
Write-Host "  PSScriptBuilder $([char] 0x2014) Smoke Test" -ForegroundColor White
Write-Host "  $([string]::new([char] 0x2550, 28))"           -ForegroundColor DarkGray
Write-Host "  Project : $ProjectRoot"        -ForegroundColor DarkGray
Write-Host "  Module  : $ModulePath"         -ForegroundColor DarkGray
#endregion Setup

#region Module
Write-SectionHeader 'Module'

Invoke-Check 'Import-Module'                  { Import-Module $ModulePath -Force }
Invoke-Check 'Set-PSScriptBuilderProjectRoot' { Set-PSScriptBuilderProjectRoot -Path $ProjectRoot }
#endregion Module

#region Configuration
Write-SectionHeader 'Configuration'

Invoke-Check 'Get-PSScriptBuilderConfiguration'      { Get-PSScriptBuilderConfiguration }
Invoke-Check 'Get-PSScriptBuilderReleaseData'        { Get-PSScriptBuilderReleaseData }
Invoke-Check 'Get-PSScriptBuilderReleaseDataTokens'  { Get-PSScriptBuilderReleaseDataTokens }
Invoke-Check 'Get-PSScriptBuilderBumpConfiguration'  { Get-PSScriptBuilderBumpConfiguration }
Invoke-Check 'Test-PSScriptBuilderBumpConfiguration' { Test-PSScriptBuilderBumpConfiguration }
Invoke-Check 'Test-PSScriptBuilderReleaseData'       { Test-PSScriptBuilderReleaseData }
#endregion Configuration

#region Collectors
Write-SectionHeader 'Collectors'

$script:cc = $null

Invoke-Check 'New-PSScriptBuilderCollector' {
    New-PSScriptBuilderCollector -Type Class -IncludePath $SourceClassesDir
}

Invoke-Check 'New-PSScriptBuilderContentCollector' {
    $script:cc = New-PSScriptBuilderContentCollector
}

Invoke-Check 'Add-PSScriptBuilderCollector (Using)' {
    $script:cc = $script:cc | Add-PSScriptBuilderCollector -Type Using -IncludePath $SourceDir
}

Invoke-Check 'Add-PSScriptBuilderCollector (Enum)' {
    $script:cc = $script:cc | Add-PSScriptBuilderCollector -Type Enum -IncludePath $SourceEnumsDir
}

Invoke-Check 'Add-PSScriptBuilderCollector (Class)' {
    $script:cc = $script:cc | Add-PSScriptBuilderCollector -Type Class -IncludePath $SourceClassesDir
}

Invoke-Check 'Add-PSScriptBuilderCollector (Function)' {
    $script:cc = $script:cc | Add-PSScriptBuilderCollector -Type Function -IncludePath $SourcePrivateDir, $SourcePublicDir
}

Invoke-Check 'Get-PSScriptBuilderCollector' {
    $script:cc | Get-PSScriptBuilderCollector
}

Invoke-Check 'Remove-PSScriptBuilderCollector' {
    $tempCc = New-PSScriptBuilderContentCollector |
        Add-PSScriptBuilderCollector -Type Enum -CollectionKey 'TEMP_ENUM' -IncludePath $SourceEnumsDir
    $tempCc | Remove-PSScriptBuilderCollector -CollectionKey 'TEMP_ENUM'
}
#endregion Collectors

#region Analysis
Write-SectionHeader 'Analysis'

Invoke-Check 'Get-PSScriptBuilderDependencyAnalysis' {
    $script:cc | Get-PSScriptBuilderDependencyAnalysis
}

Invoke-Check 'Get-PSScriptBuilderCollectorContent' {
    $script:cc | Get-PSScriptBuilderCollector -Type ClassCollector |
        Get-PSScriptBuilderCollectorContent
}

Invoke-Check 'Get-PSScriptBuilderTemplateAnalysis' {
    $script:cc | Get-PSScriptBuilderTemplateAnalysis -TemplatePath $TemplatePath
}

Invoke-Check 'Find-PSScriptBuilderUnusedComponent' {
    $script:cc | Find-PSScriptBuilderUnusedComponent -EntryPoint '*-PSScriptBuilder*'
}
#endregion Analysis

#region Summary
$total = $script:Results.Passed + $script:Results.Failed

Write-Host ''
Write-Host "  $([string]::new([char]0x2500, 28))" -ForegroundColor DarkGray

if ($script:Results.Failed -eq 0) {
    Write-Host "  All $total checks passed" -ForegroundColor Green
}
else {
    Write-Host "  $($script:Results.Passed) / $total passed" -ForegroundColor Yellow
    Write-Host "  $($script:Results.Failed) failed"          -ForegroundColor Red
}

Write-Host ''
#endregion Summary
