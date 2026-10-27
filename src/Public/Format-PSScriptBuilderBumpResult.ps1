#region Cmdlet Format-PSScriptBuilderBumpResult
function Format-PSScriptBuilderBumpResult {
    <#
    .SYNOPSIS
        Formats and displays the result of a bump operation.
    .DESCRIPTION
        The Format-PSScriptBuilderBumpResult function takes a PSScriptBuilderBumpFilesResult
        object and displays its BumpDetails in a clear, structured format. For each modified file,
        all changes are displayed with their pattern, token, old value, and new value.

        The Pattern line is only shown when it differs from Old Value - Simple and Placeholder
        Mode always set them equal, so showing both would be redundant; Regex Mode's Pattern (the
        {REGEX_TOKEN} config template) legitimately differs from the actual matched Old Value, so
        it is always shown there.
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
                # Simple/Placeholder Mode always set Pattern equal to OldValue (the pattern's own
                # literal text is what gets searched for); showing it twice adds no information.
                # Regex Mode's Pattern (the {REGEX_TOKEN} config template) legitimately differs
                # from OldValue (the actual matched text), so it is always shown there.
                if ($change.Pattern -ne $change.OldValue) {
                    Write-Host "  Pattern   : $($change.Pattern)"
                }
                Write-Host "  Token     : $($change.Token)"
                Write-Host "  Old Value : $($change.OldValue)"
                Write-Host "  New Value : $($change.NewValue)"
                Write-Host ""
            }
        }
    }
}
#endregion Cmdlet Format-PSScriptBuilderBumpResult
