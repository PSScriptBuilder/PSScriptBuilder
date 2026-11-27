# Set-PSScriptBuilderProjectRoot

Sets the PSScriptBuilder project root directory.

## Description

Explicitly sets the project root and caches it in `$Global:PSScriptBuilderProjectRoot` for every
subsequent PSScriptBuilder operation in the session.

Calling this cmdlet is optional — without it, the project root is auto-discovered by walking up
from the current PowerShell location until a directory containing `psscriptbuilder.config.json` is
found. Call this instead when auto-discovery would fail or pick the wrong directory: in CI, or
when a script runs from a location outside the project. See
[Project Root Discovery](../guides/configuration.md#project-root-discovery) for the full
auto-discovery behavior.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Path` | string | **Required.** The directory to set as the project root. Must already exist on a file system drive; a path on another provider's drive, such as `HKCU:`, is rejected. Wildcard characters are not interpreted, so a name such as `App[1]` is used as it is. Accepts pipeline input, including the output of `Get-Item` and `Get-ChildItem`. |

## Examples

### Set the project root explicitly at the top of a build script

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot
```

`$PSScriptRoot` resolves to the currently running script's own directory — call this before any
other PSScriptBuilder cmdlets.

## Output

None.

## See Also

- [Configuration Guide](../guides/configuration.md#project-root-discovery)
- [Cmdlet Reference: New-PSScriptBuilderConfiguration](New-PSScriptBuilderConfiguration.md)
