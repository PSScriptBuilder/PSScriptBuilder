# RFC 0001: Template Placeholder Escaping

- **Status:** Implemented (2026-09-05)
- **Type:** Feature
- **Created:** 2026-08-29
- **Branch:** `refactor/template-engine-consolidation`

## Summary

A PSScriptBuilder template has no way to show `{{KEY}}`-shaped text as literal prose (e.g., in a
documentation comment) without it being treated as a real, functioning placeholder. This RFC
introduces an escape syntax — `{{{{KEY}}}}` (quadruple brace) renders as literal `{{KEY}}` in the
output — and the consolidation of currently-duplicated placeholder-detection logic needed to
support it correctly everywhere.

## Motivation

A PSScriptBuilder template is plain text; placeholder detection has no concept of a "comment" —
anything that looks like `{{KEY}}` is treated as a real, functioning placeholder, regardless of
where it appears in the file. This is true at both validation time and replacement time:

- Mode detection (`$useOrderedMode`) is computed via a raw substring search of the *entire*
  template content for the ordered-components token, duplicated identically in three places:
  `Test-PSScriptBuilderTemplate` (`src\Public\Test-PSScriptBuilderTemplate.ps1:145-146`),
  `PSScriptBuilderBuildOrchestrator` (`src\Classes\ScriptBuilder\Orchestrators\PSScriptBuilderBuildOrchestrator.ps1:451-453`),
  and `PSScriptBuilderTemplateAnalyzer` (`src\Classes\ScriptBuilder\Template\PSScriptBuilderTemplateAnalyzer.ps1:136-141`,
  via `ExtractPlaceholders()`'s generic `\{\{([^}]+)\}\}` regex). None can distinguish "this
  occurrence is a real placeholder" from "this occurrence is descriptive text that happens to use
  the same syntax."
- Replacement is equally unconditional: `PSScriptBuilderTemplateProcessor.ReplaceOrderedComponentsPlaceholder()`
  (`PSScriptBuilderTemplateProcessor.ps1:610`) uses `$template.Replace($placeholder, ...)` — .NET's
  `String.Replace()` substitutes *every* occurrence of the literal substring, not just a single
  designated one.

**Real, reproduced repro:** a completely valid Free Mode project (`examples\02-classes-and-enums`
— no cross-dependencies) with this template —

```powershell
# Example: you could switch to Hybrid mode by using {{ORDERED_COMPONENTS}} instead
{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

— where `{{ORDERED_COMPONENTS}}` appears only inside a documentation comment, not as a
functioning placeholder. Result, identical across all three affected code paths:

- `Test-PSScriptBuilderTemplate` → `$false`
- `Get-PSScriptBuilderTemplateAnalysis` → `ValidationMode: Hybrid`, `IsValid: $false`
- `Invoke-PSScriptBuilderBuild` (the real build) → **fails**:
  `"Enum/Class/Function placeholders are forbidden when {{ORDERED_COMPONENTS}} is used
  (components must share the single ordered placeholder). Found: {{ENUM_DEFINITIONS}},
  {{CLASS_DEFINITIONS}}, {{FUNCTION_DEFINITIONS}}"`

A correct project with a correct template cannot be built, solely because a comment mentions the
placeholder token as prose. The same applies to any collector's default or custom key, and to a
custom `-OrderedComponentsKey`, not just the default `ORDERED_COMPONENTS`. This is not
hypothetical for PSScriptBuilder's own documentation: `templates.md` itself needs to show the
literal token text as an example in prose and in its own generated-file illustrations — the exact
scenario that triggers this.

Found 2026-08-29 while reviewing the Templates Guide (`docs/guides/templates.md`).

## Detailed Design

### Why this isn't a one-line fix

- The detection logic is duplicated across three call sites rather than shared — any fix needs to
  land consistently in all three, plus the replacement logic in `PSScriptBuilderTemplateProcessor`.
- There is currently no escape syntax at all. Introducing one is a change to the core placeholder
  *syntax*, not a corrected implementation of existing intent.
- A line-position-based heuristic ("only count a placeholder if it's alone on its own line") is
  not viable: `templates.md` documents and relies on placeholders mixed with static text on the
  same line (`# Version {{VERSION}} — built {{BUILD_DATE}}`), so this would silently break a
  supported, documented use case.

### Decision

**Escape syntax: `{{{{KEY}}}}` (quadruple brace) → literal `{{KEY}}` in the output.** See
Rationale and Alternatives for why this was chosen over a backslash-prefix alternative.

**Step 1 — Consolidate placeholder/mode detection into `PSScriptBuilderTemplateModeResolver`.**
A prerequisite refactor, no behavior change for any currently-existing template. New file
`src\Classes\ScriptBuilder\Template\PSScriptBuilderTemplateModeResolver.ps1` — a static utility
class living in `Template\`, alongside its sibling classes `PSScriptBuilderTemplateValidator`,
`PSScriptBuilderTemplateProcessor`, `PSScriptBuilderTemplateAnalyzer`, and
`PSScriptBuilderTemplateGenerator`. Deliberately not named or modeled after
`PSScriptBuilderAstEngine` (`src\Classes\ScriptBuilder\Core\PSScriptBuilderAstEngine.ps1`) — "Engine"
is reserved in this codebase for that one, much larger and more central class, which every collector
depends on; this class is a narrow, three-method utility with a single purpose (decide which of the
two rendering modes applies), so it takes a name describing exactly that instead. Needed because the
escape mechanism (Step 2) must apply consistently across all three duplicated detection call sites;
consolidating them first means the masking work in Step 2 only has to change one thing, not three.

Also deliberately not folded into `PSScriptBuilderTemplateProcessor`: `Test-PSScriptBuilderTemplate.ps1`
has no existing dependency on `PSScriptBuilderTemplateProcessor` at all (it calls
`PSScriptBuilderTemplateValidator::Validate()` directly), and `useOrderedMode` is a required
constructor parameter of `PSScriptBuilderTemplateProcessor` — the mode decision must already exist
*before* a `Processor` instance can be created, so it cannot live on that class.

```powershell
class PSScriptBuilderTemplateModeResolver {
    static [string[]] ExtractPlaceholders([string] $templateContent)
    static [bool] HasOrderedPlaceholder([string] $templateContent, [string] $orderedComponentsKey)
    static [bool] DetermineUseOrderedMode([bool] $hasCrossDependencies, [string] $templateContent, [string] $orderedComponentsKey)
}
```

- `ExtractPlaceholders` — moved from `PSScriptBuilderTemplateAnalyzer` verbatim (regex
  `\{\{([^}]+)\}\}`); becomes the one place in the codebase that does this.
- `HasOrderedPlaceholder` — internally uses `ExtractPlaceholders` + `-contains` (the more correct
  of the two approaches already in the codebase) instead of the raw
  `$templateContent -match [Regex]::Escape(...)` used today in two of the three call sites.
  Confirmed via an exhaustive repo-wide search that exactly three call sites need migrating, no
  hidden fourth consumer: `Test-PSScriptBuilderTemplate.ps1:145-146`,
  `PSScriptBuilderBuildOrchestrator.ps1:451-453`, `PSScriptBuilderTemplateAnalyzer.ps1:136-141`.
- `DetermineUseOrderedMode` — captures the `$hasCrossDependencies -or $hasOrderedPlaceholder`
  logic itself, also duplicated verbatim in all three places today.

Migration order (one consumer at a time, full test suite after each): `PSScriptBuilderTemplateAnalyzer`
first (most existing unit test coverage, proving the Engine is behaviorally equivalent), then
`Test-PSScriptBuilderTemplate.ps1`, then `PSScriptBuilderBuildOrchestrator.ps1`.

Raw `-match` and `ExtractPlaceholders()` + `-contains` behave identically for the original bug (a
plain 2-brace mention like `{{ORDERED_COMPONENTS}}` inside prose) — this consolidation step alone
does not fix that; Step 2 does. They genuinely disagree only for a 4-brace sequence: raw `-match`
finds it as a substring (`$true`), while `ExtractPlaceholders()`'s regex produces the malformed
capture `{{{{ORDERED_COMPONENTS}}` (its `[^}]+` greedily consumes the extra leading braces), which
does not equal the clean 2-brace token (`$false`). Verified with real regex execution. Zero
practical effect at this step (no existing template contains a 4-brace sequence — see Motivation),
and not something Step 2 can rely on: it's an accidental, partial side effect of one regex's
stopping behavior, not a real escape implementation.

**Step 2 — Escape masking mechanism.** New class `PSScriptBuilderTemplateEscapeHelper` in
`src\Classes\ScriptBuilder\Template\`, alongside `PSScriptBuilderTemplateModeResolver` — the same
domain-ownership reasoning applies to both: each is a narrow, static utility whose subject is the
Template placeholder syntax itself, not a class tied to whichever layer happens to call it.
`PSScriptBuilderTemplateModeResolver`'s own actual callers are the same three orchestrating call
sites this class needs (`Test-PSScriptBuilderTemplate.ps1`, `PSScriptBuilderBuildOrchestrator.ps1`,
`PSScriptBuilderTemplateAnalyzer.ps1`), not its Template-folder siblings (only the Analyzer calls it
directly) — so "belongs near its siblings because it's a Template concept" was always the real reason
for its placement, not literal caller-adjacency. The same reasoning places this class in `Template\`.

Mechanism unchanged: mask before, restore after, applied once, not patched into every individual
check/replacement method:

- `Mask([string] $content)` returns the content with every match of
  `(?<!\{)\{\{\{\{([^{}]+)\}\}\}\}(?!\})` replaced by a unique sentinel built from a NUL character
  (`` `0 ``) as the delimiter, e.g. `` `0ESC_3`0 ``. NUL bytes practically never appear in real
  PowerShell source, and the sentinel doesn't look like `{{...}}` at all, so it's invisible to
  every existing `{{...}}`-matching check or replacement without touching any of them
  individually. Returns both the masked content and a map from sentinel → original literal text
  (already un-escaped to two braces).

  **Boundary-aware, not the simpler `\{\{\{\{([^}]+)\}\}\}\}`** — the negative lookbehind/lookahead
  (no extra `{` immediately before, no extra `}` immediately after) and the tightened character
  class (`[^{}]+` instead of `[^}]+`, excluding both brace kinds from the captured key, not just
  `}`) together ensure the match is *exactly* four braces on each side, never five or more. Verified
  with real regex execution that this changes nothing for every already-correct case (a normal
  `{{{{KEY}}}}`, one embedded in surrounding text, two adjacent escapes, and the already-documented
  empty-`{{{{}}}}` case all behave identically to the simpler pattern) — see the malformed-nesting
  edge case below for why the tightened pattern is necessary.
- `Unmask([string] $content, [hashtable] $map)` reverses it after all normal processing has run.

**Corrected during a full pre-implementation re-verification (2026-09-05) — where masking is actually
applied.** The original Decision here stated masking would be applied "at exactly one entry point:
`PSScriptBuilderTemplateValidator.Validate()` and `PSScriptBuilderTemplateProcessor.Process()`."
Re-verifying this against current source found `Process()` no longer exists under that name (the
actual method is `Render()`) — but re-verification surfaced a substantially larger problem than a
stale method name: this RFC's own Motivation repro (a `{{ORDERED_COMPONENTS}}` mention inside a
comment forcing Ordered/Hybrid Mode) is not caused by `Validate()` or `Render()` at all. It is caused
by `PSScriptBuilderTemplateModeResolver.IsOrderedModeRequired()`, called at three external call
sites, always on the raw, unmasked template content, and always *before* `Validate()`/`Render()` ever
run:

| Call site | Raw content loaded | Mode detected | Validated | Rendered |
|---|---|---|---|---|
| `Test-PSScriptBuilderTemplate.ps1` | line 131 | line 145 | line 147 | never |
| `PSScriptBuilderBuildOrchestrator.ExecuteBuild()` | line 428 | line 451 | inside Processor constructor (line 319-326) | line 460 (`Render()`) |
| `PSScriptBuilderTemplateAnalyzer.Analyze()` | line 125 | lines 136-140 | line 164 | never |

Confirmed exhaustively (fresh repo-wide search, matching this RFC's own original Phase-1 audit): these
are the only three consumers of raw template content, no hidden fourth exists. Confirmed empirically,
with real execution against the current, unmodified module: `IsOrderedModeRequired` still returns
`$true` for this RFC's own Motivation repro (the currently-unfixed bug), and a live
`Test-PSScriptBuilderTemplate` run against the real `examples\02-classes-and-enums` project fails
exactly as documented — the Validator's own verbose log line ("Validating template (UseOrderedMode:
True)...") shows `Validate()` receiving the *already-wrong* mode as an input parameter. Since
PowerShell passes `[bool]` by value, no masking logic added inside `Validate()`/`Render()`'s own body
could ever retroactively change a value already computed and handed to it as an argument before it
started running — this directly follows from what Step 1 of this very RFC already establishes ("the
mode decision must already exist before a `Processor` instance can be created"), which the original
Decision here overlooked when it named `Validate()`/`Process()` as the masking entry points.

**Corrected Decision: mask once, immediately after each of the three call sites' own `LoadTemplate()`
call returns — before mode detection, before `Validate()`, before a `Processor` is constructed — not
inside `Validate()`/`Render()` at all.** All three call sites already load raw content via the same
underlying `[PSScriptBuilderTemplateFileManager]::LoadTemplate()`; masking is applied by each caller
right after that call returns, not inside `LoadTemplate()` itself (see the `TemplateSize` exception
below for why). Once masked, mode detection, `Validate()`, and `Render()` all operate transparently on
the masked content with no code changes of their own — `PSScriptBuilderTemplateValidator` and
`PSScriptBuilderTemplateProcessor` need no internal masking/unmasking logic whatsoever.

**Exactly one unmask point exists in the whole codebase:** `PSScriptBuilderBuildOrchestrator.ExecuteBuild()`,
immediately after `ProcessTemplate()` returns the rendered `$finalScript`, before it is backed up or
written to the output file. `Test-PSScriptBuilderTemplate` and `PSScriptBuilderTemplateAnalyzer` never
return rendered template text to their own caller, so neither needs an unmask step at all — the masked
sentinel text simply never leaves internal computation in those two paths.

**One correctness exception: `PSScriptBuilderTemplateAnalyzer`'s `TemplateSize` must be computed from
the original, unmasked content, not the masked copy.** `PSScriptBuilderTemplateAnalysisResult.TemplateSize`
("number of characters in the template content") is surfaced directly to users via
`Get-PSScriptBuilderTemplateAnalysis`/`Format-PSScriptBuilderTemplateAnalysis` ("Template Size: N
characters"). The sentinel format `Mask()` substitutes is very unlikely to be the same length as the
`{{{{KEY}}}}` text it replaces, so computing this size *after* masking would silently report a size
that does not match the real file on disk. `PSScriptBuilderTemplateAnalyzer.Analyze()` must capture
`$templateContent.Length` before masking, then mask a separate copy for mode detection/
`ExtractPlaceholders`/`Validate()` to consume. This is also why masking is applied at each of the
three call sites individually, not centralized inside `PSScriptBuilderTemplateFileManager.LoadTemplate()`
itself, even though all three funnel through that one method — `LoadTemplate()` is a generic
file-reading utility with its own, narrower responsibility, and baking Template-escape-specific
masking into it would make every future caller of `LoadTemplate()`, not just these three, silently
receive masked content whether it wants it or not.

**Discoverability: hint at the escape syntax in error messages, since misuse is silent otherwise.**
Masking only recognizes the exact four-brace form — a two-brace mention left unescaped by mistake
(or by an author who simply doesn't know the syntax exists yet) is invisible to `Mask()` and
reproduces the original bug unchanged (see Unresolved Questions). There is no way to infer intent
from two-brace text alone (see "why this isn't a one-line fix," above), so this cannot be fixed
automatically — but the two validation failures most likely to actually be a mistakenly-unescaped
comment (`ValidateNoForbiddenPlaceholders`'s "forbidden placeholder" error, and
`ValidateNoUnknownPlaceholders`'s "unknown placeholder" error) should append a one-line hint, e.g.
"If this was meant as literal text, escape it as `{{{{KEY}}}}`." This does not close the gap, only
makes it faster to discover and fix once hit.

**Deliberately excluded: Release Management's bump-file token replacement
(`PSScriptBuilderBumpReplacementHelper.ApplySimpleReplacements()` / `ApplyPatternReplacements()`).**
An earlier draft of this RFC planned to wrap these methods with the same masking mechanism,
reasoning that a token name (e.g. `VERSION`) both escaped in a comment and registered as a bump
token for that same file would otherwise get corrupted by the bump step before the build-side fix
ever sees it. Reconsidered after tracing through what `{{{{VERSION}}}}` actually does in a
bump-managed file **today, unmodified**: `ApplySimpleReplacements`'s `.Contains("{{VERSION}}")` /
`.Replace(...)` finds the two-brace token *embedded inside* the four-brace sequence (at a fixed
offset, since bracket characters are identical) and replaces just that, producing `{{1.3.0}}` —
the substituted value wrapped in the two *outer*, untouched literal braces. This is not an accident
to fix: it is how a user who wants a version number to render as `{{1.3.0}}` (literal decorative
braces around a substituted value) would achieve that today, and it already works. Masking this
method (or "fixing" its matching to be brace-boundary-aware) would silently break that
currently-functioning, plausibly-relied-upon behavior for every existing bump-managed project, in
exchange for protecting a narrow, coincidental case (a bump token name that happens to also be a
key someone wants to template-escape in the same file). The two conventions — this RFC's template
escape syntax, and Release Management's existing decorative-brace substitution — are genuinely,
irreducibly ambiguous for the identical `{{{{KEY}}}}` text; no regex or masking rule can tell them
apart, because the difference is the *author's intent*, not anything present in the text itself.
Release Management is therefore explicitly out of scope for this RFC and its existing behavior is
left completely unchanged — see Scope and Unresolved Questions for the resulting known limitation.

**Illustrative example of the resulting ambiguity:** `build\Templates\PSScriptBuilder.psm1.template`
is, in this very project, both a real template *and* bump-managed with the `VERSION` token (see
`build\Release\psscriptbuilder.bumpconfig.json`). Suppose its author writes, intending a literal
documentation comment for future readers:

```powershell
# Note: this project uses Release Management tokens like {{{{VERSION}}}} in templates.
# At build time, this is automatically replaced with the real version number.
```

Processing order, traced exactly:

1. **Release Management runs first** (before the build ever sees the template). It searches for
   `{{VERSION}}`, finds it *embedded inside* `{{{{VERSION}}}}`, and replaces just that occurrence:
   ```powershell
   # Note: this project uses Release Management tokens like {{1.3.0}} in templates.
   ```
   The escape is already gone — consumed by Release Management before the escape mechanism this
   RFC introduces ever runs.
2. **The Template Processor runs later** and sees only `{{1.3.0}}` (two braces) — the four-brace
   marker no longer exists to protect anything. `"1.3.0"` is not a known placeholder key, so
   validation most likely rejects it as an unknown placeholder, failing the build over what was
   meant as an inert comment.

The result matches neither the author's actual intent (literal `{{VERSION}}` text in the comment)
nor a deliberate use of Release Management's decorative-brace convention (which would have
correctly produced `{{1.3.0}}`, had that been intended) — it is simply whichever convention's
processing happens to run first, winning by accident of pipeline order rather than by resolving
the author's intent. This is precisely the same source text a different author, wanting the
version number to render as `{{1.3.0}}` on purpose, would also have written — the two intents are
indistinguishable from the text alone, which is why this is documented as a known limitation rather
than something this RFC attempts to resolve.

**Edge cases:**

- An escaped sequence's inner text is never validated as a real key (no whitespace check, no
  "must match a registered collector" check) — it is masked out before any such check runs, so
  arbitrary prose is allowed inside `{{{{...}}}}`.
- `{{{{}}}}` (empty content) does not match `[^{}]+` (requires at least one character) and falls
  through to normal 2-brace handling, most likely producing an "unknown placeholder" error —
  acceptable for what is almost certainly a typo.
- **Five or more consecutive braces on either side (e.g. `{{{{{KEY}}}}}`, `{{{{{{KEY}}}}}}`) —
  a different failure mode than the empty case above, verified separately.** The simpler pattern
  `\{\{\{\{([^}]+)\}\}\}\}` would *partially* match a malformed run like six braces — real regex
  execution confirmed it captures `{{KEY` (two extra braces baked into the "key") from
  `{{{{{{KEY}}}}}}`, leaving two unconsumed trailing braces as literal text. Masking that malformed
  capture and later un-escaping it would produce corrupted brace structure in the final output —
  not a clean rejection like the empty case, but a genuine parse error silently propagated forward.
  The boundary-aware pattern this RFC uses instead (see `Mask()`, above) does not match *any*
  brace run other than exactly four on each side — verified with real regex execution that 5, 6,
  and 8-brace inputs, and an asymmetric 5-open/4-close input, are all correctly rejected outright.
  A rejected sequence falls through to the existing generic `ExtractPlaceholders()` two-brace regex
  the same way the empty case does — verified this produces a clean, if oddly-worded, "unknown
  placeholder" validation error (the generic regex captures `{{{{KEY` from the same six-brace
  input) rather than corrupted output. Found 2026-09-01 while double-checking the empty-braces
  edge case actually covered every malformed-brace-count scenario — it did not.
- `PSScriptBuilderTemplateGenerator` (`New-PSScriptBuilderTemplate`) needs no changes — confirmed
  it only ever writes new template content, never parses or merges with existing content, so it
  never encounters escaped sequences to interpret.

## Rationale and Alternatives

**Candidate considered and rejected: backslash prefix (`\{{KEY}}`), matching Handlebars/Mustache.**
Initially preferred for two real advantages — visually obvious at a glance (no brace-counting),
and simpler to implement (a single lookbehind check instead of parsing nested brace counts).
Rejected after tracing through a concrete counter-example: PSScriptBuilder templates are
Windows/PowerShell-flavored and routinely contain backslash path separators immediately adjacent
to real placeholders (e.g. `$logPath = "C:\Logs\{{PROJECT_NAME}}.log"`). A single backslash
immediately before `{{` is exactly what that ordinary, intended usage looks like — the escape
convention would silently misfire on real, non-escaped placeholders in a very common pattern for
this domain, requiring `\\{{PROJECT_NAME}}` (doubled backslash) just to get an ordinary working
placeholder.

The general principle: an escape delimiter should be chosen for how rare it is in the *target
domain's* real content, not for how well-known the convention is in the abstract — backslash is
a poor fit for a domain built on Windows paths, even though it's well-established elsewhere
(web/JSON/HTML templating, where backslashes are rare). Quadruple brace has effectively zero
collision risk with any realistic existing template content (verified: no `.template` file
anywhere in the repository contains a quadruple-brace sequence today), reuses the same delimiter
family already central to the syntax, and mirrors a convention PSScriptBuilder's own code already
relies on internally: .NET composite formatting escapes a literal brace by doubling it
(`"{{{{{0}}}}}" -f $Key` produces the literal string `{{Key}}`).

## Scope

**In scope:** the escape syntax itself; consolidating detection logic (Step 1); masking applied at
the three call sites that load raw template content (Step 2), before mode detection, validation, or
rendering ever runs.

**Out of scope:**

- **Release Management's bump-file token replacement, entirely.** See Step 2's "Deliberately
  excluded" note for why: its existing `{{{{KEY}}}}` behavior (substitute the embedded token,
  preserve the outer literal braces) is a legitimate, currently-functioning convention this RFC
  must not disturb, and it is irreducibly ambiguous with the template escape meaning for identical
  text — see Unresolved Questions for the resulting known limitation.
- Fixing RFC 0002, RFC 0003, and RFC 0004's bugs — distinct root causes, tracked independently.
  This RFC's masking work touches the same files as those fixes (see Relationship to Other RFCs)
  but does not depend on their internal implementation, only on landing after them.
- Surfacing escaped-occurrence details in `Get-PSScriptBuilderTemplateAnalysis`'s result object —
  deferred as a first-version simplification (see Unresolved Questions).
- A similar "value collision" in the bump-file processor, where one token's *value* might
  literally contain another token's placeholder text. **Correction (2026-09-02): this RFC's own
  escape mechanism does not need to address it, but the premise it was originally dismissed on was
  wrong** — not all bump-file token values are machine-generated; `GIT_BRANCH`/`GIT_TAG` are
  human-chosen and git permits `{`/`}` characters in ref names (verified:
  `git check-ref-format --branch "feature/{{VERSION}}"` succeeds). This is real and reproducible,
  but it is a *sequential-processing* bug in `PSScriptBuilderBumpReplacementHelper` itself (the
  same anti-pattern RFC 0003 fixes, in an independent implementation) — tracked as its own RFC
  0007, not as part of this RFC's escape mechanism, which is unrelated to it.
- Ordered Mode's pre-existing whitespace/blank-line formatting difference from Free Mode
  (Ordered Mode has never had Free Mode's `CalculateConsumedLength()` blank-line-avoidance logic)
  — a real, but purely cosmetic and entirely unrelated difference, noticed while investigating RFC
  0003. Not addressed by this RFC; fixing it would change output formatting for every existing
  Ordered/Hybrid Mode build, a much broader change than anything requested.

## Relationship to Other RFCs

RFC 0002, RFC 0003, and RFC 0004 each fix a distinct, pre-existing bug inside
`PSScriptBuilderTemplateProcessor.ps1`/`PSScriptBuilderTemplateValidator.ps1`. This RFC's masking
mechanism, once corrected to apply at the three external call sites rather than inside those two
classes (see Detailed Design), no longer touches either file at all — it only needs those three
fixes to have landed first because it is sequenced after them for implementation-order clarity, not
because of any remaining file-level overlap. See `internal/rfc/IMPLEMENTATION-PLAN.md` for the
actual build order across all four RFCs.

## Test Plan

- Unit tests for `PSScriptBuilderTemplateEscapeHelper`: mixed real+escaped input masks
  correctly; the restore map round-trips back to the exact original literal text.
- Unit tests for the boundary-aware `Mask()` pattern specifically: five, six, eight, and an
  asymmetric five-open/four-close brace sequence must all be rejected (not matched, not masked);
  a rejected sequence must still surface as a clean "unknown placeholder" validation error, not
  corrupted output.
- The already-reproduced comment-escape scenario (see Motivation) must pass validation and build
  successfully, with mode detection unaffected by the comment.
- A real build test asserting the output file contains the literal two-brace text at the escaped
  position — not the real collector's substituted content, and not the raw four-brace template
  text either.
- A non-regression test confirming Release Management's existing behavior is completely unaffected:
  a bump-managed file containing `{{{{VERSION}}}}` must still produce `{{1.3.0}}`-style output
  (substituted value, literal outer braces preserved) exactly as it does today.
- A test confirming a mistakenly-unescaped (two-brace) comment mention still fails validation as
  before (no automatic fix — see Unresolved Questions), but that `ValidateNoForbiddenPlaceholders`'s
  and `ValidateNoUnknownPlaceholders`'s error messages now include the escape-syntax hint.

## Unresolved Questions

- **Known, accepted limitation, not resolved by this RFC:** a mention left unescaped (two braces
  instead of four) — by mistake, or because the author doesn't yet know the escape syntax exists —
  is invisible to `Mask()` and reproduces the original bug unchanged; there is no way to infer
  intent from two-brace text alone (see "why this isn't a one-line fix," Detailed Design). Mitigated
  only by discoverability (the escape-syntax hint added to the two relevant error messages, see
  Detailed Design and Test Plan) and documentation, not fixed automatically.
- Should escaped occurrences be surfaced anywhere in `Get-PSScriptBuilderTemplateAnalysis`'s
  result object (e.g. an `EscapedPlaceholders` count), or stay fully invisible? Deliberately
  deferred as a first-version simplification, not decided against permanently.
- **Known, accepted limitation, not resolved by this RFC:** in a file that is both a PSScriptBuilder
  template *and* Release-Management bump-managed, if a bump token name (e.g. `VERSION`) coincides
  with a key someone wants to template-escape in that same file, the outcome is decided by Release
  Management's bump substitution (since it runs before the build ever sees the template) — not by
  this RFC's escape syntax. The two conventions cannot be distinguished from identical
  `{{{{KEY}}}}` text; this is a genuine naming collision, not a bug. See Step 2's illustrative
  example (Detailed Design) for a worked-through case. No mitigation beyond documentation (choose
  non-colliding names, or avoid needing to template-escape a live bump token's exact name in a
  bump-managed file) is planned.

## Revision Log

- 2026-09-05 — Implemented (Step 2). `PSScriptBuilderTemplateEscapeHelper` (renamed from
  `PSScriptBuilderPlaceholderEscapeHelper`, see the 2026-09-05 architecture-correction entry above)
  added and wired into all three call sites per the corrected Decision: masked immediately after
  `LoadTemplate()` in `Test-PSScriptBuilderTemplate.ps1`, `PSScriptBuilderTemplateAnalyzer.Analyze()`,
  and `PSScriptBuilderBuildOrchestrator.ExecuteBuild()`; unmasked once, only in `ExecuteBuild()`,
  after rendering. Verified end-to-end with a real build: the Motivation repro (a comment mentioning
  `{{ORDERED_COMPONENTS}}`, now escaped as `{{{{ORDERED_COMPONENTS}}}}`) builds correctly, with
  literal, un-escaped text in the final output and zero leftover NUL sentinel bytes. Added the
  discoverability hint to `ValidateNoForbiddenPlaceholders`/`ValidateNoUnknownPlaceholders`. Full
  Test Plan now covered: unit tests for the Helper class (including the deliberate
  no-plausibility-check behavior on escaped content), the boundary-aware pattern's edge cases, the
  Motivation repro (validation and full build), the discoverability hint, and a non-regression test
  confirming Release Management's decorative-brace `{{{{VERSION}}}}` -> `{{1.3.0}}` behavior is
  untouched. Full suite: 1865 passed, 7 failed (RFC 0007/0008/0009 only, all pre-existing and
  unrelated).
- 2026-09-05 — Major correction, found during a full pre-implementation re-verification (real
  execution against the current module, not just re-reading code): the original Decision's masking
  entry points (`Validate()`/`Process()`) cannot actually fix this RFC's own Motivation repro, because
  mode detection (`PSScriptBuilderTemplateModeResolver.IsOrderedModeRequired`) runs on raw,
  unmasked content at three external call sites, always *before* `Validate()`/`Render()` (`Process()`
  no longer exists under that name). Confirmed exhaustively (fresh call-site audit) and empirically
  (real regex execution, a live end-to-end `Test-PSScriptBuilderTemplate` repro against
  `examples\02-classes-and-enums`) — see Detailed Design for the full trace. Corrected Decision:
  mask once, at each of the three call sites, immediately after `LoadTemplate()` returns; unmask
  once, only in `PSScriptBuilderBuildOrchestrator.ExecuteBuild()` after rendering. Found one
  additional correctness exception during this same pass: `PSScriptBuilderTemplateAnalyzer`'s
  user-facing `TemplateSize` must be computed from the original, unmasked content. Renamed the new
  class from `PSScriptBuilderPlaceholderEscapeHelper` to `PSScriptBuilderTemplateEscapeHelper` after
  discussion of whether the mechanism might extend to Release Management — decided against a
  Release-Management-neutral name for now (their existing decorative-brace convention is
  semantically different, per this RFC's own established reasoning, and would need its own class if
  ever pursued), but did drop "Placeholder" in favor of "Template" for domain clarity. Updated Scope
  and Relationship to Other RFCs to match: masking no longer touches
  `PSScriptBuilderTemplateProcessor.ps1`/`PSScriptBuilderTemplateValidator.ps1` at all.
- 2026-09-03 — Added a discoverability note to Step 2: an unescaped (two-brace) mention still
  reproduces the original bug unchanged (cannot be fixed automatically, no way to infer intent from
  the text alone), but `ValidateNoForbiddenPlaceholders`'s and `ValidateNoUnknownPlaceholders`'s
  error messages should hint at the escape syntax so the fix is easy to find once hit. Logged as a
  named limitation in Unresolved Questions, with a corresponding Test Plan bullet.
- 2026-09-03 — Step 1 (`PSScriptBuilderTemplateModeResolver` consolidation) implemented and pushed:
  new class added, all three duplicated call sites (`PSScriptBuilderTemplateAnalyzer`,
  `Test-PSScriptBuilderTemplate.ps1`, `PSScriptBuilderBuildOrchestrator.ps1`) migrated to it.
  Verified no behavior change via real test runs after each step (Unit: identical 1747/22
  throughout; Integration: 180/0). Step 2 (escape masking mechanism) remains unimplemented — the
  original bug this RFC exists to fix (e.g. a `{{ORDERED_COMPONENTS}}` mention inside a comment
  incorrectly forcing Ordered/Hybrid Mode) is confirmed to still reproduce unchanged. See
  `internal/rfc/IMPLEMENTATION-PLAN.md` for phase-level progress tracking.
- 2026-09-02 — Corrected the "value collision ruled out as impractical" reasoning in Scope: the
  premise (all bump-file token values are machine-generated) is wrong for `GIT_BRANCH`/`GIT_TAG`,
  which are human-chosen and can legally contain `{{...}}`-shaped text — verified with real
  `git check-ref-format`. Not a correction to this RFC's own decisions (its escape mechanism was
  never meant to address this); the real bug is a separate, independent sequential-processing flaw
  in `PSScriptBuilderBumpReplacementHelper`, tracked as new RFC 0007.
- 2026-09-01 — Found, during a full re-analysis of the template subsystem before implementation
  begins, that the originally-planned `Mask()` pattern (`\{\{\{\{([^}]+)\}\}\}\}`) partially
  matches malformed brace runs of five or more, capturing a corrupted "key" instead of cleanly
  failing — verified with real regex execution, and confirmed distinct from the already-documented
  empty-braces case (which fails to match at all). Replaced with a boundary-aware pattern
  (`(?<!\{)\{\{\{\{([^{}]+)\}\}\}\}(?!\})`) that rejects any brace count other than exactly four on
  each side outright; verified this changes nothing for every already-correct case and that a
  rejected malformed sequence now falls through to a clean "unknown placeholder" validation error
  instead of corrupted output.
- 2026-09-01 — Added a fully worked-through illustrative example of the known limitation, grounded
  in this project's own actual dual-role file (`PSScriptBuilder.psm1.template`) and bump
  configuration, tracing the exact processing order and resulting output step by step.
- 2026-09-01 — Removed Release Management from this RFC's scope entirely. Tracing through what
  `{{{{VERSION}}}}` actually produces in a bump-managed file today (`{{1.3.0}}` — substituted value
  wrapped in preserved literal outer braces) showed this is a legitimate, currently-functioning
  convention for authors who want decorative braces around a substituted value, not a bug — and it
  is irreducibly ambiguous with this RFC's escape meaning for identical text, since the difference
  is the author's intent, not anything in the text itself. Masking or "fixing" Release Management's
  matching would have silently broken that existing behavior to protect a narrow, coincidental
  naming collision instead. `PSScriptBuilderPlaceholderEscapeHelper` moved from `Common\` to
  `Template\` accordingly (its only remaining consumers). Documented the resulting known limitation
  in Unresolved Questions rather than attempting to resolve an intent-level ambiguity mechanically.
- 2026-09-01 — Renamed the Step 1 consolidation class from `PSScriptBuilderTemplateEngine` to
  `PSScriptBuilderTemplateModeResolver` after review: "Engine" is reserved in this codebase for
  `PSScriptBuilderAstEngine`, a much larger, broadly-depended-on class, and a three-method utility
  doesn't warrant that name. Also confirmed the class must not be folded into
  `PSScriptBuilderTemplateProcessor`: `Test-PSScriptBuilderTemplate.ps1` has no existing dependency
  on `Processor`, and `useOrderedMode` is a required `Processor` constructor parameter, so the mode
  decision must exist before a `Processor` instance can be created. No behavior or scope changed —
  naming and placement only.
- 2026-08-31 — Rewritten as a self-contained document: removed the master phase/sequencing plan
  that had accreted here for RFC 0002, 0003, and 0004's fixes (moved to
  `internal/rfc/IMPLEMENTATION-PLAN.md`, the single place build order now lives), so this RFC no
  longer needs editing every time another RFC's sequencing changes. No decisions changed — only
  the document's scope. Full prior text (five phase-by-phase drafts) remains in this file's git
  history.
- 2026-08-30 — Pre-implementation review corrected two mischaracterizations found by re-reading
  the actual source instead of relying on earlier notes: `RenderOrderedMode`'s combined-placeholder
  step is not collision-safe by construction (see RFC 0003), and the Validator's affected-method
  count is eight, not seven.
- 2026-08-29 — Initial finding, problem write-up, and design (escape syntax, detection
  consolidation, masking mechanism), including the backslash-vs-quadruple-brace decision.
