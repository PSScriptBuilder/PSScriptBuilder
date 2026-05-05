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
        1. Loads the bump files configuration from the configured file
        2. Validates the configuration structure
        3. Applies version tokens to all configured files
        4. Persists changes based on -WhatIf and -Confirm parameters
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
    param()

    process {
        try {
            # Step 1: Create orchestrator (loads configuration internally)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            # Step 2: Execute bump files update operation (preparation, validation, and backup creation)
            $result = $orchestrator.ExecuteBumpFilesUpdate()

            # Step 3: ShouldProcess check - handles -WhatIf and -Confirm automatically
            if ($PSCmdlet.ShouldProcess("Bump files", "Persist changes to bump files")) {
                # Persist operation: save changes and cleanup resources
                $orchestrator.PersistBumpFilesChanges()
            }

            # Step 4: Return the result object
            return $result
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Update-PSScriptBuilderBumpFiles
