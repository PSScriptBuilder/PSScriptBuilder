#region Cmdlet Get-PSScriptBuilderBumpConfiguration
function Get-PSScriptBuilderBumpConfiguration {
    <#
    .SYNOPSIS
        Retrieves the bump configuration.
    .DESCRIPTION
        The Get-PSScriptBuilderBumpConfiguration cmdlet loads and displays the current bump configuration,
        showing which files are configured to receive version token updates.
        This cmdlet is useful for inspecting and validating bump configuration without making any changes.
    .OUTPUTS
        Array of PSCustomObject
    .EXAMPLE
        Get-PSScriptBuilderBumpConfiguration | ForEach-Object { $_.path }
        Retrieves all bump file paths and displays them.
    .NOTES
        This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
        The bump files configuration file must be properly configured and accessible.
        To view available tokens, use Get-PSScriptBuilderReleaseDataTokens.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    process {
        try {
            # Create orchestrator (loads configuration internally)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            # Load bump configuration
            $bumpConfig = $orchestrator.LoadBumpConfiguration()

            # Initialize managers for validation
            $orchestrator.InitializeBumpFilesManagers($bumpConfig)

            # Validate bump configuration
            if (-not $orchestrator.ValidateBumpConfiguration($bumpConfig)) {
                $orchestrator.GetBumpConfigurationValidationErrors() | ForEach-Object {
                    Write-Error $_
                }

                return
            }

            return $bumpConfig
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderBumpConfiguration
