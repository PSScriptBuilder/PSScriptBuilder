# ConvertTo-PSScriptBuilderComponentDependencyTree

Converts component dependency entries to a hierarchical tree string.

## Description

Renders the array of `PSScriptBuilderComponentDependencyEntry` objects returned by
[`Get-PSScriptBuilderComponentDependency`](Get-PSScriptBuilderComponentDependency.md) as an
indented Unicode tree diagram, showing the full path from the root to each dependency. Returns
the diagram as a string — for display, writing to a file, or embedding in documentation.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-InputObject` | `PSScriptBuilderComponentDependencyEntry` | **Required.** The dependency entries to render. Accepts pipeline input. |

## Examples

### Render a dependency chain as a tree

```powershell
$analysis | Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
    ConvertTo-PSScriptBuilderComponentDependencyTree
```

```text title="Output"
New-Employee
├── Address
├── Department
└── Employee
    ├── EmploymentStatus
    └── Person
```

### Capture the tree and write it to a file

```powershell
$analysis | Get-PSScriptBuilderComponentDependency -Name 'BaseClass' -Direction Dependents |
    ConvertTo-PSScriptBuilderComponentDependencyTree |
    Set-Content -Path '.\dependents.txt'
```

## Output

Returns the tree diagram as a `string`.

## See Also

- [Dependency Analysis Guide: Querying the Dependency Graph](../guides/dependency-analysis.md#querying-the-dependency-graph)
- [Cmdlet Reference: Get-PSScriptBuilderComponentDependency](Get-PSScriptBuilderComponentDependency.md)
