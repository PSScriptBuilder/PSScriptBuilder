# RFC 0008: Release Management Token Case-Insensitivity

- **Status:** Implemented (2026-09-06)
- **Type:** Fix
- **Created:** 2026-09-02
- **Branch:** `refactor/template-engine-consolidation`

## Summary

Release Management's token matching (`{{TOKEN}}`) is case-sensitive, while PSScriptBuilder's own
Template placeholder system is documented and validated as case-insensitive (RFC 0004). Both
systems use identical `{{...}}` syntax and can process the same project — having them behave
differently for a purely cosmetic detail (casing) is inconsistent and causes a silent, no-warning
failure to substitute a token whenever its casing doesn't exactly match.

The Regex Mode `{REGEX_TOKEN}` syntax has its own, structurally distinct instance of this problem
in `ReplaceRegexPatterns` — not just missing case-insensitivity, but an internal mismatch between
how it checks for a placeholder and how it replaces it, causing a completely silent no-op (not
merely a case-sensitive requirement).

## Motivation

Found 2026-09-02 while investigating RFC 0007. Verified with the real class: a token configured as
`VERSION`, given input `{{version}}` (lowercase), produces **no substitution at all** —
`ApplySimpleReplacements` leaves the content byte-for-byte unchanged and reports `Changes.Count: 0`,
with no error or warning of any kind.

Unlike RFC 0004, this is not a documented-promise violation — nothing in Release Management's
documentation claims case-insensitivity either way. The case for fixing it is a consistency
argument, made directly during discussion: within one project, an author encounters the identical
`{{...}}` syntax in two different subsystems (Template and Release Management) and has no reason to
expect it to behave differently between them. This is the **Principle of Least Astonishment**
(also one of Nielsen's usability heuristics, "Consistency and Standards") — a well-established
design principle independent of whether either behavior was previously documented.

**A second, structurally distinct instance found while implementing the fix (2026-09-02):**
`ReplaceRegexPatterns` (used by both `ApplyRegexReplacements` and `HasContentToReplace`) resolves
`{REGEX_TOKEN}` placeholders — a different, single-brace syntax with no Template-side equivalent —
via:

```powershell
if ($result -match [regex]::Escape($regexPlaceholder)) {   # -match: case-INSENSITIVE by default
    $result = $result.Replace($regexPlaceholder, $regexValue)  # .Replace(): case-SENSITIVE (ordinal)
}
```

The guard and the action disagree on comparison mode. Verified directly: for a pattern containing
`{regex_version}` (any casing other than the exact configured one), `-match` returns `$true` (a
false green light), but `.Replace()` then does nothing, silently leaving the literal text
`{regex_version}` in the pattern. .NET's regex engine treats that as literal text (verified: no
exception, and it matches nothing in real content), so the whole operation silently produces zero
changes — worse than a simple "must match exact case" limitation, since even a *consistently*
case-sensitive implementation would behave the same as today's exact-case path; this is an outright
bug, not just an absence of case-insensitivity.

Verified the real, user-facing impact: `PSScriptBuilderBumpFilesProcessor.ps1:151` passes
`$item.pattern`/`$item.tokens` straight from `bumpconfig.json` into `ApplyPatternReplacements` with
no earlier validation of pattern/placeholder casing (`ValidateTokensForFile` only checks that the
token *name* exists and has a value). A casing typo in a bump config's Regex Mode pattern silently
skips the file entirely — no exception, no changed-file entry, reported as a normal successful bump.

No existing test covered this path.

## Detailed Design

### Root Cause

`ApplySimpleReplacements` and `ApplyPlaceholderReplacements` construct `$placeholder = "{{$token}}"`
and match/replace it using ordinal (case-sensitive) comparison throughout — consistently, just
without a case-insensitive path.

`ApplyRegexReplacements` does **not** share this exact mechanism — it never constructs `{{$token}}`
itself (that only happens in `ApplyMatchesWithCaptureGroups`'s already-safe, position-based capture
group substitution, which needs no placeholder text at all). Its own case-sensitivity problem lives
one level earlier, in `ReplaceRegexPatterns`'s handling of the distinct `{REGEX_$token}` syntax, and
is not merely "no case-insensitive path" but the check/replace mismatch described in Motivation.

### Decision

Build case-insensitive matching directly into RFC 0007's new discover/assemble methods, rather than
patching today's sequential methods first and porting the fix forward — the same sequencing
reasoning already used for RFC 0003 → RFC 0004. Concretely: the Discover phase's occurrence search
uses `IndexOf(..., [StringComparison]::OrdinalIgnoreCase)` instead of `Ordinal`. A template/bump
author can then write `{{version}}`, `{{Version}}`, or `{{VERSION}}` interchangeably, matching the
Template system's own established convention.

This only changes *matching* — a token's canonical identity (its key in `TokenMap`, or a
`DefaultRegexPatterns` entry's name) is unaffected, exactly as RFC 0004 made placeholder *matching*
case-insensitive without changing a collector's own `CollectionKey` value.

**Applies uniformly to all tokens, built-in and custom** — see Rationale for why a partial
application (built-in only) was rejected.

**`{REGEX_TOKEN}` (Regex Mode) is decided the same way, now, rather than deferred**: despite having
no Template-side equivalent to be consistent *with*, leaving it exact-case-only while `{{TOKEN}}`
becomes case-insensitive would recreate the exact inconsistency this RFC exists to remove — just
between two RM mechanisms instead of between RM and Template. Fix `ReplaceRegexPatterns` (and
thereby `HasContentToReplace`'s regex branch, which calls it) to match case-insensitively. Since the
replacement value here is itself a regex pattern being spliced into another pattern (not literal
content), use `[regex]::Replace($result, [regex]::Escape($regexPlaceholder), <MatchEvaluator>,
[RegexOptions]::IgnoreCase)` rather than `-replace` or `.Replace()` — a `MatchEvaluator` returns the
replacement value verbatim, avoiding `.NET`'s special handling of `$` in a replacement string, which
would otherwise corrupt a custom regex value containing `$&`/`$0` (whole-match self-reference,
always present regardless of capture groups) or `$$` (collapses to a literal `$`) — verified
directly; a lone `$` anchor (e.g. `\d+$`) is unaffected since the search side here has no capture
groups of its own.

## Rationale and Alternatives

**Considered: leave Release Management case-sensitive, document the difference instead.** Rejected
— documentation alone doesn't remove the silent-failure risk, and RFC 0002/0006 already established
that a near-free technical fix is preferable to documentation-only when one is available.

**Considered: case-insensitive only for the built-in `DefaultRegexPatterns` tokens, case-sensitive
for custom tokens.** Rejected — this would relocate the "identical syntax behaves inconsistently"
problem to *within* Release Management itself (built-in tokens working one way, custom tokens
another), rather than resolving it. Uniform case-insensitivity for all tokens is simpler and avoids
this.

**Considered: use the `-replace` operator directly for `{REGEX_TOKEN}` resolution (it's already
case-insensitive by default).** Rejected — verified that `.NET`'s replacement-string parsing
corrupts a custom regex value containing `$&`, `$0`, or `$$` (whole-match/self-reference and
dollar-escaping are always active, regardless of the search pattern's own group count). A
`MatchEvaluator`-based `[regex]::Replace` returns the value verbatim, avoiding this entirely.

## Scope

**In scope:** case-insensitive matching in the discover/assemble methods RFC 0007 introduces
(`ApplySimpleReplacements`/`ApplyPlaceholderReplacements`'s successors), for all tokens (built-in
and custom); **and, independently, `ReplaceRegexPatterns`'s `{REGEX_TOKEN}` resolution** (used by
`ApplyRegexReplacements` and `HasContentToReplace`) — a separate method RFC 0007 does not touch.

**Out of scope:** how token names are canonically stored (`TokenMap` keys keep whatever casing they
are configured with); Release Management's decorative-brace convention and value-collision handling
(RFC 0001's exclusion, RFC 0007) — an unrelated comparison-mode-independent concern.

## Relationship to Other RFCs

- **RFC 0007** (sequential value collision) — the `{{TOKEN}}` half of this fix is built directly
  into RFC 0007's new discover/assemble methods. The `{REGEX_TOKEN}` half (`ReplaceRegexPatterns`)
  is independent of RFC 0007 — that method was confirmed already safe against RFC 0007's concern
  and is deliberately left untouched by it, so this RFC fixes `ReplaceRegexPatterns` on its own.
- **RFC 0004** (placeholder case-sensitivity mismatch) — same general principle (placeholder
  matching should be case-insensitive), applied here to a different, independent subsystem; not
  otherwise dependent on it.
- **RFC 0010** (Release Management custom regex pattern value collision) — found while verifying
  this RFC against current source, in the same `ReplaceRegexPatterns` method this RFC modifies, for
  an unrelated reason (processing order, not comparison mode). Deliberately not fixed as part of
  this RFC — deferred, since it has no currently-reachable path (see RFC 0010's own Motivation).

See `internal/rfc/IMPLEMENTATION-PLAN.md` for where this fits in the build order.

## Test Plan

- Regression test: a differently-cased placeholder (e.g. `{{version}}` for a token configured as
  `VERSION`) must be correctly substituted, not silently left untouched.
- Regression test: a template containing both `{{VERSION}}` and `{{version}}` for the same token —
  both occurrences must be correctly replaced (the discover/assemble mechanism naturally handles
  this; Release Management has no separate duplicate-detection phase to interact with, unlike the
  Template system).
- Non-regression test: existing exact-case usage continues to work unchanged.
- Regression test: a differently-cased `{REGEX_TOKEN}` (e.g. `{regex_version}`) must be correctly
  resolved and produce a substitution, not a silent zero-change no-op.
- Regression test: `HasContentToReplace` must return `true` for a differently-cased `{REGEX_TOKEN}`
  pattern actually present in content.
- Regression test: a custom regex value containing `$&`, `$0`, or `$$` must survive `{REGEX_TOKEN}`
  resolution unchanged (guards the `MatchEvaluator` choice over `-replace`/`.Replace()`).

## Unresolved Questions

None currently — decision, scope, and sequencing are settled; only implementation remains.

## Revision Log

- 2026-09-06 — Implemented. `DiscoverOccurrences` (shared by `ApplySimpleReplacements` and
  `ApplyPlaceholderReplacements` since RFC 0007) now uses `[StringComparison]::OrdinalIgnoreCase` —
  a single one-line change fixes both `{{TOKEN}}` paths at once, since RFC 0007 already
  consolidated them onto this one shared method. `ReplaceRegexPatterns` converted from its
  check/replace mismatch to a `MatchEvaluator`-based `[Regex]::Replace(...IgnoreCase)`, matching the
  `FormatStringForVerboseOutput` MatchEvaluator idiom already used elsewhere in the same file.
  Verified with a standalone harness before insertion, including that a custom regex value
  containing `$&`/`$0`/`$$` survives resolution verbatim. Found and added one missing Test Plan
  item during implementation (a template containing both an exact-case and a differently-cased
  occurrence of the same token — both must be replaced). While verifying this RFC against current
  source, found and separately documented (RFC 0010, deferred) an unrelated, structurally similar
  value-collision bug in `ReplaceRegexPatterns` — confirmed unreachable through any current
  configuration surface, so left out of this RFC's fix. Full suite: 1872 passed, 2 failed (RFC 0009
  only).
- 2026-09-02 — Found and verified a second, structurally distinct case-sensitivity bug while
  re-analyzing before implementation: `ReplaceRegexPatterns`'s `{REGEX_TOKEN}` resolution has a
  check/replace comparison-mode mismatch (case-insensitive `-match` guard, case-sensitive
  `.Replace()` action), causing a completely silent zero-change no-op for any non-exact-case usage
  — verified end-to-end, including the real `bumpconfig.json` call path
  (`PSScriptBuilderBumpFilesProcessor.ps1:151`) and `HasContentToReplace`'s identical exposure.
  Corrected Root Cause's factually inaccurate claim that `ApplyRegexReplacements` shares the
  `{{$token}}` mechanism — it doesn't; its own syntax and bug are distinct. Decided immediately
  (per direct instruction) that `{REGEX_TOKEN}` should also become case-insensitive, using the same
  Least-Astonishment reasoning, implemented via a `MatchEvaluator`-based `[regex]::Replace` to avoid
  `$`-related corruption (`$&`/`$0`/`$$`, verified individually) of custom regex values.
- 2026-09-02 — Initial decision, made directly during discussion of the Release Management
  case-sensitivity gap found while investigating RFC 0007. Grounded in the Principle of Least
  Astonishment rather than a broken-promise correction (no case-insensitivity was ever documented
  for Release Management, unlike RFC 0004's situation). Verified the silent-failure behavior with a
  real test (`{{version}}` input left completely unchanged, `Changes.Count: 0`).
