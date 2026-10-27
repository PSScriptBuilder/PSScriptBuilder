# RFC 0018: Cross-Collector Same-Type Name Collision Silently Drops a Component

- **Status:** Implemented (2026-09-10)
- **Type:** Fix
- **Created:** 2026-09-09
- **Branch:** `fix/cross-collector-same-type-name-collision`

## Summary

Two components of the *same* type (e.g. two classes) sharing the same name - whether spelled
identically or differing only by case - but registered via *different* collectors are silently
collapsed into one during dependency analysis - one component's actual source code is completely
missing from the built output, with no error and no warning. The build reports success, and the
build result's own component count is misleading (it does not reflect what was actually rendered).
The case-differing spelling is not a precondition for the bug - it is merely how it was originally
found (see Motivation) - an identical spelling across two collectors triggers the exact same defect.

## Motivation

Found while answering a question during RFC 0017's review (whether the dependency-sort fix makes
the system "100% deterministic") - traced a residual, unrelated gap in cross-collector name
uniqueness checking.

**Verified: each collector's own duplicate check only sees its own scanned files.**
`PSScriptBuilderClassCollector` throws `InvalidOperationException` for a duplicate class name
*within the files it scans itself* (`PSScriptBuilderClassCollector.ps1:104-108`, using a
case-insensitive `ClassData` dictionary). Two *separate* Class collectors (e.g. one per directory)
each pass their own check independently - neither one ever sees the other's data.

**Verified: `PSScriptBuilderContentCollector.ValidateComponentNameUniqueness()` only guards
Class-vs-Function conflicts** (`PSScriptBuilderContentCollector.ps1:166-190`), never same-type
conflicts across collectors.

**Verified: `GetDefinedComponentNames()`'s case-insensitive `HashSet` (`PSScriptBuilderContentCollector.ps1:277`)
silently absorbs the collision** - reproduced directly: two Class collectors, one scanning a file
defining `class MyClass`, the other scanning a file defining `class myclass`:
```powershell
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'Dir1Classes' -IncludePath 'Dir1' |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'Dir2Classes' -IncludePath 'Dir2'
$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
# No error. TotalNodes: 1 (not 2) - one class vanished from the dependency graph entirely.
```

**Verified this is not merely a graph-node accounting issue - the actual rendered output silently
drops one class's entire source code**, while the build reports success with a misleading count:
```powershell
$result = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath '...' -OutputPath '...'
# Build Summary: succeeded. Component counts: Classes: 2 (misleading - only 1 was ever rendered)
# Actual output file content: only `class myclass { ... }` (from Dir2) - MyClass (Dir1) is
# completely missing, no warning anywhere.
```

**Verified PowerShell itself would reject the un-deduplicated case** (confirms this is a real
problem PSScriptBuilder must actively guard against, not a theoretical one): defining both
`class MyClass { ... }` and `class myclass { ... }` in one literal script produces a hard parser
error - `The member 'myclass' is already defined.` (`ParserError: MemberAlreadyDefined`). So the
*correct* behavior here is neither "silently keep one" nor "silently merge" - it should be a loud,
actionable validation error at collection/analysis time, mirroring the existing
within-collector and cross-type conflict checks.

## Detailed Design

The same-type check was first added directly inside
`PSScriptBuilderContentCollector.ValidateComponentNameUniqueness()`, then extracted into its own
class after a design review (see Revision Log): a new `PSScriptBuilderComponentNameValidator`
(`src/Classes/ScriptBuilder/Dependencies/PSScriptBuilderComponentNameValidator.ps1`), instantiated
with the `ContentCollector` and called from `PSScriptBuilderDependencyAnalyzer.Analyze()`'s Step 1:

```powershell
# Step 1: Validate component name uniqueness (same-type collisions, Class vs Function conflict)
$nameValidator = [PSScriptBuilderComponentNameValidator]::new($this.ContentCollector)
$nameValidator.Validate()
```

`Validate()` runs a same-type check, per type, then the Class-vs-Function check - each fully
delegated, so `Validate()` itself does nothing but orchestrate:

```powershell
[void] Validate() {
    $enumCollectors     = $this.ContentCollector.GetEnumCollectors()
    $classCollectors    = $this.ContentCollector.GetClassCollectors()
    $functionCollectors = $this.ContentCollector.GetFunctionCollectors()

    $this.ValidateNoCrossCollectorNameCollision($enumCollectors)
    $this.ValidateNoCrossCollectorNameCollision($classCollectors)
    $this.ValidateNoCrossCollectorNameCollision($functionCollectors)
    $this.ValidateNoClassFunctionNameCollision($classCollectors, $functionCollectors)
}
```

`ValidateNoCrossCollectorNameCollision(collectors)` (`hidden`) scans its collector group in a
single pass, tracking each name's source file in a running dictionary and throwing
`InvalidOperationException` - same style and severity as the Class-vs-Function check - as soon as a
name already in that dictionary is seen again from a different collector (classic single-pass
"seen-set" duplicate detection, replacing an earlier pairwise-nested-loop version - see Revision
Log). It derives the exception message's type label (e.g. "Class") directly from the colliding
collector's own `CollectorType` via the already-existing `[PSScriptBuilderTextHelper]::FormatCollectorType()`,
rather than taking it as a separate parameter - removing a redundant, independently-suppliable
argument that could in principle have been passed inconsistent with the actual collectors. It is a
no-op for a type with fewer than two registered collectors, so it costs nothing in the common case
(one collector per type). `ValidateNoClassFunctionNameCollision(classCollectors, functionCollectors)`
(`hidden`) first merges all Class collectors into one name-to-source-file dictionary (via
`Dictionary.Add()`, a defensive backstop - see Revision Log), then scans Function collectors against
it with the original, unchanged exception message.

A third `hidden` helper, `GetComponentDataForCollisionCheck(collector)`, returns the collector's
`EnumData`/`ClassData`/`FunctionData` dictionary via the same switch-on-`CollectorType` idiom
already used throughout `PSScriptBuilderContentCollector` (`GetDefinedComponentNames()`,
`GetDefinedComponentTypes()`, `GetProcessedFiles()`, etc.) - this lets
`ValidateNoCrossCollectorNameCollision()` be written once instead of three times (once per type),
without introducing dynamic/reflection-based property access, which this codebase avoids
elsewhere. The three dictionaries are typed differently
(`Dictionary[string, PSScriptBuilderEnumData]` etc.) but share the same shape needed here
(`.Keys`, `.ContainsKey()`, indexer, and each value's `.SourceFile`), so the helper's return type is
declared as the common non-generic `System.Collections.IDictionary`.

**Documented, intentionally not fixed:** when multiple independent collisions exist at once (three
or more same-type collectors, or more than one simultaneous Class-vs-Function pair), which one is
reported first, and the exact casing of the name in that report when two definitions spell it
differently, are both scan-order-dependent implementation details, not documented guarantees - see
Revision Log for the full reasoning (rejected as unneeded complexity for a cosmetic property, per
YAGNI and this project's established precedent from RFC 0017).

Answers to the three open questions from the original write-up:
- **Scope**: applies to Enum, Class, and Function collectors - the same three types
  `GetDefinedComponentNames()`/`GetDefinedComponentTypes()` already cover (RFC 0017). Using/File
  collectors are out of scope, unchanged from before - they are not graph nodes and were never
  part of this aggregation.
- **Location**: `PSScriptBuilderComponentNameValidator`, a new class in
  `src/Classes/ScriptBuilder/Dependencies/` - not `PSScriptBuilderContentCollector`. See Rationale
  and Alternatives for why this moved after the initial implementation. Same-name-*same*-case
  duplicates across collectors of the same type (the RFC's open question - see below) are caught
  by the identical mechanism, since the comparer is case-insensitive throughout.
- **Component-count logic**: needed no separate fix. The collision now throws during dependency
  analysis, before a build can run, so the misleading "Classes: 2" count described in the
  Motivation section can no longer occur.

## Rationale and Alternatives

**Rejected: a generic base-class accessor on `PSScriptBuilderCollectorBase`.** Considered adding a
`GetNames()`-style abstract method to the base class so a single loop could iterate any collector
type. Rejected: `PSScriptBuilderCollectorBase` currently has no such accessor (checked directly -
its abstract members are `Collect()`, `Reset()`, `ResetData()`, `TryGetComponentDetail()`,
`GetCount()`), and adding one only for this one validation would be a larger, cross-cutting change
to every collector subclass for a benefit only realized here. The switch-based
`GetComponentDataForCollisionCheck()` helper gets the same de-duplication with a much smaller,
localized footprint, consistent with how every other aggregating method in this class already
works.

**Rejected: string-based dynamic property access** (e.g. `$collector.("$($typeLabel)Data")`).
Would also collapse the three type-specific blocks into one, but this codebase consistently favors
explicit, typed switch-on-`CollectorType` dispatch over reflection-style dynamic member access
(see RFC 0017's rejection of `TryGetValue` for a related reason - preferring explicit, obviously
correct code over a marginally shorter but harder-to-verify alternative).

**Reconsidered and reversed: keeping the validation inside `PSScriptBuilderContentCollector`.**
The first implementation added the same-type check directly to
`ValidateComponentNameUniqueness()`, alongside the pre-existing Class-vs-Function check, both
staying on `PSScriptBuilderContentCollector`. A design review raised two issues: (1) the resulting
method mixed orchestration (three delegated same-type calls) with direct implementation (the
Class-vs-Function check inlined instead of delegated) - an inconsistent shape; (2) whether
`ContentCollector` was even the right home for this logic at all. Checking callers settled the
second question: `ValidateComponentNameUniqueness()` had exactly one production caller,
`PSScriptBuilderDependencyAnalyzer.Analyze()`, which already documents it as "Step 1" of its
seven-step analysis pipeline - directly alongside `PSScriptBuilderCycleDetector` (Step 4) and
`PSScriptBuilderCrossDependencyDetector` (Step 7), both small, focused, instance-based collaborator
classes living in `src/Classes/ScriptBuilder/Dependencies/`, constructed with exactly the data they
need and invoked with one method call. `PSScriptBuilderContentCollector`'s own docstring says it
"orchestrates collectors... by calling Collect()" - name-uniqueness validation over already-collected
data is a different responsibility, and the codebase already has a precedent for extracting exactly
this kind of thing into its own class (`PSScriptBuilderTemplateValidator`'s docstring states
verbatim: "This validator implements the Single Responsibility Principle by separating validation
logic from the TemplateProcessor's processing logic"). `PSScriptBuilderComponentNameValidator` was
added mirroring `PSScriptBuilderCrossDependencyDetector`'s exact shape (constructor takes and
null-checks the `ContentCollector`, stores it in a `hidden` property, one public method does the
work) since it lives in the same folder and is invoked the same way. The three validation methods
moved there wholesale; `ContentCollector` lost `ValidateComponentNameUniqueness()` entirely (not
kept as a delegating wrapper - there was exactly one caller to update, so a compatibility shim
would only have re-introduced the "wrong class" problem cosmetically).

## Scope

In scope: a new class `PSScriptBuilderComponentNameValidator`
(`src/Classes/ScriptBuilder/Dependencies/PSScriptBuilderComponentNameValidator.ps1`) with one
public method (`Validate()`) and three `hidden` helpers
(`ValidateNoCrossCollectorNameCollision()`, `ValidateNoClassFunctionNameCollision()`,
`GetComponentDataForCollisionCheck()`). `PSScriptBuilderContentCollector` loses
`ValidateComponentNameUniqueness()` and its two same-type helpers entirely; two docstring
cross-references (`GetDefinedComponentNames()`, `GetDefinedComponentTypes()`) now point to the new
class instead. `PSScriptBuilderDependencyAnalyzer.Analyze()`'s Step 1 is updated to construct and
call the new validator; its class-level and `Analyze()` docstrings, which still described Step 1 as
only the Class-vs-Function check (stale since the same-type check was first added), are corrected
in the same pass. No changes to `PSScriptBuilderCollectorBase` or any individual collector class.
Using/File collectors remain out of scope, as clarified in Detailed Design.

## Relationship to Other RFCs

Independent of RFC 0017 (dependency-sort determinism) - found while verifying RFC 0017's
determinism claim, but a different root cause (collection-time name validation, not sort-time
tie-breaking) in a different component (`PSScriptBuilderContentCollector` vs.
`PSScriptBuilderTopologicalSorter`).

## Test Plan

Five new `It` blocks were first added to `PSScriptBuilderContentCollector.Tests.ps1` (two Class
collectors defining the same class name case-insensitively throws; the same shape for two Function
collectors and two Enum collectors; distinct names across collectors does not throw; a single
collector of a type never throws). Confirmed red for the right reason first (`Should -Throw` failed
with "no exception was thrown", not a parse/type error) before implementing, then green after - full
suite 1957 passed, 0 failed, under PowerShell 5.1 via the project's own `tests\Invoke-Tests.ps1`
runner.

After the extraction into `PSScriptBuilderComponentNameValidator` (see Rationale and Alternatives),
all 9 `It` blocks (4 original Class-vs-Function + 5 same-type) moved to a new
`tests/Unit/ScriptBuilder/Dependencies/PSScriptBuilderComponentNameValidator.Tests.ps1`, each
rewritten from `{ $cc.ValidateComponentNameUniqueness() } | Should ...` to constructing
`[PSScriptBuilderComponentNameValidator]::new($cc)` and calling `.Validate()` - assertions
unchanged. Two new constructor tests were added, mirroring
`PSScriptBuilderCrossDependencyDetector.Tests.ps1`'s pattern: throws `ArgumentNullException` for a
null `ContentCollector`; stores the provided `ContentCollector` (accessible via the `hidden`
property in tests). Full suite after the extraction: 1959 passed, 0 failed (11 net new tests
overall: 9 moved + 2 constructor).

After restructuring both methods to single-pass dictionary scans (see Revision Log), two more `It`
blocks were added to the same test file, one per method, covering the multiple-simultaneous-collision
edge case found during that restructuring: three Class collectors with two independent
case-insensitive collisions (`ConflictX` shared by collectors 1 and 3, `ConflictY` shared by
collectors 1 and 2); two Class collectors and two Function collectors sharing two independent names
(`ConflictX`, `ConflictY`) between them. Both assert only `Should -Throw '*Component name conflict*'`
- the generic message pattern - deliberately not a specific name or file pair, since which of the
several genuine collisions is reported first is documented as scan-order-dependent, not a
guarantee (see Detailed Design). Full suite after this round: 1961 passed, 0 failed.

Verified end-to-end against a real built module three times - once against the first (in-place)
implementation, once after the extraction into its own class, once more after restructuring both
methods to single-pass scans - with identical results each time (a `MyClass`/`myclass` collision
still throws `InvalidOperationException` naming both source files, distinct names still succeed
with `TotalNodes: 2`) aside from the disclosed, expected casing difference in the third round (see
Revision Log). The legitimate multi-directory pattern (as used by
[Example 10](../../examples/10-multiple-collectors/)) was reconfirmed unaffected by running
Example 10's own `Demo-Module.ps1` and Example 13's `Run-Example.ps1` (which uses three simultaneous
Class collectors) after each round.

The first side-by-side old-vs-new simulation (see Revision Log) itself surfaced a tooling gotcha
worth recording: comparing the two algorithms' exception messages with PowerShell's default `-eq`
operator on strings reported them as identical for the `MyClass`/`myclass` scenario, because `-eq`
on strings is case-insensitive by default - masking the real casing difference that the subsequent
live end-to-end run then exposed. A harness bug, not a product bug, but a reminder that a
verification tool's own comparison semantics need the same scrutiny as the code it verifies.

A gap was then raised during review of the CHANGELOG wording (see Revision Log): every existing
"same-type collision" test used a case-*differing* pair (`MyClass`/`myclass`) - none exercised two
collectors defining the exact same name with *identical* spelling, even though that is logically
guaranteed by the same case-insensitive `Dictionary` mechanism and is, if anything, the more
realistic real-world trigger (e.g. an overlapping `IncludePath` or a copied file) than a deliberate
casing difference. Verified directly (first informally, then via a proper regression test) that an
identical-spelling collision across two Class collectors was already correctly caught - added
`'Should throw InvalidOperationException when two Class collectors define the exact same class name
(identical spelling)'` to lock this in permanently. Full suite after this addition: 1962 passed,
0 failed.

Before the extraction, every caller of the method being removed was located via a full-repository
grep for `ValidateComponentNameUniqueness`, `GetComponentDataForCollisionCheck`, and
`ValidateNoCrossCollectorNameCollision`: confirmed no reference anywhere under `src/Public/` (the
cmdlet layer only ever calls `PSScriptBuilderDependencyAnalyzer.Analyze()`, never the ContentCollector
method directly) or `scripts/`, and confirmed no test uses the `Should-HaveMethod` custom matcher
against `PSScriptBuilderContentCollector` (which would have asserted its exact method surface and
broken on removal).

## Unresolved Questions

None remaining - see Detailed Design for how each item from the original write-up was resolved.

## Revision Log

- 2026-09-10 — Corrected the CHANGELOG entry and this RFC's own Summary, both of which read as if
  a case *difference* between the two colliding names were a precondition for the bug, when the
  actual condition is simply the same name (identically spelled or differing only by case)
  registered via two collectors of the same type - the case-differing example was only ever how the
  bug happened to be discovered (see Motivation), never the defining trigger. Raised during review
  of the CHANGELOG wording. Verified directly that an identical-spelling collision was already
  correctly caught by the existing fix (case-insensitive matching also matches identical strings by
  definition), then added a dedicated regression test for it, since every prior test for this shape
  happened to use a case-differing pair - see Test Plan. Full suite: 1962 passed, 0 failed.
- 2026-09-10 — Restructured both validation methods from nested loops to single-pass dictionary
  scans, following a design question about `ValidateNoClassFunctionNameCollision()`'s three levels
  of nested `foreach`. `ValidateNoCrossCollectorNameCollision()` now scans its collector group once,
  tracking each name's source file in a running dictionary and throwing as soon as a name already
  in it is seen again (classic single-pass "seen-set" duplicate detection) - reduces
  O(collectors × names × collectors) to O(names), and needs no assumption about call order since it
  detects its own duplicates from scratch. `ValidateNoClassFunctionNameCollision()` first merges all
  Class collectors into one name-to-source-file dictionary via `Dictionary.Add()` (not indexer
  assignment) - `Add()` is a defensive backstop that fails loudly if two Class collectors ever did
  share a name at this point, instead of silently overwriting one's source file with the other's;
  in normal operation `ValidateNoCrossCollectorNameCollision()` already guarantees this can't happen,
  by call order in `Validate()`. The real Class-vs-Function detection stayed an explicit
  `ContainsKey()` check with the original exception message, never delegated to `Add()`'s own
  message - verified empirically first that `Dictionary.Add()`'s exception, as thrown from inside a
  compiled PowerShell class method, surfaces as a `MethodInvocationException` wrapping a plain
  `ArgumentException` whose message does not include the key name, which would have broken every
  existing `Should -Throw '*Name*'` test had it been relied on for the primary detection path.
  Also removed the `$typeLabel` string parameter from `ValidateNoCrossCollectorNameCollision()` -
  raised during review as redundant, derivable data (every collector already carries its own
  `CollectorType`, so passing a hand-written label for the same information was both duplication and
  a latent risk of a mismatched label going undetected) - now derived at the throw site via the
  already-existing `[PSScriptBuilderTextHelper]::FormatCollectorType()`, found via a repo search
  during review rather than reintroducing a bespoke mapping.

  Empirically verified via a side-by-side old-vs-new simulation harness (not just re-running the
  existing suite) across all 11 real test scenarios plus deliberately adversarial edge cases - found
  and disclosed two genuine, cosmetic-only behavioral differences from the prior (already-shipped
  same day) implementation, both accepted and documented rather than fixed: (1) when three or more
  same-type collectors have multiple *independent* simultaneous collisions, which one is reported
  first differs between the old and new algorithm (both always throw; neither ever misses a real
  collision or reports a false one) - added two new tests (`PSScriptBuilderComponentNameValidator.Tests.ps1`)
  for this shape, asserting only the generic exception message pattern, deliberately not the specific
  name/file pair, since that pair is not a documented guarantee. (2) When two collectors spell a
  colliding name with different casing, the exact spelling echoed in the exception message changed
  (from always the earlier-registered collector's spelling, to always the collector whose scan
  triggers the match) - both source file paths are always still named correctly regardless; adding a
  tuple-based fix to pin this down was considered and explicitly rejected as unnecessary complexity
  (YAGNI) for a purely cosmetic property that was never a documented contract, consistent with this
  project's established preference (see RFC 0017) for not trading real simplicity for imperceptible
  or cosmetic gains. Full suite after these changes: 1961 passed, 0 failed; re-verified end-to-end a
  third time against a real built module with identical (aside from the disclosed casing point)
  results to the previous two rounds.
- 2026-09-10 — Extracted validation into a new `PSScriptBuilderComponentNameValidator` class
  (`src/Classes/ScriptBuilder/Dependencies/`), following a design review that raised two concerns
  about the first implementation: `ValidateComponentNameUniqueness()` mixed orchestration
  (delegated same-type calls) with direct implementation (the inlined Class-vs-Function check),
  and `PSScriptBuilderContentCollector` was the wrong home for this validation altogether. See
  Rationale and Alternatives for the full analysis (precedent: `PSScriptBuilderCrossDependencyDetector`'s
  exact shape; `PSScriptBuilderTemplateValidator`'s explicit SRP precedent) and Test Plan for how
  the tests moved. Also corrected two stale docstrings on `PSScriptBuilderDependencyAnalyzer`
  (class-level and `Analyze()`) that still described Step 1 as only the Class-vs-Function check,
  an inaccuracy introduced by - but not caught during - the first implementation. Re-verified
  end-to-end and against Examples 10 and 13 after the extraction; full suite 1959 passed, 0 failed.
- 2026-09-10 — Implemented, verified, tests added (Status: Draft to Implemented). Extended
  `ValidateComponentNameUniqueness()` with a same-type, cross-collector check
  (`ValidateNoCrossCollectorNameCollision()` + `GetComponentDataForCollisionCheck()`, both new
  `hidden` methods), covering Enum, Class, and Function collectors. Considered and rejected two
  alternatives (a new generic base-class accessor; string-based dynamic property access) in favor
  of the existing switch-on-`CollectorType` idiom already used throughout this class - see
  Rationale and Alternatives. Verified via 5 new unit tests (regression-test-first: confirmed red
  for the right reason before implementing) and an end-to-end repro against a real built module,
  matching the Motivation section's exact scenario.
- 2026-09-09 — Logged for follow-up (Status: Draft, not started). Found and reproduced the core
  problem (cross-collector, case-differing, same-type name collision silently drops a component
  from the build output despite the build reporting success) while answering a determinism
  question during RFC 0017's review. Full investigation deferred - RFC 0017 is being finished
  first.
