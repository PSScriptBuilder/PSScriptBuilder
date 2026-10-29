[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Reset manifest
$manifestPath = Join-Path $PSScriptRoot 'build\Output\AppConfig.psd1'
(Get-Content $manifestPath) -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion     = '{{VERSION}}'" |
    Set-Content $manifestPath

# Reset template header
$templatePath = Join-Path $PSScriptRoot 'build\Templates\AppConfig.psm1.template'
(Get-Content $templatePath) -replace '# AppConfig Module v\S+', '# AppConfig Module v{{VERSION}}' |
    Set-Content $templatePath

# Reset release data
$releasedataPath = Join-Path $PSScriptRoot 'build\Release\psscriptbuilder.releasedata.json'
$initialPath     = Join-Path $PSScriptRoot 'build\Release\psscriptbuilder.releasedata.initial.json'
Copy-Item $initialPath $releasedataPath -Force

# Reset CHANGELOG
$changelogPath        = Join-Path $PSScriptRoot 'CHANGELOG.md'
$changelogInitialPath = Join-Path $PSScriptRoot 'CHANGELOG.initial.md'
Copy-Item $changelogInitialPath $changelogPath -Force

Write-Host "Reset complete."
Write-Host "  Manifest  : ModuleVersion = '{{VERSION}}'"
Write-Host "  Template  : # AppConfig Module v{{VERSION}}'"
Write-Host "  CHANGELOG : Release: {{VERSION}} | Date: {{BUILD_DATE}}"
Write-Host "  Version   : 1.0.0 (build 0)"
