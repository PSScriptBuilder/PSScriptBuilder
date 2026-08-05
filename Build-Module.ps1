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
.PARAMETER Docs
    Generates cmdlet documentation with PlatyPS after the build. Only valid in Dev mode.
    Use this to regenerate documentation without updating version metadata or running release
    steps. In Release mode, documentation is always generated automatically.
.PARAMETER ExportBuildResult
    Exports the build result to a JSON file at .\build\PSScriptBuilder.buildresult.json.
    Available in all parameter sets. Useful for CI/CD artifact collection.
.EXAMPLE
    .\Build-Module.ps1
    Development build — only compiles the module, no version changes.
.EXAMPLE
    .\Build-Module.ps1 -Docs
    Development build with documentation generation — compiles the module and regenerates
    all cmdlet markdown files via PlatyPS.
.EXAMPLE
    .\Build-Module.ps1 -ExportBuildResult
    Development build with build result export — compiles the module and writes the build
    result to .\build\PSScriptBuilder.buildresult.json.
.EXAMPLE
    .\Build-Module.ps1 -Release -Patch
    Release build — bumps patch version, updates build and Git metadata, applies version to
    configured files, builds the module, and generates cmdlet documentation.
.EXAMPLE
    .\Build-Module.ps1 -Release -Patch -ExportBuildResult
    Release build with build result export — bumps patch version, builds the module,
    generates cmdlet documentation, and writes the build result to a JSON file.
#>
[CmdletBinding(DefaultParameterSetName = 'Dev')]
param(
    [Parameter(ParameterSetName = 'Release')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Major')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Minor')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Patch')]
    [switch] $Release,

    [Parameter(Mandatory = $true, ParameterSetName = 'Major')]
    [switch] $Major,

    [Parameter(Mandatory = $true, ParameterSetName = 'Minor')]
    [switch] $Minor,

    [Parameter(Mandatory = $true, ParameterSetName = 'Patch')]
    [switch] $Patch,

    [Parameter(ParameterSetName = 'Dev')]
    [switch] $Docs,

    [switch] $ExportBuildResult
)

$ConfigPath       = '.\psscriptbuilder.config.json'
$ManifestPath     = '.\build\Output\PSScriptBuilder.psd1'
$TemplatePath     = '.\build\Templates\PSScriptBuilder.psm1.template'
$OutputPath       = '.\build\Output\PSScriptBuilder.psm1'
$BuildResultPath  = '.\build\PSScriptBuilder.buildresult.json'
$SourceDir        = '.\src'
$SourceEnumsDir   = '.\src\Enums'
$SourceClassesDir = '.\src\Classes'
$SourcePrivateDir = '.\src\Private'
$SourcePublicDir  = '.\src\Public'
$HelpSourceDir    = '.\en-US'
$HelpFile         = '.\en-US\about_PSScriptBuilder.help.txt'
$HelpOutputDir    = '.\build\Output\en-US'
$DocsOutputDir    = '.\docs\cmdlets'

function Invoke-ReleaseSteps {
    $releaseParams = @{
        UpdateBuildDetails = $true
        UpdateGitDetails   = $true
    }

    if     ($Major) { $releaseParams.Major = $true }
    elseif ($Minor) { $releaseParams.Minor = $true }
    elseif ($Patch) { $releaseParams.Patch = $true }

    $releaseDataResult = Update-PSScriptBuilderReleaseData @releaseParams
    $releaseDataResult | Format-PSScriptBuilderReleaseDataResult

    $bumpFilesResult = Update-PSScriptBuilderBumpFiles
    $bumpFilesResult | Format-PSScriptBuilderBumpResult
}

function Invoke-ModuleBuild {
    $usingCollector    = New-PSScriptBuilderCollector -Type Using    -IncludePath $SourceDir
    $enumCollector     = New-PSScriptBuilderCollector -Type Enum     -IncludePath $SourceEnumsDir
    $classCollector    = New-PSScriptBuilderCollector -Type Class    -IncludePath $SourceClassesDir
    $functionCollector = New-PSScriptBuilderCollector -Type Function -IncludePath $SourcePrivateDir, $SourcePublicDir

    $collectors = @($usingCollector, $enumCollector, $classCollector, $functionCollector)

    $contentCollector = New-PSScriptBuilderContentCollector -Collector $collectors

    $buildParams = @{
        ContentCollector = $contentCollector
        TemplatePath     = $TemplatePath
        OutputPath       = $OutputPath
    }

    return Invoke-PSScriptBuilderBuild @buildParams
}

function Sync-ModuleExports {
    $functionNames = Get-ChildItem -Path $SourcePublicDir -Filter '*.ps1' -Recurse |
        ForEach-Object {
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($_.FullName)
            [PSScriptBuilderAstEngine]::FindFunctionDefinitions($parseResult.Ast) |
                ForEach-Object { $_.Name }
        } |
        Sort-Object

    $newLine     = [Environment]::NewLine
    $exportLines = $functionNames | ForEach-Object { "    `"$_`"" }
    $exportBlock = "FunctionsToExport = @($newLine" + ($exportLines -join ",$newLine") + "$newLine)"

    $content = Get-Content -Path $ManifestPath -Raw
    $content = $content -replace '(?s)FunctionsToExport\s*=\s*@\(.*?\)', $exportBlock

    [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithoutBOM(
        (Resolve-Path $ManifestPath).ProviderPath, $content
    )

    Write-Host "Module exports synchronized: $($functionNames.Count) function(s)"
}

function Copy-HelpFiles {
    if (-not (Test-Path -Path $HelpSourceDir)) {
        $format  = "Help files source directory not found: {0}"
        $message = $format -f $HelpSourceDir
        throw [System.IO.DirectoryNotFoundException]::new($message)
    }

    if (-not (Test-Path -Path $HelpFile)) {
        $format  = "Help file not found: {0}"
        $message = $format -f $HelpFile
        throw [System.IO.FileNotFoundException]::new($message, $HelpFile)
    }

    if (-not (Test-Path -Path $HelpOutputDir)) {
        New-Item -Path $HelpOutputDir -ItemType Directory | Out-Null
    }

    Copy-Item -Path "$HelpSourceDir\*" -Destination $HelpOutputDir -Recurse -Force
}

function Invoke-DocumentationGeneration {
    Write-Host ""
    Write-Host "Generating cmdlet documentation with PlatyPS..."

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Warning "PowerShell 7 (pwsh) is required for documentation generation but was not found."
        Write-Warning "Install PowerShell 7 from: https://aka.ms/powershell"
        return
    }

    # Run PlatyPS under PowerShell 7 — PS5.1's Get-Help CBH parser truncates multi-line
    # .EXAMPLE code blocks to the first line only; PS7 parses them correctly.
    $null = New-Item -Path $DocsOutputDir -ItemType Directory -Force
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
    Get-ChildItem "$DocsOutputDir\*.md" | ForEach-Object {
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

    Write-Host "Cmdlet documentation generated: $DocsOutputDir"
}

$savedVerbosePreference = $Global:VerbosePreference
if ($VerbosePreference -eq 'Continue') {
    $Global:VerbosePreference = 'Continue'
}

if ($Global:PSScriptBuilderBuildExecuted) {
    Write-Warning "Build-Module.ps1 has already been executed in this session. Start a new PowerShell session to run it again."
    return
}

$Global:PSScriptBuilderBuildExecuted = $true

if (-not (Test-Path -Path $ConfigPath)) {
    New-PSScriptBuilderConfiguration
}

Set-PSScriptBuilderProjectRoot -Path '.'

if ($Release) { Invoke-ReleaseSteps }

$buildResult = Invoke-ModuleBuild
$buildResult | Format-PSScriptBuilderBuildResult

if ($ExportBuildResult) {
    $exportedPath = $buildResult | Export-PSScriptBuilderBuildResult -Path $BuildResultPath -Detailed -Force
    Write-Host "Build result exported: $exportedPath"
}

Sync-ModuleExports
Copy-HelpFiles

if ($Release -or $Docs) { Invoke-DocumentationGeneration }

$Global:VerbosePreference = $savedVerbosePreference
