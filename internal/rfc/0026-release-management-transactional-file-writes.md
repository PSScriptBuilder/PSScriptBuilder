# RFC 0026: Transactional File Writes in Release Management

- **Status:** Implemented (2026-11-05) — design agreed in review, then implemented; see Revision Log
- **Type:** Fix and design decision
- **Created:** 2026-11-05
- **Branch:** development

## Summary

`Update-PSScriptBuilderBumpFiles` can leave a project half bumped: when writing fails part-way
(e.g. a read-only or locked target), the files already written keep the new version, the others
keep the old one, and the backups that could restore them are left unused in the temp folder. The
documentation promises the opposite ("the originals are restored from their backups, leaving every
project file in a consistent state"). Worse, when preparing fails, the rollback restores from a
backup directory in which two bump files of the same name share one backup, and overwrites one of
them with the content of the other. The cause is a design flaw shared by the release management
write paths: the safeguards — backup, snapshot, rollback — run while *preparing* the changes, where
nothing is written, while the step that actually writes has none. A second flaw lets the classes'
internal `New-Item`/`Copy-Item`/`Remove-Item` calls inherit the caller's `-WhatIf`/`-Confirm`, so
`-Confirm` asks about internal steps and `-WhatIf` reports or suppresses them.

The fix moves every safeguard into the write step and makes it a transaction: preparation has no
side effects, the cmdlet asks once via `ShouldProcess`, and a new `PSScriptBuilderFileTransaction`
opens all target files, checks they did not change since the preparation, backs them up next to
themselves, writes them, restores them on failure, and removes the backups unless restoring failed.
File operations inside classes use .NET APIs instead of cmdlets, so they no longer depend on the
caller's `-WhatIf`/`-Confirm`.

## Motivation

Found while investigating `PSScriptBuilder_Backup_*` directories left in the temp folder. All
findings were verified on PowerShell 5.1 and 7 against copies of the bump file stress test fixture
unless marked otherwise. Finding 6 is the most severe: it corrupts a file that was never meant to
be changed.

1. **Partial bump without rollback.** With the last of five bump files read-only,
   `Update-PSScriptBuilderBumpFiles` failed with "Access … denied" after writing 2 (PS 7) or 4
   (PS 5.1) of the files; none were restored. `PersistBumpFiles()` has no rollback at all; the
   only rollback (`RollbackBumpFiles()`) runs when *preparation* fails, where no file has been
   written yet, so it never restores anything that changed.
2. **Backups leaked into the temp folder.** Backups are created during preparation, before the
   `ShouldProcess` prompt, and removed only after a successful write. A declined `-Confirm`, any
   failure, and every unit test run that calls the backup method directly left a directory behind
   — 346 accumulated on the development machine since August 2026. A failure on a missing or
   locked bump file left an empty directory, because `CleanupBumpFileBackups()` derives the
   directory from the first backup entry and returns early when there is none.
3. **`-Confirm` asked eight times instead of once.** The internal `New-Item` (backup directory),
   one `Copy-Item` per bump file and the `Remove-Item` of the cleanup each prompted. Declining the
   first aborted the cmdlet ("Failed to create directory"); declining a `Copy-Item` *silently
   skipped that backup*, so a later restore would have had nothing to restore from; declining the
   `Remove-Item` left the directory behind with a warning. `-WhatIf` listed the internal "Create
   Directory" and "Copy File" operations as if they were user-visible changes.
4. **`-WhatIf` rewrote the release data file.** When preparation failed (e.g. an invalid release
   data file), `RollbackReleaseData()` saved the loaded original back to disk — also under
   `-WhatIf`. The values stay the same (the processor works on a clone), but the file is rewritten
   with the module's formatting and a BOM, and `-WhatIf` must never change a file. Verified against
   the module before the change: without `-WhatIf`, a failed update rewrote the file as well.
5. **A second prompt when creating files.** `New-PSScriptBuilderReleaseData -Confirm` in a project
   without `build\Release` asked twice — once for the documented change, once for the internal
   directory creation; declining the second failed the cmdlet. The same helper
   (`EnsureDirectoryExists`) is used by the template generator, the configuration, the build output
   and the build result export (derived from the code, measured only for release data).
6. **Backup name collisions corrupt a file.** All backups of a run go into one directory as
   `<file name>.bak`, so two bump files with the same name in different folders overwrite each
   other's backup. Reproduced with `one\same.txt`, `two\same.txt` and a third bump file that is not
   valid UTF-8: reading the third fails during preparation, the rollback restores from the shared
   backup, and `one\same.txt` afterwards contains the content of `two\same.txt` — although nothing
   had been written before the rollback.
7. **Lost update for one file configured twice.** A file configured with two spellings
   (`CHANGELOG.md`, `.\CHANGELOG.md`) was grouped by its configured text, so both groups were
   prepared from the same original and written one after the other: only the changes of one
   survived, while the result reported both as modified. Which one survived differed between
   PowerShell versions. Found during the implementation, verified against the module before the
   change.
8. **Timestamp moved in PowerShell 7.** PowerShell 7's `ConvertFrom-Json` returns
   `build.timestamp` as a `DateTime`; `Normalize()` converted it back with `Add-Member -Force`,
   which moves the property to the end of `build`. Every update reordered the file, and the new
   check whether anything changed would have always reported a change. Found during the
   implementation.

## Detailed Design

### Phases

| Phase | Where | Side effects |
|---|---|---|
| Prepare | `Execute…()` of the orchestrator | none — load, validate, compute the new content |
| Confirm | the cmdlet, `$PSCmdlet.ShouldProcess(description, question, caption)` | none — the only prompt |
| Apply | `Persist…Changes()` via `PSScriptBuilderFileTransaction` | writes, transactional |

The `ShouldProcess` call uses the three-parameter overload (`verboseDescription`,
`verboseWarning`, `caption`): `-WhatIf` shows the description, which names every file that would
change; `-Confirm` shows the question under the caption. It stays a single
call for all files: with one call per file, "No" means "skip this file" by the documented prompt
semantics, which would produce exactly the inconsistent partial bump this RFC fixes.

### `PSScriptBuilderFileTransaction` and `PSScriptBuilderFileTransactionEntry` (new, `src/Classes/Common`)

The transaction controls the order of the steps and the error handling across all files; each
`PSScriptBuilderFileTransactionEntry` performs the operations on its own file (`Open`,
`IsUnchanged`, `Backup`, `Write`, `Restore`, `Close`, `DeleteIfCreated`, `RemoveBackup` —
Information Expert, Tell Don't Ask). An entry's operations throw an `IOException` that already
names its file and backup, so the transaction only collects the messages and never reads an
entry's internals. The kind of change is the new enum `PSScriptBuilderFileChangeType` (`Replace =
0`, `Create = 1`; the most common kind is zero, per the Framework Design Guidelines, since no
`None` makes sense); entries take it through their only constructor, so it is never left at its
default. An entry removes only what it created itself: the backup it wrote, and for Create the
file it created — never a file that already existed or a backup left by an earlier run.

- `AddReplace([string] $path, [byte[]] $expectedBytes, [byte[]] $newBytes)` — replace an existing
  file; `expectedBytes` is the content read during preparation.
- `AddCreate([string] $path, [byte[]] $newBytes)` — create a file that must not exist yet.
- `[string[]] Commit()` — applies all entries and returns warnings (backups that could not be
  deleted after a successful commit; the files are correct, so this is not a failure). The calling
  cmdlet writes them, since warnings written inside class methods are not collected by
  `-WarningVariable` (RFC 0025):
  1. Normalize every path with `[Path]::GetFullPath` and reject duplicates
     (`PSScriptBuilderFileSystemHelper.GetPathComparer()`: `OrdinalIgnoreCase` on Windows, `Ordinal`
     elsewhere, including macOS), naming both
     configured spellings. Paths must be absolute, since .NET resolves a relative path against the
     process working directory rather than the PowerShell location.
  2. **Acquire:** open every replace target with `FileAccess.ReadWrite`, `FileShare.Read`, and
     create every new file with `FileMode.CreateNew`. A read-only, locked or already existing file
     fails here, before any file is changed. If a file cannot be opened although the
     normalized paths differ, the message mentions that it may be configured twice (e.g. via a
     link).
  3. **Check:** read each replace target through its handle — in a loop, since `FileStream.Read`
     may return fewer bytes than requested — and compare it with `expectedBytes`; a difference
     aborts with an error that the file changed since the preview (Optimistic Offline Lock — check
     and write happen while the handles are held).
  4. **Back up:** if `<file>.psscriptbuilder-backup` already exists, abort — a previous run did not
     complete, and it may be the only copy of the original; otherwise copy each replace target to
     it (`[File]::Copy`).
  5. **Write:** truncate and write each file through its handle, then flush.
  6. **On failure:** restore every touched replace target — including one that failed while being
     written — from its backup through its handle.
  7. **Finally:** close all handles (also when the commit is interrupted, e.g. by Ctrl+C); then
     delete the files this run created, and delete the backups if the commit or the restore
     succeeded. Only then is the exception thrown, so its message states what actually happened: a
     failure before any file was changed passes the specific exception through; a restored failure
     is an `IOException` stating that all files were restored, with the original exception as inner
     exception; if restoring or deleting failed, the backups are kept and the exception names every
     affected file and backup. Backups are never deleted in a `finally` block, so an interrupted
     commit keeps them and the next run reports them.

The transaction is encoding-agnostic: callers pass the bytes they read and the bytes to write.

### Release management

- **Preparatory refactoring, behavior unchanged:** the prepared bump file changes, today a
  `List[PSCustomObject]` (`filePath`, `originalContent`, `newContent`, `changedItems`) passed from
  the processor through the orchestrator, become the class `PSScriptBuilderBumpFileChange` in the
  new folder `src/Classes/ReleaseManagement/Data` (matching `ScriptBuilder/Data`). Done as its own
  step before the fix ("make the change easy, then make the easy change"); the public `BumpDetails`
  of the cmdlet result stays unchanged.
- `ExecuteBumpFilesUpdate()` no longer creates backups and no longer rolls back;
  `InitializeBumpFilesBackups()`, `RollbackBumpFiles()` and `CleanupBumpFileBackups()` are removed.
  The bump files processor reads each file as bytes and keeps them for the check in step 3; it
  decodes them with a `StreamReader` using the same encoding and byte order mark detection as the
  current `File.ReadAllText`, so the text it works on is unchanged (including UTF-16 files). It
  groups the configured entries by full path with the transaction's comparer instead of
  `Group-Object`, which compares the configured text case-insensitively also on Linux and would
  merge two different files there.
  Reading and decoding are two static methods of `PSScriptBuilderFileIOHelper` (`ReadAllBytes`,
  `DecodeUTF8WithBOM`), so the call path that today reports invalid UTF-8 as "invalid UTF-8
  encoding" stays the same; the `catch` blocks check the exception itself and its inner exception
  for a `DecoderFallbackException`. Grouping by full path also makes the processing order the
  configured order on both PowerShell versions — `Group-Object` sorts its groups in PowerShell 7 but
  keeps the input order in 5.1, so the order of the files in the result and of the warnings
  differed between the versions. Transaction and processor take their path comparer from
  `PSScriptBuilderFileSystemHelper.GetPathComparer()`.
- `PersistBumpFilesChanges()` commits one transaction with an `AddReplace` per changed file and
  returns the transaction's warnings.
- `ExecuteReleaseDataUpdate()` no longer rolls back; `RollbackReleaseData()` is removed.
  `PersistReleaseDataChanges()` commits a transaction with one `AddReplace` (update) or `AddCreate`
  (new release data; `AddReplace` when overwriting with `-Force`). The release data file manager
  reads bytes (`ReadBytes`), parses them (`Deserialize`, also used by `Load`) and serializes
  release data to bytes (`Serialize`, byte-identical to the former `Save`, which is removed).
- **No warn-and-rethrow:** the `catch` blocks of `ExecuteBumpFilesUpdate()` and
  `ExecuteReleaseDataUpdate()` only remain to write "… update failed" as a warning and rethrow once
  the rollback is gone. They are removed: the warning repeated the error ("log and rethrow"), is
  not collected by `-WarningVariable` (RFC 0025), and under `-WarningAction Stop` replaced the
  original error with a nested one. `Update-PSScriptBuilderReleaseData` then raises no warnings
  from classes anymore (see `docs/limitations.md`).
- The cmdlets' `ShouldProcess` messages list the files. **Nothing to change, nothing to confirm:**
  `Update-PSScriptBuilderBumpFiles` and `Update-PSScriptBuilderReleaseData` neither prompt nor write
  when the preparation found no change (no "What if" line, no rewrite of identical content);
  `New-PSScriptBuilderReleaseData` always changes a file.

### File operations inside classes

`PSScriptBuilderFileSystemHelper.EnsureDirectoryExists` rejects an empty or relative path
(`ArgumentException`) and calls `[Directory]::CreateDirectory`; its exceptions pass through
unchanged. The `.NET` message is more precise than the former one — it names the path segment that
blocks, also when that is a parent directory — so no own existence check is made (no
check-then-act). The recursion with `Test-Path`/`New-Item`, the post-check and the
`$WhatIfPreference` detection added by RFC 0022 are removed. All five callers pass absolute paths
and run, where their cmdlet supports `-WhatIf`, only inside its confirmed branch
(`New-PSScriptBuilderTemplate`, `New-PSScriptBuilderConfiguration`). `EnsureFileExists` (both
overloads) is removed: it has no caller, and it creates files outside the transaction by checking
first and creating afterwards.

### Implementation notes

- **`UnwrapException`:** PowerShell wraps an exception of a .NET call in a
  `MethodInvocationException` ("Exception calling … with … argument(s)"). Entry and transaction
  unwrap it, so messages name the cause and an `IOException` is passed on as such.
- **`HasReleaseDataChanges()`** compares the serialized release data before and after the update
  byte by byte, not the result's change list: that list compares values without regard to letter
  case (RFC 0027). A difference in formatting only merely rewrites the file; a real change is never
  missed.
- **A `[string]` property cannot hold `$null`:** assigning `$null` stores `''`, so an entry checks
  its backup path with `IsNullOrEmpty`. Found because a failed commit warned that the backup `''`
  could not be deleted.
- **`Normalize()`** sets the timestamp on the existing property (finding 8), so loading and
  saving unchanged release data yields the same bytes.
- **Every returned warning is written:** an integration test parses the three cmdlets and checks
  that each `Persist…Changes()` call is the condition of a `foreach` whose body calls
  `Write-Warning`, so a dropped return value fails a test.

## Rationale and Alternatives

**Reverses a decision of RFC 0022.** RFC 0022 kept creating backups under `-WhatIf`, arguing that
"the in-memory preparation and validation work that follows benefits from a real backup existing".
Preparation never writes, so a backup protects nothing there, and the leaks, the extra prompts and
the missing rollback of the write step all follow from that placement. RFC 0022's detection of an
ambient `-WhatIf` in `EnsureDirectoryExists` becomes unnecessary once the helper no longer calls
`New-Item`.

**Direct overwrite with a copied backup, not `File.Replace`.** Writing a temporary file and
replacing the target (`File.Replace`, the usual atomic-write pattern) was measured: it breaks hard
links (the other link keeps the old content) and fails on symbolic links in PS 7 ("does not support
the current operation on symbolic links"), while the direct write keeps links, attributes and the
creation time. Vim's `backupcopy` documentation describes the same trade-off and defaults to
copying on Unix. Cost: a crash in the middle of writing leaves a partially written file — its
backup stays next to it, and the next run refuses to continue until it is resolved. Bump files are
small and written in milliseconds.

**Acquire before writing.** Following the Compensating Transaction pattern's advice to "acquire
these resources in advance, and then perform work only after you acquire all resources", the
realistic failures (read-only, locked) happen before any file changes; the restore is left for the
rare remainder (e.g. a full disk). On Linux and macOS, file locks are advisory, so a lock held by
another process may not be detected; read-only files are.

**Backups next to the file, not in the temp folder.** Vim (`backupdir` default `.` first, the temp
folder as fallback), Emacs (beside the original by default) and Git (`<file>.lock` in the same
directory) keep the safety copy next to the file. It rules out name collisions (finding 6), is on the
same volume, and is found where it is needed after a failed restore or a crash; the temp folder
hid 346 leftovers. After a crash the backup shows up in `git status`, which is intended. In watch
mode, a bump file under a watched path would trigger a rebuild; bump files are rarely under `src`.

**.NET file APIs instead of `-WhatIf:$false -Confirm:$false` on every cmdlet call.** Both make the
internal steps explicit, as recommended ("trust but verify"; preference inheritance is unreliable
for script modules). .NET calls need no switch at every call site, cannot be forgotten in a new
call, and match `PSScriptBuilderBackupManager`, which already uses `[File]::Copy` and was not
affected by any finding.

**Return the warnings instead of `[void]`.** `Persist…Changes()` and `Commit()` change state and
return the warnings of that change. This deviates from strict Command-Query Separation (Meyer) in
the way `SaveChanges()` returns the number of written rows: the return value describes the
command's own outcome. The Try-Parse pattern (Framework Design Guidelines) does not fit: it
returns `$false` for an expected failure, while here a failure throws, and warnings come with
success; an additional `[ref]` parameter is discouraged (CA1021). A Notification object (Fowler)
would add a type for a list of strings. The cmdlet writes the warnings, as RFC 0025 recommends.

**Considered and rejected:** keeping the temp backup directory with unique sub-paths (fixes the
collisions but keeps the hidden leftovers); one `ShouldProcess` per file (see Phases); Transactional
NTFS (deprecated by Microsoft); a Pester-only fix of the leaking tests (leaves findings 1–6).

## Scope

**In scope:** `PSScriptBuilderFileTransaction`, `PSScriptBuilderFileTransactionEntry`,
`PSScriptBuilderFileChangeType`, `PSScriptBuilderBumpFileChange`; the release management
orchestrator, bump files processor and release data file manager; `PSScriptBuilderFileSystemHelper`; the `ShouldProcess`
messages of `Update-PSScriptBuilderBumpFiles`, `Update-PSScriptBuilderReleaseData` and
`New-PSScriptBuilderReleaseData`; unit and integration tests; the documentation of backups and
rollback (`docs/guides/release-management.md`, `docs/cmdlets/Update-PSScriptBuilderBumpFiles.md`,
`docs/cmdlets/Update-PSScriptBuilderReleaseData.md`, `docs/cmdlets/New-PSScriptBuilderReleaseData.md`,
`docs/limitations.md`); `CHANGELOG.md`; this RFC.

**Out of scope:**
- **Encoding of bump files.** A bump rewrites every bump file as UTF-8 with BOM, also UTF-8
  without BOM and UTF-16 (measured; content correct). This breaks shell scripts with a `#!` line
  and strict JSON parsers. Preserving the original encoding is a separate change, prepared by the
  encoding-agnostic transaction.
- **Consistency across cmdlets.** `Update-PSScriptBuilderReleaseData` and
  `Update-PSScriptBuilderBumpFiles` are separate commands; when the bump fails, the release data is
  already updated. Only a combined release command could make both one transaction.
- Custom exception types (RFC 0015, deferred).
- **Changes in letter case only.** The processor decides whether a file changed with `-ne`, which
  ignores letter case, so a bump that only changes the case (e.g. a prerelease label `Beta` →
  `beta`) is not written and raises the RFC 0019 warning. A separate fix (RFC 0027), done right
  after this RFC.

- **Invalid UTF-8 reported as invalid JSON.** In the release data and bump configuration file
  managers and in the configuration loader, `catch [ArgumentException]` precedes the check for a
  `DecoderFallbackException`/`EncoderFallbackException` — both derive from `ArgumentException`,
  and PowerShell matches typed `catch` blocks against the inner exception too — so the "invalid
  UTF-8 encoding" branch is unreachable (six places, reproduced with a release data file). The new
  `Deserialize`/`Serialize` keep the current order, so this RFC does not change that behavior; all
  six places are fixed together in a separate change.

**Known limits:**
- On macOS, paths are compared case-sensitively although most volumes are not; a file configured
  twice in different letter case is then written twice from the same prepared content.
- A directory created for a new file (`AddCreate`) stays when the transaction fails; only the file
  is deleted.
- With `-WarningAction Stop`, the rare warning that a backup could not be deleted stops the cmdlet
  with an error although all files were written correctly (documented in `docs/limitations.md`).

## Relationship to Other RFCs

Supersedes the backup placement kept by RFC 0022 and makes its `-WhatIf` detection obsolete (see
Rationale). Related to RFC 0019 (warning for bump files whose patterns no longer match), whose
warning is raised during preparation and is unaffected. RFC 0015 (custom exceptions) stays
deferred; this RFC uses standard .NET exceptions.

Implements the PREFER rule of RFC 0025: the transaction's warnings are returned to the cmdlet, and
the warn-and-rethrow and rollback warnings it listed for `Update-PSScriptBuilderReleaseData` and
`Update-PSScriptBuilderBumpFiles` are gone. RFC 0028 resolves the cmdlets' own `-Path` against the
PowerShell location, for the reason step 1 requires absolute paths.

## Test Plan

- **Baseline before the change**, on PS 5.1 and 7: the bump and release data cmdlets on the stress
  test fixture with and without `-WhatIf`, the files written and their bytes, the warnings, and the
  findings 1–6 as reproductions (captured 2026-11-05; the two versions differ only in the order in
  which the bump files are processed).
- **Transaction unit tests** (in `TestDrive`, so backups are cleaned up with it): success;
  read-only and locked target fail before any file changes; a changed file fails the check; an
  existing backup aborts; a failure while writing restores all files byte for byte and deletes
  created files; a failed restore keeps the backups and names them; duplicate paths in different
  letter case are rejected; two files with the same name in different folders are backed up
  separately and, after a failure while writing, each is restored with its own content; hard links
  keep their content shared; a Create whose file already exists fails without deleting that file;
  a backup left by an earlier run is never deleted; empty files and empty new content; the
  transaction writes nothing to any stream.
- **Processor:** the text decoded from the bytes equals the text `File.ReadAllText` returned, for
  UTF-8 with and without BOM and UTF-16 LE.
- **Cmdlet tests:** a single prompt for `-Confirm`; `-WhatIf` lists the files and leaves the file
  system unchanged, including the release data file after a failed preparation; a declined prompt
  leaves no backup. Since Pester's `It` block breaks the ambient `-WhatIf` propagation into class
  methods (RFC 0022), the `-WhatIf`/`-Confirm` tests run the cmdlet in a child process.
- **No leftovers:** the full suite leaves no `PSScriptBuilder_Backup_*` directory and no
  `*.psscriptbuilder-backup` file behind.
- **Full suite** on PS 5.1 and 7, smoke tests and example tests.
- **Results** (2026-11-05): the baseline after the change is identical on PS 5.1 and 7, with
  findings 1–8 resolved and no leftovers; full suite PS 7: 2316 passed, 3 skipped; PS 5.1: 2317
  passed, 2 skipped (including RFC 0028); smoke tests 22 of 22 and example tests 16 of 16 on both.

## Unresolved Questions

None. Released as 1.4.0: the release adds features (source map format version,
`ComponentLineCount`), which requires a minor version; this RFC itself is a fix.

## Revision Log

- 2026-11-05 — Proposed after a review of the bump backup leak. The first design (backups in the
  write step, temp folder, `finally` cleanup) was revised against best practice: backups are kept
  when a restore fails (Compensating Transaction), `File.Replace` was measured and rejected for
  breaking links, backups moved next to the files (Vim, Emacs, Git), and path normalization, an
  optimistic concurrency check, exclusive file creation and a single descriptive `ShouldProcess`
  prompt were added. A further review split the file operations into an entry class with an enum
  for the change type, made the processor's prepared changes a class as a preparatory refactoring,
  and added: removing only what the run created (a first draft would have deleted an existing file
  when its exclusive creation failed), reading in a loop, decoding exactly as before, grouping by
  full path, and warnings for backups that cannot be deleted after a successful commit. The
  letter-case comparison of the processor was found on the way and split off as RFC 0027. The
  preparatory refactoring to `PSScriptBuilderBumpFileChange` was implemented first (behavior
  unchanged, baseline identical). A review of all affected code paths before the fix added:
  keeping the call path of the UTF-8 decoding, removing the warn-and-rethrow `catch` blocks, no
  prompt without a change, removing the unused `EnsureFileExists`, a thin `EnsureDirectoryExists`
  relying on the `.NET` message, the configured processing order on both versions, and replacing
  `Save` by `Serialize`.
- 2026-11-05 — Implemented on `development` (commits pending). The implementation added findings
  7 and 8, the byte comparison for "no change, no prompt", the order-keeping `Normalize()`, the
  `IsNullOrEmpty` check for the backup path and a test that every returned warning is written.
  Returning the warnings was reviewed against `[void]` with a Try pattern and kept. The
  `ShouldProcess` and comparer descriptions were corrected to match the code.
