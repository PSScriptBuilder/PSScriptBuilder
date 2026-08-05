using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Load configuration
$config        = Get-PSScriptBuilderConfiguration
$templatePath  = Join-Path $config.Build.TemplatePath "HRWorkforce.ps1.template"
$outputPath    = Join-Path $config.Build.OutputPath    "HRWorkforce.ps1"

# Source paths
$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

# Build ContentCollector
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

# Analyze dependencies before building
$depAnalysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector
Write-Host "Has cross-dependencies: $($depAnalysis.HasCrossDependencies)"
Write-Host "Ordered components    : $($depAnalysis.OrderedComponents -join ', ')"
Write-Host ""

# Analyze template mode
$analysis = Get-PSScriptBuilderTemplateAnalysis -ContentCollector $contentCollector -TemplatePath $templatePath
Write-Host "Template mode: $($analysis.ValidationMode)"
Write-Host ""

# Build
$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath $templatePath `
    -OutputPath $outputPath

# Summary
Format-PSScriptBuilderBuildResult -BuildResult $result

# Run generated script
Write-Host ""
Write-Host "--- Running generated script ---"
. $outputPath

$anna  = New-Employee   -FirstName "Anna"  -LastName "Schmidt" -Department "Engineering"  -StartDate     ([DateTime]::Parse("2019-03-15"))
$james = New-Employee   -FirstName "James" -LastName "Okafor"  -Department "Finance"      -StartDate     ([DateTime]::Parse("2021-07-01"))
$priya = New-Contractor -FirstName "Priya" -LastName "Sharma"  -Company    "TechSolutions" -ContractStart ([DateTime]::Parse("2023-01-01")) -ContractEnd ([DateTime]::Parse("2024-12-31"))

Write-Host "Employees:"
foreach ($e in @($anna, $james)) {
    Write-Host "  $($e.FirstName) $($e.LastName) ($($e.Department), started $($e.StartDate.ToString('yyyy-MM-dd')))"
}

Write-Host ""
Write-Host "Contractors:"
Write-Host "  $($priya.FirstName) $($priya.LastName) ($($priya.Company), $($priya.ContractStart.ToString('yyyy-MM-dd')) to $($priya.ContractEnd.ToString('yyyy-MM-dd')))"
