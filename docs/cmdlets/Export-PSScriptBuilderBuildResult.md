# Export-PSScriptBuilderBuildResult

Exports a build result to a JSON file.

## Description

Serializes a `PSScriptBuilderBuildResult` to a structured JSON file — useful as a CI artifact for
auditing, debugging, or tracking changes between builds. Always includes the build summary
(output path, file size, syntax validation status, execution time, and component counts) plus an
automatically-added UTC generation timestamp.

Add `-Detailed` to also include every processed source file and, per component, its source file
and dependencies.

The target directory is created automatically if it doesn't exist; relative paths are resolved
against the project root (see [Set-PSScriptBuilderProjectRoot](Set-PSScriptBuilderProjectRoot.md)).

## Parameters

| Name | Type | Description |
|---|---|---|
| `-BuildResult` | `PSScriptBuilderBuildResult` | **Required.** The result to export, typically piped directly from [`Invoke-PSScriptBuilderBuild`](Invoke-PSScriptBuilderBuild.md). |
| `-Path` | string | **Required.** Path to the JSON file to write. |
| `-Detailed` | switch | Also include every processed source file and each component's source file and dependencies. |
| `-Force` | switch | Overwrite the target file if it already exists. Without it, an existing file causes an `IOException`. |

## Examples

### Export a compact build summary

```powershell
$result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json"
```

### Export the full detail, overwriting an existing report

```powershell
$result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json" -Detailed -Force
```

### Build, display, and export in one pipeline

```powershell
$result = Invoke-PSScriptBuilderBuild @buildParams
$result | Format-PSScriptBuilderBuildResult
$result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json" -Force
```

## Output

Returns the resolved absolute path of the written JSON file, as a string.

## See Also

- [Build Pipeline Guide](../guides/build-pipeline.md#exporting-the-build-report)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)
- [Cmdlet Reference: Format-PSScriptBuilderBuildResult](Format-PSScriptBuilderBuildResult.md)
