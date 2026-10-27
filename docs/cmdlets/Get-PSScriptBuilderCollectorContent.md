# Get-PSScriptBuilderCollectorContent

Retrieves collected data from a collector.

## Description

Runs `.Collect()` on the given collector, then returns everything it collected — classes,
functions, enums, using statements, or file contents, depending on the collector's type — as the
matching [Collected Data Type](../reference/types.md#collected-data-types)
(`PSScriptBuilderClassData`, `PSScriptBuilderFunctionData`, and so on).

Without `-ItemName`, every collected item is returned. With `-ItemName`, only the item matching
that name is returned (case-insensitive) — a class or function name, an enum name, a `using`
statement's exact text, or a file name, depending on the collector's type.

Mainly useful for inspection and debugging while developing a project's collector configuration —
a real build processes the collected data itself, without needing to call this cmdlet.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Collector` | `PSScriptBuilderCollectorBase` | **Required.** The collector to retrieve data from — typically obtained from [`Get-PSScriptBuilderCollector`](Get-PSScriptBuilderCollector.md) or created directly with [`New-PSScriptBuilderCollector`](New-PSScriptBuilderCollector.md). Accepts pipeline input. |
| `-ItemName` | string | Returns only the item with this name (case-insensitive), instead of every collected item. |

## Examples

### Retrieve everything a collector found

```powershell
$classCollector | Get-PSScriptBuilderCollectorContent |
    Where-Object { $_.BaseClass -eq "PSScriptBuilderBase" }
```

### Retrieve one item by name

```powershell
$baseClass = Get-PSScriptBuilderCollectorContent -Collector $classCollector -ItemName "PSScriptBuilderBase"
Write-Host $baseClass.SourceCode
```

### Validate that all expected components were collected

```powershell
$functions = Get-PSScriptBuilderCollectorContent -Collector $functionCollector
$expected = @("Get-Data", "Set-Data", "Remove-Data")
$missing = $expected | Where-Object { $_ -notin $functions.Name }

if ($missing) {
    throw "Missing functions: $($missing -join ', ')"
}
```

### Check whether a collector found anything at all

```powershell
$collector = Get-PSScriptBuilderCollector -ContentCollector $contentCollector -CollectionKey "FUNCTIONS"
$content = Get-PSScriptBuilderCollectorContent -Collector $collector

if ($content.Count -eq 0) {
    Write-Warning "No functions collected. Check IncludePaths configuration."
}
```

### Inspect using statements and where they were found

```powershell
$usingData = Get-PSScriptBuilderCollectorContent -Collector $usingCollector

foreach ($using in $usingData) {
    Write-Host "Statement: $($using.Statement)"
    Write-Host "  Found in $($using.SourceFiles.Count) file(s):"
    $using.SourceFiles | ForEach-Object { Write-Host "    - $_" }
}
```

## Output

Always returns an array of the [Collected Data Type](../reference/types.md#collected-data-types)
matching the collector's `CollectorType` — for example `PSScriptBuilderClassData[]` for a `Class`
collector — even when `-ItemName` narrows the result to a single item.

## See Also

- [Collectors Guide](../guides/collectors.md)
- [Cmdlet Reference: Get-PSScriptBuilderCollector](Get-PSScriptBuilderCollector.md)
- [Cmdlet Reference: New-PSScriptBuilderCollector](New-PSScriptBuilderCollector.md)
