---
title: Stop Manually Updating Version Numbers in PowerShell Projects — PSScriptBuilder Does It For You
series: Automating PowerShell Projects with PSScriptBuilder
tags: powershell, devtools, automation, opensource
cover_image: https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/images/platforms/devto/features-banner.png
published: true
---

If you maintain a PowerShell project, you've probably done this before:

1. Bump the version in `MyScript.ps1` or `MyModule.psd1`
2. Update the version comment in your script header
3. Add the date to `CHANGELOG.md`
4. Forget one of the three — and push anyway

Manual version management is error-prone by nature. The more files you need to update, the more likely something falls out of sync. And "just use a script" sounds simple until that script breaks six months later because a filename changed.

PSScriptBuilder includes a full release management pipeline that solves this with two JSON files and two cmdlets — whether you're building a deployable script, a module, or anything in between.

## How It Works

PSScriptBuilder separates release management into two concerns:

**Release data** — a single source of truth for your current version and build metadata:

```json
{
    "version": {
        "major": 1,
        "minor": 0,
        "patch": 3,
        "prerelease": "",
        "buildmetadata": "",
        "full": "1.0.3"
    },
    "build": {
        "number": 42,
        "date": "2026-04-20",
        "time": "14:23:11",
        "timestamp": "2026-04-20T14:23:11Z",
        "year": 2026,
        "month": 4,
        "day": 20,
        "hour": 14,
        "minute": 23,
        "second": 11
    },
    "git": {
        "commit": "a3f1c2987d4e5f6b",
        "commitShort": "a3f1c29",
        "branch": "main",
        "tag": "v1.0.3"
    }
}
```

**Bump configuration** — a declaration of which files get updated and how. Here is a real-world example covering a module manifest, a script header, and a CHANGELOG — all in Mixed Bump Mode:

```json
{
    "bumpFiles": [
        {
            "description": "Module manifest - Mixed bump mode",
            "path": "build\\Output\\MyModule.psd1",
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
        },
        {
            "description": "Script header - Mixed bump mode",
            "path": "build\\Templates\\MyScript.psm1.template",
            "items": [
                {
                    "pattern": "{{VERSION}}",
                    "tokens": ["VERSION"]
                },
                {
                    "pattern": "# MyScript v({REGEX_VERSION})",
                    "tokens": ["VERSION"]
                }
            ]
        },
        {
            "description": "CHANGELOG - Mixed bump mode with VERSION and BUILD_DATE",
            "path": "CHANGELOG.md",
            "items": [
                {
                    "pattern": "{{VERSION}}",
                    "tokens": ["VERSION"]
                },
                {
                    "pattern": "{{BUILD_DATE}}",
                    "tokens": ["BUILD_DATE"]
                },
                {
                    "pattern": "Release: ({REGEX_VERSION})",
                    "tokens": ["VERSION"]
                },
                {
                    "pattern": "Date: (\\d{4}-\\d{2}-\\d{2})",
                    "tokens": ["BUILD_DATE"]
                }
            ]
        }
    ]
}
```

PSScriptBuilder automatically substitutes `{REGEX_VERSION}` and similar placeholders with the appropriate regex pattern for the token — no manual regex writing required.

## A Release in Two Cmdlets

**Step 1 — Update the release data:**

```powershell
Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails
```

This bumps the patch version, increments the build number, and refreshes date, time, and timestamp — all in one call. `-WhatIf` shows you the changes before committing them.

**Step 2 — Apply the new version to your files:**

```powershell
Update-PSScriptBuilderBumpFiles
```

PSScriptBuilder reads the bump configuration, locates each file, applies the patterns, substitutes the tokens with current values, and writes the results. Every configured file is updated atomically — either all succeed or nothing is written.

That's it. No fragile find-and-replace scripts. No forgotten files.

## Mixed Bump Mode

The first time you run `Update-PSScriptBuilderBumpFiles` on a new file, there is no existing version to match — only a placeholder token like `{{VERSION}}`. On every subsequent run, the file already contains a real version string that needs to be matched by regex.

PSScriptBuilder handles this with **Mixed Bump Mode**: each bump entry can contain both a simple token replacement (first run) and a regex replacement (all subsequent runs) within the same file entry.

First run: the simple item `"pattern": "{{VERSION}}"` matches the placeholder and replaces it with `1.0.3`.

All subsequent runs: the regex item `"pattern": "ModuleVersion\\s*=\\s*'({REGEX_VERSION})'"` matches the existing value and updates it to `1.0.4`.

PSScriptBuilder tries each item in order — whichever matches wins. No config change needed between the first and second run. Multiple tokens per entry are fully supported — the CHANGELOG example above updates both `VERSION` and `BUILD_DATE` from a single file entry.

## Available Tokens (excerpt)

| Token | Example value |
|---|---|
| `{{VERSION}}` | `1.0.3` |
| `{{VERSION_FULL}}` | `1.0.3-beta.1` |
| `{{BUILD_TIMESTAMP}}` | `2026-04-20T14:23:11Z` |
| `{{BUILD_DATE}}` | `2026-04-20` |
| `{{GIT_COMMIT_SHORT}}` | `a3f1c29` |

All available tokens — including build number, time components, and full Git metadata — are listed in the [Release Management Guide](https://docs.psscriptbuilder.com/guides/release-management/). You can also inspect the current values at any time:

```powershell
Get-PSScriptBuilderReleaseDataTokens | Format-Table -AutoSize
```

## Fitting Into a Full Build Pipeline

Release management is designed to run before your build (adjust `-Patch`, `-Minor`, or `-Major` to your needs):

```powershell
# Step 1 — Bump version and refresh metadata
Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails -UpdateGitDetails

# Step 2 — Propagate version into manifest, script header, CHANGELOG
Update-PSScriptBuilderBumpFiles

# Step 3 — Build the script
$buildResult = Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath "build/Templates/MyScript.psm1.template" `
    -OutputPath "build/Output/MyScript.psm1"
```

The version flows from the release data file through your project files all the way into the built output — automatically, every time.

## Get Started

```powershell
Install-Module -Name PSScriptBuilder
```

- Full guide: [docs.psscriptbuilder.com/guides/release-management](https://docs.psscriptbuilder.com/guides/release-management/)
- Docs: [docs.psscriptbuilder.com](https://docs.psscriptbuilder.com/)
- GitHub: [github.com/PSScriptBuilder/PSScriptBuilder](https://github.com/PSScriptBuilder/PSScriptBuilder)

New to PSScriptBuilder? Start here: [Stop Manually Sorting PowerShell Class Files — PSScriptBuilder Does It For You](https://dev.to/tim_hartling/stop-manually-sorting-powershell-class-files-psscriptbuilder-does-it-for-you-2dok)

---

Do you currently manage version numbers manually across your PowerShell projects? I'd be curious to hear what your current process looks like — or whether this covers your use case.
