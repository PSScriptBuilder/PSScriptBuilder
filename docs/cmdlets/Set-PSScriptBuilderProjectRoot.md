# Set-PSScriptBuilderProjectRoot

Sets the PSScriptBuilder project root directory.

## Description

Explicitly sets the project root and caches it in `$Global:PSScriptBuilderProjectRoot` for every
subsequent PSScriptBuilder operation in the session.

Calling this cmdlet is optional — without it, the project root is auto-discovered by walking up
from the current working directory until a directory containing `psscriptbuilder.config.json` is
found. Call this instead when auto-discovery would fail or pick the wrong directory: in CI, or
when a script's working directory differs from the project root. See
[Project Root Discovery](../guides/configuration.md#project-root-discovery) for the full
auto-discovery behavior.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Path` | string | **Required.** The directory to set as the project root. Must already exist. Accepts pipeline input. |

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
