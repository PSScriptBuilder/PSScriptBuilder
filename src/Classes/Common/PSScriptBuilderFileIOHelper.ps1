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

    All methods use UTF8 encoding with BOM (Byte Order Mark) to ensure proper file format compatibility
    and strict validation for invalid bytes.
#>
class PSScriptBuilderFileIOHelper {
    #region Static Properties
    <#
    .SYNOPSIS
        Gets the standard UTF8 encoding used for all file operations.
    .DESCRIPTION
        The utf8EncodingWithBOM static property provides a UTF8Encoding instance with BOM enabled and 
        strict byte validation.
        This is the standard encoding used throughout the project.
    #>
    static [UTF8Encoding] $utf8EncodingWithBOM = [UTF8Encoding]::new($true, $true)
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
        return [File]::ReadAllText($filePath, [PSScriptBuilderFileIOHelper]::utf8EncodingWithBOM)
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
        [File]::WriteAllText($filePath, $content, [PSScriptBuilderFileIOHelper]::utf8EncodingWithBOM)
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
        [File]::AppendAllText($filePath, $content, [PSScriptBuilderFileIOHelper]::utf8EncodingWithBOM)
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderFileIOHelper
