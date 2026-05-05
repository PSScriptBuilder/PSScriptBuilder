#region Cmdlet Test-PSScriptBuilderBumpConfiguration
function Test-PSScriptBuilderBumpConfiguration {
    <#
    .SYNOPSIS
        Tests the bump configuration file for validity.
    .DESCRIPTION
        The Test-PSScriptBuilderBumpConfiguration cmdlet validates the bump configuration file from disk
        against the configured data structure. Returns $true if the file is valid, $false otherwise.
        
        Validation errors are reported via Write-Error. This is useful when external tools have 
        modified the bump configuration file and you want to verify its integrity before proceeding 
        with bump file operations.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        if (Test-PSScriptBuilderBumpConfiguration) {
            Write-Host "Bump configuration is valid, proceeding with update..."
            Update-PSScriptBuilderBumpFiles
        } else {
            Write-Host "Bump configuration has errors, fix them first"
        }
        
        Validates bump configuration and conditionally updates bump files.
    .NOTES
        - Requires configuration to be loaded (PSScriptBuilderConfiguration.GetCurrent())
        - Requires bump configuration file to exist
        - Validation errors are displayed via Write-Error
    #>
    [CmdletBinding()]
    param()

    try {
        # Create orchestrator (loads configuration automatically)
        $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

        # Load bump configuration
        $bumpConfig = $orchestrator.LoadBumpConfiguration()

        # Initialize bump files managers
        $orchestrator.InitializeBumpFilesManagers($bumpConfig)

        # Validate bump configuration
        $result = $orchestrator.ValidateBumpConfiguration($bumpConfig)

        # Output validation errors if validation failed
        if (-not $result) {
            $orchestrator.GetBumpConfigurationValidationErrors() | ForEach-Object {
                Write-Error $_
            }
        }

        return $result
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion Cmdlet Test-PSScriptBuilderBumpConfiguration
