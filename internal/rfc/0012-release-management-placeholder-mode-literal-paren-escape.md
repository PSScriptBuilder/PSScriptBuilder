# RFC 0012: Release Management Placeholder Mode Literal Parenthesis Escape

- **Status:** Implemented (2026-09-08)
- **Type:** Fix
- **Created:** 2026-09-07
- **Branch:** `refactor/release-management-bump-mode`

## Summary

A Placeholder Mode pattern (`{{TOKEN}}`) containing a literal parenthesis cannot be replaced today,
in either form it could reasonably be written: unescaped, it is misclassified as Regex Mode and
throws a misleading exception; escaped (`\(`/`\)`, the convention the mode-detection code's own
comment implies), it is correctly classified but the replacement then silently does nothing. Strip
the escape once Placeholder Mode is confirmed, so the convention that already works for Regex Mode
patterns also works for Placeholder Mode ones.

## Motivation

Found while reviewing RFC 0011's `DetermineBumpPatternMode` extraction: raised whether the
`-match` conditions being centralized (`$pattern -match '\{\{'` / `$pattern -match '(?<!\\)\('`)
were actually sufficient. Verified both failure modes directly with the real, unmodified class:

**Unescaped literal parenthesis - misclassified, throws a misleading exception:**
```powershell
$helper.ApplyPatternReplacements('Copyright (c) 2025', 'Copyright (c) {{YEAR}}', @('YEAR'))
# throws InvalidOperationException: No regex pattern defined for token 'YEAR'
```
`(c)` is an unescaped parenthesis, so `$hasCaptures` is `true` and the pattern is routed to Regex
Mode even though the author never intended a capture group - `ValidateRegexPatterns` then fails
because `YEAR` has no `RegexPatterns` entry, with an error message that gives no hint the real
problem is an unescaped parenthesis.

**Escaped literal parenthesis - correctly classified, then silently does nothing:**
```powershell
$helper.ApplyPatternReplacements('Copyright (c) {{YEAR}}', 'Copyright \(c\) {{YEAR}}', @('YEAR'))
# Content unchanged, Changes.Count: 0 - no error, no warning
```
(Content here is a realistic, not-yet-bumped file: the real, unescaped parenthesis PSScriptBuilder
would actually find on disk, with the placeholder not yet resolved - Placeholder Mode's
content-level search can only ever match content in this pre-bump shape, never an
already-resolved value, so this is the only content shape worth testing here.)

Escaping with `\(`/`\)` (the convention `$hasCaptures`'s own code comment, "Only non-escaped
parentheses", implies) correctly routes the pattern to Placeholder Mode. But
`ApplyPlaceholderReplacements` never strips the escape - the pattern's literal text, backslashes
included, is what gets searched for in file content (`Copyright (c) {{YEAR}}`, no backslashes), so
the match never succeeds.

**Root finding: the escape convention works correctly for Regex Mode, but not for Placeholder
Mode.** In Regex Mode, `\(` is standard .NET regex syntax for "literal parenthesis, not a capture
group" - the pattern flows directly into `[regex]::Matches`, which interprets the escape natively;
no PSScriptBuilder-side unescaping step is needed, and this is already exercised by an existing
test (`"Branch: \(({REGEX_GIT_BRANCH})\), Version: \(({REGEX_VERSION})\)"` - the outer `\(`/`\)`
pairs are literal output parentheses, the inner unescaped ones are the real capture groups). The
same `\(`/`\)` text has no such native meaning once a pattern is routed to Placeholder Mode, which
does plain literal-text matching, not regex matching - the escape is consulted once (during mode
detection) and then never accounted for again.

**Net effect: no currently-working way exists to include a literal parenthesis anywhere in a
Placeholder Mode pattern.** Not a narrow edge case - copyright notices, prose containing
parenthetical text, or any other ordinary text combined with a `{{TOKEN}}` placeholder in the same
custom pattern hits this immediately, and any bump-config author could write one without knowing
any escaping convention exists (it is not documented anywhere in
`docs/guides/release-management.md`).

**Decision to fix rather than document as a known limitation:** per this project's established
Cost-of-Quality bar (RFC 0002/0006/0007/0008/0009), a reachable silent-failure defect gets fixed,
not just documented - the one established exception (RFC 0010) applies only when a defect is
confirmed to have no currently-reachable path, which is not the case here: any bump-config author
combining a literal parenthesis with a `{{TOKEN}}` placeholder reaches this immediately.

## Detailed Design

### Root Cause

`ApplyPlaceholderReplacements` (and `HasContentToReplace`'s Placeholder Mode branch) use `$pattern`
as-is, both to resolve the pattern's own `{{TOKEN}}` placeholders and to locate the pattern's text
within file content. Neither step accounts for the `\(`/`\)` escape convention the mode-detection
check (`$hasCaptures = $pattern -match '(?<!\\)\('`) relies on to route a pattern to Placeholder
Mode in the first place - the escape is read once, for classification, and never consumed.

### Decision

Once a pattern is confirmed to be Placeholder Mode, unescape it before any further use: replace
`\(` with `(` and `\)` with `)` in `$pattern`, a single pass applied right after mode detection
routes to Placeholder Mode, before the pattern's own `{{TOKEN}}` placeholders are resolved and
before its text is used to search file content. This makes both `ApplyPlaceholderReplacements` and
`HasContentToReplace`'s Placeholder Mode branch consistent with how Regex Mode already handles the
identical escape syntax - the same author-facing convention, now honored in both modes instead of
only one.

Regex Mode is untouched: its pattern flows directly into `[regex]::Matches`, which already
interprets `\(`/`\)` correctly and unassisted.

**Documentation:** add the escape convention to `docs/guides/release-management.md`'s Placeholder
Mode section, since it is not documented anywhere today and this RFC makes it actually functional
for the first time.

## Rationale and Alternatives

**Considered also changing the mode-*detection* heuristic itself** (e.g. only treating a pattern as
Regex Mode when it contains `{REGEX_` text, rather than any unescaped parenthesis), which would let
an *unescaped* literal parenthesis work in Placeholder Mode without requiring the author to know
about escaping at all. Rejected for this RFC - a materially larger, riskier change to the detection
algorithm both this RFC and RFC 0011 rely on, with its own alternative-design space and test
surface. The fix here keeps the existing, documented-by-comment convention ("escape a literal
parenthesis") and makes it actually work, rather than replacing it; the unescaped case continuing
to require escaping (with a somewhat unhelpful exception message if forgotten) is judged an
acceptable, separate, smaller-priority follow-up rather than something this RFC needs to solve too.

**Considered improving the unescaped case's exception message to hint at the escape convention**,
rather than leaving `ValidateRegexPatterns`' unrelated "No regex pattern defined for token" message
in place. Left as a possible smaller future enhancement, not required by this RFC's core fix -
noted here so it is not lost, not because it is out of scope on principle.

**Considered where to put the unescape step** (inside `PSScriptBuilderBumpModeResolver`, alongside
`DetermineBumpPatternMode`, vs. inside `PSScriptBuilderBumpReplacementHelper` itself). Leaning
toward keeping it in `PSScriptBuilderBumpReplacementHelper` - unescaping is specific to how
*replacement* uses the pattern text, not a mode-*detection* concern, so it does not belong in the
Resolver (RFC 0011's Scope explicitly keeps replacement mechanics out of the Resolver). Not fully
closed pending implementation-time review.

## Scope

**In scope:** `PSScriptBuilderBumpReplacementHelper.ApplyPlaceholderReplacements` and
`.HasContentToReplace`'s Placeholder Mode branch; the corresponding `docs/guides/release-management.md`
documentation addition; a `CHANGELOG.md` entry (this is an observable behavior fix, unlike RFC
0011).

**Out of scope:** Regex Mode (already correct, untouched); the mode-*detection* heuristic itself
(RFC 0011's concern, and see Rationale for why a detection-level fix is deliberately not pursued
here); improving the unescaped case's exception message (see Rationale).

## Relationship to Other RFCs

Found while implementing RFC 0011 (reviewing the exact `-match` conditions being centralized into
`PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode`), but independent of it - this RFC fixes
what happens *after* Placeholder Mode is determined, not the determination itself, and applies
identically regardless of whether RFC 0011's detection refactor has landed yet.

## Test Plan

- Regression test: a Placeholder Mode pattern containing an escaped literal parenthesis (`\(`/`\)`)
  must correctly match and replace in file content (the previously-silent no-op case).
- Non-regression test: existing Regex Mode escaped-parenthesis behavior
  (`"Branch: \(({REGEX_GIT_BRANCH})\), ..."`) continues to work unchanged.
- Non-regression test: existing Placeholder Mode patterns with no parentheses at all continue to
  work unchanged.
- Documented, not fixed by this RFC: the unescaped-literal-parenthesis case continues to throw:
  covered by a test that locks in the current (still misleading, but not silently wrong) exception
  behavior, so a future change to it is deliberate rather than accidental.

## Unresolved Questions

Exact placement of the unescape step (`PSScriptBuilderBumpReplacementHelper` vs. elsewhere) - see
Rationale; does not block starting implementation.

## Revision Log

- 2026-09-08 — Closed the last remaining parked item from this RFC's own review: the
  `Changes.Pattern`/`Changes.OldValue` redundancy in `Format-PSScriptBuilderBumpResult`'s output
  (Simple/Placeholder Mode always set them equal; only Regex Mode's `Pattern` - the config template
  with `{REGEX_TOKEN}` - legitimately differs from the actual matched `OldValue`). Per best-practice
  proportionality (design-doc processes like Rust RFCs/Python PEPs/K8s KEPs, the model for this
  project's own `internal/rfc/` convention, are reserved for decisions with real ambiguity or
  multiple viable designs - not warranted here, since the fix mirrors an existing, already-decided
  pattern), this was closed directly rather than as a new RFC, exactly like the item above. Fixed by
  conditionally suppressing the Pattern line in `Format-PSScriptBuilderBumpResult` when it equals
  `OldValue`, matching the existing conditional-display precedent already used in
  `Format-PSScriptBuilderTemplateAnalysis` (its `Key` line, shown only in Hybrid/Ordered mode) -
  reused verbatim rather than inventing a new display convention. Not a breaking change: the
  `Changes`/`ChangedItems` object shape itself is untouched, only the console formatter's display
  logic changed. Added `tests/Unit/Public/Format-PSScriptBuilderBumpResult.Tests.ps1` (the cmdlet had
  no dedicated test file before this), covering both the suppressed and shown cases, reusing the
  Information-stream capture pattern already established in
  `Format-PSScriptBuilderSourceCoverage.Tests.ps1`. Noted the remaining test-coverage gap across the
  other untested `Format-*` cmdlets in `internal/test-strategy.md`'s new "Known Coverage Gaps"
  section, rather than backfilling all of them now (out of scope for this fix). Full suite: 1924
  passed (1922 + 2 new), 0 failed.
- 2026-09-08 — Closed the remaining "improve the unescaped case's exception message" parked item
  (see the entry below and Rationale): `PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode`'s
  mixed-syntax exception (RFC 0013) now also appends a conditional hint pointing at the escape
  convention - "If a parenthesis here is meant to be literal text rather than a capture group,
  escape it with \( and \)." - phrased conditionally rather than as a diagnosis, since the system
  cannot know for certain the parenthesis (rather than a stray `{{TOKEN}}`) is the actual mistake;
  this is safe because it only changes message text, not routing behavior. No existing test asserts
  the exact message text (only exception type and a `-Match 'cannot mix'` substring check), so none
  needed updating. Full suite: 1922 passed, 0 failed.
- 2026-09-08 — Noted while implementing RFC 0013: the "unescaped literal parenthesis" repro this
  RFC describes (`'Copyright (c) {{YEAR}}'`) is, on reflection, the *same pattern shape* RFC 0013
  calls "mixed syntax" - a Placeholder-mode-intended pattern always contains `{{TOKEN}}`, so an
  unescaped literal parenthesis in it unavoidably makes it a mixed pattern by RFC 0013's
  definition. RFC 0013 now catches this case earlier, with a clearer, more specific error
  (`ArgumentException`: "Pattern cannot mix...") than the generic `InvalidOperationException`
  ("No regex pattern defined for token...") it previously fell through to. This substantially
  addresses this RFC's own "improve the unescaped case's exception message" parked item (see
  Rationale) - not exactly as originally envisioned (a hint pointing at escaping), but with an
  arguably more directly useful message (naming the real ambiguity). The regression test for this
  case was moved and updated accordingly as part of RFC 0013's own test changes.
- 2026-09-08 — Implemented. New hidden `UnescapeLiteralParenthesesInPattern` on
  `PSScriptBuilderBumpReplacementHelper`, called at the top of `ApplyPlaceholderReplacements`
  (reassigns `$pattern` locally) and inside `HasContentToReplace`'s Placeholder branch (via an
  intermediate variable, split out for readability on request). Added the two Test Plan regression/
  documented-behavior tests; the Regex Mode non-regression case was already covered by an existing
  RFC 0007 test. Documented the escape convention in `docs/guides/release-management.md`, next to
  Entry 3's `{{TOKEN}}`-pattern example (the guide has no separate "Placeholder Mode" section);
  verified the doc's own example against the real, fixed class before publishing it. Added a
  `CHANGELOG.md` entry. Full suite: 1912 passed, 0 failed - verified via both `build.ps1` and
  `Build-Module.ps1` (the latter is the one actually published to the PowerShell Gallery). Two
  items explicitly parked for later
  during review, not part of this RFC: the `Changes.Pattern`/`Changes.OldValue` redundancy in
  Simple/Placeholder Mode, and improving the unescaped-parenthesis case's misleading exception
  message.
- 2026-09-08 — Corrected the escaped-parenthesis repro's content example before implementation:
  the original example used already-resolved content (`Copyright (c) 2025`), which Placeholder
  Mode's content-level search can never match regardless of any fix, since that mode only ever
  looks for a pattern's own still-unresolved `{{TOKEN}}` text in content, not an already-substituted
  value. Verified the corrected repro (content still containing the literal, unescaped parenthesis
  and the unresolved placeholder - the only shape a not-yet-bumped file can realistically have)
  reproduces the same silent no-op, and that the proposed fix (unescape once inside
  `ApplyPlaceholderReplacements`, after mode detection has already routed there) resolves it
  correctly. The unescaped-parenthesis repro is unaffected by this correction - it throws inside
  `ValidateRegexPatterns` before any content is examined, regardless of content shape. Also
  confirmed, empirically, that the fix must reassign `$pattern` only *locally* inside
  `ApplyPlaceholderReplacements` - it must not be applied by re-invoking the public
  `ApplyPatternReplacements` dispatcher with an already-unescaped pattern, since that would
  re-run mode detection on the now-unescaped (and therefore unambiguously-parenthesized) text and
  misroute it to Regex Mode a second time.
- 2026-09-07 — Initial draft, written after verifying both failure modes (unescaped throws
  misleading exception; escaped silently no-ops) with the real, unmodified class, and confirming
  the escape convention already works correctly for Regex Mode via .NET's native `\(` handling.
