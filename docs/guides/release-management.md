# Release Management

PSScriptBuilder includes a built-in release management system for tracking and propagating
version numbers, build metadata, and Git context across all files in your project. It is built
around two configuration files and a small set of cmdlets that work together to cover the full
release workflow — from bumping the version to updating manifests, templates, and changelogs in
a single step.

The workflow follows the same three-phase sequence on every release: bump the version and
refresh metadata, propagate the updated values to your project files, then build the output
script from the updated sources.

---

## Walkthrough

The following steps are grouped into three stages, one for each phase of the release workflow:
working with the release data file itself, propagating its values to your project files, then
validating and running the release.

Both configuration files are located via paths declared once, in `psscriptbuilder.config.json`
— every release cmdlet used in the following steps reads this configuration to find them, so
none of them ever needs an explicit path parameter of its own:

```json title="psscriptbuilder.config.json"
{
    "release": {
        "dataFile":       ".\\build\\Release\\psscriptbuilder.releasedata.json",
        "bumpConfigFile": ".\\build\\Release\\psscriptbuilder.bumpconfig.json"
    }
}
```

Adjust `dataFile` and `bumpConfigFile` to match your own project's build layout; the rest of
this guide assumes the defaults shown here.

### Working with Release Data

Every release starts from a single JSON file that records the project's current version,
build metadata, and Git context. `psscriptbuilder.releasedata.json` is this authoritative
source of truth — every other cmdlet in this guide reads or writes it, directly or indirectly.
The following steps cover creating this file, bumping its version, and reading its values back
out.

#### 1. Set Up the Release Data File

Every other cmdlet in this guide depends on `psscriptbuilder.releasedata.json` already
existing. If it doesn't yet, create it with its starting defaults:

```powershell
New-PSScriptBuilderReleaseData
```

To find out where to write the file,
[`New-PSScriptBuilderReleaseData`](../cmdlets/New-PSScriptBuilderReleaseData.md) reads the
configured path from `psscriptbuilder.config.json` before writing default values to it.

Use `-Force` to overwrite an existing file — for example, to reinitialise a project. This, and
every other cmdlet in this guide that writes to disk, also supports `-WhatIf` (see
[Tips](#tips)).

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
        "date":      null,
        "time":      null,
        "timestamp": null,
        "year":      null,
        "month":     null,
        "day":       null,
        "hour":      null,
        "minute":    null,
        "second":    null
    },
    "git": {
        "commit":      null,
        "commitShort": null,
        "branch":      null,
        "tag":         null
    }
}
```

The `version` section follows [Semantic Versioning](https://semver.org): `major`, `minor`, and
`patch` are the three required components, `prerelease` and `buildmetadata` are the
specification's optional extensions (both `null` until set), and `full` is a derived
convenience field combining all four into the single version string SemVer itself defines — it
stays in sync automatically whenever any of the other fields change, as shown by the `full`
`Old Value`/`New Value` pair in [Bump the Version](#2-bump-the-version)'s own output. New
projects start at `0.1.0` rather than `1.0.0` — SemVer's major-version-zero convention for
initial development, where anything may still change.

The `build` section starts almost entirely empty: only `number` is initialized, to `0`. Nothing
stamps the date, time, or timestamp fields — or their individual `year`/`month`/`day`/`hour`/
`minute`/`second` components — automatically when the file is created; all of them stay `null`
until explicitly refreshed in
[Update Build and Git Metadata](#3-update-build-and-git-metadata).

The `git` section starts the same way, entirely `null`. There is no cmdlet that reads Git state
on its own — it is populated only as part of that same step.

#### 2. Bump the Version

Every version and metadata update goes through one cmdlet:
[`Update-PSScriptBuilderReleaseData`](../cmdlets/Update-PSScriptBuilderReleaseData.md). It
reads the current `psscriptbuilder.releasedata.json`, applies the requested changes, and
writes the updated values back.

Three switches increment the version following standard SemVer rules:

- `-Major` increments `major` and resets `minor` and `patch` to `0`
- `-Minor` increments `minor` and resets `patch` to `0`
- `-Patch` increments `patch` only

To set an explicit version instead of incrementing the current one — for example, jumping
straight to a specific release number — use `-Version`, which sets `major`, `minor`, and
`patch` directly from the given value:

```powershell
Update-PSScriptBuilderReleaseData -Version '2.1.0'
```

`-Major`, `-Minor`, `-Patch`, and `-Version` are mutually exclusive — only one may be used per call.

Pipe the result to
[`Format-PSScriptBuilderReleaseDataResult`](../cmdlets/Format-PSScriptBuilderReleaseDataResult.md)
for a readable summary of what changed:

```powershell
Update-PSScriptBuilderReleaseData -Patch | Format-PSScriptBuilderReleaseDataResult
```

```text title="Output"
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

#### 3. Update Build and Git Metadata

Before a release, it's often useful to record exactly when it was built and which Git commit
and branch it came from.

These are exactly the `build` and `git` sections introduced in
[Set Up the Release Data File](#1-set-up-the-release-data-file) — both start out empty, and
stay that way until explicitly refreshed. Nothing populates them automatically as part of a
version bump.

Two switches on `Update-PSScriptBuilderReleaseData` populate them independently of any version
change:

- `-UpdateBuildDetails` populates the build section
- `-UpdateGitDetails` populates the Git section

To refresh the build section, `-UpdateBuildDetails` re-stamps the build timestamp and
increments the build number:

```powershell
Update-PSScriptBuilderReleaseData -UpdateBuildDetails | Format-PSScriptBuilderReleaseDataResult
```

```text title="Output"
Category : Build

  Property  : number
  Old Value : 0
  New Value : 1

  Property  : date
  Old Value : <none>
  New Value : 2026-09-14

  Property  : time
  Old Value : <none>
  New Value : 14:18:03

  Property  : timestamp
  Old Value : <none>
  New Value : 2026-09-14T14:18:03Z

  Property  : year
  Old Value : <none>
  New Value : 2026

  Property  : month
  Old Value : <none>
  New Value : 9

  Property  : day
  Old Value : <none>
  New Value : 14

  Property  : hour
  Old Value : <none>
  New Value : 14

  Property  : minute
  Old Value : <none>
  New Value : 18

  Property  : second
  Old Value : <none>
  New Value : 3
```

To refresh the Git section, `-UpdateGitDetails` captures the current Git state — branch,
commit hash, and the latest tag:

```powershell
Update-PSScriptBuilderReleaseData -UpdateGitDetails | Format-PSScriptBuilderReleaseDataResult
```

```text title="Output"
Category : Git

  Property  : commit
  Old Value : <none>
  New Value : 55d9437fc36f519f0d5721193840fc4afcba8dcd

  Property  : commitshort
  Old Value : <none>
  New Value : 55d9437

  Property  : branch
  Old Value : <none>
  New Value : development

  Property  : tag
  Old Value : <none>
  New Value : v1.2.0
```

Both switches are independent of each other and of any version bump. Combine them with any
switch from [Bump the Version](#2-bump-the-version) — here, `-Patch` — to refresh everything in
one call:

```powershell
Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails -UpdateGitDetails
```

`-UpdateGitDetails` requires `git` to be available in `PATH`. If the project is not inside a
Git repository or `git` is not found, the cmdlet throws an error.

#### 4. Working with Prerelease and Build Metadata

Not every release is a final, stable version. A prerelease identifier marks a version as a
release candidate or preview — SemVer treats `1.0.0-rc.1` as coming *before* `1.0.0` in
precedence, so consumers can tell it apart from the finished release. Build metadata, by
contrast, doesn't affect version precedence at all. SemVer represents it as `1.0.0+build.5` —
useful for tagging which build produced a given artifact, without implying it's newer or older
than another with the same version.

PSScriptBuilder exposes both as separate switches on `Update-PSScriptBuilderReleaseData`:

- `-Prerelease "rc.1"` sets the prerelease identifier
- `-BuildMetadata "build.5"` sets build metadata

```powershell
Update-PSScriptBuilderReleaseData -Patch -Prerelease "rc.1" | Format-PSScriptBuilderReleaseDataResult
```

```text title="Output"
Category : Version

  Property  : patch
  Old Value : 0
  New Value : 1

  Property  : prerelease
  Old Value : <none>
  New Value : rc.1

  Property  : full
  Old Value : 0.1.0
  New Value : 0.1.1-rc.1
```

Build metadata works the same way:

```powershell
Update-PSScriptBuilderReleaseData -Patch -BuildMetadata "build.5"
```

Both can be removed again, independently of each other:

- `-ClearPrerelease` removes the prerelease identifier
- `-ClearBuildMetadata` removes build metadata

```powershell
Update-PSScriptBuilderReleaseData -ClearPrerelease
Update-PSScriptBuilderReleaseData -ClearBuildMetadata
```

Prerelease and build metadata identifiers follow the SemVer specification. The `version.full`
sub-property in `psscriptbuilder.releasedata.json` reflects all components: `1.0.0-rc.1+build.5`.

#### 5. Read Release Data

At any point, the current release data can be read back without modifying it, using
[`Get-PSScriptBuilderReleaseData`](../cmdlets/Get-PSScriptBuilderReleaseData.md). The default
mode returns a **hierarchical object** — ideal when you only need specific sections. For
example, you can
access `$data.Build` or work exclusively with `$data.Git` without touching the rest:

```powershell
$data = Get-PSScriptBuilderReleaseData
Write-Host "Number:    $($data.Build.Number)"
Write-Host "Timestamp: $($data.Build.Timestamp)"
```

```text title="Output"
Number:    1
Timestamp: 2026-09-14T14:18:03Z
```

Similarly, `$data.Git` isolates just the Git fields:

```powershell
$data = Get-PSScriptBuilderReleaseData
Write-Host "Branch: $($data.Git.Branch)"
Write-Host "Commit: $($data.Git.Commit)"
Write-Host "Tag:    $($data.Git.Tag)"
```

```text title="Output"
Branch: development
Commit: 55d9437fc36f519f0d5721193840fc4afcba8dcd
Tag:    v1.2.0
```

Use `-Flat` to get a **flat object** with prefixed property names instead — more convenient,
for example, in scripts that pass all token values to another function, or when you want to
enumerate all properties uniformly:

```powershell
$flat = Get-PSScriptBuilderReleaseData -Flat
Write-Host "Version:     $($flat.VersionFull)"
Write-Host "CommitShort: $($flat.GitCommitShort)"
```

```text title="Output"
Version:     0.1.1
CommitShort: 55d9437
```

### Propagating Values to Project Files

Once the release data is in place, its values still need to reach the files that actually
ship — a module manifest, a script header, a changelog entry. `psscriptbuilder.bumpconfig.json`
defines which project files get updated and how, via token replacement or regex patterns. The
following steps cover inspecting available tokens, configuring bump files in each mode, reading the
configuration back, and applying it to your project files.

#### 6. Inspect Available Tokens

Release tokens are the version, build, and Git fields from `psscriptbuilder.releasedata.json` —
the same ones bumped and refreshed in the previous steps — reformatted as named placeholders
ready to be injected into project files.

Use [`Get-PSScriptBuilderReleaseDataTokens`](../cmdlets/Get-PSScriptBuilderReleaseDataTokens.md)
to see all current token values in a single table:

```powershell
Get-PSScriptBuilderReleaseDataTokens | Format-Table -AutoSize
```

```text title="Output"
Name                  Value
----                  -----
BUILD_DATE            2026-09-14
BUILD_TIME            12:53:24
BUILD_DAY             14
BUILD_MONTH           09
BUILD_YEAR            2026
BUILD_HOUR            12
BUILD_MINUTE          53
BUILD_SECOND          24
BUILD_TIMESTAMP       2026-09-14T12:53:24Z
BUILD_NUMBER          1
GIT_COMMIT            55d9437fc36f519f0d5721193840fc4afcba8dcd
GIT_COMMIT_SHORT      55d9437
GIT_BRANCH            development
GIT_TAG               v1.2.0
VERSION               0.1.1
VERSION_MAJOR         0
VERSION_MINOR         1
VERSION_PATCH         1
VERSION_FULL          0.1.1
VERSION_PRERELEASE
VERSION_BUILDMETADATA
```

This is useful to verify that the release data is correct before running
`Update-PSScriptBuilderBumpFiles`.

#### 7. Configure Bump Files — Simple Token Mode

A project file that needs a release value — for example, a version stamp in a script header —
would otherwise have to be edited by hand on every release. The simplest way to avoid that is a
`{{TOKEN}}` placeholder, placed directly in the target file:

```powershell title="MyProject.ps1"
# Version: {{VERSION}}
# Built: {{BUILD_TIMESTAMP}}
```

PSScriptBuilder finds and replaces each placeholder using the current value from
`psscriptbuilder.releasedata.json` — but only for tokens explicitly listed in the entry's
`tokens` array:

```json title="psscriptbuilder.bumpconfig.json — simple token mode"
{
    "bumpFiles": [
        {
            "description": "Output script — inject version and build timestamp",
            "path": "src\\MyProject.ps1",
            "tokens": ["VERSION", "BUILD_TIMESTAMP"]
        }
    ]
}
```

After running `Update-PSScriptBuilderBumpFiles`, the placeholders are replaced with the
actual values. As explained in the [Templates Guide](templates.md#4-combining-with-release-management-tokens),
this mode only works once — on subsequent bumps, the placeholders are gone and the regex mode
is needed.

#### 8. Configure Bump Files — Regex Pattern Mode

After the first bump, a target file no longer contains any `{{TOKEN}}` placeholder to replace —
Simple Token Mode has nothing left to find. Regex Pattern Mode solves this by matching the
value itself with a regular expression, so it keeps working on every subsequent bump, on any
file format, without needing a placeholder at all.

Each item in `items` defines a `pattern` (regex) and a `tokens` array. Use `{REGEX_TOKEN}` as a
named capture group inside the pattern — it matches the current value and is replaced with the
new one:

```json title="psscriptbuilder.bumpconfig.json — regex pattern mode"
{
    "bumpFiles": [
        {
            "description": "Module manifest — update version",
            "path": "build\\Output\\MyModule.psd1",
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

The regex matches the surrounding context (e.g. `ModuleVersion = '...'`) but only the value
inside the parentheses `({REGEX_VERSION})` is replaced. Everything outside the capture group
is preserved as-is.

Multiple items can target the same file, and the same path can appear more than once in
`bumpFiles`. In both cases, all entries are applied sequentially to the same in-memory content
before writing — making multi-phase processing possible.

#### 9. Configure Bump Files — Mixed Mode

Simple Token Mode only works on the first bump, before any placeholder is replaced. Regex
Pattern Mode only works once a real value already exists to match against. A single bump target
commonly needs both — one to handle the very first release, the other for every release after
it.

The following example, drawn from PSScriptBuilder's own real bump configuration, shows the
template file handled by two separate entries — one for each mode:

```json title="psscriptbuilder.bumpconfig.json (real-world example)"
{
    "bumpFiles": [
        {
            "description": "PSScriptBuilder root module template - Auto token replacement",
            "path": "build\\Templates\\PSScriptBuilder.psm1.template",
            "tokens": ["VERSION", "VERSION_FULL", "BUILD_TIMESTAMP", "BUILD_NUMBER", "GIT_COMMIT_SHORT", "GIT_BRANCH", "BUILD_DATE", "BUILD_TIME"]
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
                    "pattern": "BuildNumber\\s*=\\s*'({REGEX_BUILD_NUMBER})'",
                    "tokens": ["BUILD_NUMBER"]
                },
                {
                    "pattern": "GitCommit\\s*=\\s*'({REGEX_GIT_COMMIT_SHORT})'",
                    "tokens": ["GIT_COMMIT_SHORT"]
                },
                {
                    "pattern": "GitBranch\\s*=\\s*'({REGEX_GIT_BRANCH})'",
                    "tokens": ["GIT_BRANCH"]
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

The same idea also works within a *single* entry — one item for the placeholder, one item for
the already-substituted value — verified against
[Example 11](../examples.md#11-mixed-bump-mode)'s real `AppConfig.psd1` manifest, which
genuinely starts with a placeholder on first scaffold:

```json title="psscriptbuilder.bumpconfig.json (Example 11)"
{
    "description": "AppConfig module manifest - Mixed bump mode",
    "path": "build\\Output\\AppConfig.psd1",
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
```

This combination of Simple and Regex items in a single entry is referred to as **Mixed Mode** —
the first item matches on the very first bump, the second on every bump after that.

If a bump file's entries all fail to match on a given run, `Update-PSScriptBuilderBumpFiles`
emits a warning naming the file — a sign it may need a Regex fallback like the ones above. The
warning is file-level: as long as at least one entry for a file still matches (in the first
example, any of Entry 2's five patterns), the file overall won't be flagged, even if `VERSION`,
`BUILD_DATE`, or `BUILD_TIME` — which have no regex fallback there — have gone stale since the
very first bump.

#### 10. Escaping Literal Text in Bump Patterns

Simple Token Mode, Regex Pattern Mode, and Mixed Mode all give special meaning to certain
characters — `{{...}}` marks a token placeholder, and `(...)` marks a regex capture group. If a
target file's real content happens to contain either of these literally — a copyright notice
with parentheses, or documentation text that mentions `{{...}}` — that text needs to be
distinguished from an actual token or capture group, or PSScriptBuilder will misinterpret it.

If a Placeholder Mode pattern needs to include a literal parenthesis — not a regex capture group
— escape it with `\(` and `\)`. This is the same convention Regex Mode patterns already use for
literal parentheses surrounding a capture group.

**Placeholder Mode also supports escaping literal `{{...}}` text** (`\{`/`\}`) for the same
reason — so it is not mistaken for a real token. The table compares the resulting combinations
directly, since several of them look similar but behave differently:

| Pattern | Result |
|---|---|
| `"Copyright \(c\) {{YEAR}}"` | ✅ Replaces `{{YEAR}}`, keeps `(c)` literal. |
| `"Copyright \(c\) \(all rights reserved\) {{YEAR}}"` | ✅ Both literal parentheses kept, `{{YEAR}}` replaced - escaping applies to each occurrence independently. |
| `"{{ site.name }} says {{GIT_BRANCH}}"` with `tokens: ["GIT_BRANCH"]` | ✅ No escaping needed: `{{ site.name }}` is not a declared token, so it is left untouched; only `{{GIT_BRANCH}}` is replaced. |
| `"\{\{ site.name \}\} says {{GIT_BRANCH}}"` with `tokens: ["GIT_BRANCH"]` | ✅ No escaping needed here either — escaping foreign `{{...}}` text is optional, but correctly supported for symmetry. |
| `"Example: \{\{GIT_BRANCH\}\} literal. Real: {{GIT_BRANCH}}"` with `tokens: ["GIT_BRANCH"]` | ✅ Only the unescaped occurrence is replaced; the escaped one stays as literal `{{GIT_BRANCH}}` text - useful for documentation/example text inside the same file. |
| `"Copyright \(c\) (2026) {{YEAR}}"` | ❌ Throws a mixed-syntax error. One parenthesis is escaped, but `(2026)` is not - **every** literal parenthesis in the pattern must be escaped, not just some of them. |
| `"\{\{GIT_BRANCH\}\}"` with `tokens: ["GIT_BRANCH"]` | ❌ Throws `Token 'GIT_BRANCH' has no corresponding placeholder '{{GIT_BRANCH}}' in pattern`. A declared token needs a real, unescaped occurrence somewhere in the pattern; to mention a token name as literal text without ever replacing it, remove it from the item's `tokens` array instead of escaping its braces. |

#### 11. Read Bump Configuration

To verify which files and patterns are currently configured before applying them, use
[`Get-PSScriptBuilderBumpConfiguration`](../cmdlets/Get-PSScriptBuilderBumpConfiguration.md). It
reads `psscriptbuilder.bumpconfig.json` and returns its parsed `bumpFiles` array — for example,
applied to PSScriptBuilder's own real bump configuration:

```powershell
(Get-PSScriptBuilderBumpConfiguration).bumpFiles | Select-Object path -Unique
```

```text title="Output"
path
----
build\Templates\PSScriptBuilder.psm1.template
build\Output\PSScriptBuilder.psd1
```

This is useful for confirming that a newly added bump target actually made it into the
configuration file, without needing to open and parse the JSON by hand.

#### 12. Apply Tokens to Project Files

Once the release data has been updated and `bumpconfig.json` is configured, apply all tokens to
the configured project files with
[`Update-PSScriptBuilderBumpFiles`](../cmdlets/Update-PSScriptBuilderBumpFiles.md), and pipe the
result to
[`Format-PSScriptBuilderBumpResult`](../cmdlets/Format-PSScriptBuilderBumpResult.md) for a
detailed change report:

```powershell
Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult
```

```text title="Output"
File : C:\Projects\MyProject\src\MyProject.ps1

  Token     : VERSION
  Old Value : {{VERSION}}
  New Value : 0.1.1

  Token     : BUILD_TIMESTAMP
  Old Value : {{BUILD_TIMESTAMP}}
  New Value : 2026-09-14T12:55:50Z

File : C:\Projects\MyProject\build\Output\MyModule.psd1

  Pattern   : ModuleVersion\s*=\s*'({REGEX_VERSION})'
  Token     : VERSION
  Old Value : ModuleVersion = '0.1.0'
  New Value : ModuleVersion = '0.1.1'
```

!!! info "Automatic backups before writing"
    Before writing any changes to disk, `Update-PSScriptBuilderBumpFiles` creates a backup
    of each target file. If an error occurs during processing, the originals are restored
    from their backups, leaving all project files in a consistent state.

### Validating and Running a Release

Before running updates — especially in automated scripts — both configuration files should be
validated. The following steps cover that check, then combine every previous step into one
complete release script.

#### 13. Validate Configuration

Always validate both files before running updates — especially in automated scripts where a
silent failure could leave the project in an inconsistent state:

```powershell
if (-not (Test-PSScriptBuilderReleaseData)) {
    Write-Error "Release data is invalid — fix it before bumping"
    return
}

if (-not (Test-PSScriptBuilderBumpConfiguration)) {
    Write-Error "Bump configuration is invalid — fix it before running Update-PSScriptBuilderBumpFiles"
    return
}
```

Each cmdlet checks one of the two files.
[`Test-PSScriptBuilderReleaseData`](../cmdlets/Test-PSScriptBuilderReleaseData.md) validates
the structure and values of `psscriptbuilder.releasedata.json` — for example, that all required
fields exist and the version components are valid integers.
[`Test-PSScriptBuilderBumpConfiguration`](../cmdlets/Test-PSScriptBuilderBumpConfiguration.md)
validates the structure of `bumpconfig.json` and checks that all referenced files exist.

Both cmdlets return `$true` on success and write detailed error messages on failure. Add
`-Verbose` for additional validation detail.

#### 14. Full Release Workflow

A complete release script that combines all steps, in four phases: validate, bump, propagate,
then build.

```powershell title="release.ps1"
if (-not (Test-PSScriptBuilderReleaseData))       { return }
if (-not (Test-PSScriptBuilderBumpConfiguration)) { return }

Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails -UpdateGitDetails |
    Format-PSScriptBuilderReleaseDataResult

Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath '.\src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath '.\src\Public'

Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath '.\build\Templates\MyProject.ps1.template' `
    -OutputPath   '.\build\Output\MyProject.ps1'
```

The order matters: bump first, then propagate, then build. If the build template is
configured as a bump file (see the [Templates Guide](templates.md#4-combining-with-release-management-tokens)),
the version tokens in the template must be updated before `Invoke-PSScriptBuilderBuild` runs.

---

## Reference

### Version Bump Switches

All version-changing switches accepted by `Update-PSScriptBuilderReleaseData`:

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

`-Major`, `-Minor`, `-Patch`, and `-Version` are mutually exclusive — only one may be used per
call. At least one parameter must be specified overall. `-UpdateBuildDetails` and
`-UpdateGitDetails` are the exception — they can be used standalone without a version change, or
combined with any version parameter.

### Metadata Switches

The two switches that refresh build and Git metadata independently of any version change:

| Switch | What it updates |
|---|---|
| `-UpdateBuildDetails` | `build.date`, `build.time`, `build.timestamp`, all time components, `build.number` (+1) |
| `-UpdateGitDetails` | `git.commit`, `git.commitShort`, `git.branch`, `git.tag` — requires `git` in PATH |

### Version Tokens

Tokens derived from the `version` section of `psscriptbuilder.releasedata.json` — the same
tokens seen in [Inspect Available Tokens](#6-inspect-available-tokens):

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

Tokens derived from the `build` section:

| Token | Example value | Description |
|---|---|---|
| `BUILD_NUMBER` | `42` | Incrementing build counter |
| `BUILD_DATE` | `2026-03-24` | Date in `yyyy-MM-dd` format |
| `BUILD_TIME` | `18:00:00` | Time in `HH:mm:ss` format |
| `BUILD_TIMESTAMP` | `2026-03-24T18:00:00Z` | ISO 8601 combined timestamp |
| `BUILD_YEAR` | `2026` | Year component |
| `BUILD_MONTH` | `03` | Month component (zero-padded) |
| `BUILD_DAY` | `24` | Day component (zero-padded) |
| `BUILD_HOUR` | `18` | Hour component (zero-padded) |
| `BUILD_MINUTE` | `00` | Minute component (zero-padded) |
| `BUILD_SECOND` | `00` | Second component (zero-padded) |

### Git Tokens

Tokens derived from the `git` section:

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

!!! tip "Preview any change first with -WhatIf"
    Every cmdlet in this guide that writes to disk — `New-PSScriptBuilderReleaseData`,
    `Update-PSScriptBuilderReleaseData`, and `Update-PSScriptBuilderBumpFiles` — supports
    `-WhatIf`, to preview what would change without writing anything.

!!! tip "Use Get-PSScriptBuilderReleaseDataTokens to verify values"
    Before running `Update-PSScriptBuilderBumpFiles`, call
    `Get-PSScriptBuilderReleaseDataTokens | Format-Table -AutoSize` to confirm that all
    token values match what you expect. This catches a stale bump or a missing Git update
    before it propagates to project files.

!!! warning "Bump before build when the template is a bump file"
    If your build template contains release token placeholders, `Update-PSScriptBuilderBumpFiles`
    must run before `Invoke-PSScriptBuilderBuild`. Otherwise, the build validator will
    report unknown placeholders and fail.

!!! info "Non-Git environments"
    In a project that isn't a Git repository, omit `-UpdateGitDetails` and manage the `git`
    section of `psscriptbuilder.releasedata.json` manually instead.

---

## See Also

- [Cmdlet Reference: New-PSScriptBuilderReleaseData](../cmdlets/New-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Update-PSScriptBuilderReleaseData](../cmdlets/Update-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Format-PSScriptBuilderReleaseDataResult](../cmdlets/Format-PSScriptBuilderReleaseDataResult.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseData](../cmdlets/Get-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseDataTokens](../cmdlets/Get-PSScriptBuilderReleaseDataTokens.md)
- [Cmdlet Reference: Get-PSScriptBuilderBumpConfiguration](../cmdlets/Get-PSScriptBuilderBumpConfiguration.md)
- [Cmdlet Reference: Update-PSScriptBuilderBumpFiles](../cmdlets/Update-PSScriptBuilderBumpFiles.md)
- [Cmdlet Reference: Format-PSScriptBuilderBumpResult](../cmdlets/Format-PSScriptBuilderBumpResult.md)
- [Cmdlet Reference: Test-PSScriptBuilderReleaseData](../cmdlets/Test-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Test-PSScriptBuilderBumpConfiguration](../cmdlets/Test-PSScriptBuilderBumpConfiguration.md)
- [Templates Guide](templates.md) — combining release tokens with build templates
