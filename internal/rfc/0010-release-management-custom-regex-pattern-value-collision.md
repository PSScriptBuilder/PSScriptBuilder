# RFC 0010: Release Management Custom Regex Pattern Value Collision

- **Status:** Draft — deferred, no known exploitable path
- **Type:** Fix
- **Created:** 2026-09-06
- **Branch:** none yet — deliberately not tied to `refactor/template-engine-consolidation`

## Summary

`PSScriptBuilderBumpReplacementHelper.ReplaceRegexPatterns` resolves `{REGEX_TOKEN}` placeholders
one token at a time, calling `.Replace()` on the already-modified result of the previous step —
the same sequential-mutation anti-pattern RFC 0007 and RFC 0009 fix elsewhere. If one token's own
regex *value* happens to contain another token's `{REGEX_TOKEN}` placeholder text, the outcome
depends on token processing order, exactly like RFC 0007's `{{TOKEN}}` bug. Unlike RFC 0007/0009,
this path is not reachable through any currently-existing configuration surface — deferred rather
than fixed.

## Motivation

Found 2026-09-05 while verifying RFC 0008 against current source, immediately adjacent to the exact
method RFC 0008 modifies. Re-analyzed and verified with a real, isolated repro before writing this
RFC, per standing practice.

**Real repro, using the actual `PSScriptBuilderBumpReplacementHelper` class directly, with custom
regex patterns:**

```
RegexPatterns: TOKEN_A = 'literal-{REGEX_TOKEN_B}-text', TOKEN_B = '\d+'
Pattern:       {REGEX_TOKEN_A} and {REGEX_TOKEN_B}

ReplaceRegexPatterns(@('TOKEN_A', 'TOKEN_B')):
  literal-\d+-text and \d+                    <- TOKEN_A's own regex value corrupted
ReplaceRegexPatterns(@('TOKEN_B', 'TOKEN_A')):
  literal-{REGEX_TOKEN_B}-text and \d+         <- correct, TOKEN_A's value intact
```

Identical inputs, identical `RegexPatterns` mapping — the only difference is the order tokens
appear in the `tokens` array, and the outcome silently flips between correct and corrupted, exactly
as RFC 0007 found for `{{TOKEN}}` value collisions.

**Verified this has no currently-reachable path, unlike RFC 0007/0009:**

- The only production construction site, `PSScriptBuilderBumpFilesProcessor.ps1:58`, always uses
  the single-argument constructor, which unconditionally uses `DefaultRegexPatterns` — the
  two-argument constructor accepting custom `RegexPatterns` is never called from any production
  code path, only from test fixtures.
- None of `DefaultRegexPatterns`'s 21 built-in values (`\d{4}-\d{2}-\d{2}`, `[a-zA-Z0-9._\-/]+`,
  etc.) contain literal `{REGEX_`-shaped text, so the built-in patterns can never trigger this,
  regardless of processing order.
- A repository-wide search confirms no configuration surface — `bumpconfig.json`'s schema, any
  public cmdlet, or `docs/guides/release-management.md` — exposes a way for a user to supply
  custom regex patterns at all. The two-argument constructor exists purely as a testing/extensibility
  hook, never wired to anything user-facing.

This is the deciding difference from RFC 0009, whose fix was justified specifically because
"PSScriptBuilder's own production `bumpconfig.json` uses the vulnerable multi-item shape" — a
confirmed, real exposure. Here, no such exposure exists today.

## Detailed Design

### Root Cause

`ReplaceRegexPatterns` processes tokens one at a time, each step calling `.Replace()` on the
*result* of the previous step rather than the original pattern — identical structural flaw to
`ApplySimpleReplacements`/`ApplyPlaceholderReplacements` before RFC 0007's fix, and to
`PSScriptBuilderBumpFilesProcessor`'s orchestration loop before RFC 0009's fix, in a third,
independent location none of those RFCs touches.

### Decision

Not yet decided — deferred. If ever picked up, the fix would plausibly follow the same
discover/assemble pattern RFC 0007 already established for this class (`DiscoverOccurrences`/
`AssembleFromReplacements` could very likely be reused directly, since `ReplaceRegexPatterns`
already resolves a small string much like `ApplyPlaceholderReplacements`'s pattern-resolution step
does), but this has not been designed or verified — recorded here only as a plausible direction,
not a decision.

## Rationale and Alternatives

**Considered: fix immediately, while already modifying `ReplaceRegexPatterns` for RFC 0008.**
Rejected for now — RFC 0008's own Scope is deliberately limited to case-insensitivity; folding an
unrelated fix into it would blur two independent RFCs' boundaries, inconsistent with how RFC
0007/0008/0009 are kept separate despite heavy overlap in the same file. Also, per YAGNI and
standard risk-based triage (severity *and* reachability both matter, not severity alone): with zero
currently-reachable path, fixing this now would address a purely hypothetical exposure rather than
a real one — unlike RFC 0009, which was pursued precisely because its exposure was confirmed real.

**Considered: fix opportunistically since it is cheap, using the same discover/assemble methods
already in the class.** Not rejected outright, only deferred — if custom regex patterns ever become
user-configurable, this RFC should be revisited before that feature ships, at which point the
"cheap, already-adjacent" argument would carry much more weight, since the exposure would then be
real.

## Scope

**In scope, if ever picked up:** `ReplaceRegexPatterns`'s sequential resolution of `{REGEX_TOKEN}`
placeholders when the associated `RegexPatterns` values are custom (not the built-in
`DefaultRegexPatterns`).

**Out of scope:** everything already covered by RFC 0007/0008/0009; making custom regex patterns
actually user-configurable (no such feature exists or is planned).

## Relationship to Other RFCs

- **RFC 0007** (sequential value collision) — same abstract anti-pattern (sequential mutation
  causing re-scanned inserted content), applied to `{{TOKEN}}` value collisions in
  `ApplySimpleReplacements`/`ApplyPlaceholderReplacements`; this RFC is the same pattern in a third,
  independent method (`ReplaceRegexPatterns`) neither RFC 0007 nor RFC 0009 touches.
- **RFC 0008** (Release Management token case-insensitivity) — found while verifying RFC 0008
  against current source, in the same method RFC 0008 modifies for a different, unrelated reason
  (comparison mode, not processing order). RFC 0008 does not fix this; the two remain independent.
- **RFC 0009** (Release Management cross-item value collision) — same abstract anti-pattern in a
  third location, the direct precedent for why this is tracked as its own RFC rather than folded
  into RFC 0007, per the established "same broken code vs. same abstract pattern" distinction.

## Test Plan

Not yet applicable — no implementation plan exists yet.

## Unresolved Questions

- Should this be picked up proactively, or only if/when custom regex patterns ever become a real,
  user-configurable feature? Leaning toward the latter, not decided.
- If picked up, does reusing `DiscoverOccurrences`/`AssembleFromReplacements` directly (rather than
  a new, parallel implementation) actually work cleanly for a pattern-string-level resolution step,
  the way it already does for `ApplyPlaceholderReplacements`? Not yet verified.

## Revision Log

- 2026-09-06 — Initial finding, found while verifying RFC 0008 against current source, immediately
  adjacent to the exact method RFC 0008 modifies. Verified the repro with the real class, and
  verified — via an exhaustive repo-wide search — that this has no currently-reachable path (unlike
  RFC 0007/0009, both confirmed reachable via real production configuration). Deferred rather than
  fixed, per YAGNI and risk-based triage: severity and reachability both matter, not severity alone.
