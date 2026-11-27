using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

Write-Host "Script mode - watching for changes. Press Ctrl+C to stop." -ForegroundColor Cyan

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
    -ScriptBlock {
        param([string[]] $changedFiles)
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $($changedFiles.Count) file(s) changed:" -ForegroundColor Yellow
        foreach ($file in $changedFiles) {
            Write-Host "  -> $file" -ForegroundColor Gray
        }
    }
