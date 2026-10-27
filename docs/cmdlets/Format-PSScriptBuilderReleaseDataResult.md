# Format-PSScriptBuilderReleaseDataResult

Formats and displays the result of a release data update operation.

## Description

Renders a `PSScriptBuilderReleaseDataResult`'s changes as a human-readable summary, grouped by
category (`Version`, `Build`, `Git`) with each property's old and new value. Displays a message
instead if no changes were made.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ReleaseDataResult` | `PSScriptBuilderReleaseDataResult` | **Required.** The result to display, typically piped directly from [`Update-PSScriptBuilderReleaseData`](Update-PSScriptBuilderReleaseData.md). |

## Examples

### Display what a version bump changed

```powershell
Update-PSScriptBuilderReleaseData -Patch | Format-PSScriptBuilderReleaseDataResult
```

```text title="Output"
Category: Version

  Property  : patch
  Old Value : 0
  New Value : 1

  Property  : full
  Old Value : 0.1.0
  New Value : 0.1.1
```

## Output

None — writes directly to the host with `Write-Host`.

## See Also

- [Release Management Guide](../guides/release-management.md#2-bump-the-version)
- [Cmdlet Reference: Update-PSScriptBuilderReleaseData](Update-PSScriptBuilderReleaseData.md)
