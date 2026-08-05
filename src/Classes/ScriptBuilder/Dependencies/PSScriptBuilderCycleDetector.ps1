using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderCycleDetector
<#
.SYNOPSIS
    Detects circular dependencies in a dependency graph.
.DESCRIPTION
    The PSScriptBuilderCycleDetector uses depth-first search (DFS) with 3-state tracking
    to detect cycles in a dependency graph. It can both check for cycle existence and
    retrieve the path of the first cycle found.
#>
class PSScriptBuilderCycleDetector {
    #region Properties
    <#
    .SYNOPSIS
        The dependency graph to analyze.
    .DESCRIPTION
        The Graph property holds the dependency graph that will be analyzed for circular dependencies. 
        It is set during construction and used by the HasCycle() and GetCyclePath() methods to perform the 
        analysis.
    #>
    hidden [PSScriptBuilderDependencyGraph] $Graph

    <#
    .SYNOPSIS
        Visited state for each node during DFS (detection-time context).
    .DESCRIPTION
        The VisitedState property is a case-insensitive dictionary tracking DFS state: 0=Unvisited, 1=InProgress, 
        2=Visited. 
        It is used during HasCycle() and GetCyclePath() execution to track the state of each node in the graph.
    #>
    hidden [Dictionary[string, int]] $VisitedState

    <#
    .SYNOPSIS
        Current path during DFS traversal (detection-time context).
    .DESCRIPTION
        The CurrentPath property is a list tracking the current DFS path for cycle path reconstruction.
        It is used during GetCyclePath() execution to build the path of the first cycle found.
    #>
    hidden [List[string]] $CurrentPath
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderCycleDetector.
    .DESCRIPTION
        Creates a new cycle detector for the specified dependency graph.
    .PARAMETER graph
        The dependency graph to analyze.
    #>
    PSScriptBuilderCycleDetector([PSScriptBuilderDependencyGraph] $graph) {
        if ($null -eq $graph) {
            throw [ArgumentNullException]::new("graph", "The parameter 'graph' cannot be null.")
        }

        $this.Graph = $graph
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Checks if the graph contains circular dependencies.
    .DESCRIPTION
        The HasCycle() method analyzes the dependency graph to determine if any circular dependencies exist. 
        It uses depth-first search (DFS) with 3-state tracking to detect cycles. It initializes the visited state 
        for all nodes and performs DFS from each unvisited node. If it encounters a node that is currently in 
        progress, it indicates a cycle. The method returns true if any cycle is found, or false if the graph is 
        acyclic. 
    .OUTPUTS
        Returns $true if cycle exists, $false otherwise.
    #>
    [bool] HasCycle() {
        Write-Verbose "Checking for circular dependencies..."

        $graphNodes = $this.Graph.GetAllNodes()

        if ($graphNodes.Count -eq 0) {
            Write-Verbose "  No nodes in graph - skipping analysis"
            return $false
        }

        # Initialize DFS context with case-insensitive dictionary
        $this.VisitedState = [Dictionary[string, int]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($node in $graphNodes) {
            $this.VisitedState[$node] = 0  # 0 = Unvisited
        }

        Write-Verbose "  Analyzing $($graphNodes.Count) node(s)..."

        # Perform DFS from each unvisited node
        foreach ($node in $graphNodes) {
            if ($this.VisitedState[$node] -eq 0) {
                if ($this.DfsHasCycle($node)) {
                    Write-Verbose "  Cycle detected during DFS"
                    return $true
                }
            }
        }

        Write-Verbose "  No circular dependencies found"
        return $false
    }

    <#
    .SYNOPSIS
        Gets the path of the first cycle found.
    .DESCRIPTION
        The GetCyclePath() method performs a depth-first search similar to HasCycle(), but also tracks the current 
        path of nodes being visited. When it encounters a back edge (a dependency that is currently in progress), it 
        extracts the cycle path from the current path list and returns it. If no cycle is found, it returns an empty 
        array. This allows callers to get detailed information about the cycle for error reporting or analysis.
    .OUTPUTS
        Returns array of node names forming the cycle, or empty array if no cycle.
    #>
    [string[]] GetCyclePath() {
        Write-Verbose "Retrieving cycle path..."

        # Initialize DFS context with path tracking
        $this.VisitedState = [Dictionary[string, int]]::new([StringComparer]::OrdinalIgnoreCase)
        $this.CurrentPath = [List[string]]::new()
        $graphNodes = $this.Graph.GetAllNodes()

        foreach ($node in $graphNodes) {
            $this.VisitedState[$node] = 0  # 0 = Unvisited
        }

        # Perform DFS from each unvisited node
        foreach ($node in $graphNodes) {
            if ($this.VisitedState[$node] -eq 0) {
                $cyclePath = $this.DfsGetCyclePath($node)

                if ($null -ne $cyclePath -and $cyclePath.Count -gt 0) {
                    Write-Verbose "  Cycle path retrieved: $($cyclePath -join ' -> ')"
                    return $cyclePath
                }
            }
        }

        return @()
    }
    #endregion Methods

    #region Helper Methods
    <#
    .SYNOPSIS
        Performs DFS to detect cycles (recursive helper).
    .DESCRIPTION
        The DfsHasCycle() method performs a depth-first search starting from the given node. It marks nodes as 
        InProgress when they are first visited and Visited when fully processed.
        If it encounters a node that is already InProgress, it indicates a back edge and thus a cycle. 
    .PARAMETER node
        The current node being visited.
    .OUTPUTS
        Returns $true if cycle detected, $false otherwise.
    #>
    hidden [bool] DfsHasCycle([string] $node) {
        # Mark as InProgress (currently in DFS stack)
        $this.VisitedState[$node] = 1

        # Check only fatal edges (Inheritance + StaticInitializer) - TypeReference and FunctionCall cycles are not fatal in PS 5.1
        $fatalDependencies = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($dependency in $this.Graph.GetDependencies($node, [PSScriptBuilderDependencyEdgeType]::Inheritance)) {
            $fatalDependencies.Add($dependency) | Out-Null
        }

        foreach ($dependency in $this.Graph.GetDependencies($node, [PSScriptBuilderDependencyEdgeType]::StaticInitializer)) {
            $fatalDependencies.Add($dependency) | Out-Null
        }

        foreach ($dependency in $fatalDependencies) {
            $state = $this.VisitedState[$dependency]

            if ($state -eq 1) {
                # Found back edge - cycle detected
                return $true
            }

            if ($state -eq 0) {
                # Unvisited - recurse
                if ($this.DfsHasCycle($dependency)) {
                    return $true
                }
            }

            # State 2 (Visited) - already processed, skip
        }

        # Mark as Visited (completely processed)
        $this.VisitedState[$node] = 2
        return $false
    }

    <#
    .SYNOPSIS
        Performs DFS to find cycle path (recursive helper).
    .DESCRIPTION
        The DfsGetCyclePath() method is similar to DfsHasCycle but also tracks the current path of nodes being 
        visited. 
        When it encounters a back edge (a dependency that is currently InProgress), it extracts the cycle path 
        from the current path list and returns it. If no cycle is found from the current node, it returns null. 
        This allows GetCyclePath() to return the actual nodes involved in the cycle for error reporting.
    .PARAMETER node
        The current node being visited.
    .OUTPUTS
        Returns array of nodes forming the cycle, or null if no cycle from this node.
    #>
    hidden [string[]] DfsGetCyclePath([string] $node) {
        # Mark as InProgress and add to current path
        $this.VisitedState[$node] = 1
        $this.CurrentPath.Add($node)

        # Check only fatal edges (Inheritance + StaticInitializer) - TypeReference and FunctionCall cycles are not fatal in PS 5.1
        $fatalDependencies = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($dependency in $this.Graph.GetDependencies($node, [PSScriptBuilderDependencyEdgeType]::Inheritance)) {
            $fatalDependencies.Add($dependency) | Out-Null
        }

        foreach ($dependency in $this.Graph.GetDependencies($node, [PSScriptBuilderDependencyEdgeType]::StaticInitializer)) {
            $fatalDependencies.Add($dependency) | Out-Null
        }

        foreach ($dependency in $fatalDependencies) {
            $state = $this.VisitedState[$dependency]

            if ($state -eq 1) {
                # Found back edge - extract cycle from path
                $cycleStartIndex = $this.CurrentPath.IndexOf($dependency)
                $cycleLength     = $this.CurrentPath.Count - $cycleStartIndex

                # Create cycle path: [cycleStart ... currentNode -> cycleStart]
                $cyclePath = [List[string]]::new($this.CurrentPath.GetRange($cycleStartIndex, $cycleLength))
                $cyclePath.Add($dependency)  # Close the cycle

                return $cyclePath.ToArray()
            }

            if ($state -eq 0) {
                # Unvisited - recurse
                $result = $this.DfsGetCyclePath($dependency)

                if ($null -ne $result) {
                    return $result
                }
            }

            # State 2 (Visited) - already processed, skip
        }

        # Mark as Visited and remove from current path
        $this.VisitedState[$node] = 2
        $this.CurrentPath.RemoveAt($this.CurrentPath.Count - 1)

        return $null
    }
    #endregion Helper Methods
}
#endregion Class PSScriptBuilderCycleDetector
