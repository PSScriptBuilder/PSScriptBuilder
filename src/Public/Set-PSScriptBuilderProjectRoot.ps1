using namespace System.IO

#region Cmdlet Set-PSScriptBuilderProjectRoot
function Set-PSScriptBuilderProjectRoot {
    <#
    .SYNOPSIS
        Sets the PSScriptBuilder project root directory.
    .DESCRIPTION
        The Set-PSScriptBuilderProjectRoot cmdlet explicitly sets the project root directory and caches it
        in $Global:PSScriptBuilderProjectRoot for all subsequent PSScriptBuilder operations.

        Calling this cmdlet is optional. If it is not called, Get-PSScriptBuilderProjectRoot performs
        auto-discovery by walking up the directory tree from the current working directory, searching for
        a psscriptbuilder.config.json file.

        This cmdlet is useful for:
        - Explicitly overriding the auto-discovered project root
        - CI/CD pipelines that need to work with a specific project path
        - Testing and debugging scenarios where the working directory differs from the project root
    .PARAMETER Path
        The path to set as the new project root. Must be an existing directory.
    .EXAMPLE
        Set-PSScriptBuilderProjectRoot -Path "C:\MyProject"
        Sets the project root to C:\MyProject
    .EXAMPLE
        Set-PSScriptBuilderProjectRoot -Path (Get-Location).Path
        Sets the project root to the current working directory
    .NOTES
        The global variable $Global:PSScriptBuilderProjectRoot is updated.
        This affects all subsequent PSScriptBuilder operations.

        In most cases, this cmdlet is not needed. PSScriptBuilder automatically discovers
        the project root by searching for psscriptbuilder.config.json in the current directory
        and its parents. Only call this cmdlet to override that behavior.
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path
    )

    process {
        try {
            # Resolve path to absolute
            $resolvedPath = $Path | Resolve-Path -ErrorAction Stop

            if (-not (Test-Path -Path $resolvedPath -PathType Container)) {
                throw [DirectoryNotFoundException]::new("Path is not a valid directory: $resolvedPath")
            }

            # Set global variable
            $Global:PSScriptBuilderProjectRoot = $resolvedPath.ProviderPath

            Write-Verbose "PSScriptBuilderProjectRoot set to: $Global:PSScriptBuilderProjectRoot"
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Set-PSScriptBuilderProjectRoot
