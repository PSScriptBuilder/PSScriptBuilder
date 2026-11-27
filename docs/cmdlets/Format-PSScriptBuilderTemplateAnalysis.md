# Format-PSScriptBuilderTemplateAnalysis

Formats and displays the result of a template analysis operation.

## Description

Renders a `PSScriptBuilderTemplateAnalysisResult` as a human-readable summary: validation status,
detected mode, and placeholder analysis. The combined-components key line is shown only in
Hybrid/Ordered Mode; validation errors, missing placeholders, and unknown placeholders are each
shown only when present.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-AnalysisResult` | `PSScriptBuilderTemplateAnalysisResult` | **Required.** The result to display, typically piped directly from [`Get-PSScriptBuilderTemplateAnalysis`](Get-PSScriptBuilderTemplateAnalysis.md). |

## Examples

### Display a template analysis result

```powershell
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums"  |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"  |
    Get-PSScriptBuilderTemplateAnalysis -TemplatePath "build\Templates\MyProject.ps1.template"

$analysis | Format-PSScriptBuilderTemplateAnalysis
```

```text title="Output"
Template Analysis
  Template   : ...\build\Templates\MyProject.ps1.template
  Size       : 73 characters
  Mode       : Free
  Cross-Deps : None
  Status     : Valid

Placeholders
  Expected : {{CLASS_DEFINITIONS}}, {{ENUM_DEFINITIONS}}, {{FUNCTION_DEFINITIONS}}
  Found    : {{CLASS_DEFINITIONS}}, {{ENUM_DEFINITIONS}}, {{FUNCTION_DEFINITIONS}}
```

## Output

None — writes directly to the host with `Write-Host`.

## See Also

- [Templates Guide](../guides/templates.md#6-validate-your-template)
- [Cmdlet Reference: Get-PSScriptBuilderTemplateAnalysis](Get-PSScriptBuilderTemplateAnalysis.md)
