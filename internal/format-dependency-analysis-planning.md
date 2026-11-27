# Planning: Format-PSScriptBuilderDependencyAnalysis

## Background

`Get-PSScriptBuilderDependencyAnalysis` returns a `PSScriptBuilderDependencyAnalysisResult`
object. The raw console output of this object is unreadable for end users.

Every other result-producing cmdlet in PSScriptBuilder already has a format counterpart:

| Cmdlet                              | Format Cmdlet                              |
|-------------------------------------|--------------------------------------------|
| `Invoke-PSScriptBuilderBuild`       | `Format-PSScriptBuilderBuildResult`        |
| `Update-PSScriptBuilderBumpFiles`   | `Format-PSScriptBuilderBumpResult`         |
| `Update-PSScriptBuilderReleaseData` | `Format-PSScriptBuilderReleaseDataResult`  |
| `Get-PSScriptBuilderDependencyAnalysis` | _(missing)_                            |

`Format-PSScriptBuilderDependencyAnalysis` closes this gap.

## Usage Examples

```powershell
# Compact summary (default)
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src" |
    Get-PSScriptBuilderDependencyAnalysis

$analysis | Format-PSScriptBuilderDependencyAnalysis

# Detailed output with ordered component list
$analysis | Format-PSScriptBuilderDependencyAnalysis -Detailed
```

## Design Decisions

- **Same structure as `Format-PSScriptBuilderBuildResult`**: compact by default, `-Detailed` for
  extra information. Output via `Write-Host`, `[OutputType([void])]`.
- **Compact output** always shows: summary metrics + component type counts.
- **`-Detailed`** adds: the full ordered component list (if no cycles), or the cycle path
  (if cycles were detected). These are mutually exclusive.
- **Component type labels** in the ordered list are not available from
  `PSScriptBuilderDependencyAnalysisResult` alone — the result carries only `string[]`
  component names and no per-component type metadata. The ordered list therefore shows
  names only (no `[Enum]`/`[Class]` tags). Type breakdown is in the Component Counts section.
- **Cycle state** is reflected in the summary line (`None` / `Detected`).
- **Cross-dependency state** is reflected in the summary line (`None` / `Detected`).
- **Zero-count types are omitted** from Component Counts (consistent with `Format-PSScriptBuilderBuildResult`).

## Files

| # | File | Directory | Change |
|---|---|---|---|
| 1 | `Format-PSScriptBuilderDependencyAnalysis.ps1` | `src\Public\` | New |

## 1. Format-PSScriptBuilderDependencyAnalysis — New

**Signature:**

```powershell
Function Format-PSScriptBuilderDependencyAnalysis {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderDependencyAnalysisResult] $AnalysisResult,

        [Parameter()]
        [switch] $Detailed
    )
}
```

**Compact output (no `-Detailed`), no cycles:**

```
Dependency Analysis Summary
  Components  : 23
  Nodes       : 23
  Edges       : 41
  Cycles      : None
  Cross-Deps  : None

Component Counts
  Using     :  2
  Enums     :  3
  Classes   : 11
  Functions :  7
```

**Compact output, cycles detected:**

```
Dependency Analysis Summary
  Components  : 8
  Nodes       : 8
  Edges       : 9
  Cycles      : Detected
  Cross-Deps  : Detected

Component Counts
  Classes   : 5
  Functions :  3
```

**With `-Detailed`, no cycles:**

```
Dependency Analysis Summary
  Components  : 23
  ...

Component Counts
  ...

Ordered Components (23)
  PSScriptBuilderCollectorType
  PSScriptBuilderTextHelper
  PSScriptBuilderFileSystemHelper
  PSScriptBuilderCollectorBase
  ...
```

**With `-Detailed`, cycles detected:**

```
Dependency Analysis Summary
  ...

Component Counts
  ...

Cycle Path
  PSScriptBuilderClassCollector
  -> PSScriptBuilderCollectorBase
  -> PSScriptBuilderClassCollector

No ordered component list available (cycle prevents topological sort)
```

**Cycle path formatting:** `$AnalysisResult.CyclePath` is a `string[]`. Each entry is printed
on its own line. The first entry is repeated at the end to show the cycle closing. The `->` prefix
is added to all entries except the first.

**Counts section label width:** Pad-right to the longest label present (consistent with
`Format-PSScriptBuilderBuildResult`). Value is right-padded to `TotalComponents` digit width.

## Edge Cases

| Case | Behavior |
|---|---|
| `AnalysisResult` is null | `Write-Host "AnalysisResult is null."` and return |
| `ComponentCounts` is null | Component Counts section omitted |
| `CyclePath` is empty while `HasCycles` is true | Cycle Path section shows "(cycle path unavailable)" |
| `OrderedComponents` is empty and `HasCycles` is false | Ordered section shows "(no components)" |
| All component counts are zero | Component Counts section shows "None" |
