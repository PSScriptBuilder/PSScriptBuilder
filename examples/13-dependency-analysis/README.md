# Example 13 - Dependency and Code Analysis

This example demonstrates the dependency and code analysis cmdlets introduced in PSScriptBuilder 1.1.0.
Unlike the previous examples, no build is performed — the focus is entirely on **analyzing and
visualizing component relationships and codebase metrics**. PSScriptBuilder's own source code is used as the subject,
providing a real-world codebase with 60+ components, multiple inheritance hierarchies, and
cross-subsystem dependencies.

## New in this example

- `Get-PSScriptBuilderDependencyAnalysis` — analyzes all component relationships without building
- `Export-PSScriptBuilderDependencyGraph` — exports the dependency graph as Mermaid or Graphviz DOT
- `Get-PSScriptBuilderComponentDependency` — traverses the graph from a named component in either direction
- `ConvertTo-PSScriptBuilderComponentDependencyTree` — renders traversal results as a hierarchical tree
- `-EdgeType` parameter on `Get-PSScriptBuilderComponentDependency` — restricts traversal to specific relationship types (e.g. `Inheritance` only)
- Multiple Class collectors with distinct `-CollectionKey` values in a single `ContentCollector`

## Key concepts

**Four new analysis cmdlets:**

| Cmdlet | Purpose |
|--------|---------|
| `Get-PSScriptBuilderDependencyAnalysis` | Runs full dependency analysis, returns `HasCycles`, `HasCrossDependencies`, `OrderedComponents`, and more |
| `Export-PSScriptBuilderDependencyGraph` | Exports the graph as Mermaid (`.md`) or Graphviz DOT (`.dot`) |
| `Get-PSScriptBuilderComponentDependency` | BFS traversal from a named component — `Dependencies` or `Dependents` direction |
| `ConvertTo-PSScriptBuilderComponentDependencyTree` | Converts traversal results to a Unicode tree string |

**Scoped analysis for readable diagrams:**
The full PSScriptBuilder project has 60+ components — too large for Mermaid. The example
intentionally scopes diagram exports to subsystems:
- **Mermaid**: Dependencies subsystem (8 classes) — directly renderable in VS Code, GitHub, MkDocs
- **DOT**: Collectors + Core + Dependencies (~17 classes) — shows cross-subsystem edges with type annotations

**Pipeline-first design:**
All analysis cmdlets accept pipeline input via `ValueFromPipelineByPropertyName` on the
`DependencyGraph` property. The common pattern is:

```powershell
$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
$analysis | Get-PSScriptBuilderComponentDependency -Name 'MyClass' -Direction Dependencies |
    ConvertTo-PSScriptBuilderComponentDependencyTree
```

**Multiple collectors of the same type:**
When using more than one Class collector in a single `ContentCollector`, each must have a
unique `-CollectionKey`. The default key `CLASS_DEFINITIONS` applies when `-CollectionKey` is
omitted, so a second Class collector without an explicit key causes an error.

```powershell
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'COLLECTORS' -IncludePath $collectorsPath |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CORE'       -IncludePath $corePath
```

## Scenarios

| # | What it shows |
|---|---------------|
| 1 | Full project overview: component counts, total nodes/edges, cycle and cross-dependency flags |
| 2 | Cycle check — confirms the project is cycle-free |
| 3 | Ordered components — topological sort result for the full project |
| 4 | Mermaid diagram export scoped to the Dependencies subsystem |
| 5 | Graphviz DOT export with edge-type annotations scoped to Collectors + Core + Dependencies |
| 6 | Drill-down: full dependency tree of `PSScriptBuilderBuildOrchestrator` |
| 7 | Drill-down: inheritance subtree of `PSScriptBuilderCollectorBase` (`-EdgeType Inheritance`) |
| 8 | Drill-down: all components that depend on `PSScriptBuilderDependencyGraph` |
| 9 | Top 5 components with the most transitive dependencies |
| 10 | All inheritance relationships as a flat table and as per-root inheritance trees |

## Output files

Running the script creates an `output\` directory with two files:

| File | Format | Content |
|------|--------|---------|
| `output\dependency-graph.md` | Mermaid | Dependencies subsystem — 8 classes |
| `output\dependency-graph.dot` | Graphviz DOT | Collectors + Core + Dependencies — ~17 classes with edge type labels |

Clean up after running:

```powershell
.\Reset-Example.ps1
```

## How to run

```powershell
cd examples\13-dependency-analysis
.\Run-Example.ps1
```

For verbose collector progress:

```powershell
.\Run-Example.ps1 -Verbose
```
