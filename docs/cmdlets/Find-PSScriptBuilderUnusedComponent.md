# Find-PSScriptBuilderUnusedComponent

Finds unused components in a PSScriptBuilder content collector configuration.

## Description

Analyzes the dependency graph to find `Enum`, `Class`, and `Function` components nothing else
references — in two modes:

- **Without `-EntryPoint`**: reports every component with no incoming dependency edge at all.
  Since public cmdlets are only ever called from outside the graph, they always appear "unused"
  in this mode — a false positive, not a real finding.
- **With `-EntryPoint`**: performs a transitive reachability analysis from every component whose
  name matches one of the given glob patterns, and reports everything unreachable from any of
  them. Passing every public cmdlet as an entry point removes the false-positive noise from the
  first mode and answers the real question: is there anything even the public API can't reach?

If the dependency graph contains a cycle, a warning is emitted, and components inside that cycle
may not be reported as unused — they reference each other, so each has an incoming edge.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The collector set to analyze. Accepts pipeline input, enabling fluent chaining from `Add-PSScriptBuilderCollector`. |
| `-EntryPoint` | string[] | Glob patterns (`*`, `?`, matched case-insensitively) identifying entry point components. Only components unreachable from a match are reported. Without this, every component with no incoming edge is reported. |

## Examples

### Find dead code relative to the public API

```powershell
$unused = $contentCollector | Find-PSScriptBuilderUnusedComponent -EntryPoint '*-PSScriptBuilder*'
Write-Host "Unreachable from the public API: $($unused.Count)"
```

```text title="Output"
Unreachable from the public API: 0
```

### Find components with no incoming dependencies at all

```powershell
$results = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes"   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Functions" |
    Find-PSScriptBuilderUnusedComponent
```

Useful for a class-only project without public cmdlets, where the entry-point false positive
from the first mode doesn't apply.

## Output

Returns an array of
[`PSScriptBuilderUnusedComponentEntry`](../reference/types.md#psscriptbuilderunusedcomponententry),
one per component found unused.

## See Also

- [Dependency Analysis Guide: Dead Code Detection](../guides/dependency-analysis.md#dead-code-detection)
- [Cmdlet Reference: Get-PSScriptBuilderDependencyAnalysis](Get-PSScriptBuilderDependencyAnalysis.md)
