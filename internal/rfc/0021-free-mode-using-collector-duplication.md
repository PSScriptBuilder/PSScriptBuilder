# RFC 0021: Free Mode Using Collector Duplication

- **Status:** Implemented (2026-10-14) — written retroactively, after implementation and full
  verification; see Revision Log
- **Type:** Fix
- **Created:** 2026-10-14
- **Branch:** development (no dedicated branch — landed directly, same precedent as the
  multiple-Using-placeholder fix in commit `24e6e74`, which also has no RFC)

## Summary

In Free Mode, each registered `Using` collector was rendered into its own, independent
placeholder with only its own collector's statements — unlike Ordered/Hybrid Mode, where all
registered `Using` collectors are consolidated into one global, deduplicated block. If the same
`using namespace X` statement appeared in more than one `Using` collector's source files, the
final output script contained that statement twice. A literal duplicate `using namespace`
statement anywhere in a script's leading using-block silently breaks PowerShell's type resolution
for that namespace at runtime, with zero parse error and zero build warning. Free Mode's `Using`
handling is now identical to Ordered/Hybrid Mode's: always globally consolidated into exactly one
placeholder, regardless of how many `Using` collectors are registered.

## Motivation

Brought to this session as a real bug report from another project, originally
about something unrelated — `PSScriptBuilderCollectorCollection.GetAll()`'s collector *processing*
order depending on `Sort-Object`'s PS5.1/PS7 stability difference (fixed separately, as a pure
hardening with no behavior change, since RFC 0017's tie-break already made the reported build-
output symptom unreproducible on the development branch).

While verifying that report's claim that "Free Mode lets you register multiple `Using` collectors,
each with its own placeholder" was itself correct — it was, confirmed by direct, empirical testing
(two `Using` collectors, two placeholders, Free Mode: each placeholder received only its own
group's statements, not the global set) — the user asked what legitimate purpose this even serves,
since a single `Using` collector already supports multiple `-IncludePath` values with safe,
dictionary-keyed deduplication.

That question led to checking the actual risk of two independent `Using` collectors whose source
files happen to share a statement. Empirical, byte-level verification confirmed a severe, silent
PowerShell language behavior: a duplicate `using namespace` statement anywhere in a script's
leading using-block — adjacent or not — breaks type resolution for that namespace, with the parser
itself reporting zero errors (`[Parser]::ParseFile()` on the duplicate-containing script: 0 parse
errors; `[List[string]]::new()` later in the same script: `RuntimeException: Unable to find type
[List]`). Verified in both PowerShell 5.1 and PowerShell 7. `using module` and `using assembly`
duplicates do **not** have this problem — confirmed separately, only `using namespace` is affected.

This elevated the question from "is per-collector separation good design" to "this is a correctness
bug": Free Mode's `Using` behavior could silently produce a broken output script whenever two
`Using` collectors' source files happened to reference the same namespace, with no warning or
error anywhere in the build pipeline.

## Detailed Design

**`PSScriptBuilderTemplateProcessor.DiscoverReplacements()`** (Free Mode's per-collector discovery
loop) — now skips `UsingCollector`-type collectors entirely (mirroring the existing skip pattern
already used by `ValidateUsingPlaceholderOrder`), since `Using` placeholders are handled
separately.

**`PSScriptBuilderTemplateProcessor.RenderFreeMode()`** — now additionally calls
`DiscoverUsingReplacement($template)` and merges its result into the replacements list, exactly as
`RenderOrderedMode()` already did. `DiscoverUsingReplacement()` required no changes: it already
implemented precisely the needed behavior (first-registered `Using` collector whose placeholder is
found in the template wins, filled via `GetConsolidatedUsingStatements()`, a fallback comment if
empty) — this is pure reuse across both modes, not new logic. Its docstring, previously scoped to
"the Using half of Ordered/Hybrid Mode's discover phase", was reworded to reflect that it now
serves every mode.

**`PSScriptBuilderTemplateValidator.ValidateCollectorPlaceholdersExist()`** (Free Mode's "every
collector needs its own placeholder" check) — now skips `UsingCollector`-type collectors, since
they no longer need one placeholder each.

**`ValidateNoMultipleUsingPlaceholdersInOrderedMode()` → `ValidateUsingPlaceholderCount()`** —
renamed to reflect that it is no longer Ordered/Hybrid-specific, and now called from
`ValidateInFreeMode()` as well as `ValidateInOrderedMode()`. Its check was also widened: previously
it only rejected *more than one* `Using` placeholder; it now also rejects *zero* `Using`
placeholders when one or more `Using` collectors are registered. This closes an incidental,
pre-existing gap discovered while generalizing the method — Ordered/Hybrid Mode had never actually
required a `Using` placeholder to exist, silently dropping the consolidated statements if one
wasn't present.

**`PSScriptBuilderContentProcessor.BuildCollectorContent()`** — its `UsingCollector` switch branch,
whose own comment already read "this is a fallback for individual Using collectors in Free Mode",
is now genuinely unreachable (Free Mode no longer routes `Using` collectors through this method)
and was removed rather than left in place; no unit test covered it directly.

## Rationale and Alternatives

**Why "always consolidate" rather than "detect and reject the risky overlap".** An earlier option
considered keeping per-collector placeholders in Free Mode but validating that no two registered
`Using` collectors share a statement, failing the build if they did. Rejected: `using namespace`
statements are fungible and order-irrelevant (unlike named, identity-bearing `Class`/`Function`
components, where separate placeholders give real readability value), so per-collector output
separation has no benefit worth preserving — it was purely incidental fallout of the generic
collector-registration architecture applying uniformly to all five collector types. Removing the
capability removes the entire bug class, not just the specific overlapping-namespace instance of
it, and makes `Using` behave identically in every mode instead of needing mode-specific mental
models.

**Confirmed no existing usage depended on the old behavior.** No test or example in the repository
relied on Free Mode's multiple-`Using`-collectors-with-separate-placeholders behavior. The
`PSScriptBuilderTemplateStressTest` fixture's four `Using` collectors already consolidate into one
Ordered Mode placeholder; its deliberately-invalid "Broken" variant with two placeholders is the
*rejected* case the validator is supposed to catch, not a usage to preserve.

**Why generalize `ValidateNoMultipleUsingPlaceholdersInOrderedMode()` instead of writing a second,
Free-Mode-specific method.** The two modes now require the exact same rule (consolidated into
`DiscoverUsingReplacement()`'s logic, used by both); a second method would have duplicated the
same check with a second place to keep in sync.

## Scope

**In scope:** `PSScriptBuilderTemplateProcessor` (`DiscoverReplacements`, `RenderFreeMode`,
`DiscoverUsingReplacement`'s docstring), `PSScriptBuilderTemplateValidator`
(`ValidateCollectorPlaceholdersExist`, the renamed `ValidateUsingPlaceholderCount`, its two
callers), `PSScriptBuilderContentProcessor` (dead-code removal in `BuildCollectorContent`), updated
and new regression tests, `docs/guides/collectors.md` and `docs/guides/templates.md`, a
`CHANGELOG.md` entry.

**Out of scope:** The `GetAll()` collector-ordering hardening found and fixed in the same
investigation — unrelated root cause (processing order vs. Using-statement duplication), already
shipped separately (commit `c066a35`, no CHANGELOG entry — pure hardening, no observable behavior
change). Any change to `using module`/`using assembly` handling — confirmed not affected by the
duplicate-statement defect this RFC addresses.

## Relationship to Other RFCs

Builds directly on RFC 0003 (introduced the `Discover*`/two-phase discovery pattern this fix
extends to Free Mode) and generalizes the validation added in commit `24e6e74` ("reject multiple
Using placeholders in an Ordered/Hybrid Mode template" — itself landed without an RFC) to apply in
every mode instead of only Ordered/Hybrid. Related to, but independent of, the `GetAll()`
collector-ordering hardening found in the same investigation (see Scope) and RFC 0017
(`PSScriptBuilderTopologicalSortReadyQueue`'s tie-break, which made the originally-reported
`GetAll()` symptom unreproducible before this RFC's fix was even designed).

## Test Plan

- **Unit, `PSScriptBuilderTemplateProcessor`**: two `Using` collectors with an overlapping
  namespace, Free Mode, a single placeholder — the overlapping statement appears exactly once in
  the rendered output, and the other collectors' distinct statements are all present.
- **Unit, `PSScriptBuilderTemplateValidator`**: updated three existing tests that asserted the old,
  now-intentionally-changed behavior (multiple independent `Using` placeholders tolerated in Free
  Mode; a missing `Using` placeholder tolerated in Hybrid Mode despite registered `Using`
  collectors) to expect the validation error instead. Added a test for the new "Using collectors
  registered but no placeholder present" error message.
- **End-to-end**: built and executed the original overlapping-namespace repro against the real,
  built module — the generated script contains each statement exactly once and runs correctly
  (`[List[string]]::new()` resolves without error), confirming the fix holds outside the unit-test
  harness too.
- **Full suite**: 2045 passed under PS 5.1, 2044 passed under PS 7 (both 0 failed), including the
  updated and new tests above. PSScriptAnalyzer unchanged (1 known false-positive).

## Unresolved Questions

None. The fix is a straightforward generalization of already-proven logic (`DiscoverUsingReplacement`,
in production use for Ordered/Hybrid Mode since RFC 0003) to a second mode, with no new mechanism
introduced.

## Revision Log

- 2026-10-14 — Implemented directly on `development` (commits `cacd450`, `9232385`, `77dc767`,
  `101d455`, `77553e9`, `d238f43`, `a71efa2`, `b0feb30`, `dbaa4c5`). RFC written retroactively,
  after implementation and full verification, to preserve the investigative narrative — in
  particular how a collector-ordering bug report led, via a design question about the purpose of
  multiple `Using` collectors, to discovering an unrelated but more severe correctness bug — for
  future maintainers, matching this project's established practice of documenting non-obvious
  fixes even when the RFC follows rather than precedes the code.
