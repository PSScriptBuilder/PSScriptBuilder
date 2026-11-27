using namespace System.IO
using namespace System.Text

<#
.SYNOPSIS
    Extracts release notes for a specific version from CHANGELOG.md.
.DESCRIPTION
    Reads CHANGELOG.md and extracts the content of the section matching the
    specified version tag. The extracted notes are written to release_notes.md
    in the repository root. If no matching section is found, a fallback message
    linking to the PowerShell Gallery is written instead.
.PARAMETER Tag
    The Git tag name, e.g. 'v1.0.0'. The version is extracted by stripping the leading 'v'.
.EXAMPLE
    .\extract-release-notes.ps1 -Tag 'v1.0.0'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Tag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot      = Split-Path $PSScriptRoot -Parent
$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
$outputPath    = Join-Path $repoRoot 'release_notes.md'

$version = $Tag.TrimStart('v')

#region Prerequisites
Write-Host "Checking prerequisites..."

if (-not (Test-Path $changelogPath -PathType Leaf)) {
    throw [InvalidOperationException]::new("CHANGELOG.md not found: $changelogPath")
}
Write-Host "  CHANGELOG.md found."

Write-Host "All prerequisites met."
#endregion Prerequisites

#region Extract
Write-Host "Extracting release notes for version $version..."

$changelogText  = [File]::ReadAllText($changelogPath, [UTF8Encoding]::new($true))
$escapedVersion = [regex]::Escape($version)
$pattern        = '(?ms)^## \[' + $escapedVersion + '\][^\n]*\n(.*?)(?=^## \[|\z)'
$match          = [regex]::Match($changelogText, $pattern)

if (-not $match.Success -or [string]::IsNullOrWhiteSpace($match.Groups[1].Value)) {
    Write-Host "  No release notes found for version $version. Using fallback."
    $content = "See the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSScriptBuilder/$version) for details."
}
else {
    $content = $match.Groups[1].Value.Trim()
    Write-Host "  Release notes extracted."
}

$content = $content + [Environment]::NewLine

[File]::WriteAllText($outputPath, $content, [UTF8Encoding]::new($true))

Write-Host "Release notes written to: $outputPath"
#endregion Extract
