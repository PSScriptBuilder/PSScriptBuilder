using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

$ErrorActionPreference = 'Stop'

# The scaffolded project is created as a subdirectory of this example folder.
# Any existing MyProject directory is removed first so the example can be run multiple times.
$projectPath = Join-Path $PSScriptRoot 'MyProject'

if (Test-Path $projectPath) {
    Remove-Item $projectPath -Recurse -Force
    Write-Host "Removed existing MyProject directory."
}

# ==============================================================
# Phase 1: Scaffold a new project
# ==============================================================

Write-Host ''
Write-Host '=== Phase 1: Scaffold new project ===' -ForegroundColor Cyan

$result = New-PSScriptBuilderProject -Name 'MyProject' -Path $PSScriptRoot -IncludeReleaseManagement -Verbose

Write-Host ''
Write-Host "Project created at: $($result.ProjectPath)"
Write-Host "Directories created ($($result.CreatedDirectories.Count)):"
$result.CreatedDirectories | ForEach-Object { Write-Host "  $_" }
Write-Host "Files created ($($result.CreatedFiles.Count)):"
$result.CreatedFiles | ForEach-Object { Write-Host "  $_" }

# ==============================================================
# Phase 2: Set project root to the newly scaffolded project
# ==============================================================
# Set-PSScriptBuilderProjectRoot must be called explicitly here because the
# current working directory ($PSScriptRoot) is the example folder, not the
# scaffolded project. All subsequent PSScriptBuilder cmdlets resolve paths
# relative to the registered project root.

Write-Host ''
Write-Host '=== Phase 2: Set project root ===' -ForegroundColor Cyan

Set-PSScriptBuilderProjectRoot -Path $result.ProjectPath
Write-Host "Project root set to: $($result.ProjectPath)"

# ==============================================================
# Phase 3: Update release data (bump patch version)
# ==============================================================

Write-Host ''
Write-Host '=== Phase 3: Update release data ===' -ForegroundColor Cyan

Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails -Verbose | Out-Null

$releaseData = Get-PSScriptBuilderReleaseData
Write-Host "Version  : $($releaseData.Version.Full)"
Write-Host "Timestamp: $($releaseData.Build.Timestamp)"

# ==============================================================
# Phase 4: Apply version to files (bump)
# ==============================================================

Write-Host ''
Write-Host '=== Phase 4: Apply version to template ===' -ForegroundColor Cyan

Update-PSScriptBuilderBumpFiles -Verbose | Out-Null

$templatePath = Join-Path $result.ProjectPath 'build\Templates\MyProject.ps1.template'
Write-Host "Template header after bump:"
Get-Content $templatePath | Select-Object -First 4 | ForEach-Object { Write-Host "  $_" }

# ==============================================================
# Phase 5: Build
# ==============================================================

Write-Host ''
Write-Host '=== Phase 5: Build ===' -ForegroundColor Cyan

$config = Get-PSScriptBuilderConfiguration

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath '.\src\Enums' |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath '.\src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath '.\src\Public'

$outputPath   = Join-Path $config.Build.OutputPath   'MyProject.ps1'
$templatePath = Join-Path $config.Build.TemplatePath 'MyProject.ps1.template'

Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector -TemplatePath $templatePath -OutputPath $outputPath |
    Format-PSScriptBuilderBuildResult

Write-Host ''
Write-Host "Output file: $outputPath"
Write-Host "Output file content:"
Write-Host '---'
Get-Content $outputPath | ForEach-Object { Write-Host "  $_" }
Write-Host '---'

# ==============================================================
# Phase 6: Run the generated script
# ==============================================================

Write-Host ''
Write-Host '=== Phase 6: Run the generated script ===' -ForegroundColor Cyan
Write-Host "Executing: $outputPath"
Write-Host '---'
& $outputPath
Write-Host '---'

Write-Host ''
Write-Host 'Done. The scaffolded project is available at:'
Write-Host "  $($result.ProjectPath)"
