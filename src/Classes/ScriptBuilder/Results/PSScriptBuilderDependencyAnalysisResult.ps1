using namespace System

#region Class PSScriptBuilderDependencyAnalysisResult
<#
.SYNOPSIS
    Represents the result of a dependency analysis operation.
.DESCRIPTION
    The PSScriptBuilderDependencyAnalysisResult class encapsulates comprehensive information about
    a dependency analysis operation, including cycle detection, topological ordering, cross-dependency
    detection, component statistics, and dependency graph metrics.

    This class provides a strongly-typed result object for dependency analysis operations,
    enabling pipeline compatibility and format cmdlet support (Format-PSScriptBuilderDependencyAnalysisResult).
#>
class PSScriptBuilderDependencyAnalysisResult {
    #region Properties
    <#
    .SYNOPSIS
        Indicates if circular dependencies were detected.
    .DESCRIPTION
        The HasCycles property is true if one or more circular dependencies were found during analysis.
    #>
    [bool] $HasCycles

    <#
    .SYNOPSIS
        The cycle path if circular dependencies exist.
    .DESCRIPTION
        The CyclePath property contains an array of component names forming the circular dependency chain.
        Empty if no cycles detected.
    #>
    [string[]] $CyclePath

    <#
    .SYNOPSIS
        Indicates if cross-dependencies between component types exist.
    .DESCRIPTION
        The HasCrossDependencies property is true if Enum/Class/Function components are intermixed
        in the dependency order, indicating dependencies that cross component type boundaries.
    #>
    [bool] $HasCrossDependencies

    <#
    .SYNOPSIS
        Topologically sorted component names.
    .DESCRIPTION
        The OrderedComponents property contains an array of component names in dependency order
        (dependencies appear before dependents). Empty if cycles detected.
    #>
    [string[]] $OrderedComponents

    <#
    .SYNOPSIS
        Component counts for all collector types.
    .DESCRIPTION
        The ComponentCounts property contains the number of components collected by each collector type
        (using statements, enums, classes, functions, files).
    #>
    [PSScriptBuilderBuildComponentCounts] $ComponentCounts

    <#
    .SYNOPSIS
        Total number of components collected.
    .DESCRIPTION
        The TotalComponents property contains the sum of all component counts. This is a calculated
        property set during construction.
    #>
    [int] $TotalComponents

    <#
    .SYNOPSIS
        Total number of nodes in the dependency graph.
    .DESCRIPTION
        The TotalNodes property contains the count of all nodes (components) in the dependency graph.
    #>
    [int] $TotalNodes

    <#
    .SYNOPSIS
        Total number of edges (dependencies) in the graph.
    .DESCRIPTION
        The TotalEdges property contains the count of all edges (dependencies) in the dependency graph.
    #>
    [int] $TotalEdges

    <#
    .SYNOPSIS
        The complete dependency graph.
    .DESCRIPTION
        The DependencyGraph property holds the complete dependency graph for advanced analysis scenarios.
        Can be null if not requested or if cycles prevented graph completion.
    #>
    [PSScriptBuilderDependencyGraph] $DependencyGraph
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new dependency analysis result.
    .DESCRIPTION
        Creates a new PSScriptBuilderDependencyAnalysisResult with the specified analysis information.
        The TotalComponents property is calculated automatically from the ComponentCounts.
    .PARAMETER hasCycles
        Whether circular dependencies were detected.
    .PARAMETER cyclePath
        The cycle path if cycles exist (empty array otherwise).
    .PARAMETER hasCrossDependencies
        Whether cross-dependencies between component types exist.
    .PARAMETER orderedComponents
        Topologically sorted component names (empty array if cycles).
    .PARAMETER componentCounts
        Component counts from all collectors.
    .PARAMETER totalNodes
        Total number of nodes in the dependency graph.
    .PARAMETER totalEdges
        Total number of edges in the dependency graph.
    .PARAMETER dependencyGraph
        The complete dependency graph (can be null).
    #>
    PSScriptBuilderDependencyAnalysisResult(
        [bool]                                $hasCycles,
        [string[]]                            $cyclePath,
        [bool]                                $hasCrossDependencies,
        [string[]]                            $orderedComponents,
        [PSScriptBuilderBuildComponentCounts] $componentCounts,
        [int]                                 $totalNodes,
        [int]                                 $totalEdges,
        [PSScriptBuilderDependencyGraph]      $dependencyGraph
    ) {
        $this.HasCycles            = $hasCycles
        $this.CyclePath            = $cyclePath
        $this.HasCrossDependencies = $hasCrossDependencies
        $this.OrderedComponents    = $orderedComponents
        $this.ComponentCounts      = $componentCounts
        $this.TotalNodes           = $totalNodes
        $this.TotalEdges           = $totalEdges
        $this.DependencyGraph      = $dependencyGraph

        # Calculate total components from ComponentCounts
        if ($null -ne $componentCounts) {
            $this.TotalComponents = 
                $componentCounts.UsingStatements     + 
                $componentCounts.EnumDefinitions     + 
                $componentCounts.ClassDefinitions    + 
                $componentCounts.FunctionDefinitions + 
                $componentCounts.FileContents
        }
        else {
            $this.TotalComponents = 0
        }
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderDependencyAnalysisResult
