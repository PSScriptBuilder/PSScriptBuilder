# Format-PSScriptBuilderDependencyAnalysis

Formats and displays the result of a dependency analysis operation.

## Description

Renders a `PSScriptBuilderDependencyAnalysisResult` as a human-readable summary: total nodes and
edges, cycle status, cross-dependency status, and a per-type component count with a total.

If a cycle was detected, its path is always shown, regardless of `-Detailed`. Add `-Detailed` to
also list the full topologically-sorted component sequence — or, if a cycle prevents sorting, a
note explaining why the list isn't available.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-AnalysisResult` | `PSScriptBuilderDependencyAnalysisResult` | **Required.** The result to display, typically piped directly from [`Get-PSScriptBuilderDependencyAnalysis`](Get-PSScriptBuilderDependencyAnalysis.md). |
| `-Detailed` | switch | Also list the full ordered component sequence (or a note if cycles prevent sorting). |

## Examples

### Display a compact summary

```powershell
$analysis | Format-PSScriptBuilderDependencyAnalysis
```

```text title="Output"
Analysis Summary
  Components : 8
  Nodes      : 8
  Edges      : 11
  Cycles     : None
  Cross-Deps : None

Components
  Enums     : 2
  Classes   : 3
  Functions : 3
  Total     : 8
```

### Display the full ordered component sequence

```powershell
$analysis | Format-PSScriptBuilderDependencyAnalysis -Detailed
```

```text title="Output"
Ordered Components (8)
  Department
  EmploymentStatus
  Address
  Person
  Employee
  Get-EmployeesByDepartment
  New-Employee
  Set-EmployeeStatus
```

## Output

None — writes directly to the host with `Write-Host`.

## See Also

- [Dependency Analysis Guide](../guides/dependency-analysis.md#2-display-the-analysis)
- [Cmdlet Reference: Get-PSScriptBuilderDependencyAnalysis](Get-PSScriptBuilderDependencyAnalysis.md)
