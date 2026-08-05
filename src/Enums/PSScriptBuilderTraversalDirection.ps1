#region Enum PSScriptBuilderTraversalDirection
<#
.SYNOPSIS
    Defines the traversal direction for dependency graph traversal.
.DESCRIPTION
    The PSScriptBuilderTraversalDirection enumeration defines the two directions in which
    the dependency graph can be traversed by PSScriptBuilderDependencyGraphTraverser:
    - Dependencies: follows outgoing edges - finds all components the named component depends on
    - Dependents:   follows incoming edges - finds all components that depend on the named component
#>
enum PSScriptBuilderTraversalDirection {
    <#
    .SYNOPSIS
        Traverse outgoing edges.
    .DESCRIPTION
        Finds all components that the named component directly or transitively depends on.
    #>
    Dependencies = 0

    <#
    .SYNOPSIS
        Traverse incoming edges.
    .DESCRIPTION
        Finds all components that directly or transitively depend on the named component.
    #>
    Dependents = 1
}
#endregion Enum PSScriptBuilderTraversalDirection
