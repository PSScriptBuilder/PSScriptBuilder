using namespace System
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderConfigLoader
<#
.SYNOPSIS
    Loader for PSScriptBuilder configuration files.
.DESCRIPTION
    The PSScriptBuilderConfigLoader class provides static methods to load configuration data from JSON files 
    and convert them into appropriate configuration objects used by the PSScriptBuilder.
#>
class PSScriptBuilderConfigLoader {
    #region Methods
    <#
    .SYNOPSIS
        Loads configuration from a JSON file.
    .DESCRIPTION
        The LoadFromFile method reads a JSON configuration file from the specified path and converts it into 
        a PowerShell object. It handles file not found and JSON parsing errors.
    .PARAMETER path
        The path to the configuration file to load as a string.
    .OUTPUTS
        Returns a PSCustomObject representing the configuration data.
    #>
    static [PSCustomObject] LoadFromFile([string] $path) {
        $path = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($path)

        if (-not (Test-Path -Path $path)) {
            $message = "Configuration file '$path' does not exist"
            throw [FileNotFoundException]::new($message)
        }

        Write-Verbose "Loading configuration from $path"

        try {
            # Use FileIOHelper to read configuration with UTF8 BOM encoding
            # FileIOHelper ensures consistent encoding with error detection across the project
            $jsonContent = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($path)

            $configObject = $jsonContent | ConvertFrom-Json
            return $configObject
        }
        catch [ArgumentException] {
            $message = "Failed to load configuration file '$path' due to invalid JSON: $($_.Exception.Message)"
            throw [ArgumentException]::new($message, $_.Exception)
        }
        catch {
            $inner = $_.Exception.InnerException

            if ($inner -is [DecoderFallbackException]) {
                $message = "Failed to load configuration file '$path' due to invalid UTF-8 encoding: $($inner.Message)"
                throw [IOException]::new($message, $inner)
            }

            $message = "Failed to load configuration file '$path': $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Loads configuration from a JSON string.
    .DESCRIPTION
        The LoadFromJsonString method converts a JSON string into a PowerShell object. It handles JSON parsing 
        errors.
    .PARAMETER jsonString
        The JSON string containing the configuration data.
    .OUTPUTS
        Returns a PSCustomObject representing the configuration data.
    .NOTES
        This method is useful for loading configuration data that is not stored in a file and can also be used 
        for testing or dynamic configuration scenarios.
    #>
    static [PSCustomObject] LoadFromJsonString([string] $jsonString) {
        try {
            $configObject = $jsonString | ConvertFrom-Json
            return $configObject
        }
        catch [ArgumentException] {
            $message = "Failed to load configuration from json string: $($_.Exception.Message)"
            throw [ArgumentException]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Loads release options from configuration data.
    .DESCRIPTION
        The LoadReleaseOptions method extracts the release options from the provided configuration object and 
        returns an instance of the PSScriptBuilderReleaseOptions class initialized with those settings.
    .PARAMETER config
        A PSCustomObject containing the configuration data.
    .OUTPUTS
        Returns an instance of the PSScriptBuilderReleaseOptions class.
    #>
    static [PSScriptBuilderReleaseOptions] LoadReleaseOptions([PSCustomObject] $config) {
        if (-not $config.Release) {
            $message = "Release configuration section is missing in the configuration data"
            throw [InvalidOperationException]::new($message)
        }

        return [PSScriptBuilderReleaseOptions]::new($config.Release)
    }

    <#
    .SYNOPSIS
        Loads build options from configuration data.
    .DESCRIPTION
        The LoadBuildOptions method extracts the build options from the provided configuration object and 
        returns an instance of the PSScriptBuilderBuildOptions class initialized with those settings.
    .PARAMETER config
        A PSCustomObject containing the configuration data.
    .OUTPUTS
        Returns an instance of the PSScriptBuilderBuildOptions class.
    #>
    static [PSScriptBuilderBuildOptions] LoadBuildOptions([PSCustomObject] $config) {
        if (-not $config.Build) {
            $message = "Build configuration section is missing in the configuration data"
            throw [InvalidOperationException]::new($message)
        }

        return [PSScriptBuilderBuildOptions]::new($config.Build)
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderConfigLoader
