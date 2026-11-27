# Test-PSScriptBuilderBumpConfiguration

Tests the bump configuration file for validity.

## Description

Validates `psscriptbuilder.bumpconfig.json` on disk against the expected structure and checks
that every referenced file exists. Useful before any automated bump operation, or after an
external tool has modified the file, to verify its integrity first.

Validation errors are reported via `Write-Error`; add `-Verbose` for additional validation
detail.

## Parameters

This cmdlet takes no parameters beyond the common ones.

## Examples

### Validate before updating bump files

```powershell
if (Test-PSScriptBuilderBumpConfiguration) {
    Update-PSScriptBuilderBumpFiles
}
else {
    Write-Warning "Bump configuration has errors, fix them first"
}
```

## Output

Returns `$true` if the bump configuration file is valid, `$false` otherwise.

## See Also

- [Release Management Guide](../guides/release-management.md#13-validate-configuration)
- [Cmdlet Reference: Test-PSScriptBuilderReleaseData](Test-PSScriptBuilderReleaseData.md)
- [Cmdlet Reference: Update-PSScriptBuilderBumpFiles](Update-PSScriptBuilderBumpFiles.md)
