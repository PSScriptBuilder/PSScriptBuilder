# Invoke-PSScriptBuilderBuild

Executes the complete PowerShell build process.

## Description

Runs the entire build workflow: loads the template, collects components from every registered
collector, analyzes dependencies (failing with a detailed error on a circular dependency),
topologically sorts them, processes the template, optionally backs up an existing output file,
writes the final output file, and validates its syntax.

All relative paths (`-TemplatePath`, `-OutputPath`, `-BackupPath`) are resolved against the
project root (see [Set-PSScriptBuilderProjectRoot](Set-PSScriptBuilderProjectRoot.md)).

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The fully configured collector set to build from. Accepts pipeline input, enabling fluent chaining from `Add-PSScriptBuilderCollector`. |
| `-TemplatePath` | string | **Required.** Path to the template file. |
| `-OutputPath` | string | **Required.** Path to write the final output file to. |
| `-BackupPath` | string | Directory for backup files, used only when `-EnableBackup` is specified. Defaults to the output file's own directory. |
| `-OrderedComponentsKey` | string | The combined-components placeholder key, for Ordered/Hybrid Mode templates. Default: `"ORDERED_COMPONENTS"`. |
| `-EnableBackup` | switch | Back up an existing output file (timestamped, e.g. `MyScript.ps1.260309_153045.bak`) before overwriting it. Off by default — see [Backup](../guides/build-pipeline.md#backup) for why. |
| `-SkipSyntaxValidation` | switch | Skip the post-write syntax check. Only needed if the output contains syntax the PowerShell parser can't handle at all — `TypeNotFound` errors from externally-loaded assemblies are already filtered automatically and never fail validation. |
| `-WriteSourceMap` | switch | Write a `.sourcemap.json` sidecar alongside the output, enabling [`Resolve-PSScriptBuilderSourceLocation`](Resolve-PSScriptBuilderSourceLocation.md) to map output lines back to source files. |

## Examples

### Fluent pipeline build

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
    Invoke-PSScriptBuilderBuild -TemplatePath "template.psm1" -OutputPath "output.psm1"
```

### Build using paths from a configuration file

```powershell
$config = Get-PSScriptBuilderConfiguration
$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath $config.Build.TemplatePath `
    -OutputPath $config.Build.OutputPath `
    -BackupPath $config.Build.BackupPath `
    -EnableBackup:$config.Build.BackupEnabled
```

## Output

Returns a [`PSScriptBuilderBuildResult`](../reference/types.md#psscriptbuilderbuildresult) object.
See [Interpreting the Build Result](../guides/build-pipeline.md#interpreting-the-build-result)
for how to read it.

## See Also

- [Build Pipeline Guide](../guides/build-pipeline.md)
- [Cmdlet Reference: Format-PSScriptBuilderBuildResult](Format-PSScriptBuilderBuildResult.md)
- [Cmdlet Reference: Export-PSScriptBuilderBuildResult](Export-PSScriptBuilderBuildResult.md)
- [Cmdlet Reference: Watch-PSScriptBuilderProject](Watch-PSScriptBuilderProject.md)
