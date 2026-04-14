#region Cmdlet Format-PSScriptBuilderReleaseDataResult
function Format-PSScriptBuilderReleaseDataResult {
    <#
    .SYNOPSIS
        Formats and displays the result of a release data update operation.
    .DESCRIPTION
        The Format-PSScriptBuilderReleaseDataResult function takes a PSScriptBuilderReleaseDataResult 
        object and displays its changes in a clear, structured format organized by category (Version, Build, Git). 
        For each change, the property name, old value, and new value are displayed.
    .PARAMETER ReleaseDataResult
        The PSScriptBuilderReleaseDataResult object returned from Update-PSScriptBuilderReleaseData 
        or other release data operation cmdlets.
    .OUTPUTS
        None
    .EXAMPLE
        Update-PSScriptBuilderReleaseData -Major | Format-PSScriptBuilderReleaseDataResult

        Pipes the result directly to the formatting function.
    .NOTES
        This function displays the results of release data operations in a structured, easy-to-read format.
        If no changes were made, a message indicating this is displayed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSScriptBuilderReleaseDataResult]
        $ReleaseDataResult
    )

    process {
        # Validate input
        if ($null -eq $ReleaseDataResult) {
            Write-Host "ReleaseDataResult is null. Nothing to display."
            return
        }

        # Check if there are any changes
        if ($null -eq $ReleaseDataResult.Changes -or $ReleaseDataResult.Changes.Count -eq 0) {
            Write-Host "No changes were made."
            return
        }

        # Display changes organized by category
        foreach ($category in $ReleaseDataResult.Changes.Keys) {
            $changes = $ReleaseDataResult.Changes[$category]

            # Skip empty categories
            if ($null -eq $changes -or $changes.Count -eq 0) {
                continue
            }

            Write-Host "Category: $category"
            Write-Host ""

            # Display each change in this category
            foreach ($change in $changes) {
                Write-Host "  Property  : $($change.Property)"
                Write-Host "  Old Value : $($change.OldValue)"
                Write-Host "  New Value : $($change.NewValue)"
                Write-Host ""
            }
        }
    }
}
#endregion Cmdlet Format-PSScriptBuilderReleaseDataResult
