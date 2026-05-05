using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Load configuration
$config        = Get-PSScriptBuilderConfiguration
$templatePath  = Join-Path $config.Build.TemplatePath "AppConfig.psm1.template"
$outputPath    = Join-Path $config.Build.OutputPath    "AppConfig.psm1"

# Source paths
$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

# Build
$contentCollector = New-PSScriptBuilderContentCollector
$contentCollector | Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath    | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath  | Out-Null

$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath $templatePath `
    -OutputPath $outputPath

Format-PSScriptBuilderBuildResult -BuildResult $result
Write-Host ""

# Run demo
Write-Host "--- Running Demo-Module.ps1 ---"
& "$PSScriptRoot\Demo-Module.ps1"
