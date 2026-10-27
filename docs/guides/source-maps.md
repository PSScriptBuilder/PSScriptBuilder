# Source Maps

A **source map** links every line of the compiled output script back to the source file and
line it was generated from. This makes it possible to resolve runtime errors in the output
script directly to the originating source file, and to translate Pester code coverage —
measured against the built output — back to per-source-file results, without manually
searching through the combined output.

The following examples use [Example 16 — Source Maps](../examples.md#16-source-maps) and
[Example 17 — Code Coverage](../examples.md#17-code-coverage) — two closely related HR
projects, both built around an `Employee` class inheriting from `Person`, a `New-Employee`
factory function, and a `Get-EmployeeById` lookup function that throws when an ID isn't found.
Example 17 adds one more function, `Get-EmployeesByDepartment`, specifically to demonstrate a
third coverage outcome.

---

## Generating a Source Map

To make a build's output resolvable back to source later, write a source map alongside it.
Pass `-WriteSourceMap` to `Invoke-PSScriptBuilderBuild` and PSScriptBuilder writes a sidecar
`.sourcemap.json` file next to the output script after each successful build:

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions' |
    Invoke-PSScriptBuilderBuild `
        -TemplatePath 'build\Templates\HRTools.ps1.template' `
        -OutputPath   'build\Output\HRTools.ps1' `
        -WriteSourceMap
```

The sidecar is written alongside the output file with `.sourcemap.json` appended to the file name:

```
build\Output\HRTools.ps1
build\Output\HRTools.ps1.sourcemap.json   ← generated automatically
```

The sidecar path is stored in `$result.SourceMapPath` and shown by `Format-PSScriptBuilderBuildResult` when present.

The sidecar stores a SHA-256 hash of the output file at build time. If the output script is
modified or rebuilt without `-WriteSourceMap` afterward,
`Resolve-PSScriptBuilderSourceLocation` emits a warning before resolving — line numbers may
no longer be accurate.

`-WriteSourceMap` is also available on `Watch-PSScriptBuilderProject` (Build mode). The
sidecar is updated after every successful automatic rebuild.

### Enabling via Configuration File

To generate a source map for every configuration-based build, set `writeSourceMap` to `true`
in `psscriptbuilder.config.json`:

```json
"build": {
    "writeSourceMap": true
}
```

This is equivalent to always passing `-WriteSourceMap` to `Invoke-PSScriptBuilderBuild`.

## Resolving Source Locations

Once a source map exists, you can resolve output locations back to source in three ways —
from a specific line number, from a caught error, or by listing every entry at once.

### Resolving a Line Number

To map a specific output line number back to its source, read the sidecar with
[`Resolve-PSScriptBuilderSourceLocation`](../cmdlets/Resolve-PSScriptBuilderSourceLocation.md):

```powershell
Resolve-PSScriptBuilderSourceLocation `
    -OutputPath 'build\Output\HRTools.ps1' `
    -LineNumber 41
```

```text title="Output"
ComponentName       : Get-EmployeeById
ComponentType       : Function
SourceFile          : C:\Projects\HRTools\src\Functions\Get-EmployeeById.ps1
SourceLineNumber    : 11
ComponentLineNumber : 1
OutputLineNumber    : 31
Offset              : 10
```

`OutputLineNumber` is where `Get-EmployeeById` itself begins in the output — not the queried
line. `Offset` is the distance from that start to line 41; adding it to `ComponentLineNumber`
gives `SourceLineNumber`, the corresponding line inside the original source file.

### Resolving an ErrorRecord

The most common use case is tracing an error thrown when the output script is dot-sourced or
executed. Pass the `$_` ErrorRecord directly — `Resolve-PSScriptBuilderSourceLocation`
extracts the line number from `InvocationInfo.ScriptLineNumber` automatically:

```powershell
. $result.OutputPath

$employees = @(
    New-Employee -Id 1 -FirstName 'Anna'  -LastName 'Schmidt' -Department 'Engineering'
    New-Employee -Id 2 -FirstName 'James' -LastName 'Okafor'  -Department 'Finance'
)

try {
    Get-EmployeeById -Employees $employees -Id 999
}
catch {
    Write-Host "Error at output line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_
}
```

```text title="Output"
Error at output line 43: Employee with Id 999 was not found.

ComponentName       : Get-EmployeeById
ComponentType       : Function
SourceFile          : C:\Projects\HRTools\src\Functions\Get-EmployeeById.ps1
SourceLineNumber    : 13
ComponentLineNumber : 1
OutputLineNumber    : 31
Offset              : 12
```

`Get-EmployeeById` throws when no employee matches the given `Id` — line 13 of the source file
is exactly the `throw` statement. The cmdlet accepts a `PSScriptBuilderBuildResult` from the
pipeline, so no separate `-OutputPath` is needed when the build result is in scope.

### Inspecting the Full Source Map

To verify the final component order in the output — or just see everything the source map
recorded at once — omit `-LineNumber` and `-ErrorRecord` to retrieve every entry as a
formatted table:

```powershell
$result | Resolve-PSScriptBuilderSourceLocation | Format-Table
```

```text title="Output"
ComponentName    ComponentType SourceFile
-------------    ------------- ----------
Person           Class         C:\Projects\HRTools\src\Classes\Person.ps1
Employee         Class         C:\Projects\HRTools\src\Classes\Employee.ps1
Get-EmployeeById Function      C:\Projects\HRTools\src\Functions\Get-EmployeeById.ps1
New-Employee     Function      C:\Projects\HRTools\src\Functions\New-Employee.ps1
```

The order matches the topological sort — both classes before either function, `Person` before
`Employee` since it inherits from it — the same guarantee described in the
[Dependency Analysis Guide](dependency-analysis.md#topological-sort).

## Translating Pester Code Coverage

In a typical PowerShell project, Pester's `CodeCoverage.Path` points directly at the source
files you want to measure — the files Pester instruments are the same files that actually ran.

That assumption breaks whenever tests load the **built, merged output** as a single unit
instead of the original per-file sources — most commonly because classes require `using
module` to load correctly across files, but the same is true for a plain `.ps1` output
dot-sourced directly in a `BeforeAll` block.

Either way, every executed `ScriptBlock`'s origin is the file that was actually parsed — the
built output, not the individual source files it was assembled from. Pester has no record of
executing code from files it never loaded.

**`CodeCoverage.Path` must therefore point at the built output script, not at the source
tree.** Point it at the wrong location and Pester still runs without error — it just reports
nothing useful, since it never sees any of the source files execute.

The following three steps put this into practice: build with a source map, run Pester against
the output, then translate the result back to source.

### 1. Build with a Source Map

A source map is required to translate the results back in Step 3:

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions' |
    Invoke-PSScriptBuilderBuild `
        -TemplatePath 'build\Templates\HRTools.ps1.template' `
        -OutputPath   'build\Output\HRTools.ps1' `
        -WriteSourceMap
```

### 2. Run Pester with CodeCoverage.Path Pointed at the Built Output

Point `CodeCoverage.Path` at the build's output script, not at the source tree:

```powershell
Import-Module -Name Pester -MinimumVersion 5.0 -Force

$config = [PesterConfiguration]::Default
$config.Run.Path             = 'tests'
$config.Run.PassThru         = $true
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path    = $result.OutputPath

$pesterResult = Invoke-Pester -Configuration $config
```

`[PesterConfiguration]` is only available once Pester 5 or later is loaded — if an older
Pester version is already loaded in the session, `-MinimumVersion 5.0 -Force` ensures the
correct one is used instead.

Pointing `CodeCoverage.Path` at `src\Classes` (or anywhere other than the built output)
produces no error from Pester itself — it just measures nothing useful, and the problem only
surfaces in Step 3. See
[Code coverage reports 0% or "referenced a file other than the build output"](../troubleshooting.md#code-coverage-reports-0-or-referenced-a-file-other-than-the-build-output)
in Troubleshooting if you run into this.

### 3. Translate and Display

To translate the raw, output-line-based coverage result from Step 2 back to per-source-file
aggregates, read the sidecar written in Step 1 with
[`Get-PSScriptBuilderSourceCoverage`](../cmdlets/Get-PSScriptBuilderSourceCoverage.md):

```powershell
$result | Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
    Format-PSScriptBuilderSourceCoverage
```

`SourceFile` is shown relative to the project root — falling back to the original absolute
path for a file outside it, e.g. a collector `IncludePath` pointed at a network share.

```text title="Output"
SourceFile                                    Coverage  Hit/Total
--------------------------------------------  --------  ---------
src\Classes\Person.ps1                         100.0 %        2/2
src\Classes\Employee.ps1                       100.0 %        2/2
src\Functions\Get-EmployeeById.ps1              71.4 %        5/7
src\Functions\New-Employee.ps1                 100.0 %        1/1
src\Functions\Get-EmployeesByDepartment.ps1      0.0 %        0/4
```

Add `-Detailed` to additionally list every distinct source line not covered by any test beneath
its file — useful when deciding where to add a test next, rather than only knowing which file
needs attention.

A single line can hold several missed commands (e.g. a pipeline inside a subexpression), but
each line is only listed once; consecutive lines are collapsed into a single range, and long
lists wrap at a fixed width with a hanging indent so a badly-fragmented file doesn't produce
one unreadably long line:

```powershell
$result | Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
    Format-PSScriptBuilderSourceCoverage -Detailed
```

```text
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

A file at 0% coverage shows `uncovered: entire file` instead of enumerating every line -
enumerating would always resolve to "the whole file" at that point, which the `Coverage`
column already says.

`Get-PSScriptBuilderSourceCoverage` accepts a `PSScriptBuilderBuildResult` from the pipeline,
as used in Step 3, or an explicit `-OutputPath`, mirroring `Resolve-PSScriptBuilderSourceLocation`. It
also emits a warning if the source map itself is stale — the output script changed since
`-WriteSourceMap` last wrote it.

---

## See Also

- [Build Pipeline Guide](build-pipeline.md) — `-WriteSourceMap` is a build-time option; running a build is a prerequisite for everything on this page
- [Type Reference: Source Maps & Code Coverage](../reference/types.md#source-maps-code-coverage) — full `PSScriptBuilderSourceLocation` and `PSScriptBuilderSourceCoverageResult` property tables
- [Code Analysis Guide](code-analysis.md) — structural analysis without building, if you don't yet have a build to trace
- [Troubleshooting](../troubleshooting.md) — coverage and source map related error messages
- [Cmdlet Reference: Resolve-PSScriptBuilderSourceLocation](../cmdlets/Resolve-PSScriptBuilderSourceLocation.md)
- [Cmdlet Reference: Get-PSScriptBuilderSourceCoverage](../cmdlets/Get-PSScriptBuilderSourceCoverage.md)
- [Cmdlet Reference: Format-PSScriptBuilderSourceCoverage](../cmdlets/Format-PSScriptBuilderSourceCoverage.md)
