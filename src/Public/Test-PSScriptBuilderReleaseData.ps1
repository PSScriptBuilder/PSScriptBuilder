#region Cmdlet Test-PSScriptBuilderReleaseData
function Test-PSScriptBuilderReleaseData {
    <#
    .SYNOPSIS
        Tests the release data file for validity.
    .DESCRIPTION
        The Test-PSScriptBuilderReleaseData cmdlet validates the release data file from disk
        against the configured data structure. Returns $true if the file is valid, $false otherwise.
        
        Validation errors are reported via Write-Error. This is useful when external tools have 
        modified the release data file and you want to verify its integrity before proceeding 
        with release operations.
    .OUTPUTS
        System.Boolean
    .EXAMPLE
        if (Test-PSScriptBuilderReleaseData) {
            Write-Host "Release data is valid, proceeding with update..."
            Update-PSScriptBuilderReleaseData -Patch
        } else {
            Write-Host "Release data has errors, fix them first"
        }
        
        Validates release data and conditionally updates it.
    .NOTES
        - Requires configuration to be loaded (PSScriptBuilderConfiguration.GetCurrent())
        - Requires release data file to exist
        - Validation errors are displayed via Write-Error
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        # Create orchestrator (loads configuration automatically)
        $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

        # Load release data
        $releaseData = $orchestrator.LoadReleaseData()

        # Initialize release data managers
        $orchestrator.InitializeReleaseDataManagers($releaseData)

        # Validate release data
        $result = $orchestrator.ValidateReleaseData($releaseData)

        # Output validation errors if validation failed
        if (-not $result) {
            $orchestrator.GetReleaseDataValidationErrors() | ForEach-Object {
                Write-Error $_
            }
        }

        return $result
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion Cmdlet Test-PSScriptBuilderReleaseData
