# Example 12 - Full Workflow

This example combines the complete PSScriptBuilder lifecycle in a single `Run-Example.ps1`:
**version bump, file update, module build, post-processing, demo**. All five phases run in sequence,
showing how release management, script building, and post-processing work together end to end.

## New in this example

- All phases combined: release management, build, and post-processing in one script
- `Compress-PSScriptBuilderScript` accepts pipeline input from `Invoke-PSScriptBuilderBuild` via the `OutputPath` property and writes a comment-free, blank-line-free version of the built module to `AppConfig.compressed.psm1`
- `CHANGELOG.md` as an additional bump target with two tokens (`VERSION` + `BUILD_DATE`) in one entry
- `Demo-Module.ps1` reads `Module version` directly from the built manifest via
  `Import-PowerShellDataFile` - confirming the version was correctly propagated from release data
  all the way into the deployed module
- `Reset-Example.ps1` restores the initial token state so the example can be run multiple times

## Key concepts

**The five phases of a full workflow:**

| Phase | Cmdlet(s) | What happens |
|-------|-----------|--------------|
| 1 - Update release data | `Update-PSScriptBuilderReleaseData` | Bumps version, refreshes build metadata |
| 2 - Apply version to files | `Update-PSScriptBuilderBumpFiles` | Writes version into manifest and template header |
| 3 - Build module | `Invoke-PSScriptBuilderBuild` | Collects classes/functions, fills template, writes `.psm1` |
| 4 - Post-process | `Compress-PSScriptBuilderScript` | Removes comments and blank lines, writes `AppConfig.compressed.psm1` |
| 5 - Demo | `Demo-Module.ps1` | Loads built module, confirms version, exercises types |

**Version flows through all layers:**  
`releasedata.json` feeds into `AppConfig.psd1` (manifest), `AppConfig.psm1.template` (header), and `CHANGELOG.md` (metadata comment). The built `AppConfig.psm1` and `Demo-Module.ps1` confirm the version is correctly carried through all four phases.

**Two tokens in one bump entry:** The `CHANGELOG.md` entry in `psscriptbuilder.bumpconfig.json` uses both `VERSION` and `BUILD_DATE` tokens. Each token gets its own Simple item (for first run) and Regex item (for subsequent runs) within the same entry.

**Mixed Bump Mode** is used here too - the bump config entries each have a Simple item
(`{{VERSION}}`) for the first run and a Regex item for all subsequent runs. See
[Example 11](../11-mixed-bump-mode/README.md) for a dedicated explanation.

## Project structure

```
12-full-workflow/
+-- Run-Example.ps1                                     Entry point - all four phases
+-- Demo-Module.ps1                                     Loads built module, confirms version and types
+-- Reset-Example.ps1                                   Restores all files to initial token state
+-- README.md                                           This file
+-- CHANGELOG.md                                        Tracks releases; version + date bumped automatically
+-- CHANGELOG.initial.md                                Initial token state (used by Reset-Example.ps1)
+-- psscriptbuilder.config.json                         Build configuration
+-- src/
|   +-- Classes/
|   |   +-- ConfigEntry.ps1                            Class: Key, Value, Description; ToString()
|   |   +-- AppConfig.ps1                              Class: Name, Entries; Add(), Get(), Contains(), Count()
|   +-- Functions/
|       +-- New-ConfigEntry.ps1                        Factory function, returns [ConfigEntry]
|       +-- New-AppConfig.ps1                          Factory function, returns [AppConfig]
|       +-- Get-ConfigValue.ps1                        Gets a value by key, supports -Default parameter
+-- build/
    +-- Release/
    |   +-- psscriptbuilder.releasedata.json           Current release data (modified by Run-Example.ps1)
    |   +-- psscriptbuilder.releasedata.initial.json   Initial state (used by Reset-Example.ps1)
    |   +-- psscriptbuilder.bumpconfig.json            Bump targets: manifest, template header, CHANGELOG
    +-- Templates/
    |   +-- AppConfig.psm1.template                    Template with version header + class/function placeholders
    +-- Output/
        +-- AppConfig.psd1                             Module manifest ({{VERSION}} initially)
        +-- AppConfig.compressed.psm1                  Post-processed output (comments + blank lines removed)
```

## How to run

> **Warning:** Run in a fresh PowerShell session  
> The `using module` statement loads types into the current session.  
> Reloading or switching between examples in the same session can cause type conflicts.

```powershell
.\Run-Example.ps1
```

To run the example again from scratch:

```powershell
.\Reset-Example.ps1
.\Run-Example.ps1
```

## How it works

1. `Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails` increments the patch version and refreshes date, time, and build number in `psscriptbuilder.releasedata.json`
2. `Update-PSScriptBuilderBumpFiles` applies the new version to `AppConfig.psd1`, the template header, and `CHANGELOG.md` - Mixed Bump Mode handles both first run (token) and subsequent runs (regex) for all three targets; the CHANGELOG entry also substitutes `BUILD_DATE` alongside `VERSION`
3. `Invoke-PSScriptBuilderBuild` collects `ConfigEntry` + `AppConfig` classes and three factory/utility functions, resolves dependencies, fills the template, and writes `AppConfig.psm1`
4. `Compress-PSScriptBuilderScript` accepts the build result via pipeline, removes all comments and blank lines, and writes the result to `AppConfig.compressed.psm1`
5. `Run-Example.ps1` calls `Demo-Module.ps1` as a child script via `&`
6. `Demo-Module.ps1` loads the built module with `using module`, reads the version from the manifest, and exercises strongly-typed `ConfigEntry` and `AppConfig` objects

## Expected output

```
=== Phase 1: Update release data ===
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

=== Phase 2: Apply version to files ===
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

File: ...\CHANGELOG.md

  Pattern   : {{VERSION}}
  Token     : VERSION
  Old Value : {{VERSION}}
  New Value : 1.0.1

  Pattern   : {{BUILD_DATE}}
  Token     : BUILD_DATE
  Old Value : {{BUILD_DATE}}
  New Value : 2026-03-28

=== Phase 3: Build module ===

Build Summary
  Output: ...\build\Output\AppConfig.psm1
  Size  : 2.05 KB
  Time  : 77.73 ms

Components
  Classes  : 2
  Functions: 3
  Total    : 5

=== Phase 4: Post-process output ===
Post-processing complete.

=== Phase 5: Demo ===
Module version : 1.0.1

Config   : AppSettings
Entries  : 4

  Environment     = Production  # Deployment environment
  LogLevel        = Warning  # Minimum log level
  MaxRetries      = 3  # Maximum retry attempts
  Timeout         = 30

Environment : Production
ApiKey      : (not set)

Type of entry  : ConfigEntry
Type of config : AppConfig
```
