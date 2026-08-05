#region Cmdlet Get-PSScriptBuilderReleaseData
function Get-PSScriptBuilderReleaseData {
    <#
    .SYNOPSIS
        Retrieves the current release data configuration.
    .DESCRIPTION
        The Get-PSScriptBuilderReleaseData cmdlet loads and displays the current release data,
        including version information, build metadata, and git information. This cmdlet is useful
        for inspecting the current state of release management without making any changes.

        By default, returns hierarchical data with Version, Build, and Git sections using PascalCase property names.
        With -Flat parameter, returns a single flat structure with all properties on one level.

        Both formats return OrderedDictionary objects that maintain categorical order for consistent presentation.
        Both can be sorted using: GetEnumerator() | Sort-Object -Property Key

    .PARAMETER Flat
        If specified, returns release data in a flat single-level structure with all properties prefixed
        by category (Version*, Build*, Git*). Useful for tabular display or when flat structure is preferred.

    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    .EXAMPLE
        $releaseData = Get-PSScriptBuilderReleaseData
        $releaseData.Version
        Retrieves release data and accesses version information.

    .EXAMPLE
        Get-PSScriptBuilderReleaseData -Flat | Format-Table
        Retrieves flat release data and formats as table.

    .EXAMPLE
        $releaseData = Get-PSScriptBuilderReleaseData -Flat
        $releaseData.GetEnumerator() | Sort-Object -Property Key
        Retrieves flat release data sorted alphabetically by key.

    .NOTES
        This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
        The release data file must be properly configured and accessible.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]
        $Flat
    )

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

            # Create processor to format data
            $processor = [PSScriptBuilderReleaseDataProcessor]::new($releaseData)

            # Return formatted or flattened based on parameter
            if ($Flat) {
                Write-Verbose "Returning flattened release data"
                return $processor.GetReleaseDataFlattened()
            }
            else {
                Write-Verbose "Returning hierarchical release data"
                return $processor.GetReleaseDataFormatted()
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderReleaseData
