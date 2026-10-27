# Get-PSScriptBuilderCollector

Retrieves collectors from a ContentCollector.

## Description

Retrieves one or more collectors registered on a `ContentCollector`. Without `-CollectionKey` or
`-Type`, returns every registered collector, sorted by `CollectorType` (`Using`, `Enum`, `Class`,
`Function`, `File`) — the same order they execute in during a build (see
[Execution Order](../guides/collectors.md#execution-order)).

Returns the actual collector objects (not simplified copies), so the result can be inspected
directly (`.IncludePaths`, `.ExcludePaths`, etc.), piped straight into
[`Remove-PSScriptBuilderCollector`](Remove-PSScriptBuilderCollector.md), or passed to
[`Get-PSScriptBuilderCollectorContent`](Get-PSScriptBuilderCollectorContent.md) for data
inspection.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The ContentCollector to query. Accepts pipeline input. |
| `-CollectionKey` | string | Returns only the collector with this exact key (case-insensitive). If no collector has this key, writes a non-terminating error and returns `$null`. |
| `-Type` | `PSScriptBuilderCollectorType` | Returns every collector of this type: `UsingCollector`, `EnumCollector`, `ClassCollector`, `FunctionCollector`, or `FileCollector`. Matches collectors of the same type registered under different keys (e.g. `"CLASSES_DOMAIN"`, `"CLASSES_UTILS"`). |

`-CollectionKey` and `-Type` select collectors two different ways — one exact collector by its
unique key, or every collector of a given type — and cannot be combined; passing both together is
rejected by PowerShell's own parameter binding.

## Examples

### Retrieve all collectors

```powershell
$contentCollector | Get-PSScriptBuilderCollector
```

### Retrieve one collector by key

```powershell
Get-PSScriptBuilderCollector -ContentCollector $contentCollector -CollectionKey "CLASSES"
```

### Retrieve every collector of a given type

```powershell
Get-PSScriptBuilderCollector -ContentCollector $contentCollector -Type ClassCollector
```

### Inspect a specific collector's configuration

```powershell
$classCollector = Get-PSScriptBuilderCollector -ContentCollector $contentCollector -CollectionKey "CLASSES"
$classCollector.IncludePaths
```

### Find collectors missing an IncludePath

```powershell
Get-PSScriptBuilderCollector -ContentCollector $contentCollector |
    Where-Object { -not $_.IncludePaths -or $_.IncludePaths.Count -eq 0 }
```

## Output

- Every registered collector as a
  [`PSScriptBuilderCollectorBase`](../reference/types.md#psscriptbuildercollectorbase)`[]`,
  sorted by `CollectorType`, when neither `-CollectionKey` nor `-Type` is passed
- A single `PSScriptBuilderCollectorBase`-derived object when `-CollectionKey` is passed
- A `PSScriptBuilderCollectorBase[]` filtered by type when `-Type` is passed

## See Also

- [Collectors Guide](../guides/collectors.md)
- [Cmdlet Reference: Add-PSScriptBuilderCollector](Add-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Remove-PSScriptBuilderCollector](Remove-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Get-PSScriptBuilderCollectorContent](Get-PSScriptBuilderCollectorContent.md)
