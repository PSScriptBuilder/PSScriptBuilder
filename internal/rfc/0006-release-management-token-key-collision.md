# RFC 0006: Release-Management-Token Key Collision

- **Status:** Implemented (2026-09-03)
- **Type:** Fix
- **Created:** 2026-09-02
- **Branch:** `refactor/template-engine-consolidation`

## Summary

`PSScriptBuilderBumpReplacementHelper` defines a fixed, built-in vocabulary of twenty-one Release
Management token names (`VERSION`, `BUILD_DATE`, `GIT_COMMIT`, etc.). Nothing prevents a collector
from being registered with a `CollectionKey` identical to one of these, and nothing prevents the
active `-OrderedComponentsKey` itself from being one of these either. In both cases, when the same
`.template` file is also bump-managed for that token, Release Management runs first (before the
build ever sees the template) and consumes the placeholder — the build then fails with a confusing,
misleading error that points at "typos" instead of the real, invisible cross-subsystem cause.

## Motivation

Found 2026-09-02 while examining whether a collector's `CollectionKey` colliding with a Release
Management token name is a problem. Initially assumed (incorrectly) that bump-token names are
freely user-chosen project-specific text — corrected after reading
`PSScriptBuilderBumpReplacementHelper.DefaultRegexPatterns` directly: it is a fixed, hardcoded
static property with exactly twenty-one entries, each with a standards-compliant regex (ISO 8601,
SemVer, Git conventions):

```
BUILD_DATE, BUILD_TIME, BUILD_DAY, BUILD_MONTH, BUILD_YEAR, BUILD_HOUR, BUILD_MINUTE, BUILD_SECOND,
BUILD_TIMESTAMP, BUILD_NUMBER, GIT_COMMIT, GIT_COMMIT_SHORT, GIT_BRANCH, GIT_TAG,
VERSION, VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH, VERSION_FULL, VERSION_PRERELEASE,
VERSION_BUILDMETADATA
```

This is PSScriptBuilder's own, built-in vocabulary — not arbitrary per-project configuration. That
makes it directly analogous to RFC 0002's `ORDERED_COMPONENTS`: a small, fixed, PSScriptBuilder-
owned name that nothing currently protects a `CollectionKey` from colliding with.

**Repro — real build, both pipeline stages exercised directly:** a `Class` collector with
`-CollectionKey "VERSION"`, template `{{VERSION}}`. Simulated the real release pipeline order
(Release Management runs before the build) using the actual `PSScriptBuilderBumpReplacementHelper`
class directly:

```
Template as authored:                    {{VERSION}}
After PSScriptBuilderBumpReplacementHelper.ApplySimpleReplacements('VERSION' -> '1.3.0'): 1.3.0
```

Running the real build against that (already bump-processed) file:

```
Test-PSScriptBuilderTemplate: False
Invoke-PSScriptBuilderBuild: FAILED
  "Template validation failed: Template does not contain placeholders for 1 registered
   collector(s): {{VERSION}}. Check for typos in your template or CollectionKey configuration."
```

**This is not silent corruption** — unlike RFC 0002/0003/0004, `ValidateCollectorPlaceholdersExist`
already fails the build loudly today. The problem is diagnostic quality: the message suggests a
typo or local misconfiguration, when the real cause is an entirely different, already-run
subsystem having consumed the placeholder before the build ever started. A user looking at their
template file at this point sees only `1.3.0` where their placeholder used to be, with no visible
link to Release Management at all.

**Affected scope:** Free Mode (any collector type), and `Using`/`File` collectors specifically in
Ordered/Hybrid Mode (they retain individual placeholders there). Enum/Class/Function collectors in
Ordered/Hybrid Mode are unaffected — their content only ever funnels through the single
`{{ORDERED_COMPONENTS}}` placeholder, which does not individually carry a collector's own
`CollectionKey` text.

**Repro 2 — the `-OrderedComponentsKey` parameter itself, not a collector's key:** found during a
further re-analysis pass. The same collision exists one level up: nothing prevents
`-OrderedComponentsKey` itself from being one of the twenty-one reserved names. A real `Class`
collector, template `{{VERSION}}`, built with `-OrderedComponentsKey "VERSION"`. Same simulated
pipeline order as Repro 1 — Release Management runs first and turns `{{VERSION}}` into `1.3.0`.
Running the real build against that file:

```
Test-PSScriptBuilderTemplate: False
Invoke-PSScriptBuilderBuild: FAILED
  "Template validation failed: Template does not contain placeholders for 1 registered
   collector(s): {{CLASS_DEFINITIONS}}. Check for typos in your template or CollectionKey
   configuration."
```

Since `{{VERSION}}` no longer exists in the template by the time the build runs, mode detection
never escalates to Ordered/Hybrid Mode (nothing in the template looks like an ordered-components
placeholder anymore) — the build fails in Free Mode instead, over the *Class* collector's own
missing placeholder, an even less direct error message than Repro 1's. Same underlying cause,
same fix category: `-OrderedComponentsKey` is exactly as "special" to PSScriptBuilder as a
collector's `CollectionKey` and is exposed to the identical cross-subsystem risk.

## Detailed Design

### Root Cause

Same structural gap as RFC 0002 — no reserved-word protection for a name PSScriptBuilder itself
defines and treats specially — but a different reserved-word namespace: Release Management's
built-in token vocabulary instead of `ORDERED_COMPONENTS`.

### Decision

Add a validation-time check, structurally the same kind RFC 0002 introduces: reject any collector
whose `CollectionKey`, *or* the active `-OrderedComponentsKey` itself, case-insensitively equals one
of the twenty-one names in `PSScriptBuilderBumpReplacementHelper.DefaultRegexPatterns`, with a clear,
specific error, e.g.:

> "Collector with CollectionKey 'VERSION' collides with a name reserved for Release Management
> bump-file tokens; rename the collector's key to avoid a confusing failure if this file is ever
> bump-managed."

> "OrderedComponentsKey 'VERSION' collides with a name reserved for Release Management bump-file
> tokens; pass a different -OrderedComponentsKey to avoid a confusing failure if this file is ever
> bump-managed."

Both checks share the same reserved-name list and the same case-insensitive comparison — only the
value being checked differs (a collector property, iterated per collector, vs. a single build
parameter, checked once).

**Unlike RFC 0002, this check must run regardless of mode.** RFC 0002's check could be proven to
only need Ordered/Hybrid Mode, because the *specific* name `ORDERED_COMPONENTS` colliding is what
triggers `HasOrderedPlaceholder`'s mode escalation in the first place — the collision and the mode
switch are the same event. None of these twenty-one names has that special relationship with mode
detection: a collector named `VERSION` in a genuine Free Mode project triggers no escalation at all
and would otherwise pass through untouched. The check must therefore be applied unconditionally.
Implemented in the shared `Validate()` method itself, before the mode branch — not duplicated into
both `ValidateInFreeMode` and `ValidateInOrderedMode` — the same placement `ValidateParameters()`
already uses for its own mode-independent checks.

**Scoped to the built-in default vocabulary only — not custom bump tokens.** A project can extend
`PSScriptBuilderBumpReplacementHelper` with custom token names via its own `RegexPatterns`
constructor parameter (see its test suite). Those *are* arbitrary, project-specific text, unlike
the built-in twenty-one — reserving them universally would reintroduce exactly the "arbitrary user
text" problem this RFC's design deliberately avoids for the fixed set. Custom tokens are out of
scope (see Scope).

### Why a universal reservation, not a per-file check

The precise version of this check would only reject a collision when the *specific* template file
being validated is *also* configured as a bump target for that *specific* token — but that would
require `PSScriptBuilderTemplateValidator` to read and understand `psscriptbuilder.bumpconfig.json`,
a real, new architectural coupling between Template Validation and Release Management that this
branch has already deliberately avoided (see RFC 0001's Release Management exclusion). It would
also mean a collector's validity depends on a *different* file's configuration, which can change
independently later — the same "spooky action at a distance" problem that context-sensitive
keywords cause in programming language design, and the reason mainstream languages reserve a fixed
keyword list globally rather than only where a collision would currently bite. A universal,
static-list reservation avoids both problems at near-zero cost: none of these twenty-one names is a
plausible, intentional choice for a collector representing actual program logic (an `Enum`, `Class`,
`Function`, `Using`, or `File` collector called `GIT_COMMIT_SHORT` or `BUILD_TIMESTAMP` would be a
surprising name regardless of Release Management).

## Rationale and Alternatives

**Considered: a precise, per-file check requiring the Validator to read `bumpconfig.json`.**
Rejected — real, new coupling between two subsystems this branch has repeatedly kept independent
(see RFC 0001), and introduces the "collision depends on a different file's current configuration"
problem described above.

**Considered: a warning instead of a hard validation error.** Rejected for consistency with RFC
0002's treatment of `ORDERED_COMPONENTS` (also a hard error, not a warning), and because the actual
goal is a *clear* failure, not merely a *loud* one — today's failure is already loud
(`Invoke-PSScriptBuilderBuild` throws), but its message is misleading. A warning could be missed
entirely if `-WarningAction SilentlyContinue` or similar is set; a validation error at the correct
diagnostic layer, naming Release Management explicitly, is the more reliable fix for the actual
problem (message quality), not just detection.

**Considered: documentation only, no enforcement.** Rejected — the technical safeguard is a small,
static list check (near-zero implementation cost, no new coupling), and today's error message is
actively misleading without it; documentation alone doesn't fix that.

## Scope

**In scope:** a validation-time check rejecting any collector's `CollectionKey`, *and separately*
the active `-OrderedComponentsKey` itself, that case-insensitively matches one of the twenty-one names
in `PSScriptBuilderBumpReplacementHelper.DefaultRegexPatterns`, applied in both Free and
Ordered/Hybrid Mode validation, for all collector types.

**Out of scope:**
- Custom bump token names registered via `PSScriptBuilderBumpReplacementHelper`'s custom
  `RegexPatterns` constructor parameter — genuinely arbitrary, project-specific text, not part of
  PSScriptBuilder's own fixed vocabulary (see Detailed Design).
- Any change to Release Management's own behavior — consistent with RFC 0001's decision, Release
  Management's existing token-replacement logic is not touched by this RFC either.
- Documenting this as a named caveat in `docs/guides/collectors.md` — a documentation decision
  independent of the validation fix landing (see Unresolved Questions).

## Relationship to Other RFCs

- **RFC 0002** (ordered-components-key collision) — same structural root cause (no reserved-word
  protection for a PSScriptBuilder-owned name) and the same kind of fix, applied to a different,
  additional reserved-word namespace. Not otherwise dependent — can land independently, and the two
  checks could share an implementation detail (e.g., a combined "reserved keys" check) at
  implementation time without changing either RFC's decision.
- **RFC 0004** (placeholder case-sensitivity mismatch) — this RFC's comparison must be
  case-insensitive, consistent with RFC 0004's established standard.

See `internal/rfc/IMPLEMENTATION-PLAN.md` for where this fits in the build order.

## Test Plan

- Regression test: a Free Mode collector with `-CollectionKey "VERSION"` (or any of the other
  nineteen reserved names) must fail validation with a clear, Release-Management-specific error,
  not proceed to the misleading "missing placeholder" failure.
- Regression test: the same collision in an Ordered/Hybrid Mode context (a `File` or `Using`
  collector, which retain individual placeholders there) must also be rejected.
- Regression test: a differently-cased reserved name (e.g. `"version"`) must also be rejected —
  confirms case-insensitive comparison.
- Non-regression test: a collector with a *custom*, non-default bump token name (one not in
  `DefaultRegexPatterns`) must **not** be rejected — confirms the check is scoped to the built-in
  vocabulary only.
- Regression test: a build with `-OrderedComponentsKey "VERSION"` (or any other reserved name) must
  fail validation with a clear, Release-Management-specific error, regardless of whether any
  collector is involved — confirms Repro 2 is covered.
- Regression test: a differently-cased `-OrderedComponentsKey` (e.g. `"version"`) must also be
  rejected — confirms case-insensitive comparison applies to this check too.

## Unresolved Questions

- ~~Should this be documented as a named caveat in `docs/guides/collectors.md`~~ — **resolved:**
  yes, documented (see Revision Log).
- ~~Should the error message enumerate all twenty-one reserved names, or just name the one that
  collided?~~ — **resolved:** just the one, as implemented; the full list lives in documentation.

## Revision Log

- 2026-09-16 — Corrected the Status header, which still said "Decided — design complete, not
  yet implemented" despite this RFC having been implemented and pushed on 2026-09-03 (see below).
  No decisions changed — documentation accuracy only, found while reviewing outstanding RFCs
  ahead of the 1.3.0 release.
- 2026-09-03 — Documented the reserved Release Management token names in
  `docs/guides/collectors.md` (Collection Keys), cross-referencing `release-management.md`'s
  Version/Build/Git Tokens reference tables for the full list rather than repeating an exact
  count in prose (the count can change; it isn't relevant to the point being made). A duplicate
  note was initially also added to `docs/guides/templates.md`'s "Combining with Release
  Management Tokens" section, then removed: that section is about a template containing *real*
  RM tokens alongside collector placeholders, not about collector key naming — a different
  concern, already covered in `collectors.md`. Closes both remaining open questions
  (documentation, and confirming the error message names only the one colliding key, not the
  full list).
- 2026-09-03 — Implemented and pushed: two new methods,
  `ValidateNoCollectionKeyCollidesWithReleaseManagementToken` and
  `ValidateOrderedComponentsKeyDoesNotCollideWithReleaseManagementToken`, called unconditionally
  from the shared `Validate()` method before the mode branch (not duplicated into
  `ValidateInFreeMode`/`ValidateInOrderedMode` — see Detailed Design). Corrected this RFC's own
  "twenty" miscounts to twenty-one throughout, found while re-verifying against the actual
  `DefaultRegexPatterns` hashtable (`Keys.Count: 21`) before implementing — the code itself was
  never wrong, only this RFC's prose. Also verified `DefaultRegexPatterns`'s `.Contains()` lookup is
  already case-insensitive (PowerShell's `@{}` literal default), simplifying the comparison to a
  direct `.Contains()` call. All Test Plan items covered and green, including the Ordered-Mode
  (`File` collector) regression test added during implementation. `CHANGELOG.md` entry added under
  `### Fixed`. See `internal/rfc/IMPLEMENTATION-PLAN.md` for phase-level tracking.
- 2026-09-02 — Added Repro 2: the `-OrderedComponentsKey` parameter itself (not just a collector's
  `CollectionKey`) can equally collide with a reserved Release Management token name — verified
  with a real build. Same root cause and fix category as Repro 1, per the established "one root
  cause, one RFC" criterion — folded in as an expanded scope rather than a new RFC. Expanded
  Decision/Scope/Test Plan accordingly.
- 2026-09-02 — Initial finding, in response to a direct question about collector keys colliding
  with Release Management tokens. Corrected an initial incorrect assumption that bump-token names
  are arbitrary, project-specific text — verified they are a fixed, twenty-one-item, PSScriptBuilder-
  owned vocabulary. Verified the real repro (confusing but non-silent failure) using the actual
  `PSScriptBuilderBumpReplacementHelper` class directly. Decided on a universal, static-list
  reservation (not a per-file check) after applying the "global vs. context-sensitive reserved
  keyword" principle from programming-language design.
