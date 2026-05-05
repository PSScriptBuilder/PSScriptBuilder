using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Paths
$config         = Get-PSScriptBuilderConfiguration
$templatePath   = Join-Path $config.Build.TemplatePath "AppConfig.psm1.template"
$outputPath     = Join-Path $config.Build.OutputPath   "AppConfig.psm1"
$compressedPath = Join-Path $config.Build.OutputPath   "AppConfig.compressed.psm1"

# -----------------------------------------------------------------------
# Phase 1: Update release data
# -----------------------------------------------------------------------
Write-Host "=== Phase 1: Update release data ==="
$releaseResult = Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails
Format-PSScriptBuilderReleaseDataResult -ReleaseDataResult $releaseResult

# -----------------------------------------------------------------------
# Phase 2: Apply version to files
# -----------------------------------------------------------------------
Write-Host "=== Phase 2: Apply version to files ==="
$bumpResult = Update-PSScriptBuilderBumpFiles
Format-PSScriptBuilderBumpResult -BumpResult $bumpResult

# -----------------------------------------------------------------------
# Phase 3: Build
# -----------------------------------------------------------------------
Write-Host "=== Phase 3: Build module ==="

$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

$contentCollector = New-PSScriptBuilderContentCollector
$contentCollector | Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath    | Out-Null
$contentCollector | Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath  | Out-Null

$buildResult = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath $templatePath `
    -OutputPath $outputPath

Format-PSScriptBuilderBuildResult -BuildResult $buildResult
Write-Host ""

# -----------------------------------------------------------------------
# Phase 4: Post-process
# -----------------------------------------------------------------------
Write-Host "=== Phase 4: Post-process output ==="
$buildResult | Compress-PSScriptBuilderScript -RemoveComments -RemoveBlankLines -DestinationPath $compressedPath -Force
Write-Host "Post-processing complete."
Write-Host ""

# -----------------------------------------------------------------------
# Phase 5: Demo
# -----------------------------------------------------------------------
Write-Host "=== Phase 5: Demo ==="
& "$PSScriptRoot\Demo-Module.ps1"
