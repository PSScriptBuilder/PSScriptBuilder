using namespace System

#region Class PSScriptBuilderUnusedComponentEntry
<#
.SYNOPSIS
    Represents a single unused component found during unused component analysis.
.DESCRIPTION
    The PSScriptBuilderUnusedComponentEntry class encapsulates information about a component
    that was identified as unused during analysis. It includes the component name, its type
    (Enum, Class, or Function), the collection key of the collector that provided it, and
    the source file path where it is defined.

    This class is returned by Find-PSScriptBuilderUnusedComponent and provides strongly-typed
    output suitable for pipeline processing and filtering.
#>
class PSScriptBuilderUnusedComponentEntry {
    #region Properties
    <#
    .SYNOPSIS
        The name of the unused component.
    .DESCRIPTION
        The Name property holds the identifier of the component (enum name, class name, or function name)
        that was identified as unused.
    #>
    [string] $Name

    <#
    .SYNOPSIS
        The type of the unused component.
    .DESCRIPTION
        The ComponentType property indicates whether the component is an Enum, Class, or Function,
        as defined by PSScriptBuilderUnusedComponentType.
    #>
    [PSScriptBuilderUnusedComponentType] $ComponentType

    <#
    .SYNOPSIS
        The collection key of the collector that provided this component.
    .DESCRIPTION
        The CollectionKey property identifies which collector registered this component. This is
        useful for locating the collector configuration responsible for the unused component.
    #>
    [string] $CollectionKey

    <#
    .SYNOPSIS
        The full path to the source file defining this component.
    .DESCRIPTION
        The SourceFile property contains the absolute path to the PowerShell file in which the
        component is defined.
    #>
    [string] $SourceFile
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderUnusedComponentEntry.
    .DESCRIPTION
        Creates a new PSScriptBuilderUnusedComponentEntry with the specified component details.
    .PARAMETER name
        The name of the unused component.
    .PARAMETER componentType
        The type of the component (Enum, Class, or Function).
    .PARAMETER collectionKey
        The collection key of the collector that registered the component.
    .PARAMETER sourceFile
        The full path to the source file where the component is defined.
    #>
    PSScriptBuilderUnusedComponentEntry(
        [string]                             $name,
        [PSScriptBuilderUnusedComponentType] $componentType,
        [string]                             $collectionKey,
        [string]                             $sourceFile
    ) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            $message = "Name cannot be null or empty."
            throw [ArgumentException]::new($message, "name")
        }
       
        if ([string]::IsNullOrWhiteSpace($collectionKey)) {
            $message = "CollectionKey cannot be null or empty."
            throw [ArgumentException]::new($message, "collectionKey")
        }

        $this.Name          = $name
        $this.ComponentType = $componentType
        $this.CollectionKey = $collectionKey
        $this.SourceFile    = $sourceFile
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderUnusedComponentEntry
