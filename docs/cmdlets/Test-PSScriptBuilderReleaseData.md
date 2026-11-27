# Test-PSScriptBuilderReleaseData

Tests the release data file for validity.

## Description

Validates `psscriptbuilder.releasedata.json` on disk against the expected structure — for
example, that all required fields exist and the version components are valid integers. Useful
before any automated release operation, or after an external tool has modified the file, to
verify its integrity first.

Validation errors are reported via `Write-Error`; add `-Verbose` for additional validation
detail.

## Parameters

This cmdlet takes no parameters beyond the common ones.

## Examples

### Validate before bumping the version

```powershell
if (Test-PSScriptBuilderReleaseData) {
    Update-PSScriptBuilderReleaseData -Patch
}
else {
    Write-Warning "Release data has errors, fix them first"
}
```

## Output

Returns `$true` if the release data file is valid, `$false` otherwise.

## See Also

- [Release Management Guide](../guides/release-management.md#13-validate-configuration)
- [Cmdlet Reference: Test-PSScriptBuilderBumpConfiguration](Test-PSScriptBuilderBumpConfiguration.md)
- [Cmdlet Reference: Update-PSScriptBuilderReleaseData](Update-PSScriptBuilderReleaseData.md)
