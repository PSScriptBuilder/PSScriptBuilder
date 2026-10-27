using namespace System

#region Class PSScriptBuilderComponentDependencyEntry
<#
.SYNOPSIS
    Represents a single component found during dependency graph traversal.
.DESCRIPTION
    The PSScriptBuilderComponentDependencyEntry class encapsulates information about a component
    discovered during a recursive traversal of the dependency graph, as performed by
    PSScriptBuilderDependencyGraphTraverser.

    Each entry describes one component reachable from the traversal root, including its
    distance from the root (Depth) and the full path from root to this component (DependencyPath).

    The root component itself is not included in the traversal results. Depth starts at 1
    for direct dependencies.
#>
class PSScriptBuilderComponentDependencyEntry {
    #region Properties
    <#
    .SYNOPSIS
        The name of the component.
    .DESCRIPTION
        The Name property holds the component name as it appears in the dependency graph.
    #>
    [string] $Name

    <#
    .SYNOPSIS
        The depth of this component relative to the traversal root.
    .DESCRIPTION
        The Depth property indicates how many steps away this component is from the traversal root.
        A value of 1 means a direct dependency or dependent. Higher values indicate transitive
        relationships.
    #>
    [int] $Depth

    <#
    .SYNOPSIS
        The full path from the traversal root to this component.
    .DESCRIPTION
        The DependencyPath property contains an ordered array of component names from the traversal
        root (at index 0) to this component (at the last index). This provides full context for
        understanding how a transitive dependency is reached.

        Example: for a chain ClassA -> ClassB -> ClassC, the entry for ClassC has
        DependencyPath = @('ClassA', 'ClassB', 'ClassC').
    #>
    [string[]] $DependencyPath
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderComponentDependencyEntry.
    .DESCRIPTION
        Creates a new entry with the specified name, depth, and dependency path.
    .PARAMETER name
        The name of the component.
    .PARAMETER depth
        The depth of this component relative to the traversal root.
    .PARAMETER dependencyPath
        The full path from the traversal root to this component.
    #>
    PSScriptBuilderComponentDependencyEntry([string] $name, [int] $depth, [string[]] $dependencyPath) {
        $this.Name           = $name
        $this.Depth          = $depth
        $this.DependencyPath = $dependencyPath
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderComponentDependencyEntry
