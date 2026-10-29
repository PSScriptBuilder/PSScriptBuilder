# RFC 0014: Release Management Explicit Pattern Mode Field

- **Status:** Decided — deferred until after the 1.3.0 release
- **Type:** Feature
- **Created:** 2026-09-08
- **Branch:** none yet — deliberately not tied to `refactor/release-management-bump-mode`

## Summary

Add an optional `mode` field (`"placeholder"` or `"regex"`) to items-mode bump config entries.
When present, it is used directly instead of `PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode`'s
heuristic detection, eliminating the whole class of ambiguity RFC 0011/0012/0013 detect and reject
(mixed syntax, dangling unclosed markers, an unescaped literal parenthesis needing escaping). When
absent, the existing heuristic remains the fallback - zero breaking change for existing configs.

## Motivation

Raised during RFC 0011's design discussion: after fixing several real ambiguity bugs in
shape-based mode inference (RFC 0012's escape-convention gap, RFC 0013's mixed-syntax silent
no-op, and RFC 0013's own follow-up precision correction for dangling unclosed markers), the
question came up whether the deeper problem is *how* the mode is determined at all - inferring it
from the pattern's shape - rather than any one specific inference bug.

**The pattern behind all three fixes is the same:** representing a "which variant applies here"
decision by sniffing the *shape* of unstructured text, instead of an explicit, structural
declaration. This is a well-known, named weakness in API/schema design - the well-established
alternative is a **tagged/discriminated union** (Rust enums with payloads, TypeScript discriminated
unions, F# discriminated unions) or, in JSON-specifically, a **discriminator field** (the concept
OpenAPI's `discriminator` keyword formalizes). Concretely: `PSScriptBuilderBumpPatternMode`'s two
values (`Placeholder`, `Regex`) already exist as the *internal* representation of this decision
(RFC 0011); this RFC proposes an *external*, config-level way to supply that value directly,
instead of only ever inferring it.

**Discussed at length whether the internal enum becomes redundant if this lands - confirmed it does
not.** The `mode` field is the external, serialized representation; the enum remains the internal,
typed one that the replacement dispatch logic switches on. A parsed `"mode": "regex"` string still
needs converting into `[PSScriptBuilderBumpPatternMode]::Regex` for the code to act on, exactly the
same way the pre-existing `PSScriptBuilderBumpType` enum is not made redundant by whatever CLI
switch or config value currently selects Major/Minor/Patch.

**Discussed whether a new, dedicated pattern *syntax* (e.g. different bracket characters for
capture groups) would solve this instead of a config field - concluded no.** Any syntax-based
signal has the same fundamental weakness as the current one: meaning is inferred from the shape of
freeform text, which is exactly the failure mode being fixed. Only moving the decision *out of* the
pattern text entirely, into a separate, structural field, removes the ambiguity class at its root.

**Decided to defer rather than draft in full detail now:** per the same reasoning as RFC 0015 - the
1.3.0 release has priority. This RFC captures the agreed direction and design constraints so the
next session has a decided starting point, without spending further session time on exhaustive
detail design (e.g. exact validation-error wording, whether `mode` should also apply to Simple
Mode's `tokens`-shaped entries) before it is actually being implemented.

## Detailed Design

### Root Cause

`PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode` has no way to know a pattern's intended
mode except by inferring it from the pattern text's shape - even after RFC 0011/0012/0013's fixes,
this remains an *inference*, not a *declaration*, and any future shape-based signal would carry the
same class of risk (see Motivation's rejected alternative).

### Decision

- Add an optional `mode` property to items-mode bump config entries (i.e. one level up from
  `pattern`/`tokens`, sibling properties on each object in an `items` array), accepting the string
  values `"placeholder"` or `"regex"` (case-insensitivity to be decided at implementation time,
  consistent with RFC 0008's precedent for token names).
- When `mode` is present, `PSScriptBuilderBumpFilesValidator`/`PSScriptBuilderBumpReplacementHelper`
  parse it directly into a `PSScriptBuilderBumpPatternMode` value and skip
  `DetermineBumpPatternMode`'s heuristic entirely for that item - no ambiguity is possible, since
  there is nothing left to infer.
- When `mode` is absent, behavior is unchanged: `DetermineBumpPatternMode`'s heuristic (as fixed by
  RFC 0011/0012/0013) remains the fallback. Every existing bump config continues to work exactly as
  today, with no migration required.
- `mode`, if present, should still be validated for basic sanity (e.g. does the pattern actually
  look like the declared mode - a `mode: "regex"` item whose pattern has no capture group at all is
  presumably still a config mistake worth catching, likely by *reusing* the existing shape checks
  in an advisory rather than authoritative role once a declared mode exists - exact behavior to be
  decided during implementation).

## Rationale and Alternatives

**Considered a new/different pattern syntax for capture groups instead of a config field.**
Rejected - see Motivation; this only relocates the shape-inference weakness rather than removing it.

**Considered making `mode` required instead of optional.** Rejected - would be a breaking change
for every existing bump config; the optional-with-fallback shape has direct precedent in this
project (`[1.2.0]`'s CHANGELOG entry: several `build` config section fields made optional with
built-in defaults, existing configs unaffected).

**Considered extending `PSScriptBuilderBumpPatternMode` itself to represent "not specified" as a
third value.** Rejected - conflates "how was the mode determined" (a config/parsing concern) with
"what mode is it" (the internal, already-resolved value the replacement logic switches on); keeps
the enum exactly as RFC 0011 already narrowed it (`Placeholder`/`Regex` only).

## Scope

**In scope (once un-deferred and implemented):** the optional `mode` field on items-mode bump
config entries; a way to convert its string value to `PSScriptBuilderBumpPatternMode`, reusing that
existing enum; the fallback-to-heuristic behavior when absent; documentation in
`docs/guides/release-management.md` presenting `mode` as the recommended, explicit way to author
new items-mode entries, with the heuristic documented as the legacy/implicit fallback.

**Out of scope:** removing or deprecating the heuristic - it remains permanently needed for
backward compatibility with configs that never set `mode`; changing Simple Mode
(`tokens`-shaped entries) at all, which has no analogous ambiguity to resolve.

## Relationship to Other RFCs

Builds on RFC 0011's `PSScriptBuilderBumpPatternMode` enum and `PSScriptBuilderBumpModeResolver`
(reuses both, adds a second way to arrive at a value). Complementary to, not a replacement for,
RFC 0012/0013's fixes - those remain necessary for the fallback heuristic path, which stays
permanently supported. Could share a future RFC 0015 exception type as its validation-error
mechanism (an invalid explicit `mode` value, or a `mode` that contradicts the pattern's actual
shape, would be a natural first consumer of RFC 0015's `PSScriptBuilderValidationException`) - not
a dependency, since both RFC 0014 and RFC 0015 work independently of each other today.

## Test Plan

To be written at implementation time. At minimum: an item with an explicit `mode` bypasses the
heuristic entirely (verified by using a pattern shape that would otherwise be ambiguous or
misclassified, e.g. today's dangling-marker edge cases, and confirming the explicit `mode` makes it
work correctly regardless); every existing test pattern continues to work unchanged with `mode`
absent (regression); case-insensitivity of the `mode` value itself, if decided.

## Unresolved Questions

- Case-sensitivity of the `mode` string value - lean toward case-insensitive per RFC 0008's
  precedent, not decided.
- Exact behavior when `mode` is present but contradicts the pattern's actual shape (e.g.
  `mode: "regex"` on a pattern with no capture group at all) - validation error, silent trust of
  the explicit declaration, or an advisory warning - not decided.
- Whether `mode` should be documented as the *recommended* way to author new entries (nudging
  authors away from the implicit heuristic over time) or presented as a neutral, equally-valid
  alternative - leans toward "recommended," not decided.

## Revision Log

- 2026-09-08 — Initial draft, capturing the design direction already agreed during RFC 0011's
  discussion (tagged/discriminated-union reasoning, optional-with-fallback shape, confirmation that
  RFC 0011's enum does not become redundant). Deferred until after the 1.3.0 release per Tim's
  explicit priority call, deliberately without the same depth of empirical investigation RFC 0015
  received, since the design here was already well-reasoned in prior discussion and the topic is
  smaller in scope.
