#region Class PSScriptBuilderDependencyEdge
<#
.SYNOPSIS
    Represents a single typed dependency edge in the PSScriptBuilder dependency graph.
.DESCRIPTION
    The PSScriptBuilderDependencyEdge class encapsulates a directed dependency from one component
    to another, along with the type of relationship that created the dependency.
    Edge types are defined by PSScriptBuilderDependencyEdgeType.
#>
class PSScriptBuilderDependencyEdge {
    #region Properties
    <#
    .SYNOPSIS
        The name of the component being depended on.
    .DESCRIPTION
        The Target property holds the name of the component (class or function) that the source
        component depends on.
    #>
    [string] $Target

    <#
    .SYNOPSIS
        The type of dependency relationship.
    .DESCRIPTION
        The EdgeType property classifies how the source component depends on the target component.
        See PSScriptBuilderDependencyEdgeType for the available values.
    #>
    [PSScriptBuilderDependencyEdgeType] $EdgeType
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderDependencyEdge.
    .DESCRIPTION
        Creates a new PSScriptBuilderDependencyEdge with the specified target component name
        and dependency edge type.
    .PARAMETER target
        The name of the component being depended on. Cannot be null or empty.
    .PARAMETER edgeType
        The type of dependency relationship.
    #>
    PSScriptBuilderDependencyEdge([string] $target, [PSScriptBuilderDependencyEdgeType] $edgeType) {
        if ([string]::IsNullOrWhiteSpace($target)) {
            $message = "Target cannot be null or empty."
            throw [ArgumentException]::new($message, "target")
        }

        $this.Target   = $target
        $this.EdgeType = $edgeType
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderDependencyEdge
