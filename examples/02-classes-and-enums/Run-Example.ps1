using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Build paths
$templatePath = Join-Path $PSScriptRoot "build\Templates\HRModule.ps1.template"
$outputPath   = Join-Path $PSScriptRoot "build\Output\HRModule.ps1"
$enumsPath    = Join-Path $PSScriptRoot "src\Enums"
$classesPath  = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

# Build
$contentCollector = New-PSScriptBuilderContentCollector
$contentCollector | Add-PSScriptBuilderCollector -Type Enum     -IncludePath $enumsPath     | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath   | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath | Out-Null

$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath $templatePath `
    -OutputPath $outputPath

# Summary
Format-PSScriptBuilderBuildResult -BuildResult $result

# Run the generated script
Write-Host ""
Write-Host "--- Running generated script ---"
. $outputPath

$annaAddress  = [Address]::new("Musterstrasse 12", "Berlin",   "10115", "Germany")
$jamesAddress = [Address]::new("Baker Street 221",  "London",  "NW1 6XE", "United Kingdom")
$priyaAddress = [Address]::new("Main Street 5",     "Munich",  "80331", "Germany")

$anna  = New-Employee -FirstName "Anna"  -LastName "Schmidt" -Address $annaAddress  -Department ([Department]::Engineering)   -HireDate ([DateTime]::Parse("2019-03-15")) -Salary 75000
$james = New-Employee -FirstName "James" -LastName "Okafor"  -Address $jamesAddress -Department ([Department]::Finance)        -HireDate ([DateTime]::Parse("2021-07-01")) -Salary 68000
$priya = New-Employee -FirstName "Priya" -LastName "Sharma"  -Address $priyaAddress -Department ([Department]::HumanResources) -HireDate ([DateTime]::Parse("2016-11-20")) -Salary 82000

$employees = @($anna, $james, $priya)

$engineers = Get-EmployeesByDepartment -Employees $employees -Department ([Department]::Engineering)
Write-Host "Employees in Engineering:"
foreach ($e in $engineers) {
    Write-Host "  $($e.FirstName) $($e.LastName)"
}

Set-EmployeeStatus -Employee $james -Status ([EmploymentStatus]::OnLeave)
Write-Host ""
Write-Host "$($james.FirstName) $($james.LastName) is now: $($james.Status)"
