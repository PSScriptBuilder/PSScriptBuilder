# New-PSScriptBuilderReleaseData

Creates a new release data file with default values.

## Description

Creates `psscriptbuilder.releasedata.json` (path read from the loaded PSScriptBuilder
configuration) with SemVer's starting defaults — `0.1.0`, build number `0`, and every
timestamp/Git field left `$null` until explicitly refreshed. See
[Set Up the Release Data File](../guides/release-management.md#1-set-up-the-release-data-file)
for the full resulting file and what each field means.

Fails with an error if the file already exists, unless `-Force` is specified.

This cmdlet also supports `-WhatIf` and `-Confirm` (PowerShell's `ShouldProcess` pattern).

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Force` | switch | Overwrite the release data file if it already exists. |

## Examples

### Create the release data file

```powershell
New-PSScriptBuilderReleaseData
```

### Preview without writing

```powershell
New-PSScriptBuilderReleaseData -WhatIf
```

### Reinitialize an existing project

```powershell
New-PSScriptBuilderReleaseData -Force
```

## Output

Returns the same hierarchical structure
[`Get-PSScriptBuilderReleaseData`](Get-PSScriptBuilderReleaseData.md) returns by default,
describing the newly created release data.

## See Also

- [Release Management Guide](../guides/release-management.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseData](Get-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Update-PSScriptBuilderReleaseData](Update-PSScriptBuilderReleaseData.md)
