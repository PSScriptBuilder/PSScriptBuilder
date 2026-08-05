using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderFileIOHelper
<#
.SYNOPSIS
    Provides file I/O operations with consistent UTF8 encoding.
.DESCRIPTION
    The PSScriptBuilderFileIOHelper class encapsulates file read and write operations with UTF8 encoding
    to ensure consistency across the project. This eliminates the need for repeated UTF8Encoding instantiation
    and encoding parameter handling throughout the codebase.

    PowerShell script files are written using UTF8 with BOM (Byte Order Mark). Non-PowerShell text files
    such as JSON artifacts are written using UTF8 without BOM, as required by RFC 8259.
#>
class PSScriptBuilderFileIOHelper {
    #region Static Properties
    <#
    .SYNOPSIS
        Gets the standard UTF8 encoding used for all file operations.
    .DESCRIPTION
        The UTF8EncodingWithBOM static property provides a UTF8Encoding instance with BOM enabled and 
        strict byte validation.
        This is the standard encoding used throughout the project.
    #>
    static [UTF8Encoding] $UTF8EncodingWithBOM = [UTF8Encoding]::new($true,  $true)

    <#
    .SYNOPSIS
        Gets the standard UTF8 encoding without BOM used for all file operations.
    .DESCRIPTION
        The UTF8EncodingWithoutBOM static property provides a UTF8Encoding instance with BOM disabled and 
        strict byte validation.
        This encoding is used for non-PowerShell text files, such as JSON artifacts, to comply with RFC 8259.
    #>
    static [UTF8Encoding] $UTF8EncodingWithoutBOM = [UTF8Encoding]::new($false, $true)
    #endregion Static Properties

    #region Static Methods
    <#
    .SYNOPSIS
        Reads all text from a file using UTF8 encoding with BOM.
    .DESCRIPTION
        The ReadAllTextUTF8WithBOM method reads the entire content of a file specified by the filePath parameter. 
        It uses UTF8 encoding with BOM and strict validation to ensure proper file format compatibility.
    .PARAMETER filePath
        The path to the file to read.
    .OUTPUTS
        Returns the file contents as a string.
    .EXAMPLE
        $content = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM("C:\file.txt")
    #>
    static [string] ReadAllTextUTF8WithBOM([string] $filePath) {
        return [File]::ReadAllText($filePath, [PSScriptBuilderFileIOHelper]::UTF8EncodingWithBOM)
    }

    <#
    .SYNOPSIS
        Writes text to a file using UTF8 encoding with BOM.
    .DESCRIPTION
        The WriteAllTextUTF8WithBOM method writes the specified content to a file at the given filePath. 
        It uses UTF8 encoding with BOM and strict validation to ensure proper file format compatibility.
    .PARAMETER filePath
        The path to the file to write.
    .PARAMETER content
        The text content to write to the file.
    .EXAMPLE
        [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM("C:\file.txt", "content")
    #>
    static [void] WriteAllTextUTF8WithBOM([string] $filePath, [string] $content) {
        [File]::WriteAllText($filePath, $content, [PSScriptBuilderFileIOHelper]::UTF8EncodingWithBOM)
    }

    <#
    .SYNOPSIS
        Appends text to a file using UTF8 encoding with BOM.
    .DESCRIPTION
        The AppendAllTextUTF8WithBOM method appends the specified content to a file at the given filePath. 
        It uses UTF8 encoding with BOM and strict validation to ensure proper file format compatibility.
    .PARAMETER filePath
        The path to the file to append to.
    .PARAMETER content
        The text content to append to the file.
    .EXAMPLE
        [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM("C:\file.txt", "new line")
    #>
    static [void] AppendAllTextUTF8WithBOM([string] $filePath, [string] $content) {
        [File]::AppendAllText($filePath, $content, [PSScriptBuilderFileIOHelper]::UTF8EncodingWithBOM)
    }

    <#
    .SYNOPSIS
        Writes text to a file using UTF8 encoding without BOM.
    .DESCRIPTION
        The WriteAllTextUTF8WithoutBOM method writes the specified content to a file at the given filePath.
        It uses UTF8 encoding without a Byte Order Mark, as required by RFC 8259 for JSON files and
        other non-PowerShell text artifacts intended for cross-platform consumption.
    .PARAMETER filePath
        The path to the file to write.
    .PARAMETER content
        The text content to write to the file.
    .EXAMPLE
        [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithoutBOM("C:\report.json", $json)
    #>
    static [void] WriteAllTextUTF8WithoutBOM([string] $filePath, [string] $content) {
        [File]::WriteAllText($filePath, $content, [PSScriptBuilderFileIOHelper]::UTF8EncodingWithoutBOM)
    }

    <#
    .SYNOPSIS
        Returns the paths of files that contain non-ASCII characters but lack a UTF-8 BOM.
    .DESCRIPTION
        The FindNonAsciiFilesWithoutBom method reads the bytes of each file to detect the UTF-8 BOM
        (0xEF, 0xBB, 0xBF). If the BOM is absent, the file is scanned for bytes above 0x7F.
        Files containing such bytes are returned as potentially problematic under PowerShell 5.1,
        which reads UTF-8 files without BOM as Windows-1252 and corrupts non-ASCII characters.

        Files with only ASCII content (bytes <= 0x7F) are safe regardless of BOM and are not returned.
        Files that are null, empty, do not exist, or have no content are silently skipped.
    .PARAMETER filePaths
        The array of file paths to check.
    .OUTPUTS
        Returns an array of file paths that contain non-ASCII content without a UTF-8 BOM.
    #>
    static [string[]] FindNonAsciiFilesWithoutBom([string[]] $filePaths) {
        $result = [List[string]]::new()

        if ($null -eq $filePaths -or $filePaths.Count -eq 0) {
            return $result.ToArray()
        }

        foreach ($path in $filePaths) {
            if ([string]::IsNullOrEmpty($path)) { continue }
            if (-not [File]::Exists($path))     { continue }

            $bytes = [File]::ReadAllBytes($path)

            if ($bytes.Length -eq 0) { continue }

            # Check for UTF-8 BOM (0xEF 0xBB 0xBF) - only possible with at least 3 bytes
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

            if ($hasBom) { continue }

            # No BOM - check for non-ASCII bytes (> 0x7F)
            $hasNonAscii = $false
            foreach ($byte in $bytes) {
                if ($byte -gt 0x7F) {
                    $hasNonAscii = $true
                    break
                }
            }

            if ($hasNonAscii) {
                $result.Add($path)
            }
        }

        return $result.ToArray()
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderFileIOHelper
