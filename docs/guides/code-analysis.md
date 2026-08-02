# Code Analysis

PSScriptBuilder's analysis cmdlets let you inspect your project's structure without running a
build. You can query the raw component data collected from your source files, examine the
dependency graph, and verify which validation mode your template activates. No output script is
written — the collectors run, the data is extracted, and you get back strongly-typed result
objects to work with directly.

This is useful for debugging dependency issues, understanding how PSScriptBuilder sees your code,
or building tooling and reports on top of the collected data.

---

## Collector Content

[`Get-PSScriptBuilderCollectorContent`](../cmdlets/Get-PSScriptBuilderCollectorContent.md)
returns the raw component data from a collector that has already been executed — one object per
collected component. Pass a collector instance directly using `-Collector` or via the pipeline.

The snippet below creates a Class collector, executes it, and then displays a summary table of
all collected classes together with their base class — a quick way to verify that PSScriptBuilder
found every expected class and correctly identified its inheritance:

```powershell
$classCollector = New-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes"
$classCollector.Collect()

$classes = $classCollector | Get-PSScriptBuilderCollectorContent

$classes | Format-Table Name, BaseClass
```

The returned objects are typed data classes — not `PSCustomObject`. The exact properties
depend on the collector type:

| Collector Type | Returned Type                  | Key Properties |
|----------------|--------------------------------|---|
| `Using`        | `PSScriptBuilderUsingData`     | `Statement` |
| `Enum`         | `PSScriptBuilderEnumData`      | `Name`, `SourceCode` |
| `Class`        | `PSScriptBuilderClassData`     | `Name`, `SourceCode`, `BaseClass`, `TypeReferences`, `StaticInitializerReferences`, `CalledFunctions` |
| `Function`     | `PSScriptBuilderFunctionData`  | `Name`, `SourceCode`, `CalledFunctions`, `TypeReferences` |
| `File`         | `PSScriptBuilderFileData`      | `FileName`, `FullPath`, `Content` |

For a full explanation of what each property contains and how it is populated, see
[Collected Data Properties](collectors.md#collected-data-properties) in the Collectors Guide.

The following examples all assume that `$classes` was populated as shown above.

### Find classes with a base class

Filtering by `BaseClass` gives you a complete picture of your class hierarchy.
This is useful when you want to verify that all expected derived classes are present,
or when you are debugging a dependency error caused by a missing base class:

```powershell
$classes | Where-Object { $_.BaseClass } | Select-Object Name, BaseClass
```

### Find all subclasses of a specific base class

The reverse of the previous query — instead of asking "which classes have a base class?",
this asks "which classes inherit from a specific type?". Useful when you want to verify a
concrete class hierarchy or understand the full extent of a base class:

```powershell
$classes | Where-Object { $_.BaseClass -eq "MyBaseClass" } | Select-Object Name
```

### Find classes that reference a specific type

When you are about to change a class, this query shows which other classes depend on it
directly — a lightweight impact analysis without running a full dependency graph:

```powershell
$classes |
    Where-Object { $_.TypeReferences -contains "MyService" } |
    Select-Object Name
```

### Validate that expected components are present

Use this pattern in a CI pipeline or pre-build script to assert that all required
components were collected. If a file is missing, misconfigured, or excluded by a filter,
the check will catch it before the build fails with a harder-to-diagnose error:

```powershell
$expected = @("ServiceA", "ServiceB", "RepositoryBase")
$missing  = $expected | Where-Object { $_ -notin $classes.Name }

if ($missing) {
    Write-Error "Missing classes: $($missing -join ', ')"
}
```

### Find classes with static initializer references

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

### Find functions that call other functions

The Function collector records which other functions each function calls. This information
is used to determine function call edges in the dependency graph. You can query it directly
to understand which functions are entry points and which are helpers called by others:

```powershell
$functionCollector = New-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"
$functionCollector.Collect()

$functions = $functionCollector | Get-PSScriptBuilderCollectorContent

$functions |
    Where-Object { $_.CalledFunctions.Count -gt 0 } |
    Select-Object Name, CalledFunctions
```

### Find public entry points

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

### Count type references per class

`TypeReferences` contains all non-built-in types referenced in a class — in property
declarations, method parameters, return types, and method bodies. The count gives you a
rough measure of how many other components a class depends on. Classes with a high count
tend to be orchestrators or aggregators that depend on many other types:

```powershell
$classes |
    Select-Object Name, @{ Name = 'Dependencies'; Expression = { $_.TypeReferences.Count } } |
    Sort-Object Dependencies -Descending
```

### Retrieve the source code of a specific component

When debugging a build or inspecting what PSScriptBuilder extracted, you can retrieve the
exact source code that will end up in the generated output script. This is especially useful
when the generated script contains unexpected content and you want to trace it back to the
source:

```powershell
$data = Get-PSScriptBuilderCollectorContent -Collector $classCollector -ItemName "MyBaseClass"
Write-Host $data.SourceCode
```

---

## Analysing a Monolithic Script

When migrating from a monolithic `.ps1` or `.psm1` to a PSScriptBuilder project, the first
step is identifying all components in the existing file. Instead of scanning the file manually,
point all collector types at the single file using `-IncludeFile` and let PSScriptBuilder
extract the inventory automatically.

```powershell
$scriptPath = 'C:\Projects\HRModule\HRModule.psm1'

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludeFile $scriptPath |
    Add-PSScriptBuilderCollector -Type Class    -IncludeFile $scriptPath |
    Add-PSScriptBuilderCollector -Type Function -IncludeFile $scriptPath

$contentCollector.Execute()

$contentCollector | Get-PSScriptBuilderCollector | ForEach-Object {
    $items = $_ | Get-PSScriptBuilderCollectorContent
    "$($_.CollectorType) : $($items.Name -join ', ')"
}
```

For a monolithic HR project such as the one used in
[Example 02 — Classes and Enums](../examples.md#02-classes-and-enums), this might output:

```
Enum     : Department, EmploymentStatus
Class    : Address, Person, Employee
Function : New-Employee
```

This is the exact list of files to create when splitting the monolith — one file per component.

For the step-by-step migration workflow, see
[Migrating to PSScriptBuilder](../tutorials/migrating-to-psscriptbuilder.md).

---

## Dependency Analysis

[`Get-PSScriptBuilderDependencyAnalysis`](../cmdlets/Get-PSScriptBuilderDependencyAnalysis.md)
executes all collectors, builds the full dependency graph, runs cycle detection, and returns a
`PSScriptBuilderDependencyAnalysisResult` containing the complete analysis. There is no need to
run the collectors separately — the cmdlet handles that internally.

```powershell
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"  |
    Get-PSScriptBuilderDependencyAnalysis
```

The result object gives you access to `HasCrossDependencies`, `TopologicalOrder`,
`HasCycles`, `CyclePath`, `ComponentCounts`, and the full `DependencyGraph` — including
`GetDependencies()` (what a component depends on) and `GetDependents()` (what would be
affected by a change). For querying individual components, rendering dependency trees, and
exporting the graph, see `Get-PSScriptBuilderComponentDependency`,
`ConvertTo-PSScriptBuilderComponentDependencyTree`, and `Export-PSScriptBuilderDependencyGraph`
in the [Dependency Analysis Guide](dependency-analysis.md), which also contains a complete
walkthrough of all result properties and use cases.

To identify **unused components** — classes, enums, or functions that nothing else depends on
— use [`Find-PSScriptBuilderUnusedComponent`](../cmdlets/Find-PSScriptBuilderUnusedComponent.md):

```powershell
$unused = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums"   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"  |
    Find-PSScriptBuilderUnusedComponent -EntryPoint "*-MyProject*"
```

Use `-EntryPoint` with a glob pattern matching your public cmdlets to perform a transitive
reachability analysis: only components not reachable from any matched entry point are returned.
Without `-EntryPoint`, all components with no incoming dependency edges are reported —
including public cmdlets themselves, since they are called externally and have no callers
within the graph.

---

## Template Analysis

[`Get-PSScriptBuilderTemplateAnalysis`](../cmdlets/Get-PSScriptBuilderTemplateAnalysis.md)
extends the dependency analysis with template-specific results: which validation mode is
active, which placeholders were found, and whether any are missing or unknown. This is the
right cmdlet when a build fails with a template validation error and you need to understand
exactly which placeholders are present, expected, or unknown:

```powershell
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Get-PSScriptBuilderTemplateAnalysis -TemplatePath ".\build\Templates\MyScript.ps1.template"

$analysis.ValidationMode       # Free, Hybrid, or Ordered
$analysis.IsValid
$analysis.MissingPlaceholders  # expected but not found in template
$analysis.UnknownPlaceholders  # found in template but not expected
```

See the [Templates Guide](templates.md) for a full explanation of validation modes, placeholder
rules, and all analysis result properties.

---

## See Also

- [Collectors Guide](collectors.md) — full Collected Data Properties reference with all properties and descriptions
- [Templates Guide](templates.md) — validation modes, placeholder rules, and template analysis result properties
- [Dependency Analysis Guide](dependency-analysis.md) — full dependency graph query reference
