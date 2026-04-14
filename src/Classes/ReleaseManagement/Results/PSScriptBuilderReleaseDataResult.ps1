using namespace System.Collections.Specialized

#region Class PSScriptBuilderReleaseDataResult
<#
.SYNOPSIS
    Encapsulates the result of a release data update operation.
.DESCRIPTION
    The PSScriptBuilderReleaseDataResult class represents the outcome of a release data update,
    including the number of operations performed and detailed tracking of all changes made to the 
    release data (version, build, and git information).

    Note: The command throws a terminating exception on failure, so this result object is only created
    for successful operations.

    The Changes property is an OrderedDictionary organized by category (Version, Build, Git), with each 
    category containing an array of change objects showing the old and new values.
#>
class PSScriptBuilderReleaseDataResult {
    #region Properties
    <#
    .SYNOPSIS
        Total number of operations performed.
    .DESCRIPTION
        The TotalOperationsPerformed property contains the count of update operations that were 
        executed during the release data update. This provides an overview of the scope of changes.
    #>
    [int] $TotalOperationsPerformed

    <#
    .SYNOPSIS
        Detailed changes organized by category.
    .DESCRIPTION
        The Changes property is an OrderedDictionary with categories (Version, Build, Git) as keys.
        Each category contains an array of change objects with properties:
        - Property: The name of the property that changed
        - OldValue: The previous value
        - NewValue: The new value

        Useful for audit trail and verification of what was changed.
    #>
    [OrderedDictionary] $Changes
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes an operation result with change tracking.
    .DESCRIPTION
        Creates a result instance with the total number of operations and detailed changes by category.
    .PARAMETER totalOperationsPerformed
        Total number of operations that were performed.
    .PARAMETER changes
        OrderedDictionary containing changes organized by category (Version, Build, Git).
    #>
    PSScriptBuilderReleaseDataResult([int] $totalOperationsPerformed, [OrderedDictionary] $changes) {
        $this.TotalOperationsPerformed = $totalOperationsPerformed
        $this.Changes = $changes
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderReleaseDataResult
