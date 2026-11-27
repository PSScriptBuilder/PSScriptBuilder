# New-PSScriptBuilderContentCollector

Creates a new content collector for managing multiple component collectors.

## Description

Creates an empty `PSScriptBuilderContentCollector` that manages a collection of component
collectors (`Using`, `Enum`, `Class`, `Function`, `File`), orchestrates their execution, and
provides centralized access to what they collect.

Populate it either by piping it into [`Add-PSScriptBuilderCollector`](Add-PSScriptBuilderCollector.md)
one collector at a time, or by passing pre-created collectors up front via `-Collector`. Every
collector's `CollectionKey` must be unique — a duplicate throws an error immediately, whichever
way it was added.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Collector` | `PSScriptBuilderCollectorBase[]` | Pre-created collector instances (see [`New-PSScriptBuilderCollector`](New-PSScriptBuilderCollector.md)) to initialize the ContentCollector with. |

## Examples

### Populate via the pipeline

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey "FUNCTIONS" -IncludePath "src\Public"
```

### Pre-populate with collectors created up front

```powershell
$collectors = @(
    New-PSScriptBuilderCollector -Type Using -CollectionKey "USINGS" -IncludePath "src"
    New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src\Classes"
    New-PSScriptBuilderCollector -Type Function -CollectionKey "FUNCTIONS" -IncludePath "src\Public"
)
$contentCollector = New-PSScriptBuilderContentCollector -Collector $collectors
```

## Output

Returns a [`PSScriptBuilderContentCollector`](../reference/types.md#collectors) object.

## Notes

- Collectors execute in a fixed order regardless of registration order — `Using`, `Enum`,
  `Class`, `Function`, `File` — see [Execution Order](../guides/collectors.md#execution-order).

## See Also

- [Collectors Guide](../guides/collectors.md)
- [Cmdlet Reference: New-PSScriptBuilderCollector](New-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Add-PSScriptBuilderCollector](Add-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Get-PSScriptBuilderCollector](Get-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Remove-PSScriptBuilderCollector](Remove-PSScriptBuilderCollector.md)
