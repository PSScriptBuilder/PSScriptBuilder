#Requires -Version 5.1
<#
.SYNOPSIS
    Runs all PSScriptBuilder examples and verifies they complete successfully.
.DESCRIPTION
    Executes each Run-Example.ps1 in a separate PowerShell process and checks for a zero
    exit code and the presence of expected output files. Uses the same PowerShell host
    that is running this script (pwsh or powershell.exe).

    Example 15 (Watcher) is skipped because it runs indefinitely.
    Examples 11 and 12 are reset to their initial state before and after each run.
    Examples 13 and 14 clean up created files and directories before and after each run.
.PARAMETER TimeoutSeconds
    Maximum time in seconds to wait for each example to complete. Default: 60.
.EXAMPLE
    .\tests\Invoke-ExampleTests.ps1
    Runs all examples with a 60-second timeout per example.
.EXAMPLE
    .\tests\Invoke-ExampleTests.ps1 -TimeoutSeconds 120
    Runs all examples with a 120-second timeout per example.
#>
[CmdletBinding()]
param(
    [int] $TimeoutSeconds = 60
)

Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#region Helpers
$script:Results  = @{ Passed = 0; Failed = 0 }
$script:ShellExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

function Write-SectionHeader {
    param([string] $Title)
    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "  $([string]::new([char]0x2500, $Title.Length))" -ForegroundColor DarkGray
}

function Invoke-ExampleCheck {
    param(
        [string] $Label,
        [string] $ExampleFolder,
        [string] $ExpectedOutput,
        [switch] $NeedsReset,
        [switch] $Skip
    )

    if ($Skip) {
        Write-Host '  [' -NoNewline
        Write-Host '-' -ForegroundColor DarkGray -NoNewline
        Write-Host "] $Label  " -NoNewline
        Write-Host "(skipped $([char]0x2014) runs indefinitely)" -ForegroundColor DarkGray
        return
    }

    # Reset if needed (run in subprocess to preserve $PSScriptRoot)
    if ($NeedsReset) {
        $resetScript = Join-Path $ExampleFolder 'Reset-Example.ps1'
        if (Test-Path $resetScript) {
            & $script:ShellExe -NoProfile -NonInteractive -File $resetScript 2>&1 | Out-Null
        }
    }

    try {
        $scriptPath = Join-Path $ExampleFolder 'Run-Example.ps1'

        # Use System.Diagnostics.Process directly — Start-Process -PassThru does not reliably
        # populate ExitCode in PS 5.1 (Windows PowerShell).
        $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $processStartInfo.FileName               = $script:ShellExe
        $processStartInfo.Arguments              = "-NoProfile -NonInteractive -File `"$scriptPath`""
        $processStartInfo.UseShellExecute        = $false
        $processStartInfo.CreateNoWindow         = $true
        $processStartInfo.WorkingDirectory       = $ExampleFolder
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError  = $true

        $proc = [System.Diagnostics.Process]::new()
        $proc.StartInfo = $processStartInfo
        [void] $proc.Start()

        # Read stdout/stderr asynchronously to prevent deadlock when buffers fill.
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        $completed = $proc.WaitForExit($TimeoutSeconds * 1000)
        # Second WaitForExit() (no timeout) ensures all async I/O is flushed before reading ExitCode.
        if ($completed) { $proc.WaitForExit() }

        if (-not $completed) {
            try { $proc.Kill() } catch { }
            $proc.Dispose()
            Write-Host '  [' -NoNewline
            Write-Host ([char] 0x2717) -ForegroundColor Red -NoNewline
            Write-Host "] $Label  " -NoNewline
            Write-Host "(timed out after ${TimeoutSeconds}s)" -ForegroundColor DarkGray
            $script:Results.Failed++
            return
        }

        $outText  = $stdoutTask.GetAwaiter().GetResult()
        $errText  = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $proc.ExitCode
        $proc.Dispose()

        if ($exitCode -ne 0) {
            Write-Host '  [' -NoNewline
            Write-Host ([char] 0x2717) -ForegroundColor Red -NoNewline
            Write-Host "] $Label  " -NoNewline
            Write-Host "(exit code $exitCode)" -ForegroundColor DarkGray
            if ($outText) { $outText -split [Environment]::NewLine | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray } }
            if ($errText) { $errText -split [Environment]::NewLine | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }
            $script:Results.Failed++
            return
        }

        if ($ExpectedOutput) {
            $outputPath = Join-Path $ExampleFolder $ExpectedOutput
            if (-not (Test-Path $outputPath)) {
                Write-Host '  [' -NoNewline
                Write-Host ([char] 0x2717) -ForegroundColor Red -NoNewline
                Write-Host "] $Label  " -NoNewline
                Write-Host "(output file not found: $ExpectedOutput)" -ForegroundColor DarkGray
                $script:Results.Failed++
                return
            }

            if ((Get-Item $outputPath).Length -eq 0) {
                Write-Host '  [' -NoNewline
                Write-Host ([char] 0x2717) -ForegroundColor Red -NoNewline
                Write-Host "] $Label  " -NoNewline
                Write-Host "(output file is empty: $ExpectedOutput)" -ForegroundColor DarkGray
                $script:Results.Failed++
                return
            }
        }

        Write-Host '  [' -NoNewline
        Write-Host ([char] 0x2713) -ForegroundColor Green -NoNewline
        Write-Host "] $Label"
        $script:Results.Passed++
    }
    finally {
        if ($NeedsReset) {
            $resetScript = Join-Path $ExampleFolder 'Reset-Example.ps1'
            if (Test-Path $resetScript) {
                & $script:ShellExe -NoProfile -NonInteractive -File $resetScript 2>&1 | Out-Null
            }
        }
    }
}
#endregion Helpers

#region Setup
$examplesRoot = Resolve-Path "$PSScriptRoot\..\examples"

Write-Host ''
Write-Host "  PSScriptBuilder $([char] 0x2014) Example Tests"            -ForegroundColor White
Write-Host "  $([string]::new([char] 0x2550, 34))"                       -ForegroundColor DarkGray
Write-Host "  Shell   : $script:ShellExe ($($PSVersionTable.PSVersion))" -ForegroundColor DarkGray
Write-Host "  Timeout : ${TimeoutSeconds}s per example"                  -ForegroundColor DarkGray
#endregion Setup

#region Examples
Write-SectionHeader 'Script Building (01-08)'

Invoke-ExampleCheck -Label '01 - Functions Only'          -ExampleFolder (Join-Path $examplesRoot '01-functions-only')          -ExpectedOutput 'build\Output\HRUtils.ps1'
Invoke-ExampleCheck -Label '02 - Classes and Enums'       -ExampleFolder (Join-Path $examplesRoot '02-classes-and-enums')       -ExpectedOutput 'build\Output\HRTools.ps1'
Invoke-ExampleCheck -Label '03 - With Configuration'      -ExampleFolder (Join-Path $examplesRoot '03-with-configuration')      -ExpectedOutput 'build\Output\HRTools.ps1'
Invoke-ExampleCheck -Label '04 - Flexible File Structure' -ExampleFolder (Join-Path $examplesRoot '04-flexible-file-structure') -ExpectedOutput 'build\Output\HRTools.ps1'
Invoke-ExampleCheck -Label '05 - All Collectors'          -ExampleFolder (Join-Path $examplesRoot '05-all-collectors')          -ExpectedOutput 'build\Output\HRTools.ps1'
Invoke-ExampleCheck -Label '06 - Hybrid Mode'             -ExampleFolder (Join-Path $examplesRoot '06-hybrid-mode')             -ExpectedOutput 'build\Output\HRTools.ps1'
Invoke-ExampleCheck -Label '07 - Ordered Mode'            -ExampleFolder (Join-Path $examplesRoot '07-ordered-mode')            -ExpectedOutput 'build\Output\HRWorkforce.ps1'
Invoke-ExampleCheck -Label '08 - Cycle Detection'         -ExampleFolder (Join-Path $examplesRoot '08-cycle-detection')

Write-SectionHeader 'Module Building (09-12)'

Invoke-ExampleCheck -Label '09 - Module Build'        -ExampleFolder (Join-Path $examplesRoot '09-module-build')        -ExpectedOutput 'build\Output\AppConfig.psm1'
Invoke-ExampleCheck -Label '10 - Multiple Collectors' -ExampleFolder (Join-Path $examplesRoot '10-multiple-collectors') -ExpectedOutput 'build\Output\AppLogFramework.psm1'
Invoke-ExampleCheck -Label '11 - Mixed Bump Mode'     -ExampleFolder (Join-Path $examplesRoot '11-mixed-bump-mode')     -NeedsReset
Invoke-ExampleCheck -Label '12 - Full Workflow'       -ExampleFolder (Join-Path $examplesRoot '12-full-workflow')       -ExpectedOutput 'build\Output\AppConfig.psm1' -NeedsReset

Write-SectionHeader 'Analysis and Tooling (13-15)'

Invoke-ExampleCheck -Label '13 - Dependency Analysis' -ExampleFolder (Join-Path $examplesRoot '13-dependency-analysis') -NeedsReset
Invoke-ExampleCheck -Label '14 - Scaffolding'         -ExampleFolder (Join-Path $examplesRoot '14-scaffolding')         -NeedsReset
Invoke-ExampleCheck -Label '15 - Watcher'             -ExampleFolder (Join-Path $examplesRoot '15-watcher')             -Skip
#endregion Examples

#region Summary
$total = $script:Results.Passed + $script:Results.Failed

Write-Host ''
Write-Host "  $([string]::new([char]0x2500, 34))" -ForegroundColor DarkGray

if ($script:Results.Failed -eq 0) {
    Write-Host "  All $total examples passed" -ForegroundColor Green
}
else {
    Write-Host "  $($script:Results.Passed) / $total passed" -ForegroundColor Yellow
    Write-Host "  $($script:Results.Failed) failed"          -ForegroundColor Red
}

Write-Host ''
#endregion Summary
