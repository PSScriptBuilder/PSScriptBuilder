# New-PSScriptBuilderConfiguration

Creates a new PSScriptBuilder configuration file with default values.

## Description

Writes a new `psscriptbuilder.config.json` with default values into `-Path`, or — if omitted —
the currently set project root ([`Set-PSScriptBuilderProjectRoot`](Set-PSScriptBuilderProjectRoot.md)),
falling back to the current working directory. The target directory is created automatically if
it doesn't exist yet.

Fails with an error if the file already exists, unless `-Force` is specified.

This cmdlet also supports `-WhatIf` and `-Confirm` (PowerShell's `ShouldProcess` pattern).

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Path` | string | Directory to create the configuration file in. Defaults to the current project root, or the current working directory if none is set. |
| `-Force` | switch | Overwrite the configuration file if it already exists. |

## Examples

### Create a configuration file in the current project

```powershell
New-PSScriptBuilderConfiguration
```

### Create a configuration file in a specific directory

```powershell
New-PSScriptBuilderConfiguration -Path "C:\Projects\MyProject"
```

### Reset an existing configuration file to its defaults

```powershell
New-PSScriptBuilderConfiguration -Force
```

## Output

None.

## See Also

- [Configuration Guide](../guides/configuration.md)
- [Cmdlet Reference: Get-PSScriptBuilderConfiguration](Get-PSScriptBuilderConfiguration.md)
- [Cmdlet Reference: Set-PSScriptBuilderProjectRoot](Set-PSScriptBuilderProjectRoot.md)
