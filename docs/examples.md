# Examples

Twelve standalone, runnable examples cover the complete PSScriptBuilder feature set — designed
to be read and run in order. Each example introduces one or two new concepts and builds on the
previous ones, from a minimal function-only build up to a full workflow with release management
and module output. Examples 01-08 use an HR domain, examples 09-12 use an AppConfig domain.

## Prerequisites

Clone the repository and build the module once before running any example:

```powershell
git clone https://github.com/PSScriptBuilder/PSScriptBuilder
cd PSScriptBuilder
.\build.ps1
```

Each example is then run from its own folder:

```powershell
cd examples/01-functions-only
.\Run-Example.ps1
```

!!! warning "Run in a fresh PowerShell session"
    The `using module` statement loads types into the current session.
    Reloading or switching between examples in the same session can cause type conflicts.

## Overview

| # | Name | New concept |
|---|------|-------------|
| [01](#01-functions-only) | Functions Only | `FunctionCollector`, basic build pipeline |
| [02](#02-classes-and-enums) | Classes and Enums | `EnumCollector`, `ClassCollector`, dependency ordering |
| [03](#03-with-configuration) | With Configuration | `psscriptbuilder.config.json` |
| [04](#04-flexible-file-structure) | Flexible File Structure | Mixed types per file, AST-based extraction |
| [05](#05-all-collectors) | All Collectors | `UsingCollector`, `FileCollector` with custom keys |
| [06](#06-hybrid-mode) | Hybrid Mode | `{{ORDERED_COMPONENTS}}` without cross-dependencies |
| [07](#07-ordered-mode) | Ordered Mode | Cross-dependencies detected, Ordered Mode activated |
| [08](#08-cycle-detection) | Cycle Detection | Circular dependency detection, fail-fast error |
| [09](#09-module-build) | Module Build | `.psm1` module output, `using module` loader |
| [10](#10-multiple-collectors) | Multiple Collectors | Multiple collectors of the same type with distinct keys |
| [11](#11-mixed-bump-mode) | Mixed Bump Mode | Combining Simple and Regex bump in one target |
| [12](#12-full-workflow) | Full Workflow | Complete release pipeline combining all concepts |

---

## 01 - Functions Only

The simplest possible build: a `FunctionCollector` scans a source folder, extracts all
function definitions, and replaces the `{{FUNCTION_DEFINITIONS}}` placeholder in the template.
No enums, no classes, no configuration file — just the essential build pipeline.

[:octicons-mark-github-16: examples/01-functions-only](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/01-functions-only)

---

## 02 - Classes and Enums

Introduces `EnumCollector` and `ClassCollector`. PSScriptBuilder analyzes the class
hierarchy, builds a dependency graph, and topologically sorts all components before writing
them to the output file. Base classes always appear before derived classes — no manual
ordering required.

[:octicons-mark-github-16: examples/02-classes-and-enums](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/02-classes-and-enums)

---

## 03 - With Configuration

Introduces `psscriptbuilder.config.json`. Template and output paths are read from the
configuration file via `Get-PSScriptBuilderConfiguration` instead of being hardcoded.
The source content is identical to Example 02 — only the build setup changes.

[:octicons-mark-github-16: examples/03-with-configuration](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/03-with-configuration)

---

## 04 - Flexible File Structure

Shows that PSScriptBuilder does not care how source files are organized. Enums, classes, and
functions are deliberately mixed in the same files. Each collector uses AST parsing to extract
exactly the component type it is responsible for, regardless of file structure.

[:octicons-mark-github-16: examples/04-flexible-file-structure](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/04-flexible-file-structure)

---

## 05 - All Collectors

Demonstrates all five collector types in a single build:

- `UsingCollector` — extracts and deduplicates `using namespace` statements
- `FileCollector` — injects raw file content (headers, configuration blocks) via custom collection keys
- `EnumCollector`, `ClassCollector`, `FunctionCollector` — as before

[:octicons-mark-github-16: examples/05-all-collectors](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/05-all-collectors)

---

## 06 - Hybrid Mode

The template uses only the `{{ORDERED_COMPONENTS}}` placeholder instead of separate
`{{ENUM_DEFINITIONS}}`, `{{CLASS_DEFINITIONS}}`, and `{{FUNCTION_DEFINITIONS}}` placeholders.
Because no cross-dependencies exist in this project, PSScriptBuilder activates **Hybrid Mode**:
all components are emitted as a single topologically-sorted block.

`Get-PSScriptBuilderTemplateAnalysis` is called before the build to make the selected mode visible.

[:octicons-mark-github-16: examples/06-hybrid-mode](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/06-hybrid-mode)

---

## 07 - Ordered Mode

Some projects have factory functions that depend on a type which is also a base class of other
classes. In this case the topological sort must interleave classes and functions — separate
`{{CLASS_DEFINITIONS}}` and `{{FUNCTION_DEFINITIONS}}` placeholders are no longer sufficient.
PSScriptBuilder detects this automatically and requires `{{ORDERED_COMPONENTS}}`, activating
**Ordered Mode**.

`Get-PSScriptBuilderDependencyAnalysis` is called before the build to show `HasCrossDependencies: True`
and the interleaved `OrderedComponents` sequence.

[:octicons-mark-github-16: examples/07-ordered-mode](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/07-ordered-mode)

---

## 08 - Cycle Detection

Deliberately introduces a circular **Inheritance** dependency (`ServiceA → ServiceB → ServiceC → ServiceA`).
PSScriptBuilder detects the cycle during dependency analysis and fails fast with a descriptive
error message that includes the full cycle path. No partial output file is written.

Note: only fatal cycles — Inheritance and StaticInitializer — cause a build failure. Type
reference cycles (classes referencing each other in method bodies) are valid in PowerShell 5.1
and are resolved automatically.

`Get-PSScriptBuilderDependencyAnalysis` is used before the build to inspect the `HasCycles`
and `CyclePath` properties of the result.

[:octicons-mark-github-16: examples/08-cycle-detection](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/08-cycle-detection)

---

## 09 - Module Build

Introduces **module output**: instead of building a standalone `.ps1` script, PSScriptBuilder
generates a `.psm1` module file that can be loaded with `using module`. A separate
`Demo-Module.ps1` script loads the built module and demonstrates its types and functions.

The type check at the end of the demo (`$entry.GetType().Name`) shows that PowerShell class
types defined in the module are fully available — which is only possible when the module is
loaded via `using module`, not `Import-Module`.

[:octicons-mark-github-16: examples/09-module-build](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/09-module-build)

---

## 10 - Multiple Collectors

Shows how to use **multiple collectors of the same type** to model a layered project structure.
A logging framework is split into a Core layer (`LogLevel`, `LogEntry`, `LogFormatter`, `LoggerBase`)
and an Extensions layer (`ConsoleLogger`, `FileLogger`). Each layer gets its own `Class` collector
and `Function` collector with a distinct `CollectionKey`. Five template placeholders
(`{{CoreEnums}}`, `{{CoreClasses}}`, `{{CoreFunctions}}`, `{{ExtensionClasses}}`, `{{ExtensionFunctions}}`)
control the output order explicitly.

This example also illustrates how a factory call inside a function can trigger Ordered Mode —
see [Factory functions and cross-dependencies](guides/dependency-analysis.md#factory-functions-and-cross-dependencies)
in the Dependency Analysis Guide.

[:octicons-mark-github-16: examples/10-multiple-collectors](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/10-multiple-collectors)

---

## 11 - Mixed Bump Mode

Demonstrates **Mixed Bump Mode**: a single bump target that handles both the initial state
(token placeholders like `{{VERSION}}`) and all subsequent runs (regex patterns that match
already-substituted values).

The template and manifest start with `{{VERSION}}` placeholders. After the first bump, those
are replaced with concrete values. On every subsequent bump, the Regex items in the same entry
update those values in place — no manual intervention required.

Includes `Reset-Example.ps1` to restore all files to their initial token state so the example
can be run multiple times.

See the [Release Management Guide](guides/release-management.md) for a detailed explanation of
bump modes and tokens.

[:octicons-mark-github-16: examples/11-mixed-bump-mode](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/11-mixed-bump-mode)

---

## 12 - Full Workflow

Combines the complete PSScriptBuilder lifecycle in a single script: **version bump → file update
→ module build → demo**. `Update-PSScriptBuilderReleaseData` increments the patch version and
refreshes build metadata. `Update-PSScriptBuilderBumpFiles` propagates the new version into the
module manifest, template header, and `CHANGELOG.md` using Mixed Bump Mode — the `CHANGELOG.md`
entry demonstrates two tokens (`VERSION` and `BUILD_DATE`) in a single bump target.
`Invoke-PSScriptBuilderBuild` produces the `.psm1` from the updated template. Finally,
`Demo-Module.ps1` loads the built module and confirms the version was correctly carried through
all four phases.

Includes `Reset-Example.ps1` to restore all files to their initial token state so the example
can be run multiple times.

See the [Release Management Guide](guides/release-management.md) for a detailed explanation of
bump modes and tokens.

[:octicons-mark-github-16: examples/12-full-workflow](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/12-full-workflow)

