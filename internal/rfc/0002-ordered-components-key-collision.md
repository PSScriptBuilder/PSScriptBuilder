# RFC 0002: Ordered-Components-Key Collision

- **Status:** Implemented (2026-09-03)
- **Type:** Fix
- **Created:** 2026-08-29
- **Branch:** `refactor/template-engine-consolidation`

## Summary

Nothing prevents a user from registering a collector with `-CollectionKey "ORDERED_COMPONENTS"` —
the same name PSScriptBuilder reserves for the combined-components placeholder by default. For an
Enum/Class/Function collector this produces a confusing build failure; for a `File` collector it
is worse — validation passes and the build silently corrupts output; for a `Using` collector it is
worse still — validation passes and the *entire* ordered-components block (every class, function,
and enum) silently disappears from the build output without a trace. All three need the same
validation-time collision check, covering every collector type without exception.

## Motivation

There is no reserved-word validation anywhere in the collector registration path
(`Add-PSScriptBuilderCollector`, `New-PSScriptBuilderCollector`,
`PSScriptBuilderCollectorBase.CollectionKey`) that prevents a user from registering an Enum,
Class, or Function collector with `-CollectionKey "ORDERED_COMPONENTS"` — the same name
`PSScriptBuilderTemplateValidator` treats as the reserved combined-components placeholder by
default. This is a legitimate, if unlucky, collector name choice — not user error in the way a
typo or a missing placeholder is. A project could reasonably pick `ORDERED_COMPONENTS` as a
`-CollectionKey` for an actual Enum/Class/Function collector with no awareness that the name is
reserved, since nothing documents it as reserved and nothing validates against it.

Found 2026-08-29 while reviewing `docs/guides/templates.md`'s "Using a Custom Combined
Placeholder Key" subsection. Same underlying mechanism as RFC 0001 (placeholder detection is a raw
text match against the whole template, with no concept of which collector "owns" a given
occurrence), different trigger: here the collision comes from a collector's own, legitimate
`-CollectionKey`, not from incidental prose.

**Repro 1 — Enum/Class/Function collector, real build:** a Free Mode project with a single
`Class` collector —

```powershell
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "ORDERED_COMPONENTS" -IncludePath "src\Classes"
```

— and a template containing only that collector's own placeholder (`{{ORDERED_COMPONENTS}}`). No
cross-dependencies exist; this should be an ordinary, valid Free Mode template with one
placeholder for one collector. Instead:

- `Test-PSScriptBuilderTemplate` → `$false`
- `Invoke-PSScriptBuilderBuild` → **fails**:
  `"Enum/Class/Function placeholders are forbidden when {{ORDERED_COMPONENTS}} is used
  (components must share the single ordered placeholder). Found: {{ORDERED_COMPONENTS}}"`

The error message is actively confusing: it reports `{{ORDERED_COMPONENTS}}` as a forbidden
per-type placeholder found *alongside* the ordered-components placeholder, when they are the same
single token in the template. `PSScriptBuilderTemplateValidator::ValidateNoForbiddenPlaceholders`
(`src\Classes\ScriptBuilder\Template\PSScriptBuilderTemplateValidator.ps1:153-195`) iterates
registered collectors and checks whether each one's placeholder text exists in the template,
independently of `ValidateOrderedPlaceholderExists`'s own check for the same literal text — the
two checks don't know they just matched the identical occurrence.

**Repro 2 — `File` collector, real build, worse (silent):** a single `File` collector with
`-CollectionKey "ORDERED_COMPONENTS"`, template containing just `{{ORDERED_COMPONENTS}}`, no
Enum/Class/Function collectors at all:

- `Test-PSScriptBuilderTemplate` → `$true` — validation **passes**, because `File` placeholders
  are explicitly exempted from the "forbidden alongside the combined placeholder" check
  (`ValidateNoForbiddenPlaceholders` skips `FileCollector` by design — `File` content is meant to
  coexist with the combined block), so this collision is invisible to today's validator entirely.
- `Invoke-PSScriptBuilderBuild` → **succeeds**, with silently corrupted output:
  `"# Documentation note: this project uses # No components (enums, classes, functions)\n in its template."`

This is the key collision and the Ordered-Mode template-injection bug (RFC 0003) **compounding
each other**: the `File` collector's own content (`"...uses {{ORDERED_COMPONENTS}} in its
template."`) is inserted at the template's one `{{ORDERED_COMPONENTS}}` occurrence during the
`File` replacement step — and since that inserted content itself contains the literal text
`{{ORDERED_COMPONENTS}}` again (self-collision), the *next* step
(`ReplaceOrderedComponentsPlaceholder`, which finds zero real components and falls back to a "no
components" comment) matches that residual occurrence and overwrites part of the `File`
collector's own content with the fallback comment.

**Repro 3 — `Using` collector, real build, most severe (silent, complete content loss):** found
2026-09-01 during a full pre-implementation re-analysis, after noticing this RFC's Decision section
enumerated "Enum, Class, Function, *or* `File`" but never `Using`. A `Using` collector with
`-CollectionKey "ORDERED_COMPONENTS"`, combined with a real `Class` collector, template containing
just `{{ORDERED_COMPONENTS}}`:

- `Get-PSScriptBuilderTemplateAnalysis` → `ValidationMode: Hybrid`, `IsValid: True`,
  `HasCrossDependencies: False` — no real cross-dependency is needed to trigger this, the key
  collision alone is enough to escalate to Hybrid Mode (via `HasOrderedPlaceholder`, RFC 0001).
- `Test-PSScriptBuilderTemplate` → `$true` — validation **passes**, because `ValidateNoForbiddenPlaceholders`
  explicitly exempts `Using` placeholders from the "forbidden alongside the combined placeholder"
  check, exactly like it exempts `File` — this collision is invisible to today's validator for the
  same structural reason as Repro 2.
- `Invoke-PSScriptBuilderBuild` → **succeeds**, output: `using namespace System.Collections.Generic`
  — **the entire `Class` definition is missing, with no error, no warning.**

**Root cause distinct from Repro 2's content-collision:** here it is not content colliding with a
placeholder, but the *processing order itself*. `RenderOrderedMode` runs
`ReplaceUsingCollectorPlaceholders` (Step 1) before `ReplaceOrderedComponentsPlaceholder` (Step 3).
Since the `Using` collector's own `CollectionKey` *is* `{{ORDERED_COMPONENTS}}`, Step 1 finds and
replaces the template's one occurrence with the real `using` statements — consuming the only
placeholder that Step 3 needs. Step 3 then finds nothing left to replace, and the entire sorted
component block (classes, functions, enums — regardless of how many or which kinds) is silently
dropped rather than corrupted or duplicated.

**Verified this is not an isolated fluke:**
- Registration order does not matter — `Using` registered before or after `Class` produces
  identical output.
- Not specific to `Class` — with both `Class` and `Function` collectors present, both vanish
  together; the entire block disappears regardless of its contents.
- Not specific to the default key — reproduces identically with a custom `-OrderedComponentsKey`
  (e.g. `"MY_COMPONENTS"`) when the `Using` collector's own `-CollectionKey` matches that active
  key instead of the default.

This is more severe than Repro 2: `File`'s collision corrupts *part* of one collector's own
content; `Using`'s collision silently discards the *entire* program logic of the build while
reporting success.

## Detailed Design

### Root Cause

Placeholder/mode detection is a raw text match against the whole template, with no model of
which collector a given occurrence actually belongs to (same root cause as RFC 0001, different
trigger: a collector's own key, not incidental prose).

### Decision

The fix belongs in **validation, not registration**: `Add-PSScriptBuilderCollector` cannot reject
`-CollectionKey "ORDERED_COMPONENTS"` at registration time, because the effective
ordered-components key is not known then — it's supplied later, independently, as
`-OrderedComponentsKey` on `Invoke-PSScriptBuilderBuild` / `Test-PSScriptBuilderTemplate` (default
`"ORDERED_COMPONENTS"`, overridable — see `docs/guides/templates.md` "Using a Custom Combined
Placeholder Key" and `psscriptbuilder.config.json`'s `build.orderedComponentsKey`). A collector's
`CollectionKey` is set once, upfront, with no connection to the build/validation call that will
later determine which key is "reserved" for that specific run.

`PSScriptBuilderTemplateValidator` needs to detect when **any** registered collector's
`CollectionKey` — Enum, Class, Function, `File`, *or* `Using`, with no exceptions — equals the
*active* `OrderedComponentsKey` for that call, and raise a specific, clear error at that point,
e.g.:

**The check only needs to live in `ValidateInOrderedMode`, not `ValidateInFreeMode` — proved, not
merely assumed.** The collision can never manifest silently while `$useOrderedMode` is `$false`:

- If the colliding collector's *own* placeholder is present in the template (required for the
  collision to matter at all), that placeholder text *is* the ordered-components token — so
  `HasOrderedPlaceholder` (RFC 0001) always sees it and forces `$useOrderedMode = $true` before
  `Validate()` ever runs, regardless of real cross-dependencies. Verified with a real build:
  `Get-PSScriptBuilderTemplateAnalysis` reports `ValidationMode: Hybrid`,
  `HasCrossDependencies: False` for exactly this setup.
- If the colliding collector's own placeholder is *not* present in the template, mode correctly
  stays Free — but `ValidateInFreeMode`'s existing, unrelated `ValidateCollectorPlaceholdersExist`
  check *already* fails the build today, with no changes needed: verified with a real build,
  `Invoke-PSScriptBuilderBuild` fails with `"Template does not contain placeholders for 1
  registered collector(s): {{ORDERED_COMPONENTS}}"` before the collision could ever matter.

Every possible configuration falls into one of these two cases — there is no third case where the
collision exists but mode stays Free without an existing, unrelated check already catching it. This
resolves the "should this check run unconditionally" question below with a proven "no," not a
guess.

**Comparison must be case-insensitive (`OrdinalIgnoreCase`), consistent with RFC 0004.** A
collector registered with `-CollectionKey "ordered_components"` (any casing) collides with the
default `OrderedComponentsKey` of `"ORDERED_COMPONENTS"` just as much as an exact-case match does —
per the documented case-insensitive placeholder contract (`docs/guides/templates.md`), the two are
"the same" key. A case-sensitive comparison here would silently miss that collision and let the
exact bug this RFC fixes recur under a differently-cased key. Found 2026-09-01 while re-examining
this RFC's interaction with RFC 0004 — this RFC was decided before RFC 0004 established that every
placeholder-name comparison in this codebase must be explicit and consistent about comparison mode,
and this check's original wording ("equals") never specified one.

> "Collector with CollectionKey 'ORDERED_COMPONENTS' collides with the reserved
> ordered-components placeholder key; rename the collector's key or pass a different
> `-OrderedComponentsKey`"

— instead of the current confusing "forbidden placeholder found" message (Enum/Class/Function
case) or, worse, no message at all (the `File` and `Using` cases, which currently pass validation
and either corrupt or completely discard output silently). Silent cases are strictly higher
priority than the confusing-but-loud Enum/Class/Function case — and among the silent cases,
`Using`'s complete content loss (Repro 3) is more severe than `File`'s partial corruption (Repro 2).

This check alone is sufficient for the `Using` scenario (Repro 3) — unlike `File`'s Repro 2, no
compounding interaction with RFC 0003 is involved here, since the root cause is processing *order*
consuming the sole placeholder, not re-scanned *content*. RFC 0003's discover/assemble rewrite does
not change `RenderOrderedMode`'s Using-then-File-then-OrderedComponents step ordering, only how
each step computes its own replacement — so this collision check is the complete fix for Repro 3 on
its own.

Both this collision check *and* RFC 0003's discover/assemble rewrite are needed together for the
`File` scenario (Repro 2): the collision check alone would only prevent this specific
self-referential case from validating; RFC 0003's fix is what prevents the broader class of "one
step's inserted content gets re-matched by the next" corruption in general (including for `File`
collectors whose *content* — not their key — coincidentally matches another placeholder, as in RFC
0003's two-`File`-collector repro).

## Rationale and Alternatives

**Considered and rejected: reject the colliding key at `Add-PSScriptBuilderCollector` time.** The
obvious first idea, rejected because the effective `OrderedComponentsKey` isn't known at
registration time (see Decision, above) — there is no design where this check can correctly live
at registration instead of validation.

## Scope

**In scope:** the validation-time collision check, covering Enum, Class, Function, `File`, *and*
`Using` collectors — every collector type without exception (expanded from the original
Enum/Class/Function-only scope after the `File` repro, then further expanded to include `Using`
after Repro 3). Lives only in `ValidateInOrderedMode` — proved unnecessary in `ValidateInFreeMode`
(see Decision).

**Out of scope:**

- Documenting this as a named caveat in `docs/guides/templates.md`/`docs/guides/collectors.md` —
  a documentation decision independent of the validation fix landing (see Unresolved Questions).

## Relationship to Other RFCs

- **RFC 0001** (template placeholder escaping) — same root cause, different trigger (a collector's
  own key, not incidental prose).
- **RFC 0003** (Ordered/Hybrid Mode template-injection bug) — Repro 2, above, is a compounding
  interaction between both bugs; both fixes are needed for that scenario to be fully resolved.

See `internal/rfc/IMPLEMENTATION-PLAN.md` for the build order across all four RFCs on this branch.

## Test Plan

- Integration test reproducing Repro 1 (Enum/Class/Function collision) — must now fail with the
  new, specific collision error instead of the current confusing message.
- Integration test reproducing Repro 2 (`File` collision) — must now fail validation with the new
  collision error, instead of silently passing and corrupting output.
- Integration test reproducing Repro 3 (`Using` collision) — must now fail validation with the new
  collision error, instead of silently passing and discarding the entire ordered-components block.
  Cover all three verified variants: default key, custom `-OrderedComponentsKey`, and both
  collector-registration orders.
- Regression test: a collector registered with a differently-cased `-CollectionKey` (e.g.
  `"ordered_components"`) than the active `OrderedComponentsKey` (default `"ORDERED_COMPONENTS"`)
  must also be rejected as a collision — confirms the comparison is case-insensitive.
- Non-regression test proving the Free-Mode scoping decision: a colliding collector whose own
  placeholder is absent from the template (mode stays Free) must continue to fail with the existing
  "missing placeholder" error, unaffected by this RFC's change living only in `ValidateInOrderedMode`.

## Unresolved Questions

- ~~Should this check run unconditionally (regardless of mode)~~ — **resolved:** no, proved
  unnecessary; see Decision.
- ~~Should this be documented as a named caveat in `docs/guides/templates.md` and/or
  `docs/guides/collectors.md`~~ — **resolved:** yes, documented (see Revision Log).

## Revision Log

- 2026-09-16 — Corrected the Status header, which still said "Decided — design complete, not
  yet implemented" despite this RFC having been implemented and pushed on 2026-09-03 (see below).
  No decisions changed — documentation accuracy only, found while reviewing outstanding RFCs
  ahead of the 1.3.0 release.
- 2026-09-03 — Documented `ORDERED_COMPONENTS` (and a custom `-OrderedComponentsKey`) as a
  reserved name in `docs/guides/collectors.md` (Collection Keys) — placed right after the
  uniqueness rule, before the collision examples, per the "constraints before examples" best
  practice. A duplicate note was initially also added to `docs/guides/templates.md`'s "Combining
  with Release Management Tokens" section, then removed: that section is about a template
  containing *real* RM tokens alongside collector placeholders, not about collector key naming —
  a different concern, already covered in `collectors.md`. Closes the last open question.
- 2026-09-03 — Implemented and pushed: new `ValidateNoCollectionKeyCollidesWithOrderedKey` method,
  added as the first step of `ValidateInOrderedMode`. All three repros, the case-insensitive
  regression test, and the Free-Mode non-regression test from Test Plan are committed and verified
  green. The error message wording ("collides with the reserved ordered-components...") was kept as
  originally drafted; the pre-existing Repro-1 test's `*collis*` wildcard was widened to
  `*collides with the reserved ordered-components*` to match it precisely, rather than changing the
  message to fit the wildcard. `CHANGELOG.md` entry added under `### Fixed`, as part of this same
  change (per the project's convention of attaching a CHANGELOG entry to the phase that ships the
  observable behavior change, not deferring it). See `internal/rfc/IMPLEMENTATION-PLAN.md` for
  phase-level tracking.
- 2026-09-02 — Resolved the "should this run unconditionally regardless of mode" question with a
  proof rather than a judgment call: the collision can never manifest while mode stays Free —
  either the colliding collector's own placeholder requirement forces `HasOrderedPlaceholder` to
  escalate to Ordered/Hybrid first (verified: `ValidationMode: Hybrid` with
  `HasCrossDependencies: False`), or its absence means the existing, unrelated
  `ValidateCollectorPlaceholdersExist` check already fails the build today (verified: real build
  fails with "Template does not contain placeholders for 1 registered collector(s)"). Scoped the
  check to `ValidateInOrderedMode` only; added a non-regression test for the Free-Mode case.
- 2026-09-01 — Found Repro 3 (`Using` collector collision) during a full pre-implementation
  re-analysis, after noticing the Decision section's collector-type list never included `Using`.
  Verified with a real build: more severe than Repro 2 — the entire ordered-components block is
  silently discarded, not partially corrupted, and (unlike Repro 2) this collision check alone
  fully resolves it with no RFC 0003 interaction, since the root cause is step *ordering*
  consuming the sole placeholder, not re-scanned content. Verified the finding generalizes across
  registration order, collector-content variety, and custom `-OrderedComponentsKey`. Expanded
  scope to cover `Using` collectors, closing the last remaining collector-type gap.
- 2026-09-01 — Found this RFC never specified a comparison mode for the collision check, while
  re-examining its interaction with RFC 0004 (decided afterward, which established that every
  placeholder-name comparison must be explicit and case-insensitive). Specified
  `OrdinalIgnoreCase`, added a regression test for a differently-cased colliding key.
- 2026-08-31 — Rewritten as a self-contained document: removed phase-numbering language, now
  referencing `internal/rfc/IMPLEMENTATION-PLAN.md` for build order instead. No decisions changed.
- 2026-08-29 — Repro 2 found (`File` collector, silent corruption): worse than Repro 1 and
  compounds with RFC 0003 rather than being fully independent. Expanded scope to cover `File`
  collectors, not only Enum/Class/Function.
- 2026-08-29 — Initial finding (Enum/Class/Function collector repro), fix approach decided
  (validation-time, not registration-time).
