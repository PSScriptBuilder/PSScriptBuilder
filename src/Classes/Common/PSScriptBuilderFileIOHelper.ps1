using namespace System
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
        Reads all bytes of a file.
    .DESCRIPTION
        The ReadAllBytes method reads the entire content of a file as bytes, without decoding it.
        It is used where the exact content is needed besides its text, e.g. to detect later
        whether the file changed (see PSScriptBuilderFileTransaction). DecodeUTF8WithBOM turns the
        bytes into the same text that ReadAllTextUTF8WithBOM returns.
    .PARAMETER filePath
        The absolute path to the file to read.
    .OUTPUTS
        Returns the file contents as byte[].
    .EXAMPLE
        $bytes = [PSScriptBuilderFileIOHelper]::ReadAllBytes("C:\file.txt")
    #>
    static [byte[]] ReadAllBytes([string] $filePath) {
        $bytes = [File]::ReadAllBytes($filePath)
        return $bytes
    }

    <#
    .SYNOPSIS
        Decodes bytes the way ReadAllTextUTF8WithBOM decodes a file.
    .DESCRIPTION
        The DecodeUTF8WithBOM method decodes the bytes with a StreamReader using UTF8EncodingWithBOM
        and byte order mark detection - exactly as File.ReadAllText does: a UTF-8 BOM is removed, a
        UTF-16 or UTF-32 BOM selects that encoding, and invalid UTF-8 throws a
        DecoderFallbackException because of the strict encoding. Encoding.GetString() would neither
        remove the BOM nor detect UTF-16, and would return different text.
    .PARAMETER bytes
        The bytes to decode, as read by ReadAllBytes.
    .OUTPUTS
        Returns the decoded text as string.
    .EXAMPLE
        $text = [PSScriptBuilderFileIOHelper]::DecodeUTF8WithBOM($bytes)
    #>
    static [string] DecodeUTF8WithBOM([byte[]] $bytes) {
        if ($null -eq $bytes) {
            $message = "Parameter 'bytes' cannot be null."
            throw [ArgumentNullException]::new("bytes", $message)
        }

        $stream = [MemoryStream]::new($bytes, $false)
        $reader = [StreamReader]::new($stream, [PSScriptBuilderFileIOHelper]::UTF8EncodingWithBOM, $true)

        try {
            $text = $reader.ReadToEnd()
            return $text
        }
        finally {
            $reader.Dispose()
        }
    }

    <#
    .SYNOPSIS
        Encodes text the way WriteAllTextUTF8WithBOM writes a file.
    .DESCRIPTION
        The EncodeUTF8WithBOM method returns the UTF-8 byte order mark followed by the text encoded
        with UTF8EncodingWithBOM - byte for byte what WriteAllTextUTF8WithBOM writes, also for an
        empty text (only the byte order mark). Text that cannot be encoded, e.g. a lone surrogate,
        throws an EncoderFallbackException because of the strict encoding.
    .PARAMETER content
        The text to encode.
    .OUTPUTS
        Returns the encoded content as byte[].
    .EXAMPLE
        $bytes = [PSScriptBuilderFileIOHelper]::EncodeUTF8WithBOM("content")
    #>
    static [byte[]] EncodeUTF8WithBOM([string] $content) {
        $encoding = [PSScriptBuilderFileIOHelper]::UTF8EncodingWithBOM
        $preamble = $encoding.GetPreamble()
        $body     = $encoding.GetBytes($content)

        $bytes = [byte[]]::new($preamble.Length + $body.Length)
        [Array]::Copy($preamble, 0, $bytes, 0, $preamble.Length)
        [Array]::Copy($body, 0, $bytes, $preamble.Length, $body.Length)
        return $bytes
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
        Files containing such bytes are returned as potentially problematic: PSScriptBuilder reads
        them correctly regardless of BOM presence, but other tools that assume a system codepage
        for BOM-less files (e.g. some editors or diff tools on non-UTF8 systems) may still
        misrender their non-ASCII characters.

        Files with only ASCII content (bytes <= 0x7F) are unaffected regardless of BOM and are not
        returned. Files that are null, empty, do not exist, or have no content are silently skipped.
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

    <#
    .SYNOPSIS
        Computes the SHA256 hash of a file.
    .DESCRIPTION
        The ComputeSHA256Hash method reads the file at filePath as a stream and returns its SHA256
        hash as an uppercase hexadecimal string - the same format Get-FileHash returns.
        Throws IOException (including FileNotFoundException) or UnauthorizedAccessException if
        the file cannot be read.
        Uses the .NET hashing API instead of Get-FileHash, because in Windows PowerShell 5.1
        Get-FileHash reports read failures as non-specific exception types
        (WriteErrorException, ItemNotFoundException) that cannot be caught selectively.
    .PARAMETER filePath
        The absolute path to the file to hash. .NET resolves a relative path against the process
        working directory, not the PowerShell location, so callers resolve paths first.
    .OUTPUTS
        Returns the SHA256 hash as an uppercase hexadecimal string.
    .EXAMPLE
        $hash = [PSScriptBuilderFileIOHelper]::ComputeSHA256Hash("C:\Build\MyScript.ps1")
    #>
    static [string] ComputeSHA256Hash([string] $filePath) {
        $hashBytes = $null
        $stream    = [File]::OpenRead($filePath)

        try {
            $sha256 = [System.Security.Cryptography.SHA256]::Create()

            try {
                $hashBytes = $sha256.ComputeHash($stream)
            }
            finally {
                $sha256.Dispose()
            }
        }
        finally {
            $stream.Dispose()
        }

        $hexWithDashes = [BitConverter]::ToString($hashBytes)
        $hash          = $hexWithDashes.Replace('-', '')
        return $hash
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderFileIOHelper
