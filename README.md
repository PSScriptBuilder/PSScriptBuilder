# PSScriptBuilder

<img src="https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/assets/banner.png" alt="PSScriptBuilder" width="750">

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSScriptBuilder)](https://www.powershellgallery.com/packages/PSScriptBuilder)
[![Downloads](https://img.shields.io/powershellgallery/dt/PSScriptBuilder.svg)](https://www.powershellgallery.com/packages/PSScriptBuilder)
[![Platform](https://img.shields.io/powershellgallery/p/PSScriptBuilder.svg)](https://www.powershellgallery.com/packages/PSScriptBuilder)

[![powershell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![website](https://img.shields.io/badge/website-psscriptbuilder.com-blue)](https://psscriptbuilder.com)
[![documentation](https://img.shields.io/badge/documentation-docs.psscriptbuilder.com-blue)](https://docs.psscriptbuilder.com)

A dependency-aware script builder for PowerShell. Combines multi-file PowerShell projects into a single, deployable script with automatic dependency resolution, topological sorting, and full support for classes, enums, and functions.

**The Problem:** PowerShell class definitions must appear in the correct order in a script file — base classes before derived classes, dependencies before dependents. Managing this manually across dozens of files is error-prone and breaks as the project grows. PSScriptBuilder solves this automatically using AST analysis.

## Features

- **Automatic Dependency Ordering** - AST analysis resolves class inheritance and type dependencies; output is always in valid load order — no manual sorting required
- **Cycle Detection** - Detects fatal circular dependencies (inheritance, static initializers) before any output is written; type reference cycles are resolved automatically
- **Cross-Dependency Support** - Detects when classes and functions must be interleaved and switches to a unified ordered output block automatically
- **Flexible Templates** - Define your output structure once using a template with token placeholders; supports any output format (.psm1, .ps1, .txt)
- **Multiple Collectors** - Dedicated collectors for Classes, Functions, Enums, Using statements, and raw Files
- **Release Management** - Built-in SemVer version bumping, Git metadata extraction, and file update automation
- **PS 5.1 and 7+ Compatible** - Runs on Windows PowerShell 5.1 and PowerShell 7+ (Windows, Linux, macOS)

## Installation

```powershell
Install-Module -Name PSScriptBuilder -Scope CurrentUser
```

## Important: Module Import

**Always use `using module` -- not `Import-Module` -- to import PSScriptBuilder.**

```powershell
# Correct -- classes and enums are available
using module PSScriptBuilder

# Wrong -- classes and enums will NOT be available
Import-Module PSScriptBuilder
```

PowerShell only loads class and enum definitions when a module is imported with `using module`.
The `using` statement must appear at the very top of your script, before any other code.

## Quick Start

**1. Install and import**

```powershell
Install-Module -Name PSScriptBuilder
using module PSScriptBuilder
```

**2. Create configuration** *(first-time setup)*

```powershell
New-PSScriptBuilderConfiguration
```

**3. Configure collectors**

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Public"
```

**4. Build**

```powershell
Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     "build/MyModule.psm1.template" `
    -OutputPath       "build/Output/MyModule.psm1"
```

> **Note:** PSScriptBuilder resolves relative paths (like `src/Classes`) against the project root.
> Run these commands from your project directory, or call
> `Set-PSScriptBuilderProjectRoot -Path "C:\Projects\MyModule"` first to set it explicitly.

## Collector Types

| Type       | Description                                      |
|------------|--------------------------------------------------|
| `Using`    | Collects `using` statements                      |
| `Enum`     | Collects enumeration definitions                 |
| `Class`    | Collects class definitions with dependency order |
| `Function` | Collects standalone function definitions         |
| `File`     | Includes complete file contents as-is            |

Each collector accepts `-IncludePath`, `-ExcludePath`, `-IncludeFile`, `-ExcludeFile`, and an optional `-CollectionKey` for use as a template token.

See the [Collectors Guide](https://docs.psscriptbuilder.com/guides/collectors/) for details on filtering, custom keys, and advanced collector configuration.

## Template System

A template is any plain text file with `{{Token}}` placeholders. The output file can have any extension (`.psm1`, `.ps1`, `.txt`, etc.) — PSScriptBuilder simply replaces each placeholder with the correctly ordered, resolved content of the corresponding collector.

Default `CollectionKey` per collector type:

| Collector Type | Default Token              |
|----------------|----------------------------|
| `Using`        | `{{USING_STATEMENTS}}`      |
| `Enum`         | `{{ENUM_DEFINITIONS}}`      |
| `Class`        | `{{CLASS_DEFINITIONS}}`     |
| `Function`     | `{{FUNCTION_DEFINITIONS}}`  |
| `File`         | `{{FILE_CONTENTS}}`         |

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

PSScriptBuilder includes cmdlets for SemVer version management:

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

## Building from Source

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

## Related Tools

PSScriptBuilder focuses on script building and pairs well with:

- **[Invoke-Build](https://github.com/nightroman/Invoke-Build)** - a general-purpose task runner that orchestrates the full build pipeline; PSScriptBuilder fits naturally as one step within it
- **[Pester](https://pester.dev)** - the standard PowerShell testing framework; use alongside PSScriptBuilder to test the generated output
- **[ModuleBuilder](https://github.com/PoshCode/ModuleBuilder)** - covers similar ground for simpler projects; choose PSScriptBuilder when your project uses class inheritance or requires dependency-aware ordering

## Changelog

See [CHANGELOG.md](https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/CHANGELOG.md).

## License

MIT — see [LICENSE](https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/LICENSE).

## Author

**Tim Hartling**

For questions, bug reports, or feature requests, please open an [Issue](https://github.com/PSScriptBuilder/PSScriptBuilder/issues) on GitHub.