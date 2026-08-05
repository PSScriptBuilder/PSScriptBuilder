#region Cmdlet Get-PSScriptBuilderDependencyAnalysis
function Get-PSScriptBuilderDependencyAnalysis {
    <#
    .SYNOPSIS
        Analyzes dependencies between components without performing a build.
    .DESCRIPTION
        The Get-PSScriptBuilderDependencyAnalysis cmdlet performs comprehensive dependency analysis on the
        components registered in a ContentCollector. It delegates all analysis logic to PSScriptBuilderDependencyAnalyzer
        and returns a strongly-typed PSScriptBuilderDependencyAnalysisResult object.

        The analysis includes:
        - Executing all collectors to gather components
        - Building a dependency graph
        - Detecting circular dependencies
        - Performing topological sorting (if no cycles)
        - Identifying cross-dependencies between component types
        - Gathering component statistics

        This cmdlet is useful for:
        - Validating dependencies before building
        - Understanding component relationships
        - Detecting potential circular dependencies early
        - Analyzing the dependency structure of your codebase
        - Planning refactoring with impact analysis
    .PARAMETER ContentCollector
        The ContentCollector instance containing all registered component collectors. Accepts pipeline
        input to enable fluent chaining from Add-PSScriptBuilderCollector.
    .OUTPUTS
        PSScriptBuilderDependencyAnalysisResult
    .EXAMPLE
        $analysis = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath "src" |
            Get-PSScriptBuilderDependencyAnalysis
        Write-Host "Total components: $($analysis.TotalComponents)"
        Write-Host "Classes: $($analysis.ComponentCounts.ClassDefinitions)"
        Write-Host "Cross-dependencies: $($analysis.HasCrossDependencies)"

        Fluent pipeline analysis with component statistics.
    .EXAMPLE
        $analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
        # Impact analysis: Which components would be affected by changing "BaseClass"?
        $dependents = $analysis.DependencyGraph.GetDependents("BaseClass")
        Write-Warning "Changing BaseClass affects $($dependents.Count) components:"
        $dependents | ForEach-Object { Write-Host "  - $_" }

        Advanced analysis with impact assessment using the dependency graph.
    .NOTES
        This cmdlet delegates all analysis to PSScriptBuilderDependencyAnalyzer, which executes all registered
        collectors via ContentCollector.Execute(). For large codebases, this may take some time.

        If an Inheritance or StaticInitializer cycle is detected, the OrderedComponents array will be empty and the build will fail.
        Inheritance and StaticInitializer cycles must be resolved in the source code before building.
        Type reference cycles (classes referencing each other in method bodies or property type annotations)
        are resolved automatically and do not affect HasCycles.

        Cross-dependencies occur when component types are intermixed in the sorted order (e.g., a class
        depends on a function that depends on another class). While not necessarily an error, this may
        indicate architectural issues.

        The result is a strongly-typed PSScriptBuilderDependencyAnalysisResult object that provides
        IntelliSense support and can be used with future format cmdlets.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderDependencyAnalysisResult])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderContentCollector] $ContentCollector
    )

    process {
        try {
            # Execute content collection
            $ContentCollector.Execute()

            # Use DependencyAnalyzer for analysis
            $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($ContentCollector)
            $result = $analyzer.Analyze()

            return $result
        }
        catch {
            $format = "Dependency analysis failed. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderDependencyAnalysis
