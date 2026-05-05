using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Load configuration
$config       = Get-PSScriptBuilderConfiguration
$templatePath = Join-Path $config.Build.TemplatePath "AppLogFramework.psm1.template"
$outputPath   = Join-Path $config.Build.OutputPath    "AppLogFramework.psm1"

# Source paths
$coreEnumsPath     = Join-Path $PSScriptRoot "src\Core\Enums"
$coreClassesPath   = Join-Path $PSScriptRoot "src\Core\Classes"
$coreFunctionsPath = Join-Path $PSScriptRoot "src\Core\Functions"
$extClassesPath    = Join-Path $PSScriptRoot "src\Extensions\Classes"
$extFunctionsPath  = Join-Path $PSScriptRoot "src\Extensions\Functions"

# Build
$contentCollector = New-PSScriptBuilderContentCollector
$contentCollector | Add-PSScriptBuilderCollector -Type Enum     -IncludePath $coreEnumsPath     -CollectionKey "CoreEnums"          | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Class    -IncludePath $coreClassesPath   -CollectionKey "CoreClasses"        | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Function -IncludePath $coreFunctionsPath -CollectionKey "CoreFunctions"      | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Class    -IncludePath $extClassesPath    -CollectionKey "ExtensionClasses"   | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Function -IncludePath $extFunctionsPath  -CollectionKey "ExtensionFunctions" | Out-Null

$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath $templatePath `
    -OutputPath $outputPath

Format-PSScriptBuilderBuildResult -BuildResult $result
Write-Host ""

# Run demo
Write-Host "--- Running Demo-Module.ps1 ---"
& "$PSScriptRoot\Demo-Module.ps1"
