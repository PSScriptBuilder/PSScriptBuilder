using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# Show initial state
$manifestPath  = Join-Path $PSScriptRoot 'build\Output\AppConfig.psd1'
$templatePath  = Join-Path $PSScriptRoot 'build\Templates\AppConfig.psm1.template'

Write-Host "=== Before bump ==="
Write-Host "  Manifest : $((Get-Content $manifestPath  | Where-Object { $_ -match 'ModuleVersion' } | Select-Object -First 1).Trim())"
Write-Host "  Template : $((Get-Content $templatePath  | Where-Object { $_ -match '# AppConfig'   } | Select-Object -First 1).Trim())"
Write-Host ""

# Step 1: Bump patch version and update build details
Write-Host "=== Step 1: Update release data ==="
$releaseResult = Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails
Format-PSScriptBuilderReleaseDataResult -ReleaseDataResult $releaseResult

# Step 2: Apply version to files
Write-Host "=== Step 2: Apply version to files ==="
$bumpResult = Update-PSScriptBuilderBumpFiles
Format-PSScriptBuilderBumpResult -BumpResult $bumpResult

# Show final state
Write-Host "=== After bump ==="
Write-Host "  Manifest : $((Get-Content $manifestPath  | Where-Object { $_ -match 'ModuleVersion' } | Select-Object -First 1).Trim())"
Write-Host "  Template : $((Get-Content $templatePath  | Where-Object { $_ -match '# AppConfig'   } | Select-Object -First 1).Trim())"
Write-Host ""
Write-Host "Run .\Reset-Example.ps1 to restore the initial token state."
