# RFC 0009: Release Management Cross-Item Sequential Value Collision

- **Status:** Implemented (2026-09-07)
- **Type:** Fix
- **Created:** 2026-09-02
- **Branch:** `refactor/template-engine-consolidation`

## Summary

`PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()` applies multiple `bumpFiles` entries
and multiple `items` for the same file **sequentially**, threading the in-memory content from one
replacement call to the next — a documented, intentional "multi-phase processing" feature. This
sequential threading has an undocumented side effect: a later item can accidentally match and
corrupt text that an *earlier* item's value inserted, if that inserted text happens to resemble the
later item's target pattern. This is the same abstract "sequential mutation causes re-scanning of
inserted content" defect RFC 0003 and RFC 0007 already fix — but in a third, structurally
independent location (`PSScriptBuilderBumpFilesProcessor.ps1`, not touched by either), so it is not
fixed by either of those RFCs.

## Motivation

Found 2026-09-02 while re-analyzing before implementing RFC 0007. RFC 0007 makes
`ApplySimpleReplacements`/`ApplyPlaceholderReplacements` safe *within a single call's own tokens
array*. But `PSScriptBuilderBumpFilesProcessor` calls these methods (and `ApplyPatternReplacements`)
**multiple times**, once per `items` entry and once per `bumpFiles` entry for the same file path,
feeding each call's output forward as the next call's input (`$newContent = $result.Content`).

**This chaining is not a bug in itself — it is documented and tested:**
`docs/guides/release-management.md`: *"Multiple items can target the same file, and the same path
can appear more than once in `bumpFiles`. In both cases, all entries are applied sequentially to the
same in-memory content before writing — making multi-phase processing possible."* Backed by an
existing test, `'Should apply two entries for the same file sequentially (two-phase bumping)'`. The
intended use (documented Entry 3 example in the same guide) is a **same-token**, two-state idiom:
one item matches a `{{TOKEN}}` placeholder for a freshly-initialized file, another matches a regex
pattern against the already-substituted real value for subsequent bumps — safe, because both items
target the identical token.

**The undocumented, unintended case: a later item corrupts an *earlier* item's inserted value for a
*different* token.** Verified with three real repros, using the actual class exactly as
`PSScriptBuilderBumpFilesProcessor` calls it:

- **Simple Mode:** `GIT_BRANCH = 'feature/{{VERSION}}'`, `VERSION = '1.3.0'`, content
  `'Branch: {{GIT_BRANCH}}, Version: {{VERSION}}'`. Item 1 (`GIT_BRANCH`) correctly produces
  `'Branch: feature/{{VERSION}}, Version: {{VERSION}}'`. Item 2 (`VERSION`), run on this
  already-modified content, finds `{{VERSION}}` in *two* places — the real one, and the one that
  just arrived inside `GIT_BRANCH`'s own value — and corrupts both:
  `'Branch: feature/1.3.0, Version: 1.3.0'`.
- **Placeholder Mode:** identical corruption via `ApplyPatternReplacements` with two separate
  `{{TOKEN}}`-style items.
- **Regex Mode:** safe *only* when the pattern includes enough surrounding literal context to avoid
  matching inside a previously-inserted value (verified: a pattern anchored with `"Version: ("` did
  not cross-match). With a less specific pattern (no distinguishing prefix), the identical
  corruption occurs: a `GIT_BRANCH` value `'feature/(1.3.0)'` inserted by item A had its `(1.3.0)`
  portion incorrectly matched and overwritten by item B's under-anchored `VERSION_FULL` pattern.

**This is not a narrow edge case for this project specifically** — PSScriptBuilder's own production
`build/Release/psscriptbuilder.bumpconfig.json` uses exactly this multi-item shape: one `bumpFiles`
entry with five sequential items (`VERSION_FULL`, `BUILD_TIMESTAMP`, `BUILD_NUMBER`,
`GIT_COMMIT_SHORT`, `GIT_BRANCH` — `GIT_BRANCH` last, after four other items have already inserted
their values).

**Researched whether comparable tools solve this before designing a fix.** "Bump My Version" (the
actively maintained, most directly comparable tool — identical "multiple entries applied
sequentially to the same file" design) has **no safeguard against this** — its own "Avoid incorrect
replacements" guidance addresses only single-rule pattern precision, not cross-rule collisions;
users are expected to write sufficiently specific patterns. npm/semantic-release avoid the entire
class for structured files (`package.json`) by parsing and mutating the object model instead of
using text substitution — not directly applicable here, since PSScriptBuilder is deliberately
format-agnostic (arbitrary text files, not just structured formats). The formally relevant computer
science concept is **Hygienic Macros** (Scheme, Rust, Dylan, Nim, Julia): preventing one expansion's
generated text from being accidentally reinterpreted/captured by another expansion rule, solved via
provenance ("coloring") or unique-identifier tracking — the same shape as the fix below, verified
independently before this research confirmed it maps to an established pattern rather than an
ad-hoc invention.

**Decision to fix rather than document as a known limitation:** grounded in the Cost of Quality
principle (fixing a known, understood, already-verified defect now is cheaper than a silently
corrupted release artifact discovered later) and consistency with this project's own established
bar — RFC 0002/0006/0007/0008 all close silent-failure classes rather than documenting them as
limitations. The deciding factor making this affordable: the fix is an incremental extension of
RFC 0007's discover/assemble rewrite, not a separate large undertaking (see Detailed Design).

## Detailed Design

### Root Cause

`PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()` threads `$newContent` across both the
outer loop over `bumpFiles` entries grouped by path, and the inner loop over one entry's `items`,
calling `ApplySimpleReplacements`/`ApplyPatternReplacements` once per entry/item. Each call receives
only the current content string — it has no way to distinguish text that came from the original file
from text inserted by an earlier call for a *different* token, and therefore cannot tell a real
placeholder occurrence apart from incidental, coincidentally-matching text inside another token's
freshly-substituted value.

### Decision

Extend RFC 0007's new discover/assemble methods (`ApplySimpleReplacements`,
`ApplyPlaceholderReplacements`) — and, for the same reason, `ApplyRegexReplacements`/
`ApplyMatchesWithCaptureGroups` — to accept and return a **protected-span ledger**: an ordered list
of `(Start, Length, Token)` tuples describing regions of the *current* content that were produced by
a specific token's own prior substitution.

1. **Discover** (as RFC 0007 already does), with one added filter: a candidate match is skipped if
   its range overlaps a protected span whose `Token` differs from the token currently being
   processed. A match is accepted if it lies entirely outside all protected spans, **or** inside a
   span belonging to the *same* token (preserves the documented same-token multi-phase idiom).
2. **Assemble** (as RFC 0007 already does), with one added bookkeeping step per accepted
   replacement: shift the `Start`/`Length` of existing spans that follow the edit point by the
   length delta, then register the freshly-inserted text as a new span tagged with the current
   token.

`PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()` threads this ledger alongside
`$newContent` through both loop levels (across `items` within one entry, and across multiple
`bumpFiles` entries for the same path), resetting it to empty at the start of each new file-path
group.

**Verified with a real, isolated prototype** implementing exactly this algorithm (Discover with the
same-token exception, Assemble with span-shifting) against both:
- the real corruption repro (`GIT_BRANCH`/`VERSION`) — now produces the correct
  `'Branch: feature/{{VERSION}}, Version: 1.3.0'` instead of the corrupted result, and
- the documented same-token multi-phase idiom — continues to produce the correct result unchanged,
  confirming the fix does not break the feature it must coexist with.

## Rationale and Alternatives

**Considered: document as a known limitation, recommend specific/anchored patterns (Bump My
Version's approach).** Rejected — see Motivation's Cost-of-Quality reasoning; inconsistent with this
project's own established practice of closing silent-failure classes rather than documenting them,
especially once an affordable, verified fix design exists.

**Considered: parse structured file formats (JSON, `.psd1`) and mutate them programmatically instead
of text/regex substitution (npm/semantic-release's approach).** Rejected as the *general* fix —
PSScriptBuilder's bump-file mechanism is deliberately format-agnostic (arbitrary text files,
templates, source code), and a parser-based approach cannot be universal across those. Could be a
valuable, independent, format-specific enhancement in the future, but does not address the general
case this RFC covers and is out of scope here.

**Considered: discover all items' matches against the pristine original content (ignore chaining
entirely), instead of provenance-tagged spans.** Rejected — while this happens to still produce a
correct result for the specific documented Entry-3 idiom (the two items' patterns are mutually
exclusive against the pristine original: a freshly-initialized file matches only the placeholder
item, an already-bumped file matches only the regex item), that correctness is coincidental to this
one idiom's shape, not a deliberate property of the approach. It does not generalize: it would
silently produce a no-op for any legitimate design that genuinely relies on a later item seeing an
earlier item's inserted text. Provenance-tagged spans preserve the loop's documented "later item
sees earlier item's output" semantics exactly where intended (same token) and block it only where it
is not (different token) — a precise fix rather than one that works by coincidence.

## Scope

**In scope:** `PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()`'s orchestration loop
(thread a protected-span ledger across `items` and `bumpFiles` entries for one file, reset per file);
extending RFC 0007's new `ApplySimpleReplacements`/`ApplyPlaceholderReplacements` discover/assemble
methods, and `ApplyRegexReplacements`/`ApplyMatchesWithCaptureGroups`, to accept, respect, and return
the ledger.

**Out of scope:** parser-based structured-file updates (noted above as a possible independent future
enhancement); anything already covered by RFC 0006 (key collisions), RFC 0007 (within-one-call value
collisions), or RFC 0008 (case-insensitivity).

## Relationship to Other RFCs

- **RFC 0007** (sequential value collision) — this RFC's fix is built directly on top of RFC 0007's
  new discover/assemble methods, extending them with protected-span tracking. Cannot be implemented
  before RFC 0007 lands. Same relationship RFC 0008 already has to RFC 0007.
- **RFC 0008** (case-insensitivity) — independent of this RFC (different concern: comparison mode,
  not provenance), but both build into the same methods RFC 0007 introduces. Implementing them
  together/adjacently avoids touching the same methods three separate times.
- **RFC 0003** (Ordered/Hybrid Mode template injection) — same abstract anti-pattern (sequential
  mutation causing re-scanned inserted content) as this RFC and RFC 0007, but a third, independent
  implementation in the Template system rather than Release Management; tracked separately per the
  established "same code vs. same pattern" distinction.

See `internal/rfc/IMPLEMENTATION-PLAN.md` for where this fits in the build order.

## Test Plan

- Regression test: two items (or two `bumpFiles` entries) targeting *different* tokens, where an
  earlier item's token value contains text matching a later item's placeholder/pattern — the later
  item must not corrupt the earlier item's inserted value. Cover Simple Mode, Placeholder Mode, and
  Regex Mode (with an under-anchored pattern, matching the real repro).
- Non-regression test: the existing documented multi-phase idiom (same token, two items — placeholder
  then regex, or vice versa) continues to work unchanged — locks in the existing
  `'two-phase bumping'` test's behavior.
- Non-regression test: multiple occurrences of the *same* token across multiple items/`bumpFiles`
  entries all still get replaced correctly — the protected-span logic must not accidentally block
  legitimate same-token re-application.

## Unresolved Questions

The exact API shape for threading the protected-span ledger through
`ApplySimpleReplacements`/`ApplyPlaceholderReplacements`/`ApplyRegexReplacements` (an additional
parameter/return field vs. a small dedicated state object) is an implementation detail, not decided
here — does not block finalizing the design above.

## Revision Log

- 2026-09-07 — Implemented. Extended `ApplySimpleReplacements`, `ApplyPlaceholderReplacements`, and
  `ApplyRegexReplacements`/`ApplyMatchesWithCaptureGroups` to accept and return a protected-span
  ledger, then added a ledger-aware `ApplyPatternReplacements` overload once both dispatched modes
  supported it - deferred until then so the dispatcher's public signature would never silently
  accept a ledger it could not yet fully honor for one of its two modes. Wired
  `PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()` to thread the ledger across both
  loop levels (`bumpFiles` entries and `items`), reset per file-path group. `ApplyMatchesWithCaptureGroups`
  was restructured to delegate its actual content assembly to the shared `AssembleFromReplacements`
  method instead of its own back-to-front splicing, removing the need for back-to-front processing
  across matches (the inner, within-match capture-group loop still needs it, for unrelated reasons).
  A case-sensitivity issue was found and fixed while implementing Placeholder Mode's content-level
  search: it must stay case-sensitive - RFC 0008's token-name case-insensitivity does not extend to
  a pattern's own literal text. Verified with real-class harnesses against the exact repros from
  Motivation, the documented same-token multi-phase idiom, and existing test suite scenarios, before
  each step. Full suite: 1883 passed, 0 failed - both previously-red end-to-end tests now pass.
- 2026-09-02 — Initial finding, while re-analyzing before implementing RFC 0007. Verified the
  cross-item/cross-entry corruption with three real repros (Simple, Placeholder, and
  under-anchored Regex Mode) and confirmed PSScriptBuilder's own production `bumpconfig.json` uses
  the vulnerable multi-item shape. Confirmed via `docs/guides/release-management.md` and an existing
  test that the underlying sequential chaining is a documented, intentional feature, not itself a
  bug. Researched comparable tools (Bump My Version: no safeguard, relies on pattern specificity)
  and the relevant named CS concept (Hygienic Macros) before deciding, on Cost-of-Quality grounds, to
  fix rather than document as a limitation. Verified the protected-span fix design with a real,
  isolated prototype against both the corruption repro and the documented same-token multi-phase
  idiom. Decided as a separate RFC (not folded into RFC 0007) per the established "same broken code
  vs. same abstract pattern" convention, using RFC 0007/RFC 0008's existing relationship as direct
  precedent for a closely-coupled-but-distinct root cause.
