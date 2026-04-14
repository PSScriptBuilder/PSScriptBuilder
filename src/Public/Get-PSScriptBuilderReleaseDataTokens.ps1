#region Cmdlet Get-PSScriptBuilderReleaseDataTokens
function Get-PSScriptBuilderReleaseDataTokens {
    <#
    .SYNOPSIS
        Retrieves available release data tokens for substitution in bump files.
    .DESCRIPTION
        The Get-PSScriptBuilderReleaseDataTokens cmdlet loads and displays all available tokens
        that can be used for variable substitution in bump files. These tokens are generated from
        the current release data and include version information, build metadata, and git context.

        The tokens are returned sorted alphabetically by category (Build, Git, Version) for easy reference.
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    .EXAMPLE
        $tokens = Get-PSScriptBuilderReleaseDataTokens
        $tokens.GetEnumerator() | Format-Table -AutoSize
        Retrieves tokens and formats them as a table.
    .EXAMPLE
        $tokens = Get-PSScriptBuilderReleaseDataTokens
        $tokens['VERSION_FULL']
        Retrieves a specific token value.
    .NOTES
        This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
        The release data file must be properly configured and accessible.
        Tokens are used in bump file patterns and configuration.
    #>
    [CmdletBinding()]
    param()

    process {
        try {
            # Create orchestrator (loads configuration automatically)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            # Load release data
            $releaseData = $orchestrator.LoadReleaseData()

            # Initialize release data managers
            $orchestrator.InitializeReleaseDataManagers($releaseData)

            # Validate release data
            if (-not $orchestrator.ValidateReleaseData($releaseData)) {
                $orchestrator.GetReleaseDataValidationErrors() | ForEach-Object {
                    Write-Error $_
                }
                return
            }

            # Get token map from validated release data
            $tokenMap = $orchestrator.GetReleaseDataTokenMap($releaseData)

            if ($null -eq $tokenMap) {
                throw [InvalidOperationException]::new("Failed to generate release data tokens")
            }

            return $tokenMap
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderReleaseDataTokens
