# RFC 0005: Centralized Template Tokenizer

- **Status:** Draft — idea proposed, not yet designed in detail
- **Type:** Refactor
- **Created:** 2026-08-30
- **Branch:** none yet — deliberately not tied to `refactor/template-engine-consolidation`

## Summary

Mode-detection (RFC 0001), all eight validation rules in `PSScriptBuilderTemplateValidator`
(RFC 0004's Motivation), and both of `PSScriptBuilderTemplateProcessor`'s rendering modes each
independently re-derive placeholder facts from the raw template text, using their own matching
call and — as RFC 0004 found — their own, inconsistently-chosen comparison mode. This RFC proposes
a single, centralized tokenizer: parse a template's `{{...}}` occurrences exactly once into a
canonical structure, and have mode-detection, every validation rule, and both rendering modes
consume that shared result instead of each re-scanning the raw text on their own.

## Motivation

Raised 2026-08-30 during RFC 0003's design review, originally scoped narrower ("should
`RenderFreeMode` and `RenderOrderedMode` collapse into one rendering mechanism?"). Expanded
2026-09-01 after comparing PSScriptBuilder's design against how established templating engines
(Mustache/Handlebars, Jinja2, Go's `text/template`, .NET T4, Liquid) solve the same problem: they
all tokenize a template exactly once into a fixed list of literal/placeholder segments, and every
downstream concern — validation, evaluation, rendering — operates on that one shared, already-parsed
result. None of them re-scan the raw source once for validation and again, separately, for
rendering.

PSScriptBuilder does not have that shared step. Instead, three independent groups of consumers each
re-derive placeholder facts directly from the raw string:

- **Mode-detection** (RFC 0001) — duplicated verbatim across three call sites
  (`Test-PSScriptBuilderTemplate.ps1`, `PSScriptBuilderBuildOrchestrator.ps1`,
  `PSScriptBuilderTemplateAnalyzer.ps1`), two of them via raw `-match`, one via `ExtractPlaceholders()`
  + `-contains` — two different implementations of the same idea, verified to actually disagree on
  a four-brace escape sequence.
- **Validation** — `PSScriptBuilderTemplateValidator`'s eight rules each independently call
  `-match`, `IndexOf`, or `Regex.Matches` against the raw template, each choosing its own comparison
  mode; RFC 0004 found this choice is inconsistent even *within* the Validator (`ValidateNoDuplicatePlaceholders`
  is case-sensitive while every sibling rule is case-insensitive).
- **Rendering** — `DiscoverReplacements` (Free Mode) performs its own `IndexOf` per collector;
  `RenderOrderedMode`'s (pre-RFC-0003) three `Replace*` methods each performed their own matching
  against a *mutating* intermediate string, which is what made RFC 0003's injection bug possible in
  the first place.

The pattern connecting RFC 0001, RFC 0003, and RFC 0004 is the same in all three cases: there is no
single place that authoritatively says "these are the placeholders in this template, at these
positions, matched this way" — every consumer decides that for itself, independently, and the three
decisions can (and, per RFC 0004, already do) drift out of sync. A centralized tokenizer removes the
opportunity for that drift by construction, rather than requiring each new consumer to remember to
match the other two.

## Detailed Design

### Sketch of the unified approach — revised 2026-09-17

Deliberately *not* a Mustache/Jinja2-style full token stream alternating literal and placeholder
tokens. Those engines need that shape because they parse nested constructs (loops, conditionals,
blocks); PSScriptBuilder's template grammar is flat (`{{KEY}}`, no nesting), and the existing
`AssembleFromReplacements` mechanism (RFC 0003) already reconstructs output from
`(Start, Length, Replacement)` triples without needing explicit literal-text tokens — importing a
richer token-stream shape here would be borrowing complexity from a different problem, not avoiding
reinvention.

A dedicated class, not `PSCustomObject`, matching every other structured value already in this
codebase (`PSScriptBuilderClassData`, `PSScriptBuilderSourceLocation`, `PSScriptBuilderBuildResult`,
…) — none of them use `PSCustomObject` for a reused, multiply-consumed structure, including for the
`.GetType().Name` check pattern `internal/test-strategy.md` already mandates for tests:

```powershell
class PSScriptBuilderTemplateToken {
    [string] $Key      # Trim()med - the logical lookup key
    [string] $RawKey   # exactly as captured, untrimmed
    [int]    $Start    # zero-based start index of the full {{...}} token in $templateContent
    [int]    $Length   # character length of the full {{...}} token
}

class PSScriptBuilderTemplateTokenizer {
    hidden static [string] $Pattern = '\{\{([^}]+)\}\}'
    # Centralizes a pattern that, per the 2026-09-03 Revision Log entry, already exists identically
    # in at least three places (`ExtractPlaceholders()`, `ValidateNoWhitespaceInPlaceholders`,
    # `ValidateNoUnknownPlaceholders`).

    static [PSScriptBuilderTemplateToken[]] Tokenize([string] $maskedTemplateContent)
    # One entry per {{...}}-shaped occurrence, via a single Regex.Matches() pass - .NET's regex
    # engine already returns matches in document order, so entries are returned in ascending
    # Start order as an explicit, documented contract (existing order-sensitive consumers like
    # ValidateUsingPlaceholderOrder/ValidateEnumPlaceholderOrder rely on this, today incidentally,
    # going forward by design). Case-insensitive Key comparison (OrdinalIgnoreCase, per RFC 0004)
    # used by every consumer instead of each one choosing its own.
    #
    # Expects already-masked content: the caller runs PSScriptBuilderTemplateEscapeHelper::Mask()
    # first (as every current consumer of {{...}}-matching already must, per that class's own
    # documented contract), then Tokenize()s the masked result, then only Unmask()s the final
    # rendered output at the very end. A masked `{{{{KEY}}}}` escape becomes a NUL-delimited
    # sentinel containing no `{{` at all, so it never produces a token in the first place -
    # escaping is handled entirely by the existing Mask/Unmask layer and is out of this class's
    # scope by construction, the same "right layer for the concern" reasoning already applied to
    # `Using`'s first-found-wins semantics below.
}
```

1. **Tokenize once, at the top of every entry point** (`Test-PSScriptBuilderTemplate`,
   `PSScriptBuilderBuildOrchestrator`, `PSScriptBuilderTemplateAnalyzer`) — replaces RFC 0001's
   `PSScriptBuilderTemplateModeResolver` mode-detection with a query against the tokenized result
   (e.g. "does any entry's `Key` case-insensitively equal the ordered-components key?") instead of
   a fresh raw-text match.
2. **Validation rules consume the same tokenized list.** Each of the eight `PSScriptBuilderTemplateValidator`
   rules currently re-derives its own placeholder facts (existence, order, duplicates, whitespace,
   unknown names) from raw text; each would instead operate on the shared `Tokenize()` result,
   removing eight independent opportunities for a comparison-mode or matching-logic inconsistency.
3. **Rendering only gets the position half from `Tokenize()`; content resolution is untouched.**
   Both `RenderFreeMode` and (post-RFC-0003) `RenderOrderedMode` already compute
   `(Start, Length, Replacement)` entries from the original template before assembling —
   `Tokenize()` would replace only the position-finding half (today's per-collector `IndexOf`
   calls in `DiscoverReplacements`/`DiscoverFileReplacements`/`DiscoverUsingReplacement`/
   `DiscoverOrderedComponentsReplacement`) with a query against the shared token list.
   Content resolution stays exactly as it is today, unchanged, because it isn't one uniform
   `Key → Replacement` mapping — verified against the actual code, there are three distinct
   strategies in current use, and the tokenizer is not meant to unify them:
   - **1:1** (Enum/Class/Function in Free Mode, File collectors in both modes) — one collector,
     one token, `ContentProcessor.BuildCollectorContent()` / `GetFileContent()`. The common case.
   - **Many-to-one, first-found-wins** (Using) — see "Known open design difficulties" below.
   - **Synthetic key, not tied to any collector** (`ORDERED_COMPONENTS`) — its own parameter, not
     a `CollectionKey`; content is built by concatenating the full ordered-components list
     (`DiscoverOrderedComponentsReplacement`).

   A future implementer should not read this RFC as proposing to unify these three into one
   mechanism — only the "where is the placeholder" half is centralized; "what replaces it" keeps
   whatever resolution strategy it already has today, per token kind.

### Known open design difficulties — resolved 2026-09-17

Both difficulties below turned out to dissolve once the tokenizer's scope was kept narrow:
report *occurrence facts* only (where a `{{...}}`-shaped span is, and its raw key text), and never
try to also resolve *what replaces it* — that stays entirely the renderer's job, consuming the
facts. Uses the `PSScriptBuilderTemplateToken`/`Tokenize()` design in the revised sketch above.

- **`Using`'s "first found wins" semantics — resolved.** Verified against the actual
  implementation (`PSScriptBuilderTemplateProcessor.DiscoverUsingReplacement`): all registered
  `UsingCollector`s' statements are consolidated into *one* string first, and that one string is
  then assigned to whichever *collector* (not template position) is found first when iterating
  `$usingCollectors` in registration order. This was never actually a tokenizer concern — the
  tokenizer only needs to report that `{{USING}}` occurs at some position and `{{CustomUsing}}` at
  another (or not at all); "which one wins" is a renderer-side query over that plain fact list:
  `$usingCollectors | ForEach-Object { $tokens | Where-Object Key -eq $_.CollectionKey } |
  Select-Object -First 1`. Modeling "first found wins" as a special tokenizer case would have been
  solving it at the wrong layer. No special-casing needed.

- **Mapping eight distinct validation rules onto one shared structure — resolved.** Re-examined all
  eight rules that actually scan `$templateContent` in `PSScriptBuilderTemplateValidator` (the other
  three — the Release-Management-token-collision checks — never touch template text and are out of
  this RFC's scope regardless). Every one reduces to a simple query over the revised tokenizer
  output above, none needing a bespoke shape:

  | Rule | Query over `Tokenize()` output |
  |---|---|
  | `ValidateNoWhitespaceInPlaceholders` | entries where `Key -ne RawKey` |
  | `ValidateOrderedPlaceholderExists` / `ValidateCollectorPlaceholdersExist` | any entry with matching `Key` |
  | `ValidateNoForbiddenPlaceholders` | entries whose `Key` matches a forbidden collector's `CollectionKey` |
  | `ValidateUsingPlaceholderOrder` | `Min(Start)` among Using-`Key` entries vs. `Min(Start)` among all others |
  | `ValidateEnumPlaceholderOrder` | `Max(Start)` among Enum-`Key` entries vs. `Min(Start)` among Class/Function entries |
  | `ValidateNoDuplicatePlaceholders` | `Group-Object Key \| Where Count -gt 1` |
  | `ValidateNoUnknownPlaceholders` | entries whose `Key` is not in the known-keys set |

  The `RawKey`/`Key` split (raw untrimmed capture vs. trimmed logical key) is what makes the
  whitespace rule fit the same structure as the rest — it was the one rule that looked like it
  needed something qualitatively different, and it doesn't.

## Rationale and Alternatives

**Considered folding this directly into RFC 0003's fix.** Rejected — risk-disproportionate: it
would require touching the already-correct, unmodified `RenderFreeMode`, and the `Using` design
wrinkle wasn't resolved. Bundling an unfinished design into an active bug-fix branch would have been
premature.

**Considered (2026-09-01): building this tokenizer directly instead of implementing RFC 0001-0004.**
Rejected, for reasons that apply even more strongly now that this RFC's scope has grown from "unify
two render methods" to "centralize mode-detection, validation, and rendering":

- The design is not finished — two open difficulties above, one of them new and non-trivial
  (mapping eight structurally different validation rules onto one shared structure).
- RFC 0001-0004 are fully designed, verified against real repros, and already backed by nine
  committed regression tests — attempting the larger, undesigned rewrite instead would abandon that
  completed verification work for a foundation that doesn't exist yet.
- None of RFC 0001-0004's work is wasted if this RFC is picked up later: the mode-resolver (RFC
  0001) is already a single consolidated call site a tokenizer would only need to redirect, not
  rebuild; RFC 0003's `Discover*` methods already produce the exact `(Start, Length, Replacement)`
  shape this RFC's tokenizer output would feed into; RFC 0004's case-insensitive comparison decision
  is exactly what `Tokenize()` would need to bake in permanently. Each is a real stepping stone, not
  a detour.
- General principle: this is the Strangler Fig pattern (Fowler) applied to internal architecture —
  replace a legacy mechanism behind stable interfaces, incrementally, rather than a big-bang rewrite
  of the entire template-processing subsystem in one step. RFC 0002 and RFC 0004 are also
  already-shipping, silently-corrupting bugs; deferring their fix behind an undesigned, larger
  rewrite with no completion date leaves real users exposed for an indeterminate time.

## Scope

Not yet scoped as an implementation plan — this RFC exists to record the idea, the expanded
architectural picture, and the reasoning for deferring it. The two structural design difficulties
that were blocking scoping are resolved as of 2026-09-17 (see Detailed Design); what remains before
this could become an actual implementation plan is a branch/sequencing decision and a Test Plan, not
further design work. Once picked up, in-scope would cover mode-detection, all eight Validator rules,
and both render modes (Simple/Placeholder Mode `{{TOKEN}}` matching in Release Management is a
plausible later extension, Regex Mode is explicitly out of reach — see Unresolved Questions);
explicitly still deferred behind RFC 0001-0004, all four of which are now fully implemented and
shipped.

## Relationship to Other RFCs

- **RFC 0001** (template placeholder escaping / mode-resolver consolidation) — the mode-resolver
  this RFC introduces is exactly the single call site this tokenizer would redirect to consume
  `Tokenize()` output instead of its own raw-text match; not otherwise blocked by this RFC.
- **RFC 0002** (ordered-components-key collision) — a side benefit once this RFC lands: a key
  collision becomes directly detectable on the tokenized list (two collectors claiming overlapping
  keys) rather than needing its own dedicated validation check; not a reason to delay RFC 0002.
- **RFC 0003** (Ordered/Hybrid Mode template injection) — this RFC's tokenizer output feeds directly
  into `AssembleFromReplacements`, the same generic assembly mechanism RFC 0003 already established
  for both modes; this RFC builds on that vocabulary rather than replacing it.
- **RFC 0004** (placeholder case-sensitivity mismatch) — the case-insensitive comparison mode RFC
  0004 establishes is exactly the single comparison mode `Tokenize()` would bake in permanently,
  removing the opportunity for the inconsistency RFC 0004 found to recur.

All four proceed independently of this RFC and are not blocked by it.

## Test Plan

Not yet applicable — no implementation plan exists yet.

## Unresolved Questions

- Should this RFC's scope extend to Release Management's own `{{TOKEN}}`/`{REGEX_TOKEN}` matching
  in `PSScriptBuilderBumpReplacementHelper`, not just the Template system? **Partially answered
  2026-09-17:** RFC 0007/0008/0009 have since landed (all Implemented), and
  `PSScriptBuilderBumpReplacementHelper` now has its own `#region Helper Methods: Discover/Assemble`
  with case-insensitive token-name matching (RFC 0008) — the same discover/assemble,
  case-insensitive shape this RFC's tokenizer already targets. But the file also confirms the
  suspected mismatch: Regex Mode patterns like `ModuleVersion\s*=\s*'({REGEX_VERSION})'` are
  arbitrary regexes, not `{{...}}`-shaped occurrences, so `Tokenize()` structurally cannot represent
  them. Conclusion: if this RFC is ever picked up, Simple/Placeholder Mode's `{{TOKEN}}` matching
  could plausibly share the tokenizer; Regex Mode cannot and must stay out of scope. Still not
  decided *whether* to extend to Release Management at all, only *how far* it could reach if so.
- Should this get its own dedicated branch once picked up, separate from any other in-flight work,
  given its exploratory nature?
- Is there a strong enough case (e.g., another future collector type or mode addition) to prioritize
  this soon, or should it remain a "someday" architectural note?

## Revision Log

- 2026-09-18 — Clarified that "rendering builds its content map from the same tokenized list"
  (Detailed Design, point 3) undersold how little of rendering this RFC actually touches. Verified
  against `PSScriptBuilderTemplateProcessor`: there are three distinct, already-existing
  replacement-resolution strategies (plain 1:1 per collector; Using's many-to-one first-found-wins;
  `ORDERED_COMPONENTS`' synthetic, non-collector key), none of which the tokenizer resolves or
  needs to unify — it only replaces the position-finding half. Written down explicitly so a future
  implementer doesn't mistake this RFC for proposing a unified content-resolution mechanism. Also
  decided (separately, in discussion) that this RFC stays a Draft "someday" note and is explicitly
  out of scope for the 1.3.0 release — no functional benefit, touches the core template
  validation/rendering path (1598 lines, 121 tests across the four files involved), and would
  reopen verification work just completed for 1.3.0 for zero user-facing gain.
- 2026-09-17 — Turned the sketch into a concrete class design: `PSScriptBuilderTemplateToken`
  (dedicated class, not `PSCustomObject`, matching every other structured value in the codebase)
  plus a `PSScriptBuilderTemplateTokenizer` with a centralized, `hidden static` regex pattern and a
  documented ascending-`Start`-order output contract. Deliberately not a Mustache/Jinja2-style
  literal+placeholder token stream — this project's flat, non-nested grammar and the existing
  RFC 0003 assembly mechanism don't need one. Clarified the caller contract with
  `PSScriptBuilderTemplateEscapeHelper`: `Mask()` before `Tokenize()`, `Unmask()` only on the final
  rendered output — escaping was already a solved, orthogonal concern one layer up, so the
  tokenizer needs no escape-handling of its own, the same layering already applied to `Using`'s
  first-found-wins semantics.
- 2026-09-17 — Resolved both "Known open design difficulties" against the current codebase (see
  Detailed Design): `Using`'s "first found wins" behavior turned out not to be a tokenizer concern
  at all once the tokenizer's scope was kept to occurrence facts only, not resolved replacement
  content; the eight Validator rules all reduce to simple queries (existence/count/order) over one
  `{Key, RawKey, Start, Length}` structure, with the `RawKey`/`Key` split resolving the
  whitespace-detection rule that looked like the odd one out. Also partially answered the Release
  Management scope question now that RFC 0007/0008/0009 have landed: Simple/Placeholder Mode could
  plausibly share this tokenizer, Regex Mode structurally cannot. Status remains Draft — these were
  the two structural blockers to scoping, not the whole of scoping itself; no branch decision, no
  Test Plan, and the prioritization question are all still open.
- 2026-09-05 — Raised, in discussion outside any active implementation, whether this RFC's scope
  should extend to Release Management's token matching (`PSScriptBuilderBumpReplacementHelper`'s
  `{{TOKEN}}`/`{REGEX_TOKEN}` handling) as well as the Template system. Not decided — added as a new
  Unresolved Question to revisit once RFC 0007/0008/0009 land, since only then will Release
  Management have independently converged onto the same discover/assemble, case-insensitive shape
  Templates already has, giving concrete evidence either way. Regex Mode's arbitrary, user-supplied
  patterns are a likely mismatch for a `{{...}}`-shaped tokenizer, unlike Simple/Placeholder Mode's
  fixed token syntax.
- 2026-09-03 — Confirmed a fourth concrete instance of the duplicated placeholder-matching
  pattern this RFC's Motivation already describes abstractly: RFC 0001 Phase 1's
  `PSScriptBuilderTemplateModeResolver.ExtractPlaceholders()` uses the identical
  `'\{\{([^}]+)\}\}'` pattern as two of `PSScriptBuilderTemplateValidator`'s eight rules
  (`ValidateNoWhitespaceInPlaceholders`, `ValidateNoUnknownPlaceholders`) — verified via grep
  across `src/`. Reinforces, but does not change, the existing decision to defer this RFC.
- 2026-09-01 — Expanded scope after comparing PSScriptBuilder's design against established
  templating engines (Mustache/Handlebars, Jinja2, Go `text/template`): the same missing piece — a
  single, canonical tokenization step — explains RFC 0001's triplicated mode-detection, RFC 0004's
  comparison-mode inconsistency across eight Validator rules, and RFC 0003's rendering bug, not just
  the render-mode duplication originally identified. Renamed from "Unified Template Rendering
  Mechanism" to reflect the broader scope. Considered and rejected implementing this directly
  instead of RFC 0001-0004 (see Rationale and Alternatives) — the design is further from finished
  than before (a new open difficulty found: mapping eight validation rules onto one shared
  structure), and none of RFC 0001-0004's work would be wasted by proceeding with them first.
- 2026-08-30 — Raised during RFC 0003's review; logged as a separate, deferred RFC per the
  "correct the known bug now, redesign later" principle. Originally scoped narrowly: unify
  `RenderFreeMode`/`RenderOrderedMode` into one rendering mechanism.
