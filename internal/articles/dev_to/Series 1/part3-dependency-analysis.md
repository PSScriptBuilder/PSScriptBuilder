---
title: How PSScriptBuilder Analyzes PowerShell Dependencies — and What Happens When They Form a Cycle
series: Automating PowerShell Projects with PSScriptBuilder
tags: powershell, devtools, automation, opensource
cover_image: https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/images/platforms/devto/features-banner.png
published: true
---

If you've read [the first article in this series](https://dev.to/tim_hartling/stop-manually-sorting-powershell-class-files-psscriptbuilder-does-it-for-you-2dok), you already know that PSScriptBuilder resolves PowerShell class load order automatically. This article goes one level deeper: what exactly does PSScriptBuilder analyze, how does it build a dependency graph, and what happens when that graph contains a cycle?

## What PSScriptBuilder Extracts

When PSScriptBuilder processes your source files, it runs AST analysis on every collected component and extracts the following dependency information:

| Component | Dependencies extracted |
|---|---|
| Class | Base class, type references (properties, method parameters), static initializer references, called functions |
| Function | Called functions, type references |
| Enum | None — enums have no outgoing dependencies and always appear first |

Built-in types (`string`, `int`, `bool`, `System.*`, etc.) are automatically excluded — only types that are part of your project create graph edges.

## The Dependency Graph

The extracted dependencies form a directed graph where each node is a component and each edge represents a dependency. An edge from `Employee` to `Person` means: `Employee` depends on `Person`, so `Person` must appear first in the output.

Consider this example:

```powershell
class Employee : Person {
    [Address] $Address
    [decimal] $Salary
}
```

PSScriptBuilder extracts two edges from this class:

- `Employee` --[inherits]--> `Person`
- `Employee` --[type reference]--> `Address`

Both `Person` and `Address` must appear before `Employee` in the output. PSScriptBuilder applies topological sorting to the full graph and determines the correct order for all components automatically — regardless of file or directory order.

You can inspect the dependency graph at any time:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src/Classes"

$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector

Write-Host "Components : $($analysis.TotalComponents)"
Write-Host "Has cycles : $($analysis.HasCycles)"
```

## Not All Cycles Are Equal

PSScriptBuilder distinguishes two fundamentally different types of cycles — and only one of them is a problem.

### Fatal Cycles

A cycle is fatal when it creates an unresolvable ordering constraint at PowerShell load time. PowerShell processes type definitions from top to bottom before any code runs. Two dependency types create this hard constraint:

**Inheritance** — a base class must be fully defined before any class that inherits from it can be loaded. If two classes inherit from each other — directly or through a chain — there is no valid order:

```powershell
class ServiceA : ServiceB { }  # requires ServiceB first
class ServiceB : ServiceC { }  # requires ServiceC first
class ServiceC : ServiceA { }  # requires ServiceA first — impossible
```

**Static property initializers** — static initializers run immediately when a class is loaded, not when a method is called. A type referenced in a static initializer must already be defined at load time — the same hard requirement as inheritance:

```powershell
class ClassA {
    static [ClassB] $Default = [ClassB]::new()  # runs when ClassA loads
}

class ClassB {
    static [ClassA] $Default = [ClassA]::new()  # runs when ClassB loads
}
```

Neither class can be loaded first. PSScriptBuilder catches both cycle types before writing any output.

### Type Reference Cycles — Not Fatal

A type reference cycle occurs when two classes reference each other inside method bodies:

```powershell
class ClassA {
    [void] Process() { $b = [ClassB]::new() }
}

class ClassB {
    [void] Process() { $a = [ClassA]::new() }
}
```

This looks like a cycle — but it isn't a problem. Method bodies are not executed when the class is loaded; they only run when the method is called. By that time, all class definitions in the script have already been loaded. PSScriptBuilder recognizes this and handles it automatically — no error, no manual intervention required.

## When a Fatal Cycle Is Detected

When the `$contentCollector` points at classes that form a fatal cycle, `Get-PSScriptBuilderDependencyAnalysis` reports it immediately:

```powershell
$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector

if ($analysis.HasCycles) {
    Write-Host "Cycle path: $($analysis.CyclePath -join ' -> ')"
}
```

Output:

```plaintext
Cycle path: ServiceA -> ServiceB -> ServiceC -> ServiceA
```

If you call `Invoke-PSScriptBuilderBuild` directly, it fails fast with the same information:

```plaintext
Build failed: Circular dependency detected: ServiceA -> ServiceB -> ServiceC -> ServiceA
```

The full cycle path tells you exactly where to look. A fatal cycle always represents a structural problem in the code — PSScriptBuilder surfaces it clearly so you can fix it at the source.

Whether your project has only a few components or over a hundred — like PSScriptBuilder itself — PSScriptBuilder figures out the correct order and tells you immediately when a cycle makes that impossible.

For the full reference, see the [Dependency Analysis Guide](https://docs.psscriptbuilder.com/guides/dependency-analysis/).

## Get Started

```powershell
Install-Module -Name PSScriptBuilder
```

- Docs: [docs.psscriptbuilder.com](https://docs.psscriptbuilder.com/)
- GitHub: [github.com/PSScriptBuilder/PSScriptBuilder](https://github.com/PSScriptBuilder/PSScriptBuilder)

New to PSScriptBuilder? Start here: [Stop Manually Sorting PowerShell Class Files — PSScriptBuilder Does It For You](https://dev.to/tim_hartling/stop-manually-sorting-powershell-class-files-psscriptbuilder-does-it-for-you-2dok)

---

Have you run into dependency issues in your PowerShell projects? I'd be curious to hear how you've been handling them — or whether PSScriptBuilder covers your use case.
