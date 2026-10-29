[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Remove the scaffolded project directory created by Run-Example.ps1
$projectDir = Join-Path $PSScriptRoot 'MyProject'
if (Test-Path $projectDir) {
    Remove-Item $projectDir -Recurse -Force
    Write-Host "Reset complete."
    Write-Host "  Removed: MyProject\"
}
else {
    Write-Host "Reset complete (nothing to remove)."
}
