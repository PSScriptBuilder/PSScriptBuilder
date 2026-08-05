---
title: When PowerShell Classes and Functions Depend on Each Other — How PSScriptBuilder Handles It
series: Automating PowerShell Projects with PSScriptBuilder
tags: powershell, devtools, automation, opensource
cover_image: https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/images/platforms/devto/features-banner.png
published: true
---

When you build a PowerShell project from multiple files, the natural structure is clear: enums first, then classes, then functions. Each group has its own place, and as long as dependencies only flow in one direction, that structure works perfectly.

But sometimes a function depends on a class, and that class calls the function. There is no longer a clean boundary between the two groups — they need to be interleaved in the output. That's a cross-dependency, and handling it manually is where things get fragile.

## What a Cross-Dependency Looks Like

Consider this scenario:

```powershell
# New-Report.ps1
function New-Report([ReportConfig] $config) {
    # uses ReportConfig as a parameter type
}

# ReportConfig.ps1
class ReportConfig {
    [string] $Title

    [void] Generate() {
        New-Report $this  # calls New-Report
    }
}
```

`New-Report` references `ReportConfig` as a parameter type — so `ReportConfig` must be defined before `New-Report` is loaded. But `ReportConfig` calls `New-Report` — so `New-Report` must appear before `ReportConfig`.

There is no single clean boundary between classes and functions anymore — they need to be interleaved in the output. That's exactly what PSScriptBuilder's Ordered Mode handles.

## PSScriptBuilder Detects It Automatically

PSScriptBuilder analyzes the full dependency graph of your project and detects whether classes and functions need to be interleaved in the output. You can check this before building:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes"    |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Functions"

$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector

Write-Host "Has cross-dependencies: $($analysis.HasCrossDependencies)"
```

Output:

```plaintext
Has cross-dependencies: True
```

## Free Mode, Ordered Mode, and Hybrid Mode

PSScriptBuilder selects a build mode based on the actual dependency structure of your project.

**Free Mode** applies when all enums, classes, and functions can be cleanly separated in the output — all enums first, then all classes in dependency order, then all functions. Each component type maps to its own placeholder in the template:

```plaintext
{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

**Ordered Mode** applies when cross-dependencies exist and classes and functions must be interleaved. A separate placeholder per component type is no longer sufficient — the output order cannot be determined until all dependencies are resolved globally. The template must use a single placeholder instead:

```plaintext
{{ORDERED_COMPONENTS}}
```

PSScriptBuilder then outputs all enums, classes, and functions in a single topologically-sorted block in the correct order.

**Hybrid Mode** applies when the template already uses `{{ORDERED_COMPONENTS}}` but no cross-dependencies exist. This is an opt-in configuration — useful when you anticipate future cross-dependencies, or simply prefer a single unified component block. PSScriptBuilder handles Hybrid Mode and Ordered Mode identically.

## Adapting the Template

When PSScriptBuilder detects cross-dependencies and the template still uses separate placeholders, the build fails with a clear error pointing to the required change.

The fix is straightforward — replace the separate placeholders with a single one:

```plaintext
# Before
{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}

# After
{{ORDERED_COMPONENTS}}
```

PSScriptBuilder takes care of the rest. The output will contain all components in the correct interleaved order — automatically, on every build.

You can also check the detected mode before building:

```powershell
$templateAnalysis = Get-PSScriptBuilderTemplateAnalysis `
    -ContentCollector $contentCollector `
    -TemplatePath     "build/Templates/MyScript.ps1.template"

Write-Host "Template mode: $($templateAnalysis.ValidationMode)"
```

Output:

```plaintext
Template mode: Ordered
```

No manual reordering, no fragile concatenation scripts — PSScriptBuilder resolves the interleaving and produces a correctly ordered output file on every run.

Whether your project has only a few components or over a hundred — like PSScriptBuilder itself — PSScriptBuilder figures out the correct structure and tells you immediately when the template needs to be adapted.

For the full reference, see the [Templates Guide](https://docs.psscriptbuilder.com/guides/templates/) and the [Dependency Analysis Guide](https://docs.psscriptbuilder.com/guides/dependency-analysis/).

## Get Started

```powershell
Install-Module -Name PSScriptBuilder
```

- Docs: [docs.psscriptbuilder.com](https://docs.psscriptbuilder.com/)
- GitHub: [github.com/PSScriptBuilder/PSScriptBuilder](https://github.com/PSScriptBuilder/PSScriptBuilder)

New to PSScriptBuilder? Start here: [Stop Manually Sorting PowerShell Class Files — PSScriptBuilder Does It For You](https://dev.to/tim_hartling/stop-manually-sorting-powershell-class-files-psscriptbuilder-does-it-for-you-2dok)

---

Have you run into cross-dependency issues in your PowerShell projects? I'd be curious to hear how you've been handling them — or whether PSScriptBuilder covers your use case.
