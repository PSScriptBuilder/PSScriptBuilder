# Add-PSScriptBuilderCollector

Adds a collector to a ContentCollector for fluent pipeline configuration.

## Description

Creates a collector and registers it on a
[`PSScriptBuilderContentCollector`](../reference/types.md#collectors) in one step — equivalent to
calling [`New-PSScriptBuilderCollector`](New-PSScriptBuilderCollector.md) and then its
`AddCollector()` method by hand. Returns the same `ContentCollector` it was given, so multiple
calls chain in a single pipeline expression.

Every collector's `-CollectionKey` must be unique within the `ContentCollector` — a duplicate
throws an error. To initialize a `ContentCollector` with several pre-created collectors at once
instead, use `-Collector` on
[`New-PSScriptBuilderContentCollector`](New-PSScriptBuilderContentCollector.md).

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The ContentCollector to add the collector to. Accepts pipeline input, enabling fluent chaining. |
| `-Type` | string | **Required.** One of `Using`, `Enum`, `Class`, `Function`, `File` — see [Collector Types](../guides/collectors.md#collector-types). |
| `-CollectionKey` | string | Unique identifier for the new collector, and the template placeholder name it corresponds to. Defaults to the type's own default key (see [Default Keys and Tokens](../guides/collectors.md#default-keys-and-tokens)) if not specified. |
| `-IncludePath` | string[] | Directories to scan. Relative to the project root or absolute. |
| `-IncludeFile` | string[] | Specific files or glob patterns to include, bypassing `-ExcludePath`/`-ExcludeFile`. |
| `-ExcludePath` | string[] | Directories excluded from scanning. Takes precedence over `-IncludePath`. |
| `-ExcludeFile` | string[] | File name patterns excluded from scanning. |
| `-FileExtension` | string[] | File extensions to scan. Default: `@(".ps1")`. |
| `-NoRecurse` | switch | Scan only the top-level directory of each `-IncludePath` instead of recursing. |

## Examples

### Chain multiple collectors onto a new ContentCollector

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey "FUNCTIONS" -IncludePath "src\Public"
```

### Add a single collector via the pipeline

```powershell
$contentCollector = New-PSScriptBuilderContentCollector
$contentCollector | Add-PSScriptBuilderCollector -Type Using -IncludePath "src"
```

### Add multiple collectors of the same type with different keys

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" `
        -IncludePath "src\Classes\Domain" -ExcludeFile "*.Internal.ps1" |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "UTILS" `
        -IncludePath "src\Classes\Utils"
```

## Output

Returns the same [`PSScriptBuilderContentCollector`](../reference/types.md#collectors) passed
in via `-ContentCollector`, with the new collector registered.

## See Also

- [Collectors Guide](../guides/collectors.md)
- [Cmdlet Reference: New-PSScriptBuilderContentCollector](New-PSScriptBuilderContentCollector.md)
- [Cmdlet Reference: New-PSScriptBuilderCollector](New-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Remove-PSScriptBuilderCollector](Remove-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Get-PSScriptBuilderCollector](Get-PSScriptBuilderCollector.md)
