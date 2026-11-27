# RFC 0004: Template Placeholder Case-Sensitivity Mismatch

- **Status:** Implemented (2026-09-04)
- **Type:** Fix
- **Created:** 2026-08-30
- **Branch:** `refactor/template-engine-consolidation`

## Summary

`docs/guides/templates.md` documents placeholder matching as case-insensitive. Validation
(`PSScriptBuilderTemplateValidator`) correctly implements that contract throughout. Replacement
(`PSScriptBuilderTemplateProcessor`) does not — every one of its replacement paths compares
case-sensitively. The result: `Test-PSScriptBuilderTemplate` returns `$true` for a
differently-cased placeholder, but the real build silently ships output with the literal,
unreplaced `{{...}}` text still in it and the corresponding content missing entirely — with no
error or warning anywhere.

## Motivation

`docs/guides/templates.md` states the contract explicitly, twice:

> "Matching is case-insensitive, so `{{CLASS_DEFINITIONS}}` and `{{class_definitions}}` are
> equivalent." (line 33-34)
>
> "Placeholder matching is case-insensitive." (line 311, opening the Placeholder Rules section)

`PSScriptBuilderTemplateValidator.ps1` implements this consistently — every placeholder-matching
call in the file uses either `[StringComparison]::OrdinalIgnoreCase` (`IndexOf` calls at lines
317, 343, 388, 411, 425) or PowerShell's default case-insensitive `-match` (lines 158, 473). This
is why `Test-PSScriptBuilderTemplate` correctly returns `$true` for a differently-cased
placeholder — validation is not the problem.

`PSScriptBuilderTemplateProcessor.ps1` does not honor the same contract anywhere:

- `DiscoverReplacements()` (Free Mode, line 288) finds each collector's placeholder via
  `IndexOf($placeholder, [StringComparison]::Ordinal)` (line 294) — explicitly case-sensitive.
- `ReplaceUsingCollectorPlaceholders()` (line 447), `ReplaceFileCollectorPlaceholders()` (line
  520), and `ReplaceOrderedComponentsPlaceholder()` (line 572) each use a case-insensitive `-match`
  only to check *whether* a placeholder exists, then call `.Replace($placeholder, $content)` — the
  two-argument `String.Replace` overload, which has no case-insensitive form and matches only the
  exact casing of `$placeholder` as constructed from the collector's `CollectionKey` or the active
  `OrderedComponentsKey`.

Found 2026-08-30 while investigating a request to check template processing in detail for any
undiscovered pitfall, following up on the pattern established by RFC 0001-0003 (raw text matching
with inconsistent assumptions about what counts as "the same" placeholder).

**Repro — verified with real builds, one per replacement path, all four confirmed:**

| Path | Method | Template | Result |
|---|---|---|---|
| Free Mode, any collector | `DiscoverReplacements` | `{{class_definitions}}` (Class collector, default `CollectionKey` `CLASS_DEFINITIONS`) | `Test-PSScriptBuilderTemplate` → `$true`. Build "succeeds"; output is the literal text `{{class_definitions}}`; the class itself is entirely missing. |
| Ordered/Hybrid, `Using` | `ReplaceUsingCollectorPlaceholders` | `{{using_statements}}` | Build "succeeds"; `{{using_statements}}` left literally in output. |
| Ordered/Hybrid, `File` | `ReplaceFileCollectorPlaceholders` | `{{doc_file}}` (`CollectionKey` `DOC_FILE`) | Build "succeeds"; `{{doc_file}}` left literally in output. |
| Ordered/Hybrid, combined block | `ReplaceOrderedComponentsPlaceholder` | `{{my_components}}` (`-OrderedComponentsKey "MY_COMPONENTS"`) | `Test-PSScriptBuilderTemplate` → `$true`. Build "succeeds"; `{{my_components}}` left literally in output. |

In every case: no error, no warning, `Invoke-PSScriptBuilderBuild` reports success, and the shipped
file contains raw template syntax instead of the intended content.

This is broader than RFC 0002/0003: those affect only Ordered/Hybrid Mode under specific
conditions (a colliding key, a content collision). This affects **every** collector type in
**both** modes, and is trivially easy to trigger by accident precisely because the documentation
tells users case doesn't matter.

**Compounding gap found while designing this RFC's regression tests:**
`ValidateNoDuplicatePlaceholders` (`PSScriptBuilderTemplateValidator.ps1:523-553`) also does not
detect a duplicate that differs only in case. Verified: a template containing both
`{{CLASS_DEFINITIONS}}` and `{{class_definitions}}` for the same `Class` collector passes
`Validate()` without error — the method's `[Regex]::Matches($templateContent, $pattern)` call
(line 536) has no `RegexOptions.IgnoreCase`, unlike every other placeholder-matching call in the
same class. This is not a separate bug — same root cause, another location — but it is a sharper
version of it: `DiscoverReplacements`'s own doc comment states its `IndexOf` (finds only the first
occurrence) is safe specifically *because* "`ValidateNoDuplicatePlaceholders()` guarantees each
placeholder appears at most once in `$template`". That precondition is false across case variants,
so the two bugs compound: today, only the exact-case occurrence would even be found by
`DiscoverReplacements`, but the *documented* guarantee it relies on does not hold for
differently-cased duplicates either.

**Second compounding gap, found during a full pre-implementation re-analysis:**
`ValidateNoDuplicatePlaceholders` explicitly skips `Using` collectors entirely (line 529-531,
"Skip Using collectors — they have their own duplicate handling"), deferring to
`ReplaceUsingCollectorPlaceholders`'s own "first found wins, others warned" logic. That logic does
not actually detect a same-collector duplicate at all — it iterates once *per registered
collector*, checking only whether *that collector's own* placeholder exists anywhere in the
template (`-match`), never how many times. With a single registered `Using` collector, this loop
runs exactly once and cannot notice that its placeholder appears more than once in the text, in
any casing.

**Verified with a real build, both modes:** a template containing `{{USING_STATEMENTS}}` and
`{{using_statements}}` (same collector, differing only in case) —

```
Test-PSScriptBuilderTemplate → $true
Build output:
  using namespace System.Collections.Generic
  # some code here
  {{using_statements}}          <- left literally in output, unreplaced
```

Identical result in Hybrid Mode. The first (exact-case) occurrence is replaced correctly by
`.Replace()`; the second, differently-cased occurrence is untouched by that same case-sensitive
call and is never reached by any duplicate check, since `Using` is exempted from the one check that
would otherwise catch it. This is the same silent-corruption pattern as the rest of this RFC, for a
case `ValidateNoDuplicatePlaceholders`'s fix (above) does not reach because of the pre-existing
`Using` exemption.

**Confirmed the exemption is not actually needed for this check**, before proposing to remove it —
checked git history (no rationale beyond the doc comment already quoted), searched for any test
exercising two distinct `Using` collectors together (none exists), and re-read
`ReplaceUsingCollectorPlaceholders`'s full doc comment: its "multiple Using placeholders" warning
is about *multiple different, distinctly-keyed* `Using` collectors coexisting in one template (e.g.
`USING_STATEMENTS` and `EXTERNAL_USINGS`, both present, consolidated content landing at whichever
is found first) — a scenario `ValidateNoDuplicatePlaceholders`'s per-collector-key check does not
conflict with, since it only asks "does *this one* collector's own key appear more than once,"
never "do two different collectors' keys coexist." There is also no plausible legitimate reason to
want the *same* `Using` collector's placeholder to appear twice in one template: PowerShell requires
`using` statements at the very top of a script, so a second occurrence anywhere else could never be
syntactically valid regardless of intent.

## Detailed Design

### Root Cause

`PSScriptBuilderTemplateValidator` and `PSScriptBuilderTemplateProcessor` were implemented against
the same documented contract independently, with inconsistent `StringComparison` choices.
Compounding this, .NET's two-argument `String.Replace(string, string)` — used at every replacement
site in the Processor — has no case-insensitive overload at all, so even a call site that first
*checks* case-insensitively (the `-match` calls in the three `Replace*` methods) still performs a
case-sensitive substitution once it decides to act.

### Decision

**Free Mode (`DiscoverReplacements`):** change the `IndexOf` call from
`[StringComparison]::Ordinal` to `[StringComparison]::OrdinalIgnoreCase`. This is sufficient on its
own: the replacement's length is derived from the *found* substring's length (identical regardless
of case — changing case never changes character count), and the replacement content comes from the
collector, not from the matched text itself. Low-risk, mirrors the Validator's own choice, no
further design needed.

**Ordered/Hybrid Mode (`Using`/`File`/`ORDERED_COMPONENTS`):** RFC 0003 converts
`ReplaceUsingCollectorPlaceholders`, `ReplaceFileCollectorPlaceholders`, and
`ReplaceOrderedComponentsPlaceholder` into new `Discover*` sibling methods that compute
`(Start, Length, Replacement)` entries instead of calling `.Replace()` directly (see RFC 0003,
Detailed Design). The case-insensitivity fix belongs **inside those same new methods**: each one's
internal position search should use `IndexOf(..., [StringComparison]::OrdinalIgnoreCase)` instead
of today's case-insensitive-check-then-case-sensitive-`.Replace()` pattern. Building this into RFC
0003's new methods directly — rather than patching the current `Replace*` methods first and
porting the fix forward — means each method's matching logic is touched exactly once, in its final
shape (see `internal/rfc/IMPLEMENTATION-PLAN.md` for why this fix builds on RFC 0003's methods
rather than landing independently).

**`ValidateNoDuplicatePlaceholders`:** add `[RegexOptions]::IgnoreCase` to its `[Regex]::Matches`
call (line 536), matching the case-insensitive treatment every other Validator method already
gives placeholder matching. This makes the Validator correctly reject a template containing the
same collector's placeholder in two different casings as a duplicate, restoring the precondition
`DiscoverReplacements`'s doc comment already claims to rely on.

**Also remove `ValidateNoDuplicatePlaceholders`'s `Using`-collector exemption** (the `continue` at
line 530-531) so the same, now case-insensitive, per-collector-key check applies to `Using`
collectors uniformly, exactly like Enum/Class/Function/File. This does not change behavior for the
legitimate multiple-different-`Using`-collectors scenario (see Motivation for why the two checks
don't conflict) — it only starts catching the case where one specific `Using` collector's own key
appears more than once, in any combination of casing, which was never a legitimate configuration to
begin with.

## Rationale and Alternatives

**Considered: change the Validator to be case-sensitive instead, matching the Processor's actual
behavior.** Rejected — this would remove a feature the documentation explicitly promises and users
may already rely on; a behavior removal like that is a breaking change (Major, per SemVer), not a
bug fix, and there is no indication the case-insensitivity design intent itself is wrong. The
Validator's implementation is the correct half of the contract; the Processor's is the broken half.

**Considered as an interim mitigation: make validation strict enough to catch a case mismatch and
fail loudly, without yet making the Processor itself case-insensitive.** This would convert
today's silent corruption into a loud, safe validation failure — a real safety improvement — but
would leave the documented feature ("case-insensitive matching") still false, merely with a better
failure mode. Not adopted as the target design; noted here in case implementation needs to be
staged and a quick safety net is wanted before the full fix lands.

## Scope

**In scope:** `DiscoverReplacements`'s comparison mode (Free Mode); the case-sensitivity of the
three `Discover*` methods RFC 0003 introduces for Ordered/Hybrid Mode; `ValidateNoDuplicatePlaceholders`'s
case-sensitivity *and* its `Using`-collector exemption (see Detailed Design).

**Out of scope:** `PSScriptBuilderBumpReplacementHelper` (Release Management bump-file token
replacement) — checked `docs/guides/` and found no documented case-insensitivity claim for bump
tokens; this subsystem was never advertised as case-insensitive, so its existing case-sensitive
`.Replace()` behavior (`ApplySimpleReplacements`, line 169) is not a contract violation and is not
part of this fix.

## Relationship to Other RFCs

- **RFC 0003** (Ordered/Hybrid Mode template injection) — this fix's Ordered/Hybrid-Mode half is
  implemented inside the same `Discover*` methods RFC 0003 introduces, so it must land as part of
  that same implementation step rather than as an independent, later change.
- **RFC 0001** (template placeholder escaping) — shares the same general theme (raw text matching
  with an inconsistent assumption about what counts as "the same" placeholder) but a distinct root
  cause (comparison mode, not escaping/injection); not otherwise dependent on it.

See `internal/rfc/IMPLEMENTATION-PLAN.md` for the build order across all four RFCs on this branch.

## Test Plan

- Regression test: Free Mode template with a differently-cased placeholder than its collector's
  `CollectionKey` (e.g. `{{class_definitions}}` for a `Class` collector) must build successfully
  with the class content correctly substituted, not left as literal template text.
- Regression test: Ordered/Hybrid Mode template with a differently-cased `Using`/`File`/combined
  placeholder must build successfully with correct substitution, covering all three `Discover*`
  methods introduced by RFC 0003.
- Regression test: a custom `-OrderedComponentsKey` (e.g. `MY_COMPONENTS`) with a differently-cased
  placeholder in the template must also build correctly.
- Regression test: a template containing the same collector's placeholder twice, in two different
  casings (e.g. `{{CLASS_DEFINITIONS}}` and `{{class_definitions}}`), must fail validation as a
  duplicate, not pass silently.
- Regression test: a template containing a single registered `Using` collector's placeholder twice,
  in two different casings, must fail validation as a duplicate — confirms the `Using` exemption
  removal.
- Regression test: two *distinct* `Using` collectors, each with its own placeholder both present in
  the template, must continue to validate successfully and build with the existing "first found
  wins, other warned" behavior unchanged — confirms removing the exemption does not affect the
  legitimate multi-collector scenario.
- Confirm existing exact-case templates are unaffected (no behavior change for the common case).

All nine tests above were written and run against the current implementation, confirming each
fails today for the precise reason described in Motivation (not for an unrelated reason), and are
already committed to this branch — see Revision Log. The two `Using`-specific tests above are new
and not yet committed.

## Unresolved Questions

- None currently — fix direction and scope are decided; only implementation remains, pending
  explicit authorization.

## Revision Log

- 2026-09-04 — Implemented. Free Mode's `DiscoverReplacements` and all three Ordered/Hybrid Mode
  `Discover*` methods RFC 0003 introduces already use `[StringComparison]::OrdinalIgnoreCase`, per
  Decision. `ValidateNoDuplicatePlaceholders` now uses `[RegexOptions]::IgnoreCase` and no longer
  exempts `Using` collectors. Before removing the exemption, verified with a real
  `ContentCollector.AddCollector()` call — including via the `-Collector` array constructor path —
  that two collectors can never share the same `CollectionKey` within one `ContentCollector`;
  registration itself throws `InvalidOperationException` for a duplicate key. This confirms the
  per-collector-key duplicate check can never produce a false positive for the legitimate
  multiple-`Using`-collectors scenario, since any two `Using` collectors registered together
  necessarily have distinct keys. All nine Test Plan regression tests pass; full suite at 1838
  passed.
- 2026-09-01 — Found and verified, during a full pre-implementation re-analysis, that
  `ValidateNoDuplicatePlaceholders`'s pre-existing `Using`-collector exemption defeats this RFC's
  own duplicate-detection fix for `Using` specifically: confirmed with a real build (both modes)
  that a single `Using` collector's placeholder appearing twice, differing only in case, passes
  validation and leaves the second occurrence unreplaced in the output. Before proposing to remove
  the exemption, confirmed it is not actually protecting a legitimate scenario: checked git history
  (no rationale beyond the existing doc comment), found no test exercising multiple `Using`
  collectors together, and re-read `ReplaceUsingCollectorPlaceholders`'s doc comment to confirm its
  "multiple placeholders" warning is about distinct, differently-keyed `Using` collectors
  coexisting — a scenario the per-collector-key duplicate check does not conflict with. Added
  removing the exemption to Decision and Scope, with two new regression tests (one confirming the
  fix, one confirming the legitimate multi-collector scenario is unaffected).
- 2026-08-31 — Rewritten as a self-contained document, renumbered from RFC 0005 to RFC 0004 as
  part of a branch-wide RFC renumbering (the deferred, out-of-scope unified-rendering RFC moved
  from 0004 to 0005 instead, so the four active-branch RFCs occupy consecutive numbers). Removed
  phase-numbering language (now in `internal/rfc/IMPLEMENTATION-PLAN.md`). No decisions changed.
- 2026-08-30 — Before writing any code, drafted all nine regression tests from the Test Plan and
  ran them against the current implementation to verify each fails today for the precise
  documented reason (not a test-authoring mistake). Found and added a compounding gap while doing
  so: `ValidateNoDuplicatePlaceholders` also does not detect a case-differing duplicate, breaking
  the precondition `DiscoverReplacements`'s own doc comment claims to rely on. Confirmed the
  RFC0002-Repro-1 test should assert a substring (`*collis*`) rather than the full proposed message
  text, to avoid coupling the test to not-yet-finalized exact wording. All nine tests committed to
  this branch, verified red.
- 2026-08-30 — Initial finding, in response to a direct request to check template processing in
  detail for any remaining undiscovered pitfall. Verified all four replacement paths via real
  builds.
