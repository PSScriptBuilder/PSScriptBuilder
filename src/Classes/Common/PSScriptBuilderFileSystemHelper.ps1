using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderFileSystemHelper
<#
.SYNOPSIS
    Helper class for file system operations.
.DESCRIPTION
    The PSScriptBuilderFileSystemHelper class provides static methods to assist with common file system tasks, such as 
    ensuring directories exist.
#>
class PSScriptBuilderFileSystemHelper {
    #region Methods
    <#
    .SYNOPSIS
        Ensures that the specified directory path exists, creating it if necessary.
    .DESCRIPTION
        The EnsureDirectoryExists method checks if the given path exists as a directory. If it does not exist, 
        the method creates the directory along with any necessary parent directories recursively.
    .PARAMETER path
        The path to ensure exists as a string.
        This can be either an absolute or relative path.
        This can also be a file path; in that case, the parent directory will be created.
    #>
    static [void] EnsureDirectoryExists([string] $path) {
        # Convert to absolute path if necessary
        if (-not [Path]::IsPathRooted($path)) {
            $path = [Path]::GetFullPath($path)
        }

        # Check if the path is an existing directory and return if so
        if (Test-Path $path -PathType Container) {
            return
        }

        # If not, extract parent from path
        $parent = Split-Path $path -Parent

        # If parent is valid, ensure it exists
        # This is done recursively to create all necessary parent directories
        if ($parent -and -not (Test-Path $parent -PathType Container)) {
            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($parent)
        }

        # Create the directory
        if (-not (Test-Path $path -PathType Container)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }

    <#
    .SYNOPSIS
        Ensures that the specified file exists, creating it and its parent directory if necessary, and writes 
        content if provided.
    .DESCRIPTION
        The EnsureFileExists method checks if the given file exists. If not, it ensures the parent directory 
        exists (using EnsureDirectoryExists) and then creates the file with the specified content (or empty 
        if none).
    .PARAMETER filePath
        The file path to ensure exists as a string.
    .PARAMETER content
        The content to write to the file if it is created.
    #>
    static [void] EnsureFileExists([string] $filePath, [string] $content) {
        # Convert to absolute path if necessary
        if (-not [Path]::IsPathRooted($filePath)) {
            $filePath = [Path]::GetFullPath($filePath)
        }

        # If file already exists, nothing to do
        if (Test-Path $filePath -PathType Leaf) {
            return
        }

        # Extract directory from file path
        $directory = Split-Path $filePath -Parent

        # If directory is valid, ensure it exists
        if ($directory) {
            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($directory)
        }

        # Create file with content or empty
        if ($null -ne $content) {
            $utf8EncodingWithBOM = [UTF8Encoding]::new($true, $true)
            [File]::WriteAllText($filePath, $content, $utf8EncodingWithBOM)
        } 
        else {
            New-Item -Path $filePath -ItemType File -Force | Out-Null
        }
    }

    <#
    .SYNOPSIS
        Ensures that the specified file exists, creating it and its parent directory if necessary.
    .DESCRIPTION
        The EnsureFileExists method checks if the given file exists. If not, it ensures the parent directory 
        exists (using EnsureDirectoryExists) and then creates an empty file.
    .PARAMETER filePath
        The file path to ensure exists as a string.
    #>
    static [void] EnsureFileExists([string] $filePath) {
        [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath, $null)
    }

    <#
    .SYNOPSIS
        Converts a relative path to an absolute path rooted at the project root.
    .DESCRIPTION
        The GetProjectRootedPath method checks if the provided path is already rooted. If it is, it returns
        the path as is. If not, it retrieves the project root via Get-PSScriptBuilderProjectRoot (which
        triggers auto-discovery if no root has been set explicitly) and combines it with the relative path.
    .PARAMETER path
        The path to convert to a project-rooted absolute path as a string.
    .OUTPUTS
        Return the absolute path rooted at the project root as a string.
    #>
    static [string] GetProjectRootedPath([string] $path) {
        if ([Path]::IsPathRooted($path)) {
            return $path
        }

        # Normalize path separators for cross-platform compatibility (backslashes from Windows config files)
        $normalizedPath = $path.Replace('\', [char][Path]::DirectorySeparatorChar)

        # Retrieve project root via cmdlet — triggers auto-discovery if $Global: is not set
        $projectRoot  = Get-PSScriptBuilderProjectRoot
        $combinedPath = [Path]::Combine($projectRoot, $normalizedPath)

        # Normalize path to resolve any . or .. components
        $fullPath = [Path]::GetFullPath($combinedPath)

        return $fullPath
    }

    <#
    .SYNOPSIS
        Creates a concise, unique backup directory name.
    .DESCRIPTION
        The NewBackupDirectoryName static method generates a backup directory name with the format:
        PSScriptBuilder_Backup_yyMMdd_HHmmss_shortGuid (e.g., PSScriptBuilder_Backup_260205_143025_a1b2c3d4)

        This format ensures uniqueness while remaining compact and human-readable. The name is sortable by 
        timestamp and can be easily identified in temp directories.
    .OUTPUTS
        Returns a unique directory name string suitable for use in temporary storage.
    #>
    static [string] NewBackupDirectoryName() {
        $dateTime = Get-Date -Format "yyMMdd_HHmmss"
        $miniGuid = [Guid]::NewGuid().ToString().Substring(0, 8)

        $format = "PSScriptBuilder_Backup_{0}_{1}"
        $result = [string]::Format($format, $dateTime, $miniGuid)

        return $result
    }

    <#
    .SYNOPSIS
        Generates a timestamped backup filename.
    .DESCRIPTION
        The NewBackupFileName method creates a backup filename by appending a timestamp to the
        original filename. This ensures unique backup files and prevents overwrites.
        
        Pattern: {OriginalFileName}.{Timestamp}.bak
        Example: PSScriptBuilder.psm1.260304_182045.bak
        
        The timestamp format (yyMMdd_HHmmss) matches the format used by NewBackupDirectoryName()
        for consistency across backup operations.
    .PARAMETER filePath
        The path to the original file. Only the filename component is used.
    .OUTPUTS
        Returns the generated backup filename (without directory path) as a string.
    #>
    static [string] NewBackupFileName([string] $filePath) {
        $fileName  = [Path]::GetFileName($filePath)
        $timestamp = Get-Date -Format "yyMMdd_HHmmss"

        $format = "{0}.{1}.bak"
        $result = [string]::Format($format, $fileName, $timestamp)

        return $result
    }

    <#
    .SYNOPSIS
        Truncates a file path to a maximum length with ellipsis in the middle.
    .DESCRIPTION
        The GetTruncatedPath method truncates long file paths to a maximum length by keeping the beginning 
        and end of the path and inserting "..." in the middle. This is useful for displaying paths in 
        verbose output without making the output too long.
        
        If the path is shorter than or equal to the maximum length, it is returned unchanged.
        If truncation is needed, components from the beginning and end are kept, with "..." replacing 
        the middle section.
        
        Example:
        C:\Data\_GIT\Privat\PSScriptBuilder\src\Classes\ReleaseManagement\Managers\Deep\file.json
        -> C:\Data\_GIT\...\Deep\file.json (if maxLength=60)
    .PARAMETER path
        The file path to truncate as a string.
    .PARAMETER maxLength
        The maximum length of the returned path as an integer.
    .OUTPUTS
        Returns the truncated or original path as a string.
    #>
    static [string] GetTruncatedPath([string] $path, [int] $maxLength) {
        if ($path.Length -le $maxLength) {
            return $path
        }

        # Path needs truncation
        $ellipsis = "..."
        $availableLength = $maxLength - $ellipsis.Length

        # Split path into components
        $pathSeparator = [char][Path]::DirectorySeparatorChar
        $components    = $path -split [regex]::Escape($pathSeparator)

        # Build from start and end until we reach availableLength
        $frontParts  = @()
        $backParts   = @()
        $frontLength = 0
        $backLength  = 0

        # Build front part
        foreach ($component in $components) {
            $testLength = $frontLength + $component.Length + 1  # +1 for path separator

            if ($testLength -le ($availableLength / 2)) {
                $frontParts += $component
                $frontLength = $testLength
            } 
            else {
                break
            }
        }

        # Build back part (from end)
        for ($i = $components.Count - 1; $i -ge 0; $i--) {
            $component = $components[$i]
            $testLength = $backLength + $component.Length + 1  # +1 for path separator

            if ($testLength -le ($availableLength / 2)) {
                $backParts  = @($component) + $backParts
                $backLength = $testLength
            } 
            else {
                break
            }
        }

        # Build result
        $front = $frontParts -join $pathSeparator
        $back  = $backParts -join $pathSeparator

        if ($front -and $back) {
            return "$front$pathSeparator$ellipsis$pathSeparator$back"
        } 
        elseif ($back) {
            return "$ellipsis$pathSeparator$back"
        } 
        else {
            return $path.Substring(0, [Math]::Min($maxLength - $ellipsis.Length, $path.Length)) + $ellipsis
        }
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderFileSystemHelper
