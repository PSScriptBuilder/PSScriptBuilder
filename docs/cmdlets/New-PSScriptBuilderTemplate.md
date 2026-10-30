# New-PSScriptBuilderTemplate

Generates a PSScriptBuilder template file from a content collector configuration.

## Description

Analyzes the registered collectors and their dependencies to generate a ready-to-use template
file with the correct placeholders, automatically choosing the appropriate mode:

- **Free** — no cross-dependencies detected; an individual `{{CollectionKey}}` placeholder is
  generated for each registered collector
- **Ordered** — cross-dependencies detected between component types; a combined
  `{{ORDERED_COMPONENTS}}` placeholder is generated instead, along with `{{USING_STATEMENTS}}`
  and `{{FILE_CONTENTS}}` if those collectors are registered
- **Hybrid** — no cross-dependencies detected, but `-OrderedMode` was specified; same
  placeholders as Ordered mode

See the [Templates Guide](../guides/templates.md#3-ordered-mode-and-hybrid-mode) for the full
mode-selection rules.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The collector configuration to generate the template from. Accepts pipeline input — typically chained directly from `New-PSScriptBuilderContentCollector`/`Add-PSScriptBuilderCollector`. |
| `-OutputPath` | string | **Required.** Path to the template file to generate. Supports both absolute paths and paths relative to the project root (see [`Set-PSScriptBuilderProjectRoot`](Set-PSScriptBuilderProjectRoot.md)). |
| `-OrderedComponentsKey` | string | The placeholder key used for the combined components block in Ordered/Hybrid mode. Default: `"ORDERED_COMPONENTS"`. Must match the key passed to [`Invoke-PSScriptBuilderBuild`](Invoke-PSScriptBuilderBuild.md) and [`Get-PSScriptBuilderTemplateAnalysis`](Get-PSScriptBuilderTemplateAnalysis.md). |
| `-OrderedMode` | switch | Forces Hybrid mode even when no cross-dependencies are detected — use this to keep a template valid ahead of cross-dependencies you expect to introduce later. |
| `-Force` | switch | Overwrites the template file if it already exists. |

This cmdlet also supports `-WhatIf` and `-Confirm` (PowerShell's `ShouldProcess` pattern).

## Examples

### Generate a template with automatic mode detection

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
    New-PSScriptBuilderTemplate -OutputPath "build\Templates\MyProject.ps1.template"

Write-Host "Generated template: $($result.OutputPath)"
Write-Host "Mode: $($result.Mode)"
Write-Host "Placeholders: $($result.Placeholders -join ', ')"
```

### Force Ordered/Hybrid mode ahead of expected cross-dependencies

```powershell
New-PSScriptBuilderTemplate -ContentCollector $contentCollector `
    -OutputPath "build\Templates\MyScript.ps1.template" `
    -OrderedMode
```

### Overwrite an existing template

```powershell
New-PSScriptBuilderTemplate -ContentCollector $contentCollector `
    -OutputPath "build\Templates\MyScript.ps1.template" `
    -Force
```

### Preview template generation without writing any files

```powershell
New-PSScriptBuilderTemplate -ContentCollector $contentCollector `
    -OutputPath "build\Templates\MyScript.ps1.template" `
    -WhatIf
```

## Output

Returns a
[`PSScriptBuilderTemplateGenerationResult`](../reference/types.md#psscriptbuildertemplategenerationresult)
object describing what was generated.

## Notes

- Templates are written using UTF-8 with a byte order mark (BOM).
- The generated file is a minimal starting point — add any surrounding PowerShell code (module
  header, footer, etc.) before using it in a build.

## See Also

- [Templates Guide](../guides/templates.md)
- [Cmdlet Reference: Get-PSScriptBuilderTemplateAnalysis](Get-PSScriptBuilderTemplateAnalysis.md)
- [Cmdlet Reference: Test-PSScriptBuilderTemplate](Test-PSScriptBuilderTemplate.md)
- [Cmdlet Reference: Format-PSScriptBuilderTemplateAnalysis](Format-PSScriptBuilderTemplateAnalysis.md)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)
