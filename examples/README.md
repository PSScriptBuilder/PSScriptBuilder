# Examples

This folder contains fifteen standalone, runnable examples for
[PSScriptBuilder](https://github.com/PSScriptBuilder/PSScriptBuilder) — a PowerShell module
that builds a single deployable script or module from multi-file projects, with automatic
dependency resolution, topological sorting, and integrated release management.

The examples are designed to be read and run in order. Each example introduces one or two new
concepts and builds on the previous ones — from a minimal function-only build up to a full
workflow with release management and module output.

- **Examples 01-08** use an HR domain (`Person`, `Employee`, `Address`, ...)
- **Examples 09-12** use an AppConfig domain (`ConfigEntry`, `AppConfig`, ...)
- **Example 13** uses PSScriptBuilder's own source code as the analysis subject
- **Example 14** scaffolds a brand-new project and runs the full workflow from scratch
- **Example 15** demonstrates the file watcher in Build mode and Script mode

---

## Prerequisites

**1. Clone the repository**

```powershell
git clone https://github.com/PSScriptBuilder/PSScriptBuilder
cd PSScriptBuilder
```

The built module is included in the repository — no build step required.

**2. PowerShell version**

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
| 12 | [12-full-workflow](12-full-workflow/) | Complete lifecycle in one script: version bump, file update (manifest, template, CHANGELOG), module build, post-processing (comments + blank lines removed), demo |
| 13 | [13-dependency-analysis](13-dependency-analysis/) | Dependency and code analysis without building: component counts, cycle detection, Mermaid and DOT diagram export, drill-down traversal, inheritance tree rendering, codebase metrics |
| 14 | [14-scaffolding](14-scaffolding/) | Cold-start workflow: scaffold a new project with `New-PSScriptBuilderProject`, set the project root, bump version, and build |
| 15 | [15-watcher](15-watcher/) | Real-time file watching: Build mode rebuilds automatically on every source change; Script mode invokes a custom script block with the changed file paths |

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

### Dependency and code analysis (13)

| Concept | First shown in |
|---------|---------------|
| `Get-PSScriptBuilderDependencyAnalysis` | [13](13-dependency-analysis/) |
| `Export-PSScriptBuilderDependencyGraph` (Mermaid + DOT) | [13](13-dependency-analysis/) |
| `Get-PSScriptBuilderComponentDependency` + `-EdgeType` | [13](13-dependency-analysis/) |
| `ConvertTo-PSScriptBuilderComponentDependencyTree` | [13](13-dependency-analysis/) |

### Scaffolding (14)

| Concept | First shown in |
|---------|---------------|
| `New-PSScriptBuilderProject` | [14](14-scaffolding/) |
| `Set-PSScriptBuilderProjectRoot` after scaffolding | [14](14-scaffolding/) |

### File watching (15)

| Concept | First shown in |
|---------|---------------|
| `Watch-PSScriptBuilderProject` Build mode | [15](15-watcher/) |
| `Watch-PSScriptBuilderProject` Script mode | [15](15-watcher/) |
| `-Action` script block after successful build | [15](15-watcher/) |

---

## Reset scripts

Some examples create or modify files. Use `Reset-Example.ps1` to restore the initial state
before running the example again:

| Example | What is reset |
|---------|---------------|
| 11 | Version tokens in manifest and template restored to `{{VERSION}}` |
| 12 | Version tokens in manifest, template, and CHANGELOG restored to `{{VERSION}}` |
| 13 | `output\` directory removed |
| 14 | `MyProject\` directory removed |

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
