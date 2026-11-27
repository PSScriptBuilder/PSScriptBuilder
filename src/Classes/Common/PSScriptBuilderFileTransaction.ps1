using namespace System
using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderFileTransaction
<#
.SYNOPSIS
    Writes a set of files as one transaction: all files are changed, or none.
.DESCRIPTION
    The PSScriptBuilderFileTransaction collects files to replace (AddReplace) or create (AddCreate)
    and writes them in Commit():
    1. open every file - a read-only, locked or already existing file fails before any change
    2. check that no file changed since its content was read (Optimistic Offline Lock)
    3. back up every replaced file next to itself
    4. write every file through its open handle
    5. on failure, restore every touched file from its backup and delete every created file
    Backups are removed after a successful commit or restore and kept otherwise, also when the
    commit is interrupted. Only .NET file APIs are used, so the caller's -WhatIf and -Confirm do
    not affect the individual steps - confirming the change is the calling cmdlet's
    responsibility. The operations on a single file are performed by
    PSScriptBuilderFileTransactionEntry. See RFC 0026.
#>
class PSScriptBuilderFileTransaction {
    #region Properties
    <#
    .SYNOPSIS
        The files of the transaction.
    .DESCRIPTION
        The Entries property holds one PSScriptBuilderFileTransactionEntry per added file, in the
        order the files were added; Commit() processes them in this order.
    #>
    hidden [List[PSScriptBuilderFileTransactionEntry]] $Entries

    <#
    .SYNOPSIS
        The full paths of the added files, for the duplicate check.
    .DESCRIPTION
        The EntryPaths property compares paths with the platform's path comparer (see
        PSScriptBuilderFileSystemHelper.GetPathComparer).
    #>
    hidden [HashSet[string]] $EntryPaths

    <#
    .SYNOPSIS
        Whether Commit() was called.
    .DESCRIPTION
        The IsCommitStarted property prevents adding files after, and committing more than once.
    #>
    hidden [bool] $IsCommitStarted
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes an empty transaction.
    .DESCRIPTION
        Creates the transaction without files. Paths are compared with the platform's path
        comparer, so a file added twice in a different letter case is detected on Windows.
    #>
    PSScriptBuilderFileTransaction() {
        $this.Entries         = [List[PSScriptBuilderFileTransactionEntry]]::new()
        $this.EntryPaths      = [HashSet[string]]::new([PSScriptBuilderFileSystemHelper]::GetPathComparer())
        $this.IsCommitStarted = $false
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Adds an existing file to replace.
    .DESCRIPTION
        The AddReplace method registers a file whose content is replaced by newBytes. Commit()
        fails without changing any file if the file no longer has expectedBytes at that time.
    .PARAMETER path
        The absolute path to the file.
    .PARAMETER expectedBytes
        The content the caller read when preparing the change.
    .PARAMETER newBytes
        The content to write.
    #>
    [void] AddReplace([string] $path, [byte[]] $expectedBytes, [byte[]] $newBytes) {
        if ($null -eq $expectedBytes) {
            $message = "Parameter 'expectedBytes' cannot be null."
            throw [ArgumentNullException]::new("expectedBytes", $message)
        }

        $this.AddEntry([PSScriptBuilderFileChangeType]::Replace, $path, $expectedBytes, $newBytes)
    }

    <#
    .SYNOPSIS
        Adds a file to create.
    .DESCRIPTION
        The AddCreate method registers a new file. Commit() fails without changing any file if the
        file exists at that time.
    .PARAMETER path
        The absolute path to the file. Its directory is created if necessary.
    .PARAMETER newBytes
        The content to write.
    #>
    [void] AddCreate([string] $path, [byte[]] $newBytes) {
        $this.AddEntry([PSScriptBuilderFileChangeType]::Create, $path, $null, $newBytes)
    }

    <#
    .SYNOPSIS
        Writes all files of the transaction, or none.
    .DESCRIPTION
        The Commit method opens, checks, backs up and writes all files; if writing fails, it
        restores every touched file and deletes every created file. Handles are closed in a finally
        block, so they are released also when the commit is interrupted. Backups are deleted only
        after a successful commit or restore - never in the finally block - so an interrupted
        commit keeps them and the next run reports them. The exception is thrown only after all
        cleanup, so its message states what actually happened:
        - failed before any file was changed: the specific exception
        - failed while writing, all files restored: IOException with the cause as inner exception
        - restoring or deleting failed: IOException naming every affected file and backup
        - backups could not be deleted after an otherwise handled failure: IOException naming them
        A transaction can be committed only once.
    .OUTPUTS
        Returns warnings as string[] - backups that could not be deleted after a successful commit
        (the files are correct); an empty array otherwise. The calling cmdlet writes them, since
        warnings written inside class methods are not collected by -WarningVariable.
    #>
    [string[]] Commit() {
        if ($this.IsCommitStarted) {
            $message = "The transaction has already been committed."
            throw [InvalidOperationException]::new($message)
        }

        $this.IsCommitStarted = $true
        $failure              = $null
        $touched              = [List[PSScriptBuilderFileTransactionEntry]]::new()
        $problems             = [List[string]]::new()

        try {
            try {
                $this.OpenAll()
                $this.CheckAllUnchanged()
                $this.BackupAll()

                foreach ($entry in $this.Entries) {
                    $touched.Add($entry)
                    $entry.Write()
                }
            }
            catch {
                $failure = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
            }

            if ($null -ne $failure) {
                $problems.AddRange([string[]] $this.RestoreTouched($touched))
            }
        }
        finally {
            foreach ($entry in $this.Entries) {
                $entry.Close()
            }
        }

        if ($null -eq $failure) {
            $warnings = $this.RemoveAllBackups()
            return $warnings
        }

        $problems.AddRange([string[]] $this.DeleteAllCreated())
        if ($problems.Count -gt 0) {
            $format  = "Writing the files failed ({0}), and the cleanup failed too. The backups were kept:{1}{2}"
            $message = $format -f $failure.Message, [Environment]::NewLine, ($problems -join [Environment]::NewLine)
            throw [IOException]::new($message, $failure)
        }

        $leftoverBackups = $this.RemoveAllBackups()
        if ($leftoverBackups.Count -gt 0) {
            $format  = "Writing the files failed ({0}). The files were left unchanged or restored, but some backups could not be deleted:{1}{2}"
            $message = $format -f $failure.Message, [Environment]::NewLine, ($leftoverBackups -join [Environment]::NewLine)
            throw [IOException]::new($message, $failure)
        }

        if ($touched.Count -eq 0) {
            # Failed before any file was changed - the specific exception states why
            throw $failure
        }

        $format  = "Writing the files failed ({0}). All files were restored to their previous content."
        $message = $format -f $failure.Message
        throw [IOException]::new($message, $failure)
    }

    <#
    .SYNOPSIS
        Validates a file and adds it to the transaction.
    .DESCRIPTION
        The AddEntry method rejects files added after Commit(), empty or relative paths (.NET
        resolves a relative path against the process working directory, not the PowerShell
        location), a missing newBytes, and a file that is already part of the transaction -
        compared by full path with the platform's path comparer. The entry is created by NewEntry().
    .PARAMETER changeType
        Replace or Create.
    .PARAMETER path
        The absolute path to the file.
    .PARAMETER expectedBytes
        The content the change was prepared from; $null for Create.
    .PARAMETER newBytes
        The content to write.
    #>
    hidden [void] AddEntry([PSScriptBuilderFileChangeType] $changeType, [string] $path, [byte[]] $expectedBytes, [byte[]] $newBytes) {
        if ($this.IsCommitStarted) {
            $message = "Files cannot be added after the transaction was committed."
            throw [InvalidOperationException]::new($message)
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            $message = "Parameter 'path' cannot be null or empty."
            throw [ArgumentException]::new($message, "path")
        }

        if (-not [Path]::IsPathRooted($path)) {
            $format  = "The path '{0}' must be absolute."
            $message = $format -f $path
            throw [ArgumentException]::new($message, "path")
        }

        if ($null -eq $newBytes) {
            $message = "Parameter 'newBytes' cannot be null."
            throw [ArgumentNullException]::new("newBytes", $message)
        }

        $fullPath = [Path]::GetFullPath($path)
        if (-not $this.EntryPaths.Add($fullPath)) {
            $format  = "The file '{0}' is part of the transaction more than once - it may be configured twice, e.g. in a different letter case."
            $message = $format -f $path
            throw [ArgumentException]::new($message, "path")
        }

        $entry = $this.NewEntry($changeType, $fullPath, $expectedBytes, $newBytes)
        $this.Entries.Add($entry)
    }

    <#
    .SYNOPSIS
        Creates the entry for one file of the transaction.
    .DESCRIPTION
        The NewEntry method creates a PSScriptBuilderFileTransactionEntry. It is the only place where
        entries are created, so a derived class can supply a different entry - the unit tests use this
        to simulate a failure while writing, which cannot be produced with a real file once it is open
        (Factory Method).
    .PARAMETER changeType
        Replace or Create.
    .PARAMETER path
        The absolute, normalized path to the file.
    .PARAMETER expectedBytes
        The content the change was prepared from; $null for Create.
    .PARAMETER newBytes
        The content to write.
    .OUTPUTS
        Returns the new entry as PSScriptBuilderFileTransactionEntry.
    #>
    hidden [PSScriptBuilderFileTransactionEntry] NewEntry([PSScriptBuilderFileChangeType] $changeType, [string] $path, [byte[]] $expectedBytes, [byte[]] $newBytes) {
        $entry = [PSScriptBuilderFileTransactionEntry]::new($changeType, $path, $expectedBytes, $newBytes)
        return $entry
    }

    <#
    .SYNOPSIS
        Opens every file of the transaction.
    .DESCRIPTION
        The OpenAll method opens or creates every file; the first one that cannot be opened stops
        the commit before any file is changed. The message names the file and the likely causes.
    #>
    hidden [void] OpenAll() {
        foreach ($entry in $this.Entries) {
            try {
                $entry.Open()
            }
            catch [IOException], [UnauthorizedAccessException] {
                $cause   = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
                $format  = "The file '{0}' cannot be opened for writing ({1}) - it may be read-only, locked by another program, already exist, or be configured more than once (e.g. via a link). No file was changed."
                $message = $format -f $entry.Path, $cause.Message
                throw [IOException]::new($message, $cause)
            }
        }
    }

    <#
    .SYNOPSIS
        Checks that no file to replace changed since its content was read.
    .DESCRIPTION
        The CheckAllUnchanged method stops the commit before any file is changed if a file to
        replace no longer has the content the change was prepared from, e.g. because it was edited
        while a -Confirm prompt was open. Writing would otherwise overwrite that edit with content
        computed from the old state.
    #>
    hidden [void] CheckAllUnchanged() {
        foreach ($entry in $this.Entries) {
            if ($entry.ChangeType -ne [PSScriptBuilderFileChangeType]::Replace) {
                continue
            }

            if ($entry.IsUnchanged()) {
                continue
            }

            $format  = "The file '{0}' was changed after the changes were prepared. No file was changed - run the command again."
            $message = $format -f $entry.Path
            throw [InvalidOperationException]::new($message)
        }
    }

    <#
    .SYNOPSIS
        Backs up every file to replace.
    .DESCRIPTION
        The BackupAll method creates the backup of every file to replace before any file is
        written. An existing backup stops the commit; backups created so far are removed by
        Commit().
    #>
    hidden [void] BackupAll() {
        foreach ($entry in $this.Entries) {
            if ($entry.ChangeType -eq [PSScriptBuilderFileChangeType]::Replace) {
                $entry.Backup()
            }
        }
    }

    <#
    .SYNOPSIS
        Restores every touched file to replace from its backup.
    .DESCRIPTION
        The RestoreTouched method restores every entry that was about to be or was written,
        including one that failed while being written. A failing restore does not stop the others.
    .PARAMETER touched
        The entries Commit() started to write, in order.
    .OUTPUTS
        Returns one message per file that could not be restored as string[]; an empty array if all
        were restored.
    #>
    hidden [string[]] RestoreTouched([List[PSScriptBuilderFileTransactionEntry]] $touched) {
        $problems = [List[string]]::new()
        foreach ($entry in $touched) {
            if ($entry.ChangeType -ne [PSScriptBuilderFileChangeType]::Replace) {
                continue
            }

            try {
                $entry.Restore()
            }
            catch [IOException] {
                $cause = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
                $problems.Add($cause.Message)
            }
        }

        $result = $problems.ToArray()
        return $result
    }

    <#
    .SYNOPSIS
        Deletes every file the transaction created.
    .DESCRIPTION
        The DeleteAllCreated method deletes, after a failure, every file that Open() created -
        never a file that existed before. Must be called after the handles were closed. A failing
        deletion does not stop the others.
    .OUTPUTS
        Returns one message per file that could not be deleted as string[]; an empty array if all
        were deleted.
    #>
    hidden [string[]] DeleteAllCreated() {
        $problems = [List[string]]::new()

        foreach ($entry in $this.Entries) {
            try {
                $entry.DeleteIfCreated()
            }
            catch [IOException] {
                $cause = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
                $problems.Add($cause.Message)
            }
        }

        $result = $problems.ToArray()
        return $result
    }

    <#
    .SYNOPSIS
        Deletes every backup the transaction created.
    .DESCRIPTION
        The RemoveAllBackups method deletes the backups once they are no longer needed - after a
        successful commit or restore. A failing deletion does not stop the others.
    .OUTPUTS
        Returns one warning per backup that could not be deleted as string[]; an empty array if all
        were deleted.
    #>
    hidden [string[]] RemoveAllBackups() {
        $warnings = [List[string]]::new()

        foreach ($entry in $this.Entries) {
            try {
                $entry.RemoveBackup()
            }
            catch [IOException] {
                $cause = [PSScriptBuilderFileTransactionEntry]::UnwrapException($_.Exception)
                $warnings.Add($cause.Message)
            }
        }

        $result = $warnings.ToArray()
        return $result
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderFileTransaction
