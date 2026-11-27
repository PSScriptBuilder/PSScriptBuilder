using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderTopologicalSorter
<#
.SYNOPSIS
    Performs topological sorting of a dependency graph.
.DESCRIPTION
    The PSScriptBuilderTopologicalSorter uses Kahn's algorithm to produce a topological
    ordering of components in a dependency graph. This ensures that all dependencies
    appear before the components that depend on them.
#>
class PSScriptBuilderTopologicalSorter {
    #region Properties
    <#
    .SYNOPSIS
        The dependency graph to sort.
    .DESCRIPTION
        The Graph property holds the dependency graph that will be sorted topologically.
        It is set during construction and used by the Sort() method.
    #>
    hidden [PSScriptBuilderDependencyGraph] $Graph

    <#
    .SYNOPSIS
        Optional node name -> collector type map, used to break ties deterministically.
    .DESCRIPTION
        The NodeTypes property maps component names to their PSScriptBuilderCollectorType
        (ClassCollector or FunctionCollector). When present, RunKahnsAlgorithm() uses it to choose
        deterministically among several simultaneously-ready nodes that have no dependency path
        between them, instead of relying on the graph's own node enumeration order. Nodes with no
        entry here (e.g. enums, or when the map itself is not supplied) fall back to plain arrival
        order - StabilizeEnumsFirst corrects enum positions afterward regardless.
    #>
    hidden [Dictionary[string, PSScriptBuilderCollectorType]] $NodeTypes

    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderTopologicalSorter.
    .DESCRIPTION
        Creates a new topological sorter for the specified dependency graph. Ties among
        simultaneously-ready nodes with no dependency path between them fall back to arrival order.
    .PARAMETER graph
        The dependency graph to sort.
    #>
    PSScriptBuilderTopologicalSorter([PSScriptBuilderDependencyGraph] $graph) {
        if ($null -eq $graph) {
            $message = "The parameter 'graph' cannot be null."
            throw [ArgumentNullException]::new("graph", $message)
        }

        $this.Graph     = $graph
        $this.NodeTypes = $null
    }

    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderTopologicalSorter with a node-type map.
    .DESCRIPTION
        Creates a new topological sorter for the specified dependency graph, using the supplied
        node-type map to break ties deterministically among simultaneously-ready Class/Function
        nodes with no dependency path between them: Classes are preferred over Functions, and ties
        within the same type are broken alphabetically. Nodes with no entry in the map fall back to
        arrival order.
    .PARAMETER graph
        The dependency graph to sort.
    .PARAMETER nodeTypes
        Maps component names to their PSScriptBuilderCollectorType (ClassCollector or
        FunctionCollector). Entries for other collector types are ignored.
    #>
    PSScriptBuilderTopologicalSorter(
        [PSScriptBuilderDependencyGraph] $graph,
        [Dictionary[string, PSScriptBuilderCollectorType]] $nodeTypes
    ) {
        if ($null -eq $graph) {
            $message = "The parameter 'graph' cannot be null."
            throw [ArgumentNullException]::new("graph", $message)
        }

        $this.Graph     = $graph
        $this.NodeTypes = $nodeTypes
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Performs topological sort on the dependency graph.
    .DESCRIPTION
        The Sort() method uses Kahn's algorithm to produce a topological ordering of all
        components in the graph. The algorithm:
        1. Runs Kahn's algorithm across all edge types (Inheritance, TypeReference, FunctionCall, StaticInitializer)
        2. If all nodes are processed, reverses the result and returns it
        3. If nodes remain (stuck due to TypeReference-only cycles), builds a sub-graph
           containing only the stuck nodes and their fatal edges (Inheritance and StaticInitializer),
           runs Kahn's algorithm again on the sub-graph, and appends the result
        4. Reverses the combined result to produce prerequisites-first order

        TypeReference cycles (e.g. two classes referencing each other in method bodies) are
        fully valid in PowerShell 5.1 and do not cause a load-time error. Stuck nodes caused
        by such cycles are resolved by the fatal-edge sub-graph pass.

        If the graph still contains unprocessed nodes after both passes, a fatal cycle
        (Inheritance or StaticInitializer) exists. This throws InvalidOperationException as
        a safety net (fatal cycles should have been caught by PSScriptBuilderCycleDetector
        before Sort() is called).
    .OUTPUTS
        Returns array of component names in topological order (dependencies first).
    #>
    [string[]] Sort() {
        Write-Verbose "Starting topological sort..."

        $graphNodes = $this.Graph.GetAllNodes()
        $totalNodes = $graphNodes.Count

        if ($totalNodes -eq 0) {
            Write-Verbose "  No nodes in graph - skipping sort"
            return @()
        }

        Write-Verbose "  Processing $totalNodes node(s)..."

        # Run Kahn's algorithm on the full graph (all edge types)
        $mainResult = $this.RunKahnsAlgorithm($this.Graph)

        # Handle stuck nodes: components involved in TypeReference-only cycles were not
        # processed by the main pass. Build a sub-graph using only load-time ordering constraints
        # (Inheritance and StaticInitializer edges) to establish a valid order among them.
        if ($mainResult.Count -lt $totalNodes) {
            $processedSet = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

            foreach ($node in $mainResult) {
                $processedSet.Add($node) | Out-Null
            }

            # Collect stuck nodes
            $stuckNodes = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

            foreach ($node in $graphNodes) {
                if (-not $processedSet.Contains($node)) {
                    $stuckNodes.Add($node) | Out-Null
                }
            }

            # Build sub-graph with stuck nodes and their Inheritance edges only
            $subGraph = [PSScriptBuilderDependencyGraph]::new()

            foreach ($node in $stuckNodes) {
                $subGraph.AddNode($node)
            }

            foreach ($node in $stuckNodes) {
                $fatalDependencies = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

                foreach ($dependency in $this.Graph.GetDependencies($node, [PSScriptBuilderDependencyEdgeType]::Inheritance)) {
                    $fatalDependencies.Add($dependency) | Out-Null
                }

                foreach ($dependency in $this.Graph.GetDependencies($node, [PSScriptBuilderDependencyEdgeType]::StaticInitializer)) {
                    $fatalDependencies.Add($dependency) | Out-Null
                }

                foreach ($dependency in $fatalDependencies) {
                    if ($stuckNodes.Contains($dependency)) {
                        $subGraph.AddEdge($node, $dependency, [PSScriptBuilderDependencyEdgeType]::Inheritance)
                    }
                }
            }

            $subResult = $this.RunKahnsAlgorithm($subGraph)

            foreach ($node in $subResult) {
                $mainResult.Add($node)
            }

            Write-Verbose "  $($subResult.Count) node(s) in type-reference cycle(s) ordered by load-time constraints"
        }

        # Safety net: if still incomplete, an Inheritance cycle exists
        # (should have been caught by CycleDetector before Sort() is called)
        if ($mainResult.Count -ne $totalNodes) {
            $format  = "Topological sort incomplete: processed {0} of {1} nodes. The graph likely contains cycles."
            $message = $format -f $mainResult.Count, $totalNodes
            throw [InvalidOperationException]::new($message)
        }

        # Reverse: Kahn's on a natural-direction graph yields dependents-first;
        # reversing produces the required prerequisites-first order.
        $sortedComponents = $mainResult.ToArray()
        [Array]::Reverse($sortedComponents)

        Write-Verbose "  Topological sort complete: $($sortedComponents.Count) node(s) sorted"
        return $sortedComponents
    }
    #endregion Methods

    #region Helper Methods
    <#
    .SYNOPSIS
        Runs Kahn's algorithm on a given graph and returns nodes in processed order.
    .DESCRIPTION
        The RunKahnsAlgorithm() method receives a graph, performs Kahn's algorithm, and returns the
        list of processed node names in dependents-first order (caller must reverse for
        prerequisites-first).

        Nodes with no dependency path between them (ties) are broken deterministically instead of
        relying on the graph's own node enumeration order (RFC 0017): among simultaneously-ready
        nodes, a Function is preferred over a Class, and ties within the same type are broken by
        alphabetically-later name first. Both preferences are the OPPOSITE of the desired final
        order, because this method's dependents-first output is reversed by the caller (Sort()) -
        preferring Functions here yields Classes first in the final output; preferring
        alphabetically-later names here yields alphabetically-ascending order in the final output.
        Nodes with no entry in NodeTypes (e.g. enums, or when NodeTypes itself is $null) fall back
        to plain arrival order, unchanged from before RFC 0017 - StabilizeEnumsFirst corrects their
        position afterward regardless.

        Two ties are never broken against each other unless the graph has already established no
        dependency path exists between them: a node only becomes ready once every real prerequisite
        it depends on (directly or transitively) has already been processed and removed from
        contention, so this tie-break can never disturb a real, existing dependency chain.

        If the graph contains cycles, the returned list will be incomplete (fewer nodes than
        the graph contains). The caller is responsible for detecting this condition.
    .PARAMETER graph
        The dependency graph to process.
    .OUTPUTS
        Returns List[string] of node names in processed (dependents-first) order.
    #>
    hidden [List[string]] RunKahnsAlgorithm([PSScriptBuilderDependencyGraph] $graph) {
        $inDegree   = [Dictionary[string, int]]::new([StringComparer]::OrdinalIgnoreCase)
        $graphNodes = $graph.GetAllNodes()

        # Initialize all nodes with in-degree 0
        foreach ($node in $graphNodes) {
            $inDegree[$node] = 0
        }

        # Count incoming edges for each node
        foreach ($node in $graphNodes) {
            $dependencies = $graph.GetDependencies($node)

            foreach ($dependency in $dependencies) {
                $inDegree[$dependency]++
            }
        }

        # The ready queue is local to THIS call - never instance state. This method runs twice per
        # Sort() whenever a TypeReference cycle triggers the stuck-node sub-graph pass (see Sort()
        # above); an instance-field ready queue would be left empty after the first invocation and
        # silently break the second one. See PSScriptBuilderTopologicalSortReadyQueue for the
        # tie-break routing/priority logic itself.
        $ready = [PSScriptBuilderTopologicalSortReadyQueue]::new($this.NodeTypes)

        foreach ($entry in $inDegree.GetEnumerator()) {
            if ($entry.Value -eq 0) {
                $ready.Add($entry.Key)
            }
        }

        $result = [List[string]]::new()

        # Kahn's algorithm: process nodes with zero in-degree
        while ($ready.Count() -gt 0) {
            $currentNode = $ready.Dequeue()
            $result.Add($currentNode)

            # Reduce in-degree for each prerequisite of the current node
            $dependencies = $graph.GetDependencies($currentNode)

            foreach ($dependency in $dependencies) {
                $inDegree[$dependency]--

                if ($inDegree[$dependency] -eq 0) {
                    $ready.Add($dependency)
                }
            }
        }

        return $result
    }
    #endregion Helper Methods
}
#endregion Class PSScriptBuilderTopologicalSorter
