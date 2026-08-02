---
title: The full PSScriptBuilder workflow — version bump, build, and release
series: Building real PowerShell projects with PSScriptBuilder
tags: powershell, automation, devops, tutorial
cover_image: 
published: false
---

*Parts 1–3 covered standalone scripts, automatic class ordering, and module builds. In this final part we wire everything together: version management, build, post-processing, and a self-verifying demo — all in one repeatable workflow.*

*This article uses the same AppConfig module introduced in [Part 3](#). If you haven't read it yet, the project structure and source files are shown there.*

---

## One script, five phases

A real release workflow does more than generate a file. It bumps the version, applies it everywhere it needs to appear, builds the output, and optionally post-processes it for deployment. PSScriptBuilder has dedicated cmdlets for every phase.

| Phase | Cmdlet | What happens |
|-------|--------|--------------|
| 1 — Update release data | `Update-PSScriptBuilderReleaseData` | Bumps version, refreshes build date/time |
| 2 — Apply to files | `Update-PSScriptBuilderBumpFiles` | Writes version into manifest, template, changelog |
| 3 — Build module | `Invoke-PSScriptBuilderBuild` | Collects classes + functions, fills template, writes `.psm1` |
| 4 — Post-process | `Compress-PSScriptBuilderScript` | Strips comments and blank lines for deployment |
| 5 — Demo | `Demo-Module.ps1` | Loads built module, reads version from manifest to confirm propagation |

---

## Version flows through the project

The release data file (`psscriptbuilder.releasedata.json`) is the single source of truth for the version. Phase 2 propagates it into every file that needs it:

```
psscriptbuilder.releasedata.json
        │
        ├── AppConfig.psd1          (ModuleVersion = '1.0.1')
        ├── AppConfig.psm1.template (# AppConfig Module v1.0.1)
        └── CHANGELOG.md            (Release: 1.0.1 | Date: 2026-05-20)
```

At Phase 3, the template — already carrying the updated version in its header — is filled with the collected source code. The built `AppConfig.psm1` inherits the version comment automatically.

---

## Phase 1 — Update release data

```powershell
$releaseResult = Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails
Format-PSScriptBuilderReleaseDataResult -ReleaseDataResult $releaseResult
```

`-Patch` increments the patch segment. `-UpdateBuildDetails` refreshes the build date, time, and timestamp. The updated values are written back to `psscriptbuilder.releasedata.json`.

For a full explanation of release data, tokens, and Mixed Bump Mode, see
[Stop Manually Updating Version Numbers in PowerShell Projects](https://dev.to/tim_hartling/stop-manually-updating-version-numbers-in-powershell-projects-psscriptbuilder-does-it-for-you-150c).

---

## Phase 2 — Apply version to files

```powershell
$bumpResult = Update-PSScriptBuilderBumpFiles
Format-PSScriptBuilderBumpResult -BumpResult $bumpResult
```

PSScriptBuilder reads `psscriptbuilder.bumpconfig.json` and applies the new version to every
configured file. In this example, three files are updated in one call:

| File | Token(s) replaced |
|------|-------------------|
| `AppConfig.psd1` | `VERSION` |
| `AppConfig.psm1.template` | `VERSION` |
| `CHANGELOG.md` | `VERSION` + `BUILD_DATE` |

After Phase 2, the template already carries the updated version header — so the built output
in Phase 3 inherits the correct version without any additional steps.

---

## Phase 3 — Build module

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = $templatePath
    OutputPath       = $outputPath
}

$buildResult = Invoke-PSScriptBuilderBuild @buildParams

Format-PSScriptBuilderBuildResult -BuildResult $buildResult
```

Same pattern as Part 3. The key difference here is that the template already contains the updated version header from Phase 2 — so the built output carries the correct version without any additional steps.

---

## Phase 4 — Post-process

```powershell
$compressParams = @{
    RemoveComments   = $true
    RemoveBlankLines = $true
    DestinationPath  = $compressedPath
    Force            = $true
}

$buildResult | Compress-PSScriptBuilderScript @compressParams
```

`Compress-PSScriptBuilderScript` accepts pipeline input from `Invoke-PSScriptBuilderBuild` via the `OutputPath` property. `-RemoveComments` and `-RemoveBlankLines` produce a compact version of the module written to `AppConfig.compressed.psm1` — ready for environments where you want to minimize the deployed file size.

---

## Phase 5 — Demo

The demo script reads the version directly from the built manifest to confirm the full propagation chain:

```powershell
using module .\build\Output\AppConfig.psd1

$manifest      = Import-PowerShellDataFile -Path "$PSScriptRoot\build\Output\AppConfig.psd1"
$moduleVersion = $manifest.ModuleVersion
Write-Host "Module version : $moduleVersion"

$config = New-AppConfig -Name "AppSettings"
$config.Add((New-ConfigEntry -Key "Environment" -Value "Production" -Description "Deployment environment"))
# ...
```

If `psscriptbuilder.releasedata.json` says `1.0.1`, the manifest will say `1.0.1`, and `$moduleVersion` will be `1.0.1`. The version that entered at Phase 1 confirms itself at Phase 5.

---

## Repeatability

Running the example multiple times always produces a clean result because `Reset-Example.ps1` restores the initial token state:

```powershell
# Resets releasedata.json, CHANGELOG.md, and all other modified files
.\Reset-Example.ps1
```

This is the same pattern used in CI: every run starts from a known state, applies the workflow, and produces a deterministic output.

---

## The complete output

```
=== Phase 1: Update release data ===
  Version : 1.0.0 → 1.0.1
  Date    : 2026-05-20

=== Phase 2: Apply version to files ===
  AppConfig.psd1              1 replacement
  AppConfig.psm1.template     1 replacement
  CHANGELOG.md                2 replacements

=== Phase 3: Build module ===

Build Summary
  Output : ...\build\Output\AppConfig.psm1
  Size   : 2.02 KB
  Time   : 12 ms

Components
  Classes   : 2
  Functions : 3
  Total     : 5

=== Phase 4: Post-process output ===
  Post-processing complete.

=== Phase 5: Demo ===
  Module version : 1.0.1

  Config   : AppSettings
  Entries  : 4

  Environment  = Production  # Deployment environment
  LogLevel     = Warning     # Minimum log level
  MaxRetries   = 3           # Maximum retry attempts
  Timeout      = 30

  Environment : Production
  ApiKey      : (not set)
```

---

## Wrapping up the series

Across these four articles we went from scattered `.ps1` files to a fully automated release pipeline:

- **Part 1** — Collect loose functions, fill a template, write a deployable script
- **Part 2** — Let PSScriptBuilder resolve class inheritance order automatically
- **Part 3** — Switch output to a module, get strongly-typed objects for free
- **Part 4** — Add version management, bump propagation, and post-processing

The full source for all examples is in the [PSScriptBuilder repository](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples).

---

*Questions or feedback? Drop a comment below or open an issue on [GitHub](https://github.com/PSScriptBuilder/PSScriptBuilder/issues).*
