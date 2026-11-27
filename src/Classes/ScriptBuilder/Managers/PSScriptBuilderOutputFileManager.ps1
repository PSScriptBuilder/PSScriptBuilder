using namespace System
using namespace System.IO

#region Class PSScriptBuilderOutputFileManager
<#
.SYNOPSIS
    Manages writing build output script files.
.DESCRIPTION
    The PSScriptBuilderOutputFileManager provides static methods for writing build output script files to disk.
    It handles output directory creation and uses PSScriptBuilderFileIOHelper for consistent UTF8 encoding.
    The manager always overwrites existing files as backup management is handled by the orchestrator.
#>
class PSScriptBuilderOutputFileManager {
    #region Static Methods
    <#
    .SYNOPSIS
        Writes the build output script to the specified file.
    .DESCRIPTION
        The WriteScript method writes the provided script content to the specified file path.
        If the output directory does not exist, it will be created automatically.
        If the file already exists, it will be overwritten without warning (backup management is handled externally).
        The file is written using UTF8 encoding with BOM via PSScriptBuilderFileIOHelper.
    .PARAMETER filePath
        The absolute or relative path where the script should be written.
    .PARAMETER content
        The script content to write to the file.
    #>
    static [void] WriteScript([string] $filePath, [string] $content) {
        # Validate parameters
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            $message = "Parameter 'filePath' cannot be null or empty."
            throw [ArgumentException]::new($message, "filePath")
        }

        if ($null -eq $content) {
            $message = "Parameter 'content' cannot be null."
            throw [ArgumentException]::new($message, "content")
        }

        Write-Verbose "Writing output script to: $filePath"

        # Resolve path to absolute
        $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($filePath)

        # Ensure output directory exists
        $directory = [Path]::GetDirectoryName($resolvedPath)

        if ($directory -and -not (Test-Path -Path $directory -PathType Container)) {
            try {
                [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($directory)
                Write-Verbose "  Created output directory: $directory"
            }
            catch {
                $format  = "Failed to create output directory: {0}. Error: {1}"
                $message = $format -f $directory, $_.Exception.Message
                throw [IOException]::new($message, $_.Exception)
            }
        }

        # Write script file
        try {
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($resolvedPath, $content)
            Write-Verbose "  Script written: $($content.Length) character(s)"
        }
        catch {
            $format  = "Failed to write output script to: {0}. Error: {1}"
            $message = $format -f $resolvedPath, $_.Exception.Message
            throw [IOException]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Checks if an output script file exists.
    .DESCRIPTION
        The ScriptExists method verifies whether an output script file exists at the specified path.
        It resolves relative paths to absolute paths before checking existence.
    .PARAMETER filePath
        The absolute or relative path to the script file.
    .OUTPUTS
        Returns $true if the script file exists, $false otherwise.
    #>
    static [bool] ScriptExists([string] $filePath) {
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            return $false
        }

        try {
            $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($filePath)
            return [File]::Exists($resolvedPath)
        }
        catch {
            return $false
        }
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderOutputFileManager
