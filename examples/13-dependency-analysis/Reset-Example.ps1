[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Remove the output directory created by Run-Example.ps1
$outputDir = Join-Path $PSScriptRoot 'output'
if (Test-Path $outputDir) {
    Remove-Item $outputDir -Recurse -Force
    Write-Host "Reset complete."
    Write-Host "  Removed: output\"
}
else {
    Write-Host "Reset complete (nothing to remove)."
}
