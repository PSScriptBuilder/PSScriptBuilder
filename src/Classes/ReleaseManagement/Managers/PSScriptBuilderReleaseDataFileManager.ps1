using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderReleaseDataFileManager
<#
.SYNOPSIS
    Manages release data files for PSScriptBuilder.
.DESCRIPTION
    The PSScriptBuilderReleaseDataFileManager class is responsible for loading and saving release data files 
    in JSON format. It utilizes the file path provided to handle file I/O operations.
#>
class PSScriptBuilderReleaseDataFileManager {
    #region Properties
    <#
    .SYNOPSIS
        Path to the release data file.
    .DESCRIPTION
        The ReleaseDataFilePath property holds the file path where release data is loaded from and saved to.
    #>
    [string] $ReleaseDataFilePath
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderReleaseDataFileManager class.
    .DESCRIPTION
        The constructor takes a file path to configure the manager.
    .PARAMETER path
        The file path to the release data file as a string.
    #>
    PSScriptBuilderReleaseDataFileManager([string] $path) {
        $this.ReleaseDataFilePath = $path
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Loads release data from the configured file path.
    .DESCRIPTION
        The Load method reads the release data in JSON format from the configured file path.
        This is the primary method for loading release data using the configured settings.
        If any errors occur during loading, an exception is thrown with the details of the error.
    .OUTPUTS
        Returns a PSCustomObject containing the loaded release data.
    #>
    [PSCustomObject] Load() {
        return $this.Load($this.ReleaseDataFilePath)
    }

    <#
    .SYNOPSIS
        Loads release data from a specified file path.
    .DESCRIPTION
        The Load method reads the release data in JSON format from the specified file path.
        If any errors occur during loading, an exception is thrown with the details of the error.
    .PARAMETER path
        The file path to load the release data from as a string.
    .OUTPUTS
        Returns a PSCustomObject containing the loaded release data.
    #>
    [PSCustomObject] Load([string] $path) {
        Write-Verbose "Loading release data from $path"

        # Guard clause: fail fast with a clear message if file does not exist
        if (-not (Test-Path $path -PathType Leaf)) {
            $message = "Failed to load release file '$path' because it does not exist"
            throw [FileNotFoundException]::new($message, $path)
        }

        try {
            $jsonContent = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($path)
            $data = $jsonContent | ConvertFrom-Json
            $this.Normalize($data)
            return $data
        }
        catch [ArgumentException] {
            $message = "Failed to load release file '$path' due to invalid JSON: $($_.Exception.Message)"
            throw [ArgumentException]::new($message, $_.Exception)
        }
        catch {
            $inner = $_.Exception.InnerException

            if ($inner -is [DecoderFallbackException]) {
                $message = "Failed to load release file '$path' due to invalid UTF-8 encoding: $($inner.Message)"
                throw [DecoderFallbackException]::new($message, $inner)
            }

            $message = "Failed to load release file '$path': $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Saves the release data to the configured file path.
    .DESCRIPTION
        The Save method writes the release data in JSON format to the configured file path.
        This is the primary method for saving release data using the configured settings.
        If any errors occur during saving, an exception is thrown with the details of the error.
    .PARAMETER releaseData
        The release data to save as a PSCustomObject.
    #>
    [void] Save([PSCustomObject] $releaseData) {
        $this.Save($this.ReleaseDataFilePath, $releaseData)
    }

    <#
    .SYNOPSIS
        Saves the release data to a specified file path.
    .DESCRIPTION
        The Save method writes the release data in JSON format to the specified file path.
        If any errors occur during saving, an exception is thrown with the details of the error.
    .PARAMETER path
        The file path to save the release data to as a string.
    .PARAMETER releaseData
        The release data to save as a PSCustomObject.
    #>
    [void] Save([string] $path, [PSCustomObject] $releaseData) {
        Write-Verbose "Saving release data to $path"

        try {
            $jsonContent = $releaseData | ConvertTo-Json -Depth 10
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($path, $jsonContent)
        }
        catch [ArgumentException] {
            $message = "Failed to save release data to file '$path' due to invalid JSON: $($_.Exception.Message)"
            throw [ArgumentException]::new($message, $_.Exception)
        }
        catch {
            $inner = $_.Exception.InnerException

            if ($inner -is [EncoderFallbackException]) {
                $message = "Failed to save release data to file '$path' due to invalid UTF-8 encoding: $($inner.Message)"
                throw [EncoderFallbackException]::new($message, $inner)
            }

            $message = "Failed to save release data to file '$path': $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Checks if the release file exists.
    .DESCRIPTION
        The Exists method checks if the file at the configured path exists on the filesystem.
    .OUTPUTS
        Returns $true if the release file exists, otherwise $false.
    #>
    [bool] Exists() {
        return $this.Exists($this.ReleaseDataFilePath)
    }

    <#
    .SYNOPSIS
        Checks if a file exists at the specified path.
    .DESCRIPTION
        The Exists method checks if the specified file exists on the filesystem.
    .PARAMETER path
        The file path to check as a string.
    .OUTPUTS
        Returns $true if the file exists, otherwise $false.
    #>
    [bool] Exists([string] $path) {
        $path = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($path)

        try {
            return Test-Path -Path $path -PathType Leaf
        }
        catch {
            $message = "Failed to check existence of release file '$path': $($_.Exception.Message)"
            throw [IOException]::new($message)
        }
    }

    <#
    .SYNOPSIS
        Normalizes deserialized release data for cross-version compatibility.
    .DESCRIPTION
        The Normalize method corrects type differences introduced by PowerShell 7's ConvertFrom-Json,
        which automatically deserializes ISO 8601 strings as DateTime objects. This ensures consistent
        behavior across PowerShell 5.1 and PowerShell 7.
    .PARAMETER data
        The deserialized release data as a PSCustomObject.
    #>
    [void] Normalize([PSCustomObject] $data) {
        # PowerShell 7 automatically deserializes ISO 8601 strings as DateTime objects.
        # Convert back to string to ensure consistent behavior across PS 5.1 and PS 7,
        # and to satisfy the release data validator which expects a string type.
        # Add-Member -Force is required because direct property assignment does not overwrite
        # NoteProperty values on deserialized PSCustomObjects in PowerShell 7.
        if ($null -ne $data.build -and $null -ne $data.build.timestamp -and $data.build.timestamp -isnot [string]) {
            $value = $data.build.timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssK')
            $data.build | Add-Member -NotePropertyName 'timestamp' -NotePropertyValue $value -Force
        }
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderReleaseDataFileManager
