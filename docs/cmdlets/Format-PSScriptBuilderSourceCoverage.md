# Format-PSScriptBuilderSourceCoverage

Formats and displays per-source-file code coverage results.

## Description

Renders one or more `PSScriptBuilderSourceCoverageResult` objects — as returned by
[`Get-PSScriptBuilderSourceCoverage`](Get-PSScriptBuilderSourceCoverage.md) — as an aligned table:
one row per source file, with its coverage percentage and hit/total command count. `SourceFile`
is shown relative to the project root, falling back to the original path for a file outside it
(for example a collector `IncludePath` pointed at a network share).

Add `-Detailed` to also list, beneath each file's row, every distinct source line not covered by
any test — consecutive lines collapsed into a range (e.g. `uncovered: lines 12-14, 20`), and a
file at 0% coverage shown as `uncovered: entire file` instead of enumerating every line. Long
lists wrap at a fixed width with a hanging indent.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-CoverageResult` | `PSScriptBuilderSourceCoverageResult` | **Required.** The result to display. Accepts pipeline input — all piped objects are collected and rendered together as one aligned table. |
| `-Detailed` | switch | Also list the uncovered source lines beneath each file's row. |

## Examples

### Display a compact coverage table

```powershell
$result | Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
    Format-PSScriptBuilderSourceCoverage
```

### Display the table with uncovered lines per file

```powershell
$coverage | Format-PSScriptBuilderSourceCoverage -Detailed
```

```text title="Output"
SourceFile                                   Coverage  Hit/Total
-------------------------------------------  --------  ---------
src\Classes\Person.ps1                        100.0 %        2/2
src\Classes\Employee.ps1                      100.0 %        2/2
src\Functions\Get-EmployeeById.ps1             71.4 %        5/7
  uncovered: lines 12-13
src\Functions\New-Employee.ps1                100.0 %        1/1
src\Functions\Get-EmployeesByDepartment.ps1     0.0 %        0/4
  uncovered: entire file
```

## Output

None — writes directly to the host with `Write-Host`.

## See Also

- [Source Maps Guide](../guides/source-maps.md#translating-pester-code-coverage)
- [Cmdlet Reference: Get-PSScriptBuilderSourceCoverage](Get-PSScriptBuilderSourceCoverage.md)
