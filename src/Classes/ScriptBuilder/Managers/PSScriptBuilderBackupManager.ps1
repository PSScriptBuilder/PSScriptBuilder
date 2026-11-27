using namespace System
using namespace System.IO

#region Class PSScriptBuilderBackupManager
<#
.SYNOPSIS
    Manages backup and restore operations for build output files.
.DESCRIPTION
    The PSScriptBuilderBackupManager provides static methods for creating and restoring backups of build output files.
    Backups are stored with timestamp naming to ensure uniqueness and prevent overwrites.
    The manager uses PSScriptBuilderFileIOHelper for consistent UTF8 encoding.
#>
class PSScriptBuilderBackupManager {
    #region Static Methods
    <#
    .SYNOPSIS
        Creates a backup of the specified file.
    .DESCRIPTION
        The CreateBackup method copies the specified file to the backup directory with a timestamped filename.
        The backup directory is created if it does not exist.

        Backup naming pattern: {OriginalFileName}.{Timestamp}.bak
        Example: PSScriptBuilder.psm1.260302_153045.bak

        If the source file does not exist, null is returned and a verbose message is logged.
    .PARAMETER filePath
        The absolute path to the file to backup.
    .PARAMETER backupDirectoryPath
        The absolute path to the backup directory where the backup will be stored.
    .OUTPUTS
        Returns the full path to the created backup file, or null if no backup was created.
    #>
    static [string] CreateBackup([string] $filePath, [string] $backupDirectoryPath) {
        # Validate parameters
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            $message = "Parameter 'filePath' cannot be null or empty."
            throw [ArgumentException]::new($message, "filePath")
        }

        if ([string]::IsNullOrWhiteSpace($backupDirectoryPath)) {
            $message = "Parameter 'backupDirectoryPath' cannot be null or empty."
            throw [ArgumentException]::new($message, "backupDirectoryPath")
        }

        # Resolve paths to absolute
        $resolvedFilePath  = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($filePath)
        $resolvedBackupDir = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($backupDirectoryPath)

        # Check if source file exists
        if (-not [File]::Exists($resolvedFilePath)) {
            Write-Verbose "No backup required (output file does not exist)"
            return $null
        }

        Write-Verbose "Creating backup of file: $filePath"

        # Generate backup filename
        $backupFileName = [PSScriptBuilderFileSystemHelper]::NewBackupFileName($resolvedFilePath)

        # Ensure backup directory exists
        [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($resolvedBackupDir)

        # Build full backup path
        $backupPath = [Path]::Combine($resolvedBackupDir, $backupFileName)

        # Copy file to backup location
        try {
            [File]::Copy($resolvedFilePath, $backupPath, $false)
            Write-Verbose "  Backup created: $backupPath"
            return $backupPath
        }
        catch {
            $format  = "Failed to create backup of file: {0}. Error: {1}"
            $message = $format -f $resolvedFilePath, $_.Exception.Message
            throw [IOException]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Restores a backup file to the specified target location.
    .DESCRIPTION
        The RestoreBackup method copies a backup file back to its original location (or a specified target).
        The backup file is retained after restore for debugging purposes.

        If the backup file does not exist, a FileNotFoundException is thrown.
        If the target file exists, it will be overwritten.
    .PARAMETER backupPath
        The absolute path to the backup file to restore.
    .PARAMETER targetPath
        The absolute path where the backup should be restored.
    #>
    static [void] RestoreBackup([string] $backupPath, [string] $targetPath) {
        # Validate parameters
        if ([string]::IsNullOrWhiteSpace($backupPath)) {
            $message = "Parameter 'backupPath' cannot be null or empty."
            throw [ArgumentException]::new($message, "backupPath")
        }

        if ([string]::IsNullOrWhiteSpace($targetPath)) {
            $message = "Parameter 'targetPath' cannot be null or empty."
            throw [ArgumentException]::new($message, "targetPath")
        }

        Write-Verbose "Restoring backup from: $backupPath"

        # Resolve paths to absolute
        $resolvedBackupPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($backupPath)
        $resolvedTargetPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($targetPath)

        # Check if backup file exists
        if (-not [File]::Exists($resolvedBackupPath)) {
            $format  = "Cannot restore backup: Backup file not found: {0}"
            $message = $format -f $resolvedBackupPath
            throw [FileNotFoundException]::new($message, $resolvedBackupPath)
        }

        # Ensure target directory exists
        $targetDirectory = [Path]::GetDirectoryName($resolvedTargetPath)

        if ($targetDirectory) {
            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($targetDirectory)
        }

        # Copy backup to target location (overwrite if exists)
        try {
            [File]::Copy($resolvedBackupPath, $resolvedTargetPath, $true)
            Write-Verbose "  Backup restored to: $resolvedTargetPath"
            Write-Verbose "  Backup file retained for debugging: $resolvedBackupPath"
        }
        catch {
            $format  = "Failed to restore backup from: {0} to: {1}. Error: {2}"
            $message = $format -f $resolvedBackupPath, $resolvedTargetPath, $_.Exception.Message
            throw [IOException]::new($message, $_.Exception)
        }
    }

    <#
    .SYNOPSIS
        Checks if a backup file exists.
    .DESCRIPTION
        The HasBackup method verifies whether a backup file exists at the specified path.
        It resolves relative paths to absolute paths before checking existence.
    .PARAMETER backupPath
        The absolute or relative path to the backup file.
    .OUTPUTS
        Returns $true if the backup file exists, $false otherwise.
    #>
    static [bool] HasBackup([string] $backupPath) {
        if ([string]::IsNullOrWhiteSpace($backupPath)) {
            return $false
        }

        try {
            $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($backupPath)
            return [File]::Exists($resolvedPath)
        }
        catch {
            return $false
        }
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderBackupManager
