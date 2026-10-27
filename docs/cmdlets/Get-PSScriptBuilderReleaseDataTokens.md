# Get-PSScriptBuilderReleaseDataTokens

Retrieves available release data tokens for substitution in bump files.

## Description

Reformats the current release data — version, build, and Git fields — as the named `{{TOKEN}}`
placeholders used in `psscriptbuilder.bumpconfig.json`. Returned sorted alphabetically by
category (`Build`, `Git`, `Version`). See
[Inspect Available Tokens](../guides/release-management.md#6-inspect-available-tokens) and the
[full token reference](../guides/release-management.md#version-tokens) for what each one means.

## Parameters

This cmdlet takes no parameters beyond the common ones.

## Examples

### List all current token values

```powershell
Get-PSScriptBuilderReleaseDataTokens | Format-Table -AutoSize
```

```text title="Output"
Name                  Value
----                  -----
BUILD_DATE            2026-09-14
BUILD_TIME            12:53:24
BUILD_DAY             14
BUILD_MONTH           09
BUILD_YEAR            2026
BUILD_HOUR            12
BUILD_MINUTE          53
BUILD_SECOND          24
BUILD_TIMESTAMP       2026-09-14T12:53:24Z
BUILD_NUMBER          1
GIT_COMMIT            55d9437fc36f519f0d5721193840fc4afcba8dcd
GIT_COMMIT_SHORT      55d9437
GIT_BRANCH            development
GIT_TAG               v1.2.0
VERSION               0.1.1
VERSION_MAJOR         0
VERSION_MINOR         1
VERSION_PATCH         1
VERSION_FULL          0.1.1
VERSION_PRERELEASE
VERSION_BUILDMETADATA
```

### Look up a single token

```powershell
$tokens = Get-PSScriptBuilderReleaseDataTokens
$tokens['VERSION_FULL']
```

## Output

Returns a `System.Collections.Specialized.OrderedDictionary` mapping each token name to its
current value.

## See Also

- [Release Management Guide](../guides/release-management.md)
- [Cmdlet Reference: Get-PSScriptBuilderReleaseData](Get-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Update-PSScriptBuilderBumpFiles](Update-PSScriptBuilderBumpFiles.md)
