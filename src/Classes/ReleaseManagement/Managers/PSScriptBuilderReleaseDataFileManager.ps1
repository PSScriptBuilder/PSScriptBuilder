using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderReleaseDataFileManager
<#
.SYNOPSIS
    Manages release data files for PSScriptBuilder.
.DESCRIPTION
    The PSScriptBuilderReleaseDataFileManager class is responsible for reading, parsing and serializing
    release data files in JSON format. It utilizes the file path provided to handle file I/O operations.
    Writing is done by PSScriptBuilderFileTransaction (RFC 0026): this class reads the bytes of the
    file, parses them, and serializes release data to the bytes to write.
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
        The Load method reads the release data in JSON format from the specified file path, as
        ReadBytes followed by Deserialize. If any errors occur during loading, an exception is
        thrown with the details of the error.
    .PARAMETER path
        The file path to load the release data from as a string.
    .OUTPUTS
        Returns a PSCustomObject containing the loaded release data.
    #>
    [PSCustomObject] Load([string] $path) {
        Write-Verbose "Loading release data from $path"

        $bytes = $this.ReadBytes($path)
        $data  = $this.Deserialize($bytes, $path)
        return $data
    }

    <#
    .SYNOPSIS
        Reads the bytes of the configured release data file.
    .DESCRIPTION
        The ReadBytes method reads the release data file at the configured path as bytes. The
        orchestrator keeps them to check, before writing, that the file did not change since it was
        read (see PSScriptBuilderFileTransaction).
    .OUTPUTS
        Returns the content of the release data file as byte[].
    #>
    [byte[]] ReadBytes() {
        $bytes = $this.ReadBytes($this.ReleaseDataFilePath)
        return $bytes
    }

    <#
    .SYNOPSIS
        Reads the bytes of a release data file.
    .DESCRIPTION
        The ReadBytes method reads the release data file at the specified path as bytes. Throws
        FileNotFoundException if the file does not exist, and Exception naming the file if it cannot
        be read - with the same messages as Load before.
    .PARAMETER path
        The file path to read the release data from as a string.
    .OUTPUTS
        Returns the content of the release data file as byte[].
    #>
    [byte[]] ReadBytes([string] $path) {
        # Guard clause: fail fast with a clear message if file does not exist
        if (-not (Test-Path $path -PathType Leaf)) {
            $message = "Failed to load release file '$path' because it does not exist"
            throw [FileNotFoundException]::new($message, $path)
        }

        try {
            $bytes = [PSScriptBuilderFileIOHelper]::ReadAllBytes($path)
            return $bytes
        }
        catch {
            $message = "Failed to load release file '$path': $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Parses the bytes of a release data file.
    .DESCRIPTION
        The Deserialize method decodes the bytes as ReadAllTextUTF8WithBOM does, parses them as JSON
        and normalizes the result (see Normalize). Errors are reported as Load reported them before:
        ArgumentException for invalid JSON, IOException for invalid UTF-8 encoding, Exception
        otherwise - each naming the file. The order of the catch blocks is kept unchanged on purpose
        (see RFC 0026, out of scope: invalid UTF-8 currently reaches the invalid JSON branch).
    .PARAMETER bytes
        The content of the release data file, as read by ReadBytes.
    .PARAMETER path
        The path of the release data file, used in error messages.
    .OUTPUTS
        Returns the release data as PSCustomObject.
    #>
    [PSCustomObject] Deserialize([byte[]] $bytes, [string] $path) {
        try {
            $jsonContent = [PSScriptBuilderFileIOHelper]::DecodeUTF8WithBOM($bytes)
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
                throw [IOException]::new($message, $inner)
            }

            $message = "Failed to load release file '$path': $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Serializes release data to the bytes of a release data file.
    .DESCRIPTION
        The Serialize method converts the release data to JSON (depth 10) and encodes it as UTF-8
        with BOM - byte for byte what the former Save method wrote. Errors are reported as Save
        reported them before: ArgumentException for content that cannot be converted to JSON,
        EncoderFallbackException for text that cannot be encoded, Exception otherwise. The order of
        the catch blocks is kept unchanged on purpose (see RFC 0026, out of scope).
    .PARAMETER releaseData
        The release data to serialize as a PSCustomObject.
    .OUTPUTS
        Returns the content of the release data file as byte[].
    #>
    [byte[]] Serialize([PSCustomObject] $releaseData) {
        $path = $this.ReleaseDataFilePath

        try {
            $jsonContent = $releaseData | ConvertTo-Json -Depth 10
            $bytes       = [PSScriptBuilderFileIOHelper]::EncodeUTF8WithBOM($jsonContent)
            return $bytes
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
        behavior across PowerShell 5.1 and PowerShell 7. The order of the properties is kept, so
        loading and saving unchanged release data yields the same file content.
    .PARAMETER data
        The deserialized release data as a PSCustomObject.
    #>
    [void] Normalize([PSCustomObject] $data) {
        # PowerShell 7 automatically deserializes ISO 8601 strings as DateTime objects.
        # Convert back to string to ensure consistent behavior across PS 5.1 and PS 7,
        # and to satisfy the release data validator which expects a string type.
        # The value is set on the NoteProperty itself: Add-Member -Force would move the property to
        # the end of the build section, so every update would reorder the file (RFC 0026).
        if ($null -ne $data.build -and $null -ne $data.build.timestamp -and $data.build.timestamp -isnot [string]) {
            $value = $data.build.timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssK')
            $data.build.PSObject.Properties['timestamp'].Value = $value
        }
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderReleaseDataFileManager
