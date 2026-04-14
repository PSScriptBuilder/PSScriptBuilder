using module .\build\Output\PSScriptBuilder.psd1

<#
.SYNOPSIS
    Builds the PSScriptBuilder module using the module CLI and the template.
.DESCRIPTION
    Builds PSScriptBuilder.psm1 from source using the module's own collector and template pipeline.
    In Release mode, version metadata is updated and all configured bump files are synchronized
    before the build runs.
.PARAMETER Release
    Activates Release mode: updates build metadata, Git metadata, and configured bump files
    before building. Use together with -Major, -Minor, or -Patch to also bump the version.
.PARAMETER Major
    Bumps the major version (X.0.0). Only valid in combination with -Release.
.PARAMETER Minor
    Bumps the minor version (0.X.0). Only valid in combination with -Release.
.PARAMETER Patch
    Bumps the patch version (0.0.X). Only valid in combination with -Release.
.EXAMPLE
    .\Build-Module.ps1
    Development build — only compiles the module, no version changes.
.EXAMPLE
    .\Build-Module.ps1 -Release -Patch
    Release build — bumps patch version, updates build and Git metadata, applies version to
    configured files, then builds the module.
#>
[CmdletBinding()]
param(
    [switch] $Release,
    [switch] $Major,
    [switch] $Minor,
    [switch] $Patch
)

$savedVerbosePreference = $Global:VerbosePreference
if ($VerbosePreference -eq 'Continue') {
    $Global:VerbosePreference = 'Continue'
}

if ($Global:PSScriptBuilderBuildExecuted) {
    Write-Warning "Build-Module.ps1 has already been executed in this session. Start a new PowerShell session to run it again."
    return
}

$Global:PSScriptBuilderBuildExecuted = $true

if (-not (Test-Path -Path '.\psscriptbuilder.config.json')) {
    New-PSScriptBuilderConfiguration
}

Set-PSScriptBuilderProjectRoot -Path '.'

if ($Release) {
    $releaseParams = @{
        UpdateBuildDetails = $true
        UpdateGitDetails   = $true
    }

    if ($Major) { $releaseParams.Major = $true }
    if ($Minor) { $releaseParams.Minor = $true }
    if ($Patch) { $releaseParams.Patch = $true }

    $releaseDataResult = Update-PSScriptBuilderReleaseData @releaseParams
    $releaseDataResult | Format-PSScriptBuilderReleaseDataResult

    $bumpFilesResult = Update-PSScriptBuilderBumpFiles
    $bumpFilesResult | Format-PSScriptBuilderBumpResult
}

$usingCollector    = New-PSScriptBuilderCollector -Type Using    -IncludePath '.\src'
$enumCollector     = New-PSScriptBuilderCollector -Type Enum     -IncludePath '.\src\Enums'
$classCollector    = New-PSScriptBuilderCollector -Type Class    -IncludePath '.\src\Classes'
$functionCollector = New-PSScriptBuilderCollector -Type Function -IncludePath '.\src\Private', '.\src\Public'

$collectors = @($usingCollector, $enumCollector, $classCollector, $functionCollector)

$contentCollector = New-PSScriptBuilderContentCollector -Collector $collectors

$templatePath = '.\build\Templates\PSScriptBuilder.psm1.template'
$outputPath   = '.\build\Output\PSScriptBuilder.psm1'

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = $templatePath
    OutputPath       = $outputPath
}

Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult

if ($Release) {
    Write-Host ""
    Write-Host "Generating cmdlet documentation with PlatyPS..."

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Warning "PowerShell 7 (pwsh) is required for documentation generation but was not found."
        Write-Warning "Install PowerShell 7 from: https://aka.ms/powershell"
    }
    else {
        # Run PlatyPS under PowerShell 7 — PS5.1's Get-Help CBH parser truncates multi-line
        # .EXAMPLE code blocks to the first line only; PS7 parses them correctly.
        $null = New-Item -Path '.\docs\cmdlets' -ItemType Directory -Force
        pwsh -NoProfile -Command {
            if (-not (Get-Module -Name PlatyPS -ListAvailable)) {
                Write-Warning "PlatyPS is not installed. Run: Install-Module -Name PlatyPS -Scope CurrentUser"
            }
            else {
                Import-Module PlatyPS -Force
                Import-Module .\build\Output\PSScriptBuilder.psd1 -Force
                New-MarkdownHelp -Module PSScriptBuilder -OutputFolder '.\docs\cmdlets' -Force -ExcludeDontShow | Out-Null
            }
        }

        # Post-process generated markdown files for MkDocs (Python-Markdown) compatibility.
        Get-ChildItem '.\docs\cmdlets\*.md' | ForEach-Object {
            $content = Get-Content $_.FullName -Raw

            # Remove the ### -ProgressAction parameter section (up to the next ### or ##).
            # PS 7.4+ added -ProgressAction as a common parameter; PlatyPS picks it up but it
            # does not exist in PS 5.1 and must not appear in the published documentation.
            $content = $content -replace '(?m)^### -ProgressAction\r?\n[\s\S]*?(?=^### |^## )', ''

            # Remove -ProgressAction from the SYNTAX line.
            $content = $content -replace ' \[-ProgressAction <ActionPreference>\]', ''

            # Fix: Python-Markdown requires a blank line before list items that follow a
            # non-empty, non-list line. PlatyPS does not emit these blank lines.
            # Process line-by-line to safely skip content inside fenced code blocks.
            $lines = $content -split '\r?\n'
            $fixed = [System.Collections.Generic.List[string]]::new()
            $inCodeBlock = $false

            foreach ($line in $lines) {
                if ($line -match '^\s*```') { $inCodeBlock = -not $inCodeBlock }
                if (-not $inCodeBlock -and $line -match '^- ' -and $fixed.Count -gt 0) {
                    $prevLine = $fixed[$fixed.Count - 1]

                    if ($prevLine -ne '' -and $prevLine -notmatch '^- ') {
                        $fixed.Add('')
                    }
                }

                $fixed.Add($line)
            }

            $content = $fixed -join "`r`n"
            Set-Content $_.FullName $content -NoNewline
        }

        Write-Host "Cmdlet documentation generated: .\docs\cmdlets"
    }
}

$Global:VerbosePreference = $savedVerbosePreference
