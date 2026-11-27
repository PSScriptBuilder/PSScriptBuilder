# RFC 0023: Source Location Silent Mis-Resolution

- **Status:** Implemented (2026-11-04) — written retroactively, after implementation and full
  cross-version verification; see Revision Log
- **Type:** Fix
- **Created:** 2026-11-04
- **Branch:** development

## Summary

`Resolve-PSScriptBuilderSourceLocation` could return a confident, plausible-looking but wrong
source location without any warning, in two independent ways:

1. **Unbounded component extents.** The source map stored only the output line where each
   component *starts*. Every line after it — blank lines, template boilerplate, code outside any
   placeholder — was attributed to the preceding component, up to the start of the next one.
2. **ErrorRecord origin never checked.** `-ErrorRecord` used only
   `InvocationInfo.ScriptLineNumber` and never looked at `InvocationInfo.ScriptName`. An error
   raised in a different script (e.g. the caller's own test or build script) had its line number
   mapped onto the output script's source map, returning an unrelated component.

Both are fixed: the source map now records each component's line count and the resolver rejects
lines beyond it; an `ErrorRecord` is only resolved if it originated in the output script or an
unmodified copy of it — otherwise a warning is emitted and `$null` is returned. The source map's
line counting was aligned with PowerShell's own line-break definition along the way, because a
bounded extent is only correct if it counts lines exactly as PowerShell reports them.

## Motivation

Reported as a detailed bug report against 1.3.1, reproduced with a local end-to-end example that
is not part of this repository.

**Issue 1 (origin)** — the report's own reproduction ("Case B": a .NET exception surfacing at the
call site) did not reproduce as described when re-run. The underlying gap was confirmed
independently: the resolver does not read `InvocationInfo.ScriptName` at all, so any `ErrorRecord`
from another script with a line number inside the output's mapped range resolves to whatever
component happens to cover that line. As the report points out, this is the common case rather
than an edge case: build and test scripts are usually shorter than the output they generate, so a
caller's line number nearly always lands inside the mapped range.

**Issue 2 (extents)** — reproduced directly on the build output of the shipped
`examples/16-source-maps`: lines between components resolved into the preceding component. Code
coverage translation (`Get-PSScriptBuilderSourceCoverage`) uses the same lookup and therefore
attributed hits on template code to the preceding component's source file.

**Line counting** — verifying the extent fix against PowerShell's own `ScriptLineNumber` showed
that the generator's `-split '\r?\n'` counts lines differently from PowerShell for CR-only line
endings and for `\r\r\n` sequences. PowerShell's parser treats exactly CR, LF and CRLF as line
breaks (verified via token extents on PS 5.1 and 7; NEL, LS, PS, FF and VT are not line breaks).
With unbounded extents this divergence was mostly hidden; with bounded extents it would produce
wrong boundaries, so it was fixed as part of this RFC.

## Detailed Design

**`PSScriptBuilderSourceLocation`** — new `ComponentLineCount` property (the number of lines of
the component in the output script; 0 means unknown). A new 8-argument constructor sets it; the
existing 7-argument constructor remains and sets it to 0.

**`PSScriptBuilderSourceMapGenerator`** — `AddEntry` computes `ComponentLineCount` via a new
`CountLines` helper (a single trailing line break ends the last line, it does not start a new
one). `FindLine` and `CountLines` both use a new `CountLineBreaks` helper that counts CRLF, CR and
LF as one line break each — one shared definition, matching PowerShell's.

**`PSScriptBuilderSourceMapFileManager`** — writes `ComponentLineCount` to the sidecar. When
reading, a missing property (sidecar written by an earlier version) yields 0; the property is
checked via `PSObject.Properties` because a bare access to a missing property throws when the
class runs in a strict-mode scope.

**`PSScriptBuilderSourceLocationResolver`**

- `FindLocation` rejects a line beyond the found entry's last line when `ComponentLineCount` is
  greater than 0. With 0 (source map of an earlier version), the previous unbounded behavior is
  kept.
- `Resolve([ErrorRecord])` is replaced by `Resolve([ErrorRecord], [string] $outputPath)`. After
  the existing argument checks it delegates the origin check to a new hidden
  `CheckErrorOrigin(scriptName, outputPath, lineNumber)`, which returns a
  `PSScriptBuilderErrorOriginCheckResult` (`IsFromMappedOutput`, `MismatchMessage`), and emits
  the message as exactly one warning if the error did not originate in the output script.
- The origin rule: the error originated in the output script if `ScriptName` is the same path as
  `outputPath` (both normalized with `GetFullPath`, compared case-insensitively — the same
  precedent as `PSScriptBuilderCodeCoverageTranslator`), **or** if the file at `ScriptName` has the
  same SHA256 hash as the output script the source map was created for (the sidecar's
  `OutputHash`). The hash is only computed when the paths differ. An empty `ScriptName` never
  counts as the output script.
- Each rejection reason has its own warning, all pointing to `-LineNumber` as the manual
  fallback: no script file origin; different script (or a modified copy); content could not be
  compared (file exists but cannot be read).

**`PSScriptBuilderFileIOHelper`** — new public `ComputeSHA256Hash(filePath)`, returning the same
uppercase hexadecimal format as `Get-FileHash`. It uses `[File]::OpenRead` and
`SHA256::Create()` and lets `IOException`/`UnauthorizedAccessException` propagate.

**`Resolve-PSScriptBuilderSourceLocation`** — passes its resolved output path to
`Resolve([ErrorRecord], [string])`.

## Rationale and Alternatives

**Origin: path *or* content, rather than path only or content only.** Path only would reject an
unmodified copy of the output script (e.g. a deployed or installed copy), which a user can
legitimately want to resolve. Content only would hash on every call, and would turn the
documented "same path, changed content: stale warning, still resolves" behavior into a rejection.
Identifying an artifact by its content rather than its location is established practice for
debug-symbol matching (PDB GUIDs, ELF build IDs, JavaScript debug IDs); the path check is the
cheap fast path in front of it.

**Comparing against the call-time output path, not the sidecar's `OutputPath`.** The sidecar's
`OutputPath` is informational — it records where the build wrote the output. If the output and
its sidecar are moved together, the path the caller passes is the correct reference.

**Empty `ScriptName`: reject (A), rather than resolve with a warning (B) or an opt-in switch
(C).** `ScriptName` is empty for errors raised interactively or in code loaded via
`Invoke-Expression`, so the origin cannot be verified. The bug report suggested falling through
to the old behavior (B); rejected because programmatic callers would still receive a wrong object
next to a warning they may never see. (C) is deferred until someone asks for it; adding it later
is non-breaking.

**Throw versus warn.** Invalid arguments (null `ErrorRecord`, missing `InvocationInfo`, no valid
line number, empty `outputPath`) are caller errors and throw `ArgumentException`, as before. An
error that did not originate in the output script is a valid input that simply cannot be
resolved; it is handled like an unresolvable line number in `Resolve([int])`: a warning and
`$null`.

**Same path with changed content keeps resolving.** This is documented behavior (the cmdlet
emits a stale-map warning but still resolves); making it a rejection would be a breaking change
and is noted as a follow-up. Known harmless edge: an unmodified copy of the *previous* output
resolves correctly via its hash, but the cmdlet still prints the stale-map warning, because that
check compares the current output file.

**.NET hashing instead of `Get-FileHash`.** In Windows PowerShell 5.1, `Get-FileHash` is a script
function that reports read failures as non-specific exception types (`WriteErrorException`,
`ItemNotFoundException`), so they cannot be caught selectively; it was also observed to dispose a
caller-scope variable named `$stream` on failure. The .NET approach is byte-identical in its
result and throws `IOException`/`UnauthorizedAccessException` consistently on 5.1 and 7. It lives
in `PSScriptBuilderFileIOHelper` because hashing a file is file I/O, not resolver logic, and the
helper is the target for consolidating the existing `Get-FileHash` call sites later (see Scope).

**`ComponentLineCount` with 0 as "unknown", rather than a sidecar format version.** The field is
purely additive: older module versions ignore it, and older sidecars simply lack it. Treating a
missing value as "unknown, keep the old behavior" keeps both directions compatible without
introducing a format version now.

**Constructor overload rather than a default parameter value.** PowerShell class constructors and
methods accept default parameter values syntactically but silently ignore them (`::new(...)` with
fewer arguments fails with "Cannot find an overload"). The overload keeps every existing
7-argument caller working.

**Line counting via `String.Replace`, matching PowerShell's definition.** A source map must count
lines exactly as its consumer does. Three implementations were compared on 300 lookups in a
25,000-line output: the old `-split '\r?\n'` (about 1.7 s on PS 7 / 6.2 s on PS 5.1),
`[Regex]::Matches` (2.9 s / 4.2 s) and normalizing CRLF/CR to LF and counting via `Replace`
(0.6 s / 2.0 s). The `Replace` variant is both correct and the fastest. The helpers stay in the
generator rather than `PSScriptBuilderTextHelper`: it is their only consumer, and the "count like
PowerShell's parser" rule is specific to source maps.

## Scope

**In scope:** `PSScriptBuilderSourceLocation`, `PSScriptBuilderSourceMapGenerator`,
`PSScriptBuilderSourceMapFileManager`, `PSScriptBuilderSourceLocationResolver`,
`PSScriptBuilderFileIOHelper.ComputeSHA256Hash`, `Resolve-PSScriptBuilderSourceLocation`; unit
tests for all of them; documentation of the new property and the `-ErrorRecord` origin rule;
correcting the already wrong sample output in `examples/16-source-maps/README.md`; a
`CHANGELOG.md` entry; this RFC.

**Out of scope (deferred, considered but not rejected):**

- Switching the three existing `Get-FileHash` call sites for the output script to
  `ComputeSHA256Hash` — a refactoring that does not belong in this fix.
- A format version field in the sidecar — not needed for an additive field, but worth adding
  before any non-additive format change.
- An opt-in switch to resolve errors without a script file origin (option C above).
- Rejecting same-path errors when the content has changed — breaking change.

## Relationship to Other RFCs

None. No earlier RFC covers source maps or source location resolution.

## Test Plan

- **Unit, resolver:** resolution of a component's last line; a line after it, and a line between
  two components, are not resolved; `ComponentLineCount` 0 keeps the unbounded behavior;
  `ComponentLineCount` is carried over to the result. Origin check: same path in non-normalized
  form, same path with outdated hash, unmodified copy, different script, deleted script, unknown
  output hash, `Invoke-Expression` (empty `ScriptName`), unreadable script (locked file, Windows
  only) — each rejection with exactly one warning. The three existing `Resolve(ErrorRecord)` tests
  were adapted to the new signature, plus argument checks for `outputPath`.
- **Unit, generator:** `ComponentLineCount` of a multi-line component; a trailing line break of a
  file component is not counted. For LF, CRLF, CR-only and `\r\r\n`, the output script is actually
  executed and PowerShell's own `ScriptLineNumber` of an error inside the component is asserted
  together with the mapped start line and line count.
- **Unit, file manager / source location / file I/O helper / cmdlet:** sidecar round-trip of
  `ComponentLineCount`; reading a sidecar of an earlier version yields 0; both constructors;
  `ComputeSHA256Hash` equals `Get-FileHash`, empty file, file released after hashing, missing file
  (`FileNotFoundException`), locked file (`IOException`, Windows only); the cmdlet resolves an
  `ErrorRecord` from the output script and rejects one from a different script.
- **Mutation check:** before the tests were added to the repository, they were run against the
  repository classes with each fix removed in turn (extent check, origin check, new line
  counting) — exactly the corresponding new tests failed, and all passed with the fixes in place,
  under PS 5.1 and PS 7.
- **Full suite** (after a regular build): 2084 passed under PS 5.1 (0 failed, 0 skipped), 2083
  passed under PS 7 (0 failed, 1 skipped — a pre-existing PS 5.1-only test), including the new
  tests. Smoke tests (22 checks) and example tests (16 examples, including 16-source-maps and
  17-code-coverage against real builds) passed under both versions.

## Unresolved Questions

Whether the release is a patch or a minor version: the observable behavior changes only in cases
that previously returned wrong results, and the changed resolver method is an internal class
member, so a patch release is defensible — decided at release time.

## Revision Log

- 2026-11-04 — Implemented on `development` (commits pending). RFC written retroactively after
  implementation and full cross-version verification, to preserve the design decisions — in
  particular the origin rule (path or content), the rejection of errors without a script file
  origin, and the alignment of the source map's line counting with PowerShell's parser — for
  future maintainers.
- 2026-11-04 — The deferred sidecar format version was implemented before the release, see
  RFC 0024.
- 2026-11-04 — The origin check was first implemented as
  `IsFromMappedOutput(…, [ref] mismatchMessage)`. That only resembled the Try pattern: in the
  Try-Parse pattern of the .NET Framework Design Guidelines the out parameter carries the result
  of a successful operation and a throwing counterpart exists, whereas here it carried the reason
  for a negative answer. Outside the Try pattern the guidelines advise against out and ref
  parameters, so the check now returns a small result object instead —
  `PSScriptBuilderErrorOriginCheckResult`, created via `FromMappedOutput()` /
  `NotFromMappedOutput(message)` (methods rather than a static property, since PowerShell class
  properties cannot be read-only) — and is named with a verb phrase, `CheckErrorOrigin`. Its
  properties are domain-specific rather than `Succeeded`/`ErrorMessage` as in `IdentityResult` or
  `ValidationResult`, because a negative result is not a failed check. Behavior is unchanged.
- 2026-11-04 — The stale-map check of both cmdlets moved into
  `PSScriptBuilderSourceMapFileManager.GetStaleWarnings`, which hashes the output script via
  `ComputeSHA256Hash` (the last `Get-FileHash` call sites are gone). Found while doing so: a
  missing, locked or inaccessible output script produced a non-terminating error that differed
  between PowerShell versions plus the misleading warning that the script had changed. Following
  the PowerShell error-reporting guidelines — terminating only if the cmdlet cannot continue,
  errors for failed input objects, warnings for conditions the caller should know about — it now
  yields a single warning that staleness cannot be checked, and resolution continues, since it
  only needs the sidecar. The warnings are returned as `string[]` and written by the cmdlet:
  verified on PS 5.1 and 7, a warning written inside a class method reaches `3>&1` and honors
  `-WarningAction` but is not collected by the cmdlet's `-WarningVariable`. The same limitation
  affects warnings that other classes write directly; that is tracked separately.
