using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Build paths
$templatePath = Join-Path $PSScriptRoot "build\Templates\HRUtils.ps1.template"
$outputPath   = Join-Path $PSScriptRoot "build\Output\HRUtils.ps1"
$srcPath      = Join-Path $PSScriptRoot "src"

# Build
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $srcPath

$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath $templatePath `
    -OutputPath $outputPath

# Summary
Format-PSScriptBuilderBuildResult -BuildResult $result

# Run the generated script
Write-Host ""
Write-Host "--- Running generated script ---"
. $outputPath

Write-Host (Get-FormattedName -FirstName "Anna" -LastName "Schmidt")
Write-Host (Get-YearsOfService -HireDate ([DateTime]::Parse("2019-03-15")))
Write-Host (Format-Salary -Amount 55000)
