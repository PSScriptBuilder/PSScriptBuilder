#region Cmdlet Get-PSScriptBuilderComponentDependency
function Get-PSScriptBuilderComponentDependency {
    <#
    .SYNOPSIS
        Retrieves all dependencies or dependents of a named component from the dependency graph.
    .DESCRIPTION
        The Get-PSScriptBuilderComponentDependency cmdlet performs a breadth-first traversal of the
        dependency graph starting from the specified component name. It returns all reachable components
        in the specified direction as PSScriptBuilderComponentDependencyEntry objects.

        Each entry contains the component name, its depth relative to the starting component, and the
        full dependency path from the root to that component.

        The cmdlet accepts ValueFromPipelineByPropertyName, enabling direct piping from
        Get-PSScriptBuilderDependencyAnalysis, which returns an object with a DependencyGraph property.

        When -EdgeType is specified, only edges of that type are followed during BFS traversal.
        This enables focused analysis such as inheritance-only hierarchies. When omitted, all
        edge types are traversed.
    .PARAMETER DependencyGraph
        The dependency graph to traverse. Accepts pipeline input by property name, enabling
        direct piping from Get-PSScriptBuilderDependencyAnalysis.
    .PARAMETER Name
        The name of the component to start the traversal from. Must exist in the dependency graph.
    .PARAMETER Direction
        The traversal direction. Use Dependencies (default) to find all components the named
        component depends on, or Dependents to find all components that depend on it.
    .PARAMETER EdgeType
        Optional. Restricts BFS traversal to edges of the specified type(s) only. When omitted,
        all edge types (Inheritance, TypeReference, FunctionCall, StaticInitializer) are traversed.
        When multiple types are specified, their results are combined (union).

        Use EdgeType Inheritance to build a pure inheritance hierarchy - ancestors when combined
        with Dependencies, subclasses when combined with -Direction Dependents.
    .OUTPUTS
        PSScriptBuilderComponentDependencyEntry
    .EXAMPLE
        $analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
        $analysis | Get-PSScriptBuilderComponentDependency -Name 'ClassA'

        Returns all components that ClassA directly or transitively depends on.
    .EXAMPLE
        $analysis | Get-PSScriptBuilderComponentDependency -Name 'BaseClass' -Direction Dependents

        Returns all components that directly or transitively depend on BaseClass.
        Useful for impact analysis before modifying a shared base class.
    .EXAMPLE
        $analysis = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath ".\src\Classes" |
            Get-PSScriptBuilderDependencyAnalysis

        $analysis | Get-PSScriptBuilderComponentDependency -Name 'MyService' |
            ConvertTo-PSScriptBuilderComponentDependencyTree

        Fluent pipeline: analyzes dependencies and renders the result as a tree.
    .EXAMPLE
        $analysis.DependencyGraph.Dependencies.Keys | ForEach-Object {
            $deps = $analysis | Get-PSScriptBuilderComponentDependency -Name $_
            [PSCustomObject]@{ Name = $_; Count = $deps.Count }
        } | Sort-Object Count -Descending | Select-Object -First 5

        Identifies the five components with the most transitive dependencies.
        A high count may indicate a God-Class that accumulates too many responsibilities.
    .EXAMPLE
        $analysis | Get-PSScriptBuilderComponentDependency -Name 'ValidatorBase' -Direction Dependents -EdgeType Inheritance |
            ConvertTo-PSScriptBuilderComponentDependencyTree

        Renders the full inheritance hierarchy of ValidatorBase as a tree.
        Only subclasses are included - components that merely reference ValidatorBase as a type are excluded.
    .NOTES
        Traversal uses breadth-first search (BFS). A visited HashSet prevents infinite traversal
        through TypeReference cycles, which are valid in PowerShell 5.1.

        The named component itself is not included in the results. Depth starts at 1 for direct
        neighbours.

        The component name lookup is case-insensitive, matching PowerShell's type system behavior.

        Traversal covers all dependency edge types: Inheritance, TypeReference, FunctionCall, and
        StaticInitializer. This means a component appears in the results if it is related through
        any of these relationships - not only through inheritance. Use -EdgeType to restrict
        traversal to one or more specific relationship types.

        Using -Direction Dependents is the PowerShell equivalent of "Find All References" in an IDE:
        it reveals every component that would be affected by a change to the named component.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderComponentDependencyEntry])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [PSScriptBuilderDependencyGraph] $DependencyGraph,

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter()]
        [PSScriptBuilderTraversalDirection] $Direction = [PSScriptBuilderTraversalDirection]::Dependencies,

        [Parameter()]
        [PSScriptBuilderDependencyEdgeType[]] $EdgeType
    )

    process {
        try {
            $traverser = [PSScriptBuilderDependencyGraphTraverser]::new($DependencyGraph)

            if ($PSBoundParameters.ContainsKey('EdgeType')) {
                return $traverser.Traverse($Name, $Direction, $EdgeType)
            }

            return $traverser.Traverse($Name, $Direction)
        }
        catch {
            $format  = "Failed to retrieve component dependencies. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [Exception]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderComponentDependency
