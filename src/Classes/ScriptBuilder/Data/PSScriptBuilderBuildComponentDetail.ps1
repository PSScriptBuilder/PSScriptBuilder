#region Class PSScriptBuilderBuildComponentDetail
<#
.SYNOPSIS
    Represents detailed information about a build component.
.DESCRIPTION
    The PSScriptBuilderBuildComponentDetail class encapsulates detailed information about a single component
    (enum, class, or function) collected during the build process, including its type, name, source file,
    and dependencies.
#>
class PSScriptBuilderBuildComponentDetail {
    #region Properties
    <#
    .SYNOPSIS
        The collector type that identifies the component's kind.
    .DESCRIPTION
        The Type property holds the PSScriptBuilderCollectorType value that identifies what kind
        of component this is (Enum, Class, Function, File, or Using). The value uses the
        collector type enum; use [PSScriptBuilderTextHelper]::FormatCollectorType() to obtain a
        clean display name (e.g., "Class" instead of "ClassCollector").
    #>
    [PSScriptBuilderCollectorType] $Type

    <#
    .SYNOPSIS
        The name of the component.
    .DESCRIPTION
        The Name property holds the component name as defined in the source code (enum name, class name, or function name).
    #>
    [string] $Name

    <#
    .SYNOPSIS
        The file path where the component is defined.
    .DESCRIPTION
        The SourceFile property holds the absolute path to the file containing this component definition.
    #>
    [string] $SourceFile

    <#
    .SYNOPSIS
        Array of component dependencies.
    .DESCRIPTION
        The Dependencies property contains the names of other components that this component depends on.
        For classes: base class and type references. For functions: called functions and type references.
        For enums: empty array (no dependencies).
    #>
    [string[]] $Dependencies
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderBuildComponentDetail.
    .DESCRIPTION
        Creates a new PSScriptBuilderBuildComponentDetail with the specified component information.
    .PARAMETER type
        The collector type this component belongs to.
    .PARAMETER name
        The name of the component.
    .PARAMETER sourceFile
        The absolute path to the file containing this component definition.
    .PARAMETER dependencies
        Array of component names that this component depends on.
    #>
    PSScriptBuilderBuildComponentDetail(
        [PSScriptBuilderCollectorType] $type,
        [string]                       $name,
        [string]                       $sourceFile,
        [string[]]                     $dependencies
    ) {
        $this.Type         = $type
        $this.Name         = $name
        $this.SourceFile   = $sourceFile
        $this.Dependencies = $dependencies
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderBuildComponentDetail
