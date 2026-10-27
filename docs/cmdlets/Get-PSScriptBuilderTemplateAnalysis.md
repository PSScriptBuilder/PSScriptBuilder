# Get-PSScriptBuilderTemplateAnalysis

Analyzes a PSScriptBuilder template file and returns comprehensive analysis information.

## Description

Validates a template against the current collector configuration and returns a detailed result:
validation status and errors, the detected validation mode (`Free`, `Hybrid`, or `Ordered`), and
a full placeholder comparison — found, expected, missing, and unknown. See
[Validation Modes](../guides/templates.md#validation-modes) for how the mode is determined, and
[Validate Your Template](../guides/templates.md#6-validate-your-template) for the full workflow.

For a plain `$true`/`$false` result instead, use
[`Test-PSScriptBuilderTemplate`](Test-PSScriptBuilderTemplate.md). This cmdlet focuses on
template-specific information only — for topological order, component counts, or the dependency
graph itself, use [`Get-PSScriptBuilderDependencyAnalysis`](Get-PSScriptBuilderDependencyAnalysis.md)
separately.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The collector configuration to validate against. Accepts pipeline input, enabling fluent chaining from `Add-PSScriptBuilderCollector`. |
| `-TemplatePath` | string | **Required.** Path to the template file to analyze. |
| `-OrderedComponentsKey` | string | The combined-components placeholder key, for Ordered/Hybrid Mode templates. Default: `"ORDERED_COMPONENTS"`. |

## Examples

### Analyze a template and branch on validity

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
    Get-PSScriptBuilderTemplateAnalysis -TemplatePath "template.psm1"

if ($result.IsValid) {
    Write-Host "Template is valid - Mode: $($result.ValidationMode)"
}
else {
    Write-Warning "Template validation failed:"
    $result.ValidationErrors | ForEach-Object { Write-Warning "  $_" }
}
```

### Inspect placeholder mismatches

```powershell
$result = Get-PSScriptBuilderTemplateAnalysis -ContentCollector $contentCollector -TemplatePath "template.psm1"

if ($result.MissingPlaceholders.Count -gt 0) {
    Write-Host "Missing placeholders: $($result.MissingPlaceholders -join ', ')"
}

if ($result.UnknownPlaceholders.Count -gt 0) {
    Write-Host "Unknown placeholders: $($result.UnknownPlaceholders -join ', ')"
}
```

### Pipe into Format-PSScriptBuilderTemplateAnalysis for a full report

```powershell
Get-PSScriptBuilderTemplateAnalysis -ContentCollector $contentCollector -TemplatePath "template.psm1" |
    Format-PSScriptBuilderTemplateAnalysis
```

## Output

Returns a
[`PSScriptBuilderTemplateAnalysisResult`](../reference/types.md#psscriptbuildertemplateanalysisresult)
object.

## See Also

- [Templates Guide](../guides/templates.md)
- [Cmdlet Reference: Format-PSScriptBuilderTemplateAnalysis](Format-PSScriptBuilderTemplateAnalysis.md)
- [Cmdlet Reference: Test-PSScriptBuilderTemplate](Test-PSScriptBuilderTemplate.md)
- [Cmdlet Reference: Get-PSScriptBuilderDependencyAnalysis](Get-PSScriptBuilderDependencyAnalysis.md)
