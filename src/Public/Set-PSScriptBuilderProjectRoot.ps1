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
        auto-discovery by walking up the directory tree from the current PowerShell location, searching for
        a psscriptbuilder.config.json file.

        This cmdlet is useful for:
        - Explicitly overriding the auto-discovered project root
        - CI/CD pipelines that need to work with a specific project path
        - Testing and debugging scenarios where the current location is outside the project
    .PARAMETER Path
        The path to set as the new project root. Must be an existing directory on a file system drive;
        a path on another provider's drive, such as HKCU:, is rejected. Wildcard characters are not
        interpreted; a name such as App[1] is used as it is. Accepts the output of Get-Item and
        Get-ChildItem through the pipeline. The directory is stored with its full name, as Windows
        resolves it: without trailing spaces or dots, and without 8.3 short names.
    .EXAMPLE
        Set-PSScriptBuilderProjectRoot -Path "C:\MyProject"
        Sets the project root to C:\MyProject
    .EXAMPLE
        Set-PSScriptBuilderProjectRoot -Path (Get-Location).Path
        Sets the project root to the current PowerShell location
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('PSPath')]
        [string]
        $Path
    )

    process {
        try {
            # A path of white space only would resolve to the current location
            if ([string]::IsNullOrWhiteSpace($Path)) {
                $message = 'The path must not consist of white space only.'
                throw [ArgumentException]::new($message, 'Path')
            }

            # A directory name such as App[1] is no wildcard pattern, and a pattern must not set several roots
            $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop

            # Windows PowerShell 5.1 returns nothing, without an error, for a literal path containing * or ?
            if ($null -eq $resolvedPath) {
                $format  = "Cannot find path '{0}' because it does not exist."
                $message = $format -f $Path
                throw [System.Management.Automation.ItemNotFoundException]::new($message)
            }

            # A registry key passes the container check below, but its provider path is no directory
            if ($resolvedPath.Provider.Name -ne 'FileSystem') {
                $format  = "The path '{0}' resolves to '{1}' of the {2} provider, not to a file system path. Specify a directory on a file system drive."
                $message = $format -f $Path, $resolvedPath.ProviderPath, $resolvedPath.Provider.Name
                throw [ArgumentException]::new($message, 'Path')
            }

            if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
                $format  = 'Path is not a valid directory: {0}'
                $message = $format -f $resolvedPath.ProviderPath
                throw [DirectoryNotFoundException]::new($message)
            }

            # Windows ignores trailing spaces and dots and expands 8.3 short names, but a path combined
            # from the unchanged root does not; FullName holds the directory as Windows resolves it
            $Global:PSScriptBuilderProjectRoot = [DirectoryInfo]::new($resolvedPath.ProviderPath).FullName

            Write-Verbose "PSScriptBuilderProjectRoot set to: $Global:PSScriptBuilderProjectRoot"
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Set-PSScriptBuilderProjectRoot
