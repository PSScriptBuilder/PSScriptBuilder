#region Cmdlet New-PSScriptBuilderReleaseData
function New-PSScriptBuilderReleaseData {
    <#
    .SYNOPSIS
        Creates a new release data file with default values.
    .DESCRIPTION
        The New-PSScriptBuilderReleaseData cmdlet creates and initializes a new release data file with default values:
        - Version: 0.1.0
        - Build Number: 0
        - All timestamps and git information are set to $null

        If the release data file already exists, the cmdlet fails with an error. Use -Force to overwrite an existing file.

        The cmdlet supports PowerShell's -WhatIf and -Confirm parameters for safe preview and confirmation.
    .PARAMETER Force
        Overwrites the release data file if it already exists. Use with caution as this will replace existing data.
    .OUTPUTS
        PSCustomObject
    .EXAMPLE
        # Preview what would be created (with -WhatIf)
        New-PSScriptBuilderReleaseData -WhatIf

    .EXAMPLE
        # Overwrite existing release data file
        New-PSScriptBuilderReleaseData -Force

    .NOTES
        Requires PSScriptBuilder configuration to be loaded.
        The release data file path is specified in the PSScriptBuilder configuration.
        If its directory does not exist yet, it is created automatically.
        The file is written as one transaction; an existing file overwritten with -Force is checked
        to be unchanged since it was read and restored if writing fails.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    process {
        try {
            # Create orchestrator (loads configuration automatically)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            # Create new release data (in-memory, not persisted yet)
            # The release data has the same format as returned by Get-PSScriptBuilderReleaseData
            $releaseData = $orchestrator.CreateNewReleaseData($Force)

            # Use standard ShouldProcess pattern (handles -WhatIf and -Confirm automatically) -
            # -WhatIf shows the description, -Confirm the question
            # -Force only controls whether existing file can be overwritten, not confirmation behavior
            $filePath    = $orchestrator.GetReleaseDataFilePath()
            $format      = "Writing new release data to '{0}'"
            $description = $format -f $filePath
            $format      = "Write new release data to '{0}'?"
            $question    = $format -f $filePath

            if ($PSCmdlet.ShouldProcess($description, $question, "Create release data")) {
                foreach ($warning in $orchestrator.PersistReleaseDataChanges()) {
                    Write-Warning $warning
                }
            }

            # Return the created release data
            return $releaseData
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet New-PSScriptBuilderReleaseData
