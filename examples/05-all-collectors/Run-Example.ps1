using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Load configuration
$config       = Get-PSScriptBuilderConfiguration
$templatePath = Join-Path $config.Build.TemplatePath "HRTools.ps1.template"
$outputPath   = Join-Path $config.Build.OutputPath    "HRTools.ps1"

# Source paths
$usingPath     = Join-Path $PSScriptRoot "src\Functions"
$headerFile    = Join-Path $PSScriptRoot "src\Files\Header.ps1"
$configFile    = Join-Path $PSScriptRoot "src\Files\Configuration.ps1"
$enumsPath     = Join-Path $PSScriptRoot "src\Enums"
$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

# Build
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Using    -IncludePath $usingPath |
    Add-PSScriptBuilderCollector -Type File     -CollectionKey "Header"        -IncludeFile $headerFile  |
    Add-PSScriptBuilderCollector -Type File     -CollectionKey "Configuration" -IncludeFile $configFile  |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath $enumsPath     |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath |
    Invoke-PSScriptBuilderBuild -TemplatePath $templatePath -OutputPath $outputPath

# Summary
Format-PSScriptBuilderBuildResult -BuildResult $result

# Run the generated script
Write-Host ""
Write-Host "--- Running generated script ---"
. $outputPath

$annaAddress = [Address]::new("Musterstrasse 12", "Berlin", "10115", "Germany")
$anna = New-Employee -FirstName "Anna" -LastName "Schmidt" -Address $annaAddress `
    -Department ([Department]::Engineering) -HireDate ([DateTime]::Parse("2019-03-15")) -Salary 75000

Write-Host (Format-EmployeeReport -Employee $anna)
Write-Host ""
Write-Host "Test-EmailAddress 'anna.schmidt@example.com' : $(Test-EmailAddress -EmailAddress 'anna.schmidt@example.com')"
Write-Host "Test-EmailAddress 'not-an-email'             : $(Test-EmailAddress -EmailAddress 'not-an-email')"
