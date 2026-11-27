using namespace System
using namespace System.Collections
using namespace System.IO

#region Class PSScriptBuilderFileTransactionEntry
<#
.SYNOPSIS
    Represents one file of a PSScriptBuilderFileTransaction and performs the operations on it.
.DESCRIPTION
    The PSScriptBuilderFileTransactionEntry holds the path of a file, the content the change was
    prepared from (Replace only) and the content to write, and - while the transaction is
    committed - the open handle and the backup of the file. It performs every operation that
    concerns only its own file; PSScriptBuilderFileTransaction controls the order of the
    operations across all entries.

    An entry removes only what it created itself: the backup it wrote and, for Create, the file it
    created. A file that already existed or a backup left by an earlier run is never deleted.
    Failures of Restore, DeleteIfCreated and RemoveBackup are thrown as IOException whose message
    already names the file and its backup, so the transaction only collects the messages.
#>
class PSScriptBuilderFileTransactionEntry {
    #region Static Fields
    <#
    .SYNOPSIS
        The suffix of the backup file created next to a replaced file.
    .DESCRIPTION
        The backup of a file is written to the file's own path plus this suffix, in the same
        directory: it is on the same volume, cannot collide with the backup of a file of the same
        name in another folder, and is found next to the file after a failed restore or a crash
        (see RFC 0026).
    #>
    hidden static [string] $BackupSuffix = '.psscriptbuilder-backup'
    #endregion Static Fields

    #region Properties
    <#
    .SYNOPSIS
        The kind of change applied to the file.
    .DESCRIPTION
        The ChangeType property is Replace for an existing file that gets new content, or Create
        for a new file. It is set only by the constructor.
    #>
    [PSScriptBuilderFileChangeType] $ChangeType

    <#
    .SYNOPSIS
        The full path to the file.
    .DESCRIPTION
        The Path property holds the absolute, normalized path of the file, as passed by
        PSScriptBuilderFileTransaction.
    #>
    [string] $Path

    <#
    .SYNOPSIS
        The content the change was prepared from.
    .DESCRIPTION
        The ExpectedBytes property holds the bytes the caller read when preparing the change.
        IsUnchanged() compares the current content with it. It is $null for Create.
    #>
    [byte[]] $ExpectedBytes

    <#
    .SYNOPSIS
        The content to write.
    .DESCRIPTION
        The NewBytes property holds the bytes Write() writes to the file.
    #>
    [byte[]] $NewBytes

    <#
    .SYNOPSIS
        The open handle of the file while the transaction is committed.
    .DESCRIPTION
        The Stream property holds the handle opened by Open() with read and write access, shared
        for reading only, so no other process can change the file until Close(). It is $null
        before Open() and after Close().
    #>
    hidden [FileStream] $Stream

    <#
    .SYNOPSIS
        The path of the backup this entry created.
    .DESCRIPTION
        The BackupPath property is set by Backup() once the backup was written and reset by
        RemoveBackup(). It stays $null when Backup() found an existing backup, so that backup is
        never deleted by this entry.
    #>
    hidden [string] $BackupPath

    <#
    .SYNOPSIS
        Whether this entry created the file.
    .DESCRIPTION
        The IsCreated property is set by Open() only after a Create succeeded, so DeleteIfCreated()
        never deletes a file that existed before.
    #>
    hidden [bool] $IsCreated
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderFileTransactionEntry.
    .DESCRIPTION
        All values are required, so the change type is never left at its default. The values are
        validated by PSScriptBuilderFileTransaction, which creates the entries.
    .PARAMETER changeType
        Replace for an existing file, Create for a new file.
    .PARAMETER path
        The absolute, normalized path to the file.
    .PARAMETER expectedBytes
        The content the change was prepared from; $null for Create.
    .PARAMETER newBytes
        The content to write.
    #>
    PSScriptBuilderFileTransactionEntry([PSScriptBuilderFileChangeType] $changeType, [string] $path, [byte[]] $expectedBytes, [byte[]] $newBytes) {
        $this.ChangeType    = $changeType
        $this.Path          = $path
        $this.ExpectedBytes = $expectedBytes
        $this.NewBytes      = $newBytes
        $this.Stream        = $null
        $this.BackupPath    = $null
        $this.IsCreated     = $false
    }
    #endregion Constructors

    #region Static Methods
    <#
    .SYNOPSIS
        Returns the exception that actually caused a failure.
    .DESCRIPTION
        The UnwrapException method returns the inner exception of a MethodInvocationException, which
        PowerShell wraps around an exception thrown by a .NET call (e.g. "Exception calling ".ctor" with
        "4" argument(s): ..."), and the exception itself otherwise. Nested wrappers are unwrapped as
        well. Used so messages show the cause and a specific exception such as IOException is passed on
        instead of the wrapper.
    .PARAMETER exception
        The caught exception.
    .OUTPUTS
        Returns the causing exception as Exception.
    #>
    hidden static [Exception] UnwrapException([Exception] $exception) {
        $cause = $exception

        while ($cause -is [System.Management.Automation.MethodInvocationException] -and $null -ne $cause.InnerException) {
            $cause = $cause.InnerException
        }

        return $cause
    }
    #endregion Static Methods

    #region Methods
    <#
    .SYNOPSIS
        Opens the file for writing, or creates it exclusively.
    .DESCRIPTION
        The Open method opens an existing file (Replace) with read and write access, shared for
        reading only, or creates a new file (Create) with FileMode.CreateNew, which fails if the
        file already exists - in one step, without a separate existence check that another process
        could outrun. For Create, the directory is created first if necessary. A read-only, locked
        or - for Create - existing file throws here, before any file of the transaction is changed.
    #>
    [void] Open() {
        if ($this.ChangeType -eq [PSScriptBuilderFileChangeType]::Create) {
            $directory      = [Path]::GetDirectoryName($this.Path)
            $null           = [Directory]::CreateDirectory($directory)
            $this.Stream    = [FileStream]::new($this.Path, [FileMode]::CreateNew, [FileAccess]::ReadWrite, [FileShare]::Read)
            $this.IsCreated = $true
            return
        }

        $this.Stream = [FileStream]::new($this.Path, [FileMode]::Open, [FileAccess]::ReadWrite, [FileShare]::Read)
    }

    <#
    .SYNOPSIS
        Checks whether the file still has the content the change was prepared from.
    .DESCRIPTION
        The IsUnchanged method reads the current content through the open handle and compares it
        byte by byte with ExpectedBytes. The content is read in a loop, because FileStream.Read may
        return fewer bytes than requested. Must be called after Open() and only for Replace.
    .OUTPUTS
        Returns $true if the content equals ExpectedBytes, $false otherwise, as bool.
    #>
    [bool] IsUnchanged() {
        $currentBytes = [byte[]]::new($this.Stream.Length)
        $offset       = 0
        $this.Stream.Position = 0

        while ($offset -lt $currentBytes.Length) {
            $read = $this.Stream.Read($currentBytes, $offset, $currentBytes.Length - $offset)

            if ($read -eq 0) {
                break
            }

            $offset += $read
        }

        $isUnchanged = [StructuralComparisons]::StructuralEqualityComparer.Equals($currentBytes, $this.ExpectedBytes)
        return $isUnchanged
    }

    <#
    .SYNOPSIS
        Copies the file to its backup next to itself.
    .DESCRIPTION
        The Backup method copies the file to its path plus BackupSuffix. If that backup already
        exists, a previous run did not complete and the backup may be the only copy of the original,
        so the method throws without touching it. The copy is made while the handle is held; the
        handle shares read access, so the copy can read the file.
    #>
    [void] Backup() {
        # A local variable must not be named like the BackupPath property in a PowerShell class
        $newBackupPath = $this.Path + [PSScriptBuilderFileTransactionEntry]::BackupSuffix

        if ([File]::Exists($newBackupPath)) {
            $format  = "The backup '{0}' already exists - a previous run did not complete. Compare it with '{1}', keep the correct content, and delete the backup. No file was changed."
            $message = $format -f $newBackupPath, $this.Path
            throw [IOException]::new($message)
        }

        [File]::Copy($this.Path, $newBackupPath, $false)
        $this.BackupPath = $newBackupPath
    }

    <#
    .SYNOPSIS
        Writes the new content to the file.
    .DESCRIPTION
        The Write method replaces the file's content with NewBytes through the open handle and
        flushes it to disk. Writing through the handle keeps hard and symbolic links, attributes
        and the creation time of the file, unlike replacing the file (see RFC 0026).
    #>
    [void] Write() {
        $this.WriteBytes($this.NewBytes)
    }

    <#
    .SYNOPSIS
        Restores the file from its backup.
    .DESCRIPTION
        The Restore method writes the content of the backup back through the open handle. Only
        valid for Replace after Backup() succeeded. A failure is thrown as IOException naming the
        file and its backup, which the caller must keep.
    #>
    [void] Restore() {
        try {
            $backupBytes = [File]::ReadAllBytes($this.BackupPath)
            $this.WriteBytes($backupBytes)
        }
        catch {
            $format  = "'{0}' could not be restored from its backup '{1}' ({2})."
            $cause   = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
            $message = $format -f $this.Path, $this.BackupPath, $cause.Message
            throw [IOException]::new($message, $cause)
        }
    }

    <#
    .SYNOPSIS
        Closes the handle of the file.
    .DESCRIPTION
        The Close method disposes the handle opened by Open(). It can be called more than once and
        before Open(); it does nothing then.
    #>
    [void] Close() {
        if ($null -eq $this.Stream) {
            return
        }

        $this.Stream.Dispose()
        $this.Stream = $null
    }

    <#
    .SYNOPSIS
        Deletes the file if this entry created it.
    .DESCRIPTION
        The DeleteIfCreated method deletes the file only if Open() created it (IsCreated), never a
        file that existed before. Must be called after Close(). A failure is thrown as IOException
        naming the file.
    #>
    [void] DeleteIfCreated() {
        if (-not $this.IsCreated) {
            return
        }

        try {
            [File]::Delete($this.Path)
            $this.IsCreated = $false
        }
        catch {
            $format  = "'{0}' was created by this run but could not be deleted ({1})."
            $cause   = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
            $message = $format -f $this.Path, $cause.Message
            throw [IOException]::new($message, $cause)
        }
    }

    <#
    .SYNOPSIS
        Deletes the backup if this entry created it.
    .DESCRIPTION
        The RemoveBackup method deletes the backup written by Backup() (BackupPath), never a backup
        left by an earlier run. A failure is thrown as IOException naming the backup and that the
        file itself is correct.
    #>
    [void] RemoveBackup() {
        # Assigning $null to a [string] property stores an empty string in a PowerShell class
        if ([string]::IsNullOrEmpty($this.BackupPath)) {
            return
        }

        try {
            [File]::Delete($this.BackupPath)
            $this.BackupPath = $null
        }
        catch {
            $format  = "The backup '{0}' could not be deleted ({1}). '{2}' is correct - delete the backup, otherwise the next run stops."
            $cause   = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
            $message = $format -f $this.BackupPath, $cause.Message, $this.Path
            throw [IOException]::new($message, $cause)
        }
    }

    <#
    .SYNOPSIS
        Replaces the file's content with the given bytes.
    .DESCRIPTION
        The WriteBytes method truncates the file through the open handle, writes the bytes and
        flushes them to disk, so the content is persisted before the next file is written.
    .PARAMETER bytes
        The content to write.
    #>
    hidden [void] WriteBytes([byte[]] $bytes) {
        $this.Stream.SetLength(0)
        $this.Stream.Write($bytes, 0, $bytes.Length)
        $this.Stream.Flush($true)
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderFileTransactionEntry
