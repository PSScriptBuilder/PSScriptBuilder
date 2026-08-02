#region Cmdlet Find-PSScriptBuilderUnusedComponent
Function Find-PSScriptBuilderUnusedComponent {
    <#
    .SYNOPSIS
        Finds unused components in a PSScriptBuilder content collector configuration.
    .DESCRIPTION
        The Find-PSScriptBuilderUnusedComponent cmdlet analyzes the dependency graph of the
        provided ContentCollector to identify Enum, Class, and Function components that are
        not referenced by any other component.

        Two analysis modes are available:

        Without -EntryPoint: Reports all components that have no incoming dependency edges.
        A component is considered unused when nothing else in the graph depends on it.
        Because public cmdlets are called externally (not from within the graph), they will
        always appear in results in this mode.

        With -EntryPoint: Performs a transitive reachability analysis starting from all
        components whose names match any of the specified glob patterns. Components not
        reachable (directly or transitively) from any matched entry point are returned
        as unused. Use this mode to identify dead code relative to a known set of
        public API functions.

        If dependency cycles are detected, a warning is emitted and components involved
        in the cycle may not be reported as unused (they reference each other, giving
        each an incoming edge).
    .PARAMETER ContentCollector
        The ContentCollector instance containing all registered component collectors. Accepts
        pipeline input to enable fluent chaining from Add-PSScriptBuilderCollector.
    .PARAMETER EntryPoint
        One or more glob patterns identifying the entry point components. When specified, only
        components not reachable from the matched entry points are reported as unused.
        Wildcards (* and ?) are supported. Patterns are matched case-insensitively.
    .OUTPUTS
        PSScriptBuilderUnusedComponentEntry
    .EXAMPLE
        $results = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src/Enums"   |
            Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Public"  |
            Find-PSScriptBuilderUnusedComponent -EntryPoint "*-MyModule*"

        Finds all components not reachable from public cmdlets matching the "*-MyModule*" pattern.
    .EXAMPLE
        $results = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Functions" |
            Find-PSScriptBuilderUnusedComponent

        Finds all components with no incoming dependencies. Useful for class-only projects
        without public cmdlets.
    .NOTES
        Public cmdlets collected by FunctionCollectors will always appear as unused when
        -EntryPoint is omitted, because they have no callers within the dependency graph.
        Use -EntryPoint with a wildcard pattern matching your cmdlet names to exclude them.

        Components involved in dependency cycles may not be reported as unused even if they
        are not reachable from any entry point, because they reference each other.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderUnusedComponentEntry])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter()]
        [string[]] $EntryPoint
    )

    process {
        try {
            $hasEntryPoint = $PSBoundParameters.ContainsKey('EntryPoint')

            if (-not $hasEntryPoint) {
                Write-Warning "No -EntryPoint specified. Components with no incoming dependencies will be reported as unused."
                Write-Warning "Public cmdlets will always appear in results when -EntryPoint is omitted."
            }

            # Execute content collection
            $ContentCollector.Execute()

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($ContentCollector)

            if ($hasEntryPoint) {
                $result = $finder.Find($EntryPoint)
            }
            else {
                $result = $finder.Find()
            }

            return $result
        }
        catch {
            $format = "Failed to find unused components. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Find-PSScriptBuilderUnusedComponent
