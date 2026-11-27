[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# Reset Manifest.psd1: back to {{VERSION}} token
$manifestPath = Join-Path $root 'build\Output\Manifest.psd1'
(Get-Content $manifestPath) -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '{{VERSION}}'" |
    Set-Content $manifestPath

# Reset Manifest2.psd1: back to {{VERSION}} token
$manifest2Path = Join-Path $root 'build\Output\Manifest2.psd1'
(Get-Content $manifest2Path) -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '{{VERSION}}'" |
    Set-Content $manifest2Path

# Reset CHANGELOG.md: back to {{VERSION}} / {{BUILD_DATE}} tokens
$changelogPath = Join-Path $root 'CHANGELOG.md'
Set-Content -Path $changelogPath -Value @'
# Changelog

## Unreleased

- Release: {{VERSION}} | Date: {{BUILD_DATE}}
'@

# Reset config/app.json: back to the initial apiVersion value
$appJsonPath = Join-Path $root 'config\app.json'
(Get-Content $appJsonPath) -replace '"apiVersion":\s*"[^"]*"', '"apiVersion": "1.0.0"' |
    Set-Content $appJsonPath

# Reset the build template: back to {{VERSION}} / {{BUILD_DATE}} / {{BUILD_NUMBER}} tokens
$templatePath = Join-Path $root 'build\Templates\Template.ps1.template'
Set-Content -Path $templatePath -Value @'
# StressTest build template
# Version: {{VERSION}}
# Date: {{BUILD_DATE}}
# Build: {{BUILD_NUMBER}}
'@

# Reset release data from the initial backup
$releasedataPath = Join-Path $root 'build\Release\psscriptbuilder.releasedata.json'
$initialPath     = Join-Path $root 'build\Release\psscriptbuilder.releasedata.initial.json'
Copy-Item $initialPath $releasedataPath -Force

Write-Host "Reset complete. All 5 bump targets and release data restored to their initial token state."
