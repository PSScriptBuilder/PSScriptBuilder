#region Enum PSScriptBuilderCollectorType
<#
.SYNOPSIS
    Defines the types of collectors available in PSScriptBuilder.
.DESCRIPTION
    The PSScriptBuilderCollectorType enum represents the different collector types used for script building.
    The numeric values define the default execution order (lower values execute first).
#>
enum PSScriptBuilderCollectorType {
    <#
    .SYNOPSIS
        Collector for 'using' statements.
    .DESCRIPTION
        The UsingCollector type is responsible for collecting 'using' statements across PowerShell files.
    #>
    UsingCollector = 0

    <#
    .SYNOPSIS
        Collector for enum definitions.
    .DESCRIPTION
        The EnumCollector type is responsible for collecting enum definitions across PowerShell files.
    #>
    EnumCollector = 1

    <#
    .SYNOPSIS
        Collector for class definitions.
    .DESCRIPTION
        The ClassCollector type is responsible for collecting class definitions across PowerShell files.
    #>
    ClassCollector = 2

    <#
    .SYNOPSIS
        Collector for function definitions.
    .DESCRIPTION
        The FunctionCollector type is responsible for collecting function definitions across PowerShell files.
    #>
    FunctionCollector = 3

    <#
    .SYNOPSIS
        Collector for file content.
    .DESCRIPTION
        The FileCollector type is responsible for collecting raw file content, used for scenarios where AST-based 
        collection is not sufficient or desired.
    #>
    FileCollector = 4
}
#endregion Enum PSScriptBuilderCollectorType
