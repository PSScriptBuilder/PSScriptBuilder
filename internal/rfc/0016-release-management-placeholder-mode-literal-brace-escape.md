# RFC 0016: Release Management Placeholder Mode Literal Brace Escape

- **Status:** Implemented (2026-09-08)
- **Type:** Fix
- **Created:** 2026-09-08
- **Branch:** `refactor/release-management-bump-mode`

## Summary

A Placeholder Mode pattern containing literal, non-token `{{...}}` text (e.g. another templating
system's own syntax coexisting in the same file, such as Helm's `{{ .Chart.Name }}`) already works
correctly today when written unescaped - Placeholder Mode only ever touches occurrences of a
pattern's *declared* `{{TOKEN}}` placeholders, so unrelated `{{...}}` text is naturally left alone.
But an author who reasonably escapes that foreign text by analogy to RFC 0012's documented
`\(`/`\)` convention (`\{`/`\}`) hits a silent no-op: nothing ever strips the brace escape, so the
resolved search text still contains literal backslashes that can never match real file content -
the exact same failure class RFC 0012 fixed for parentheses, now confirmed for braces. Add the
missing unescape step, placed so it does not weaken the existing, separate validation that catches
an author accidentally escaping their own *declared* token's only occurrence.

## Motivation

Raised while investigating a reported edge case in `PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode`
(a Regex Mode pattern mixing `{{ other_template_var }}` foreign text with a real `{REGEX_...}`
capture group correctly throws the RFC 0013 mixed-syntax error - by design, since Regex Mode has no
brace-escape convention and none is needed there: a real capture group is present, and unrelated
`{{...}}` should simply not appear in a Regex Mode pattern at all). Investigating the equivalent
Placeholder Mode question - can literal `{{...}}` text coexist with a real `{{TOKEN}}` placeholder -
found a materially different, worse problem than initially assumed.

**Verified: the unescaped case already works correctly, no fix needed there.**
```powershell
$content = 'name: {{ site.name }} says {{GIT_BRANCH}}'
$pattern = '{{ site.name }} says {{GIT_BRANCH}}'
$helper.ApplyPatternReplacements($content, $pattern, @('GIT_BRANCH'))
# Changes.Count: 1, Content: 'name: {{ site.name }} says main'
```
`ApplyPlaceholderReplacements` only ever searches for a *declared* token's own `{{TOKEN}}` text
(`PSScriptBuilderBumpReplacementHelper.ps1:637-645`); any other `{{...}}` substring is never
inspected, never validated, and is carried through untouched as literal anchor text. No escaping is
needed or expected for this case.

**Verified: escaping that same foreign text (reasonably, by analogy to RFC 0012's documented
convention) silently no-ops.**
```powershell
$pattern = '\{\{ site.name \}\} says {{GIT_BRANCH}}'
$helper.ApplyPatternReplacements($content, $pattern, @('GIT_BRANCH'))
# Changes.Count: 0, Content unchanged - no error, no warning
```
Traced through the real, unmodified source: `UnescapeLiteralParenthesesInPattern`
(`PSScriptBuilderBumpReplacementHelper.ps1:879-882`) only replaces `\(`/`\)`; nothing analogous
exists for `\{`/`\}`. The escaped text survives unchanged through validation and the pattern's own
token-resolution step, and is still present - backslashes included - in the literal text used to
search file content at `PSScriptBuilderBumpReplacementHelper.ps1:653`
(`DiscoverOccurrences($content, $pattern, $searchString, ...)` - the *search key* here is `$pattern`
itself, not the already-partially-resolved `$searchString`). Real file content never contains a
backslash before a brace, so the search can never succeed. Zero matches is indistinguishable from
"this pattern legitimately doesn't apply to this file yet" - the method returns normally with
`Changes.Count: 0`, exactly mirroring RFC 0012's original escaped-parenthesis bug, one character
class later.

**Investigated, and deliberately rejected, the obvious fix: mirroring RFC 0012's exact placement**
(unescape unconditionally at the very top of `ApplyPlaceholderReplacements`, before anything else).
Parentheses are never part of Placeholder Mode's own syntax, so unescaping them before validation
is harmless. Braces are the placeholder delimiter syntax itself - unescaping them that early erases
the distinction between "this was always a real, unescaped `{{TOKEN}}`" and "this was an escaped,
supposedly-literal occurrence of the same token name" *before* the one existing safety check
(`PSScriptBuilderBumpReplacementHelper.ps1:626-633`, "Token 'X' has no corresponding placeholder")
ever runs. Verified the concrete regression this would cause:
```powershell
# A declared token's ONLY occurrence is escaped - almost certainly a config mistake (either a typo,
# or the author no longer wants this token replaced here, in which case it should not be declared
# for this item at all)
$pattern = '\{\{GIT_BRANCH\}\} Year: {{YEAR}}'
# TODAY, unaffected by any fix: throws "Token 'GIT_BRANCH' has no corresponding placeholder
# '{{GIT_BRANCH}}' in pattern" - a clear, actionable error.
# WITH A NAIVE TOP-OF-METHOD UNESCAPE: the escape is stripped before validation runs, the pattern
# becomes '{{GIT_BRANCH}} Year: {{YEAR}}', validation passes, and GIT_BRANCH is silently replaced -
# the config inconsistency (a declared token whose only occurrence contradicts that declaration) is
# silently resolved in one direction without the author ever being asked to confirm which they meant.
```
The system cannot tell "typo, meant to write `{{GIT_BRANCH}}`" apart from "meant literal text,
should not have declared GIT_BRANCH as a token for this item" - both are plausible. Preserving
today's loud failure for this specific inconsistency is the safer default; see Detailed Design for
the placement that achieves this.

**Verified the corrected design (unescape only after validation and after the pattern's own
token-resolution step, not before) handles all three relevant scenarios correctly**, via a
prototype built directly on the real, unmodified helper methods
(`DiscoverOccurrences`/`AssembleFromReplacements`):
- Foreign escaped brace text, no declared-token collision: now correctly replaces (`Changes: 1`,
  `'name: {{ site.name }} says main'`).
- A declared token's only occurrence escaped: still throws the existing, unchanged validation error.
- The same token name appearing twice in one pattern - once escaped (intended to stay literal, e.g.
  example/documentation text) and once unescaped (the real substitution point): only the real
  occurrence is replaced, the escaped/literal one is carried through unchanged
  (`'Example: {{GIT_BRANCH}} literal. Real: main'`). This works because the pattern's own
  token-resolution step (`DiscoverOccurrences` searching for the literal, unescaped `"{{TOKEN}}"`
  text) naturally never matches the still-escaped occurrence - the escape is only stripped
  afterward, when building the final content-search key and replacement string, by which point the
  two occurrences have already been correctly told apart.

**Decision to fix rather than document as a known limitation:** per this project's established
Cost-of-Quality bar (RFC 0002/0006/0007/0008/0009/0012), a reachable silent-failure defect gets
fixed, not just documented. This is reachable the same way RFC 0012's was: any bump-config author
combining literal, foreign `{{...}}`-shaped text with a real Placeholder Mode token, who escapes it
by reasonable analogy to the one escaping convention this project already documents, hits it
immediately.

## Detailed Design

### Root Cause

`ApplyPlaceholderReplacements` has no unescape step for `\{`/`\}` anywhere in its pipeline -
`UnescapeLiteralParenthesesInPattern` handles only `\(`/`\)`. Unlike parentheses, braces cannot
simply be unescaped at the top of the method: they are the same delimiter syntax the method's
validation and pattern-internal token-resolution steps use to identify `{{TOKEN}}` occurrences, so
stripping the escape too early would erase information those steps need (see Motivation).

### Decision

- Add a new hidden method, `UnescapeLiteralBracesInPattern`, structurally parallel to
  `UnescapeLiteralParenthesesInPattern` (replace `\{` with `{` and `\}` with `}`).
- Apply it only at the point where the content-level search key and the final replacement string
  are built - after validation (`PSScriptBuilderBumpReplacementHelper.ps1:626-633`) and after the
  pattern's own token-resolution step (`:637-647`), immediately before the values used in
  `DiscoverOccurrences($content, ...)` (`:653`) are computed. Concretely: apply it to both the
  content-search key (today just `$pattern`) and to `$searchString`, so any brace escape still
  present at that point - by construction, only ever *foreign*, non-declared-token text, since a
  declared token's own occurrence was already required to be unescaped to pass validation and get
  substituted - becomes literal, matchable text.
- `HasContentToReplace`'s Placeholder Mode branch (`PSScriptBuilderBumpReplacementHelper.ps1:311-313`)
  needs the equivalent fix for consistency, mirroring how RFC 0012 updated both call sites.
- No change to `PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode` or the RFC 0013
  mixed-syntax check: both already operate correctly on the raw, still-escaped pattern text
  (escaped braces already don't count as a placeholder signal, exactly as escaped parentheses
  already don't count as a capture-group signal).

## Rationale and Alternatives

**Considered mirroring RFC 0012's exact placement (unescape unconditionally at the top of the
method).** Rejected - see Motivation's verified regression: it would silently resolve a declared
token's own accidentally-escaped-only occurrence instead of failing loudly, removing a safety net
that exists today with no way for the system to know which of the two plausible author intents
(typo vs. deliberate literal text) applies.

**Considered leaving this undocumented/unfixed, reasoning that the unescaped case already works for
the overwhelmingly common scenario (foreign text that never happens to share a declared token's
name).** Rejected per this project's Cost-of-Quality bar - the escaped form is directly invited by
RFC 0012's own documentation of the parenthesis convention, and silently no-ops rather than erroring,
exactly the kind of reachable silent failure this project has consistently chosen to fix rather than
document around.

**Considered a single shared `UnescapeLiteralBracesAndParenthesesInPattern` method instead of two
separate ones.** Leaning toward keeping them separate, since they are applied at different points in
the pipeline for different reasons (parentheses: harmless to strip immediately, unescaped once and
never revisited; braces: must be deferred until after validation/token-resolution) - not fully
closed pending implementation-time review.

## Scope

**In scope:** `PSScriptBuilderBumpReplacementHelper.ApplyPlaceholderReplacements` and
`.HasContentToReplace`'s Placeholder Mode branch; a new `docs/guides/release-management.md` section
documenting the brace-escape convention with multiple worked examples (see Documentation below);
a `CHANGELOG.md` entry (observable behavior fix, like RFC 0012).

**Out of scope:** Regex Mode (no escape convention needed there - see Motivation); changing
`DetermineBumpPatternMode`'s detection heuristic itself (already correct for this case); Simple
Mode (`tokens`-shaped entries, no analogous pattern-text concept).

## Documentation

Requested explicitly: this needs a dedicated, example-driven section in
`docs/guides/release-management.md` (near the existing `\(`/`\)` documentation added by RFC 0012),
covering each distinct scenario this RFC identifies separately enough that a reader can find their
own exact situation rather than having to infer it from one generic rule:

1. **Foreign `{{...}}` text that never collides with a declared token name** (e.g. a file also
   templated by Helm/Jinja2/Handlebars) - show the *unescaped* form working correctly out of the
   box, and state explicitly that no escaping is needed or expected here. This is the common case
   and should be presented first, so a reader whose foreign text simply happens not to share a
   token name does not reach for escaping unnecessarily.
2. **Foreign `{{...}}` text that is itself escaped** (e.g. copied from elsewhere, or written
   defensively by analogy to the parenthesis convention) - show that `\{`/`\}` is recognized and
   stripped correctly as of this RFC, with a worked before/after example.
3. **A declared token whose only pattern occurrence is escaped** - show that this still throws
   `Token 'X' has no corresponding placeholder`, and explain why: the system cannot distinguish a
   typo from a deliberate "keep this literal" intent, so declaring a token for an item requires an
   actual, unescaped occurrence of it in that item's pattern.
4. **The same token name appearing twice, once escaped (meant to stay literal) and once unescaped
   (the real substitution point)** - e.g. documentation/example text inside the same target file
   that happens to spell out a real token's placeholder syntax - show that only the unescaped
   occurrence is substituted.

## Relationship to Other RFCs

Mirrors RFC 0012's fix (same silent-no-op failure class, one character class later), but requires a
different implementation placement - see Motivation and Rationale for why the two escape conventions
cannot share identical mechanics despite the parallel author-facing convention. Independent of RFC
0013 (mixed-syntax detection) and `DetermineBumpPatternMode` generally - both already handle escaped
braces correctly at the detection stage; this RFC only concerns what happens after a pattern is
already confirmed to be Placeholder Mode. Complementary to the still-deferred RFC 0014 (explicit
`mode` field): once available, RFC 0014's discriminator would let an author sidestep brace-escaping
questions entirely for genuinely ambiguous patterns, but does not remove the need for this fix in the
meantime, nor for patterns that still rely on heuristic detection going forward.

## Test Plan

- Regression test: a Placeholder Mode pattern containing escaped, non-declared-token `{{...}}` text
  must correctly match and replace in file content (the previously-silent no-op case).
- Non-regression test: a declared token whose only pattern occurrence is escaped continues to throw
  `Token 'X' has no corresponding placeholder` (must not silently start working after this fix).
- Regression test: the same token name appearing both escaped (literal) and unescaped (real) in one
  pattern replaces only the unescaped occurrence, leaving the escaped one as literal text unchanged.
- Non-regression test: existing Placeholder Mode patterns with no braces beyond the declared
  token(s) continue to work unchanged.
- Non-regression test: RFC 0012's existing escaped-parenthesis tests continue to pass unaffected.

## Unresolved Questions

- Exact method naming/structure (`UnescapeLiteralBracesInPattern` as a separate method vs. merging
  with the parenthesis one) - see Rationale; does not block starting implementation.
- Exact placement of the new `docs/guides/release-management.md` section relative to RFC 0012's
  existing parenthesis documentation (new subsection vs. extending the existing one) - to be decided
  at implementation/documentation time, guided by the "one scenario per example" structure above.

## Revision Log

- 2026-09-08 — Initial draft. Investigated after a Regex Mode edge case raised the general question
  of literal `{{...}}` text coexisting with real Placeholder Mode tokens; found the unescaped case
  already works correctly (no fix needed) but the escaped case - reasonably attempted by analogy to
  RFC 0012's documented convention - silently no-ops, the same failure class one character class
  later. Initially considered mirroring RFC 0012's fix placement exactly, but verified (via a
  concrete repro) that doing so would silently paper over a separate, currently-loud validation
  error for a declared token's accidentally-escaped-only occurrence - revised the design to defer
  brace-unescaping until after validation and pattern-internal token-resolution, and verified via a
  prototype built on the real, unmodified helper methods that this correctly handles all three
  relevant scenarios (foreign escaped text, declared-token-escaped-only, and same-token-name
  coexistence). Status set to Decided (not deferred), consistent with RFC 0012's precedent of fixing
  reachable silent-failure defects immediately rather than deferring per this project's Cost-of-
  Quality bar - implementation timing to be confirmed separately.
- 2026-09-08 — Implementation timing confirmed: to be implemented now, alongside the upcoming
  release, not deferred like RFC 0014/0015 - an easy-to-implement, already-verified fix that brings
  real value belongs in the release rather than being held back during a stabilize-and-ship phase.
- 2026-09-08 — Implemented. New hidden `UnescapeLiteralBracesInPattern($text)` on
  `PSScriptBuilderBumpReplacementHelper`, structurally parallel to
  `UnescapeLiteralParenthesesInPattern` but applied at a different point: inside
  `ApplyPlaceholderReplacements`, only after validation and after the pattern's own token-resolution
  step, to both the content-search key and the final replacement string (not at the top of the
  method, unlike the parenthesis fix - see Detailed Design for why). `HasContentToReplace`'s
  Placeholder Mode branch updated the same way, chained after the existing parenthesis-unescape
  call. Also corrected the `Changes` entries' `Pattern`/`OldValue` fields to use the fully
  brace-unescaped search key rather than the still-escaped `$pattern`, so change records never show
  backslashes that were never actually in the file content. Verified against the real, built module
  (not just a prototype): all three scenarios behave as designed (foreign escaped text now replaces
  correctly; a declared token's only occurrence still throws unchanged; same-token-name
  escaped/literal + unescaped/real coexistence replaces only the real occurrence), plus
  non-regression checks (RFC 0012's escaped-parenthesis case, `HasContentToReplace`, and a plain
  pattern with no extra braces). Added 4 new Pester tests next to RFC 0012/0013's existing tests in
  `PSScriptBuilderBumpReplacementHelper.Tests.ps1`. Documented all four scenarios with worked,
  verified examples in `docs/guides/release-management.md`, directly after the existing parenthesis
  convention. Added a `CHANGELOG.md` entry (observable behavior fix). Full suite: 1922 passed
  (1918 + 4 new), 0 failed - verified via both `build.ps1` (bootstrap) and `Build-Module.ps1`
  (authoritative) per [[authoritative-build-artifact]].
