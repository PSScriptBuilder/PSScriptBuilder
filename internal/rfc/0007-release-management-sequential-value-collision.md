# RFC 0007: Release Management Sequential Value Collision

- **Status:** Implemented (2026-09-05)
- **Type:** Fix
- **Created:** 2026-09-02
- **Branch:** `refactor/template-engine-consolidation`

## Summary

Two of `PSScriptBuilderBumpReplacementHelper`'s three replacement methods
(`ApplySimpleReplacements`, `ApplyPlaceholderReplacements`) process tokens sequentially, calling
`.Replace()` on the already-modified result of the previous step. When one token's *value* happens
to contain another token's placeholder text — a real, git-permitted possibility for `GIT_BRANCH`/
`GIT_TAG`, not just a theoretical one — the inserted value gets silently re-scanned and corrupted
by a later replacement step, with the outcome depending on token processing order. The third method,
`ApplyRegexReplacements`, is already immune by design — see Motivation.

## Motivation

RFC 0001 previously considered this class of problem ("value collision") and ruled it out as
impractical, reasoning that bump-file token values are machine-generated (versions, timestamps,
git hashes), not user-authored free text. That premise is wrong for `GIT_BRANCH` and `GIT_TAG`:
these are human-chosen git ref names, and `PSScriptBuilderReleaseDataProcessor.ps1:593` assigns
`GitBranch = $this.ReleaseData.git.branch` directly into the token map with no validation against
`PSScriptBuilderBumpReplacementHelper.DefaultRegexPatterns['GIT_BRANCH']` at that point.

**Verified git itself permits a colliding branch name:**

```
git check-ref-format --branch "feature/{{VERSION}}"
feature/{{VERSION}}
```

This succeeds — nothing in git's own ref-naming rules forbids curly braces.

**Real repro, using the actual `PSScriptBuilderBumpReplacementHelper` class directly:**

```
Content:  Branch: {{GIT_BRANCH}}, Version: {{VERSION}}
TokenMap: GIT_BRANCH = 'feature/{{VERSION}}', VERSION = '1.3.0'

ApplySimpleReplacements(@('GIT_BRANCH', 'VERSION')):
  Branch: feature/1.3.0, Version: 1.3.0        <- branch name silently corrupted

ApplySimpleReplacements(@('VERSION', 'GIT_BRANCH')):
  Branch: feature/{{VERSION}}, Version: 1.3.0  <- correct
```

Identical input, identical token map — the *only* difference is the order tokens appear in the
`tokens` array (which comes from `bumpconfig.json`), and the outcome silently flips between correct
and corrupted. No error, no warning either way.

**Same underlying anti-pattern as RFC 0003** (`RenderOrderedMode`'s sequential mutation, fixed by
converting to a two-phase discover/assemble pattern) — but a structurally independent
implementation: different class, different file, different configuration model (`TokenMap`/
`RegexPatterns` vs. collectors/placeholders), no shared code and no shared fix. Per the
"same broken code vs. same abstract pattern" distinction already established this session, this is
tracked as its own RFC rather than folded into RFC 0003.

**Checked all three replacement methods individually — the vulnerability is not uniform across
them:**

- `ApplySimpleReplacements` — vulnerable (the repro above).
- `ApplyPlaceholderReplacements` — also vulnerable, verified with a real, analogous repro: a single
  pattern referencing both tokens (`'{{GIT_BRANCH}} - {{VERSION}}'`) produces
  `'feature/1.3.0 - 1.3.0'` (branch corrupted) in one token order and
  `'feature/{{VERSION}} - 1.3.0'` (correct) in the other. The vulnerability lives in this method's
  internal step that resolves the *pattern* into a `$searchString` by sequentially calling
  `.Replace()` on it token-by-token, before that fully-resolved string is inserted into `$content`
  in one single, final step.
- `ApplyRegexReplacements` / `ApplyMatchesWithCaptureGroups` — **already safe by design**, verified
  by reading the implementation in full: matches are found once, via regex, against the *original*
  content before any mutation; each match's capture groups are then resolved using exact
  position-based substring surgery (`Substring`/concatenation), not `.Replace()`; and matches are
  processed **back to front** specifically so that resolving one match never shifts or re-exposes
  another match's position. The code's own comment states this directly: "Replace at exact position
  in content (not global replace!)". Since the full set of positions is captured once, before any
  content mutation, a value inserted at one position can never be found by a later regex search
  (there is no later regex search — the match list is fixed upfront).

## Detailed Design

### Root Cause

`ApplySimpleReplacements` and `ApplyPlaceholderReplacements` process tokens/patterns one at a time,
each step calling `.Replace()` on the *result* of the previous step rather than the original
content — identical structural flaw to `RenderOrderedMode` before RFC 0003's fix, in an unrelated
class. `ApplyRegexReplacements` does not share this flaw (see Motivation).

### Decision

Convert `ApplySimpleReplacements` and `ApplyPlaceholderReplacements` to the same two-phase
discover/assemble pattern already proven correct in `PSScriptBuilderTemplateProcessor` (and,
independently, already present in spirit in `ApplyMatchesWithCaptureGroups` — see Motivation):

1. **Discover:** for each token/pattern, find *every* occurrence in the original, unmodified
   content (not just the first — `.Replace()`'s existing "replace every occurrence" semantics must
   be preserved), recording `(Start, Length, Replacement)` entries.
2. **Assemble:** sort all entries by `Start`, walk the original content once, copying literal
   segments and inserting replacement values into a fresh output buffer. Inserted values are never
   re-scanned.

**Verified with a real, isolated reimplementation of this algorithm** against the `GIT_BRANCH`/
`VERSION` repro above: produces the identical, correct result (`Branch: feature/{{VERSION}},
Version: 1.3.0`) regardless of token array order, and correctly still replaces multiple occurrences
of the same token in one pass.

`ApplyPlaceholderReplacements` applies this pattern one level in: its vulnerability is in resolving
the small `pattern` string into `$searchString`, not in the final content-level substitution (which
is already a single, one-time `.Replace()` of the whole original `$pattern` text and is not itself
vulnerable). The fix is the same discover/assemble algorithm applied to that resolution step —
find every `{{TOKEN}}` occurrence in the *original* `pattern` string, assemble the resolved
`$searchString` in one pass — before handing the result to the existing, unchanged content-level
replacement.

**Comparison mode: `[StringComparison]::Ordinal` (case-sensitive), deliberately unchanged.** This
matches Release Management's existing, undocumented-but-established case-sensitive behavior. See
RFC 0008 for the separate decision on whether Release Management should become case-insensitive —
kept as a distinct RFC since it is a different root cause (comparison mode, not processing order),
even though it will be built into the same new methods this RFC introduces.

## Rationale and Alternatives

**Considered: document a "safe token ordering" requirement instead of fixing the mechanism.**
Rejected — this pushes an unreasonable burden onto users, who have no natural way to predict that a
git branch or tag name could collide with an unrelated token, and the "safe" order depends on
runtime values (actual branch/tag names) a config author cannot know in advance.

**Considered: validate `GIT_BRANCH`/`GIT_TAG` values against their own `DefaultRegexPatterns` entry
at the point they are populated, rejecting or sanitizing disallowed characters.** Would address the
two specific built-in tokens but not custom tokens with their own custom (and possibly also
colliding) values — and is unnecessary once the discover/assemble fix is in place, since a
correctly-designed assembly mechanism is safe regardless of what characters a value contains.
Rejected in favor of the more general, structurally complete fix.

## Scope

**In scope:** `ApplySimpleReplacements` and `ApplyPlaceholderReplacements` — converting both to the
discover/assemble pattern.

**Confirmed already safe, no change needed:** `ApplyRegexReplacements` and
`ApplyMatchesWithCaptureGroups` — read in full and verified to already use a position-based,
discover-once/assemble-once design (see Motivation). A regression test locks this in (see Test
Plan) so it is never silently reintroduced.

**Out of scope:** Release Management's case-sensitivity (see RFC 0008); any change to how
`GIT_BRANCH`/`GIT_TAG` values are sourced from git or CI environment data.

## Relationship to Other RFCs

- **RFC 0001** — corrects that RFC's "value collision ruled out as impractical" reasoning, which
  was based on an incorrect premise; see RFC 0001's own Revision Log for the correction note. Not a
  change to any of RFC 0001's actual decisions.
- **RFC 0003** (Ordered/Hybrid Mode template injection) — same abstract anti-pattern (sequential
  mutation causing re-scanned inserted content), but an independent implementation in a different
  class; tracked separately per the established "same code vs. same pattern" distinction.
- **RFC 0008** (Release Management token case-insensitivity) — sequenced immediately after this
  RFC, built into the same new discover/assemble methods this RFC introduces, so they are touched
  exactly once.

See `internal/rfc/IMPLEMENTATION-PLAN.md` for where this fits in the build order.

## Test Plan

- Regression test: a `GIT_BRANCH` (or any token) value containing another token's placeholder text
  must not have that text corrupted, verified in both possible token-processing orders.
- Regression test: multiple occurrences of the same token in one content string must all still be
  replaced (non-regression — preserves `.Replace()`'s existing "replace every occurrence" behavior).
- Regression test: the same order-independence property, verified for `ApplyPlaceholderReplacements`
  (a pattern referencing two tokens, one token's value colliding with the other) as well as
  `ApplySimpleReplacements`.
- Non-regression test: confirm `ApplyRegexReplacements` continues to produce the correct,
  order-independent result for the same kind of colliding value — locks in its already-correct
  behavior so it cannot silently regress.

## Unresolved Questions

None currently — the scope split (two methods need the fix, one is already safe) is verified, not
assumed.

## Revision Log

- 2026-09-05 — Implemented. `ApplySimpleReplacements` and `ApplyPlaceholderReplacements` both
  converted to the discover/assemble pattern via two new shared helper methods,
  `DiscoverOccurrences`/`AssembleFromReplacements` — mirroring `PSScriptBuilderTemplateProcessor`'s
  already-proven design (RFC 0003). `ApplyPlaceholderReplacements`'s fix touches only its internal
  pattern-to-`$searchString` resolution step, exactly as scoped; the final, already-safe
  content-level replace is unchanged. Verified with a standalone harness before insertion, including
  a byte-identical comparison against the real, unmodified method for a normal, non-colliding case,
  and confirmed empirically that the comparison mode (`[StringComparison]::Ordinal`) matches the
  existing method's actual current case-sensitive behavior (`.Contains()`/`.Replace()` default to
  ordinal). All four Test Plan regression tests now pass, including one added during this
  implementation (multiple occurrences of the same token in `ApplySimpleReplacements` must all still
  be replaced — not previously covered by a formal test). Full suite: 1868 passed, 5 failed (RFC
  0008/0009 only, all pre-existing and unrelated).
- 2026-09-02 — Resolved the open question about `ApplyMatchesWithCaptureGroups` before
  implementation, as requested: read both it and `ApplyRegexReplacements` in full and confirmed
  they are already safe by design (matches found once against the original content, processed
  back-to-front, position-based substring replacement — no re-scanning possible). Also verified
  `ApplyPlaceholderReplacements` independently, with a real, analogous repro: it shares the
  vulnerability, in its internal pattern-to-`$searchString` resolution step rather than the final
  content-level replace. Narrowed Scope to the two genuinely vulnerable methods; added a
  non-regression test locking in `ApplyRegexReplacements`'s already-correct behavior.
- 2026-09-02 — Initial finding, while re-examining RFC 0001's "value collision ruled out as
  impractical" reasoning after a question about Release-Management-token case-sensitivity.
  Disproved the premise (verified `GIT_BRANCH`/`GIT_TAG` are human-chosen, git permits colliding
  characters) and verified the real, order-dependent corruption using the actual
  `PSScriptBuilderBumpReplacementHelper` class. Verified the discover/assemble fix design against
  the repro with a real, isolated reimplementation before writing this RFC.
