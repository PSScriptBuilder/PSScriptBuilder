#region Enum PSScriptBuilderDependencyEdgeType
<#
.SYNOPSIS
    Defines the types of dependency edges in the PSScriptBuilder dependency graph.
.DESCRIPTION
    The PSScriptBuilderDependencyEdgeType enum classifies how one component depends on another.
    The edge type determines whether a cycle between two components is fatal at PowerShell 5.1 load time.
#>
enum PSScriptBuilderDependencyEdgeType {
    <#
    .SYNOPSIS
        Inheritance dependency.
    .DESCRIPTION
        Represents a base class relationship: the source class inherits from the target class.
        Inheritance cycles are fatal in PowerShell 5.1 and cause a load-time error.
    #>
    Inheritance = 0

    <#
    .SYNOPSIS
        Type reference dependency.
    .DESCRIPTION
        Represents a type usage in a method body or property type annotation.
        Type reference cycles are not fatal in PowerShell 5.1 because all classes in a .psm1 file
        are parsed together before any method body is executed.
    #>
    TypeReference = 1

    <#
    .SYNOPSIS
        Function call dependency.
    .DESCRIPTION
        Represents a call to a standalone function defined elsewhere in the project.
        Function call cycles are not fatal in PowerShell 5.1.
    #>
    FunctionCall = 2

    <#
    .SYNOPSIS
        Static property initializer dependency.
    .DESCRIPTION
        Represents a type usage in a static property initializer expression.
        Static property initializers are executed at load time when the .psm1 file is loaded,
        so the referenced type must already be defined.
        StaticInitializer cycles are fatal in PowerShell 5.1 and cause a load-time error,
        identical in severity to Inheritance cycles.
    #>
    StaticInitializer = 3
}
#endregion Enum PSScriptBuilderDependencyEdgeType
