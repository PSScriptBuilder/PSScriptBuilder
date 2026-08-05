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

## Developer Scripts

Two utility scripts are available for verifying and analyzing the module after a successful build.

**Prerequisite**: Both scripts require a built module at `build\Output\PSScriptBuilder.psd1`. Run `.\build.ps1` first.

### Smoke Test

Verifies that all analysis cmdlets are callable:

```powershell
.\tests\Invoke-SmokeTests.ps1
```

Runs 20 checks across module import, configuration, collector setup, and analysis cmdlets. Useful after a build to confirm nothing is broken.

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

## Changelog

All notable changes between versions are documented in [CHANGELOG.md](CHANGELOG.md).
