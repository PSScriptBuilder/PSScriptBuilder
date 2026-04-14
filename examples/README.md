# Examples

This folder contains twelve standalone, runnable examples for
[PSScriptBuilder](https://github.com/PSScriptBuilder/PSScriptBuilder) — a PowerShell module
that builds a single deployable script or module from multi-file projects, with automatic
dependency resolution, topological sorting, and integrated release management.

The examples are designed to be read and run in order. Each example introduces one or two new
concepts and builds on the previous ones — from a minimal function-only build up to a full
workflow with release management and module output.

- **Examples 01-08** use an HR domain (`Person`, `Employee`, `Address`, ...)
- **Examples 09-12** use an AppConfig domain (`ConfigEntry`, `AppConfig`, ...)

---

## Prerequisites

**1. Clone the repository**

```powershell
git clone https://github.com/PSScriptBuilder/PSScriptBuilder
cd PSScriptBuilder
```

**2. Build the module once** (required before running any example)

```powershell
.\build.ps1
```

This produces `build\Output\PSScriptBuilder.psd1` which all examples load via `using module`.

**3. PowerShell version**

PowerShell 5.1 or later is required. All examples are compatible with Windows PowerShell 5.1.

---

## How to run

Each example is self-contained. Navigate into the example folder and run `Run-Example.ps1`:

```powershell
cd examples\01-functions-only
.\Run-Example.ps1
```

For detailed build output including collector progress and dependency resolution:

```powershell
.\Run-Example.ps1 -Verbose
```

> **Warning:** Run each example in a fresh PowerShell session.
> The `using module` statement loads types into the current session.
> Reloading or switching between examples in the same session can cause type conflicts.
> Use a new terminal window or `pwsh -NoProfile` for each example.

---

## Overview

| # | Folder | What it shows |
|---|--------|---------------|
| 01 | [01-functions-only](01-functions-only/) | The simplest possible build: three standalone functions collected from separate files and merged into a single output script using a template |
| 02 | [02-classes-and-enums](02-classes-and-enums/) | Enum and class collectors with automatic dependency ordering — base classes always appear before derived classes |
| 03 | [03-with-configuration](03-with-configuration/) | Decoupling build paths from the script via `psscriptbuilder.config.json` |
| 04 | [04-flexible-file-structure](04-flexible-file-structure/) | Enums, classes, and functions mixed in the same files — PSScriptBuilder extracts each type via AST parsing regardless of file layout |
| 05 | [05-all-collectors](05-all-collectors/) | All five collector types in one build: `Using`, `Enum`, `Class`, `Function`, `File` |
| 06 | [06-hybrid-mode](06-hybrid-mode/) | `{{ORDERED_COMPONENTS}}` placeholder without cross-dependencies — Hybrid Mode emits all components in topological order as a single block |
| 07 | [07-ordered-mode](07-ordered-mode/) | Factory function creates a cross-dependency — PSScriptBuilder detects it and activates Ordered Mode to emit classes and functions in the correct interleaved sequence |
| 08 | [08-cycle-detection](08-cycle-detection/) | Circular dependency (`ServiceA -> ServiceB -> ServiceC -> ServiceA`) — PSScriptBuilder fails fast with a descriptive error, no broken output is produced |
| 09 | [09-module-build](09-module-build/) | Building a `.psm1` module instead of a standalone script — a separate demo script loads the module via `using module` to access strongly-typed objects |
| 10 | [10-multiple-collectors](10-multiple-collectors/) | Multiple collectors of the same type with distinct `CollectionKey` values — a logging framework split into Core and Extensions layers |
| 11 | [11-mixed-bump-mode](11-mixed-bump-mode/) | Mixed Bump Mode: a single bump target handles both initial token placeholders and all subsequent regex-based updates without manual intervention |
| 12 | [12-full-workflow](12-full-workflow/) | Complete lifecycle in one script: version bump, file update (manifest, template, CHANGELOG), module build, demo |

---

## Concepts by example

### Script building (01-08)

| Concept | First shown in |
|---------|---------------|
| Basic build pipeline | [01](01-functions-only/) |
| Dependency ordering | [02](02-classes-and-enums/) |
| Configuration file | [03](03-with-configuration/) |
| AST-based extraction | [04](04-flexible-file-structure/) |
| All collector types | [05](05-all-collectors/) |
| Hybrid Mode | [06](06-hybrid-mode/) |
| Ordered Mode | [07](07-ordered-mode/) |
| Cycle detection | [08](08-cycle-detection/) |

### Module building (09-12)

| Concept | First shown in |
|---------|---------------|
| Module output (`.psm1`) | [09](09-module-build/) |
| Multiple collectors of the same type | [10](10-multiple-collectors/) |
| Release management / Mixed Bump Mode | [11](11-mixed-bump-mode/) |
| Full release + build workflow | [12](12-full-workflow/) |

---

## Reset scripts

Examples 11 and 12 modify files during the bump phase (version numbers are written into the
manifest, template header, and CHANGELOG). Use `Reset-Example.ps1` to restore all files to
their initial token state before running the example again:

```powershell
cd examples\11-mixed-bump-mode
.\Reset-Example.ps1
.\Run-Example.ps1
```

---

## Further reading

- [Full documentation](https://docs.psscriptbuilder.com)
- [Getting started](https://docs.psscriptbuilder.com/getting-started/installation/)
- [Collectors guide](https://docs.psscriptbuilder.com/guides/collectors/)
- [Dependency analysis guide](https://docs.psscriptbuilder.com/guides/dependency-analysis/)
- [Release management guide](https://docs.psscriptbuilder.com/guides/release-management/)
