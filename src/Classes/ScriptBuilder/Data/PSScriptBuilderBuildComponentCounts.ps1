#region Class PSScriptBuilderBuildComponentCounts
<#
.SYNOPSIS
    Holds count information for all build component types.
.DESCRIPTION
    The PSScriptBuilderBuildComponentCounts class contains the number of components collected for each collector type
    during the build process.
#>
class PSScriptBuilderBuildComponentCounts {
    #region Properties
    <#
    .SYNOPSIS
        Number of using statements collected.
    .DESCRIPTION
        The UsingStatements property holds the count of using statements collected by the UsingCollector.
    #>
    [int] $UsingStatements

    <#
    .SYNOPSIS
        Number of enums collected.
    .DESCRIPTION
        The EnumDefinitions property holds the count of enum definitions collected by the EnumCollector.
    #>
    [int] $EnumDefinitions

    <#
    .SYNOPSIS
        Number of classes collected.
    .DESCRIPTION
        The ClassDefinitions property holds the count of class definitions collected by the ClassCollector.
    #>
    [int] $ClassDefinitions

    <#
    .SYNOPSIS
        Number of functions collected.
    .DESCRIPTION
        The FunctionDefinitions property holds the count of function definitions collected by the FunctionCollector.
    #>
    [int] $FunctionDefinitions

    <#
    .SYNOPSIS
        Number of files collected.
    .DESCRIPTION
        The FileContents property holds the count of files collected by the FileCollector.
    #>
    [int] $FileContents
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderBuildComponentCounts.
    .DESCRIPTION
        Creates a new PSScriptBuilderBuildComponentCounts with all counts initialized to zero.
        Counts are typically set after construction by the BuildDataAggregator.
    #>
    PSScriptBuilderBuildComponentCounts() {
        $this.UsingStatements     = 0
        $this.EnumDefinitions     = 0
        $this.ClassDefinitions    = 0
        $this.FunctionDefinitions = 0
        $this.FileContents        = 0
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderBuildComponentCounts
