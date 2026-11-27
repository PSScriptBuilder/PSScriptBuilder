# Planning: Format-PSScriptBuilderTemplateAnalysis

## Background

`Get-PSScriptBuilderTemplateAnalysis` returns a `PSScriptBuilderTemplateAnalysisResult` object.
Unlike the other analysis and build cmdlets, there is no corresponding Format cmdlet to display
the result in a structured, human-readable form.

This feature adds `Format-PSScriptBuilderTemplateAnalysis` to fill that gap and make the template
analysis workflow consistent with the rest of PSScriptBuilder.

## Usage Example

```powershell
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"  |
    Get-PSScriptBuilderTemplateAnalysis -TemplatePath "build\Templates\MyProject.ps1.template"

$analysis | Format-PSScriptBuilderTemplateAnalysis
```

## Design Decision

No `-Detailed` switch. The `PSScriptBuilderTemplateAnalysisResult` is flat — there are no long
lists (such as component details or ordered components) that would need to be hidden by default.
All relevant information fits in the compact view.

## Output Structure

### Section 1 — Template Analysis (always shown)

Fixed label width: 11 characters (longest label is `Cross-Deps` at 10 chars → 1 trailing space → 11).
Labels use hardcoded spaces, consistent with all other Format cmdlets.

```
Template Analysis
  Template   : <TemplatePath>
  Size       : <TemplateSize> characters
  Mode       : <ValidationMode>
  Key        : <OrderedComponentsKey>      ← only when ValidationMode is Hybrid or Ordered
  Cross-Deps : <Detected|None>
  Status     : <Valid|Invalid>
```

### Section 2 — Validation Errors (only when IsValid = false AND ValidationErrors.Count > 0)

```
Validation Errors
  <error message 1>
  <error message 2>
```

### Section 3 — Placeholders (always shown)

Placeholder lists are displayed as comma-joined strings. Empty arrays display as `<none>`.

```
Placeholders
  Expected : <USING, CLASS, FUNCTION>
  Found    : <USING, CLASS, FUNCTION>
```

### Section 4 — Missing Placeholders (only when MissingPlaceholders.Count > 0)

```
Missing Placeholders
  <KEY1>
  <KEY2>
```

### Section 5 — Unknown Placeholders (only when UnknownPlaceholders.Count > 0)

```
Unknown Placeholders
  <KEY1>
```

## Output Examples

### Valid, Free Mode

```
Template Analysis
  Template   : C:\Projects\MyProject\build\Templates\MyProject.ps1.template
  Size       : 2845 characters
  Mode       : Free
  Cross-Deps : None
  Status     : Valid

Placeholders
  Expected : USING, CLASS, FUNCTION
  Found    : USING, CLASS, FUNCTION
```

### Valid, Ordered Mode

```
Template Analysis
  Template   : C:\Projects\MyProject\build\Templates\MyProject.ps1.template
  Size       : 1200 characters
  Mode       : Ordered
  Key        : ORDERED_COMPONENTS
  Cross-Deps : Detected
  Status     : Valid

Placeholders
  Expected : USING, ORDERED_COMPONENTS
  Found    : USING, ORDERED_COMPONENTS
```

### Invalid, Free Mode — Missing and Unknown Placeholders

```
Template Analysis
  Template   : C:\Projects\MyProject\build\Templates\MyProject.ps1.template
  Size       : 980 characters
  Mode       : Free
  Cross-Deps : None
  Status     : Invalid

Validation Errors
  Missing placeholder: {{CLASS}}
  Unknown placeholder: {{MY_CUSTOM_KEY}}

Placeholders
  Expected : USING, CLASS, FUNCTION
  Found    : USING, FUNCTION, MY_CUSTOM_KEY

Missing Placeholders
  CLASS

Unknown Placeholders
  MY_CUSTOM_KEY
```

## Files

| # | File | Directory | Change |
|---|---|---|---|
| 1 | `Format-PSScriptBuilderTemplateAnalysis.ps1` | `src\Public\` | New |

No existing files need to be changed. The module manifest is updated automatically by the build.

## Implementation Notes

- `[CmdletBinding()]`, `[OutputType([void])]`, `ValueFromPipeline`
- Parameter type: `[PSScriptBuilderTemplateAnalysisResult]`
- Null guard at the top of `process {}` — `Write-Host` message and `return`
- `ValidationMode` labels: `Free`, `Hybrid`, `Ordered` — `"$($AnalysisResult.ValidationMode)"` calls `.ToString()` implicitly in PS 5.1
- Label spacing: hardcoded spaces (not `PadRight`) — consistent with all other Format cmdlets
- Placeholder join: `$placeholders -join ', '` — empty array produces `''`, replaced by `'<none>'`
- `Key` line: only emitted when `$AnalysisResult.ValidationMode -ne [PSScriptBuilderTemplateValidationMode]::Free`
- `Cross-Deps` value: `if ($AnalysisResult.HasCrossDependencies) { 'Detected' } else { 'None' }`
- `Status` value: `if ($AnalysisResult.IsValid) { 'Valid' } else { 'Invalid' }`
- `Validation Errors` section: `(-not $AnalysisResult.IsValid) -and $AnalysisResult.ValidationErrors.Count -gt 0`
- All sections separated by `Write-Host ""`
- Follows `Write-Host` pattern of all other Format cmdlets (no pipeline output)
