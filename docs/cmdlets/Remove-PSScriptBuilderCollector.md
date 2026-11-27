# Remove-PSScriptBuilderCollector

Removes a collector from a ContentCollector.

## Description

Removes the collector matching `-CollectionKey` from a `ContentCollector`, and returns the same
`ContentCollector` for further pipeline chaining.

If no collector with that key exists, the cmdlet writes a warning rather than an error — safe to
call from a cleanup or idempotent script even if the collector was already removed. This is a
RAM-only change: nothing on disk is affected, and the collector can always be re-registered later
with [`Add-PSScriptBuilderCollector`](Add-PSScriptBuilderCollector.md).

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The ContentCollector to remove the collector from. Accepts pipeline input, enabling fluent chaining. |
| `-CollectionKey` | string | **Required.** The exact key (case-insensitive) of the collector to remove. |

## Examples

### Remove a collector via the pipeline

```powershell
$contentCollector | Remove-PSScriptBuilderCollector -CollectionKey "TEMP_FUNCTIONS"
```

### Replace a collector in a single pipeline

```powershell
$contentCollector = $contentCollector |
    Remove-PSScriptBuilderCollector -CollectionKey "TEMP" |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\New"
```

### Remove every collector matching a key pattern

```powershell
$collectorsToRemove = Get-PSScriptBuilderCollector -ContentCollector $contentCollector |
    Where-Object { $_.CollectionKey -like "TEMP_*" }

foreach ($collector in $collectorsToRemove) {
    $contentCollector = Remove-PSScriptBuilderCollector -ContentCollector $contentCollector -CollectionKey $collector.CollectionKey
}
```

## Output

Returns the same [`PSScriptBuilderContentCollector`](../reference/types.md#collectors) passed in
via `-ContentCollector` — always, even when the key wasn't found.

## See Also

- [Collectors Guide](../guides/collectors.md)
- [Cmdlet Reference: Add-PSScriptBuilderCollector](Add-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Get-PSScriptBuilderCollector](Get-PSScriptBuilderCollector.md)
