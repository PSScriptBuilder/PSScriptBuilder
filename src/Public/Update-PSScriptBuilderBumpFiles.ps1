#region Cmdlet Update-PSScriptBuilderBumpFiles
function Update-PSScriptBuilderBumpFiles {
    <#
    .SYNOPSIS
        Updates configured project files with current version information.
    .DESCRIPTION
        The Update-PSScriptBuilderBumpFiles cmdlet synchronizes project files with the current version 
        information from the release data. It applies version tokens to all configured files according to 
        the bump files configuration, supporting preview mode (-WhatIf) and interactive confirmation (-Confirm).

        The operation:
        1. Loads and validates the bump files configuration
        2. Prepares the new content of every configured file in memory
        3. Asks once for confirmation, listing the files that change - not at all if none changes
        4. Writes all changed files as one transaction: each file is checked to be unchanged since
           step 2 and backed up next to itself (<file>.psscriptbuilder-backup); if writing any file
           fails, all files are restored. An existing backup from an earlier, incomplete run stops
           the operation before any file is changed.

        A warning is emitted for any configured file whose entries all failed to match its current
        content - most commonly a Placeholder-mode entry with no Regex-mode fallback, already
        consumed by an earlier run. Add a Regex-mode entry (Mixed Bump Mode) to keep matching on
        subsequent runs.
    .OUTPUTS
        PSScriptBuilderBumpFilesResult
    .EXAMPLE
        Update-PSScriptBuilderBumpFiles -WhatIf
        Shows which files would be updated without making changes.
    .EXAMPLE
        Update-PSScriptBuilderBumpFiles -Confirm
        Prompts for confirmation before updating files.
    .NOTES
        This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
        The bump files configuration must be properly defined in the project configuration.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSScriptBuilderBumpFilesResult])]
    param()

    process {
        try {
            # Step 1: Create orchestrator (loads configuration internally)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            # Step 2: Prepare the changes in memory - nothing is written yet
            $result = $orchestrator.ExecuteBumpFilesUpdate()

            # Nothing to change, nothing to confirm (RFC 0026)
            if ($result.TotalFilesModified -eq 0) {
                Write-Verbose "No bump file changes - nothing to persist"
                return $result
            }

            # Step 3: One confirmation for all files - -WhatIf shows the description, -Confirm the question
            $files       = @($result.BumpDetails | ForEach-Object { $_.Path })
            $fileList    = ($files | ForEach-Object { "  $_" }) -join [Environment]::NewLine
            $format      = "Updating {0} bump file(s):{1}{2}"
            $description = $format -f $files.Count, [Environment]::NewLine, $fileList
            $format      = "Update these {0} bump file(s)?{1}{2}"
            $question    = $format -f $files.Count, [Environment]::NewLine, $fileList

            if ($PSCmdlet.ShouldProcess($description, $question, "Update bump files")) {
                # Step 4: Write all files as one transaction
                foreach ($warning in $orchestrator.PersistBumpFilesChanges()) {
                    Write-Warning $warning
                }
            }

            # Step 5: Return the result object
            return $result
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Update-PSScriptBuilderBumpFiles
