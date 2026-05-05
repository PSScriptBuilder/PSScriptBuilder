# PSScriptBuilder

<img src="https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/assets/banner.png" alt="PSScriptBuilder" width="750">

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSScriptBuilder)](https://www.powershellgallery.com/packages/PSScriptBuilder)
[![Downloads](https://img.shields.io/powershellgallery/dt/PSScriptBuilder.svg)](https://www.powershellgallery.com/packages/PSScriptBuilder)
[![Platform](https://img.shields.io/powershellgallery/p/PSScriptBuilder.svg)](https://www.powershellgallery.com/packages/PSScriptBuilder)

[![powershell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![website](https://img.shields.io/badge/website-psscriptbuilder.com-blue)](https://psscriptbuilder.com)
[![documentation](https://img.shields.io/badge/documentation-docs.psscriptbuilder.com-blue)](https://docs.psscriptbuilder.com)

A dependency-aware PowerShell script builder that combines multi-file projects into a single, deployable script.

**The Problem**

As a PowerShell project grows, managing the order of classes, enums, and functions across dozens of files becomes error-prone and hard to maintain. Class and enum definitions must appear before the code that references them — base classes before derived classes, enums before the classes that use them, classes before the functions that depend on them.

**The Solution**

PSScriptBuilder analyzes your source files using PowerShell's AST, resolves all dependencies automatically, and combines everything into a single, correctly ordered, deployable script — no manual sorting required.

## Features

- **Automatic Dependency Ordering** — AST analysis resolves class inheritance and type dependencies; output is always in valid load order
- **Cycle Detection** — Detects fatal circular dependencies (inheritance, static initializers) before any output is written; type reference cycles are resolved automatically
- **Cross-Dependency Support** — Detects when classes and functions must be interleaved and switches to a unified ordered output block automatically
- **Flexible Templates** — Define your output structure once using a template with token placeholders; supports any output format (.psm1, .ps1, .txt)
- **Multiple Collectors** — Dedicated collectors for Classes, Functions, Enums, Using statements, and raw Files
- **Project Scaffolding** — Generates a ready-to-build project structure with sample source files and a build script
- **Script Compression** — Strips comments and blank lines from the built output for lean, deployable scripts
- **Release Management** — Built-in SemVer version bumping, Git metadata extraction, and file update automation
- **PowerShell 5.1 and 7+ Compatible** — Runs on Windows PowerShell 5.1 and PowerShell 7+ (Windows, Linux, macOS)

## Getting Started

PSScriptBuilder is available on the PowerShell Gallery and requires `using module` for import.

**1. Install**

```powershell
Install-Module -Name PSScriptBuilder -Scope CurrentUser
```

**2. Import**

> **Note:** Always use `using module` — not `Import-Module`. PowerShell only loads
> class and enum definitions with `using module`. The `using` statement must appear
> at the very top of your script, before any other code.

✅ Correct:

```powershell
using module PSScriptBuilder
```

❌ Wrong — classes and enums will NOT be available:

```powershell
Import-Module PSScriptBuilder
```

## Quick Start

After importing the module, follow the path that matches your situation.

---

### New Project

**1. Scaffold**

```powershell
New-PSScriptBuilderProject -Name "MyProject" -Path "C:\Projects"
cd "C:\Projects\MyProject"
```

**2. Build** *(runs the generated build script with sample source files)*

```powershell
.\Build-MyProject.ps1
```

---

### Existing Project

**1. Create configuration** *(first-time setup)*

```powershell
New-PSScriptBuilderConfiguration
```

**2. Configure collectors**

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Public"
```

**3. Build**

```powershell
Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     "build/MyModule.psm1.template" `
    -OutputPath       "build/Output/MyModule.psm1"
```

> **Note:** PSScriptBuilder resolves relative paths (like `src/Classes`) against the project root.
> Run these commands from your project directory, or call
> `Set-PSScriptBuilderProjectRoot -Path "C:\Projects\MyProject"` first to set it explicitly.

---

## Examples

Fourteen runnable examples are included in the [`examples/`](examples/) directory, covering scenarios from simple function builds to full release workflows with scaffolding and compression.

See the [Examples page](https://docs.psscriptbuilder.com/examples/) for descriptions and walkthroughs.

## Collector Types

PSScriptBuilder provides five collector types, each targeting a specific PowerShell component.

| Type       | Description                                                    |
|------------|----------------------------------------------------------------|
| `Using`    | Collects `using` statements                                    |
| `Enum`     | Collects enumeration definitions                               |
| `Class`    | Collects class definitions with dependency order               |
| `Function` | Collects standalone function definitions with dependency order |
| `File`     | Includes complete file contents as-is                          |

Each collector accepts `-IncludePath`, `-ExcludePath`, `-IncludeFile`, `-ExcludeFile`, `-FileExtension`, and an optional `-CollectionKey` for use as a template token.

See the [Collectors Guide](https://docs.psscriptbuilder.com/guides/collectors/) for details on filtering, custom keys, and advanced collector configuration.

## Template System

PSScriptBuilder uses plain text template files with `{{Token}}` placeholders to define the structure of the output file — supporting any extension (`.psm1`, `.ps1`, `.txt`, etc.).

Default `CollectionKey` per collector type:

| Collector Type | Default Token              |
|----------------|----------------------------|
| `Using`        | `{{USING_STATEMENTS}}`     |
| `Enum`         | `{{ENUM_DEFINITIONS}}`     |
| `Class`        | `{{CLASS_DEFINITIONS}}`    |
| `Function`     | `{{FUNCTION_DEFINITIONS}}` |
| `File`         | `{{FILE_CONTENTS}}`        |

Example template (`build/MyModule.psm1.template`):

```powershell
{{USING_STATEMENTS}}

{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}

{{FILE_CONTENTS}}
```

Use `-CollectionKey` on `Add-PSScriptBuilderCollector` to define a custom token name, e.g. `{{DOMAIN_CLASSES}}`.

### Ordered and Hybrid Mode

When classes and functions have mutual dependencies that require interleaving in the output, PSScriptBuilder automatically switches to **Ordered Mode**. Replace the individual per-type placeholders with a single `{{ORDERED_COMPONENTS}}` token:

```powershell
{{USING_STATEMENTS}}
{{ORDERED_COMPONENTS}}
```

**Hybrid Mode** lets you adopt this layout proactively — even when no cross-dependencies currently exist — making the template resilient to future dependency changes without restructuring. See the [Templates Guide](https://docs.psscriptbuilder.com/guides/templates/) for details.

## Release Management

PSScriptBuilder includes cmdlets for SemVer version management, Git metadata extraction, and automated file updates.

```powershell
# Bump the version (Major / Minor / Patch)
Update-PSScriptBuilderReleaseData -Minor

# Propagate version tokens across all registered files
Update-PSScriptBuilderBumpFiles

# Then run your build
Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     "build/MyModule.psm1.template" `
    -OutputPath       "build/Output/MyModule.psm1"
```

See the [Release Management Guide](https://docs.psscriptbuilder.com/guides/release-management/) for details on bump configuration, token replacement, and the full release pipeline.

## Build from Source

To build the module from source, clone the repository and run the build script.

```powershell
git clone https://github.com/PSScriptBuilder/PSScriptBuilder.git
cd PSScriptBuilder

.\build.ps1 -ProjectRoot $PWD
```

## Contributing

This GitHub repository is a mirror of the primary development repository hosted on GitLab.
Pull requests submitted here will not be merged.
Please use [GitHub Issues](https://github.com/PSScriptBuilder/PSScriptBuilder/issues) for bug reports and feature requests.

For code conventions, testing instructions, and contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

## See Also

[ModuleBuilder](https://github.com/PoshCode/ModuleBuilder) — a simpler alternative for projects that do not require class dependency ordering.

## Changelog

See [CHANGELOG.md](https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/CHANGELOG.md).

## License

MIT — see [LICENSE](https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/LICENSE).

## Author

**Tim Hartling**

For questions, bug reports, or feature requests, please open an [Issue](https://github.com/PSScriptBuilder/PSScriptBuilder/issues) on GitHub.
