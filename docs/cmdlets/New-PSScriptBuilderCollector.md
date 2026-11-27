# New-PSScriptBuilderCollector

Creates a new collector for PowerShell script components.

## Description

Creates a standalone collector instance for extracting one specific kind of PowerShell component
— using statements, enums, classes, functions, or entire file contents — from source files. Use
it on its own to explore or inspect a codebase, or pass it to
[`New-PSScriptBuilderContentCollector`](New-PSScriptBuilderContentCollector.md) or
[`Add-PSScriptBuilderCollector`](Add-PSScriptBuilderCollector.md) to include it in a build.

A non-existent `-IncludePath` produces a warning, not an error, at creation time — the collector
is still created, to support paths that are generated later. See
[File Resolution Rules](../guides/collectors.md#file-resolution-rules) for the full behavior,
including what happens if the path is still missing once the collector actually runs.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Type` | string | **Required.** One of `Using`, `Enum`, `Class`, `Function`, `File` — see [Collector Types](../guides/collectors.md#collector-types). |
| `-CollectionKey` | string | Unique identifier for this collector, and the template placeholder name it corresponds to. Defaults to the type's own default key (see [Default Keys and Tokens](../guides/collectors.md#default-keys-and-tokens)) if not specified. |
| `-IncludePath` | string[] | Directories to scan. Relative to the project root or absolute. |
| `-IncludeFile` | string[] | Specific files or glob patterns to include, bypassing `-ExcludePath`/`-ExcludeFile`. |
| `-ExcludePath` | string[] | Directories excluded from scanning. Takes precedence over `-IncludePath`. |
| `-ExcludeFile` | string[] | File name patterns excluded from scanning. |
| `-FileExtension` | string[] | File extensions to scan. Default: `@(".ps1")`. |
| `-NoRecurse` | switch | Scan only the top-level directory of each `-IncludePath` instead of recursing. |

## Examples

### Create a collector with the default key

```powershell
New-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes"
```

### Create a collector with a custom key

```powershell
New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src\Classes"
```

### Include a file that would otherwise be excluded

```powershell
New-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" `
    -ExcludeFile "*.Internal.ps1" -IncludeFile "src\Classes\Legacy.Internal.ps1"
```

### Exclude a subdirectory

```powershell
New-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" `
    -IncludePath "src\Classes" -ExcludePath "src\Classes\Legacy"
```

## Output

Returns a [`PSScriptBuilderCollectorBase`](../reference/types.md#psscriptbuildercollectorbase)-derived
object (the concrete type matches `-Type`). Calling `.Collect()` on it populates a type-specific
data property — `.FunctionData` for a `Function` collector, `.ClassData` for a `Class` collector,
and so on — with entries of the corresponding
[Collected Data Type](../reference/types.md#collected-data-types).

## See Also

- [Collectors Guide](../guides/collectors.md)
- [Cmdlet Reference: New-PSScriptBuilderContentCollector](New-PSScriptBuilderContentCollector.md)
- [Cmdlet Reference: Add-PSScriptBuilderCollector](Add-PSScriptBuilderCollector.md)
- [Cmdlet Reference: Get-PSScriptBuilderCollectorContent](Get-PSScriptBuilderCollectorContent.md)
