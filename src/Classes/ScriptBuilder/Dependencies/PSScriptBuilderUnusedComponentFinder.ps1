using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderUnusedComponentFinder
<#
.SYNOPSIS
    Finds unused components in a PSScriptBuilder project.
.DESCRIPTION
    The PSScriptBuilderUnusedComponentFinder class analyzes the dependency graph of a content
    collector configuration to identify components that are not referenced by any other component.

    Two analysis modes are supported:

    - Without entry points: Reports all Enum, Class, and Function components that have no
      incoming dependency edges. Components that nothing else depends on are considered unused.
      Note that public cmdlets always appear in this mode since they are called from outside
      the graph.

    - With entry points: Performs a reachability analysis starting from components matching
      the specified glob patterns. All components not reachable (directly or transitively)
      from any entry point are considered unused.

    This class is the backing implementation for Find-PSScriptBuilderUnusedComponent.
#>
class PSScriptBuilderUnusedComponentFinder {
    #region Properties
    <#
    .SYNOPSIS
        The ContentCollector providing the component configuration.
    .DESCRIPTION
        The ContentCollector property holds the PSScriptBuilderContentCollector instance whose
        registered collectors are used as the source for component discovery and analysis.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderUnusedComponentFinder.
    .DESCRIPTION
        Creates a new PSScriptBuilderUnusedComponentFinder with the specified ContentCollector.
    .PARAMETER contentCollector
        The ContentCollector instance containing all registered component collectors. Cannot be null.
    #>
    PSScriptBuilderUnusedComponentFinder([PSScriptBuilderContentCollector] $contentCollector) {
        if ($null -eq $contentCollector) {
            $message = "ContentCollector cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        $this.ContentCollector = $contentCollector
    }
    #endregion Constructors

    #region Public Methods
    <#
    .SYNOPSIS
        Finds components with no incoming dependencies.
    .DESCRIPTION
        Analyzes the dependency graph and returns all Enum, Class, and Function components that
        have no incoming dependency edges - i.e., no other component depends on them.

        Note: Public cmdlets (functions) typically have no incoming edges within the graph since
        they are invoked externally. Use Find([string[]]) with -EntryPoint patterns to exclude
        them from results.
    .OUTPUTS
        Returns an array of PSScriptBuilderUnusedComponentEntry objects for components with no incoming dependencies.
    #>
    [PSScriptBuilderUnusedComponentEntry[]] Find() {
        Write-Verbose "Starting unused component analysis (mode: no entry points)..."

        $analysisResult = $this.RunAnalysis()
        $this.EmitCycleWarning($analysisResult)

        $lookup = $this.BuildComponentLookup()
        $graph  = $analysisResult.DependencyGraph

        Write-Verbose "  Component lookup: $($lookup.Count) component(s)"

        $result = [List[PSScriptBuilderUnusedComponentEntry]]::new()

        foreach ($name in $lookup.Keys) {
            $dependents = $graph.GetDependents($name)

            if ($dependents.Count -eq 0) {
                $result.Add($lookup[$name])
            }
        }

        Write-Verbose "  Found: $($result.Count) unused component(s)"
        Write-Verbose "Unused component analysis complete"

        return $result.ToArray()
    }

    <#
    .SYNOPSIS
        Finds components not reachable from the specified entry points.
    .DESCRIPTION
        Performs a reachability analysis starting from all components whose names match any of
        the specified glob patterns. All components not reachable (directly or transitively via
        dependency edges) from the matched entry points are returned as unused.

        Glob patterns support wildcards: * matches any sequence of characters, ? matches a single
        character. Patterns are matched case-insensitively against component names.
    .PARAMETER entryPoints
        An array of glob patterns identifying the entry point components. Cannot be null or empty.
    .OUTPUTS
        Returns an array of PSScriptBuilderUnusedComponentEntry objects for components not reachable from the entry points.
    #>
    [PSScriptBuilderUnusedComponentEntry[]] Find([string[]] $entryPoints) {
        if ($null -eq $entryPoints -or $entryPoints.Count -eq 0) {
            $message = "EntryPoints cannot be null or empty."
            throw [ArgumentException]::new($message, "entryPoints")
        }

        Write-Verbose "Starting unused component analysis (mode: entry points)..."
        Write-Verbose "  Entry point pattern(s): $($entryPoints -join ', ')"

        $analysisResult = $this.RunAnalysis()
        $this.EmitCycleWarning($analysisResult)

        $lookup    = $this.BuildComponentLookup()
        $graph     = $analysisResult.DependencyGraph
        $reachable = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $queue     = [Queue[string]]::new()

        Write-Verbose "  Component lookup: $($lookup.Count) component(s)"

        # Seed the BFS queue with components matching any entry point pattern
        foreach ($name in $lookup.Keys) {
            foreach ($pattern in $entryPoints) {
                if ($name -like $pattern) {
                    if ($reachable.Add($name)) {
                        $queue.Enqueue($name)
                    }

                    break
                }
            }
        }

        Write-Verbose "  Matched entry point(s): $($reachable.Count)"

        # BFS: follow outgoing dependency edges to find all transitively reachable components
        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            $targets = $graph.GetDependencies($current)

            foreach ($target in $targets) {
                if ($reachable.Add($target)) {
                    $queue.Enqueue($target)
                }
            }
        }

        # Return components not reached from any entry point
        $result = [List[PSScriptBuilderUnusedComponentEntry]]::new()

        foreach ($name in $lookup.Keys) {
            if (-not $reachable.Contains($name)) {
                $result.Add($lookup[$name])
            }
        }

        Write-Verbose "  Found: $($result.Count) unused component(s)"
        Write-Verbose "Unused component analysis complete"

        return $result.ToArray()
    }
    #endregion Public Methods

    #region Private Methods
    <#
    .SYNOPSIS
        Runs the dependency analyzer and returns the analysis result.
    .DESCRIPTION
        Creates a new PSScriptBuilderDependencyAnalyzer for the current ContentCollector,
        executes the full analysis pipeline, and returns the resulting
        PSScriptBuilderDependencyAnalysisResult.
    .OUTPUTS
        Returns the PSScriptBuilderDependencyAnalysisResult from the full analysis pipeline.
    #>
    hidden [PSScriptBuilderDependencyAnalysisResult] RunAnalysis() {
        $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($this.ContentCollector)
        return $analyzer.Analyze()
    }

    <#
    .SYNOPSIS
        Emits warnings if cycles were detected in the dependency graph.
    .DESCRIPTION
        Checks the HasCycles property of the analysis result and emits a Write-Warning
        message when cycles are present. The cycle path is included in a second warning
        to help the user identify the affected components.
    .PARAMETER result
        The PSScriptBuilderDependencyAnalysisResult to check for cycles.
    #>
    hidden [void] EmitCycleWarning([PSScriptBuilderDependencyAnalysisResult] $result) {
        if ($result.HasCycles) {
            Write-Warning "Dependency cycles detected. Components in cycles may not be reported as unused."
            $cyclePath = $result.CyclePath -join " -> "
            Write-Warning "  Cycle: $cyclePath"
        }
    }

    <#
    .SYNOPSIS
        Builds a lookup of component name to PSScriptBuilderUnusedComponentEntry.
    .DESCRIPTION
        Iterates through all Enum, Class, and Function collectors registered in the
        ContentCollector to build a case-insensitive hashtable mapping each component
        name to a pre-constructed PSScriptBuilderUnusedComponentEntry. The lookup is
        used by Find() and Find([string[]]) to resolve graph nodes to entry objects.
    .OUTPUTS
        Returns a hashtable mapping component names to PSScriptBuilderUnusedComponentEntry objects.
    #>
    hidden [hashtable] BuildComponentLookup() {
        $lookup = @{}

        foreach ($collector in $this.ContentCollector.GetEnumCollectors()) {
            foreach ($entry in $collector.EnumData.GetEnumerator()) {
                $lookup[$entry.Key] = [PSScriptBuilderUnusedComponentEntry]::new(
                    $entry.Key,
                    [PSScriptBuilderUnusedComponentType]::Enum,
                    $collector.CollectionKey,
                    $entry.Value.SourceFile
                )
            }
        }

        foreach ($collector in $this.ContentCollector.GetClassCollectors()) {
            foreach ($entry in $collector.ClassData.GetEnumerator()) {
                $lookup[$entry.Key] = [PSScriptBuilderUnusedComponentEntry]::new(
                    $entry.Key,
                    [PSScriptBuilderUnusedComponentType]::Class,
                    $collector.CollectionKey,
                    $entry.Value.SourceFile
                )
            }
        }

        foreach ($collector in $this.ContentCollector.GetFunctionCollectors()) {
            foreach ($entry in $collector.FunctionData.GetEnumerator()) {
                $lookup[$entry.Key] = [PSScriptBuilderUnusedComponentEntry]::new(
                    $entry.Key,
                    [PSScriptBuilderUnusedComponentType]::Function,
                    $collector.CollectionKey,
                    $entry.Value.SourceFile
                )
            }
        }

        return $lookup
    }
    #endregion Private Methods
}
#endregion Class PSScriptBuilderUnusedComponentFinder
