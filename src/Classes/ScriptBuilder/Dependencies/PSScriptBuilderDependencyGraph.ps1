using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderDependencyGraph
<#
.SYNOPSIS
    Represents a dependency graph as an adjacency list.
.DESCRIPTION
    The PSScriptBuilderDependencyGraph class stores dependencies between components (enums, classes, functions) 
    using a minimal adjacency list structure.
    Each node maps to a set of its dependencies. Uses case-insensitive comparison for component names to match 
    PowerShell's type system behavior.
#>
class PSScriptBuilderDependencyGraph {
    #region Properties
    <#
    .SYNOPSIS
        Adjacency list storing component dependencies.
    .DESCRIPTION
        Dictionary where key is a component name and value is a List of PSScriptBuilderDependencyEdge objects
        representing all outgoing edges. Uses case-insensitive string comparison for component names.
    #>
    hidden [Dictionary[string, List[PSScriptBuilderDependencyEdge]]] $Dependencies
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderDependencyGraph.
    .DESCRIPTION
        Creates an empty dependency graph with case-insensitive component name comparison.
    #>
    PSScriptBuilderDependencyGraph() {
        $this.Dependencies = [Dictionary[string, List[PSScriptBuilderDependencyEdge]]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Registers a component as a node in the graph without any edges.
    .DESCRIPTION
        The AddNode() method ensures a component exists as a node in the graph, even if it has no
        dependencies and nothing depends on it. This is required for isolated components (no edges)
        to appear in topological sort results.

        The method is idempotent: calling it for an already-registered node has no effect.
    .PARAMETER name
        The component name to register. Cannot be null or empty.
    #>
    [void] AddNode([string] $name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [ArgumentException]::new("Parameter 'name' cannot be null or empty")
        }

        if (-not $this.Dependencies.ContainsKey($name)) {
            $this.Dependencies[$name] = [List[PSScriptBuilderDependencyEdge]]::new()
        }
    }

    <#
    .SYNOPSIS
        Adds a typed dependency edge to the graph.
    .DESCRIPTION
        The AddEdge method creates a directed edge from the 'from' component to the 'to' component, indicating
        that 'from' depends on 'to'. The edge type classifies the nature of the dependency.
        If the 'from' node does not exist in the graph, it is created automatically.
        Self-dependencies (where 'from' and 'to' are the same) are allowed and will be detected by cycle
        detection logic elsewhere.
        Duplicate prevention: if an identical edge (same Target and EdgeType) already exists for 'from',
        the call is a no-op. This allows multiple distinct edge types to co-exist for the same target
        (e.g. an Inheritance edge and a StaticInitializer edge can both be recorded for the same dependency).
    .PARAMETER from
        The component that has a dependency.
    .PARAMETER to
        The component that is depended upon.
    .PARAMETER edgeType
        The type of dependency relationship.
    #>
    [void] AddEdge([string] $from, [string] $to, [PSScriptBuilderDependencyEdgeType] $edgeType) {
        if ([string]::IsNullOrWhiteSpace($from)) {
            throw [ArgumentException]::new("Parameter 'from' cannot be null or empty")
        }

        if ([string]::IsNullOrWhiteSpace($to)) {
            throw [ArgumentException]::new("Parameter 'to' cannot be null or empty")
        }

        # Ensure the 'from' node exists
        if (-not $this.Dependencies.ContainsKey($from)) {
            $this.Dependencies[$from] = [List[PSScriptBuilderDependencyEdge]]::new()
        }

        # Duplicate prevention: skip if an identical edge (same target and edge type) already exists
        foreach ($existingEdge in $this.Dependencies[$from]) {
            if ($existingEdge.Target -eq $to -and $existingEdge.EdgeType -eq $edgeType) {
                return
            }
        }

        # Add the typed edge
        $this.Dependencies[$from].Add([PSScriptBuilderDependencyEdge]::new($to, $edgeType))
    }

    <#
    .SYNOPSIS
        Gets all dependencies for a specific component.
    .DESCRIPTION
        Returns a HashSet of all target component names that the given component depends on,
        across all edge types. Returns a copy to prevent external modification of the internal
        graph structure.
    .PARAMETER componentName
        The name of the component.
    .OUTPUTS
        Returns HashSet[string] of dependency target names, or empty set if component has none.
    #>
    [HashSet[string]] GetDependencies([string] $componentName) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            throw [ArgumentException]::new("Parameter 'componentName' cannot be null or empty")
        }

        $result = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        if ($this.Dependencies.ContainsKey($componentName)) {
            foreach ($edge in $this.Dependencies[$componentName]) {
                $result.Add($edge.Target) | Out-Null
            }
        }

        return $result
    }

    <#
    .SYNOPSIS
        Gets dependencies of a specific edge type for a component.
    .DESCRIPTION
        Returns a HashSet of target component names that the given component depends on,
        filtered to only the specified edge type. Used by CycleDetector to restrict cycle
        detection to Inheritance edges only.
    .PARAMETER componentName
        The name of the component.
    .PARAMETER edgeType
        The edge type to filter by.
    .OUTPUTS
        Returns HashSet[string] of dependency target names matching the given edge type,
        or empty set if none exist.
    #>
    [HashSet[string]] GetDependencies([string] $componentName, [PSScriptBuilderDependencyEdgeType] $edgeType) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            throw [ArgumentException]::new("Parameter 'componentName' cannot be null or empty")
        }

        $result = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        if ($this.Dependencies.ContainsKey($componentName)) {
            foreach ($edge in $this.Dependencies[$componentName]) {
                if ($edge.EdgeType -eq $edgeType) {
                    $result.Add($edge.Target) | Out-Null
                }
            }
        }

        return $result
    }

    <#
    .SYNOPSIS
        Gets components that depend on a specific component.
    .DESCRIPTION
        The GetDependents method returns all components that have a dependency on the given component.
        This is the reverse direction of GetDependencies() and is useful for impact analysis and refactoring 
        scenarios. For example, if you want to know which components would be affected by changes to a base 
        class, use this method.

        Returns a HashSet copy to prevent external modification of the internal graph structure.

        Example use cases:
        - Impact analysis: Which components are affected if I change this component?
        - Refactoring: What needs to be updated if I rename/remove this component?
        - Hierarchy analysis: Which classes inherit from this base class?
        - Breaking change detection: Which components depend on this API?
    .PARAMETER componentName
        The name of the component to find dependents for.
    .OUTPUTS
        Returns HashSet[string] of components that depend on the given component, or empty set if no dependents 
        exist.
    #>
    [HashSet[string]] GetDependents([string] $componentName) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            throw [ArgumentException]::new("Parameter 'componentName' cannot be null or empty")
        }

        $result = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        # Iterate through all components and check if they depend on the given component
        foreach ($entry in $this.Dependencies.GetEnumerator()) {
            foreach ($edge in $entry.Value) {
                if ($edge.Target -eq $componentName) {
                    $result.Add($entry.Key) | Out-Null
                    break
                }
            }
        }

        return $result
    }

    <#
    .SYNOPSIS
        Gets components that depend on a specific component via a specific edge type.
    .DESCRIPTION
        The GetDependents method returns all components that have a dependency of the specified
        edge type on the given component. This is the edge-type-filtered reverse of GetDependencies().

        The primary use case is inheritance hierarchy analysis: passing EdgeType Inheritance returns
        only the direct subclasses of the given component, ignoring TypeReference and other edge types.

        Returns a HashSet copy to prevent external modification of the internal graph structure.

        Example use cases:
        - Inheritance hierarchy: Which classes directly inherit from this base class?
        - Impact analysis filtered by relationship type: Which components depend on this component via FunctionCall?
    .PARAMETER componentName
        The name of the component to find dependents for.
    .PARAMETER edgeType
        The edge type to filter by.
    .OUTPUTS
        Returns HashSet[string] of components that depend on the given component via the specified edge type,
        or empty set if no such dependents exist.
    #>
    [HashSet[string]] GetDependents([string] $componentName, [PSScriptBuilderDependencyEdgeType] $edgeType) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            throw [ArgumentException]::new("Parameter 'componentName' cannot be null or empty")
        }

        $result = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($entry in $this.Dependencies.GetEnumerator()) {
            foreach ($edge in $entry.Value) {
                if ($edge.Target -eq $componentName -and $edge.EdgeType -eq $edgeType) {
                    $result.Add($entry.Key) | Out-Null
                    break
                }
            }
        }

        return $result
    }

    <#
    .SYNOPSIS
        Gets all component names in the graph.
    .DESCRIPTION
        The GetAllNodes method aggregates all unique component names that appear as keys (components with 
        dependencies) or values (components that are depended upon) in the graph.
    .OUTPUTS
        Returns HashSet[string] of all component names.
    #>
    [HashSet[string]] GetAllNodes() {
        $nodes = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        # Add all keys (components that have dependencies)
        foreach ($key in $this.Dependencies.Keys) {
            $nodes.Add($key) | Out-Null
        }

        # Add all values (components that are depended upon)
        foreach ($edgeList in $this.Dependencies.Values) {
            foreach ($edge in $edgeList) {
                $nodes.Add($edge.Target) | Out-Null
            }
        }

        return $nodes
    }

    <#
    .SYNOPSIS
        Checks if a component exists in the graph.
    .DESCRIPTION
        The HasNode method checks if a given component name exists in the graph either as a key (indicating it has 
        dependencies) or as a value in any of the dependency sets (indicating it is depended upon).
        This allows for detection of components that may not have their own dependencies but are still part of 
        the graph.
    .PARAMETER componentName
        The name of the component to check.
    .OUTPUTS
        Returns $true if component exists, $false otherwise.
    #>
    [bool] HasNode([string] $componentName) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            return $false
        }

        # Check if it's a key
        if ($this.Dependencies.ContainsKey($componentName)) {
            return $true
        }

        # Check if it appears in any edge list
        foreach ($edgeList in $this.Dependencies.Values) {
            foreach ($edge in $edgeList) {
                if ($edge.Target -eq $componentName) {
                    return $true
                }
            }
        }

        return $false
    }

    <#
    .SYNOPSIS
        Gets the total number of dependency edges in the graph.
    .DESCRIPTION
        The GetEdgeCount method calculates the total number of dependency edges (connections) in the graph
        by summing the counts of all dependency sets. This represents the total number of dependencies
        across all components.
    .OUTPUTS
        Returns the total number of dependency edges as an integer.
    #>
    [int] GetEdgeCount() {
        $count = 0

        foreach ($edgeList in $this.Dependencies.Values) {
            $count += $edgeList.Count
        }

        return $count
    }

    <#
    .SYNOPSIS
        Returns the internal adjacency list as a read-accessible map.
    .DESCRIPTION
        The GetEdgeMap() method provides controlled access to the internal dependency map
        for consumers that need to iterate over all nodes and their outgoing edges
        (e.g. graph renderers, warning generators).

        The returned dictionary is the live internal structure - callers must not modify it.
        For read-only iteration (rendering, analysis), this is sufficient.
    .OUTPUTS
        Returns Dictionary[string, List[PSScriptBuilderDependencyEdge]] of all nodes and their edges.
    #>
    [Dictionary[string, List[PSScriptBuilderDependencyEdge]]] GetEdgeMap() {
        return $this.Dependencies
    }

    <#
    .SYNOPSIS
        Gets the total number of nodes (components) in the graph.
    .DESCRIPTION
        The GetNodeCount method returns the total number of unique components in the graph,
        including both components that have dependencies (keys) and components that are depended
        upon (values). Delegates to GetAllNodes() for consistency.
    .OUTPUTS
        Returns the total number of nodes as an integer.
    #>
    [int] GetNodeCount() {
        return $this.GetAllNodes().Count
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderDependencyGraph
