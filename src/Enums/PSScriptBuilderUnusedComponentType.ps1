#region Enum PSScriptBuilderUnusedComponentType
<#
.SYNOPSIS
    Defines the component types that can be reported during unused component analysis.
.DESCRIPTION
    The PSScriptBuilderUnusedComponentType enum represents the component types that can appear
    in unused component analysis results. Each value corresponds to a collector type that
    contributes named components to the dependency graph and can be identified as unused.
#>
enum PSScriptBuilderUnusedComponentType {
    <#
    .SYNOPSIS
        An enum definition.
    .DESCRIPTION
        The Enum value represents a PowerShell enum definition collected by an EnumCollector.
    #>
    Enum = 0

    <#
    .SYNOPSIS
        A class definition.
    .DESCRIPTION
        The Class value represents a PowerShell class definition collected by a ClassCollector.
    #>
    Class = 1

    <#
    .SYNOPSIS
        A function definition.
    .DESCRIPTION
        The Function value represents a PowerShell function definition collected by a FunctionCollector.
    #>
    Function = 2
}
#endregion Enum PSScriptBuilderUnusedComponentType
