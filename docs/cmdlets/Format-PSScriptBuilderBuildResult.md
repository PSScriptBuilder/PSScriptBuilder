# Format-PSScriptBuilderBuildResult

Formats and displays the result of a build operation.

## Description

Renders a `PSScriptBuilderBuildResult` as a human-readable summary: output path, file size,
execution time, backup/source map paths (when present), and a per-type component count with a
total.

Add `-Detailed` to also list every processed source file and, per component, its source file and
dependencies.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-BuildResult` | `PSScriptBuilderBuildResult` | **Required.** The result to display, typically piped directly from [`Invoke-PSScriptBuilderBuild`](Invoke-PSScriptBuilderBuild.md). |
| `-Detailed` | switch | Also list every processed source file and each component's source file and dependencies. |

## Examples

### Display a compact build summary

```powershell
$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector -TemplatePath "template.psm1" -OutputPath "output.psm1"
Format-PSScriptBuilderBuildResult -BuildResult $result
```

```text title="Output"
Build Summary
  Output : ...\build\Output\MyProject.ps1
  Size   : 734 bytes
  Time   : 830.15 ms

Components
  Enums     : 1
  Classes   : 1
  Functions : 1
  Total     : 3
```

### Display the full detail via the pipeline

```powershell
$result | Format-PSScriptBuilderBuildResult -Detailed
```

## Output

None — writes directly to the host with `Write-Host`.

## See Also

- [Build Pipeline Guide](../guides/build-pipeline.md#interpreting-the-build-result)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)
- [Cmdlet Reference: Export-PSScriptBuilderBuildResult](Export-PSScriptBuilderBuildResult.md)
