# Update-PSScriptBuilderReleaseData

Updates release data including version and metadata.

## Description

Updates the release data file. The update is prepared and validated in memory first; the file is
written only afterwards, and only if the update changes it. Supports:

- Semantic version bumping (Major/Minor/Patch)
- Explicit version setting via `-Version` (e.g., `"1.0.0"`, `"2.1.0-beta"`)
- Build metadata updates (automatic or manual)
- Git metadata updates (automatic from repository)
- Prerelease and build metadata management

If validation fails, the file is not touched; if writing fails, its original content is restored.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Major` | switch | Increments the major version (`X.0.0`), resetting minor and patch to `0`. |
| `-Minor` | switch | Increments the minor version (`0.X.0`), resetting patch to `0`. |
| `-Patch` | switch | Increments the patch version (`0.0.X`). |
| `-Version` | string | Sets an explicit version string (e.g., `"1.0.0"`, `"2.1.0-beta"`, `"v1.0.0"`), supporting full SemVer including prerelease and build metadata. |
| `-Prerelease` | string | Sets the prerelease identifier (e.g., `"alpha.1"`, `"beta"`, `"rc.1"`). Must match `^[0-9a-zA-Z-.]+$`. |
| `-ClearPrerelease` | switch | Removes the prerelease identifier. |
| `-BuildMetadata` | string | Sets build metadata (not auto-updated). Must match `^[0-9a-zA-Z-.]+$`. |
| `-ClearBuildMetadata` | switch | Removes build metadata. |
| `-UpdateBuildDetails` | switch | Re-stamps the build date, time, and timestamp with the current time in UTC, and increments the build number. |
| `-UpdateGitDetails` | switch | Captures the current Git commit, short commit, branch, and latest tag. Requires `git` to be available in `PATH`. |

`-Major`, `-Minor`, `-Patch`, and `-Version` are mutually exclusive — at most one may be used
per call. Every other parameter in this table can be combined freely with a version switch, or
used entirely on its own. `-Prerelease` and `-ClearPrerelease` are likewise mutually exclusive
with each other, as are `-BuildMetadata` and `-ClearBuildMetadata`. This cmdlet also supports
`-WhatIf` and `-Confirm` (PowerShell's `ShouldProcess` pattern).

## Examples

### Bump the major version and refresh build metadata

```powershell
Update-PSScriptBuilderReleaseData -Major -UpdateBuildDetails
```

### Preview a minor bump with a prerelease identifier, without writing it

```powershell
Update-PSScriptBuilderReleaseData -Minor -Prerelease "beta.1" -WhatIf
```

### Set an explicit version and refresh build metadata

```powershell
Update-PSScriptBuilderReleaseData -Version "1.0.0" -UpdateBuildDetails
```

### Refresh only the Git metadata, without changing the version

```powershell
Update-PSScriptBuilderReleaseData -UpdateGitDetails
```

## Output

Returns a
[`PSScriptBuilderReleaseDataResult`](../reference/types.md#psscriptbuilderreleasedataresult)
object describing what changed.

## Notes

- Requires a loaded PSScriptBuilder configuration and an existing release data file.
- The file is written only after the update was validated and confirmed, and only if it changes
  the release data — otherwise no confirmation is requested.
- The file is not overwritten if it was changed since the update was prepared. A backup
  (`<file>.psscriptbuilder-backup`) left by an interrupted run stops the next run that would
  change the file, before anything is changed.

## See Also

- [Release Management Guide](../guides/release-management.md)
- [Cmdlet Reference: New-PSScriptBuilderReleaseData](New-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseData](Get-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Format-PSScriptBuilderReleaseDataResult](Format-PSScriptBuilderReleaseDataResult.md)
