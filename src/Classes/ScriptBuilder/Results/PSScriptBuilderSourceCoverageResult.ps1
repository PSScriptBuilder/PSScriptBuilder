#region Class PSScriptBuilderSourceCoverageResult
<#
.SYNOPSIS
    Represents the aggregated code coverage of a single source file.
.DESCRIPTION
    The PSScriptBuilderSourceCoverageResult class holds the number of hit and missed commands
    for one original source file, translated from Pester's built-output-relative coverage data
    via the source map. Returned by Get-PSScriptBuilderSourceCoverage.
#>
class PSScriptBuilderSourceCoverageResult {
    #region Properties
    <#
    .SYNOPSIS
        The absolute path to the source file.
    .DESCRIPTION
        The SourceFile property holds the absolute path to the original source file that
        this coverage entry was aggregated for.
    #>
    [string] $SourceFile

    <#
    .SYNOPSIS
        The total number of coverage-analyzed commands attributed to this source file.
    .DESCRIPTION
        The TotalCommands property holds the sum of HitCommands and MissedCommands for
        this source file.
    #>
    [int] $TotalCommands

    <#
    .SYNOPSIS
        The number of commands that were executed at least once.
    .DESCRIPTION
        The HitCommands property holds the count of commands from this source file that
        Pester recorded as executed during the test run.
    #>
    [int] $HitCommands

    <#
    .SYNOPSIS
        The number of commands that were never executed.
    .DESCRIPTION
        The MissedCommands property holds the count of commands from this source file that
        Pester recorded as never executed during the test run. Equals TotalCommands minus
        HitCommands.
    #>
    [int] $MissedCommands

    <#
    .SYNOPSIS
        The percentage of commands that were executed.
    .DESCRIPTION
        The CoveragePercent property holds HitCommands divided by TotalCommands, expressed
        as a percentage. Zero if TotalCommands is zero.
    #>
    [double] $CoveragePercent

    <#
    .SYNOPSIS
        The resolved source locations of every missed command.
    .DESCRIPTION
        The MissedLocations property holds one PSScriptBuilderSourceLocation per missed
        command, for drill-down to the exact source line that was never executed.
    #>
    [PSScriptBuilderSourceLocation[]] $MissedLocations
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderSourceCoverageResult.
    .PARAMETER sourceFile
        The absolute path to the source file.
    .PARAMETER totalCommands
        The total number of coverage-analyzed commands attributed to this source file.
    .PARAMETER hitCommands
        The number of commands that were executed at least once.
    .PARAMETER missedCommands
        The number of commands that were never executed.
    .PARAMETER coveragePercent
        The percentage of commands that were executed.
    .PARAMETER missedLocations
        The resolved source locations of every missed command.
    #>
    PSScriptBuilderSourceCoverageResult(
        [string] $sourceFile,
        [int]    $totalCommands,
        [int]    $hitCommands,
        [int]    $missedCommands,
        [double] $coveragePercent,
        [PSScriptBuilderSourceLocation[]] $missedLocations
    ) {
        $this.SourceFile      = $sourceFile
        $this.TotalCommands   = $totalCommands
        $this.HitCommands     = $hitCommands
        $this.MissedCommands  = $missedCommands
        $this.CoveragePercent = $coveragePercent
        $this.MissedLocations = $missedLocations
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderSourceCoverageResult
