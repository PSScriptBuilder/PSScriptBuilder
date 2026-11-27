# Test-PSScriptBuilderTemplate

Validates a PSScriptBuilder template file without performing a build.

## Description

Runs the same collection and dependency analysis a real build would — so it sees the same
cross-dependencies — then reports whether the template is valid, without writing any output.
Returns a plain `$true`/`$false`; for the specific errors when it's `$false`, or a full report of
which placeholders are missing or unknown, use
[`Get-PSScriptBuilderTemplateAnalysis`](Get-PSScriptBuilderTemplateAnalysis.md) instead — or add
`-Verbose` here to see the same validation detail logged as it runs.

See [Placeholder Rules](../guides/templates.md#placeholder-rules) and
[Validation Modes](../guides/templates.md#validation-modes) for what's actually checked, and
[Validation Error Reference](../guides/templates.md#validation-error-reference) for what each
failure means and how to fix it.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The collector configuration to validate against. Accepts pipeline input, enabling fluent chaining from `Add-PSScriptBuilderCollector`. |
| `-TemplatePath` | string | **Required.** Path to the template file to validate. |
| `-OrderedComponentsKey` | string | The combined-components placeholder key, for Ordered/Hybrid Mode templates. Default: `"ORDERED_COMPONENTS"`. |

## Examples

### Validate before building

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"

if (Test-PSScriptBuilderTemplate -ContentCollector $contentCollector -TemplatePath "build\Templates\MyProject.ps1.template") {
    Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
        -TemplatePath "build\Templates\MyProject.ps1.template" `
        -OutputPath   "build\Output\MyProject.ps1"
}
```

### Validate with a custom combined-components key

```powershell
Test-PSScriptBuilderTemplate -ContentCollector $contentCollector `
    -TemplatePath "template.psm1" `
    -OrderedComponentsKey "ALL_COMPONENTS"
```

## Output

Returns `$true` if the template is valid, `$false` otherwise. Only unexpected errors (e.g. a
missing template file) are terminating — a failed validation is a normal `$false` result, not an
error.

## See Also

- [Templates Guide](../guides/templates.md)
- [Cmdlet Reference: Get-PSScriptBuilderTemplateAnalysis](Get-PSScriptBuilderTemplateAnalysis.md)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)
