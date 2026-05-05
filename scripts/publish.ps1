<#
.SYNOPSIS
    Publishes PSScriptBuilder to the PowerShell Gallery or a local test repository.
.DESCRIPTION
    Validates all prerequisites, copies README, LICENSE, and CHANGELOG to the output directory,
    and publishes the module. Without -PSGallery, a local test publish is performed
    and the installation is verified. With -PSGallery, the module is published to
    PSGallery using Publish-PSResource. Cleans up afterwards.
.PARAMETER PSGallery
    When specified, publishes to the PowerShell Gallery. Requires the PSGALLERY_API_KEY
    environment variable to be set. Without this switch, a local test publish is performed.
.EXAMPLE
    .\publish.ps1
.EXAMPLE
    .\publish.ps1 -PSGallery
#>
[CmdletBinding()]
param(
    [switch] $PSGallery
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot        = Split-Path $PSScriptRoot -Parent
$outputPath      = Join-Path $repoRoot   'build\Output'
$psd1Path        = Join-Path $outputPath 'PSScriptBuilder.psd1'
$psm1Path        = Join-Path $outputPath 'PSScriptBuilder.psm1'
$readmeSource    = Join-Path $repoRoot   'README.md'
$readmeTarget    = Join-Path $outputPath 'README.md'
$licenseSource   = Join-Path $repoRoot   'LICENSE'
$licenseTarget   = Join-Path $outputPath 'LICENSE'
$changelogPath   = Join-Path $repoRoot   'CHANGELOG.md'
$changelogTarget = Join-Path $outputPath 'CHANGELOG.md'
$localRepoPath   = Join-Path $repoRoot   'build\LocalFeed'
$localRepoName   = 'PSScriptBuilderLocalFeed'

#region Prerequisites
Write-Host "Checking prerequisites..."

# 1. Output directory
if (-not (Test-Path $outputPath -PathType Container)) {
    throw [InvalidOperationException]::new("Output directory not found: $outputPath")
}

Write-Host "  Output directory found."

# 2. .psd1
if (-not (Test-Path $psd1Path -PathType Leaf)) {
    throw [InvalidOperationException]::new("Module manifest not found: $psd1Path")
}

Write-Host "  Module manifest found."

# 3. .psm1
if (-not (Test-Path $psm1Path -PathType Leaf)) {
    throw [InvalidOperationException]::new("Module file not found: $psm1Path")
}

Write-Host "  Module file found."

# 4. README
if (-not (Test-Path $readmeSource -PathType Leaf)) {
    throw [InvalidOperationException]::new("README.md not found: $readmeSource")
}

Write-Host "  README.md found."

# 5. LICENSE
if (-not (Test-Path $licenseSource -PathType Leaf)) {
    throw [InvalidOperationException]::new("LICENSE not found: $licenseSource")
}

Write-Host "  LICENSE found."

# 6. CHANGELOG
if (-not (Test-Path $changelogPath -PathType Leaf)) {
    throw [InvalidOperationException]::new("CHANGELOG.md not found: $changelogPath")
}

Write-Host "  CHANGELOG.md found."

# 7. Syntax check on .psm1
Write-Host "Validating module syntax..."

$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile($psm1Path, [ref] $tokens, [ref] $errors) | Out-Null

if ($errors.Count -gt 0) {
    $message = "Syntax errors found in {0}:`n{1}" -f $psm1Path, ($errors | Out-String)
    throw [InvalidOperationException]::new($message)
}

Write-Host "  Syntax OK."

# 8. Version consistency: .psd1 vs. CHANGELOG.md
Write-Host "Checking version consistency..."

$manifest = Import-PowerShellDataFile -Path $psd1Path
$psd1Version = $manifest.ModuleVersion
$changelogContent = Get-Content $changelogPath -Raw

if ($changelogContent -notmatch [regex]::Escape("## [$psd1Version]")) {
    $message = "Version '{0}' from PSScriptBuilder.psd1 not found in CHANGELOG.md." -f $psd1Version
    throw [InvalidOperationException]::new($message)
}

Write-Host "  Version $psd1Version matches CHANGELOG.md."

# 9. PSResourceGet available and imported
Write-Host "Preparing Microsoft.PowerShell.PSResourceGet..."

if (-not (Get-Module -Name Microsoft.PowerShell.PSResourceGet -ListAvailable)) {
    Write-Host "  Installing Microsoft.PowerShell.PSResourceGet..."
    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force
}

Import-Module -Name Microsoft.PowerShell.PSResourceGet

if (-not (Get-Module -Name Microsoft.PowerShell.PSResourceGet)) {
    throw [InvalidOperationException]::new("Failed to import module: Microsoft.PowerShell.PSResourceGet")
}

Write-Host "  Microsoft.PowerShell.PSResourceGet imported."

# Ensure PSGallery repository is registered (required on Linux runners)
if (-not (Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Write-Host "  Registering PSGallery repository..."
    Register-PSResourceRepository -PSGallery -Trusted
}

Write-Host "  PSGallery repository ready."

if ($PSGallery) {
    # 10. API key
    $apiKey = $env:PSGALLERY_API_KEY

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw [InvalidOperationException]::new("PSGALLERY_API_KEY environment variable is not set or empty.")
    }

    Write-Host "  API key found."

    # 11. Version not already published on PSGallery
    Write-Host "Checking PSGallery for existing version..."
    $existing = Find-Module -Name PSScriptBuilder -RequiredVersion $psd1Version -Repository PSGallery -ErrorAction SilentlyContinue

    if ($null -ne $existing) {
        $message = "Version '{0}' is already published on PSGallery." -f $psd1Version
        throw [InvalidOperationException]::new($message)
    }

    Write-Host "  Version $psd1Version is not yet published."
}

Write-Host "All prerequisites met."
#endregion Prerequisites

#region Publish
try {
    # Copy README
    Write-Host "Copying README.md to output..."
    Copy-Item -Path $readmeSource -Destination $readmeTarget -Force

    if (-not (Test-Path $readmeTarget -PathType Leaf)) {
        throw [InvalidOperationException]::new("Failed to copy README.md to output directory: $readmeTarget")
    }

    # Copy LICENSE
    Write-Host "Copying LICENSE to output..."
    Copy-Item -Path $licenseSource -Destination $licenseTarget -Force

    if (-not (Test-Path $licenseTarget -PathType Leaf)) {
        throw [InvalidOperationException]::new("Failed to copy LICENSE to output directory: $licenseTarget")
    }

    # Copy CHANGELOG
    Write-Host "Copying CHANGELOG.md to output..."
    Copy-Item -Path $changelogPath -Destination $changelogTarget -Force

    if (-not (Test-Path $changelogTarget -PathType Leaf)) {
        throw [InvalidOperationException]::new("Failed to copy CHANGELOG.md to output directory: $changelogTarget")
    }

    try {
        if ($PSGallery) {
            # Publish to PSGallery
            Write-Host "Publishing PSScriptBuilder $psd1Version to PSGallery..."
            Publish-PSResource -Path $outputPath -ApiKey $apiKey -Repository PSGallery
            Write-Host "Publish complete."
        }
        else {
            # Local test publish
            Write-Host "Setting up local test repository..."
            New-Item -ItemType Directory -Path $localRepoPath -Force | Out-Null
            Register-PSResourceRepository -Name $localRepoName -Uri $localRepoPath -Trusted

            Write-Host "Publishing PSScriptBuilder $psd1Version to local test repository..."
            Publish-PSResource -Path $outputPath -ApiKey 'dummy' -Repository $localRepoName

            Write-Host "Testing installation from local test repository..."
            Install-PSResource -Name PSScriptBuilder -Repository $localRepoName -Reinstall

            if (-not (Get-PSResource -Name PSScriptBuilder -ErrorAction SilentlyContinue)) {
                throw [InvalidOperationException]::new("PSScriptBuilder could not be installed from local test repository.")
            }

            Write-Host "  PSScriptBuilder installed successfully."
            Write-Host "Local test publish complete."
        }
    }
    catch {
        $message = "Publish failed: {0}" -f $_.Exception.Message
        throw [Exception]::new($message, $_.Exception)
    }
}
finally {
    # Cleanup: remove copied README from output
    if (Test-Path $readmeTarget) {
        Remove-Item -Path $readmeTarget -Force
        Write-Host "Cleaned up README.md from output."
    }

    # Cleanup: remove copied LICENSE from output
    if (Test-Path $licenseTarget) {
        Remove-Item -Path $licenseTarget -Force
        Write-Host "Cleaned up LICENSE from output."
    }

    # Cleanup: remove copied CHANGELOG from output
    if (Test-Path $changelogTarget) {
        Remove-Item -Path $changelogTarget -Force
        Write-Host "Cleaned up CHANGELOG.md from output."
    }

    # Cleanup: remove local test repository
    if (-not $PSGallery) {
        Unregister-PSResourceRepository -Name $localRepoName -ErrorAction SilentlyContinue

        if (Test-Path $localRepoPath) {
            try {
                Remove-Item -Path $localRepoPath -Recurse -Force
                Write-Host "Cleaned up local feed."
            }
            catch {
                Write-Host "Warning: Could not clean up local feed: $($_.Exception.Message)"
            }
        }
    }
}
#endregion Publish
