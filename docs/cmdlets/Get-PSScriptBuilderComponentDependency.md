---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderComponentDependency

## SYNOPSIS
Retrieves all dependencies or dependents of a named component from the dependency graph.

## SYNTAX

```
Get-PSScriptBuilderComponentDependency [-DependencyGraph] <PSScriptBuilderDependencyGraph> [-Name] <String>
 [[-Direction] <PSScriptBuilderTraversalDirection>] [[-EdgeType] <PSScriptBuilderDependencyEdgeType[]>]
 [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderComponentDependency cmdlet performs a breadth-first traversal of the
dependency graph starting from the specified component name.
It returns all reachable components
in the specified direction as PSScriptBuilderComponentDependencyEntry objects.

Each entry contains the component name, its depth relative to the starting component, and the
full dependency path from the root to that component.

The cmdlet accepts ValueFromPipelineByPropertyName, enabling direct piping from
Get-PSScriptBuilderDependencyAnalysis, which returns an object with a DependencyGraph property.

When -EdgeType is specified, only edges of that type are followed during BFS traversal.
This enables focused analysis such as inheritance-only hierarchies.
When omitted, all
edge types are traversed.

## EXAMPLES

### EXAMPLE 1
```
$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
$analysis | Get-PSScriptBuilderComponentDependency -Name 'ClassA'
```

Returns all components that ClassA directly or transitively depends on.

### EXAMPLE 2
```
$analysis | Get-PSScriptBuilderComponentDependency -Name 'BaseClass' -Direction Dependents
```

Returns all components that directly or transitively depend on BaseClass.
Useful for impact analysis before modifying a shared base class.

### EXAMPLE 3
```
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath ".\src\Classes" |
    Get-PSScriptBuilderDependencyAnalysis
```

$analysis | Get-PSScriptBuilderComponentDependency -Name 'MyService' |
    ConvertTo-PSScriptBuilderComponentDependencyTree

Fluent pipeline: analyzes dependencies and renders the result as a tree.

### EXAMPLE 4
```
$analysis.DependencyGraph.Dependencies.Keys | ForEach-Object {
    $deps = $analysis | Get-PSScriptBuilderComponentDependency -Name $_
    [PSCustomObject]@{ Name = $_; Count = $deps.Count }
} | Sort-Object Count -Descending | Select-Object -First 5
```

Identifies the five components with the most transitive dependencies.
A high count may indicate a God-Class that accumulates too many responsibilities.

### EXAMPLE 5
```
$analysis | Get-PSScriptBuilderComponentDependency -Name 'ValidatorBase' -Direction Dependents -EdgeType Inheritance |
    ConvertTo-PSScriptBuilderComponentDependencyTree
```

Renders the full inheritance hierarchy of ValidatorBase as a tree.
Only subclasses are included - components that merely reference ValidatorBase as a type are excluded.

## PARAMETERS

### -DependencyGraph
The dependency graph to traverse.
Accepts pipeline input by property name, enabling
direct piping from Get-PSScriptBuilderDependencyAnalysis.

```yaml
Type: PSScriptBuilderDependencyGraph
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Name
The name of the component to start the traversal from.
Must exist in the dependency graph.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Direction
The traversal direction.
Use Dependencies (default) to find all components the named
component depends on, or Dependents to find all components that depend on it.

```yaml
Type: PSScriptBuilderTraversalDirection
Parameter Sets: (All)
Aliases:
Accepted values: Dependencies, Dependents

Required: False
Position: 3
Default value: Dependencies
Accept pipeline input: False
Accept wildcard characters: False
```

### -EdgeType
Optional.
Restricts BFS traversal to edges of the specified type(s) only.
When omitted,
all edge types (Inheritance, TypeReference, FunctionCall, StaticInitializer) are traversed.
When multiple types are specified, their results are combined (union).

Use EdgeType Inheritance to build a pure inheritance hierarchy - ancestors when combined
with Dependencies, subclasses when combined with -Direction Dependents.

```yaml
Type: PSScriptBuilderDependencyEdgeType[]
Parameter Sets: (All)
Aliases:
Accepted values: Inheritance, TypeReference, FunctionCall, StaticInitializer

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderComponentDependencyEntry
## NOTES
Traversal uses breadth-first search (BFS).
A visited HashSet prevents infinite traversal
through TypeReference cycles, which are valid in PowerShell 5.1.

The named component itself is not included in the results.
Depth starts at 1 for direct
neighbours.

The component name lookup is case-insensitive, matching PowerShell's type system behavior.

Traversal covers all dependency edge types: Inheritance, TypeReference, FunctionCall, and
StaticInitializer.
This means a component appears in the results if it is related through
any of these relationships - not only through inheritance.
Use -EdgeType to restrict
traversal to one or more specific relationship types.

Using -Direction Dependents is the PowerShell equivalent of "Find All References" in an IDE:
it reveals every component that would be affected by a change to the named component.

## RELATED LINKS
