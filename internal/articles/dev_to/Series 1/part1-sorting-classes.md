---
title: Stop Manually Sorting PowerShell Class Files — PSScriptBuilder Does It For You
series: Automating PowerShell Projects with PSScriptBuilder
tags: powershell, devtools, automation, opensource
cover_image: https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/images/platforms/devto/features-banner.png
published: true
---

If you've ever written a PowerShell module with classes, you know the pain:

```plaintext
Unable to find type [Employee].
```

PowerShell requires class definitions to appear in the correct order — base classes before derived classes, dependencies before dependents. In a single file with only a few classes, that's manageable. In a multi-file project with dozens of classes? It becomes a maintenance nightmare that only grows as the project does.

**PSScriptBuilder** solves this. It's a dependency-aware build tool that combines your multi-file PowerShell project into a single, deployable script — with class definitions automatically sorted into the correct load order using AST analysis.

## Installation

```powershell
Install-Module -Name PSScriptBuilder -Scope CurrentUser
```

PSScriptBuilder requires `using module` instead of `Import-Module` to make classes and enums available. The `using` statement must appear at the very top of your script, before any other code.

PSScriptBuilder runs on Windows PowerShell 5.1 and PowerShell 7+ (Windows, Linux, macOS). Generated output is fully PS 5.1 compatible — ideal for enterprise environments.

## Core Concepts

PSScriptBuilder has two building blocks:

**Collectors** define where your source files live. You configure one collector per source location and point it at a directory. Multiple collectors of the same type are fully supported — useful when your classes are spread across several directories that each need different filter rules.

**Templates** define the output structure. You create a template file with `{{Token}}` placeholders, and each placeholder is replaced by the collected, dependency-ordered source code of the corresponding collector.

## A Complete Example

Given this project structure:

```plaintext
MyModule/
├── src/
│   ├── Enums/
│   ├── Classes/
│   └── Public/
└── build/
    ├── Templates/
    │   └── MyModule.psm1.template
    └── Output/
```

**Step 1 — Generate the configuration file:**

```powershell
New-PSScriptBuilderConfiguration
```

This creates `psscriptbuilder.config.json` in your project root. PSScriptBuilder searches for it automatically starting from the current directory upward.

**Step 2 — Create a template:**

```powershell
{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

**Step 3 — Configure collectors and build:**

```powershell
using module PSScriptBuilder

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src/Enums"   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Public"

Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     "build/Templates/MyModule.psm1.template" `
    -OutputPath       "build/Output/MyModule.psm1"
```

PSScriptBuilder reads every source file, resolves all type dependencies via AST analysis, and writes a correctly ordered output file. If `Employee` inherits from `Person`, `Person` will always appear first — regardless of file or directory order.

## More Features

**Cycle detection** — Circular inheritance dependencies are caught before any output is written, with a clear error message showing the full cycle path.

**Cross-dependency handling** — When classes and functions have mutual dependencies, PSScriptBuilder detects this situation and reports it. You resolve it by replacing the separate `{{CLASS_DEFINITIONS}}` and `{{FUNCTION_DEFINITIONS}}` placeholders in your template with a single `{{ORDERED_COMPONENTS}}` token — PSScriptBuilder then outputs all components interleaved in the correct dependency order.

**Using statement deduplication** — If multiple source files contain the same `using namespace` or `using assembly` statements, PSScriptBuilder collects them via a dedicated `Using` collector and outputs each statement exactly once at the top of the script.

**Flexible filtering** — Collectors support include/exclude patterns, recursive or flat scanning, and custom file extensions:

```powershell
Add-PSScriptBuilderCollector -Type Class `
    -IncludePath   "src/Classes" `
    -ExcludeFile   "*.Tests.ps1" `
    -FileExtension ".ps1", ".psm1"
```

**Release management** — PSScriptBuilder includes a full release pipeline beyond simple version bumping. A release data file tracks your current SemVer version, build details, and Git metadata. You update it with `Update-PSScriptBuilderReleaseData`, which offers granular control over what gets refreshed — version bumping (`-Major`, `-Minor`, `-Patch`), build details (`-UpdateBuildDetails`), Git metadata (`-UpdateGitDetails`), or any combination in a single call.

A separate bump configuration file defines which files get updated and how. Each file can have multiple replacement rules — each rule uses a regex pattern to locate the value and a release data token (e.g. `{{VERSION_FULL}}`) to inject the new value. This means a single `Update-PSScriptBuilderReleaseData` call can update your `.psd1`, `README`, and version header simultaneously, each with its own pattern.

Consider this pattern: on the first bump, a static placeholder like `{{BUILD_TIMESTAMP}}` is replaced with the actual timestamp. On every subsequent bump, the regex matches the existing timestamp value and replaces it with the new one — no manual intervention, no config change between runs.

## Get Started

- **PSGallery:** `Install-Module -Name PSScriptBuilder`
- **Docs:** [docs.psscriptbuilder.com](https://docs.psscriptbuilder.com)
- **GitHub:** [github.com/PSScriptBuilder/PSScriptBuilder](https://github.com/PSScriptBuilder/PSScriptBuilder)

Have you run into load-order issues in your PowerShell projects? I'd love to hear how you've been handling it — or if PSScriptBuilder covers your use case.
