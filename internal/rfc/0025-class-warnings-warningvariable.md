# RFC 0025: Warnings from Classes and -WarningVariable

- **Status:** Accepted (2026-11-04) — documented as a known limitation; see Revision Log
- **Type:** Design decision
- **Created:** 2026-11-04
- **Branch:** development

## Summary

Warnings written with `Write-Warning` inside PowerShell class methods are displayed and honor
`-WarningAction`, `$WarningPreference` and stream redirection, but they are not collected by the
calling cmdlet's `-WarningVariable`. Most PSScriptBuilder warnings are raised inside classes, so
seven cmdlets are affected. The decision is to document this as a known limitation with verified
workarounds instead of restructuring how classes report warnings, and to prefer returning warning
messages to the cmdlet in new code wherever that needs no extra plumbing.

## Motivation

Found while consolidating the stale check for RFC 0023: a stale warning moved into a class method
was no longer collected by `-WarningVariable`, which an existing cmdlet test caught. The stale
check was therefore changed to return its warnings to the cmdlet (`GetStaleWarnings`). A review of
the remaining classes found 20 further `Write-Warning` calls in 9 classes with the same behavior.

Measured in a module on PowerShell 5.1 and 7:

| Call inside a class method   | `-WarningVariable` | `3>&1` | `-WarningAction` | `-Verbose` |
|------------------------------|--------------------|--------|------------------|------------|
| `Write-Warning`              | not collected      | works  | works            | —          |
| `$PSCmdlet.WriteWarning()`   | collected          | works  | works            | —          |
| `Write-Verbose`              | —                  | —      | —                | works      |

Affected cmdlets, traced from each call to its public entry point:

- `Invoke-PSScriptBuilderBuild` and `Watch-PSScriptBuilderProject` — content processor (fallback
  comment for an empty collector), template processor, build orchestrator, source map generator
- `Update-PSScriptBuilderReleaseData` — failed update and failed rollback
- `Update-PSScriptBuilderBumpFiles` — no pattern matched, failed update, failed rollback, failed
  backup cleanup
- `Find-PSScriptBuilderUnusedComponent` — dependency cycles
- `Resolve-PSScriptBuilderSourceLocation` — origin check for `-ErrorRecord`, resolver
- `Get-PSScriptBuilderSourceCoverage` — skipped coverage entries, resolver

Not affected: warnings the cmdlets write themselves (the `-EntryPoint` hints of
`Find-PSScriptBuilderUnusedComponent`, the stale warnings of the source map cmdlets). The 305
`Write-Verbose` calls in classes are not affected either: they respect the caller's preference, and
`-Verbose` works.

The limitation had been noticed once before, but only recorded internally: the bump file stress
test fixture (`tests/Fixtures/BumpFileStressTest/Run-StressTest.ps1`) already uses `*>&1` with a
filter because `-WarningVariable` missed the warnings.

## Detailed Design

- `docs/limitations.md` gets the section "Warnings Not Collected by -WarningVariable": cause,
  affected cmdlets, what still works, implication, and two workarounds — redirecting the warning
  stream (`3>&1`) and filtering `WarningRecord` objects, or `-WarningAction Stop` to fail on the
  first warning.
- `AGENTS.md` gets a PREFER rule: a class method called directly by the cmdlet returns its warning
  messages to the cmdlet, which writes them, whenever that needs no extra plumbing (the
  `GetStaleWarnings` pattern). It is deliberately not a NEVER rule — returning messages through a
  deep call chain is exactly the restructuring this RFC decides against, and a class that runs a
  loop itself (the project watcher) has no result to return.
- No code changes; the existing 20 calls stay as they are.

## Rationale and Alternatives

**Decision: document instead of fix.** Weighed by frequency and impact against the cost of a fix:

- **Frequency: rare.** Only scripts that set `-WarningVariable` and evaluate it are affected. CI
  scripts typically use `$WarningPreference` or `-WarningAction`, which work. No user has reported
  it; it was found by chance during testing.
- **Impact: low.** The warning is still displayed in the console and CI log. Most warnings are
  informational (fallback comment, cycles, skipped coverage entries). The severe cases — failed
  updates and rollbacks in release management — end in a thrown exception anyway, so the failure
  itself stays visible; only the additional warning is missing from the variable.
- **Cost of a fix: medium to high.** 20 calls in 9 classes, signature changes along the call
  chains, new tests per cmdlet, and changes to the release error path, where the regression risk is
  highest — for a small benefit, and none at all for the watcher.

**Explicit deviation from the established bar.** RFCs 0009, 0012, 0013, 0016 and 0019 state that a
reachable silent-failure defect gets fixed, not just documented; the only exception so far
(RFC 0010) applies to defects with no reachable path. This defect is reachable. The deviation is
justified because the failure is only partly silent (the warning is displayed and all other
warning mechanisms work), its cause lies in PowerShell's class design rather than in this module,
and a verified workaround exists. Future silent-failure defects that do not meet all three
conditions still fall under the established bar.

**Considered and rejected:**

- **Injecting `$PSCmdlet` (directly or via a writer class).** Works fully and in real time, but
  contradicts the official guidance: about_Classes_Methods says to avoid the `Write-*` cmdlets in
  class methods and not to use `$PSCmdlet` in classes ("Using it in a class may have unexpected
  side effects"), and the language designer's stated intent is that "streams are not a part of
  classes semantically speaking. […] Methods *return* values and *throw* errors"
  ([PowerShell issue #9702](https://github.com/PowerShell/PowerShell/issues/9702)). The `ILogger`
  analogy holds for .NET libraries, not for PowerShell classes.
- **Warnings in the result objects** (Notification pattern). The public result objects are
  formatted, exported and passed on; a warning describes the run of the operation, not its result.
  It also fails on the error path, where an exception replaces the result and the warnings of a
  failed rollback would be lost.
- **Collecting Parameter** (the cmdlet passes a list the classes add to, and writes it in
  `finally`). Follows the official guidance and covers the error path, but adds a parameter along
  every affected call chain — disproportionate to the benefit.
- **Ambient context** (a module-wide "current cmdlet"). Least effort, but a hidden dependency and a
  recognized anti-pattern (Seemann/van Deursen, *Dependency Injection Principles, Practices, and
  Patterns*, chapter 5).

## Scope

Documentation and a development rule only. No change to module behavior, so no CHANGELOG entry:
Keep a Changelog records changes (Added, Changed, Deprecated, Removed, Fixed, Security), and
documenting an existing limitation is none of them.

## Relationship to Other RFCs

Follows from RFC 0023, whose stale check consolidation surfaced the behavior and introduced the
return-to-the-cmdlet pattern (`GetStaleWarnings`) that the PREFER rule generalizes. Deviates, with
the justification above, from the fix-rather-than-document bar of RFCs 0009, 0012, 0013, 0016 and
0019.

## Test Plan

No automated tests, since no behavior changes. The documented behavior and workarounds were
verified manually on PowerShell 5.1 and 7:

- **Mechanism:** a minimal module with a class and an advanced function, measuring the matrix in
  Motivation.
- **Real build:** `Invoke-PSScriptBuilderBuild` on example 16 with an empty class directory, which
  raises the fallback comment warning. `-WarningVariable` collected 0 warnings; `3>&1` with the
  documented filter yielded exactly 1 warning and 1 `PSScriptBuilderBuildResult`;
  `-WarningAction Stop` aborted the build and no output script was written.
- **Bump files:** a copy of the bump file stress test fixture, bumped until a target no longer
  matched. `Update-PSScriptBuilderBumpFiles -WarningAction Stop` aborted with an
  `ActionPreferenceStopException` that includes the original warning, and no file in the project
  changed.
- **Existing tests:** no test relies on `-WarningVariable` for a warning raised inside a class.

## Unresolved Questions

- **When to revisit:** as soon as a user reports the limitation, or when one of the affected
  classes is substantially reworked anyway — then its warnings are moved to the cmdlet as part of
  that work.

## Revision Log

- 2026-11-04 — Decided and documented on `development`. The evaluation went through injecting
  `$PSCmdlet` via a writer class, warnings in the result objects and a Collecting Parameter before
  settling on documentation; the official guidance on classes and streams ruled out the first, and
  the cost-benefit assessment the others. A strict NEVER rule for new code was softened to PREFER.
- 2026-11-05 — RFC 0026 removed the warn-and-rethrow and rollback warnings of
  `Update-PSScriptBuilderReleaseData` and `Update-PSScriptBuilderBumpFiles` and returns the
  transaction's warnings to the cmdlet. `Update-PSScriptBuilderReleaseData` is no longer affected;
  `docs/limitations.md` was updated accordingly.
