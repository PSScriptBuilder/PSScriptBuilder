# Update-PSScriptBuilderBumpFiles

Updates configured project files with current version information.

## Description

Applies the current release data's tokens to every file configured in
`psscriptbuilder.bumpconfig.json` — Simple Token Mode, Regex Pattern Mode, or a mix of both. See
[Apply Tokens to Project Files](../guides/release-management.md#12-apply-tokens-to-project-files)
for the full workflow, and [Configure Bump Files](../guides/release-management.md#7-configure-bump-files-simple-token-mode)
for how a file's tokens/patterns are set up in the first place.

Before writing any change to disk, a backup of each target file is created; if an error occurs
during processing, the originals are restored from their backups, leaving every project file in
a consistent state.

A warning is emitted for any configured file whose entries all failed to match its current
content — most commonly a Placeholder-mode entry with no Regex-mode fallback, already consumed by
an earlier run. Add a Regex-mode entry ([Mixed Mode](../guides/release-management.md#9-configure-bump-files-mixed-mode))
to keep matching on subsequent runs.

This cmdlet also supports `-WhatIf` and `-Confirm` (PowerShell's `ShouldProcess` pattern).

## Parameters

This cmdlet takes no parameters beyond the common ones and `-WhatIf`/`-Confirm`.

## Examples

### Preview which files would change

```powershell
Update-PSScriptBuilderBumpFiles -WhatIf
```

### Apply tokens and display what changed

```powershell
Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult
```

```text title="Output"
File : C:\Projects\MyProject\src\MyProject.ps1

  Token     : VERSION
  Old Value : {{VERSION}}
  New Value : 0.1.1

  Token     : BUILD_TIMESTAMP
  Old Value : {{BUILD_TIMESTAMP}}
  New Value : 2026-09-14T12:55:50Z

File : C:\Projects\MyProject\build\Output\MyModule.psd1

  Pattern   : ModuleVersion\s*=\s*'({REGEX_VERSION})'
  Token     : VERSION
  Old Value : ModuleVersion = '0.1.0'
  New Value : ModuleVersion = '0.1.1'
```

## Output

Returns a
[`PSScriptBuilderBumpFilesResult`](../reference/types.md#psscriptbuilderbumpfilesresult) object.

## See Also

- [Release Management Guide](../guides/release-management.md)
- [Cmdlet Reference: Format-PSScriptBuilderBumpResult](Format-PSScriptBuilderBumpResult.md)
- [Cmdlet Reference: Test-PSScriptBuilderBumpConfiguration](Test-PSScriptBuilderBumpConfiguration.md)
- [Cmdlet Reference: Get-PSScriptBuilderBumpConfiguration](Get-PSScriptBuilderBumpConfiguration.md)
