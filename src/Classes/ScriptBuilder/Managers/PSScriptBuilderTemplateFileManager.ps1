using namespace System
using namespace System.IO

#region Class PSScriptBuilderTemplateFileManager
<#
.SYNOPSIS
    Manages loading and validation of template files.
.DESCRIPTION
    The PSScriptBuilderTemplateFileManager provides static methods for loading template files from disk.
    It encapsulates template file access logic and provides consistent error handling for template operations.
    Uses PSScriptBuilderFileIOHelper for consistent UTF8 encoding.
#>
class PSScriptBuilderTemplateFileManager {
    #region Static Methods
    <#
    .SYNOPSIS
        Loads a template file from the specified path.
    .DESCRIPTION
        The LoadTemplate method reads the template file from disk using UTF8 encoding with BOM.
        It validates that the file exists and that the content is not empty.
        If the file does not exist or is empty, an appropriate exception is thrown.
    .PARAMETER templatePath
        The absolute or relative path to the template file.
    .OUTPUTS
        Returns the template content as a string.
    .EXAMPLE
        $content = [PSScriptBuilderTemplateFileManager]::LoadTemplate(".\build\Templates\PSScriptBuilder.psm1.template")
    #>
    static [string] LoadTemplate([string] $templatePath) {
        Write-Verbose "Loading template from: $templatePath"

        if ([string]::IsNullOrWhiteSpace($templatePath)) {
            $message = "Parameter 'templatePath' cannot be null or empty."
            throw [ArgumentException]::new($message, "templatePath")
        }

        # Resolve to absolute path (relative to project root)
        $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($templatePath)

        # Check if file exists
        if (-not [File]::Exists($resolvedPath)) {
            $format  = "Template file not found: {0}"
            $message = $format -f $resolvedPath
            throw [FileNotFoundException]::new($message, $resolvedPath)
        }

        # Load template content
        try {
            $content = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($resolvedPath)

            if ([string]::IsNullOrWhiteSpace($content)) {
                $format  = "Template file is empty: {0}"
                $message = $format -f $resolvedPath
                throw [InvalidOperationException]::new($message)
            }

            Write-Verbose "Template loaded successfully: $($content.Length) character(s)"
            return $content
        }
        catch [InvalidOperationException] {
            # Re-throw empty file exception as-is
            throw
        }
        catch {
            $format  = "Failed to load template file: {0}. Error: {1}"
            $message = $format -f $resolvedPath, $_.Exception.Message
            throw [IOException]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Checks if a template file exists at the specified path.
    .DESCRIPTION
        The TemplateExists method verifies whether a template file exists at the given path.
        It resolves relative paths to absolute paths before checking existence.
    .PARAMETER templatePath
        The absolute or relative path to the template file.
    .OUTPUTS
        Returns $true if the file exists, $false otherwise.
    .EXAMPLE
        if ([PSScriptBuilderTemplateFileManager]::TemplateExists(".\template.psm1")) {
            # Load template
        }
    #>
    static [bool] TemplateExists([string] $templatePath) {
        if ([string]::IsNullOrWhiteSpace($templatePath)) {
            return $false
        }

        try {
            $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($templatePath)
            return [File]::Exists($resolvedPath)
        }
        catch {
            return $false
        }
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderTemplateFileManager
