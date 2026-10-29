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

# All collectors point to the same src/ directory
$srcPath = Join-Path $PSScriptRoot "src"

# Build
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath $srcPath |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $srcPath |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $srcPath |
    Invoke-PSScriptBuilderBuild -TemplatePath $templatePath -OutputPath $outputPath

# Summary
Format-PSScriptBuilderBuildResult -BuildResult $result

# Run the generated script
Write-Host ""
Write-Host "--- Running generated script ---"
. $outputPath

$annaAddress  = [Address]::new("Musterstrasse 12", "Berlin", "10115", "Germany")
$jamesAddress = [Address]::new("Baker Street 221", "London", "NW1 6XE", "United Kingdom")

$anna  = New-Employee -FirstName "Anna"  -LastName "Schmidt" -Address $annaAddress  -Department ([Department]::Engineering) -HireDate ([DateTime]::Parse("2019-03-15")) -Salary 75000
$james = New-Employee -FirstName "James" -LastName "Okafor"  -Address $jamesAddress -Department ([Department]::Finance)     -HireDate ([DateTime]::Parse("2021-07-01")) -Salary 68000

$employees = @($anna, $james)

$engineers = Get-EmployeesByDepartment -Employees $employees -Department ([Department]::Engineering)
Write-Host "Employees in Engineering:"
foreach ($e in $engineers) {
    Write-Host "  $($e.FirstName) $($e.LastName)"
}
