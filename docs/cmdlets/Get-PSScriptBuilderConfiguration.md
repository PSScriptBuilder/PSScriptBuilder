# Get-PSScriptBuilderConfiguration

Retrieves the global PSScriptBuilder configuration.

## Description

Loads `psscriptbuilder.config.json` and returns it as a structured object with `ConfigFileName`,
`Build`, and `Release` properties. See [Build Options Reference](../guides/configuration.md#build-options-reference)
and [Release Options Reference](../guides/configuration.md#release-options-reference) for every
field.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Flat` | switch | Returns a single flat structure instead, with every property prefixed by category (`Release*`, `Build*`) — useful for tabular or diagnostic display. |

## Examples

### Read the configuration and access a value

```powershell
$config = Get-PSScriptBuilderConfiguration
$config.Build.OutputPath
```

### Read the structured configuration

```powershell
$config = Get-PSScriptBuilderConfiguration
$config.Build | Format-List
```

```text title="Output"
OutputPath              : C:\Projects\MyProject\build\Output
BackupPath              : C:\Projects\MyProject\build\Output\Backup
TemplatePath            : C:\Projects\MyProject\build\Templates
OrderedComponentsKey    : ORDERED_COMPONENTS
BackupEnabled           : False
SyntaxValidationEnabled : True
WriteSourceMap          : False
```

### Read the flat configuration for tabular display

```powershell
Get-PSScriptBuilderConfiguration -Flat
```

```text title="Output"
Name                           Value
----                           -----
ReleaseDataFile                C:\Projects\MyProject\build\Release\psscriptbuilder.releasedata.json
ReleaseBumpConfigFile          C:\Projects\MyProject\build\Release\psscriptbuilder.bumpconfig.json
BuildTemplatePath              C:\Projects\MyProject\build\Templates
BuildOutputPath                C:\Projects\MyProject\build\Output
BuildBackupPath                C:\Projects\MyProject\build\Output\Backup
BuildOrderedComponentsKey      ORDERED_COMPONENTS
BuildBackupEnabled             False
BuildSyntaxValidationEnabled   True
BuildWriteSourceMap            False
```

## Output

Returns a `PSScriptBuilderConfiguration` object by default, or a
`System.Collections.Specialized.OrderedDictionary` when `-Flat` is specified.

## See Also

- [Configuration Guide](../guides/configuration.md)
- [Cmdlet Reference: New-PSScriptBuilderConfiguration](New-PSScriptBuilderConfiguration.md)
- [Cmdlet Reference: Set-PSScriptBuilderProjectRoot](Set-PSScriptBuilderProjectRoot.md)
