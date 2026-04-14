# Release Management

PSScriptBuilder includes a built-in release management system for tracking and propagating
version numbers, build metadata, and Git context across all files in your project. It is built
around two JSON configuration files and a small set of cmdlets that work together to cover the
full release workflow — from bumping the version to updating manifests, templates, and
changelogs in a single step.

Release management is based on two JSON files:

| File | Purpose |
|---|---|
| `psscriptbuilder.releasedata.json` | The authoritative source of truth for the current version, build metadata, and Git context |
| `psscriptbuilder.bumpconfig.json` | Defines which project files get updated and how — via token replacement or regex patterns |

Both files are referenced in `psscriptbuilder.config.json`:

```json title="psscriptbuilder.config.json"
{
    "release": {
        "dataFile":       ".\\build\\Release\\psscriptbuilder.releasedata.json",
        "bumpConfigFile": ".\\build\\Release\\psscriptbuilder.bumpconfig.json"
    }
}
```

The workflow follows a simple three-step sequence on every release:

1. **Bump** — `Update-PSScriptBuilderReleaseData` increments the version and refreshes build and Git metadata in `psscriptbuilder.releasedata.json`
2. **Propagate** — `Update-PSScriptBuilderBumpFiles` reads the updated data and applies it to all configured project files
3. **Build** — `Invoke-PSScriptBuilderBuild` assembles the output script from the updated sources

---

## Walkthrough

### 1. Set Up the Release Data File

If no release data file exists yet, create one with default values (`0.1.0`, build number `1`):

```powershell title="Create the release data file"
New-PSScriptBuilderReleaseData
```

[`New-PSScriptBuilderReleaseData`](../cmdlets/New-PSScriptBuilderReleaseData.md) reads the
configured path from `psscriptbuilder.config.json` and writes a new file with default values.
Use `-Force` to overwrite an existing file (e.g. to reinitialise a project). Use `-WhatIf` to
preview what would be written without creating the file.

The resulting `psscriptbuilder.releasedata.json` contains three sections:

```json title="psscriptbuilder.releasedata.json"
{
    "version": {
        "major":         0,
        "minor":         1,
        "patch":         0,
        "prerelease":    null,
        "buildmetadata": null,
        "full":          "0.1.0"
    },
    "build": {
        "number":    0,
        "date":      "2026-03-24",
        "time":      "18:00:00",
        "timestamp": "2026-03-24T18:00:00Z",
        "year":      2026,
        "month":     3,
        "day":       24,
        "hour":      18,
        "minute":    0,
        "second":    0
    },
    "git": {
        "commit":      null,
        "commitShort": null,
        "branch":      null,
        "tag":         null
    }
}
```

The `version` section follows [Semantic Versioning](https://semver.org). The `build` section
is stamped with the current date and time when the file is created. The `git` section starts
empty and is populated by `-UpdateGitDetails` on the first bump.

### 2. Bump the Version

[`Update-PSScriptBuilderReleaseData`](../cmdlets/Update-PSScriptBuilderReleaseData.md) is the
central cmdlet for all version and metadata updates. It reads the current `psscriptbuilder.releasedata.json`,
applies the requested changes, and writes the updated values back.

```powershell title="Bump patch version (0.1.0 → 0.1.1)"
Update-PSScriptBuilderReleaseData -Patch
```

```powershell title="Bump minor version (0.1.1 → 0.2.0)"
Update-PSScriptBuilderReleaseData -Minor
```

```powershell title="Bump major version (0.2.0 → 1.0.0)"
Update-PSScriptBuilderReleaseData -Major
```

Version bump rules follow standard SemVer:

- `-Major` increments `major` and resets `minor` and `patch` to `0`
- `-Minor` increments `minor` and resets `patch` to `0`
- `-Patch` increments `patch` only

Only one bump switch may be used at a time.

To preview changes without writing them to disk, add `-WhatIf` and pipe the result to
[`Format-PSScriptBuilderReleaseDataResult`](../cmdlets/Format-PSScriptBuilderReleaseDataResult.md)
for a readable summary of what would change:

```powershell title="Preview changes"
Update-PSScriptBuilderReleaseData -Patch -WhatIf | Format-PSScriptBuilderReleaseDataResult
```

To apply the bump and display a summary of what changed, omit `-WhatIf`:

```powershell title="Bump and display a change summary"
Update-PSScriptBuilderReleaseData -Patch | Format-PSScriptBuilderReleaseDataResult
```

```title="Example output"
Category: Version

  Property  : patch
  Old Value : 0
  New Value : 1

  Property  : full
  Old Value : 0.1.0
  New Value : 0.1.1
```

!!! info "Automatic rollback on error"
    If an error occurs while writing `psscriptbuilder.releasedata.json`, `Update-PSScriptBuilderReleaseData`
    automatically restores the original file. The release data is never left in a partially
    updated state.

### 3. Update Build and Git Metadata

Version bumps can be combined with metadata updates in a single call. `-UpdateBuildDetails`
re-stamps the build timestamp and increments the build number. `-UpdateGitDetails` captures
the current Git state — branch, commit hash, and the latest tag. Both switches are independent
and can be used together or without a version bump:

```powershell title="Bump patch, update build details and Git context"
Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails -UpdateGitDetails
```

```powershell title="Refresh Git context only"
Update-PSScriptBuilderReleaseData -UpdateGitDetails
```

```powershell title="Re-stamp build timestamp only"
Update-PSScriptBuilderReleaseData -UpdateBuildDetails
```

`-UpdateGitDetails` requires `git` to be available in `PATH`. If the project is not inside a
Git repository or `git` is not found, the cmdlet throws an error.

### 4. Working with Prerelease and Build Metadata

SemVer supports optional prerelease identifiers (e.g. `1.0.0-rc.1`) and build metadata
(e.g. `1.0.0+build.5`). PSScriptBuilder exposes these as separate switches:

```powershell title="Add a prerelease identifier (0.1.1 → 0.1.2-rc.1)"
Update-PSScriptBuilderReleaseData -Patch -Prerelease "rc.1"
```

```powershell title="Remove prerelease (0.1.2-rc.1 → 0.1.2)"
Update-PSScriptBuilderReleaseData -ClearPrerelease
```

```powershell title="Set build metadata"
Update-PSScriptBuilderReleaseData -Patch -BuildMetadata "build.5"
```

```powershell title="Remove build metadata"
Update-PSScriptBuilderReleaseData -ClearBuildMetadata
```

Prerelease and build metadata identifiers follow the SemVer specification. The `version.full`
sub-property in `psscriptbuilder.releasedata.json` reflects all components: `1.0.0-rc.1+build.5`.

### 5. Read Release Data

Use [`Get-PSScriptBuilderReleaseData`](../cmdlets/Get-PSScriptBuilderReleaseData.md) to read
the current release data at any point — without modifying it. The default mode returns a
**hierarchical object** — ideal when you only need specific sections. For example, you can
access `$data.Build` or work exclusively with `$data.Git` without touching the rest:

```powershell title="Read hierarchical — access the build section"
$data = Get-PSScriptBuilderReleaseData
Write-Host "Timestamp: $($data.Build.Timestamp)"
Write-Host "Number:    $($data.Build.Number)"
Write-Host "Date:      $($data.Build.Date)"
```

```powershell title="Read hierarchical — access the Git section"
$data = Get-PSScriptBuilderReleaseData
Write-Host "Branch: $($data.Git.Branch)"
Write-Host "Commit: $($data.Git.Commit)"
Write-Host "Tag:    $($data.Git.Tag)"
```

Use `-Flat` when a single object with prefixed property names is more convenient — for
example in scripts that pass all token values to another function, or when you want to
enumerate all properties uniformly:

```powershell title="Read flat"
$flat = Get-PSScriptBuilderReleaseData -Flat
Write-Host "Version:   $($flat.VersionFull)"
Write-Host "Timestamp: $($flat.BuildTimestamp)"
Write-Host "Branch:    $($flat.GitBranch)"

# Enumerate all properties uniformly
$flat.PSObject.Properties | ForEach-Object { "$($_.Name) = $($_.Value)" }
```

### 6. Inspect Available Tokens

Release tokens are the values derived from `psscriptbuilder.releasedata.json` that can be injected into
project files. Use [`Get-PSScriptBuilderReleaseDataTokens`](../cmdlets/Get-PSScriptBuilderReleaseDataTokens.md)
to see all current token values in a single table:

```powershell title="List all available tokens"
Get-PSScriptBuilderReleaseDataTokens | Format-Table -AutoSize
```

This is useful to verify that the release data is correct before running
`Update-PSScriptBuilderBumpFiles`.

### 7. Configure Bump Files — Simple Token Mode

`psscriptbuilder.bumpconfig.json` defines which files get updated and how. The simplest mode
is **simple token replacement**: the file contains `{{TOKEN}}` placeholders, and the `tokens`
array lists which ones to replace. PSScriptBuilder substitutes each with the current value
from `psscriptbuilder.releasedata.json`:

```powershell title="File with token placeholders"
# MyModule.psm1
$moduleVersion = '{{VERSION}}'
$buildTimestamp = '{{BUILD_TIMESTAMP}}'
```

```json title="psscriptbuilder.bumpconfig.json — simple token mode"
{
    "bumpFiles": [
        {
            "description": "Module script — inject version and build timestamp",
            "path": "src\\MyModule.psm1",
            "tokens": ["VERSION", "BUILD_TIMESTAMP"]
        }
    ]
}
```

After running `Update-PSScriptBuilderBumpFiles`, the placeholders are replaced with the
actual values. As explained in the [Templates Guide](templates.md#5-combining-with-release-management-tokens),
this mode only works once — on subsequent bumps, the placeholders are gone and the regex mode
is needed.

### 8. Configure Bump Files — Regex Pattern Mode

**Regex pattern mode** uses regular expressions to target existing values in a file. This
works on any file format, requires no placeholder strings, and handles subsequent bumps
correctly. Each item in `items` defines a `pattern` (regex) and a `tokens` array. Use
`{REGEX_TOKEN}` as a named capture group inside the pattern — it matches the current value and
is replaced with the new one:

```json title="psscriptbuilder.bumpconfig.json — regex pattern mode"
{
    "bumpFiles": [
        {
            "description": "Module manifest — update version and build timestamp",
            "path": "build\\Output\\MyModule.psd1",
            "items": [
                {
                    "pattern": "ModuleVersion\\s*=\\s*'({REGEX_VERSION})'",
                    "tokens": ["VERSION"]
                },
                {
                    "pattern": "PrivateData.*BuildTimestamp\\s*=\\s*'({REGEX_BUILD_TIMESTAMP})'",
                    "tokens": ["BUILD_TIMESTAMP"]
                }
            ]
        }
    ]
}
```

The regex matches the surrounding context (e.g. `ModuleVersion = '...'`) but only the value
inside the parentheses `({REGEX_VERSION})` is replaced. Everything outside the capture group
is preserved as-is.

Multiple items can target the same file, and the same path can appear more than once in
`bumpFiles`. In both cases, all entries are applied sequentially to the same in-memory content
before writing — making multi-phase processing possible.

The following example shows how both modes can be combined in a single configuration:

```json title="psscriptbuilder.bumpconfig.json (real-world example)"
{
    "bumpFiles": [
        {
            "description": "PSScriptBuilder root module template - Auto token replacement",
            "path": "build\\Templates\\PSScriptBuilder.psm1.template",
            "tokens": ["VERSION", "VERSION_FULL", "BUILD_TIMESTAMP", "GIT_COMMIT_SHORT", "BUILD_DATE", "BUILD_TIME"]
        },
        {
            "description": "PSScriptBuilder root module template - Multi-phase bumping",
            "path": "build\\Templates\\PSScriptBuilder.psm1.template",
            "items": [
                {
                    "pattern": "Version\\s*=\\s*'({REGEX_VERSION_FULL})'",
                    "tokens": ["VERSION_FULL"]
                },
                {
                    "pattern": "BuildTimestamp\\s*=\\s*'({REGEX_BUILD_TIMESTAMP})'",
                    "tokens": ["BUILD_TIMESTAMP"]
                },
                {
                    "pattern": "GitCommit\\s*=\\s*'({REGEX_GIT_COMMIT_SHORT})'",
                    "tokens": ["GIT_COMMIT_SHORT"]
                }
            ]
        },
        {
            "description": "PSScriptBuilder Module Manifest (.psd1) - Multi-phase bumping",
            "path": "build\\Output\\PSScriptBuilder.psd1",
            "items": [
                {
                    "pattern": "{{VERSION}}",
                    "tokens": ["VERSION"]
                },
                {
                    "pattern": "ModuleVersion\\s*=\\s*'({REGEX_VERSION})'",
                    "tokens": ["VERSION"]
                }
            ]
        }
    ]
}
```

**Entry 1** — The module template contains `{{TOKEN}}` placeholders that are replaced on the
first release using simple token mode.

**Entry 2** — The same template file appears a second time using regex mode. After the first
bump, all `{{TOKEN}}` placeholders are gone. This entry targets the already-substituted values
and updates them on every subsequent release.

**Entry 3** — The module manifest is handled with two items: the first matches a `{{VERSION}}`
placeholder for freshly initialised manifests; the second uses a regex pattern for all
subsequent bumps. Having both ensures the file is updated correctly in either state. This
combination of Simple and Regex items in a single entry is referred to as **Mixed mode**.

### 9. Apply Tokens to Project Files

Once the release data has been updated and `bumpconfig.json` is configured, apply all tokens
to the configured project files in a single call:

```powershell title="Apply bump files"
Update-PSScriptBuilderBumpFiles
```

Preview all changes without writing them to disk:

```powershell title="Preview changes"
Update-PSScriptBuilderBumpFiles -WhatIf
```

Display a detailed change report showing what changed in each file:

```powershell title="Display a change report"
Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult
```

!!! info "Automatic backups before writing"
    Before writing any changes to disk, `Update-PSScriptBuilderBumpFiles` creates a backup
    of each target file. If an error occurs during processing, the originals are restored
    from their backups, leaving all project files in a consistent state.

### 10. Validate Configuration

Always validate both files before running updates — especially in automated scripts where a
silent failure could leave the project in an inconsistent state:

```powershell title="Validate before updating"
if (-not (Test-PSScriptBuilderReleaseData)) {
    Write-Error "Release data is invalid — fix it before bumping"
    return
}

if (-not (Test-PSScriptBuilderBumpConfiguration)) {
    Write-Error "Bump configuration is invalid — fix it before running Update-PSScriptBuilderBumpFiles"
    return
}
```

[`Test-PSScriptBuilderReleaseData`](../cmdlets/Test-PSScriptBuilderReleaseData.md) validates
the structure and values of `psscriptbuilder.releasedata.json` (e.g. that all required fields exist and the
version components are valid integers).
[`Test-PSScriptBuilderBumpConfiguration`](../cmdlets/Test-PSScriptBuilderBumpConfiguration.md)
validates the structure of `bumpconfig.json` and checks that all referenced files exist.

Both cmdlets return `$true` on success and write detailed error messages on failure. Add
`-Verbose` for additional validation detail.

### 11. Full Release Workflow

A complete release script that combines all steps:

```powershell title="release.ps1"
# 1. Validate
if (-not (Test-PSScriptBuilderReleaseData))      { return }
if (-not (Test-PSScriptBuilderBumpConfiguration)) { return }

# 2. Bump version, refresh build and Git metadata
Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails -UpdateGitDetails |
    Format-PSScriptBuilderReleaseDataResult

# 3. Apply tokens to all configured project files
Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult

# 4. Build the output script
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath '.\src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath '.\src\Public'

Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath '.\build\Templates\MyModule.psm1.template' `
    -OutputPath   '.\build\Output\MyModule.psm1'
```

The order matters: bump first, then propagate, then build. If the build template is
configured as a bump file (see the [Templates Guide](templates.md#5-combining-with-release-management-tokens)),
the version tokens in the template must be updated before `Invoke-PSScriptBuilderBuild` runs.

---

## Reference

### Version Bump Switches

| Switch | Effect |
|---|---|
| `-Major` | Increments `major`, resets `minor` and `patch` to `0` |
| `-Minor` | Increments `minor`, resets `patch` to `0` |
| `-Patch` | Increments `patch` |
| `-Version "1.0.0"` | Sets an explicit version; cannot be combined with `-Major`, `-Minor`, or `-Patch` |
| `-Prerelease "alpha.1"` | Sets the prerelease identifier |
| `-ClearPrerelease` | Removes the prerelease identifier |
| `-BuildMetadata "build.5"` | Sets build metadata (not auto-updated) |
| `-ClearBuildMetadata` | Removes build metadata |

`-Major`, `-Minor`, `-Patch`, and `-Version` are mutually exclusive — only one may be used per call. At least one parameter must be specified overall; `-UpdateBuildDetails` and `-UpdateGitDetails` can be used standalone without a version change, or combined with any version parameter.

### Metadata Switches

| Switch | What it updates |
|---|---|
| `-UpdateBuildDetails` | `build.date`, `build.time`, `build.timestamp`, all time components, `build.number` (+1) |
| `-UpdateGitDetails` | `git.commit`, `git.commitShort`, `git.branch`, `git.tag` — requires `git` in PATH |

### Version Tokens

| Token | Example value | Description |
|---|---|---|
| `VERSION` | `1.2.0` | `major.minor.patch` |
| `VERSION_FULL` | `1.2.0-rc.1+build.5` | Full SemVer including prerelease and metadata |
| `VERSION_MAJOR` | `1` | Major number only |
| `VERSION_MINOR` | `2` | Minor number only |
| `VERSION_PATCH` | `0` | Patch number only |
| `VERSION_PRERELEASE` | `rc.1` | Prerelease identifier, or empty |
| `VERSION_BUILDMETADATA` | `build.5` | Build metadata, or empty |

### Build Tokens

| Token | Example value | Description |
|---|---|---|
| `BUILD_NUMBER` | `42` | Incrementing build counter |
| `BUILD_DATE` | `2026-03-24` | Date in `yyyy-MM-dd` format |
| `BUILD_TIME` | `18:00:00` | Time in `HH:mm:ss` format |
| `BUILD_TIMESTAMP` | `2026-03-24T18:00:00Z` | ISO 8601 combined timestamp |
| `BUILD_YEAR` | `2026` | Year component |
| `BUILD_MONTH` | `3` | Month component |
| `BUILD_DAY` | `24` | Day component |
| `BUILD_HOUR` | `18` | Hour component |
| `BUILD_MINUTE` | `0` | Minute component |
| `BUILD_SECOND` | `0` | Second component |

### Git Tokens

| Token | Example value | Description |
|---|---|---|
| `GIT_COMMIT` | `2a98ae58cc96e12c78614ec28ed044996ee86d43` | Full 40-character SHA1 hash |
| `GIT_COMMIT_SHORT` | `2a98ae5` | Short hash (7–40 characters) |
| `GIT_BRANCH` | `main` | Current branch name |
| `GIT_TAG` | `v1.2.0` | Latest tag, or empty if none |

### Regex Token Placeholders

Use these inside `pattern` values in `bumpconfig.json` to match the current value of a token:

| Regex placeholder | Matches |
|---|---|
| `{REGEX_VERSION}` | `major.minor.patch` (e.g. `1.2.0`) |
| `{REGEX_VERSION_FULL}` | Full SemVer including optional prerelease and metadata |
| `{REGEX_VERSION_MAJOR}` | Major version number (one or more digits) |
| `{REGEX_VERSION_MINOR}` | Minor version number (one or more digits) |
| `{REGEX_VERSION_PATCH}` | Patch version number (one or more digits) |
| `{REGEX_VERSION_PRERELEASE}` | Prerelease identifier (e.g. `rc.1`, `alpha`) |
| `{REGEX_VERSION_BUILDMETADATA}` | Build metadata (e.g. `build.5`) |
| `{REGEX_BUILD_NUMBER}` | One or more digits |
| `{REGEX_BUILD_DATE}` | `yyyy-MM-dd` |
| `{REGEX_BUILD_TIME}` | `HH:mm:ss` |
| `{REGEX_BUILD_TIMESTAMP}` | ISO 8601 timestamp |
| `{REGEX_BUILD_YEAR}` | Four-digit year (e.g. `2026`) |
| `{REGEX_BUILD_MONTH}` | Zero-padded month (e.g. `03`) |
| `{REGEX_BUILD_DAY}` | Zero-padded day (e.g. `24`) |
| `{REGEX_BUILD_HOUR}` | Zero-padded hour (e.g. `18`) |
| `{REGEX_BUILD_MINUTE}` | Zero-padded minute (e.g. `00`) |
| `{REGEX_BUILD_SECOND}` | Zero-padded second (e.g. `00`) |
| `{REGEX_GIT_COMMIT}` | 40-character hex string |
| `{REGEX_GIT_COMMIT_SHORT}` | 7–40 character hex string |
| `{REGEX_GIT_BRANCH}` | Branch name (alphanumeric, `-`, `_`, `/`) |
| `{REGEX_GIT_TAG}` | Tag name, or empty string |

---

## Tips

!!! tip "Combine bump and format in one expression"
    Piping `Update-PSScriptBuilderReleaseData` directly to `Format-PSScriptBuilderReleaseDataResult`
    gives an instant summary of what changed. This keeps release scripts readable and
    confirms that the right values were updated.

!!! tip "Use -WhatIf before the first release"
    Both `Update-PSScriptBuilderReleaseData` and `Update-PSScriptBuilderBumpFiles` support
    `-WhatIf`. Run both with `-WhatIf` on a new project to verify that the configuration
    is correct before making any changes.

!!! tip "Use Get-PSScriptBuilderReleaseDataTokens to verify values"
    Before running `Update-PSScriptBuilderBumpFiles`, call
    `Get-PSScriptBuilderReleaseDataTokens | Format-Table -AutoSize` to confirm that all
    token values match what you expect. This catches a stale bump or a missing Git update
    before it propagates to project files.

!!! warning "Bump before build when the template is a bump file"
    If your build template contains release token placeholders, `Update-PSScriptBuilderBumpFiles`
    must run before `Invoke-PSScriptBuilderBuild`. Otherwise, the build validator will
    report unknown placeholders and fail.

!!! info "Git details require git in PATH"
    `-UpdateGitDetails` calls `git` directly. If `git` is not available or the project is
    not inside a Git repository, the cmdlet throws. In non-Git environments, omit
    `-UpdateGitDetails` and manage the `git` section manually.

---

## See Also

- [Cmdlet Reference: Update-PSScriptBuilderReleaseData](../cmdlets/Update-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Update-PSScriptBuilderBumpFiles](../cmdlets/Update-PSScriptBuilderBumpFiles.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseData](../cmdlets/Get-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseDataTokens](../cmdlets/Get-PSScriptBuilderReleaseDataTokens.md)
- [Templates Guide](templates.md) — combining release tokens with build templates
