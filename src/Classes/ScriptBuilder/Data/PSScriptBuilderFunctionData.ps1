#region Class PSScriptBuilderFunctionData
<#
.SYNOPSIS
    Represents collected function data with dependency information.
.DESCRIPTION
    The PSScriptBuilderFunctionData class encapsulates data about a PowerShell function definition
    including its name, source code, called functions, and type references.
#>
class PSScriptBuilderFunctionData {
    #region Properties
    <#
    .SYNOPSIS
        The name of the function.
    .DESCRIPTION
        The Name property holds the function name as defined in the source code.
    #>
    [string] $Name

    <#
    .SYNOPSIS
        The complete source code of the function.
    .DESCRIPTION
        The SourceCode property contains the full function definition including all code.
    #>
    [string] $SourceCode

    <#
    .SYNOPSIS
        The file path where the function is defined.
    .DESCRIPTION
        The SourceFile property holds the absolute path to the file containing this function definition.
    #>
    [string] $SourceFile

    <#
    .SYNOPSIS
        Array of function names called within this function.
    .DESCRIPTION
        The CalledFunctions property contains all function/command names that are called
        within this function. Used for dependency analysis.
    #>
    [string[]] $CalledFunctions

    <#
    .SYNOPSIS
        Array of type references used in the function.
    .DESCRIPTION
        The TypeReferences property contains all non-built-in types referenced in the function
        (parameters, return types, variables, etc.). Used for dependency analysis.
    #>
    [string[]] $TypeReferences
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderFunctionData.
    .DESCRIPTION
        Creates a new PSScriptBuilderFunctionData with the specified function information.
    .PARAMETER name
        The name of the function.
    .PARAMETER sourceCode
        The complete source code of the function.
    .PARAMETER sourceFile
        The absolute path to the file containing this function definition.
    .PARAMETER calledFunctions
        Array of function names called within this function.
    .PARAMETER typeReferences
        Array of type references used in the function.
    #>
    PSScriptBuilderFunctionData([string] $name, [string] $sourceCode, [string] $sourceFile, [string[]] $calledFunctions, [string[]] $typeReferences) {
        $this.Name            = $name
        $this.SourceCode      = $sourceCode
        $this.SourceFile      = $sourceFile
        $this.CalledFunctions = $calledFunctions
        $this.TypeReferences  = $typeReferences
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderFunctionData
