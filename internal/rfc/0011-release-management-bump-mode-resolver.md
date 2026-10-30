# RFC 0011: Release Management Bump Mode Resolver

- **Status:** Implemented (2026-09-08)
- **Type:** Refactor
- **Created:** 2026-09-07
- **Branch:** `refactor/release-management-bump-mode`

## Summary

Release Management determines which replacement mechanism applies via ad-hoc boolean checks
recomputed independently at four call sites across three classes. Introduce
`PSScriptBuilderBumpModeResolver`, a static utility class modeled directly on the existing
`PSScriptBuilderTemplateModeResolver`, so this detection logic exists exactly once and every
consumer reacts to an explicit, named result instead of re-deriving it.

## Motivation

Raised while discussing `PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()`'s
`tokens`/`items` branch: reacting to an explicitly determined mode reads better than an
`if`/`elseif` chain that re-derives the mode inline. Checked whether this concern already has a
concrete, duplicated instance in the code rather than being purely stylistic - it does, in two
structurally different places, answering two genuinely independent questions about two different
objects:

**Pattern-level duplication (Placeholder vs. Regex), confirmed byte-identical:**
`PSScriptBuilderBumpReplacementHelper.ApplyPatternReplacements` (the public dispatcher) and
`.HasContentToReplace` (the content-aware validation helper) each independently compute, for a
single `item.pattern` *string*:
```powershell
$hasPlaceholders = $pattern -match '\{\{'
$hasCaptures     = $pattern -match '(?<!\\)\('  # Only non-escaped parentheses
```
then branch identically. The two blocks differ only in what each branch does once the mode is
known (dispatch to a replacement method vs. a lightweight presence check). Verified this is the
*only* place this specific check exists: `PSScriptBuilderBumpFilesValidator.ValidateItemConfiguration`
validates that `item.pattern` is a non-empty string but never itself inspects its shape - Placeholder
vs. Regex classification is deferred entirely to runtime, so there is no third, hidden occurrence.

**File-level duplication (Simple vs. Items), confirmed behaviorally equivalent:**
`PSScriptBuilderBumpFilesValidator` and `PSScriptBuilderBumpFilesProcessor` both check a
`fileConfig` *object*'s `tokens`/`items` property to decide Simple Mode vs. Items Mode. The
Validator's version adds `$fileConfig.PSObject.Properties.Name -contains 'tokens'` on top of the
Processor's plain `$null -ne $fileConfig.tokens`; verified directly (property absent, property
present as `null`, property present as an empty array) that accessing an absent property on a
`PSCustomObject` already returns `$null` in PowerShell, so the extra check never changes the result
- this is redundant duplication, not a latent inconsistency.

Both are an instance of **Primitive Obsession** (Fowler/Kerievsky): a recurring domain concept
represented by ad-hoc boolean flags recomputed at each use site instead of a single, named type.

**These two duplications are genuinely different granularities, not one 3-way split.** An earlier
draft of this RFC modeled them as one `Simple`/`Placeholder`/`Regex` enum. Re-examined after
noticing `Simple` was never actually returned by any method in that design (the file-level check
stayed boolean-shaped regardless) - a defined-but-unused enum value is a sign the model does not
match reality. The two questions really are independent: "does this *entry* use `tokens` or
`items`" (an object-shape question, asked once per `bumpFiles` entry) vs. "is this *pattern string*
Placeholder- or Regex-shaped" (a content question, asked once per `item`). Conflating them into one
enum was a category error.

**"Mixed Mode" is a related but separate, purely descriptive term - not a third runtime state.**
`docs/guides/release-management.md` defines it as "the combination of Simple and Regex items in a
single entry" (Entry 3's example: one item with a `{{VERSION}}` placeholder pattern and a second
with a `{REGEX_VERSION}` regex pattern, targeting the same file in different states). This describes
the *composition* of a whole `items` array (some items Placeholder-shaped, some Regex-shaped) -
grep confirms there is no `if`/`switch` anywhere in the code that computes "is this Mixed" as a
value; each item is simply classified and processed independently, and "Mixed" is what a reader
calls the resulting combination. It does not need, and must not get, its own enum value.

**Direct precedent for the fix already exists in this codebase.** `PSScriptBuilderTemplateModeResolver`
(`src/Classes/ScriptBuilder/Template/`) was introduced for the structurally identical problem on
the Template side (Free vs. Ordered/Hybrid Mode, previously duplicated across three call sites) - a
static utility class with no properties or constructor, called directly as
`[PSScriptBuilderTemplateModeResolver]::MethodName(...)` by consumers that do not need to know about
each other. Notably, that class does not itself return any custom enum - its methods return
`[string[]]`/`[bool]` (`ExtractPlaceholders`, `HasOrderedPlaceholder`, `IsOrderedModeRequired`); the
class name reflects its full responsibility ("resolving mode-related facts"), not the shape of any
one return type. The same reasoning applies here: `PSScriptBuilderBumpModeResolver` covers both
independent questions, even though only one of them is expressed as an enum.

## Detailed Design

### Root Cause

Neither "Simple Mode", "Placeholder Mode", nor "Regex Mode" is ever named as a value anywhere in
Release Management - each of the four call sites re-derives which one applies, from either a
`fileConfig` object's properties or a pattern string's shape, independently.

### Decision

- New enum `src/Enums/PSScriptBuilderBumpPatternMode.ps1`: `Placeholder`, `Regex` - covers only the
  pattern-content question (see Motivation for why a third, `Simple` value does not belong here).
  Named after the two existing hidden replacement methods (`ApplyPlaceholderReplacements`,
  `ApplyRegexReplacements`), not after the class's own SYNOPSIS wording ("Pattern Mode") - see
  Rationale for why `Pattern` is deliberately avoided as a value name.
- New static class `src/Classes/ReleaseManagement/Helper/PSScriptBuilderBumpModeResolver.ps1`,
  modeled directly on `PSScriptBuilderTemplateModeResolver`'s shape (static methods, no properties,
  no constructor):
  ```powershell
  static [PSScriptBuilderBumpPatternMode] DetermineBumpPatternMode([string] $pattern)
  static [bool] IsSimpleMode([PSCustomObject] $fileConfig)
  static [bool] IsItemsMode([PSCustomObject] $fileConfig)
  ```
  `DetermineBumpPatternMode` encapsulates the two pattern regex checks and returns `Placeholder` or
  `Regex`; throws the same `ArgumentException` `ApplyPatternReplacements` already throws today when
  a pattern matches neither shape. `IsSimpleMode`/`IsItemsMode` encapsulate the `tokens`/`items`
  property checks (without the Validator's redundant `PSObject.Properties.Name -contains` guard,
  confirmed unnecessary - see Motivation).
- `PSScriptBuilderBumpReplacementHelper.ApplyPatternReplacements` and `.HasContentToReplace` both
  call `DetermineBumpPatternMode` and `switch` on the result instead of recomputing
  `$hasPlaceholders`/`$hasCaptures` themselves. `HasContentToReplace`'s existing exception-safe
  `try`/`catch` already handles the "neither" case via the exception `DetermineBumpPatternMode`
  throws, so its current `else { return $false }` branch becomes unreachable and is removed.
- `PSScriptBuilderBumpFilesValidator` and `PSScriptBuilderBumpFilesProcessor` both call
  `IsSimpleMode`/`IsItemsMode` in place of their own inline checks; both keep their current
  `if`/`elseif` shape (the Validator additionally needs to detect "both" and "neither" as distinct
  error states - see Rationale for why this rules out a shared enum for this half).

## Rationale and Alternatives

**Considered one `Simple`/`Placeholder`/`Regex` enum covering both questions.** Rejected - see
Motivation. The two questions operate on different objects (a `fileConfig`, vs. a single pattern
string) at different granularities (once per entry, vs. once per item), and `Simple` would never
actually be returned by any method, since the file-level check must stay boolean-shaped regardless
(next point).

**Considered making the file-level check return `PSScriptBuilderBumpPatternMode` too (e.g. adding a
`Simple` value there) instead of two booleans.** Rejected independently of the above - `PSScriptBuilderBumpFilesValidator`
needs to detect *both* "has both `tokens` and `items`" and "has neither" as distinct,
separately-worded validation errors. Two independent booleans express this directly; a single enum
would need extra values (`Both`, `Neither`) that exist only to serve one caller's error-reporting
needs, not to represent an actual replacement mechanism.

**Considered naming the enum value `Pattern` instead of `Placeholder`.** Rejected - `Pattern`
already names the public dispatcher method (`ApplyPatternReplacements`) and the bump config
property (`item.pattern`), both of which cover *both* Placeholder and Regex shapes. Using `Pattern`
as one specific enum value the dispatcher itself resolves to would be a confusing self-reference.
`Placeholder` matches the already-existing hidden method name (`ApplyPlaceholderReplacements`)
exactly.

**Considered naming the two boolean methods `HasSimpleModeTokens`/`HasItemsModeItems` (mirroring
the current `$hasTokens`/`$hasItems` variable names).** Rejected in favor of `IsSimpleMode`/
`IsItemsMode`, per the .NET Framework Design Guidelines' boolean-naming guidance (`Is`/`Has`/`Can`
are all idiomatic, chosen by semantic fit) and by direct comparison with
`PSScriptBuilderTemplateModeResolver` itself: there, `HasOrderedPlaceholder` is a *supporting fact*
consumed by the *final decision* method `IsOrderedModeRequired`. Our two methods are not supporting
facts for some further decision - they are themselves the final decision each call site branches
on directly, so they should read as `Is*`, matching how the precedent names its own decision-level
method. `Has*` would also re-expose the underlying mechanism (a `tokens` property check) in the
name, working against the resolver's whole purpose of hiding that mechanism behind an
intention-revealing name.

**Considered a static method on `PSScriptBuilderBumpReplacementHelper` instead of a new class.**
Rejected - this would fix only the pattern-level duplication and leave the file-level one either
unfixed or fixed by introducing a dependency from `PSScriptBuilderBumpFilesValidator` or
`PSScriptBuilderBumpFilesProcessor` onto `PSScriptBuilderBumpReplacementHelper` (or vice versa),
none of which exists today. A dedicated static resolver class fixes both without adding any new
dependency between existing classes - exactly the property `PSScriptBuilderTemplateModeResolver`
already demonstrates on the Template side.

**Considered naming the resolver class `PSScriptBuilderBumpPatternModeResolver` to match the enum.**
Rejected - the class's actual scope is broader than the enum (it also resolves the file-level
Simple/Items question, which has no enum at all). `PSScriptBuilderTemplateModeResolver` sets the
precedent for a "ModeResolver" class name that does not correspond to any single equally-named
enum - the class name reflects its full responsibility, not one return type.

## Scope

**In scope:** the new `PSScriptBuilderBumpPatternMode` enum; the new
`PSScriptBuilderBumpModeResolver` static class; converting
`PSScriptBuilderBumpReplacementHelper.ApplyPatternReplacements`/`.HasContentToReplace` and
`PSScriptBuilderBumpFilesValidator`/`PSScriptBuilderBumpFilesProcessor`'s relevant checks to use it.
This is a pure, behavior-preserving refactor - no `CHANGELOG.md` entry (a pure refactor with no
observable behavior change does not get one - see RFC 0001's Phase 1 in `IMPLEMENTATION-PLAN.md`
for the same reasoning applied previously).

**Out of scope:** any change to the actual replacement mechanics (`ApplySimpleReplacements`,
`ApplyPlaceholderReplacements`, `ApplyRegexReplacements`, the protected-span ledger) - this RFC
touches only mode *detection*, never replacement behavior. "Mixed Mode" itself needs no code change
- it already works today and is not represented as a value anywhere (see Motivation).

## Relationship to Other RFCs

Touches the same class RFC 0007/0008/0009 already modified
(`PSScriptBuilderBumpReplacementHelper`), but only the mode-*detection* logic (which method to
call), not the replacement mechanics or the protected-span ledger those RFCs introduced - no
functional overlap. Follows the same "consolidate duplicated detection into a static Resolver
class" pattern already established for `PSScriptBuilderTemplateModeResolver` (Phase 1,
`refactor/template-engine-consolidation`, unrelated RFC but the direct architectural precedent).

## Test Plan

- New unit tests for `PSScriptBuilderBumpModeResolver` directly, independent of the three consumer
  classes: `DetermineBumpPatternMode` for a Placeholder-only pattern, a Regex/capture-group pattern,
  and a pattern matching neither (throws); `IsSimpleMode`/`IsItemsMode` for tokens present/absent/empty
  and items present/absent/empty.
- Non-regression: every existing test for `ApplyPatternReplacements`, `HasContentToReplace`,
  `PSScriptBuilderBumpFilesValidator`, and `PSScriptBuilderBumpFilesProcessor` continues to pass
  unchanged (behavior-preserving refactor).

## Unresolved Questions

None currently - decision, scope, and the resolver's method shapes are settled; only
implementation remains.

## Revision Log

- 2026-09-08 — Implemented. Added `PSScriptBuilderBumpPatternMode` enum and the static
  `PSScriptBuilderBumpModeResolver` class (`DetermineBumpPatternMode`, `IsSimpleMode`,
  `IsItemsMode`), verified against real scenarios before insertion. Converted all four call sites
  (`ApplyPatternReplacements`, `HasContentToReplace`, `PSScriptBuilderBumpFilesValidator`,
  `PSScriptBuilderBumpFilesProcessor`) to use it via `switch` (matching the enum-switch style used
  everywhere else in this codebase - `([EnumType]::Value)` expressions, not bare string literals,
  confirmed as the exclusive convention across every existing switch-on-enum in `src/`). Added a
  dedicated test file for the new Resolver, following the majority convention among comparable
  static utility classes (`PSScriptBuilderTextHelper`, `PSScriptBuilderFileSystemHelper`,
  `PSScriptBuilderFileIOHelper` all have one) rather than the precedent set by
  `PSScriptBuilderTemplateModeResolver` (which has none) - also added the missing test file for
  that class while at it, since the gap was noticed during this RFC's own design discussion. Full
  suite: 1910 passed, 0 failed.
- 2026-09-07 — Narrowed the enum to `PSScriptBuilderBumpPatternMode` (`Placeholder`, `Regex` only)
  after noticing the earlier three-value design never actually returned `Simple` from any method -
  the file-level Simple/Items question and the pattern-level Placeholder/Regex question are
  different granularities (object-shape vs. string-content) that do not belong in one enum.
  Confirmed "Mixed Mode" (`docs/guides/release-management.md`) is a documentation-only descriptive
  term for a composition of items, never computed anywhere in code, and does not need a value.
  Confirmed via `ValidateItemConfiguration` that the Validator has no third, hidden occurrence of
  the pattern-shape check. Resolver class keeps the broader name `PSScriptBuilderBumpModeResolver`
  (covering both questions) rather than being renamed to match the narrower enum, mirroring
  `PSScriptBuilderTemplateModeResolver`'s own precedent of not returning any equally-named enum.
- 2026-09-07 — Rewritten after discussion: the fix is a new static `PSScriptBuilderBumpModeResolver`
  class (mirroring `PSScriptBuilderTemplateModeResolver`), not just an enum plus a method on the
  existing Helper class - this also brought the previously-out-of-scope file-level `tokens`/`items`
  duplication (Validator + Processor) into scope, since a static resolver introduces no new
  dependency between those two classes, removing the earlier objection to unifying it. Boolean
  method names decided as `IsSimpleMode`/`IsItemsMode` (not `Has*`) after comparing directly against
  `PSScriptBuilderTemplateModeResolver`'s own `Has*`-for-supporting-fact vs. `Is*`-for-final-decision
  naming split.
- 2026-09-07 — Initial draft, written after verifying the exact duplication (byte-identical
  detection logic in `ApplyPatternReplacements`/`HasContentToReplace`) and confirming the related
  file-level check is behaviorally equivalent between its two existing copies (not a latent bug).
