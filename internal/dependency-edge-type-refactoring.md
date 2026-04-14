# Refactoring Plan: Typed Dependency Edges

## Background

### Problem

When PSScriptBuilder is used to build a module that contains classes with mutual type
references (e.g. `Session` references `SessionStateBase` in a method, and `SessionStateBase`
references `Session` in a method), the build fails with a circular dependency error:

```
Cycle path retrieved: Session -> SessionStateBase -> Session
```

The root cause is that `PSScriptBuilderCycleDetector` treats all edges in the dependency
graph equally — both `base class` (inheritance) and `type reference` (method-level usage)
edges trigger a cycle error.

In PowerShell 5.1, only **inheritance cycles** are fatal at load time. Circular type
references in method bodies are completely valid: all classes in a `.psm1` file are parsed
together, so method bodies can freely reference types defined later in the file.

### Why the current design is insufficient

`PSScriptBuilderDependencyGraph` stores all edges as a
`Dictionary[string, HashSet[string]]` — the target component name only. There is no
information about _why_ one component depends on another. This makes it impossible for
`CycleDetector` or `TopologicalSorter` to distinguish between edge types without introducing
a parallel data structure (a second adjacency list), which is error-prone and requires
synchronisation.

### Decision

Introduce **typed edges** via a new `PSScriptBuilderDependencyEdge` data class and a new
`PSScriptBuilderDependencyEdgeType` enum. The graph's internal adjacency list is changed
from `Dictionary[string, HashSet[string]]` to `Dictionary[string, List[PSScriptBuilderDependencyEdge]]`.
All traversal methods are updated to work with the enriched model. Callers that need
filtering (e.g. `CycleDetector`) use the new overload `GetDependencies(name, edgeType)`.

This is a clean, single-model solution with no synchronisation risk and full extensibility
for future edge types.

---

## Scope

### New files

| File | Type | Purpose |
|---|---|---|
| `src/Enums/PSScriptBuilderDependencyEdgeType.ps1` | Enum | Classifies dependency edge types |
| `src/Classes/ScriptBuilder/Dependencies/PSScriptBuilderDependencyEdge.ps1` | Data class | Represents a single typed edge |

### Changed source files

| File | Change scope |
|---|---|
| `PSScriptBuilderDependencyGraph.ps1` | Internal storage type, all methods |
| `PSScriptBuilderDependencyGraphBuilder.ps1` | `TryAddEdge()`, `AddTypeReferenceEdges()`, `ProcessClassDependencies()`, `ProcessFunctionDependencies()` |
| `PSScriptBuilderCycleDetector.ps1` | `DfsHasCycle()`, `DfsGetCyclePath()` |
| `PSScriptBuilderTopologicalSorter.ps1` | `Sort()` restructured, helper properties/methods removed, new `RunKahnsAlgorithm()` |

### Changed test files

| File | Change scope |
|---|---|
| `PSScriptBuilderDependencyGraph.Tests.ps1` | All `AddEdge()` calls, new tests for typed queries |
| `PSScriptBuilderDependencyGraphBuilder.Tests.ps1` | New test: edge types stored correctly |
| `PSScriptBuilderCycleDetector.Tests.ps1` | All cycle tests use `AddEdge` with `Inheritance`; new test for `TypeReference` non-cycle |
| `PSScriptBuilderTopologicalSorter.Tests.ps1` | 3 cycle tests replaced with stuck-node assertions; new test for stuck-node sub-sort |

### Unchanged files

- `PSScriptBuilderDependencyAnalyzer.ps1`
- `PSScriptBuilderCrossDependencyDetector.ps1`
- `PSScriptBuilderDependencyAnalysisResult.ps1`
- All collectors, orchestrators, cmdlets

---

## Detailed Specification

### 1. New Enum: `PSScriptBuilderDependencyEdgeType`

**File:** `src/Enums/PSScriptBuilderDependencyEdgeType.ps1`

Three values:

| Value | Meaning | Cycle-fatal in PS 5.1? |
|---|---|---|
| `Inheritance` | Class inherits from another class (`base class`) | Yes |
| `TypeReference` | Class or function references a type in method/property body | No |
| `FunctionCall` | Class or function calls a function defined in the project | No |

---

### 2. New Data Class: `PSScriptBuilderDependencyEdge`

**File:** `src/Classes/ScriptBuilder/Dependencies/PSScriptBuilderDependencyEdge.ps1`

Properties:

| Property | Type | Description |
|---|---|---|
| `Target` | `[string]` | The name of the component being depended on |
| `EdgeType` | `[PSScriptBuilderDependencyEdgeType]` | The type of dependency |

Constructor: `PSScriptBuilderDependencyEdge([string] $target, [PSScriptBuilderDependencyEdgeType] $edgeType)`

Validation: `$target` cannot be null or empty (throws `ArgumentException`).

---

### 3. `PSScriptBuilderDependencyGraph`

#### Internal storage change

Old: `[Dictionary[string, HashSet[string]]] $Dependencies`

New: `[Dictionary[string, List[PSScriptBuilderDependencyEdge]]] $Dependencies`

The `List` is used instead of `HashSet` because `PSScriptBuilderDependencyEdge` is a class
(reference type) — duplicate prevention is handled explicitly in `AddEdge()` by checking
whether a `Target` is already present for the given `EdgeType`.

#### `AddNode([string] $name)` — unchanged signature

Initialises `Dependencies[$name]` with an empty `List[PSScriptBuilderDependencyEdge]`
instead of an empty `HashSet[string]`.

#### `AddEdge([string] $from, [string] $to, [PSScriptBuilderDependencyEdgeType] $edgeType)` — new signature

Old signature: `AddEdge([string] $from, [string] $to)`

New signature adds the edge type. Duplicate prevention: if an edge with the same `Target`
and `EdgeType` already exists for `$from`, the call is a no-op. Ensures `$from` node exists
(auto-creates). Self-loops are still permitted (detected by `CycleDetector`).

**Breaking change:** All callers of `AddEdge()` must pass an `EdgeType`. The only caller is
`PSScriptBuilderDependencyGraphBuilder.TryAddEdge()` — updated in step 4.

**Note:** Tests that call `graph.AddEdge()` directly also require updating.

#### `GetDependencies([string] $componentName)` — unchanged signature, updated implementation

Returns `HashSet[string]` of all target component names across **all** edge types. Existing
callers (`TopologicalSorter`, `GetDependents()`) continue to work without change.

#### New overload: `GetDependencies([string] $componentName, [PSScriptBuilderDependencyEdgeType] $edgeType)`

Returns `HashSet[string]` of target names filtered by the given edge type. Used by
`CycleDetector`.

#### `GetDependents([string] $componentName)` — unchanged signature, updated implementation

Iterates over `List[PSScriptBuilderDependencyEdge]` instead of `HashSet[string]`.
Behaviour is identical.

#### `GetAllNodes()` — unchanged signature, updated implementation

Collects keys plus all `Target` values from all edge lists.

#### `HasNode()`, `GetEdgeCount()`, `GetNodeCount()` — unchanged signatures, updated implementation

`GetEdgeCount()` sums `List.Count` values instead of `HashSet.Count` values.

---

### 4. `PSScriptBuilderDependencyGraphBuilder`

#### `TryAddEdge([string] $from, [string] $to, [PSScriptBuilderDependencyEdgeType] $edgeType)`

Old signature: `TryAddEdge([string] $from, [string] $to, [string] $edgeType)`

The third parameter changes from `[string]` (used only for Verbose logging) to
`[PSScriptBuilderDependencyEdgeType]` (used for both the edge and Verbose logging via
`$edgeType.ToString()`).

The Verbose output uses a switch to preserve the existing human-readable labels:

```powershell
$label = switch ($edgeType) {
    ([PSScriptBuilderDependencyEdgeType]::Inheritance)    { 'base class'      }
    ([PSScriptBuilderDependencyEdgeType]::TypeReference)  { 'type reference'  }
    ([PSScriptBuilderDependencyEdgeType]::FunctionCall)   { 'function call'   }
}
Write-Verbose "      $from -> $to ($label)"
```

This preserves the existing labels (`base class`, `type reference`, `function call`) exactly
as they appear in the current output, making the change transparent to users reading Verbose
output.

#### Duplicate check — critical adaptation

The current duplicate check in `TryAddEdge()` reads:

```powershell
if ($this.CurrentGraph.Dependencies.ContainsKey($from)) {
    if ($this.CurrentGraph.Dependencies[$from].Contains($to)) {
        return $false
    }
}
```

After the storage change, `Dependencies[$from]` is a `List[PSScriptBuilderDependencyEdge]`
— `Contains(string)` no longer works. The check must be replaced with a target-only search:

```powershell
if ($this.CurrentGraph.Dependencies.ContainsKey($from)) {
    $exists = $false
    foreach ($edge in $this.CurrentGraph.Dependencies[$from]) {
        if ($edge.Target -eq $to) {
            $exists = $true
            break
        }
    }
    if ($exists) { return $false }
}
```

**Semantics:** Duplicate detection is based on `Target` only, not on `EdgeType`. This means
that if class A inherits from B (`Inheritance`) and also references B in a method body
(`TypeReference`), only the first registered edge (whichever is processed first) is stored.
In practice, `ProcessClassDependencies()` processes the base class before type references, so
the `Inheritance` edge is stored and the `TypeReference` edge for the same target is
silently skipped. This is the correct and desirable behaviour: the stronger constraint
(inheritance) takes precedence.

#### `AddTypeReferenceEdges([string] $componentName, [string[]] $typeReferences)`

Calls `TryAddEdge($componentName, $ref, [PSScriptBuilderDependencyEdgeType]::TypeReference)`.

#### `ProcessClassDependencies()`

Base class call:
```
TryAddEdge($className, $classData.BaseClass, [PSScriptBuilderDependencyEdgeType]::Inheritance)
```

Type reference call (via `AddTypeReferenceEdges()`): `TypeReference`

Function call:
```
TryAddEdge($className, $calledFunction, [PSScriptBuilderDependencyEdgeType]::FunctionCall)
```

#### `ProcessFunctionDependencies()`

Called function:
```
TryAddEdge($functionName, $calledFunction, [PSScriptBuilderDependencyEdgeType]::FunctionCall)
```

Type reference call (via `AddTypeReferenceEdges()`): `TypeReference`

---

### 5. `PSScriptBuilderCycleDetector`

Only two lines change — one in `DfsHasCycle()` and one in `DfsGetCyclePath()`:

Old:
```
$dependencies = $this.Graph.GetDependencies($node)
```

New:
```
$dependencies = $this.Graph.GetDependencies($node, [PSScriptBuilderDependencyEdgeType]::Inheritance)
```

All other logic (3-state DFS, path tracking, Verbose output) is unchanged.

**Effect:** A cycle `A -> B -> A` via `TypeReference` edges is no longer detected. A cycle
`A -> B -> A` via `Inheritance` edges still throws correctly.

---

### 6. `PSScriptBuilderTopologicalSorter`

#### Structural change

The current implementation holds sort-time state as instance properties (`$InDegree`,
`$ZeroInDegreeQueue`) and exposes two hidden helper methods (`CalculateInDegrees()`,
`InitializeZeroInDegreeQueue()`). This design exists because the Kahn's algorithm is
spread across `Sort()` and two helpers via `$this` state.

After the refactoring, the Kahn's algorithm is extracted into a new self-contained hidden
method `RunKahnsAlgorithm()`. The instance properties and the two helper methods become
dead code and are removed.

#### Properties removed

- `hidden [Dictionary[string, int]] $InDegree` — replaced by local variable in `RunKahnsAlgorithm()`
- `hidden [Queue[string]] $ZeroInDegreeQueue` — replaced by `SortedSet[string]` in `RunKahnsAlgorithm()`

#### Helper methods removed

- `hidden [void] CalculateInDegrees()` — logic moved into `RunKahnsAlgorithm()`
- `hidden [void] InitializeZeroInDegreeQueue()` — logic moved into `RunKahnsAlgorithm()`

#### New method: `hidden [List[string]] RunKahnsAlgorithm([PSScriptBuilderDependencyGraph] $graph)`

A pure function: receives a graph, performs Kahn's algorithm, returns a `List[string]` of
node names in processed order (not yet reversed). No `$this` state is read or written.

Internally uses a `SortedSet[string]` (case-insensitive) instead of `Queue[string]` as the
zero-in-degree collection. This provides alphabetical tie-breaking for free: when multiple
nodes simultaneously have in-degree 0, `SortedSet.Min` always yields the alphabetically
first one. This makes the output deterministic and reproducible regardless of graph
traversal order.

If the input graph contains no cycles, the returned list contains all nodes. If it contains
cycles (e.g. when called directly in tests with inheritance-cycle graphs), the returned
list is incomplete — the caller is responsible for detecting this.

#### `Sort()` — restructured

New flow:

```
1. totalNodes = $this.Graph.GetAllNodes().Count
2. mainResult = $this.RunKahnsAlgorithm($this.Graph)
3. if mainResult.Count -lt totalNodes:
   a. Build processedSet (HashSet) from mainResult
   b. Collect stuckNodes (all nodes not in processedSet)
   c. Build subGraph:
      - AddNode() for each stuck node
      - For each stuck node, call GetDependencies(node, Inheritance),
        filter to stuck nodes only, AddEdge(..., Inheritance) for each
   d. subResult = $this.RunKahnsAlgorithm($subGraph)
   e. Append subResult to mainResult
   f. Write-Verbose: "  N node(s) with circular type references resolved via inheritance sub-sort"
4. Reverse mainResult.ToArray() and return
```

**Guarantee for step 3d:** The sub-graph contains only stuck nodes and Inheritance edges
between them. `CycleDetector` has guaranteed no Inheritance cycles exist anywhere in the
graph. Therefore `RunKahnsAlgorithm($subGraph)` always returns a complete result
(`subResult.Count == stuckNodes.Count`). No further fallback is needed.

**No infinite recursion risk:** `RunKahnsAlgorithm()` never calls `Sort()` or itself.
It is a pure function with no side effects.

**Sorter still throws for pure Inheritance cycles (robustness):** If `Sort()` is called
directly (bypassing `CycleDetector`) with a graph containing an Inheritance cycle, the
main Kahn's pass produces an incomplete `mainResult`. The sub-graph is built and also
produces an incomplete result. `mainResult.Count` will still be less than `totalNodes`
after appending `subResult`. An `InvalidOperationException` is thrown at the end of `Sort()`
as a safety net:

```
if (($mainResult.Count + appended) -ne $totalNodes) {
    throw [InvalidOperationException]::new("Topological sort incomplete...")
}
```

This means the three existing tests (`Should throw InvalidOperationException for a direct
cycle`, etc.) remain valid if they use `Inheritance` edges — they test the safety net path.


---

## Module Load Order

`PSScriptBuilderDependencyEdgeType` is an enum — it must be defined before
`PSScriptBuilderDependencyEdge` (which uses it as a property type) and before
`PSScriptBuilderDependencyGraph` (which uses both).

PSScriptBuilder's own build uses an `EnumCollector` that runs before the `ClassCollector`.
The enum file is placed in `src/Enums/`, which is already the source path for all enums.
No manual ordering is required.

---

## Test Specification

### `PSScriptBuilderDependencyGraph.Tests.ps1`

All existing calls to `AddEdge('A', 'B')` are updated to
`AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)` (generic tests use
`TypeReference` as a neutral edge type).

New test context: `GetDependencies - filtered by edge type`

- `GetDependencies(name)` returns all targets regardless of edge type
- `GetDependencies(name, Inheritance)` returns only inheritance targets
- `GetDependencies(name, TypeReference)` returns only type reference targets
- `GetDependencies(name, Inheritance)` returns empty set when only `TypeReference` edges exist
- `GetDependencies(name)` returns combined targets when both `Inheritance` and `TypeReference` edges exist

### `PSScriptBuilderDependencyGraphBuilder.Tests.ps1`

New test context: `Build - edge types stored correctly`

- A `base class` dependency is stored as `Inheritance` edge type
- A `type reference` dependency is stored as `TypeReference` edge type
- A `function call` dependency is stored as `FunctionCall` edge type

### `PSScriptBuilderCycleDetector.Tests.ps1`

All existing cycle tests that call `graph.AddEdge('A', 'B')` and `graph.AddEdge('B', 'A')`
are updated to use `AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)`.

New test: `HasCycle - TypeReference cycle is not detected`

- Graph with `AddEdge('A', 'B', TypeReference)` and `AddEdge('B', 'A', TypeReference)`
- `HasCycle()` returns `$false`

New test: `GetCyclePath - returns empty for TypeReference cycle`

- Same graph
- `GetCyclePath()` returns empty array

### `PSScriptBuilderTopologicalSorter.Tests.ps1`

The existing context `Sort - Cycle detection` contains three tests that use `AddEdge(A, B)`
without edge type and expect `InvalidOperationException`.

These tests are split into two groups:

**Group 1 — TypeReference cycles do not throw (new behavior):**
The three tests are updated to use `TypeReference` edges. They now verify:
- `Sort()` does not throw
- Result contains all nodes
- Result count equals total node count

**Group 2 — Inheritance cycles still throw (safety net preserved):**
Three new tests (mirroring the originals) use `Inheritance` edges and verify that
`Sort()` still throws `InvalidOperationException`. These test the safety-net path for
when `Sort()` is called without a prior `HasCycle()` check.

**New context — stuck-node ordering:**
- Stuck nodes with an Inheritance constraint between them are correctly ordered
  (prerequisite before dependent)
- Example: `AddEdge('ZClass', 'AHelper', Inheritance)`, `AddEdge('AHelper', 'ZClass', TypeReference)`
  → result contains `AHelper` before `ZClass`

**Note:** The existing exception behaviour of the sorter for `Inheritance` cycles is
preserved for robustness — the sorter still throws if somehow called with an inheritance
cycle. The test simply adds a new group to verify that `TypeReference` cycles are handled
gracefully.

---

## Summary of Behaviour Change

| Scenario | Before | After |
|---|---|---|
| `Session -> SessionStateBase -> Session` (TypeReference) | Build fails with cycle error | Build succeeds; nodes appended in fallback order |
| `A inherits B`, `B inherits A` (Inheritance) | Build fails with cycle error | Build fails with cycle error (unchanged) |
| No cycles | Build succeeds (unchanged) | Build succeeds (unchanged) |
| Mixed: TypeReference cycle + valid inheritance | Build fails (cycle) | Build succeeds; stuck nodes appended |
