using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderDependencyGraphTraverser
<#
.SYNOPSIS
    Traverses a dependency graph recursively for a named component.
.DESCRIPTION
    The PSScriptBuilderDependencyGraphTraverser class performs a breadth-first search (BFS)
    on a PSScriptBuilderDependencyGraph starting from a named component. It collects all
    reachable components in either direction:

    - Dependencies: all components that the named component directly or transitively depends on
    - Dependents:   all components that directly or transitively depend on the named component

    A visited HashSet guards against infinite traversal caused by TypeReference cycles, which
    are valid in PowerShell 5.1 and not treated as build errors.

    The traversal root itself is not included in the results. Depth starts at 1 for direct
    neighbours.

    This class is the backing implementation for Get-PSScriptBuilderComponentDependency.
#>
class PSScriptBuilderDependencyGraphTraverser {
    #region Properties
    <#
    .SYNOPSIS
        The dependency graph to traverse.
    .DESCRIPTION
        The Graph property holds the dependency graph used for all traversal operations.
        It is set during construction and used by the Traverse() method.
    #>
    hidden [PSScriptBuilderDependencyGraph] $Graph
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderDependencyGraphTraverser.
    .DESCRIPTION
        Creates a new traverser for the specified dependency graph.
    .PARAMETER graph
        The dependency graph to traverse. Cannot be null.
    #>
    PSScriptBuilderDependencyGraphTraverser([PSScriptBuilderDependencyGraph] $graph) {
        if ($null -eq $graph) {
            $message = "The parameter 'graph' cannot be null."
            throw [ArgumentNullException]::new("graph", $message)
        }

        $this.Graph = $graph
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Traverses the dependency graph from the named component and returns all reachable entries.
    .DESCRIPTION
        The Traverse() method performs a breadth-first search starting from the named component
        in the specified direction. Each reachable component is returned as a
        PSScriptBuilderComponentDependencyEntry with its name, depth, and full path from root.

        A visited HashSet prevents infinite traversal through TypeReference cycles.
        The root component itself is not included in the results.
    .PARAMETER name
        The name of the component to start traversal from. Must exist in the graph.
    .PARAMETER direction
        The traversal direction. Use PSScriptBuilderTraversalDirection.Dependencies or .Dependents.
    .OUTPUTS
        Returns an array of PSScriptBuilderComponentDependencyEntry objects, one per reachable component.
        Returns an empty array if the component has no reachable neighbours in the specified direction.
    #>
    [PSScriptBuilderComponentDependencyEntry[]] Traverse([string] $name, [PSScriptBuilderTraversalDirection] $direction) {
        $this.ValidateName($name)
        Write-Verbose "Traversing $direction of '$name'..."
        return $this.RunBfs($name, $direction, @())
    }

    <#
    .SYNOPSIS
        Traverses the dependency graph filtered by edge type.
    .DESCRIPTION
        The Traverse() method performs a breadth-first search starting from the named component
        in the specified direction, following only edges of the specified type. Each reachable
        component is returned as a PSScriptBuilderComponentDependencyEntry with its name, depth,
        and full path from root.

        The primary use case is inheritance hierarchy analysis: passing EdgeType Inheritance
        returns only the inheritance chain, ignoring TypeReference and other edge types.

        A visited HashSet prevents infinite traversal through TypeReference cycles.
        The root component itself is not included in the results.
    .PARAMETER name
        The name of the component to start traversal from. Must exist in the graph.
    .PARAMETER direction
        The traversal direction. Use PSScriptBuilderTraversalDirection.Dependencies or .Dependents.
    .PARAMETER edgeType
        One or more edge types to follow during traversal. Only edges of these types are traversed.
        When multiple types are specified, their results are combined (union).
    .OUTPUTS
        Returns an array of PSScriptBuilderComponentDependencyEntry objects, one per reachable component.
        Returns an empty array if the component has no reachable neighbours of the specified edge type(s).
    #>
    [PSScriptBuilderComponentDependencyEntry[]] Traverse([string] $name, [PSScriptBuilderTraversalDirection] $direction, [PSScriptBuilderDependencyEdgeType[]] $edgeTypes) {
        $this.ValidateName($name)
        Write-Verbose "Traversing $direction of '$name' (EdgeTypes: $($edgeTypes -join ', '))..."
        return $this.RunBfs($name, $direction, $edgeTypes)
    }

    <#
    .SYNOPSIS
        Validates the component name parameter.
    .DESCRIPTION
        The ValidateName() method enforces guard clauses shared by all Traverse() overloads:
        the name must not be null or whitespace, and must exist in the dependency graph.
    .PARAMETER name
        The component name to validate.
    #>
    hidden [void] ValidateName([string] $name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            $message = "Parameter 'name' cannot be null or empty."
            throw [ArgumentException]::new($message, "name")
        }

        if (-not $this.Graph.Dependencies.ContainsKey($name)) {
            $format  = "Component '{0}' was not found in the dependency graph."
            $message = $format -f $name
            throw [InvalidOperationException]::new($message)
        }
    }

    <#
    .SYNOPSIS
        Shared BFS implementation for all Traverse() overloads.
    .DESCRIPTION
        The RunBfs() method contains the breadth-first search logic shared by all Traverse() overloads.
        When edgeTypeFilter is empty, all edge types are traversed. When it contains one or more elements,
        only edges of those types are followed and their results are combined (union).
    .PARAMETER name
        The validated component name to start traversal from.
    .PARAMETER direction
        The traversal direction.
    .PARAMETER edgeTypeFilter
        An array of edge types to filter by. Pass an empty array to traverse all edge types.
    .OUTPUTS
        Returns an array of PSScriptBuilderComponentDependencyEntry objects.
    #>
    hidden [PSScriptBuilderComponentDependencyEntry[]] RunBfs([string] $name, [PSScriptBuilderTraversalDirection] $direction, [PSScriptBuilderDependencyEdgeType[]] $edgeTypeFilter) {
        $results   = [List[PSScriptBuilderComponentDependencyEntry]]::new()
        $visited   = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $depthMap  = [Dictionary[string, int]]::new([StringComparer]::OrdinalIgnoreCase)
        $parentMap = [Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
        $queue     = [Queue[string]]::new()

        [void] $visited.Add($name)
        $depthMap[$name] = 0
        $queue.Enqueue($name)

        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()

            if ($edgeTypeFilter.Length -eq 0) {
                $neighbors = $this.GetNeighbors($current, $direction)
            }
            else {
                $neighbors = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

                foreach ($edgeType in $edgeTypeFilter) {
                    foreach ($edgeNeighbor in $this.GetNeighbors($current, $direction, $edgeType)) {
                        [void] $neighbors.Add($edgeNeighbor)
                    }
                }
            }

            foreach ($neighbor in $neighbors) {
                if (-not $visited.Contains($neighbor)) {
                    [void] $visited.Add($neighbor)
                    $depthMap[$neighbor]  = $depthMap[$current] + 1
                    $parentMap[$neighbor] = $current
                    $queue.Enqueue($neighbor)

                    $depth = $depthMap[$neighbor]
                    $path  = $this.BuildPath($neighbor, $parentMap, $name)
                    $entry = [PSScriptBuilderComponentDependencyEntry]::new($neighbor, $depth, $path)
                    $results.Add($entry)
                }
            }
        }

        Write-Verbose "Traversal complete: $($results.Count) component(s) found"
        return $results.ToArray()
    }

    <#
    .SYNOPSIS
        Returns the direct neighbours of a component in the specified direction.
    .DESCRIPTION
        The GetNeighbors() method delegates to GetDependencies() or GetDependents() on the graph
        depending on the traversal direction.
    .PARAMETER name
        The component name to retrieve neighbours for.
    .PARAMETER direction
        The traversal direction.
    .OUTPUTS
        Returns a HashSet[string] of direct neighbour names.
    #>
    hidden [HashSet[string]] GetNeighbors([string] $name, [PSScriptBuilderTraversalDirection] $direction) {
        if ($direction -eq [PSScriptBuilderTraversalDirection]::Dependents) {
            return $this.Graph.GetDependents($name)
        }

        return $this.Graph.GetDependencies($name)
    }

    <#
    .SYNOPSIS
        Returns the direct neighbours of a component in the specified direction, filtered by edge type.
    .DESCRIPTION
        The GetNeighbors() method delegates to GetDependencies() or GetDependents() on the graph
        with the specified edge type filter.
    .PARAMETER name
        The component name to retrieve neighbours for.
    .PARAMETER direction
        The traversal direction.
    .PARAMETER edgeType
        The edge type to filter by.
    .OUTPUTS
        Returns a HashSet[string] of direct neighbour names reachable via the specified edge type.
    #>
    hidden [HashSet[string]] GetNeighbors([string] $name, [PSScriptBuilderTraversalDirection] $direction, [PSScriptBuilderDependencyEdgeType] $edgeType) {
        if ($direction -eq [PSScriptBuilderTraversalDirection]::Dependents) {
            return $this.Graph.GetDependents($name, $edgeType)
        }

        return $this.Graph.GetDependencies($name, $edgeType)
    }

    <#
    .SYNOPSIS
        Reconstructs the full path from root to a component using the parent map.
    .DESCRIPTION
        The BuildPath() method walks the parentMap backwards from the given component name
        up to the root, then reverses the result to produce a root-first ordered path.
    .PARAMETER name
        The component to build the path to.
    .PARAMETER parentMap
        Dictionary mapping each visited component to its BFS parent.
    .PARAMETER root
        The traversal root (starting component name).
    .OUTPUTS
        Returns a string array with the root at index 0 and the component at the last index.
    #>
    hidden [string[]] BuildPath([string] $name, [Dictionary[string, string]] $parentMap, [string] $root) {
        $path    = [List[string]]::new()
        $current = $name

        while ($current -ne $root) {
            $path.Add($current)
            $current = $parentMap[$current]
        }

        $path.Add($root)
        $path.Reverse()

        return $path.ToArray()
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderDependencyGraphTraverser
