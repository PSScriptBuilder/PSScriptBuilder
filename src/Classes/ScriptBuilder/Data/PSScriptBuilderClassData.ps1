#region Class PSScriptBuilderClassData
<#
.SYNOPSIS
    Represents collected class data with dependency information.
.DESCRIPTION
    The PSScriptBuilderClassData class encapsulates data about a PowerShell class definition
    including its name, source code, base class, and type references.
#>
class PSScriptBuilderClassData {
    #region Properties
    <#
    .SYNOPSIS
        The name of the class.
    .DESCRIPTION
        The Name property holds the class name as defined in the source code.
    #>
    [string] $Name

    <#
    .SYNOPSIS
        The complete source code of the class.
    .DESCRIPTION
        The SourceCode property contains the full class definition including all members.
    #>
    [string] $SourceCode

    <#
    .SYNOPSIS
        The file path where the class is defined.
    .DESCRIPTION
        The SourceFile property holds the absolute path to the file containing this class definition.
    #>
    [string] $SourceFile

    <#
    .SYNOPSIS
        The base class name, if any.
    .DESCRIPTION
        The BaseClass property holds the name of the base class this class inherits from.
        Is null if the class does not inherit from another class.
    #>
    [string] $BaseClass

    <#
    .SYNOPSIS
        Array of type references used in the class.
    .DESCRIPTION
        The TypeReferences property contains all non-built-in types referenced in the class
        (method bodies, property type annotations, etc.). Used for dependency analysis.
        Does not include types that appear exclusively in static property initializer expressions
        (those are in StaticInitializerReferences).
    #>
    [string[]] $TypeReferences

    <#
    .SYNOPSIS
        Array of type references used in static property initializer expressions.
    .DESCRIPTION
        The StaticInitializerReferences property contains all non-built-in types referenced in the
        initializer expressions of static properties (e.g. 'static [B] $x = [B]::new()').
        These represent load-time ordering constraints equivalent to inheritance: the referenced
        type must be defined before this class in the output script.
    #>
    [string[]] $StaticInitializerReferences

    <#
    .SYNOPSIS
        Array of function/command names called in the class body.
    .DESCRIPTION
        The CalledFunctions property contains all function and command names invoked within the class
        (method bodies and static property initializers). Used for dependency analysis to
        detect when a class depends on a project-defined function at load time.
    #>
    [string[]] $CalledFunctions
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderClassData.
    .DESCRIPTION
        Creates a new PSScriptBuilderClassData with the specified class information.
    .PARAMETER name
        The name of the class.
    .PARAMETER sourceCode
        The complete source code of the class.
    .PARAMETER sourceFile
        The absolute path to the file containing this class definition.
    .PARAMETER baseClass
        The base class name, or null if no inheritance.
    .PARAMETER typeReferences
        Array of type references used in the class (method bodies, property type annotations).
        Does not include types appearing exclusively in static property initializer expressions.
    .PARAMETER staticInitializerReferences
        Array of type references appearing in static property initializer expressions.
        These represent load-time ordering constraints equivalent to inheritance.
    .PARAMETER calledFunctions
        Array of function/command names called within the class.
    #>
    PSScriptBuilderClassData(
        [string]   $name, 
        [string]   $sourceCode, 
        [string]   $sourceFile, 
        [string]   $baseClass, 
        [string[]] $typeReferences,
        [string[]] $staticInitializerReferences,
        [string[]] $calledFunctions
    ) {
        $this.Name                          = $name
        $this.SourceCode                    = $sourceCode
        $this.SourceFile                    = $sourceFile
        $this.BaseClass                     = $baseClass
        $this.TypeReferences                = $typeReferences
        $this.StaticInitializerReferences   = $staticInitializerReferences
        $this.CalledFunctions               = $calledFunctions
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderClassData
