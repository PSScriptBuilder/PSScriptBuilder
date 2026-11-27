using namespace System
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderFileSystemHelper
<#
.SYNOPSIS
    Helper class for file system operations.
.DESCRIPTION
    The PSScriptBuilderFileSystemHelper class provides static methods to assist with common file system tasks, such as
    ensuring directories exist, building project-rooted paths, naming build backups and comparing paths.
#>
class PSScriptBuilderFileSystemHelper {
    #region Methods
    <#
    .SYNOPSIS
        Ensures that the specified directory exists, creating it and its parents if necessary.
    .DESCRIPTION
        The EnsureDirectoryExists method creates the directory with Directory.CreateDirectory, which creates
        missing parent directories and does nothing if the directory already exists. A file in the way throws
        IOException naming the blocking path segment, also when it is a parent directory. .NET file APIs are
        used instead of New-Item, so the caller's -WhatIf and -Confirm do not apply: callers run inside their
        cmdlet's confirmed branch (RFC 0026). The path must be absolute, because .NET resolves a relative path
        against the process working directory, not the PowerShell location.
    .PARAMETER path
        The absolute path of the directory.
    #>
    static [void] EnsureDirectoryExists([string] $path) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            $message = "Parameter 'path' cannot be null or empty."
            throw [ArgumentException]::new($message, "path")
        }

        if (-not [Path]::IsPathRooted($path)) {
            $format  = "The path '{0}' must be absolute."
            $message = $format -f $path
            throw [ArgumentException]::new($message, "path")
        }

        $null = [Directory]::CreateDirectory($path)
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

        # Retrieve project root via cmdlet - triggers auto-discovery if $Global: is not set
        $projectRoot  = Get-PSScriptBuilderProjectRoot
        $combinedPath = [Path]::Combine($projectRoot, $normalizedPath)

        # Normalize path to resolve any . or .. components
        $fullPath = [Path]::GetFullPath($combinedPath)

        return $fullPath
    }

    <#
    .SYNOPSIS
        Resolves a path against the current PowerShell location and ensures it is a file system path.
    .DESCRIPTION
        The ResolveFileSystemPath method resolves a relative path against the current PowerShell
        location instead of the process working directory, which .NET uses and Set-Location does not
        change. The path does not need to exist. A path on a drive of another provider, such as HKCU:
        or Env:, is rejected, since its provider path is not a file system path and .NET would resolve
        it against the process working directory again; this includes '.' while the current location
        is on such a drive. The path is returned as Windows resolves it, without trailing spaces or
        dots in its last segment and without 8.3 short names of existing directories, so paths
        combined from it name the same directory. The caller passes its path intrinsics
        ($PSCmdlet.SessionState.Path), because a class method has no access to the session state
        (RFC 0028).
    .PARAMETER pathIntrinsics
        The path intrinsics of the calling command, which know the current PowerShell location.
    .PARAMETER path
        The path to resolve, absolute or relative to the current PowerShell location.
    .OUTPUTS
        Returns the absolute file system path as a string.
    #>
    static [string] ResolveFileSystemPath([System.Management.Automation.PathIntrinsics] $pathIntrinsics, [string] $path) {
        $provider     = $null
        $drive        = $null
        $resolvedPath = $pathIntrinsics.GetUnresolvedProviderPathFromPSPath($path, [ref] $provider, [ref] $drive)

        if ($provider.Name -ne 'FileSystem') {
            $format  = "The path '{0}' resolves to '{1}' of the {2} provider, not to a file system path. Specify a directory on a file system drive."
            $message = $format -f $path, $resolvedPath, $provider.Name
            throw [ArgumentException]::new($message, 'path')
        }

        # A trailing space would otherwise remain in every path combined from this one
        $fullPath = [Path]::GetFullPath($resolvedPath)

        return $fullPath
    }

    <#
    .SYNOPSIS
        Converts an absolute path to a project-relative path.
    .DESCRIPTION
        The GetProjectRelativePath method checks whether the provided absolute path starts with
        the project root stored in $Global:PSScriptBuilderProjectRoot. If it does, the project
        root prefix (including the trailing separator) is removed and the relative path is
        returned. If the path does not start with the project root, or if no project root is
        set, the original path is returned unchanged.

        The comparison is case-insensitive to handle Windows file systems correctly.
        A trailing separator is always appended to the normalized root before comparison to
        prevent false-positive prefix matches (e.g. /MyProject_backup matching /MyProject).
    .PARAMETER absolutePath
        The absolute path to convert to a project-relative path as a string.
    .OUTPUTS
        Returns the project-relative path as a string, or the original path if it cannot be
        made relative.
    #>
    static [string] GetProjectRelativePath([string] $absolutePath) {
        $projectRoot = $Global:PSScriptBuilderProjectRoot

        if ([string]::IsNullOrEmpty($projectRoot)) {
            return $absolutePath
        }

        $normalizedAbsolutePath = $absolutePath.Replace('\', [char][Path]::DirectorySeparatorChar)
        $normalizedRoot         = $projectRoot.TrimEnd('\', '/').Replace('\', [char][Path]::DirectorySeparatorChar) + [Path]::DirectorySeparatorChar

        if ($normalizedAbsolutePath.StartsWith($normalizedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            return $absolutePath.Substring($normalizedRoot.Length)
        }

        return $absolutePath
    }

    <#
    .SYNOPSIS
        Generates a timestamped backup filename.
    .DESCRIPTION
        The NewBackupFileName method creates a backup filename by appending a timestamp to the
        original filename. This ensures unique backup files and prevents overwrites.

        Pattern: {OriginalFileName}.{Timestamp}.bak
        Example: PSScriptBuilder.psm1.260304_182045.bak

        The timestamp format (yyMMdd_HHmmss) is sortable and compact.
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
        Returns the comparer for file paths on the current platform.
    .DESCRIPTION
        The GetPathComparer method returns StringComparer.OrdinalIgnoreCase on Windows, whose file
        systems ignore letter case, and StringComparer.Ordinal on Unix-like systems. macOS is
        reported as Unix by .NET and therefore compared case-sensitively, although most macOS
        volumes ignore letter case; it cannot be told apart reliably inside a class (see the known
        limits in RFC 0026). Used wherever file paths are grouped or checked for duplicates, so
        they are compared the same way everywhere.
    .OUTPUTS
        Returns the comparer as StringComparer.
    #>
    static [StringComparer] GetPathComparer() {
        $comparer = [StringComparer]::OrdinalIgnoreCase

        if ([Environment]::OSVersion.Platform -eq [PlatformID]::Unix) {
            $comparer = [StringComparer]::Ordinal
        }

        return $comparer
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderFileSystemHelper
