# Setting Up Release Management

This tutorial walks you through setting up PSScriptBuilder's release management system. You
will create a release data file, configure which files receive automatic version updates,
and add a release step to your build script. By the end, running a single command will bump
the version, update all registered files, and produce a correctly versioned build output.

**Prerequisites:**

- A working PSScriptBuilder project — see [Building Your First Project](building-your-first-project.md)

---

## 1. Create the Release Data File

The release data file (`psscriptbuilder.releasedata.json`) is the central store for your
project's current version and release metadata — build timestamp, Git commit hash, branch
name, and more. All other release management steps read from and write to this file.

Create it by running:

```powershell
New-PSScriptBuilderReleaseData
```

This creates `psscriptbuilder.releasedata.json` in your project root with an initial version
of `0.1.0`. Open the file to verify it was created and adjust the starting version if needed.

!!! tip
    If your project already has an established version, edit `psscriptbuilder.releasedata.json`
    and set the `"major"`, `"minor"`, `"patch"`, and `"full"` fields under `"version"` to match
    your current version before continuing.

---

## 2. Create the Bump Configuration

The bump configuration file (`psscriptbuilder.bumpconfig.json`) tells PSScriptBuilder which
files to update when a new version is released. You register each file once — PSScriptBuilder
handles all subsequent updates automatically.

Create `psscriptbuilder.bumpconfig.json` in your project root:

```json title="psscriptbuilder.bumpconfig.json"
{
    "bumpFiles": []
}
```

For each file that should receive version updates, add an entry to the `bumpFiles` array.
There are two ways to configure an entry, depending on the file format.

### Using `tokens` — for files you author yourself

If you write the file yourself (such as a template), place `{{TOKEN_NAME}}` placeholders
directly in the content. PSScriptBuilder injects the current values on the first release —
**this works only once**. After the first bump, the placeholders are replaced with real values
and no longer exist in the file. To keep the file in sync across subsequent releases, combine
this entry with an `items` entry on the same file — as described in the next section.

```json title="psscriptbuilder.bumpconfig.json"
{
    "bumpFiles": [
        {
            "description": "Output template — inject version and build metadata",
            "path": "build\\Templates\\HRTools.ps1.template",
            "tokens": ["VERSION", "BUILD_DATE", "GIT_COMMIT_SHORT"]
        }
    ]
}
```

The corresponding template file would contain lines like:

```powershell title="HRTools.ps1.template"
# Version: {{VERSION}} — Built: {{BUILD_DATE}} ({{GIT_COMMIT_SHORT}})
```

### Using `items` — for files with a fixed format

If the file format is fixed and you cannot add placeholders — such as a `.psd1` generated
by `New-ModuleManifest` — use `items` with a regex pattern. The pattern finds the existing
value and replaces only the version number, leaving the surrounding syntax intact:

```json title="psscriptbuilder.bumpconfig.json"
{
    "bumpFiles": [
        {
            "description": "Module manifest — update version",
            "path": "build\\Output\\MyProject.psd1",
            "items": [
                {
                    "pattern": "ModuleVersion\\s*=\\s*'({REGEX_VERSION})'",
                    "tokens": ["VERSION"]
                }
            ]
        }
    ]
}
```

The `{REGEX_VERSION}` placeholder expands to the built-in regex pattern for a semantic
version string (`\d+\.\d+\.\d+`). PSScriptBuilder matches the surrounding context
(`ModuleVersion = '...'`) and replaces only the captured version value.

!!! note "Available tokens"
    PSScriptBuilder provides tokens for version components, build metadata, and Git details.
    To see all available tokens, run `Get-PSScriptBuilderReleaseDataTokens`.
    For the full token list with descriptions, see the [Release Management Guide](../guides/release-management.md).

---

## 3. Add Release Logic to the Build Script

Open your build script and add a `-Release` switch with the three version bump options.
The release logic runs only when `-Release` is passed — a normal development build skips it
entirely, so everyday runs remain fast and have no side-effects:

```powershell title="Build-HRTools.ps1"
using module PSScriptBuilder

[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [switch] $Release,
    [Parameter(ParameterSetName = 'Major')] [switch] $Major,
    [Parameter(ParameterSetName = 'Minor')] [switch] $Minor,
    [Parameter(ParameterSetName = 'Patch')] [switch] $Patch
)

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$config = Get-PSScriptBuilderConfiguration

if ($Release) {
    $releaseParams = @{
        UpdateBuildDetails = $true
        UpdateGitDetails   = $true
    }

    switch ($PSCmdlet.ParameterSetName) {
        'Major' { $releaseParams.Major = $true }
        'Minor' { $releaseParams.Minor = $true }
        'Patch' { $releaseParams.Patch = $true }
    }

    Update-PSScriptBuilderReleaseData @releaseParams | Format-PSScriptBuilderReleaseDataResult
    Update-PSScriptBuilderBumpFiles                  | Format-PSScriptBuilderBumpResult
}

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = Join-Path $config.Build.TemplatePath 'HRTools.ps1.template'
    OutputPath       = Join-Path $config.Build.OutputPath   'HRTools.ps1'
}

Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult
```

What each release step does:

- `Update-PSScriptBuilderReleaseData` — bumps the version in `psscriptbuilder.releasedata.json`
  and optionally records the current build timestamp (`-UpdateBuildDetails`) and Git state
  (`-UpdateGitDetails`)
- `Update-PSScriptBuilderBumpFiles` — reads the updated release data and applies all
  registered replacements across every file in `psscriptbuilder.bumpconfig.json`

The order matters: release data is updated first, then bump files are processed, then the
build runs. This ensures every registered file already has the new version before the output
is written. If the build runs before `Update-PSScriptBuilderBumpFiles` has replaced the
placeholders, release management tokens such as `{{VERSION}}` will still be present in the
template. The build validates that all `{{...}}` patterns are expected — and since it only
recognizes the placeholders it manages itself, any remaining release management placeholder
will cause a validation error.

---

## 4. Run a Release Build

For a patch release:

```powershell
.\Build-HRTools.ps1 -Release -Patch
```

Use `-Minor` for new features and `-Major` for breaking changes.

You will see three blocks of output:

1. **Release data result** — the new version and the metadata that was recorded
2. **Bump files result** — every registered file, with each replacement listed
3. **Build result** — the output path, file size, build time, and component counts

To preview what would change without writing anything to disk, run the release cmdlets
interactively with `-WhatIf`:

```powershell
Update-PSScriptBuilderReleaseData -Patch -WhatIf | Format-PSScriptBuilderReleaseDataResult
Update-PSScriptBuilderBumpFiles -WhatIf
```

After a successful release build, open `psscriptbuilder.releasedata.json` and one of the
registered files to confirm the version was updated correctly before tagging and distributing.

Your release management setup is complete. From here, a single command bumps the version,
updates all registered files, and produces a correctly versioned build output.

---

## See Also

- [Release Management Guide](../guides/release-management.md) — full token reference and advanced configuration
- [CI/CD Integration Guide](../guides/cicd-integration.md) — automating builds and publishing
