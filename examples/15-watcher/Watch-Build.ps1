using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$config        = Get-PSScriptBuilderConfiguration
$templatePath  = Join-Path $config.Build.TemplatePath "AppConfig.ps1.template"
$outputPath    = Join-Path $config.Build.OutputPath   "AppConfig.ps1"

$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

Write-Host "Build mode - watching for changes. Press Ctrl+C to stop." -ForegroundColor Cyan

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
    -TemplatePath $templatePath `
    -OutputPath   $outputPath `
    -OnSuccess {
        param($result)
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Build OK -> $($result.OutputPath)" -ForegroundColor Green
    } `
    -OnError {
        param($result)
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Build FAILED: $($result.Exception.Message)" -ForegroundColor Red
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Triggered by: $($result.ChangedFiles -join ', ')" -ForegroundColor Red
    }
