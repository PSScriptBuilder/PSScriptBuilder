using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderDependencyAnalyzer
<#
.SYNOPSIS
    Analyzes dependencies between PowerShell components.
.DESCRIPTION
    The PSScriptBuilderDependencyAnalyzer orchestrates the complete dependency analysis workflow:

    1. Content Collection: Executes all registered collectors
    2. Graph Building: Constructs a dependency graph from collected components
    3. Cycle Detection: Identifies circular dependencies
    4. Topological Sorting: Orders components by dependencies (if no cycles)
    5. Enum Stabilization: Ensures enums appear before classes and functions (if no cycles)
    6. Cross-Dependency Detection: Identifies if component types are intermixed (if no cycles)

    The analyzer is separated from build orchestration to follow the Single Responsibility Principle.
    It can be used independently for analysis-only scenarios (e.g., Get-PSScriptBuilderDependencyAnalysis)
    or as part of the build process (via PSScriptBuilderBuildOrchestrator).

    This separation enables:
    - Reusability across different contexts (analysis cmdlets, build process, validation)
    - Independent testing of dependency analysis logic
    - Clear separation of concerns (analysis vs. build workflow)
#>
class PSScriptBuilderDependencyAnalyzer {
    #region Properties
    <#
    .SYNOPSIS
        The content collector containing all component collectors.
    .DESCRIPTION
        The ContentCollector property holds a reference to the ContentCollector that manages all registered
        collectors (Using, Enum, Class, Function, File). The analyzer uses this to execute collection and
        retrieve component data for dependency analysis.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderDependencyAnalyzer.
    .DESCRIPTION
        Creates the analyzer with the specified content collector. The content collector must have
        at least one registered collector for meaningful analysis.
    .PARAMETER contentCollector
        The content collector with registered component collectors. Cannot be null.
    #>
    PSScriptBuilderDependencyAnalyzer([PSScriptBuilderContentCollector] $contentCollector) {
        if ($null -eq $contentCollector) {
            $message = "Parameter 'contentCollector' cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        $this.ContentCollector = $contentCollector
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Performs complete dependency analysis.
    .DESCRIPTION
        The Analyze() method orchestrates the complete dependency analysis workflow:

        1. Executes all registered collectors to gather components
        2. Builds dependency graph from collected components
        3. Gathers component statistics
        4. Detects circular dependencies
        5. Sorts components topologically (if no cycles)
        6. Stabilizes order: ensures enums appear before classes and functions (if no cycles)
        7. Detects cross-dependencies between component types (if no cycles)

        Returns a strongly-typed PSScriptBuilderDependencyAnalysisResult object containing
        all analysis results.
    .OUTPUTS
        Returns a PSScriptBuilderDependencyAnalysisResult containing comprehensive analysis results.
    .EXAMPLE
        $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($contentCollector)
        $result = $analyzer.Analyze()

        if ($result.HasCycles) {
            Write-Warning "Circular dependency: $($result.CyclePath -join ' -> ')"
        }
        elseif ($result.HasCrossDependencies) {
            Write-Host "Cross-dependencies detected - use {{ORDERED_COMPONENTS}} placeholder"
        }
    #>
    [PSScriptBuilderDependencyAnalysisResult] Analyze() {
        try {
            Write-Verbose "Starting dependency analysis..."

            # Step 1: Execute content collection
            $this.ExecuteContentCollection()

            # Step 2: Gather component statistics (result of collection)
            $aggregator = [PSScriptBuilderBuildDataAggregator]::new($this.ContentCollector)
            $componentCounts = $aggregator.GetComponentCounts()

            # Step 3: Build dependency graph
            $graph = $this.BuildDependencyGraph()

            # Step 4: Detect cycles
            $cycleDetector = [PSScriptBuilderCycleDetector]::new($graph)
            $hasCycles = $cycleDetector.HasCycle()

            # If cycles detected, return early with cycle information
            if ($hasCycles) {
                $cyclePath = $cycleDetector.GetCyclePath()

                return [PSScriptBuilderDependencyAnalysisResult]::new(
                    $true,                  # HasCycles
                    $cyclePath,             # CyclePath
                    $false,                 # HasCrossDependencies
                    @(),                    # OrderedComponents (empty - cannot sort with cycles)
                    $componentCounts,       # ComponentCounts
                    $graph.GetNodeCount(),  # TotalNodes
                    $graph.GetEdgeCount(),  # TotalEdges
                    $graph                  # DependencyGraph
                )
            }

            # Step 5: Sort topologically
            $orderedComponents = $this.SortTopologically($graph)

            # Step 6: Stabilize — enums always before classes and functions
            $orderedComponents = $this.StabilizeEnumsFirst($orderedComponents)

            # Step 7: Detect cross-dependencies
            $hasCrossDependencies = $this.DetectCrossDependencies($orderedComponents)

            Write-Verbose "Dependency analysis complete"

            return [PSScriptBuilderDependencyAnalysisResult]::new(
                $false,                 # HasCycles
                @(),                    # CyclePath (empty - no cycles)
                $hasCrossDependencies,  # HasCrossDependencies
                $orderedComponents,     # OrderedComponents
                $componentCounts,       # ComponentCounts
                $graph.GetNodeCount(),  # TotalNodes
                $graph.GetEdgeCount(),  # TotalEdges
                $graph                  # DependencyGraph
            )
        }
        catch {
            $format = "Dependency analysis failed. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Executes all registered content collectors.
    .DESCRIPTION
        Executes the ContentCollector to gather all components from source files.
        This triggers all registered collectors (Using, Enum, Class, Function, File)
        to process their respective source files.
    #>
    [void] ExecuteContentCollection() {
        $this.ContentCollector.Execute()
    }

    <#
    .SYNOPSIS
        Builds the dependency graph from collected components.
    .DESCRIPTION
        Creates a dependency graph using the DependencyGraphBuilder.
        The graph contains nodes for all components (enums, classes, functions) and
        edges representing dependencies between them.

        The graph is used for cycle detection, topological sorting, and cross-dependency analysis.
    .OUTPUTS
        Returns the constructed PSScriptBuilderDependencyGraph.
    #>
    [PSScriptBuilderDependencyGraph] BuildDependencyGraph() {
        $builder = [PSScriptBuilderDependencyGraphBuilder]::new($this.ContentCollector)
        return $builder.Build()
    }

    <#
    .SYNOPSIS
        Sorts components topologically based on dependencies.
    .DESCRIPTION
        Uses the TopologicalSorter to order components so that dependencies appear before dependents.
        This order is required for valid PowerShell scripts where definitions must precede usage.

        The sorting uses Kahn's algorithm to produce a valid topological ordering.
    .PARAMETER graph
        The dependency graph to sort. Cannot be null.
    .OUTPUTS
        Returns an array of component names in topological order.
    .EXAMPLE
        $orderedComponents = $analyzer.SortTopologically($graph)
        # Result: Dependencies appear before components that use them
    #>
    [string[]] SortTopologically([PSScriptBuilderDependencyGraph] $graph) {
        if ($null -eq $graph) {
            $message = "Parameter 'graph' cannot be null."
            throw [ArgumentNullException]::new("graph", $message)
        }

        $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)
        return $sorter.Sort()
    }

    <#
    .SYNOPSIS
        Detects if component types are intermixed (cross-dependencies).
    .DESCRIPTION
        Uses the CrossDependencyDetector to analyze the sorted component list and determine
        if Enum, Class, and Function components are intermixed in the dependency order.

        Cross-dependencies exist when component types are not cleanly separated, for example:
        - Enum -> Class -> Function -> Class (Function depends on Class, which depends on another Class)

        This information determines template processing mode:
        - Cross-dependencies detected: Must use {{ORDERED_COMPONENTS}} placeholder (strict mode)
        - No cross-dependencies: Can use individual collector placeholders (free mode)
    .PARAMETER sortedComponents
        Array of component names in topological order. Cannot be null.
    .OUTPUTS
        Returns true if cross-dependencies exist, false otherwise.
    .EXAMPLE
        $hasCrossDeps = $analyzer.DetectCrossDependencies($orderedComponents)
        if ($hasCrossDeps) {
            Write-Host "Use {{ORDERED_COMPONENTS}} placeholder in template"
        }
    #>
    [bool] DetectCrossDependencies([string[]] $orderedComponents) {
        if ($null -eq $orderedComponents) {
            $message = "Parameter 'orderedComponents' cannot be null."
            throw [ArgumentNullException]::new("orderedComponents", $message)
        }

        if ($orderedComponents.Count -eq 0) {
            return $false
        }

        $detector = [PSScriptBuilderCrossDependencyDetector]::new($this.ContentCollector)
        return $detector.HasCrossDependencies($orderedComponents)
    }

    <#
    .SYNOPSIS
        Stabilizes the topological order by ensuring enums appear before all other components.
    .DESCRIPTION
        The StabilizeEnumsFirst() method reorders the topologically sorted component array so that
        all enum definitions appear before classes and functions. This is valid because enums never
        have incoming dependencies and therefore their position within the zero-in-degree group
        is arbitrary. Placing them first matches PowerShell conventions and produces consistent,
        readable output scripts regardless of graph traversal order.

        The topological order of non-enum components is fully preserved.
    .PARAMETER orderedComponents
        Array of component names in topological order.
    .OUTPUTS
        Returns the reordered array with enum components first.
    #>
    hidden [string[]] StabilizeEnumsFirst([string[]] $orderedComponents) {
        $enumCollectors = $this.ContentCollector.GetEnumCollectors()

        if ($enumCollectors.Count -eq 0) {
            return $orderedComponents
        }

        $enumNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($collector in $enumCollectors) {
            foreach ($name in $collector.EnumData.Keys) {
                [void] $enumNames.Add($name)
            }
        }

        $enums    = [List[string]]::new()
        $nonEnums = [List[string]]::new()

        foreach ($component in $orderedComponents) {
            if ($enumNames.Contains($component)) {
                $enums.Add($component)
            }
            else {
                $nonEnums.Add($component)
            }
        }

        $enums.Sort([StringComparer]::OrdinalIgnoreCase)

        $result = [List[string]]::new()
        $result.AddRange($enums)
        $result.AddRange($nonEnums)

        Write-Verbose "  Stabilized: $($enums.Count) enum(s) output first"
        return $result.ToArray()
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderDependencyAnalyzer
