#region Class PSScriptBuilderEnumData
<#
.SYNOPSIS
    Represents collected enum data.
.DESCRIPTION
    The PSScriptBuilderEnumData class encapsulates data about a PowerShell enum definition
    including its name, source code, and source file location.
#>
class PSScriptBuilderEnumData {
    #region Properties
    <#
    .SYNOPSIS
        The name of the enum.
    .DESCRIPTION
        The Name property holds the enum name as defined in the source code.
    #>
    [string] $Name

    <#
    .SYNOPSIS
        The complete source code of the enum.
    .DESCRIPTION
        The SourceCode property contains the full enum definition including all values.
    #>
    [string] $SourceCode

    <#
    .SYNOPSIS
        The file path where the enum is defined.
    .DESCRIPTION
        The SourceFile property holds the absolute path to the file containing this enum definition.
    #>
    [string] $SourceFile
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderEnumData.
    .DESCRIPTION
        Creates a new PSScriptBuilderEnumData with the specified enum information.
    .PARAMETER name
        The name of the enum.
    .PARAMETER sourceCode
        The complete source code of the enum.
    .PARAMETER sourceFile
        The absolute path to the file containing this enum definition.
    #>
    PSScriptBuilderEnumData([string] $name, [string] $sourceCode, [string] $sourceFile) {
        $this.Name       = $name
        $this.SourceCode = $sourceCode
        $this.SourceFile = $sourceFile
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderEnumData
