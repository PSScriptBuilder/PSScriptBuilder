# Type Reference

Property and method tables for the PowerShell classes PSScriptBuilder's cmdlets return.
This page is for looking up a specific type by name; for how-to explanations and worked
examples of what produces these objects, see each section's own linked guide.

---

## Scaffolding

[`New-PSScriptBuilderProject`](../cmdlets/New-PSScriptBuilderProject.md) returns a
`PSScriptBuilderScaffoldingResult` describing exactly what was created — the project name and
path, the generated build script, and every file and directory written. See the
[Quick Start Guide](../getting-started/quick-start.md) for the full scaffolding workflow.

### PSScriptBuilderScaffoldingResult

Returned by `New-PSScriptBuilderProject`.

| Property | Type | Description |
|---|---|---|
| `ProjectName` | `string` | The name used when scaffolding the project |
| `ProjectPath` | `string` | Absolute path to the project root directory |
| `BuildScriptPath` | `string` | Absolute path to the generated `Build-<Name>.ps1` script |
| `CreatedFiles` | `string[]` | Absolute paths of all files created, in creation order |
| `CreatedDirectories` | `string[]` | Absolute paths of all directories created, in creation order |

---

## Build Results

A single call to [`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md)
returns one `PSScriptBuilderBuildResult` describing what happened: where the output went, how
long it took, and whether a backup or source map was written. Two of its properties are
themselves structured objects rather than plain values — `ComponentCounts` gives per-type
totals (how many classes, functions, enums, and so on), and `ComponentDetails` (populated only
when `-Detailed` is used) lists every individual component along with what it depends on. See
the [Build Pipeline Guide](../guides/build-pipeline.md) for the full build workflow and how to
read this result.

### PSScriptBuilderBuildResult

Returned directly by `Invoke-PSScriptBuilderBuild`.

| Property | Type | Description |
|---|---|---|
| `OutputPath` | `string` | Absolute path of the generated output file |
| `OutputFileSize` | `long` | Output file size in bytes |
| `ExecutionTime` | `TimeSpan` | Total build duration |
| `BackupPath` | `string` | Path of the backup file; `$null` if no backup was created |
| `SourceMapPath` | `string` | Path of the source map sidecar; `$null` if `-WriteSourceMap` was not specified |
| `TotalComponents` | `int` | Sum of all collected components across all collector types |
| `ComponentCounts` | `PSScriptBuilderBuildComponentCounts` | Per-type component counts |
| `ProcessedFiles` | `string[]` | Absolute paths of all source files processed during collection |
| `ComponentDetails` | `PSScriptBuilderBuildComponentDetail[]` | Detailed info per component; shown by `-Detailed` |
| `SyntaxValid` | `bool` | `$true` if the output file passed the syntax parse check |

### PSScriptBuilderBuildComponentCounts

The value of `PSScriptBuilderBuildResult.ComponentCounts`; also reused as
`PSScriptBuilderDependencyAnalysisResult.ComponentCounts` in
[Dependency Analysis](#dependency-analysis).

| Property | Type | Description |
|---|---|---|
| `UsingStatements` | `int` | Number of `using` statements collected |
| `EnumDefinitions` | `int` | Number of enum definitions collected |
| `ClassDefinitions` | `int` | Number of class definitions collected |
| `FunctionDefinitions` | `int` | Number of function definitions collected |
| `FileContents` | `int` | Number of raw file contents collected |

### PSScriptBuilderBuildComponentDetail

The value of each entry in `PSScriptBuilderBuildResult.ComponentDetails`, shown when
`-Detailed` is passed to `Format-PSScriptBuilderBuildResult`.

| Property | Type | Description |
|---|---|---|
| `Type` | `PSScriptBuilderCollectorType` | Collector type (`Enum`, `Class`, `Function`, etc.) |
| `Name` | `string` | Component name as defined in source code |
| `SourceFile` | `string` | Absolute path to the file containing the component |
| `Dependencies` | `string[]` | Names of components this component depends on |

---

## Source Maps & Code Coverage

Building merges many source files into one output script, so a line number reported by an
error or by Pester refers to a position in that merged file, not to anything in your `src\`
tree. A source map (written via `-WriteSourceMap`) is what makes translating back possible.
`PSScriptBuilderSourceLocation` is the basic unit of that translation — one resolved point,
returned by [`Resolve-PSScriptBuilderSourceLocation`](../cmdlets/Resolve-PSScriptBuilderSourceLocation.md)
for a single output line or `ErrorRecord`. `PSScriptBuilderSourceCoverageResult` builds on the
same mechanism at a larger scale: [`Get-PSScriptBuilderSourceCoverage`](../cmdlets/Get-PSScriptBuilderSourceCoverage.md)
resolves every line in a Pester `CodeCoverage` result this way and aggregates the outcome per
source file, so
[`PSScriptBuilderSourceCoverageResult.MissedLocations`](#psscriptbuildersourcecoverageresult) is
simply a collection of `PSScriptBuilderSourceLocation` entries. See the
[Source Maps Guide](../guides/source-maps.md) for the full workflow, including
translating Pester code coverage.

### PSScriptBuilderSourceLocation

Returned by `Resolve-PSScriptBuilderSourceLocation` for each resolved entry, and reused as each
element of
[`PSScriptBuilderSourceCoverageResult.MissedLocations`](#psscriptbuildersourcecoverageresult).

| Property | Type | Description |
|---|---|---|
| `ComponentName` | `string` | Name of the class, function, enum, or file component |
| `ComponentType` | `string` | Collector type that produced this component |
| `SourceFile` | `string` | Absolute path to the source file |
| `SourceLineNumber` | `int` | 1-based line in `SourceFile` that corresponds to `OutputLineNumber` |
| `ComponentLineNumber` | `int` | 1-based line within the component's source block |
| `OutputLineNumber` | `int` | 1-based line in the compiled output script |
| `Offset` | `int` | Lines between `OutputLineNumber` and the component's first output line |

### PSScriptBuilderSourceCoverageResult

Returned by `Get-PSScriptBuilderSourceCoverage`, one instance per source file.

| Property | Type | Description |
|---|---|---|
| `SourceFile` | `string` | Absolute path to the source file (`Format-PSScriptBuilderSourceCoverage` displays it relative to the project root; the object itself always holds the absolute path) |
| `TotalCommands` | `int` | Coverage-analyzed commands attributed to this source file |
| `HitCommands` | `int` | Commands executed at least once |
| `MissedCommands` | `int` | Commands never executed |
| `CoveragePercent` | `double` | `HitCommands / TotalCommands * 100` |
| `MissedLocations` | `PSScriptBuilderSourceLocation[]` | Resolved location of every missed command |

---

## File Watching

[`Watch-PSScriptBuilderProject`](../cmdlets/Watch-PSScriptBuilderProject.md) rebuilds
automatically whenever a watched file changes, with no interactive session to display a normal
error in. `PSScriptBuilderWatchBuildErrorResult` exists to carry a failed build's information
out of that automated loop and into your own `-OnError` script block, so you can log it, alert
on it, or otherwise react programmatically instead of losing the error entirely. See the
[File Watching Guide](../guides/file-watching.md) for the full callback setup, including how
to combine `-OnError` with `-OnSuccess`.

### PSScriptBuilderWatchBuildErrorResult

Passed to the `-OnError` script block of `Watch-PSScriptBuilderProject`.

| Property | Type | Description |
|---|---|---|
| `Exception` | `Exception` | The exception that was thrown during the build operation |
| `ChangedFiles` | `string[]` | Paths of the files whose changes triggered the failed build |
| `Timestamp` | `datetime` | Date and time the build failure occurred |

---

## Dependency Analysis

[`Get-PSScriptBuilderDependencyAnalysis`](../cmdlets/Get-PSScriptBuilderDependencyAnalysis.md)
runs collectors, builds the full dependency graph, and returns one
`PSScriptBuilderDependencyAnalysisResult` summarizing the whole project: whether a cycle exists,
whether classes and functions need to be interleaved, and the resulting build order. That
result's `DependencyGraph` property holds the underlying graph object itself, with its own set
of [query methods](#psscriptbuilderdependencygraph-methods) for anything the summary properties
don't already answer directly —
such as asking what a single named component depends on, or what would be affected if it
changed. [`Get-PSScriptBuilderComponentDependency`](../cmdlets/Get-PSScriptBuilderComponentDependency.md)
wraps exactly that kind of query, returning one `PSScriptBuilderComponentDependencyEntry` per
dependency found. A related but distinct question — not "what does X depend on" but "is anything
still using X at all" — is answered by
[`Find-PSScriptBuilderUnusedComponent`](../cmdlets/Find-PSScriptBuilderUnusedComponent.md), which
walks the same graph from a set of entry points and returns one `PSScriptBuilderUnusedComponentEntry`
per component nothing reaches. See the [Dependency Analysis Guide](../guides/dependency-analysis.md)
for the full workflow, diagram export, and drill-down traversal.

### PSScriptBuilderDependencyAnalysisResult

Returned by `Get-PSScriptBuilderDependencyAnalysis`.

| Property | Type | Description |
|---|---|---|
| `HasCycles` | `bool` | Whether a circular dependency was detected |
| `CyclePath` | `string[]` | Components forming the cycle, e.g. `A → B → C → A`. Empty if no cycle. |
| `HasCrossDependencies` | `bool` | Whether classes and functions are interleaved in the sorted order. Always `false` if `HasCycles` is `true`. |
| `OrderedComponents` | `string[]` | Topologically sorted component names, enums first. Empty if `HasCycles` is `true`. |
| `ComponentCounts` | `PSScriptBuilderBuildComponentCounts` | Per-type counts: `UsingStatements`, `EnumDefinitions`, `ClassDefinitions`, `FunctionDefinitions`, `FileContents` |
| `TotalComponents` | `int` | Sum of all `ComponentCounts` fields |
| `TotalNodes` | `int` | Number of nodes in the dependency graph |
| `TotalEdges` | `int` | Number of edges (dependency relationships) in the graph |
| `DependencyGraph` | `PSScriptBuilderDependencyGraph` | The full graph object for advanced queries |

### PSScriptBuilderComponentDependencyEntry

Returned by `Get-PSScriptBuilderComponentDependency`, one instance per dependency.

| Property | Type | Description |
|---|---|---|
| `Name` | `string` | The name of the dependency |
| `Depth` | `int` | Steps from the starting component: 1 = direct dependency, 2+ = transitive |
| `DependencyPath` | `string[]` | Ordered path from the starting component to this dependency, e.g. `{New-Employee, Employee, Person}` |

### PSScriptBuilderUnusedComponentEntry

Returned by `Find-PSScriptBuilderUnusedComponent`, one instance per unused component found.

| Property | Type | Description |
|---|---|---|
| `Name` | `string` | The component's name (enum, class, or function name) |
| `ComponentType` | `PSScriptBuilderUnusedComponentType` | Which kind of component this is: `Enum`, `Class`, or `Function` |
| `CollectionKey` | `string` | The collection key of the collector that provided this component |
| `SourceFile` | `string` | Path to the file the component is defined in |

### PSScriptBuilderDependencyGraph Methods

Methods available on `PSScriptBuilderDependencyAnalysisResult.DependencyGraph`, for
queries beyond what the result object's own properties expose.

| Method | Returns | Description |
|---|---|---|
| `GetDependencies(name)` | `HashSet[string]` | All components `name` depends on (all edge types) |
| `GetDependencies(name, edgeType)` | `HashSet[string]` | Dependencies filtered to a specific edge type |
| `GetDependents(name)` | `HashSet[string]` | All components that depend on `name` |
| `GetDependents(name, edgeType)` | `HashSet[string]` | Dependents filtered to a specific edge type |
| `GetAllNodes()` | `HashSet[string]` | All component names in the graph |
| `HasNode(name)` | `bool` | Whether a component is present in the graph |
| `GetNodeCount()` | `int` | Total number of nodes |
| `GetEdgeCount()` | `int` | Total number of dependency edges |
| `GetEdgeMap()` | `Dictionary[string, List[PSScriptBuilderDependencyEdge]]` | Read-only access to every node's outgoing edges, for renderers and other consumers that need to iterate the full graph |

The `PSScriptBuilderDependencyEdgeType` enum values used with the filtered overloads:

| Value | Meaning | Fatal cycle? |
|---|---|---|
| `Inheritance` | `class A : B` — class inherits from another class | Yes |
| `StaticInitializer` | Static property initializer references another type at load time | Yes |
| `TypeReference` | Type used in a method body or property type annotation | No |
| `FunctionCall` | Call to a standalone function defined elsewhere in the project | No |

All methods return a `HashSet[string]`. In PowerShell this behaves like any other collection —
iterable with `ForEach-Object`, testable with `.Count`, joinable with `-join`.
If no dependencies exist, the result is an empty collection, not an error.

---

## Templates

[`New-PSScriptBuilderTemplate`](../cmdlets/New-PSScriptBuilderTemplate.md) generates a template
file automatically from your collector configuration — one placeholder per collector in Free
Mode, or a single `{{ORDERED_COMPONENTS}}` block when cross-dependencies require it — and returns
a `PSScriptBuilderTemplateGenerationResult` describing what it wrote. Later, whether a template
was generated this way or written by hand, a build fails if its `{{Placeholder}}` tokens and the
registered collectors don't match — a missing token, a typo, or the wrong ordering.
`PSScriptBuilderTemplateAnalysisResult`, returned by
[`Get-PSScriptBuilderTemplateAnalysis`](../cmdlets/Get-PSScriptBuilderTemplateAnalysis.md),
surfaces exactly that comparison ahead of time: which placeholders were found in the template,
which were expected given the collectors and validation mode, and where the two disagree. See
the [Templates Guide](../guides/templates.md) for validation modes, placeholder rules, and the
validation error reference.

### PSScriptBuilderTemplateGenerationResult

Returned by `New-PSScriptBuilderTemplate`.

| Property | Type | Description |
|---|---|---|
| `OutputPath` | `string` | Absolute path to the generated template file |
| `Mode` | `PSScriptBuilderTemplateValidationMode` | Validation mode applied during generation: `Free`, `Ordered`, or `Hybrid` |
| `Placeholders` | `string[]` | All placeholder tokens written into the template, in the order they appear |
| `OrderedMode` | `bool` | `$true` if `-OrderedMode` forced Hybrid mode; `$false` if Ordered mode was instead triggered automatically by cross-dependency detection |

### PSScriptBuilderTemplateAnalysisResult

Returned by `Get-PSScriptBuilderTemplateAnalysis`.

| Property | Type | Description |
|---|---|---|
| `IsValid` | `bool` | Whether the template passed all validation rules |
| `ValidationErrors` | `string[]` | Array of error messages (empty when valid) |
| `ValidationMode` | `PSScriptBuilderTemplateValidationMode` | `Free`, `Hybrid`, or `Ordered` |
| `OrderedComponentsKey` | `string` | The placeholder key used for the ordered components block (default: `ORDERED_COMPONENTS`) |
| `HasCrossDependencies` | `bool` | Whether cross-dependencies were detected |
| `PlaceholdersFound` | `string[]` | All `{{...}}` tokens found in the template (sorted, unique) |
| `PlaceholdersExpected` | `string[]` | Tokens expected based on collectors and mode |
| `MissingPlaceholders` | `string[]` | Expected but not found in template |
| `UnknownPlaceholders` | `string[]` | Found in template but not matching any collector |
| `TemplatePath` | `string` | Resolved absolute path to the template file |
| `TemplateSize` | `int` | Template character count |

---

## Collectors

[`New-PSScriptBuilderContentCollector`](../cmdlets/New-PSScriptBuilderContentCollector.md) returns
a `PSScriptBuilderContentCollector` — the object every other collector cmdlet operates on, either
via [its own methods](#psscriptbuildercontentcollector-methods) or via the
`Add-`/`Get-`/`Remove-PSScriptBuilderCollector` cmdlets that wrap them. Before a build assembles anything, each individual collector registered on it extracts
one raw data object per component it finds — the same objects
[`Get-PSScriptBuilderCollectorContent`](../cmdlets/Get-PSScriptBuilderCollectorContent.md) returns
for direct inspection, independent of running a build at all. Which type you get back depends on
the collector. See the [Collectors Guide](../guides/collectors.md) for the full walkthrough.

### PSScriptBuilderCollectorBase

Returned by `New-PSScriptBuilderCollector` and `Get-PSScriptBuilderCollector`; the base type of
every collector (`PSScriptBuilderClassCollector`, `PSScriptBuilderFunctionCollector`, etc.).

| Property | Type | Description |
|---|---|---|
| `CollectorType` | `PSScriptBuilderCollectorType` | Which kind of component this collector extracts: `Using`, `Enum`, `Class`, `Function`, or `File` |
| `CollectionKey` | `string` | The unique key identifying this collector — also the template placeholder name |
| `IncludePaths` | `string[]` | Directories scanned for source files |
| `ExcludePaths` | `string[]` | Directories excluded from scanning |
| `IncludeFiles` | `string[]` | Specific files or patterns always included, bypassing path exclusion |
| `ExcludeFiles` | `string[]` | File name patterns excluded from scanning |
| `FileExtensions` | `string[]` | File extensions scanned. Default: `@(".ps1")` |
| `Recurse` | `bool` | Whether subdirectories are scanned. Default: `$true` |
| `HasCollected` | `bool` | `$true` once `Collect()` has run successfully |

Calling `Collect()` runs the collection and populates a type-specific data property
(`FunctionData` for a `Function` collector, `ClassData` for a `Class` collector, and so on), each
holding entries of the corresponding [Collected Data Types](#collected-data-types).

### PSScriptBuilderContentCollector Methods

Methods available directly on the `PSScriptBuilderContentCollector` object, in addition to the
collector cmdlets that wrap most of them.

| Method | Returns | Cmdlet equivalent | Description |
|---|---|---|---|
| `AddCollector(collector)` | `void` | `Add-PSScriptBuilderCollector` | Adds a collector to the collection |
| `RemoveCollector(key)` | `bool` | `Remove-PSScriptBuilderCollector` | Removes a collector by key. Returns `$true` if removed, `$false` if not found |
| `GetCollector(key)` | `PSScriptBuilderCollectorBase` | `Get-PSScriptBuilderCollector` | Returns the collector with the given key |
| `GetCollectors()` | `PSScriptBuilderCollectorBase[]` | `Get-PSScriptBuilderCollector` | Returns all collectors, sorted by `CollectorType` |
| `GetCount()` | `int` | — | Number of registered collectors |
| `Clear()` | `void` | — | Removes all collectors at once |
| `Execute()` | `void` | — | Runs `Collect()` on every registered collector, in `CollectorType` order |
| `GetCollectionKeys()` | `string[]` | — | Returns every registered collector's `CollectionKey` |
| `GetProcessedFiles()` | `string[]` | — | Returns every source file path collected, deduplicated |
| `GetDefinedComponentNames()` | `HashSet[string]` | — | Returns the names of all collected enums, classes, and functions |
| `GetDefinedComponentTypes()` | `Dictionary[string, PSScriptBuilderCollectorType]` | — | Maps every collected component's name to its collector type |
| `GetComponentSourceCode(componentName)` | `string` | — | Returns the source code of the named enum, class, or function |
| `GetComponentType(componentName)` | `PSScriptBuilderCollectorType` | — | Returns which collector type owns the named component |
| `BuildComponentCollectorMap()` | `hashtable` | — | Maps each class/function/enum name to its owning collector's `CollectionKey` |
| `GetUsingCollectors()` | `PSScriptBuilderUsingCollector[]` | `Get-PSScriptBuilderCollector -Type Using` | Returns all registered Using collectors |
| `GetFileCollectors()` | `PSScriptBuilderFileCollector[]` | `Get-PSScriptBuilderCollector -Type File` | Returns all registered File collectors |
| `GetEnumCollectors()` | `PSScriptBuilderEnumCollector[]` | `Get-PSScriptBuilderCollector -Type Enum` | Returns all registered Enum collectors |
| `GetClassCollectors()` | `PSScriptBuilderClassCollector[]` | `Get-PSScriptBuilderCollector -Type Class` | Returns all registered Class collectors |
| `GetFunctionCollectors()` | `PSScriptBuilderFunctionCollector[]` | `Get-PSScriptBuilderCollector -Type Function` | Returns all registered Function collectors |

Most of these methods have no cmdlet equivalent — they support scenarios (dependency analysis,
cross-collector lookups, manual execution) that operate on the whole `ContentCollector` rather
than exposing a dedicated top-level cmdlet. `GetCount()` is useful for asserting that all
expected collectors were registered before starting a build. `Clear()` resets the object for
reuse — for example in a script that dynamically rebuilds the collector configuration.

### Collected Data Types

| Type | Collector | Holds |
|---|---|---|
| `PSScriptBuilderClassData` | `Class` | Name, source code, base class, and type/call/static-initializer references |
| `PSScriptBuilderFunctionData` | `Function` | Name, source code, and type/call references |
| `PSScriptBuilderEnumData` | `Enum` | Name and source code |
| `PSScriptBuilderUsingData` | `Using` | The `using` statement text and the source files it came from |
| `PSScriptBuilderFileData` | `File` | Raw file name, path, and content |

The dependency-related properties (`BaseClass`, `TypeReferences`, `StaticInitializerReferences`,
`CalledFunctions`) carry semantics tied to how PSScriptBuilder orders components — what each one
means and why it matters is explained where those concepts are taught, in
[Collected Data Properties](../guides/collectors.md#collected-data-properties) in the
Collectors Guide, rather than repeated here.

---

## Release Management

Release management tracks two things across a project: the current version, build, and Git
state (`psscriptbuilder.releasedata.json`), and which project files receive that state
(`psscriptbuilder.bumpconfig.json`).
[`Update-PSScriptBuilderReleaseData`](../cmdlets/Update-PSScriptBuilderReleaseData.md) returns a
`PSScriptBuilderReleaseDataResult` describing exactly which values changed;
[`Update-PSScriptBuilderBumpFiles`](../cmdlets/Update-PSScriptBuilderBumpFiles.md) returns a
`PSScriptBuilderBumpFilesResult` describing which project files were updated. See the
[Release Management Guide](../guides/release-management.md) for the full workflow.

### PSScriptBuilderReleaseDataResult

Returned by `Update-PSScriptBuilderReleaseData`.

| Property | Type | Description |
|---|---|---|
| `TotalOperationsPerformed` | `int` | Count of update operations performed |
| `Changes` | `OrderedDictionary` | Changes grouped by category (`Version`, `Build`, `Git`), each an array of `Property`/`OldValue`/`NewValue` entries |

### PSScriptBuilderBumpFilesResult

Returned by `Update-PSScriptBuilderBumpFiles`.

| Property | Type | Description |
|---|---|---|
| `TotalFilesProcessed` | `int` | Count of all files processed, whether modified or not |
| `TotalFilesModified` | `int` | Count of files that had actual content changes |
| `BumpDetails` | `PSCustomObject[]` | One entry per modified file: `Path`, and `ChangedItems` (`Pattern`, `Token`, `OldValue`, `NewValue`) — only present for files that changed |
