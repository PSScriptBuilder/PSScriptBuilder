#region Cmdlet New-PSScriptBuilderConfiguration
function New-PSScriptBuilderConfiguration {
    <#
    .SYNOPSIS
        Creates a new PSScriptBuilder configuration file with default values.
    .DESCRIPTION
        The New-PSScriptBuilderConfiguration cmdlet creates a new psscriptbuilder.config.json file
        with default values in the specified or currently set project root directory.

        If the target directory does not exist yet, it is created automatically.

        If no -Path is specified, the cmdlet uses the project root set via
        Set-PSScriptBuilderProjectRoot. If neither is set, the current PowerShell location is used.

        If the configuration file already exists, the cmdlet fails with an error. Use -Force to
        overwrite an existing file.

        The cmdlet supports PowerShell's -WhatIf and -Confirm parameters for safe preview and
        confirmation.
    .PARAMETER Path
        The directory in which to create the configuration file. If not specified, the currently
        set project root or the current PowerShell location is used. A relative path is resolved
        against the current PowerShell location. A path on another provider's drive, such as HKCU:,
        is rejected.
    .PARAMETER Force
        Overwrites the configuration file if it already exists.
    .EXAMPLE
        New-PSScriptBuilderConfiguration

        Creates a new psscriptbuilder.config.json with default values in the current
        PowerShell location or the project root set via Set-PSScriptBuilderProjectRoot.

    .EXAMPLE
        New-PSScriptBuilderConfiguration -Path "C:\MyProject"

        Creates a new configuration file in the specified directory.

    .EXAMPLE
        New-PSScriptBuilderConfiguration -Force

        Creates or overwrites an existing configuration file in the current working
        directory. Useful for resetting the configuration to its default values.
    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Path,

        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    process {
        try {
            # Resolve project root without auto-discovery (config file may not exist yet)
            # Resolved against the PowerShell location, never against the process working directory
            # that .NET would use (RFC 0028)
            if (-not [string]::IsNullOrWhiteSpace($Path)) {
                $resolvedRoot = [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($PSCmdlet.SessionState.Path, $Path)
            }
            elseif (-not [string]::IsNullOrWhiteSpace($Global:PSScriptBuilderProjectRoot)) {
                $resolvedRoot = $Global:PSScriptBuilderProjectRoot
            }
            else {
                $resolvedRoot = [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($PSCmdlet.SessionState.Path, '.')
            }

            if ($PSCmdlet.ShouldProcess($resolvedRoot, "Create configuration file")) {
                $configPath = [PSScriptBuilderConfiguration]::CreateDefault($resolvedRoot, $Force.IsPresent)
                Write-Verbose "Configuration file created: $configPath"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet New-PSScriptBuilderConfiguration
