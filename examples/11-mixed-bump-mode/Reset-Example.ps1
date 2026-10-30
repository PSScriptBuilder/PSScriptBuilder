[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Reset manifest: replace current version back to {{VERSION}} token
$manifestPath = Join-Path $PSScriptRoot 'build\Output\AppConfig.psd1'
(Get-Content $manifestPath) -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '{{VERSION}}'" |
    Set-Content $manifestPath

# Reset template header: replace current version back to {{VERSION}} token
$templatePath = Join-Path $PSScriptRoot 'build\Templates\AppConfig.psm1.template'
(Get-Content $templatePath) -replace '# AppConfig Module v\S+', '# AppConfig Module v{{VERSION}}' |
    Set-Content $templatePath

# Reset release data from initial backup
$releasedataPath = Join-Path $PSScriptRoot 'build\Release\psscriptbuilder.releasedata.json'
$initialPath     = Join-Path $PSScriptRoot 'build\Release\psscriptbuilder.releasedata.initial.json'
Copy-Item $initialPath $releasedataPath -Force

Write-Host "Reset complete."
Write-Host "  Manifest  : ModuleVersion = '{{VERSION}}'"
Write-Host "  Template  : # AppConfig Module v{{VERSION}}'"
Write-Host "  Version   : 1.0.0 (build 0)"
