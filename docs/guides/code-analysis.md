# Code Analysis

PSScriptBuilder's analysis cmdlets let you inspect your project's structure without running a
build. No output script is written — the collectors run, the data is extracted, and you get
back strongly-typed result objects to work with directly.

Three distinct capabilities fall under this umbrella: querying the raw component data a
collector extracted from your source files, examining the full dependency graph and load
order, and checking which template validation mode your project activates. This guide's main
focus is the first of these — direct, low-level access to collector content — since that level
of detail isn't covered anywhere else. Dependency analysis and template analysis are each
substantial enough to warrant their own guide, so they're introduced here only briefly, with a
pointer to the full treatment.

Collector content queries are especially useful for debugging dependency issues without
running a full dependency graph, understanding exactly how PSScriptBuilder sees your code, and
building tooling or reports on top of the collected data.

---

## Collector Content

To inspect exactly what PSScriptBuilder extracted from your source files — without building
anything — retrieve a collector's raw content directly.
[`Get-PSScriptBuilderCollectorContent`](../cmdlets/Get-PSScriptBuilderCollectorContent.md)
returns one strongly-typed object per collected component; pass a collector instance directly
using `-Collector` or via the pipeline, and it executes the collector for you automatically.

The returned objects are typed data classes — not `PSCustomObject`. The exact properties
depend on the collector type:

| Collector Type | Returned Type                  | Key Properties |
|----------------|--------------------------------|---|
| `Using`        | `PSScriptBuilderUsingData`     | `Statement`, `SourceFiles` |
| `Enum`         | `PSScriptBuilderEnumData`      | `Name`, `SourceCode` |
| `Class`        | `PSScriptBuilderClassData`     | `Name`, `SourceCode`, `BaseClass`, `TypeReferences`, `StaticInitializerReferences`, `CalledFunctions` |
| `Function`     | `PSScriptBuilderFunctionData`  | `Name`, `SourceCode`, `CalledFunctions`, `TypeReferences` |
| `File`         | `PSScriptBuilderFileData`      | `FileName`, `FullPath`, `Content` |

For a full explanation of what each property contains and how it is populated, see
[Collected Data Properties](collectors.md#collected-data-properties) in the Collectors Guide.

!!! note "Setup — PSScriptBuilder"
    All examples in this section query PSScriptBuilder's own source tree. Run the following
    from the root of a PSScriptBuilder checkout to populate `$classes` and `$functions`, reused
    by the Class and Function query examples that follow. The Enum, Using, and File examples
    under [Other Collector Types](#other-collector-types) are each self-contained instead,
    creating their own variable inline since each is used only once.
    ```powershell
    $classes = New-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
        Get-PSScriptBuilderCollectorContent

    $functions = New-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
        Get-PSScriptBuilderCollectorContent
    ```

### Class Collector Queries

#### Find classes with a base class

Filtering by `BaseClass` gives you a complete picture of your class hierarchy.
This is useful when you want to verify that all expected derived classes are present,
or when you are debugging a dependency error caused by a missing base class:

```powershell
$classes | Where-Object { $_.BaseClass } | Select-Object Name, BaseClass
```

```text title="Output"
Name                             BaseClass
----                             ---------
PSScriptBuilderBuildOptions      PSScriptBuilderOptionsBase
PSScriptBuilderReleaseOptions    PSScriptBuilderOptionsBase
PSScriptBuilderClassCollector    PSScriptBuilderCollectorBase
PSScriptBuilderEnumCollector     PSScriptBuilderCollectorBase
PSScriptBuilderFileCollector     PSScriptBuilderCollectorBase
PSScriptBuilderFunctionCollector PSScriptBuilderCollectorBase
PSScriptBuilderUsingCollector    PSScriptBuilderCollectorBase
```

Seven classes in PSScriptBuilder's own source inherit from something: two configuration classes
share `PSScriptBuilderOptionsBase`, and five collector implementations share
`PSScriptBuilderCollectorBase`.

#### Find all subclasses of a specific base class

The reverse of the previous query — instead of asking "which classes have a base class?",
this asks "which classes inherit from a specific type?". Useful when you want to verify a
concrete class hierarchy or understand the full extent of a base class:

```powershell
$classes |
    Where-Object { $_.BaseClass -eq "PSScriptBuilderCollectorBase" } |
    Select-Object Name
```

```text title="Output"
Name
----
PSScriptBuilderClassCollector
PSScriptBuilderEnumCollector
PSScriptBuilderFileCollector
PSScriptBuilderFunctionCollector
PSScriptBuilderUsingCollector
```

#### Find classes that reference a specific type

When you are about to change a class, this query shows which other classes depend on it
directly — a lightweight impact analysis without running a full dependency graph:

```powershell
$classes |
    Where-Object { $_.TypeReferences -contains "PSScriptBuilderFileSystemHelper" } |
    Select-Object Name
```

Output (18 matches; first 6 shown):

```
Name
----
PSScriptBuilderFileSystemHelper
PSScriptBuilderConfigLoader
PSScriptBuilderConfiguration
PSScriptBuilderBuildOptions
PSScriptBuilderBumpConfigFileManager
PSScriptBuilderBumpFilesProcessor
```

`PSScriptBuilderFileSystemHelper` is one of PSScriptBuilder's most widely used helper classes —
18 other classes reference it directly.

#### Validate that expected components are present

Use this pattern in a CI pipeline or pre-build script to assert that all required
components were collected. If a file is missing, misconfigured, or excluded by a filter,
the check will catch it before the build fails with a harder-to-diagnose error:

```powershell
$expected = @(
    "PSScriptBuilderCollectorBase",
    "PSScriptBuilderOptionsBase",
    "PSScriptBuilderNonExistentHelper"
)
$missing  = $expected | Where-Object { $_ -notin $classes.Name }

if ($missing) {
    Write-Error "Missing classes: $($missing -join ', ')"
}
```

```text title="Output"
Write-Error: Missing classes: PSScriptBuilderNonExistentHelper
```

#### Find classes with static initializer references

Static initializer references are types used in static property initializer expressions — for
example `static [MyClass] $Default = [MyClass]::new()`. These create the same
hard ordering constraint as inheritance: the referenced type must already be defined when
PowerShell loads the class. See the [Dependency Analysis Guide](dependency-analysis.md) for
details.

Use this query to identify classes that carry this constraint. If the referenced type is not a
project-internal type — for example a .NET framework type — PSScriptBuilder will skip it when
building the dependency graph, which is expected and correct:

```powershell
$classes |
    Where-Object { $_.StaticInitializerReferences.Count -gt 0 } |
    Select-Object Name, StaticInitializerReferences
```

```text title="Output"
Name                         StaticInitializerReferences
----                         ---------------------------
PSScriptBuilderFileIOHelper  {UTF8Encoding}
PSScriptBuilderAstEngine     {HashSet, StringComparer}
```

Only two classes in PSScriptBuilder's own source carry this constraint — both reference .NET
framework types (`UTF8Encoding`, `HashSet`, `StringComparer`), which PSScriptBuilder correctly
excludes from the dependency graph rather than treating as a project-internal ordering
requirement.

#### Count type references per class

`TypeReferences` contains all non-built-in types referenced in a class — in property
declarations, method parameters, return types, and method bodies. The count gives you a
rough measure of how many other components a class depends on. Classes with a high count
tend to be orchestrators or aggregators that depend on many other types:

```powershell
$classes |
    Select-Object Name, @{ Name = 'Dependencies'; Expression = { $_.TypeReferences.Count } } |
    Sort-Object Dependencies -Descending |
    Select-Object -First 5
```

```text title="Output"
Name                                         Dependencies
----                                         ------------
PSScriptBuilderAstEngine                               29
PSScriptBuilderBuildOrchestrator                       27
PSScriptBuilderReleaseManagementOrchestrator           21
PSScriptBuilderTemplateAnalyzer                        17
PSScriptBuilderProjectWatcher                          16
```

`PSScriptBuilderAstEngine` — the class responsible for parsing PowerShell source with the AST —
references more other types than anything else in the project, which fits its role as the
foundation the rest of the collectors build on.

#### Retrieve the source code of a specific component

When debugging a build or inspecting what PSScriptBuilder extracted, you can retrieve the
exact source code that will end up in the generated output script. This is especially useful
when the generated script contains unexpected content and you want to trace it back to the
source:

```powershell
$classCollector = New-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes"
$data = Get-PSScriptBuilderCollectorContent `
    -Collector $classCollector `
    -ItemName "PSScriptBuilderSourceRange"
Write-Host $data.SourceCode
```

```powershell title="Output"
class PSScriptBuilderSourceRange {
    [int] $StartLineNumber
    [int] $EndLineNumber

    PSScriptBuilderSourceRange([int] $startLineNumber, [int] $endLineNumber) {
        $this.StartLineNumber = $startLineNumber
        $this.EndLineNumber   = $endLineNumber
    }
}
```

(Comment-based help trimmed for brevity — the real source includes full documentation for
every member.)

### Function Collector Queries

#### Find functions that call other functions

The Function collector records which other functions each function calls. This information
is used to determine function call edges in the dependency graph. You can query it directly
to understand which functions are entry points and which are helpers called by others:

```powershell
$functions |
    Where-Object { $_.CalledFunctions.Count -gt 0 } |
    Select-Object Name, CalledFunctions
```

Output (29 matches; first 5 shown):

```
Name                                   CalledFunctions
----                                   ---------------
Add-PSScriptBuilderCollector           {New-PSScriptBuilderCollector}
Compress-PSScriptBuilderScript         {Write-Warning, Write-Verbose}
Export-PSScriptBuilderBuildResult      {Write-Verbose}
Export-PSScriptBuilderDependencyGraph  {Write-Verbose}
Find-PSScriptBuilderUnusedComponent    {Write-Warning}
```

`CalledFunctions` records every command called within the function body, not just other
PSScriptBuilder functions — which is why most of these entries only list
`Write-Warning`/`Write-Verbose` calls. `Add-PSScriptBuilderCollector` is the one shown here
that also calls another PSScriptBuilder function directly (`New-PSScriptBuilderCollector`),
reflecting genuine composition between the two cmdlets.

#### Find public entry points

Functions that are never called by other functions are likely public entry points — the
top-level cmdlets or commands that users invoke directly. This query builds a set of all
internally called function names and filters them out, leaving only the uncalled ones:

```powershell
$calledFunctions = $functions.CalledFunctions |
    ForEach-Object { $_ } |
    Sort-Object -Unique

$functions |
    Where-Object { $_.Name -notin $calledFunctions } |
    Select-Object Name
```

Output (37 matches; first 5 shown):

```
Name
----
Add-PSScriptBuilderCollector
Compress-PSScriptBuilderScript
ConvertTo-PSScriptBuilderComponentDependencyTree
Export-PSScriptBuilderBuildResult
Export-PSScriptBuilderDependencyGraph
```

Every one of PSScriptBuilder's 38 public functions except one turns out to be a genuine entry
point — expected, since public cmdlets are meant to be called from outside the project, not
from within it. The one exception is `New-PSScriptBuilderCollector`, called internally by
`Add-PSScriptBuilderCollector` — the same composition already seen in
[Find functions that call other functions](#find-functions-that-call-other-functions). It's
still a genuine, independently useful public cmdlet; it just also happens to be composed into
another one.

### Other Collector Types

Using and Enum collectors have fewer queryable properties than Class and Function, but the
same `Get-PSScriptBuilderCollectorContent` pattern applies to all of them.

#### Enum collector

```powershell
$enums = New-PSScriptBuilderCollector -Type Enum -IncludePath "src\Enums" |
    Get-PSScriptBuilderCollectorContent

$enums | Select-Object Name
```

```text title="Output"
Name
----
PSScriptBuilderBumpPatternMode
PSScriptBuilderBumpType
PSScriptBuilderCollectorType
PSScriptBuilderDependencyEdgeType
PSScriptBuilderTemplateValidationMode
PSScriptBuilderTraversalDirection
PSScriptBuilderUnusedComponentType
```

#### Using collector

`SourceFiles` tracks every file where a given `using` statement appears, so its count shows how
widely a namespace or module is used across the project:

```powershell
$usings = New-PSScriptBuilderCollector -Type Using -IncludePath "src" |
    Get-PSScriptBuilderCollectorContent

$usings |
    Select-Object Statement, @{ Name = 'FileCount'; Expression = { $_.SourceFiles.Count } } |
    Sort-Object FileCount -Descending |
    Select-Object -First 5
```

```text title="Output"
Statement                                      FileCount
---------                                      ---------
using namespace System                                62
using namespace System.Collections.Generic            51
using namespace System.IO                             32
using namespace System.Text                           13
using namespace System.Collections.Specialized         7
```

#### File collector

File collectors don't parse content as PowerShell at all — they pass through the raw text of
any file unchanged. Use this for content with no AST to analyze: license headers,
configuration files, or documentation you want to embed verbatim in the generated output.
`-IncludeFile` targets a single file directly, rather than scanning a directory for a
component type:

```powershell
$file = New-PSScriptBuilderCollector -Type File -IncludeFile "CHANGELOG.md" |
    Get-PSScriptBuilderCollectorContent

$file.FileName
```

```text title="Output"
CHANGELOG.md
```

`FullPath` and `Content` give you the same file's absolute path and complete text, for
inspecting or re-embedding it elsewhere.

---

## Analysing a Monolithic Script

When migrating from a monolithic `.ps1` or `.psm1` to a PSScriptBuilder project — such as the
one used in [Example 02 — Classes and Enums](../examples.md#02-classes-and-enums) — the first
step is identifying all components in the existing file. Instead of scanning the file manually,
point all collector types at the single file using `-IncludeFile` and let PSScriptBuilder
extract the inventory automatically.

```powershell
$scriptPath = 'C:\Projects\HRModule\HRModule.psm1'

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludeFile $scriptPath |
    Add-PSScriptBuilderCollector -Type Class    -IncludeFile $scriptPath |
    Add-PSScriptBuilderCollector -Type Function -IncludeFile $scriptPath

$contentCollector | Get-PSScriptBuilderCollector | ForEach-Object {
    $items = $_ | Get-PSScriptBuilderCollectorContent
    "$($_.CollectorType) : $($items.Name -join ', ')"
}
```

This outputs:

```
EnumCollector     : Department, EmploymentStatus
ClassCollector    : Person, Address, Employee
FunctionCollector : New-Employee, Get-EmployeesByDepartment, Set-EmployeeStatus
```

This is the exact list of files to create when splitting the monolith — one file per component.

### Extracting Components to Individual Files

Since each collected component already carries its own `SourceCode`, the same collectors can
write every component straight to its own file — no manual copy-pasting required. Map each
`CollectorType` to the folder convention PSScriptBuilder projects use, then write one file per
component:

```powershell
$folderByType = @{
    EnumCollector     = 'Enums'
    ClassCollector    = 'Classes'
    FunctionCollector = 'Public'
}

$collectors = $contentCollector | Get-PSScriptBuilderCollector

foreach ($collector in $collectors) {
    $folderName = $folderByType[$collector.CollectorType.ToString()]
    $folder     = Join-Path 'src' $folderName
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    $components = $collector | Get-PSScriptBuilderCollectorContent
    foreach ($component in $components) {
        $filePath = Join-Path $folder "$($component.Name).ps1"
        Set-Content -Path $filePath -Value $component.SourceCode
        Write-Host "Created $filePath"
    }
}
```

For Example 02, this creates:

```
src\Enums\Department.ps1
src\Enums\EmploymentStatus.ps1
src\Classes\Person.ps1
src\Classes\Address.ps1
src\Classes\Employee.ps1
src\Public\New-Employee.ps1
src\Public\Get-EmployeesByDepartment.ps1
src\Public\Set-EmployeeStatus.ps1
```

Each generated file matches the original component's source exactly — this is genuine
extraction, not a reformatted copy.

For the step-by-step migration workflow — planning the directory structure, setting up
PSScriptBuilder, and verifying the first build — see
[Migrating to PSScriptBuilder](../tutorials/migrating-to-psscriptbuilder.md).

---

## Dependency Analysis

To understand load order, detect cycles, or check for cross-dependencies without running a
build, run a full dependency analysis.
[`Get-PSScriptBuilderDependencyAnalysis`](../cmdlets/Get-PSScriptBuilderDependencyAnalysis.md)
executes all collectors, builds the dependency graph, runs cycle detection, and returns a
single result object with everything — there's no need to run the collectors separately first.
The following example uses PSScriptBuilder's own real build configuration — the same
collectors it uses to build itself:

```powershell title="Run a full dependency analysis"
$usingCollector    = New-PSScriptBuilderCollector -Type Using    -IncludePath "src"
$enumCollector     = New-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums"
$classCollector    = New-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes"
$functionCollector = New-PSScriptBuilderCollector -Type Function -IncludePath "src\Private", "src\Public"

$contentCollector = New-PSScriptBuilderContentCollector `
    -Collector @($usingCollector, $enumCollector, $classCollector, $functionCollector)

$analysis = $contentCollector | Get-PSScriptBuilderDependencyAnalysis
$analysis | Format-PSScriptBuilderDependencyAnalysis
```

```text title="Output"
Analysis Summary
  Components : 144
  Nodes      : 133
  Edges      : 337
  Cycles     : None
  Cross-Deps : Detected

Components
  Using     :  11
  Enums     :   7
  Classes   :  87
  Functions :  39
  Total     : 144
```

PSScriptBuilder's own source genuinely has cross-dependencies (classes and functions
interleaved in the load order) but no cycles — exactly the mix a real, mature project
accumulates over time.

The underlying `$analysis` object also exposes every property directly —
`HasCrossDependencies`, `OrderedComponents`, `HasCycles`, `CyclePath`, `ComponentCounts`, and
the full `DependencyGraph` — for scripts that need to branch on a specific value rather than
just display it. For querying individual components, rendering dependency trees, and
exporting the graph, see `Get-PSScriptBuilderComponentDependency`,
`ConvertTo-PSScriptBuilderComponentDependencyTree`, and `Export-PSScriptBuilderDependencyGraph`
in the [Dependency Analysis Guide](dependency-analysis.md), which also contains a complete
walkthrough of all result properties and use cases.

To identify **unused components** — classes, enums, or functions that nothing else depends on
— use [`Find-PSScriptBuilderUnusedComponent`](../cmdlets/Find-PSScriptBuilderUnusedComponent.md);
see [Dead Code Detection](dependency-analysis.md#dead-code-detection) in the
[Dependency Analysis Guide](dependency-analysis.md) for a complete worked example.

---

## Template Analysis

Before running a build — while designing or reviewing a template — you can verify exactly
which placeholders it declares, which validation mode it will activate, and whether anything
is missing or unexpected.
[`Get-PSScriptBuilderTemplateAnalysis`](../cmdlets/Get-PSScriptBuilderTemplateAnalysis.md)
extends the dependency analysis with exactly this template-specific information. The following
example reuses PSScriptBuilder's own real build configuration and checks its own real
template:

```powershell title="Run a template analysis"
$usingCollector    = New-PSScriptBuilderCollector -Type Using    -IncludePath "src"
$enumCollector     = New-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums"
$classCollector    = New-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes"
$functionCollector = New-PSScriptBuilderCollector -Type Function -IncludePath "src\Private", "src\Public"

$contentCollector = New-PSScriptBuilderContentCollector `
    -Collector @($usingCollector, $enumCollector, $classCollector, $functionCollector)

$templateAnalysis = $contentCollector |
    Get-PSScriptBuilderTemplateAnalysis -TemplatePath ".\build\Templates\PSScriptBuilder.psm1.template"
$templateAnalysis | Format-PSScriptBuilderTemplateAnalysis
```

```text title="Output"
Template Analysis
  Template   : C:\Projects\PSScriptBuilder\build\Templates\PSScriptBuilder.psm1.template
  Size       : 1025 characters
  Mode       : Ordered
  Key        : ORDERED_COMPONENTS
  Cross-Deps : Detected
  Status     : Valid

Placeholders
  Expected : {{ORDERED_COMPONENTS}}, {{USING_STATEMENTS}}
  Found    : {{ORDERED_COMPONENTS}}, {{USING_STATEMENTS}}
```

Every expected placeholder is present and nothing unexpected was found — confirming the
template is complete and correct. The underlying `$templateAnalysis` object also exposes
`ValidationMode`, `IsValid`, `MissingPlaceholders`, and `UnknownPlaceholders` directly, for
scripts that need to check a specific value rather than just display it.

See the [Templates Guide](templates.md) for a full explanation of validation modes, placeholder
rules, and all analysis result properties.

---

## See Also

- [Cmdlet Reference: Get-PSScriptBuilderCollectorContent](../cmdlets/Get-PSScriptBuilderCollectorContent.md)
- [Collectors Guide](collectors.md) — full Collected Data Properties reference with all properties and descriptions
- [Templates Guide](templates.md) — validation modes, placeholder rules, and template analysis result properties
- [Dependency Analysis Guide](dependency-analysis.md) — full dependency graph query reference
- [Source Maps Guide](source-maps.md) — tracing runtime errors and translating Pester code coverage back to source; requires an actual build and test run, unlike the static analysis in this guide
