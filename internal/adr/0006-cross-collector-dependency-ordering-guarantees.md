# ADR 0006: Cross-Collector Dependency Ordering Guarantees

## Status
**Accepted**

Date: 2026-08-28

## Context

`docs/guides/collectors.md`'s "Cross-Collector Dependencies" section claims, without distinguishing
between dependency causes, that a wrong template placeholder order "generates a script that fails
at runtime with a `type-not-found` error." This claim was written to cover all four causes tracked
by `PSScriptBuilderClassData`/`PSScriptBuilderFunctionData`: `BaseClass` (inheritance),
`TypeReferences`, `StaticInitializerReferences`, and `CalledFunctions`.

While reviewing this section for accuracy, the question arose whether this blanket claim is
actually true for all four causes, or whether `PSScriptBuilderCrossDependencyDetector`'s existing
asymmetric treatment — only Function→Class transitions in the topological sort are treated as
"genuine" cross-dependencies requiring Ordered Mode, per its own code comment — reflects a real,
narrower risk that the documentation should describe more precisely instead of overgeneralizing.

This ADR records an empirical investigation into the actual PowerShell runtime behavior for each
dependency cause, to confirm whether the current detection/warning/auto-mode logic in
`PSScriptBuilderCrossDependencyDetector` and `PSScriptBuilderBuildOrchestrator.WarnCrossCollectorDependencies`
is correctly calibrated, or whether it represents a design gap.

## Investigation

Verified via real `Invoke-PSScriptBuilderBuild` runs (not just isolated PowerShell snippets) under
**both** Windows PowerShell 5.1 and PowerShell 7.6.5 — the two runtimes the module manifest
declares support for (`PowerShellVersion = '5.1'`, `CompatiblePSEditions = @('Desktop', 'Core')`).
Results were identical across both versions for every scenario tested.

| Dependency cause | Free Mode build with wrong placeholder order | Actual runtime consequence |
|---|---|---|
| **Inheritance** (`class A : B`) | Succeeds with `SyntaxValid: True` and an advisory warning — the post-build syntax check cannot catch this (see below) | **Real failure**: `ParseException: Unable to find type [B]` when the output script loads |
| **TypeReferences** (property/parameter type, non-inheritance) | Succeeds, advisory warning only | No failure — PowerShell resolves the type reference lazily once the whole script has loaded |
| **StaticInitializerReferences**, one-directional | Succeeds, advisory warning only | No failure — confirmed with both a static property typed as the forward-referenced class and a static initializer calling a forward-referenced static method |
| **CalledFunctions** (a class method/initializer calls a function) | **Build fails outright** — `PSScriptBuilderCrossDependencyDetector.HasCrossDependencies()` flags the Function→Class transition and the template validator then requires `{{ORDERED_COMPONENTS}}` | With Ordered Mode, the function is placed before the class automatically; output runs correctly |
| **Any cause, when genuinely circular/mutual** (e.g. two classes' static initializers reference each other) | **Build fails outright** — `PSScriptBuilderCycleDetector` finds the cycle during dependency analysis (`Circular dependency detected: A -> B -> A`) | Never reaches the user as a built script at all |

The circular case is the most consequential finding: a hand-written PowerShell repro of two classes
with mutually-referencing static field initializers does **not** throw an error — it silently
produces **wrong values**, because .NET resolves the two types' static constructors in an order
that does not match their textual position in the file (observed: the physically-second class's
static initializer actually ran first). PSScriptBuilder's own build-time cycle detection prevents
a user from ever producing this specific script in the first place.

## Decision

No code changes. The existing behavior is correct and already calibrated to the real risk:

- The Free Mode advisory warning fires for any cross-collector edge, regardless of cause — broader
  than strictly necessary, but harmless (advisory only).
- `HasCrossDependencies()`'s Function→Class-only trigger for automatic Ordered Mode is correct: it
  is the one non-inheritance case where a naive Free Mode ordering could not otherwise guarantee
  correctness, so PSScriptBuilder removes the burden from the user entirely.
- Genuine circular dependencies, regardless of which of the four causes produced them, are caught
  by `PSScriptBuilderCycleDetector` before a script is ever produced.

`docs/guides/collectors.md` and `docs/guides/dependency-analysis.md` both made this
overgeneralization and should be (or have been) corrected to describe this differentiated
behavior instead of a single blanket "wrong order fails at runtime" claim.

`dependency-analysis.md` additionally claimed that PSScriptBuilder's own post-build syntax
validation would catch a wrong-order inheritance case ("the build will fail with a syntax
validation error before the script is ever used... If `-SkipSyntaxValidation` is set, the
invalid script is written to disk and will fail at load time"). This is incorrect regardless of
`-SkipSyntaxValidation`: `PSScriptBuilderBuildOrchestrator.ValidateSyntax()` parses the output
with `[Parser]::ParseFile()` (a pure grammar parse, no type resolution) and deliberately filters
out `TypeNotFound` parse errors via `GetStructuralParseErrors()` — by design, since a
`TypeNotFound` error is also produced for legitimate external-assembly type references that
are valid at runtime but unavailable at build time. The build's syntax check can never
distinguish that legitimate case from a genuine cross-collector inheritance ordering bug, so it
always reports `SyntaxValid: True` for both — confirmed via a real build. The Free Mode advisory
warning is therefore the *only* safety net for the inheritance case; there is no build-time
fallback that would catch it if the warning is ignored.

## Rationale

### Why the current detection logic needs no changes

1. **Inheritance is the only cause with a genuine Free-Mode ordering requirement**, because
   PowerShell resolves a class's base type during parsing of the `class X : Y` statement itself,
   not lazily. This is the one case the warning's message ("script fails at runtime") is literally
   true for.
2. **Type references and non-circular static initializer references resolve lazily** — a
   PowerShell class's property/parameter type annotations and static initializer expressions are
   evaluated only once the type is actually used or its static constructor runs, which in a
   PSScriptBuilder-assembled script happens after the entire file has loaded, regardless of
   physical ordering.
3. **Called-function dependencies are exactly the case `HasCrossDependencies()` already singles
   out** for mandatory Ordered Mode. This matches the real risk precisely: a function call inside
   a class method body is late-bound and would actually be safe in any order too, but forcing
   Ordered Mode here is a low-cost simplification that also correctly handles any future
   Class-Function-Class multi-hop chains without further special-casing.
4. **Circular dependencies are the one scenario where silent corruption (not a clean error) is
   possible**, per the mutual static-initializer repro. `PSScriptBuilderCycleDetector` already
   blocks these unconditionally at build time, independent of which dependency cause created the
   cycle — this is the actual safety net that matters most, and it already exists and works
   correctly.

### Why not tighten the Free Mode warning to only fire for inheritance

Precisely modeling PowerShell's class-compilation resolution order inside PSScriptBuilder would
require relying on CLR/PowerShell internals that are not a documented, stable contract. A broader,
conservative advisory warning costs nothing (it never blocks a build) and remains correct even if
future PowerShell versions change laziness guarantees for non-inheritance cases.

## Alternatives Considered

1. **Narrow the Free Mode warning to inheritance-only edges** — rejected: no meaningful benefit
   (the warning is advisory, not blocking) and adds fragility by depending on undocumented
   PowerShell internals for a distinction that provides no actual safety improvement.
2. **Remove automatic Ordered Mode triggering for Function→Class edges**, since a single such edge
   in isolation does not actually fail at runtime — rejected: Ordered Mode handles any future
   multi-hop Class/Function chains transparently, and removing the auto-trigger would only save the
   user from adding one placeholder while reintroducing an ordering concern PSScriptBuilder
   currently eliminates entirely.

## Consequences

### Positive
- Confirms the existing cross-collector dependency detection, warning, and auto-mode logic
  requires no code changes — it already matches the real risk correctly.
- Documents precisely which of the four tracked dependency causes carry genuine runtime risk in
  Free Mode (inheritance only), which are effectively safe regardless of order (type references,
  one-directional static initializer references), and which PSScriptBuilder actively prevents from
  ever reaching a broken build (called-functions via forced Ordered Mode; genuine circular
  dependencies of any cause, via build-time cycle detection).
- Grounds future documentation and maintenance decisions in verified, reproducible evidence
  (tested under both supported PowerShell editions) rather than assumption.

### Negative
- The Free Mode advisory warning remains broader than strictly necessary — accepted as a
  negligible cost for a conservative, low-maintenance warning that does not depend on modeling
  undocumented PowerShell internals.

## Related Decisions

- ADR 0004: Dependency Graph Edge Direction Convention
