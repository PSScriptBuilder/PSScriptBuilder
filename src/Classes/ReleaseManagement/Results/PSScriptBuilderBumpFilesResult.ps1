#region Class PSScriptBuilderBumpFilesResult
<#
.SYNOPSIS
    Encapsulates the result of a bump files operation.
.DESCRIPTION
    The PSScriptBuilderBumpFilesResult class provides a structured container for the outcome 
    of a bump files update operation, including operations performed and files that were updated.
.NOTES
    This result object is only created for successful operations as the processor will throw exceptions for 
    any errors encountered during processing.
#>
class PSScriptBuilderBumpFilesResult {
    #region Properties
    <#
    .SYNOPSIS
        Total number of files processed.
    .DESCRIPTION
        The TotalFilesProcessed property contains the count of all files that were processed during 
        the bump operation, regardless of whether they were modified or not.
    #>
    [int] $TotalFilesProcessed

    <#
    .SYNOPSIS
        Total number of files modified.
    .DESCRIPTION
        The TotalFilesModified property contains the count of files that had actual content changes 
        during the bump operation. This is useful for understanding the actual impact of the operation.
    #>
    [int] $TotalFilesModified

    <#
    .SYNOPSIS
        Detailed information about each file bumped.
    .DESCRIPTION
        The BumpDetails property contains an array of PSCustomObject items, each describing:
        - Path: File path that was modified
        - ChangedItems: Array of specific changes made (Pattern, Token, OldValue, NewValue)
        
        Note: BumpDetails only contains entries for files that had actual content changes.
    #>
    [PSCustomObject[]] $BumpDetails
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes an operation result.
    .PARAMETER totalFilesProcessed
        Total number of files processed.
    .PARAMETER totalFilesModified
        Total number of files that were modified.
    .PARAMETER bumpDetails
        Array of PSCustomObject with detailed bump change information.
    #>
    PSScriptBuilderBumpFilesResult([int] $totalFilesProcessed, [int] $totalFilesModified, [PSCustomObject[]] $bumpDetails) {
        $this.TotalFilesProcessed = $totalFilesProcessed
        $this.TotalFilesModified  = $totalFilesModified
        $this.BumpDetails         = $bumpDetails
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderBumpFilesResult
