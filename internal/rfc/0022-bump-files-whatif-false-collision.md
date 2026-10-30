# RFC 0022: Bump Files Backup WhatIf False Collision

- **Status:** Implemented (2026-10-29) — written retroactively, after implementation and full
  cross-version verification; see Revision Log
- **Type:** Fix
- **Created:** 2026-10-29
- **Branch:** development

## Summary

Under `-WhatIf`, `Update-PSScriptBuilderBumpFiles` (and therefore any release script with
`SupportsShouldProcess`) always failed with "Failed to create directory: ... A file already
exists at this path", even though nothing existed at that path. The 1.3.0 post-condition check
added to `EnsureDirectoryExists`/`EnsureFileExists` (commit `357466d`, no RFC at the time) could
not distinguish a genuine file/directory collision from `New-Item` being silently suppressed by an
ambient `-WhatIf` propagated from the calling cmdlet. Both methods now explicitly check for the
real collision signal (the opposite path type existing) before throwing, and only treat a
non-collision "nothing happened" outcome as a failure when `-WhatIf` is not active.

## Motivation

Reported externally against the published 1.3.0 package, with a thorough writeup already covering
reproduction, call-chain analysis, and three candidate fixes. Reproduced directly against this
repository's own `development` branch before any fix was designed, confirming it was not specific
to the reporter's environment.

Investigating *why* `New-Item` silently did nothing under `-WhatIf` here, but still correctly
reported "What if: Performing the operation..." led to a more fundamental discovery:
`$WhatIfPreference` cannot be referenced directly inside a PowerShell class's static method at
all — not merely "untested", but a parse error (`Variable is not assigned in the method`), and
`$global:WhatIfPreference` always resolves to `$false` regardless of the caller's actual state
(confirmed: it is a function-scoped automatic variable, never global). Yet `New-Item`, called from
within that same method, still honors the ambient value correctly — because cmdlets resolve
preference variables through PowerShell's own dynamic scope-chain lookup, a mechanism independent
of a class's stricter lexical variable rules. `Get-Variable -Name WhatIfPreference -ValueOnly
-ErrorAction SilentlyContinue` — a cmdlet call, not a bare variable reference — uses that same
lookup and was verified to work reliably inside a static method, including through a multi-level
class-to-class call chain matching the real orchestrator structure.

A related discovery shaped the test strategy: Pester's own `It` block execution breaks this exact
propagation path once the call crosses into a class's static method — verified to be a general
PowerShell behavior, not Pester-specific (a plain `& { $WhatIfPreference = $true; [SomeClass]::
Method() }` outside Pester reproduces the identical gap), while an ordinary nested *function* call
does not have this problem. A direct unit test calling the helper from inside an `It` block
therefore cannot faithfully reproduce — or verify a fix for — this scenario; see Test Plan.

## Detailed Design

**`PSScriptBuilderFileSystemHelper.EnsureDirectoryExists()`** — after `New-Item` and the existing
`Test-Path -PathType Container` check fails, the method now checks `Test-Path -PathType Leaf`
first: if true, a file genuinely blocks the path and the original, precise error is thrown
unconditionally (even under `-WhatIf` — a real collision is a real problem a dry run should still
surface). Only if that is false does it check `Get-Variable -Name WhatIfPreference -ValueOnly
-ErrorAction SilentlyContinue`: if `-WhatIf` is not active, this is a genuine, unexplained failure
(e.g. a permission error) and still throws, with a message that no longer falsely claims a file
collision; if `-WhatIf` *is* active, nothing is wrong and the method returns normally.

**`PSScriptBuilderFileSystemHelper.EnsureFileExists()`, no-content branch** — the exact mirror
image: checks `Test-Path -PathType Container` (a directory blocking a file path) before falling
back to the same `Get-Variable` check.

**`PSScriptBuilderFileSystemHelper.EnsureFileExists()`, content branch** — this branch never used
`New-Item` at all; it calls `[File]::WriteAllText(...)` directly, which does not honor
`$WhatIfPreference` under any mechanism, since it is a plain .NET call, not a PowerShell cmdlet.
It is now guarded by the same `Get-Variable` check *before* writing, skipping the write entirely
when `-WhatIf` is active. No caller in `src/` currently passes non-`$null` content through this
path (confirmed by search), so this had no live effect — fixed anyway, since the defect was
already concretely known rather than speculative (see Unresolved Questions).

## Rationale and Alternatives

**Why detect collision-vs-suppression in the helper, rather than thread an explicit WhatIf
parameter through the whole call chain.** Threading `-WhatIf` state explicitly from
`Update-PSScriptBuilderBumpFiles` through `PSScriptBuilderReleaseManagementOrchestrator`'s instance
methods down into the static helper would require changes across multiple classes for no
behavioral benefit; the detection-based fix is fully equivalent and self-contained in one file.

**Why not skip backup creation entirely under `-WhatIf`** (one of the externally reported fix
options). `InitializeBumpFilesBackups`'s own docstring documents that backups are always created
before persistence, regardless of `-WhatIf` — this is intentional: the in-memory preparation and
validation work that follows benefits from a real backup existing. Skipping it would change that
documented contract and still would not help `New-PSScriptBuilderConfiguration -WhatIf` or the
`EnsureFileExists` content branch, which have the identical underlying defect.

**Why not rely solely on the `Test-Path -PathType Leaf`/`Container` check, without the
`Get-Variable` check.** An earlier draft of this fix used only the path-type check. Rejected after
explicit verification against all four relevant combinations (WhatIf × collision): it would
silently swallow a genuine real-run failure that is neither a collision nor caused by `-WhatIf`
(e.g. a permission error), reintroducing exactly the class of silent failure `357466d` was meant to
fix — just narrower. The combined check preserves `357466d`'s full protection for every outcome of
a real run while correctly recognizing the suppressed case.

## Scope

**In scope:** `PSScriptBuilderFileSystemHelper.EnsureDirectoryExists`, `EnsureFileExists` (both
branches); a new process-boundary Integration test; a `CHANGELOG.md` entry; this RFC.

**Out of scope:** Threading `-WhatIf` state through the orchestrator/cmdlet layer (not needed, see
Rationale); any change to `InitializeBumpFilesBackups`'s own "always create real backups" contract;
the externally-provided bug report document (kept locally for reference, not checked into this
repository — its content is superseded by this RFC).

## Relationship to Other RFCs

Directly addresses a regression introduced by the fix landed in commit `357466d` (part of 1.3.0's
"silent directory/file failures" `CHANGELOG` entry; that original fix had no RFC). No other RFC
covers `PSScriptBuilderFileSystemHelper`.

## Test Plan

- Reproduced the regression end-to-end against the unmodified `development` branch, via the real
  `Update-PSScriptBuilderBumpFiles -WhatIf` cmdlet (not the helper in isolation).
- Verified the fix against the actual production code (not a structural simulation) by patching a
  scratch copy of the built module and re-running the same end-to-end repro for all four
  WhatIf × collision combinations, under both PowerShell 5.1 and PowerShell 7.
- A direct Pester unit test calling the helper from an `It` block was designed, then discarded once
  shown to be structurally incapable of reproducing the ambient-`-WhatIf` scenario (see Motivation).
- New Integration test (`PSScriptBuilderReleaseManagement.Integration.Tests.ps1`) spawns a real
  child process to verify `Update-PSScriptBuilderBumpFiles -WhatIf` exits cleanly and leaves the
  bump target file unchanged.
- Full suite: 2051 passed under PS 5.1 (0 failed, 0 skipped), 2050 passed under PS 7 (0 failed, 1
  skipped), including the new test.

## Unresolved Questions

None for this fix. Separately noted but intentionally out of scope: `EnsureFileExists`'s
content-writing branch had no caller anywhere in `src/` before this fix (confirmed by search) —
fixed anyway, since the defect was already concretely diagnosed rather than speculative, consistent
with this project's standing practice of not leaving a known, already-understood defect in place
merely because no current caller happens to reach it.

## Revision Log

- 2026-10-29 — Implemented on `development` (commits pending). RFC written retroactively after
  implementation and full cross-version verification, to preserve the investigative narrative —
  particularly the PowerShell class/preference-variable scope-chain limitation and its interaction
  with scriptblock-based execution (including Pester's) — for future maintainers.
