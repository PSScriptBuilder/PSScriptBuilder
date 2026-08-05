#region Cmdlet Format-PSScriptBuilderBumpResult
function Format-PSScriptBuilderBumpResult {
    <#
    .SYNOPSIS
        Formats and displays the result of a bump operation.
    .DESCRIPTION
        The Format-PSScriptBuilderBumpResult function takes a PSScriptBuilderBumpFilesResult 
        object and displays its BumpDetails in a clear, structured format. For each modified file, 
        all changes are displayed with their pattern, token, old value, and new value.
    .PARAMETER BumpResult
        The PSScriptBuilderBumpFilesResult object returned from Update-PSScriptBuilderBumpFiles 
        or other bump operation cmdlets.
    .OUTPUTS
        None
    .EXAMPLE
        Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult

        Pipes the result directly to the formatting function.
    .NOTES
        This function displays the results of bump operations in a structured, easy-to-read format.
        If no changes were made, a message indicating this is displayed.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSScriptBuilderBumpFilesResult]
        $BumpResult
    )

    process {
        # Validate input
        if ($null -eq $BumpResult) {
            Write-Host "BumpResult is null. Nothing to display."
            return
        }

        # Check if there are any bump details
        if ($null -eq $BumpResult.BumpDetails -or $BumpResult.BumpDetails.Count -eq 0) {
            Write-Host "No changes were made."
            return
        }

        # Display details for each file
        foreach ($detail in $BumpResult.BumpDetails) {
            Write-Host "File : $($detail.Path)"
            Write-Host ""

            if ($null -eq $detail.ChangedItems -or $detail.ChangedItems.Count -eq 0) {
                Write-Host "  (No changes recorded)"
                Write-Host ""
                continue
            }

            # Display each change for this file
            foreach ($change in $detail.ChangedItems) {
                Write-Host "  Pattern   : $($change.Pattern)"
                Write-Host "  Token     : $($change.Token)"
                Write-Host "  Old Value : $($change.OldValue)"
                Write-Host "  New Value : $($change.NewValue)"
                Write-Host ""
            }
        }
    }
}
#endregion Cmdlet Format-PSScriptBuilderBumpResult
