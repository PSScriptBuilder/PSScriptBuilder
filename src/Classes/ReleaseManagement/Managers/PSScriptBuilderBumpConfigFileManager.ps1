using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderBumpConfigFileManager
<#
.SYNOPSIS
    Manages bump configuration for PSScriptBuilder.
.DESCRIPTION
    The PSScriptBuilderBumpConfigFileManager class is responsible for loading and saving bump configuration files 
    in JSON format. It utilizes the file path provided to handle file I/O operations.
#>
class PSScriptBuilderBumpConfigFileManager {
    #region Properties
    <#
    .SYNOPSIS
        Path to the bump configuration file.
    .DESCRIPTION
        The BumpConfigFilePath property holds the file path where bump configuration is loaded from and saved to.
    #>
    [string] $BumpConfigFilePath
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderBumpConfigFileManager class.
    .DESCRIPTION
        The constructor takes a file path to configure the manager.
    .PARAMETER path
        The file path to the bump configuration file as a string.
    #>
    PSScriptBuilderBumpConfigFileManager([string] $path) {
        $this.BumpConfigFilePath = $path
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Loads bump configuration from the configured file path.
    .DESCRIPTION
        The Load method reads the bump configuration in JSON format from the configured file path.
        This is the primary method for loading bump configuration using the configured settings.
        If any errors occur during loading, an exception is thrown with the details of the error.
    .OUTPUTS
        Returns a PSCustomObject containing the loaded bump configuration.
    #>
    [PSCustomObject] Load() {
        return $this.Load($this.BumpConfigFilePath)
    }

    <#
    .SYNOPSIS
        Loads bump configuration from a specified file path.
    .DESCRIPTION
        The Load method reads the bump configuration in JSON format from the specified file path.
        If any errors occur during loading, an exception is thrown with the details of the error.
    .PARAMETER path
        The file path to load the bump configuration from as a string.
    .OUTPUTS
        Returns a PSCustomObject containing the loaded bump configuration.
    #>
    [PSCustomObject] Load([string] $path) {
        Write-Verbose "Loading bump configuration from $path"

        # Guard clause: fail fast with a clear message if file does not exist
        if (-not (Test-Path $path -PathType Leaf)) {
            $message = "Failed to load bump configuration '$path' because it does not exist"
            throw [FileNotFoundException]::new($message, $path)
        }

        try {
            $jsonContent = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($path)
            return $jsonContent | ConvertFrom-Json
        }
        catch [ArgumentException] {
            $message = "Failed to load bump configuration '$path' due to invalid JSON: $($_.Exception.Message)"
            throw [ArgumentException]::new($message, $_.Exception)
        }
        catch {
            $inner = $_.Exception.InnerException

            if ($inner -is [DecoderFallbackException]) {
                $message = "Failed to load bump configuration '$path' due to invalid UTF-8 encoding: $($inner.Message)"
                throw [IOException]::new($message, $inner)
            }

            $message = "Failed to load bump configuration '$path': $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Saves bump configuration to the configured file path.
    .DESCRIPTION
        The Save method writes the bump configuration in JSON format to the configured file path.
        This is the primary method for saving bump configuration using the configured settings.
        If any errors occur during saving, an exception is thrown with the details of the error.
    .PARAMETER bumpConfigData
        The bump configuration data to save as a PSCustomObject.
    #>
    [void] Save([PSCustomObject] $bumpConfigData) {
        $this.Save($this.BumpConfigFilePath, $bumpConfigData)
    }

    <#
    .SYNOPSIS
        Saves bump configuration to a specified file path.
    .DESCRIPTION
        The Save method writes the bump configuration in JSON format to the specified file path.
        If any errors occur during saving, an exception is thrown with the details of the error.
    .PARAMETER path
        The file path to save the bump configuration to as a string.
    .PARAMETER bumpConfigData
        The bump configuration data to save as a PSCustomObject.
    #>
    [void] Save([string] $path, [PSCustomObject] $bumpConfigData) {
        try {
            $jsonContent = $bumpConfigData | ConvertTo-Json -Depth 10
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($path, $jsonContent)
        }
        catch [ArgumentException] {
            $message = "Failed to save bump configuration to '$path' due to invalid JSON: $($_.Exception.Message)"
            throw [ArgumentException]::new($message, $_.Exception)
        }
        catch {
            $inner = $_.Exception.InnerException

            if ($inner -is [EncoderFallbackException]) {
                $message = "Failed to save bump configuration to '$path' due to invalid UTF-8 encoding: $($inner.Message)"
                throw [EncoderFallbackException]::new($message, $inner)
            }

            $message = "Failed to save bump configuration to '$path': $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Checks if the bump configuration file exists at the configured path.
    .DESCRIPTION
        The Exists method checks if the bump configuration file exists at the configured file path.
    .OUTPUTS
        Returns a boolean indicating whether the file exists.
    #>
    [bool] Exists() {
        return Test-Path -Path $this.BumpConfigFilePath -PathType Leaf
    }

    <#
    .SYNOPSIS
        Checks if the bump configuration file exists at a specified path.
    .DESCRIPTION
        The Exists method checks if the bump configuration file exists at the specified file path.
    .PARAMETER path
        The file path to check for existence as a string.
    .OUTPUTS
        Returns a boolean indicating whether the file exists.
    #>
    [bool] Exists([string] $path) {
        $path = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($path)

        try {
            return Test-Path -Path $path -PathType Leaf
        }
        catch {
            $message = "Failed to check existence of bump configuration file '$path': $($_.Exception.Message)"
            throw [IOException]::new($message)
        }
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderBumpConfigFileManager
