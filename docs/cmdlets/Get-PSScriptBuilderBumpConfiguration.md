# Get-PSScriptBuilderBumpConfiguration

Retrieves the bump configuration.

## Description

Loads `psscriptbuilder.bumpconfig.json` and returns its parsed `bumpFiles` array — which files
are configured to receive version token updates, and how. Useful for confirming a newly added
bump target actually made it into the configuration file, without opening and parsing the JSON
by hand.

## Parameters

This cmdlet takes no parameters beyond the common ones.

## Examples

### List the configured bump file paths

```powershell
(Get-PSScriptBuilderBumpConfiguration).bumpFiles | Select-Object path -Unique
```

```text title="Output"
path
----
build\Templates\PSScriptBuilder.psm1.template
build\Output\PSScriptBuilder.psd1
```

## Output

Returns an array of `PSCustomObject`, one per entry in `bumpFiles`.

## See Also

- [Release Management Guide](../guides/release-management.md#11-read-bump-configuration)
- [Cmdlet Reference: Test-PSScriptBuilderBumpConfiguration](Test-PSScriptBuilderBumpConfiguration.md)
- [Cmdlet Reference: Update-PSScriptBuilderBumpFiles](Update-PSScriptBuilderBumpFiles.md)
