#region Class PSScriptBuilderSourceLocation
<#
.SYNOPSIS
    Represents the resolved source location of a component in the output script.
.DESCRIPTION
    The PSScriptBuilderSourceLocation class maps a line position in a built output script
    back to the corresponding location in the original source file. Returned by
    Resolve-PSScriptBuilderSourceLocation.
#>
class PSScriptBuilderSourceLocation {
    #region Properties
    <#
    .SYNOPSIS
        The name of the component.
    .DESCRIPTION
        The ComponentName property holds the name of the enum, class, function, or file
        that contains the resolved line.
    #>
    [string] $ComponentName

    <#
    .SYNOPSIS
        The type of the component.
    .DESCRIPTION
        The ComponentType property holds the component type as a string: Enum, Class,
        Function, or File.
    #>
    [string] $ComponentType

    <#
    .SYNOPSIS
        The absolute path to the source file.
    .DESCRIPTION
        The SourceFile property holds the absolute path to the original source file
        containing this component.
    #>
    [string] $SourceFile

    <#
    .SYNOPSIS
        The resolved line number in the source file.
    .DESCRIPTION
        The SourceLineNumber property holds the exact 1-based line number in the source
        file that corresponds to the target output line. This is the primary navigation
        target: open SourceFile and go to this line.
        Equals ComponentLineNumber + LineOffset.
    #>
    [int] $SourceLineNumber

    <#
    .SYNOPSIS
        The first line of the component in the source file.
    .DESCRIPTION
        The ComponentLineNumber property holds the 1-based line number where this
        component begins in the source file. Always 1 for File components.
    #>
    [int] $ComponentLineNumber

    <#
    .SYNOPSIS
        The first line of the component in the output script.
    .DESCRIPTION
        The OutputLineNumber property holds the 1-based line number where this component
        begins in the built output script.
    #>
    [int] $OutputLineNumber

    <#
    .SYNOPSIS
        The offset from the component start to the resolved line.
    .DESCRIPTION
        The Offset property holds the number of lines between the component start and
        the target line. Zero for full source map entries.
        Equals SourceLineNumber - ComponentLineNumber.
    #>
    [int] $Offset
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderSourceLocation.
    .PARAMETER componentName
        The name of the component.
    .PARAMETER componentType
        The type string: Enum, Class, Function, or File.
    .PARAMETER sourceFile
        The absolute path to the source file.
    .PARAMETER sourceLineNumber
        The resolved 1-based line number in the source file.
    .PARAMETER componentLineNumber
        The 1-based line number where the component begins in the source file.
    .PARAMETER outputLineNumber
        The 1-based line number where the component begins in the output script.
    .PARAMETER offset
        The number of lines between the component start and the target line.
    #>
    PSScriptBuilderSourceLocation(
        [string] $componentName,
        [string] $componentType,
        [string] $sourceFile,
        [int]    $sourceLineNumber,
        [int]    $componentLineNumber,
        [int]    $outputLineNumber,
        [int]    $offset
    ) {
        $this.ComponentName       = $componentName
        $this.ComponentType       = $componentType
        $this.SourceFile          = $sourceFile
        $this.SourceLineNumber    = $sourceLineNumber
        $this.ComponentLineNumber = $componentLineNumber
        $this.OutputLineNumber    = $outputLineNumber
        $this.Offset              = $offset
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderSourceLocation
