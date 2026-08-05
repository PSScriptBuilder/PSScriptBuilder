#region Cmdlet Get-PSScriptBuilderConfiguration
function Get-PSScriptBuilderConfiguration {
    <#
    .SYNOPSIS
        Retrieves the global PSScriptBuilder configuration.
    .DESCRIPTION
        The Get-PSScriptBuilderConfiguration function loads the psscriptbuilder.config.json file
        and returns the configuration object. This includes release and build configuration
        settings.

        By default, returns hierarchical data with Release and Build sections.
        With -Flat parameter, returns a single flat structure with all properties on one level.
    .PARAMETER Flat
        If specified, returns configuration in a flat single-level structure with all properties
        prefixed by category (Release*, Build*). Useful for tabular display or when flat
        structure is preferred.
    .OUTPUTS
        PSScriptBuilderConfiguration
            Returns when called without -Flat.
        System.Collections.Specialized.OrderedDictionary
            Returns when called with -Flat.
    .EXAMPLE
        $config = Get-PSScriptBuilderConfiguration
        $config.Build.OutputPath

        Access specific configuration values.
    .EXAMPLE
        Get-PSScriptBuilderConfiguration -Flat | Format-Table

        Returns flat configuration and formats as table.
    .NOTES
        The configuration is loaded from psscriptbuilder.config.json in the project root.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSScriptBuilderConfiguration],                     ParameterSetName = 'Default')]
    [OutputType([System.Collections.Specialized.OrderedDictionary], ParameterSetName = 'Flat')]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'Flat')]
        [switch]
        $Flat
    )

    process {
        try {
            $config = [PSScriptBuilderConfiguration]::new()

            if ($Flat) {
                Write-Verbose "Returning flattened configuration"
                return $config.GetConfigurationFlattened()
            }

            Write-Verbose "Returning hierarchical configuration"
            return $config
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderConfiguration
