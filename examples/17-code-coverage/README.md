# Example 17 - Code Coverage

This example demonstrates the code coverage translation feature: mapping a Pester
`CodeCoverage` result — reported against the built, merged output script — back to
per-source-file coverage. It builds directly on the source map feature introduced in
[Example 16](../16-source-maps/): the build below writes its own `.sourcemap.json` sidecar
(into this example's own `build\Output\`), which `Get-PSScriptBuilderSourceCoverage` then
reads to do the translation.

In a typical PowerShell project, Pester's `CodeCoverage.Path` points directly at the source
files you want to measure. That assumption breaks once tests load a **built, merged output**
as a single unit — which is required here because `Employee` inherits from `Person` across
separate files, and PowerShell classes need `using module`/dot-sourcing of the already
type-resolved output to load correctly. Every executed `ScriptBlock`'s origin is the file that
was actually parsed — the built output, not the individual source files it was assembled
from. `Get-PSScriptBuilderSourceCoverage` translates the raw, output-line-based Pester result
back to the original source files using that sidecar.

## New in this example

- `Get-PSScriptBuilderSourceCoverage` — translates a Pester `CodeCoverage` result back to per-source-file coverage aggregates, using the sidecar written by `-WriteSourceMap`
- `Format-PSScriptBuilderSourceCoverage` — displays the result as an aligned table (`SourceFile` shown relative to the project root); `-Detailed` additionally lists every distinct source line not covered by any test, collapsing consecutive lines into a range and a 0%-covered file into `uncovered: entire file`

## Key concepts

**The test suite in this example is deliberately incomplete** (`tests\HRTools.Tests.ps1`) —
not to model good testing practice, but to produce a realistic, mixed coverage report with
three distinct outcomes in a single run:

| Source file | Coverage | Why |
|---|---|---|
| `Person.ps1`, `Employee.ps1`, `New-Employee.ps1` | 100% | Every test constructs an `Employee`, exercising both classes and the factory function |
| `Get-EmployeeById.ps1` | Partial | Only the "found" path is tested; the "not found" branch (the `throw`) is never reached |
| `Get-EmployeesByDepartment.ps1` | 0% | Built into the output, but no test ever calls it |

**Three steps, same as [`docs/guides/source-maps.md`](../../docs/guides/source-maps.md#translating-pester-code-coverage):**

1. **Build with `-WriteSourceMap`** — same as Example 16, required to translate results back in step 3.
2. **Run Pester with `CodeCoverage.Path` pointed at the built output** (`build\Output\HRTools.ps1`), not at `src\` — pointing it at `src\` produces no error, just a meaningless 0% everywhere, since Pester never sees any of the source files execute.
3. **Translate and display** via `Get-PSScriptBuilderSourceCoverage | Format-PSScriptBuilderSourceCoverage -Detailed`.

## Project structure

```
17-code-coverage/
+-- Run-Example.ps1                        Entry point
+-- README.md                              This file
+-- src/
|   +-- Classes/
|   |   +-- Person.ps1                     Class: FirstName, LastName
|   |   +-- Employee.ps1                   Class: inherits Person, adds Id and Department
|   +-- Functions/
|       +-- New-Employee.ps1               Factory function for Employee
|       +-- Get-EmployeeById.ps1           Lookup by Id; throws KeyNotFoundException if not found
|       +-- Get-EmployeesByDepartment.ps1  Filter by Department - never called by any test
+-- tests/
|   +-- HRTools.Tests.ps1                  Deliberately incomplete Pester suite (see comment at its top)
+-- build/
    +-- Templates/
    |   +-- HRTools.ps1.template           Same template as Example 16
    +-- Output/                            Generated output (not committed to source control)
```

## How to run

> **Warning:** Run in a fresh PowerShell session
> The `using module` statement loads types into the current session.
> Reloading or switching between examples in the same session can cause type conflicts.

```powershell
.\Run-Example.ps1
```

Requires Pester 5.0 or later (`Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser`
if not already installed).

## Expected output

```
WARNING: 3 cross-collector dependency(s) detected. Verify template placeholder order. Run with -Verbose for details.

Build Summary
  Output : ...\build\Output\HRTools.ps1
  Size   : x.xx KB
  Time   : xxx ms
  Map    : ...\build\Output\HRTools.ps1.sourcemap.json

Components
  Classes   : 2
  Functions : 3
  Total     : 5

Pester v5.7.1

Starting discovery in 1 files.
Discovery found 2 tests in xxx ms.
Starting code coverage.
Code Coverage preparation finished after xxx ms.
Running tests.

Running tests from '...\tests\HRTools.Tests.ps1'
Describing New-Employee
  [+] Creates an Employee with the given properties xxx ms

Describing Get-EmployeeById
  [+] Returns the employee with the matching Id xxx ms
Tests completed in xxx ms
Tests Passed: 2, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
Processing code coverage result.
Code Coverage result processed in xxx ms.
Covered 62.5% / 75%. 16 analyzed Commands in 1 File.
Missed commands:

File        Class Function                  Line Command
----        ----- --------                  ---- -------
HRTools.ps1       Get-EmployeesByDepartment   58 return @($Employees | Where-Object { $_.Department -eq $Department })
HRTools.ps1       Get-EmployeesByDepartment   58 $Employees
HRTools.ps1       Get-EmployeesByDepartment   58 Where-Object { $_.Department -eq $Department }
HRTools.ps1       Get-EmployeesByDepartment   58 $_.Department -eq $Department
HRTools.ps1       Get-EmployeeById            72 $message = "Employee with Id {0} was not found." -f $Id
HRTools.ps1       Get-EmployeeById            73 throw [System.Collections.Generic.KeyNotFoundException]::new($message)

=== Source coverage, by original file ===

SourceFile                                    Coverage  Hit/Total
--------------------------------------------  --------  ---------
src\Classes\Person.ps1                         100.0 %        2/2
src\Classes\Employee.ps1                       100.0 %        2/2
src\Functions\New-Employee.ps1                 100.0 %        1/1
src\Functions\Get-EmployeeById.ps1              71.4 %        5/7
  uncovered: lines 12-13
src\Functions\Get-EmployeesByDepartment.ps1      0.0 %        0/4
  uncovered: entire file
```

`SourceFile` is shown relative to the project root that `Set-PSScriptBuilderProjectRoot`
registered at the top of `Run-Example.ps1` (this example's own folder) - not the full absolute
path.

The warning about cross-collector dependencies is expected and harmless here — `New-Employee`,
`Get-EmployeeById`, and `Get-EmployeesByDepartment` all reference the `Employee` class, so
PSScriptBuilder flags the Function-to-Class dependency for the template author to verify
(see [Example 07](../07-ordered-mode/) for when this actually requires Ordered Mode).

The `12-13` range in `Get-EmployeeById.ps1` is the `throw` branch's message formatting and the
`throw` itself — two adjacent lines, collapsed into one range instead of printed separately.
They are never reached because the test suite only ever looks up existing Ids.
`Get-EmployeesByDepartment.ps1` shows `uncovered: entire file` instead of a line number: at 0%
coverage, enumerating would always resolve to "the whole file" - information the `Coverage`
column already gives, so nothing is gained by listing it. Exact percentages depend on the
template and source files; the fact that three different outcomes (full, partial, zero) show
up side by side in one table is what this example demonstrates.

Notice the contrast between Pester's own "Missed commands" report and the table below it:
Pester reports lines 58, 72, and 73 — real line numbers, but in `HRTools.ps1`, the merged
output file, which doesn't exist in the `src\` tree you actually edit. `Get-PSScriptBuilderSourceCoverage`
translates those same missed commands back to `Get-EmployeesByDepartment.ps1` (shown as
`uncovered: entire file`, since the whole file is 0% covered) and the 12-13 range in
`Get-EmployeeById.ps1` in the original source files — this translation step is exactly what
the example demonstrates.
