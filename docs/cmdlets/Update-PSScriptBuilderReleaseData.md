# Update-PSScriptBuilderReleaseData

Updates release data including version and metadata.

## Description

Performs atomic release data management operations with transactional semantics and automatic
rollback capability. Supports:

- Semantic version bumping (Major/Minor/Patch)
- Explicit version setting via `-Version` (e.g., `"1.0.0"`, `"2.1.0-beta"`)
- Build metadata updates (automatic or manual)
- Git metadata updates (automatic from repository)
- Prerelease and build metadata management

Operations are transactional with automatic rollback on failure.

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
| `-UpdateBuildDetails` | switch | Re-stamps the build date, time, timestamp, and number. |
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
- Automatic rollback on failure restores all modified files — the release data is never left
  in a partially updated state.

## See Also

- [Release Management Guide](../guides/release-management.md)
- [Cmdlet Reference: New-PSScriptBuilderReleaseData](New-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseData](Get-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Format-PSScriptBuilderReleaseDataResult](Format-PSScriptBuilderReleaseDataResult.md)
