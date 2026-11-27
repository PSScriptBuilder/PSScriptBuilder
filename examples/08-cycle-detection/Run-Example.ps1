using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Load configuration
$config       = Get-PSScriptBuilderConfiguration
$templatePath = Join-Path $config.Build.TemplatePath "Services.ps1.template"
$outputPath   = Join-Path $config.Build.OutputPath    "Services.ps1"

# Source paths
$classesPath = Join-Path $PSScriptRoot "src\Classes"

# Build ContentCollector
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath $classesPath

# Analyze dependencies before building
$depAnalysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector
Write-Host "Has cycles: $($depAnalysis.HasCycles)"

if ($depAnalysis.HasCycles) {
    Write-Host "Cycle path: $($depAnalysis.CyclePath -join ' -> ')"
}

Write-Host ""

# Attempt build - will fail with a descriptive error
Write-Host "Attempting build..."
Write-Host ""

try {
    Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
        -TemplatePath $templatePath `
        -OutputPath $outputPath | Out-Null
}
catch {
    Write-Host "Build failed: $($_.Exception.Message)"
}
