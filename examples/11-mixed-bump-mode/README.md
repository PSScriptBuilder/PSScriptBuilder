# Example 11 - Mixed Bump Mode

This example demonstrates **Mixed Bump Mode**: a single bump target that handles both the initial
state (token placeholders like `{{VERSION}}`) and all subsequent runs (regex patterns that match
already-substituted values). No manual intervention is needed between the first and any later bump.

## New in this example

- `Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails` - bumps patch version and refreshes build metadata
- `Update-PSScriptBuilderBumpFiles` - applies the current version to all configured files
- `Format-PSScriptBuilderReleaseDataResult` - displays what changed in the release data
- `Format-PSScriptBuilderBumpResult` - displays which files were updated and how
- `Reset-Example.ps1` - restores all files to their initial token state so the example can be run again

## Key concepts

**Mixed Bump Mode** means each bump target entry in `psscriptbuilder.bumpconfig.json` contains
two items pointing at the same location:

1. A **Simple** item with pattern `{{VERSION}}` - matches on the very first bump when the file
   still contains the raw token
2. A **Regex** item with a pattern like `ModuleVersion\s*=\s*'({REGEX_VERSION})'` - matches on
   every subsequent bump after the token has already been replaced with a real version number

PSScriptBuilder processes both items on every run. On the first run only the Simple item finds a
match. On all later runs only the Regex item finds a match. The result is always correct - no
branching logic needed in the script.

**`{REGEX_VERSION}`** is a built-in placeholder that PSScriptBuilder expands to a semantic version
pattern at runtime. It matches values like `1.0.1`, `2.3.0`, `1.0.0-beta.1`.

**`Reset-Example.ps1`** uses plain PowerShell string replacement to write back the `{{VERSION}}`
tokens and copies the initial release data from `psscriptbuilder.releasedata.initial.json`. It
does not use PSScriptBuilder cmdlets - the reset is intentionally low-level to make the mechanism
transparent.

## Project structure

```
11-mixed-bump-mode/
+-- Run-Example.ps1                                     Entry point - bumps version, shows before/after
+-- Reset-Example.ps1                                   Restores all files to initial token state
+-- README.md                                           This file
+-- psscriptbuilder.config.json                         Build configuration
+-- build/
    +-- Release/
    |   +-- psscriptbuilder.releasedata.json            Current release data (modified by Run-Example.ps1)
    |   +-- psscriptbuilder.releasedata.initial.json    Initial state (used by Reset-Example.ps1)
    |   +-- psscriptbuilder.bumpconfig.json             Bump targets with Mixed Mode entries
    +-- Templates/
    |   +-- AppConfig.psm1.template                     Template with {{VERSION}} in header
    +-- Output/
        +-- AppConfig.psd1                              Module manifest with {{VERSION}} placeholder
```

## How to run

```powershell
.\Run-Example.ps1
```

To run the example again from scratch:

```powershell
.\Reset-Example.ps1
.\Run-Example.ps1
```

## How it works

1. `Run-Example.ps1` reads the manifest and template to show the current state (tokens or versions)
2. `Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails` increments the patch number and updates date, time, and build number in `psscriptbuilder.releasedata.json`
3. `Update-PSScriptBuilderBumpFiles` reads the bump config and applies the new version to both files - using the Simple item on the first run and the Regex item on all subsequent runs
4. The before/after comparison confirms the replacement

## Expected output

```
=== Before bump ===
  Manifest : ModuleVersion     = '{{VERSION}}'
  Template : # AppConfig Module v{{VERSION}}

=== Step 1: Update release data ===
Category: Version

  Property  : patch
  Old Value : 0
  New Value : 1

  Property  : full
  Old Value : 1.0.0
  New Value : 1.0.1

Category: Build

  Property  : number
  Old Value : 0
  New Value : 1

  Property  : date
  Old Value : 2026-01-01
  New Value : 2026-03-28

  ...

=== Step 2: Apply version to files ===
File: ...\build\Output\AppConfig.psd1

  Pattern   : {{VERSION}}
  Token     : VERSION
  Old Value : {{VERSION}}
  New Value : 1.0.1

File: ...\build\Templates\AppConfig.psm1.template

  Pattern   : {{VERSION}}
  Token     : VERSION
  Old Value : {{VERSION}}
  New Value : 1.0.1

=== After bump ===
  Manifest : ModuleVersion     = '1.0.1'
  Template : # AppConfig Module v1.0.1

Run .\Reset-Example.ps1 to restore the initial token state.
```
