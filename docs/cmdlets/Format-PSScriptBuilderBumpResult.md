# Format-PSScriptBuilderBumpResult

Formats and displays the result of a bump operation.

## Description

Renders a `PSScriptBuilderBumpFilesResult`'s changes as a human-readable summary, one section per
modified file, listing each change's token, old value, and new value. Displays a message instead
if no files were modified.

The `Pattern` line is shown only when it differs from `Old Value`: Simple and Placeholder Mode
always set them equal, so showing both would be redundant; Regex Mode's `Pattern` (the
`{REGEX_TOKEN}` config template) legitimately differs from the actual matched value, so it's
always shown there.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-BumpResult` | `PSScriptBuilderBumpFilesResult` | **Required.** The result to display, typically piped directly from [`Update-PSScriptBuilderBumpFiles`](Update-PSScriptBuilderBumpFiles.md). |

## Examples

### Display what a bump run changed

```powershell
Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult
```

## Output

None — writes directly to the host with `Write-Host`.

## See Also

- [Release Management Guide](../guides/release-management.md#12-apply-tokens-to-project-files)
- [Cmdlet Reference: Update-PSScriptBuilderBumpFiles](Update-PSScriptBuilderBumpFiles.md)
