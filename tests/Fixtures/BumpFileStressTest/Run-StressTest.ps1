using module '..\..\..\build\Output\PSScriptBuilder.psd1'

<#
.SYNOPSIS
    Manual runner for the BumpFileStressTest fixture.
.DESCRIPTION
    Not a numbered example (see tests/Fixtures/BumpFileStressTest/README.md for why) - this runs
    the release/bump cycle three times in a row across 5 targets covering every bump mode
    combination (Simple-only, Placeholder-only, self-sustaining Regex, Mixed Mode, partial Regex
    fallback), to show live which targets go stale and warn (RFC 0019) and which stay silent.
    Run .\Reset-StressTest.ps1 first if this has already been run once.
#>

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-PSScriptBuilderProjectRoot -Path $root

function Write-Section {
    param([string] $Title)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

for ($run = 1; $run -le 3; $run++) {
    Write-Section "Run $run of 3"

    Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null

    # -WarningVariable does not reliably capture warnings raised from deep inside a class method
    # call chain (verified empirically); '*>&1' does - it merges every stream into the output
    # pipeline, so a WarningRecord shows up as a regular object next to the bump result.
    $output     = Update-PSScriptBuilderBumpFiles *>&1
    $warnings   = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
    $bumpResult = $output | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }

    Write-Host "  Files processed : $($bumpResult.TotalFilesProcessed)"
    Write-Host "  Files modified  : $($bumpResult.TotalFilesModified)"

    if ($warnings -and $warnings.Count -gt 0) {
        foreach ($w in $warnings) {
            Write-Host "  WARNING: $($w.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  No warnings." -ForegroundColor Green
    }
}

Write-Section "Done"
Write-Host "Run .\Reset-StressTest.ps1 to restore the initial token state before running again."
