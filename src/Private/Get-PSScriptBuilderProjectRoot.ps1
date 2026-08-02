using namespace System.IO

#region Function Get-PSScriptBuilderProjectRoot
function Get-PSScriptBuilderProjectRoot {
    <#
    .SYNOPSIS
        Gets the PSScriptBuilder project root path.
    .DESCRIPTION
        The Get-PSScriptBuilderProjectRoot function returns the current project root path.

        If Set-PSScriptBuilderProjectRoot was called previously, the cached value is returned immediately.

        Otherwise, the function performs auto-discovery by walking up the directory tree from the current
        working directory, searching for a psscriptbuilder.config.json file. The first directory that
        contains this file is used as the project root and cached in $Global:PSScriptBuilderProjectRoot
        for subsequent calls.

        If no psscriptbuilder.config.json is found in the current directory or any parent directory,
        an InvalidOperationException is thrown.
    .OUTPUTS
        Returns the project root path as a string.
    .NOTES
        This is an internal helper function, not exported by the module.
        Called by public cmdlets that require the project root path.
        Callers do not need to invoke this function directly - it is called automatically.
    #>
    # Return cached value if already set (by Set-PSScriptBuilderProjectRoot or prior auto-discovery)
    if (-not [string]::IsNullOrWhiteSpace($Global:PSScriptBuilderProjectRoot)) {
        return $Global:PSScriptBuilderProjectRoot
    }

    # Walk up the directory tree from the current working directory
    $current = [DirectoryInfo]::new((Get-Location).Path)

    while ($null -ne $current) {
        $configFile = [Path]::Combine($current.FullName, [PSScriptBuilderWellKnownFileNames]::Configuration)

        if ([File]::Exists($configFile)) {
            $Global:PSScriptBuilderProjectRoot = $current.FullName
            Write-Verbose "Auto-discovered project root: $($Global:PSScriptBuilderProjectRoot)"
            return $Global:PSScriptBuilderProjectRoot
        }

        $current = $current.Parent
    }

    $format = 
        "No '{0}' found in '{1}' or any parent directory. " +
        "Run from your project directory or call Set-PSScriptBuilderProjectRoot first."
    $message = $format -f [PSScriptBuilderWellKnownFileNames]::Configuration, (Get-Location).Path
    throw [InvalidOperationException]::new($message)
}
#endregion Function Get-PSScriptBuilderProjectRoot
