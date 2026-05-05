# Contributing to PSScriptBuilder

Thank you for your interest in PSScriptBuilder!

PSScriptBuilder is a **solo-maintained project**. Issues and feature requests are welcome, but pull requests may not always be accepted. If you plan to contribute code, please open an issue first to discuss the change.

---

## Reporting Issues

Use [GitHub Issues](https://github.com/PSScriptBuilder/PSScriptBuilder/issues) to report bugs or request features. Please include:

- PowerShell version (`$PSVersionTable.PSVersion`)
- Operating system
- A minimal reproduction script or error output

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

## Code Conventions

- Compatible with **PowerShell 5.1** — avoid PS7-only language features
- All source code in English (comments included)
- Existing `#region` / `#endregion` blocks must be preserved as-is — do not add, remove, move, or rename them

See the inline documentation in `src/` for detailed patterns and examples.

---

## Changelog

All notable changes between versions are documented in [CHANGELOG.md](CHANGELOG.md).
