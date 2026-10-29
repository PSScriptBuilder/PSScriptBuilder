# Contributing to PSScriptBuilder

Thank you for your interest in PSScriptBuilder!

PSScriptBuilder is a **solo-maintained project**. Issues and feature requests are welcome, but pull requests may not always be accepted. If you plan to contribute code, please open an issue first to discuss the change.

---

## Reporting Issues

Use [GitHub Issues](https://github.com/PSScriptBuilder/PSScriptBuilder/issues) to report bugs or request features.

After importing the module, two global variables capture all relevant context for bug reports:
`$Global:PSScriptBuilderModuleInfo` contains the module version, build number, and Git details;
`$Global:PSScriptBuilderRuntimeInfo` contains the PowerShell version, edition, and host name.

Please include:

```powershell
$Global:PSScriptBuilderModuleInfo
$Global:PSScriptBuilderRuntimeInfo
```

Also include a minimal reproduction script or error output.

---

## Running Tests Locally

Tests require [Pester 5.7+](https://pester.dev):

```powershell
Install-Module -Name Pester -MinimumVersion 5.7.1 -Force -SkipPublisherCheck
```

Run the full test suite from the repository root:

```powershell
.\tests\Invoke-Tests.ps1
```

Run only unit or integration tests:

```powershell
.\tests\Invoke-Tests.ps1 -Suite Unit
.\tests\Invoke-Tests.ps1 -Suite Integration
```

> **Note**: The integration tests require the examples directory to be present. Do not run them from a partial checkout.

---

## Building the Module

```powershell
git clone https://github.com/PSScriptBuilder/PSScriptBuilder.git
cd PSScriptBuilder
.\build.ps1 -ProjectRoot .
```

This produces `build\Output\PSScriptBuilder.psd1` — a built module, but not one `Install-Module`
ever registered on `$env:PSModulePath`. Because of that, `using module PSScriptBuilder` (by
name) will not find it: the same by-name lookup `Import-Module` uses only searches
`$env:PSModulePath`, and `build\Output\` is not on it. Reference the manifest file by path
instead:

```powershell title="Correct — loads the freshly built module directly, without installing it"
using module .\build\Output\PSScriptBuilder.psd1
```

This works immediately, without running `Install-Module` at all — useful for testing a local
change before publishing it.

---

## Developer Scripts

Three utility scripts are available for verifying and analyzing the module after a successful build.

**Prerequisite**: All three scripts require a built module at `build\Output\PSScriptBuilder.psd1`. See [Building the Module](#building-the-module).

### Smoke Test

Verifies that all analysis cmdlets are callable:

```powershell
.\tests\Invoke-SmokeTests.ps1
```

Runs 22 checks across module import, configuration, collector setup, and analysis cmdlets. Useful after a build to confirm nothing is broken.

### Example Tests

Runs every example in `examples/` in its own process and verifies a clean exit and the expected output files:

```powershell
.\tests\Invoke-ExampleTests.ps1
```

### Project Analysis

Reports codebase metrics — component counts, inheritance chains, dependency graph statistics, and quality indicators:

```powershell
.\tests\Invoke-ProjectAnalysis.ps1
```

---

## Code Conventions

- Compatible with **PowerShell 5.1** — avoid PS7-only language features
- All source code in English (comments included)
- Existing `#region` / `#endregion` blocks must be preserved as-is — do not add, remove, move, or rename them

See the inline documentation in `src/` for detailed patterns and examples.

---

## Cmdlet Documentation

Cmdlet reference pages (`docs/cmdlets/*.md`) are being migrated, one cmdlet at a time, from
PlatyPS-generated pages to a custom, hand-maintained format. A page counts as migrated once it
no longer starts with PlatyPS's frontmatter (`external help file: ...`) — `Build-Module.ps1`'s
documentation step detects this automatically and never regenerates a migrated page.

**If you change a migrated cmdlet's parameters, examples, or behavior, update its
`docs/cmdlets/*.md` page by hand in the same change** — this no longer happens automatically.
Non-migrated cmdlets are unaffected; their pages continue to regenerate from CBH via
`.\Build-Module.ps1 -Docs` (or any `-Release` build) as before.

---

## Changelog

All notable changes between versions are documented in [CHANGELOG.md](CHANGELOG.md).
