# RFC 0013: Release Management Mixed Pattern Syntax Validation

- **Status:** Implemented (2026-09-08)
- **Type:** Fix
- **Created:** 2026-09-07
- **Branch:** `refactor/release-management-bump-mode`

## Summary

A bump config item's pattern combining both Placeholder syntax (`{{TOKEN}}`) and Regex syntax (an
unescaped capture group, typically built from `{REGEX_TOKEN}`) is accepted by validation today, but
always silently fails to replace anything at runtime - no error, no warning. Reject this
combination explicitly, both at config-validation time (a clear, actionable error) and at
replacement time (defense in depth), instead of letting it fail silently.

## Motivation

Found while discussing RFC 0011's `DetermineBumpPatternMode` extraction: asked what happens if a
bump config item's pattern accidentally combines both pattern modes. Verified directly with the
real, unmodified class:

```powershell
$helper.ApplyPatternReplacements('main vs (main)', '{{GIT_BRANCH}} vs ({REGEX_GIT_BRANCH})', @('GIT_BRANCH'))
# Content unchanged, Changes.Count: 0 - no error, no warning
```

No exception is thrown (unlike RFC 0012's unescaped-literal-parenthesis case) - the pattern is
routed to Regex Mode (an unescaped parenthesis is present, and the current detection logic always
prefers Regex Mode whenever any unescaped parenthesis appears, regardless of `{{`). `ReplaceRegexPatterns`
only resolves `{REGEX_GIT_BRANCH}` (single-brace syntax); the literal `{{GIT_BRANCH}}` text is left
untouched inside the constructed regex, which then requires that exact literal text to be present
in file content to match anything - content produced by any real bump (with the placeholder already
resolved, or never containing that literal text to begin with) can never satisfy this, so the regex
finds zero matches and the operation quietly does nothing.

**Distinct from RFC 0012.** RFC 0012 is about a pattern with no genuine regex intent at all (a
literal parenthesis in ordinary text) failing due to an escape convention that is read but never
consumed. This is a different root cause: no validation exists anywhere to reject a pattern that
*ambiguously combines both syntaxes* in the first place - `PSScriptBuilderBumpFilesValidator.ValidateItemConfiguration`
checks that `item.pattern` is a non-empty string, but never inspects its shape (confirmed while
writing RFC 0011's Motivation). Kept as a separate RFC per this project's established
same-investigation-different-root-cause convention (the direct precedent being RFC 0007/0008/0009,
found together, kept as three RFCs because each has a distinct cause).

**Decision to fix rather than document as a known limitation:** per this project's established
Cost-of-Quality bar, a reachable silent-failure defect gets fixed. Reachability here is real,
though probably less common than RFC 0012's (a pattern combining both a `{{TOKEN}}` reference and a
`{REGEX_TOKEN}` reference is a more deliberate authoring mistake than an incidental literal
parenthesis) - still a config an author could plausibly write, e.g. while migrating a pattern from
one mode to the other and leaving a stray reference behind, and the current behavior gives them
zero indication anything is wrong.

## Detailed Design

### Root Cause

Two independent gaps combine to produce the silent failure:
1. `PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode` (RFC 0011) resolves the ambiguous
   "both present" case silently in favor of Regex Mode, rather than treating it as invalid input.
2. `PSScriptBuilderBumpFilesValidator.ValidateItemConfiguration` never inspects `item.pattern`'s
   shape at all, so this ambiguity is never caught before it reaches replacement time.

### Decision

- Extend `DetermineBumpPatternMode` with a dedicated branch for the "both present" case, throwing a
  specific `ArgumentException` distinct from the existing "neither present" exception:
  ```powershell
  static [PSScriptBuilderBumpPatternMode] DetermineBumpPatternMode([string] $pattern) {
      $hasPlaceholders = $pattern -match '\{\{'
      $hasCaptures     = $pattern -match '(?<!\\)\('

      if ($hasPlaceholders -and $hasCaptures) {
          throw [ArgumentException]::new("Pattern cannot mix {{TOKEN}} placeholder syntax with regex capture group syntax: $pattern")
      }
      if ($hasPlaceholders) {
          return [PSScriptBuilderBumpPatternMode]::Placeholder
      }
      if ($hasCaptures) {
          return [PSScriptBuilderBumpPatternMode]::Regex
      }

      throw [ArgumentException]::new("Pattern must contain either {{TOKEN}} placeholders or capture groups: $pattern")
  }
  ```
  This is defense in depth at replacement time, for any caller that reaches `ApplyPatternReplacements`/
  `HasContentToReplace` without having gone through config validation.
- `PSScriptBuilderBumpFilesValidator.ValidateItemConfiguration` calls `DetermineBumpPatternMode` on
  `item.pattern` (wrapped so its exception becomes a normal validation error with file/item-index
  context, matching every other validation failure in that method) as an additional check, so a
  bump config with this mistake fails immediately and clearly when the user runs
  `Update-PSScriptBuilderBumpFiles` (or any validation-first entry point), instead of silently
  producing zero changes with no explanation.

## Rationale and Alternatives

**Considered only fixing this at the Validator level, without changing `DetermineBumpPatternMode`
itself.** Rejected - `ApplyPatternReplacements`/`HasContentToReplace` are usable independently of
`PSScriptBuilderBumpFilesValidator` (there is no enforced call order between them at the class
level), so relying solely on upstream validation would leave a direct caller of the replacement
helper with the same silent failure RFC 0013 exists to close. Fixing the shared detection method
closes it for every caller at once.

**Considered a softer fallback (e.g., preferring Placeholder Mode and ignoring the stray capture
group, or vice versa) instead of throwing.** Rejected - guessing which of the two conflicting
intents the author meant is exactly the kind of silent, unverifiable behavior this project's
Cost-of-Quality bar exists to avoid; an explicit, immediate error that names the actual problem
lets the author fix their config with full information, consistent with how the existing "neither"
case already throws rather than guessing.

## Scope

**In scope:** `PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode`'s new "both present"
branch; `PSScriptBuilderBumpFilesValidator.ValidateItemConfiguration`'s new pattern-shape check; a
`CHANGELOG.md` entry (this is an observable behavior fix - a config that previously produced a
silent no-op now fails validation with a clear error).

**Out of scope:** RFC 0012's literal-parenthesis-escaping fix (independent root cause, tracked
separately); any change to how a *validly-shaped* Placeholder or Regex pattern is processed.

## Relationship to Other RFCs

Depends on RFC 0011 (`PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode` must exist first) -
this RFC extends that method rather than duplicating its pattern-shape checks. Found during the
same investigation as RFC 0012, touching an overlapping area
(`PSScriptBuilderBumpReplacementHelper`'s pattern-mode detection) but with a distinct root cause
(missing validation for an ambiguous pattern, vs. RFC 0012's unconsumed escape hint for an
unambiguous one) - kept separate per this project's established convention, with RFC 0007/0008/0009
as the direct precedent for related-but-distinct RFCs found in one investigation.

## Test Plan

- Regression test: a pattern containing both `{{TOKEN}}` and an unescaped capture group must throw
  a clear `ArgumentException` from `DetermineBumpPatternMode` (replacing the current silent
  zero-match no-op).
- Regression test: a bump config item with such a pattern must fail
  `PSScriptBuilderBumpFilesValidator.Validate()` with a clear, contextualized error (file/item
  index), not merely at replacement time.
- Non-regression test: existing valid Placeholder-only and Regex-only patterns continue to be
  classified and validated identically to before.

## Unresolved Questions

None currently - decision, scope, and the exact new exception/validation wording are settled; only
implementation remains.

## Revision Log

- 2026-09-08 — Corrected shortly after implementation: the `$hasPlaceholders`/`$hasCaptures`
  signals this RFC's new "both present" check relies on only detected an *opening* marker
  (`\{\{` / an unescaped `\(`), not a complete, well-formed shape. A dangling, unclosed `{{` or `(`
  - never a valid placeholder or capture group on its own - could therefore trigger a false-positive
  "cannot mix" error once combined with a genuine signal of the other kind (e.g. `'Value: (\d+) {{'`
  incorrectly threw, even though the trailing `{{` was never a real placeholder attempt). Tightened
  both checks to require a complete, closed shape (`\{\{[^}]+\}\}` and `(?<!\\)\([^)]*\)`),
  matching the precedent `PSScriptBuilderTemplateModeResolver.ExtractPlaceholders` already uses for
  the identical purpose on the Template side. Verified this does not reopen RFC 0012's own
  deliberately-deferred case (a *balanced*-but-unescaped literal parenthesis, e.g. `(c)`, still
  correctly counts as a capture-group signal - only a *dangling, unclosed* one no longer does), and
  confirmed zero regressions against every existing real Placeholder/Regex pattern in the test
  suite. Per this project's RFC convention, corrected in place (Revision Log, not a rewrite of the
  frozen Decision text above) rather than as a new RFC, since this refines the exact same two lines
  RFC 0013 introduced minutes earlier, with no other work yet depending on the looser behavior.
  Added four new regression tests. Full suite: 1918 passed, 0 failed.
- 2026-09-08 — Implemented. `DetermineBumpPatternMode` now throws a dedicated `ArgumentException`
  for the "both present" case; `PSScriptBuilderBumpFilesValidator.ValidateItemConfiguration` calls
  it and surfaces the exception as a normal, contextualized validation error. While implementing,
  found that RFC 0012's own "unescaped literal parenthesis" repro is the identical pattern shape
  this RFC calls "mixed syntax" (a Placeholder-intended pattern always contains `{{TOKEN}}`, so an
  unescaped parenthesis in it is unavoidably "mixed") - updated RFC 0012's own regression test to
  expect the new, clearer `ArgumentException` instead of the old, unrelated
  `InvalidOperationException` it used to fall through to, and added a note to RFC 0012's Revision
  Log; this RFC substantially resolves RFC 0012's own parked "improve the misleading exception
  message" item as a side effect. Verified no existing test pattern (Validator, Processor,
  Orchestrator) was ambiguous under the new check before implementing. Full suite: 1914 passed, 0
  failed - verified via both `build.ps1` and `Build-Module.ps1`.
- 2026-09-07 — Initial draft, written after verifying the silent no-op with the real, unmodified
  class and confirming the root cause is a missing validation guard, distinct from RFC 0012's
  unconsumed-escape-hint root cause, per this project's established same-investigation-different-
  cause convention.
