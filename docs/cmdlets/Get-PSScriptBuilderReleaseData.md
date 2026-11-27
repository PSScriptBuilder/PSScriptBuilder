# Get-PSScriptBuilderReleaseData

Retrieves the current release data configuration.

## Description

Loads `psscriptbuilder.releasedata.json` without modifying it — version, build metadata, and Git
information. By default, returns a **hierarchical object** with `Version`, `Build`, and `Git`
sections, ideal when only one section is needed. Use `-Flat` for a **flat object** instead, with
every property prefixed by category (`Version*`, `Build*`, `Git*`) — more convenient for
enumerating every property uniformly or passing all values to another function.

Both forms are `OrderedDictionary` objects that preserve categorical order; sort either with
`GetEnumerator() | Sort-Object -Property Key`.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Flat` | switch | Return a flat, prefixed structure instead of the default hierarchical one. |

## Examples

### Read one section of the hierarchical object

```powershell
$data = Get-PSScriptBuilderReleaseData
Write-Host "Number:    $($data.Build.Number)"
Write-Host "Timestamp: $($data.Build.Timestamp)"
```

```text title="Output"
Number:    1
Timestamp: 2026-09-14T14:18:03Z
```

### Read the flat object

```powershell
$flat = Get-PSScriptBuilderReleaseData -Flat
Write-Host "Version:     $($flat.VersionFull)"
Write-Host "CommitShort: $($flat.GitCommitShort)"
```

```text title="Output"
Version:     0.1.1
CommitShort: 55d9437
```

## Output

Returns a `System.Collections.Specialized.OrderedDictionary` — hierarchical (`Version`, `Build`,
`Git` sections) by default, or flat with prefixed property names when `-Flat` is specified.

## See Also

- [Release Management Guide](../guides/release-management.md#5-read-release-data)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseDataTokens](Get-PSScriptBuilderReleaseDataTokens.md)
- [Cmdlet Reference: Update-PSScriptBuilderReleaseData](Update-PSScriptBuilderReleaseData.md)
