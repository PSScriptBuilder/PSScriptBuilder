# Get-PSScriptBuilderComponentDependency

Retrieves all dependencies or dependents of a named component from the dependency graph.

## Description

Performs a breadth-first traversal of a dependency graph starting from `-Name`, returning every
reachable component as a `PSScriptBuilderComponentDependencyEntry` — its name, depth from the
starting component (1 = direct, 2+ = transitive), and the full path that reaches it.

`-Direction` controls which way the traversal runs: `Dependencies` (the default) shows what the
named component needs; `Dependents` shows what needs it — the PowerShell equivalent of an IDE's
"Find All References", useful for assessing a refactor's impact before touching a shared base
class. `-EdgeType` restricts traversal to specific relationship kinds — for example `Inheritance`
alone, to build a pure inheritance hierarchy.

The named component itself is never included in the results. Component name lookup is
case-insensitive.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-DependencyGraph` | `PSScriptBuilderDependencyGraph` | **Required.** The graph to traverse. Accepts pipeline input by property name, enabling direct piping from [`Get-PSScriptBuilderDependencyAnalysis`](Get-PSScriptBuilderDependencyAnalysis.md) (its `DependencyGraph` property). |
| `-Name` | string | **Required.** The component to start the traversal from. Must exist in the graph. |
| `-Direction` | `PSScriptBuilderTraversalDirection` | `Dependencies` (default) or `Dependents`. |
| `-EdgeType` | `PSScriptBuilderDependencyEdgeType[]` | Restricts traversal to these edge types: `Inheritance`, `TypeReference`, `FunctionCall`, `StaticInitializer`. Combines multiple types as a union. All types are traversed when omitted. |

## Examples

### Find everything a component depends on

```powershell
$analysis | Get-PSScriptBuilderComponentDependency -Name 'New-Employee'
```

```text title="Output"
Name              Depth  DependencyPath
----              -----  --------------
Address               1  {New-Employee, Address}
Department            1  {New-Employee, Department}
Employee              1  {New-Employee, Employee}
EmploymentStatus      2  {New-Employee, Employee, EmploymentStatus}
Person                2  {New-Employee, Employee, Person}
```

### Assess the impact of changing a shared base class

```powershell
$analysis | Get-PSScriptBuilderComponentDependency -Name 'Person' -Direction Dependents
```

```text title="Output"
Name                       Depth  DependencyPath
----                       -----  --------------
Employee                       1  {Person, Employee}
Get-EmployeesByDepartment      2  {Person, Employee, Get-EmployeesByDepartment}
New-Employee                   2  {Person, Employee, New-Employee}
Set-EmployeeStatus             2  {Person, Employee, Set-EmployeeStatus}
```

### Build a pure inheritance hierarchy

```powershell
$analysis | Get-PSScriptBuilderComponentDependency -Name 'ValidatorBase' -Direction Dependents -EdgeType Inheritance
```

Only subclasses are included — components that merely reference `ValidatorBase` as a type are
excluded.

## Output

Returns an array of
[`PSScriptBuilderComponentDependencyEntry`](../reference/types.md#psscriptbuildercomponentdependencyentry),
one per reachable component.

## See Also

- [Dependency Analysis Guide](../guides/dependency-analysis.md#querying-the-dependency-graph)
- [Cmdlet Reference: Get-PSScriptBuilderDependencyAnalysis](Get-PSScriptBuilderDependencyAnalysis.md)
- [Cmdlet Reference: ConvertTo-PSScriptBuilderComponentDependencyTree](ConvertTo-PSScriptBuilderComponentDependencyTree.md)
