#region Class PSScriptBuilderSourceRange
<#
.SYNOPSIS
    Represents the line range of a component within a source file.
.DESCRIPTION
    The PSScriptBuilderSourceRange class encapsulates the start and end line numbers of
    a collected component (enum, class, function, or file) within its source file.
    Used internally by collectors to track source positions for source map generation.
#>
class PSScriptBuilderSourceRange {
    #region Properties
    <#
    .SYNOPSIS
        The first line of the component in the source file.
    .DESCRIPTION
        The StartLineNumber property holds the 1-based line number where the component begins
        in the source file.
    #>
    [int] $StartLineNumber

    <#
    .SYNOPSIS
        The last line of the component in the source file.
    .DESCRIPTION
        The EndLineNumber property holds the 1-based line number where the component ends
        in the source file.
    #>
    [int] $EndLineNumber
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderSourceRange.
    .DESCRIPTION
        Creates a new PSScriptBuilderSourceRange with the specified line range.
    .PARAMETER startLineNumber
        The 1-based line number where the component begins in the source file.
    .PARAMETER endLineNumber
        The 1-based line number where the component ends in the source file.
    #>
    PSScriptBuilderSourceRange([int] $startLineNumber, [int] $endLineNumber) {
        $this.StartLineNumber = $startLineNumber
        $this.EndLineNumber   = $endLineNumber
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderSourceRange
