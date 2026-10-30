# RFC 0017: Cross-Dependency Detection False Positive for Independent Components

- **Status:** Implemented (2026-09-09)
- **Type:** Fix
- **Created:** 2026-09-09
- **Branch:** `fix/cross-dependency-false-positive`

## Summary

`PSScriptBuilderDependencyAnalyzer`'s `HasCrossDependencies` result can be `$true` even when a
project's classes and functions have zero actual dependency edges between them. When this
happens, `Invoke-PSScriptBuilderBuild` incorrectly forces Ordered Mode and fails any template
using the default Free Mode placeholder layout (`{{CLASS_DEFINITIONS}}`/`{{FUNCTION_DEFINITIONS}}`)
with `Template validation failed: In cross-dependencies mode, template MUST contain placeholder
'{{ORDERED_COMPONENTS}}'` - for a project that has no real cross-dependency at all. The condition
is silent and non-obvious: it depends on the internal enumeration order of a `HashSet[string]`,
not on anything in the user's code.

**This is not a Free-Mode-only issue.** The build *failure* only ever surfaces for a Free-Mode-shaped
template (no `{{ORDERED_COMPONENTS}}` placeholder) - a Hybrid/Ordered-Mode-shaped template never
errors either way. But `HasCrossDependencies` also determines the template's *mode
classification* (Ordered vs. Hybrid) and, independently of that, `OrderedComponents` (the same
list, computed identically regardless of mode) determines the literal component order written into
the merged output file. Both are affected in Ordered/Hybrid-Mode builds too, whenever independent
components are involved - verified directly (see Motivation): the identical project, built with an
`{{ORDERED_COMPONENTS}}` template, is classified `Ordered` before this fix and `Hybrid` after, with
a different component order in the actual output file in both cases - even though neither build
ever fails.

While investigating, found this is one symptom of a broader gap: the sorter has no explicit,
deterministic tie-break for *any* components with no forced relative order (not just
Class/Function pairs - two independent classes, or two independent functions, are equally affected,
just without an observable build failure since Free Mode does not care about intra-bucket order).
This RFC's fix addresses both: the reported false positive, and the underlying missing tie-break
that causes it.

## Motivation

Found while reviewing `docs/guides/tool-integrations.md`'s Pester example, which builds a scratch
project with one independent class (`MyClass`) and one independent function (`Get-MyData`) - no
relationship between them at all.

**Verified: two completely independent components can trigger a false positive**, using the
project's own existing test fixtures (`ClassA`, `ClassB`, `Get-FuncA` -
`tests\TestData\Classes\ClassA.ps1`/`ClassB.ps1`, `tests\TestData\Functions\FuncA.ps1` - all three
already used elsewhere in the test suite):

```powershell
$classCollector = [PSScriptBuilderClassCollector]::new('Classes')
$classCollector.IncludeFiles = @("$ClassesPath\ClassA.ps1", "$ClassesPath\ClassB.ps1")
$funcCollector = [PSScriptBuilderFunctionCollector]::new('Functions')
$funcCollector.IncludeFiles = @("$FuncsPath\FuncA.ps1")
# ... registered on a ContentCollector, executed, then:
$result = $analyzer.Analyze()
# OrderedComponents: Get-FuncA, ClassB, ClassA
# TotalEdges: 0
# HasCrossDependencies: True
```

Confirmed this is not incidental to these specific names: renaming `ClassA`/`ClassB` (tested with
`AClass`/`BClass`), and reversing collector registration order (Function collector registered
before the Class collector), both produced the identical result. Also confirmed with 2 independent
functions + 1 independent class (`FuncA`, `FuncB`, `AClass` all unrelated) - same outcome
(`HasCrossDependencies: True`, `TotalEdges: 0`).

**Verified this reaches a real build failure**, not just the analyzer result: building a scratch
project with these exact two components (`MyClass`, `Get-MyData`, no relationship) against the
default Free Mode template scaffolded by `New-PSScriptBuilderProject` fails with:
```
Template validation failed: In cross-dependencies mode, template MUST contain placeholder
'{{ORDERED_COMPONENTS}}'.
```

**Verified this is stable, not randomized per process**: ran the same repro 3 times in separate
`powershell.exe` process launches - identical result every time. The order is not alphabetical, not
collector-registration order, but it is deterministic within a given build of the module.

**Verified the same-type case is also affected, confirming this is a general missing-tie-break
problem, not specific to Class/Function pairs:** two mutually-independent classes (`ClassA`,
`ClassB`, no edges to anything), scanned in reverse file order, produce the exact reverse final
component order:
```
IncludeFiles: ClassA.ps1, ClassB.ps1 -> OrderedComponents: ClassB, ClassA
IncludeFiles: ClassB.ps1, ClassA.ps1 -> OrderedComponents: ClassA, ClassB
```
No build failure results from this (Free Mode does not care about intra-bucket order), but it
confirms the underlying mechanism - an unconstrained tie resolved by incidental enumeration order,
then a full-list reversal - affects same-type ties identically to cross-type ties.

**Verified the impact on Ordered/Hybrid Mode directly, before committing** (raised explicitly
during review whether this fix is Free-Mode-only - it is not): built the identical project (two independent
classes `AppleClass`/`ZebraClass`, one independent function `Get-MyData`) against a template
containing only `{{ORDERED_COMPONENTS}}` (an Ordered/Hybrid-Mode-shaped template), once with the
pre-fix module (via `git stash`) and once with the fix:
```
Pre-fix:  OrderedComponents: Get-MyData, ZebraClass, AppleClass | HasCrossDependencies: True  | Mode: Ordered
Post-fix: OrderedComponents: AppleClass, ZebraClass, Get-MyData | HasCrossDependencies: False | Mode: Hybrid
```
Both builds succeeded (neither template shape ever hit the reported failure), but the actual
rendered output file differs:
```
Pre-fix:                              Post-fix:
function Get-MyData { return 42 }     class AppleClass { [string] $Name }
                                       
class ZebraClass { [string] $Name }   class ZebraClass { [string] $Name }
                                       
class AppleClass { [string] $Name }   function Get-MyData { return 42 }
```
Confirms this fix changes observable behavior (mode classification and literal output order) for
Ordered/Hybrid Mode projects with independent components too, not only Free Mode ones - though
only Free Mode was ever capable of an outright build *failure* from this bug.

**Verified real (non-independent) dependencies are unaffected - this is specifically a
zero-edge problem:**
- A function genuinely depending on a class (e.g. `Get-MyData` taking a `[RealDep]` parameter):
  `OrderedComponents: RealDep, Get-MyData`, `TotalEdges: 1`, `HasCrossDependencies: False` -
  correct, since Free Mode's fixed class-then-function placeholder layout already satisfies this.
- A class genuinely depending on a function (`ClassCallsFuncA.Run()` calls `Get-FuncA` - existing
  fixture, existing passing test): `OrderedComponents: Get-FuncA, ClassCallsFuncA`, `TotalEdges: 1`,
  `HasCrossDependencies: True` - correctly detected and unaffected by anything in this RFC.

**Verified the existing test suite has zero coverage for the zero-edge case:**
`PSScriptBuilderCrossDependencyDetector.Tests.ps1` unit-tests `HasCrossDependencies(orderedComponents)`
in complete isolation, feeding it hand-written arrays (e.g. `@('Get-Func', 'ClassA')`) as if that
order were simply given - it never exercises the real topological sorter that produces this order,
so it cannot catch the sorter producing a spurious order for edge-free components.
`PSScriptBuilderDependencyAnalyzer.Tests.ps1`'s existing `Context 'Analyze - no cycles, correct
ordering'` block already registers `ClassA`, `ClassB`, and `Get-FuncA` together (all mutually
independent) in `'Should include all components in OrderedComponents'` - but that test only
asserts `-Contain`, never `HasCrossDependencies`. The exact repro fixture already existed in the
suite; nothing asserted on the property that is wrong.

**Added a regression test, confirmed red, then confirmed it is the only failure in the full
suite**, run under PowerShell 5.1 (`5.1.26100.8875`, this project's standard test runtime) via
`tests\Invoke-Tests.ps1 -Suite Unit`:
```
Tests Passed: 1852, Failed: 1, Skipped: 0
Failed Tests (1):
  [-] Should return HasCrossDependencies = false when classes and functions are completely independent
      Expected $false, but got $true.
```

**Verified the full two-level tie-break design (type priority + alphabetical) with a standalone
prototype**, mirroring the real in-degree/queue/reversal mechanics exactly (not the real source),
across 8 scenarios plus a control:
```
[MultiIndependentClasses]     Apple, Mango, Zebra                                  PASS
[MultiIndependentFunctions]   Get-Apple, Get-Zebra                                 PASS
[MixedIndependent]            Apple, Zebra, Get-Apple, Get-Zebra                    PASS
[RealClassDependsOnFunc]      Get-FuncA, ClassCallsFuncA                           PASS (unaffected)
[RealFuncDependsOnClass]      RealDep, Get-MyData                                  PASS (unaffected)
[CrossTypeTransitive]         FuncG, ClassC, ClassD, FuncH                         PASS
[SameTypeTransitive]          ClassA, ClassB, ClassY, ClassX                       PASS
[FullCombinedStress]          ClassA, FuncG, ClassC, ClassD, ClassM, FuncH, FuncZ  PASS
Control (ascending, wrong direction): Zebra, Mango, Apple -> FAIL, as expected
```
`SameTypeTransitive` is the critical proof: `ClassX : ClassY` (real inheritance, `ClassY` must
precede `ClassX`) - alphabetically `ClassX` < `ClassY`, the *opposite* of the required real order,
deliberately chosen to catch a tie-break that applies alphabetical order too broadly. Result
correctly places `ClassY` before `ClassX`, because the two are never simultaneously ready (`ClassX`
only becomes ready once `ClassY` is already processed) - the tie-break never applies between them.

**Verified both Class→Function and Function→Class real dependencies together, including chains
that flip direction more than once** (raised explicitly: a class can require a function and a
function can require a class, and both can occur in the same project):
```
[AlternatingDirectionChain]    ClassC, FuncB, ClassA               PASS
  ClassA -> FuncB (Class needs Function) -> ClassC (Function needs Class): direction flips twice.
[BothDirectionsSimultaneously] FuncQ, ClassP, ClassS, ClassZ, FuncR, FuncW  PASS
  ClassP->FuncQ and FuncR->ClassS present together, unrelated to each other, plus independent noise.
[SharedFunctionMultipleFlips]  ClassBase, FuncShared, ClassA, ClassOther   PASS
  Two classes both call the same function, which itself needs a third class.
```
`AlternatingDirectionChain` was additionally cross-checked against the real, current (unfixed)
module with actual PowerShell classes/functions (not just the prototype): `ClassC` (base),
`FuncB` (`param([ClassC] $Item)`, i.e. Function→Class), `ClassA` (`[void] Run() { FuncB }`, i.e.
Class→Function) - real result `ClassC, FuncB, ClassA`, `TotalEdges: 2`, matching the prototype
exactly. This case has no ties at all (every step is fully constrained by a real edge), so it
already works correctly today - confirms the prototype's mechanics faithfully mirror the real
module, including for a direction-flipping chain not otherwise covered by existing tests.

**Verified the full pipeline - the new two-level tie-break followed by the existing
`StabilizeEnumsFirst` - composes correctly with Enums in the mix**, previously untested:
```
[AllThreeTypesIndependent]         StatusEnum, MyClass, Get-MyData                     PASS
[MultipleOfEachTypeIndependent]    AppleEnum, ZebraEnum, AClass, ZClass, Get-Apple, Get-Zebra  PASS
[ClassUsesEnum-RealEdge]           StatusEnum, ClassUsesEnum                           PASS
[EnumNoExplicitDependency]         StatusEnum, ClassA                                  PASS
[FullCombinedWithEnums]            OtherEnum, StatusEnum, FuncG, ClassC, ClassD,
                                    ClassIndependent, ClassUsesEnum, FuncIndependent    PASS
```
The last scenario combines everything verified in this RFC in one graph: two independent enums, a
real enum→class dependency, a real cross-type chain (`FuncG -> ClassC -> ClassD`), and independent
classes/functions of both types - all resolve correctly together.

## Detailed Design

### Root Cause

Traced through the real, unmodified source, in call order:

1. `PSScriptBuilderContentCollector.GetDefinedComponentNames()`
   (`PSScriptBuilderContentCollector.ps1:277-296`) aggregates every enum/class/function name into a
   single `HashSet[string]` with `[StringComparer]::OrdinalIgnoreCase`.
2. `PSScriptBuilderDependencyGraphBuilder.Build()` (`PSScriptBuilderDependencyGraphBuilder.ps1:84-118`)
   processes real edges first (`ProcessClassDependencies`/`ProcessFunctionDependencies`), then, at
   line 104, registers every remaining component with no edges as an isolated graph node by
   enumerating that same `HashSet[string]`:
   ```powershell
   foreach ($componentName in $this.CurrentDefinedComponents) {
       $this.CurrentGraph.AddNode($componentName)
   }
   ```
   For components with zero edges, this `HashSet` enumeration order - not registration order, not
   alphabetical order - is the *only* thing that determines their relative node order in the graph.
3. `PSScriptBuilderTopologicalSorter.RunKahnsAlgorithm` (`PSScriptBuilderTopologicalSorter.ps1:179-228`)
   seeds its initial zero-in-degree FIFO queue by enumerating `$graph.GetAllNodes()`
   (`PSScriptBuilderDependencyGraph.ps1:261-277`, itself a `HashSet[string]`) - for edge-free nodes,
   this directly inherits the same indeterminate order from step 2, with no tie-breaking logic at
   all (unlike enums, which get an explicit, dedicated stabilization pass afterward).
4. `PSScriptBuilderCrossDependencyDetector.HasCrossDependencies` (`PSScriptBuilderCrossDependencyDetector.ps1:73-135`)
   scans the final sorted list for any Function-then-Class adjacency and reports it as a
   cross-dependency, *regardless of whether a real edge caused that adjacency*. For edge-free
   components, this adjacency is pure artifact of steps 1-3, not a real constraint - the detector
   has no way to distinguish "the sorter was forced into this order by a real edge" from "the
   sorter had complete freedom and happened to land here."

`StabilizeEnumsFirst` (`PSScriptBuilderDependencyAnalyzer.ps1:243+`) already solves an analogous
problem for enums unconditionally - safe there because an enum can never depend on anything,
so moving it earlier can never violate a real constraint. The equivalent safety property does not
hold for classes and functions, which can depend on each other in *either* direction (see next
section) - the current code has no stabilization step for them at all.

Note that steps 1-3 apply identically regardless of component type: any set of mutually-independent
components (two classes, two functions, or a mix) has its relative order determined the same
incidental way. Step 4 (`CrossDependencyDetector`) is what turns this into an observable *failure*
specifically for the Class/Function case - the same-type case produces no error, only an
unspecified (but equally undesirable) final ordering.

### Decision

Fix the tie-break used by `PSScriptBuilderTopologicalSorter.RunKahnsAlgorithm`
(`PSScriptBuilderTopologicalSorter.ps1:179-228`) itself, rather than reordering its output
afterward. This is the standard technique used by comparable tools that face the same
non-determinism (module bundlers such as Webpack/Rollup/esbuild, and package managers, all
implement a **stable topological sort** for exactly this reason): when multiple nodes are
simultaneously eligible (zero in-degree) and the graph does not constrain their relative order,
break the tie using a fixed, meaningful secondary key instead of leaving it to an incidental data
structure enumeration order.

**API change required (found during final pre-implementation review):** `PSScriptBuilderTopologicalSorter`
operates on `PSScriptBuilderDependencyGraph`, which has no concept of component *type* at all - its
nodes are plain strings, and edges carry only `PSScriptBuilderDependencyEdgeType` (Inheritance,
TypeReference, FunctionCall, StaticInitializer), never a node-type label. Confirmed by reading
`PSScriptBuilderTopologicalSorter.Tests.ps1` in full: it constructs graphs and asserts on them with
no Class/Function distinction whatsoever. The type-priority tie-break therefore cannot be
implemented purely inside `RunKahnsAlgorithm` as originally scoped - the sorter needs to be told
which nodes are Classes and which are Functions.

Add a second constructor overload,
`PSScriptBuilderTopologicalSorter([PSScriptBuilderDependencyGraph] $graph, [Dictionary[string,PSScriptBuilderCollectorType]] $nodeTypes)`,
alongside the existing single-argument one (this project's own established, already-used pattern for
optional-parameter constructors - e.g. `PSScriptBuilderClassCollector`'s parameterless vs.
`[string] $collectionKey` constructors). `PSScriptBuilderDependencyAnalyzer.SortTopologically`
(`PSScriptBuilderDependencyAnalyzer.ps1:180-188`, the only real production call site) builds this
map from `$this.ContentCollector.GetClassCollectors()`/`.GetFunctionCollectors()` (both already
public, confirmed in `PSScriptBuilderContentCollector.ps1:497,511`) and passes it through. When no
map is supplied (the existing single-argument constructor), `RunKahnsAlgorithm` falls back to
today's untyped, arrival-order behavior exactly as now - **verified this is safe**: read all 17
existing tests in `PSScriptBuilderTopologicalSorter.Tests.ps1`; none assert a specific order among
genuinely tied (edge-free or type-agnostic) nodes - every ordering assertion in that file is on
nodes fully constrained by real edges, which the tie-break never touches regardless of whether type
information is available.

The "stuck node" sub-graph pass for TypeReference cycles (`Sort()`,
`PSScriptBuilderTopologicalSorter.ps1:89-137`) re-invokes the same `RunKahnsAlgorithm` on a
different graph instance; storing the type map as an instance field (set once via the constructor)
means this sub-graph pass automatically benefits from the identical, already-proven tie-break logic
with no separate change needed. In practice this rarely matters for the Class/Function type
priority specifically - `TypeReference` edges can only target Classes/Enums (functions are never
referenced as a `[Type]`), so a "stuck" cycle can only ever involve Classes (and/or Enums) - but the
alphabetical same-type tie-break could still apply there, and composes correctly by the same
argument as the main pass (see "Why this resolves the transitive-ordering question" below).

Concretely: today, `RunKahnsAlgorithm` uses a plain FIFO `Queue[string]` for the "currently ready"
node set (`PSScriptBuilderTopologicalSorter.ps1:200-206, 211-225`). Replace it with a two-level,
fully deterministic pick among all currently-ready nodes (nodes with no entry in the type map, e.g.
Enums, fall through to today's arrival-order behavior via a plain `Queue` - `StabilizeEnumsFirst`
corrects their position afterward regardless, as already verified below):

1. **Type priority: prefer to dequeue a Function over a Class** when both are simultaneously ready.
2. **Among ties of the same type, prefer to dequeue the alphabetically-later name first**
   (`[StringComparer]::OrdinalIgnoreCase`, descending) - see below for why descending.

**Efficient implementation, verified to produce identical results to the naive approach**: rather
than re-filtering and re-sorting the entire ready set on every dequeue (O(n log n) per pick, O(n² log n)
overall - correct but needlessly expensive), use three parallel ready structures instead of one
`Queue`: a `SortedSet[string]` (`[StringComparer]::OrdinalIgnoreCase`) for ready Functions, a second
`SortedSet[string]` for ready Classes, and a plain `Queue[string]` for anything with no type entry
(Enums). Each dequeue step checks the Function set first (`.Max`, then remove - the alphabetically
latest ready function), then the Class set the same way, then falls back to the `Queue`. This keeps
every operation at O(log n) instead of O(n log n), for O(n log n) total instead of O(n² log n) -
verified to produce byte-for-byte identical output to the naive re-filter/re-sort approach across
all 11 scenarios already established in this RFC (independent components of each type, all
cross-type/same-type transitive chains, both dependency directions, the full combined stress test).

**Critical implementation constraint:** the `SortedSet[string]` (and fallback `Queue[string]`)
ready structures MUST be local variables created fresh inside `RunKahnsAlgorithm` on every call -
never instance fields (only the read-only type map from the new constructor belongs on the
instance, exactly as today's `$inDegree`/`$zeroInDegree` are already method-local). This is not
optional: `Sort()` already invokes `RunKahnsAlgorithm` *twice* within a single call whenever a
TypeReference cycle triggers the "stuck node" sub-graph pass (`PSScriptBuilderTopologicalSorter.ps1:89-137`).
Instance-field ready structures would be left empty (drained) after the first invocation, silently
breaking every ordinary build containing a TypeReference cycle - not merely an external
double-`Sort()`-call edge case. Verified the baseline (current, unfixed) behavior for exactly this
combined shape - independent nodes alongside a real `TypeRefCycleA`/`TypeRefCycleB` cycle - is
idempotent across two `Sort()` calls; the same must hold for the new implementation once done.

**Verified: using the same `[StringComparer]::OrdinalIgnoreCase` comparer for the new `SortedSet`s
does not introduce a new same-type name-collision risk.** `GetDefinedComponentNames()`
(`PSScriptBuilderContentCollector.ps1:277`) already uses a case-insensitive `HashSet` today, and its
own docstring already documents that a name collision is "silently absorbed"; `ValidateComponentNameUniqueness()`
only guards against Class-vs-Function conflicts, never two same-type components whose names differ
only by case. This is pre-existing, out-of-scope behavior inherited unchanged - not something this
RFC's `SortedSet` choice introduces.

The secondary key (alphabetical) departs from what module bundlers/package managers typically use
for the same kind of tie ("original declaration/scan order") - a deliberate choice, for two concrete
reasons specific to this project:

- **This project already has an established internal precedent for exactly this kind of tie**:
  `StabilizeEnumsFirst` (`PSScriptBuilderDependencyAnalyzer.ps1:243+`) already sorts enums
  alphabetically (`$enums.Sort([StringComparer]::OrdinalIgnoreCase)`) when their position is
  otherwise unconstrained. Applying the same convention to classes/functions is a direct
  generalization of an already-decided design principle, not a new one.
- **"Declaration order" is not actually a stable, cross-platform-safe concept here.** Verified that
  file discovery goes through `Get-ChildItem` (`PSScriptBuilderCollectorBase.ps1:202`), whose
  underlying directory-enumeration order is an OS/filesystem implementation detail - NTFS (Windows)
  and ext4 (Linux) do not enumerate directory entries in the same order, and neither guarantees
  alphabetical order. Since this project explicitly supports Windows/Linux/macOS, using scan order
  as a tie-break would make the exact same source tree produce a *different* component order
  depending on which OS performed the build - a new, self-inflicted cross-platform reproducibility
  bug. Alphabetical-by-name is fully OS/filesystem-independent.

**Both tie-break levels require the same non-intuitive direction, and for the same reason**: because
`RunKahnsAlgorithm` produces a *dependents-first* list that `Sort()`
(`PSScriptBuilderTopologicalSorter.ps1:149-150`) reverses to get the required prerequisites-first
order, whatever should win in the *final* output must be dequeued *last* among its tied peers in the
pre-reversal pass. Concretely: preferring Functions first (pre-reversal) yields Classes first
(final); preferring alphabetically-later names first (pre-reversal) yields alphabetically-ascending
order (final). This is the single trickiest part of this fix and is easy to get backwards by
reasoning alone - every direction claimed here was verified empirically, not just derived, including
a control check confirming the naive/opposite direction produces the wrong result (see Motivation).

**Why this resolves the transitive-ordering question raised during design, rather than merely
avoiding it:** two nodes are only ever compared against each other by this tie-break if they are
*simultaneously* eligible - i.e. if the graph has already established there is no dependency path
between them. A node that depends (even transitively, through other same-type nodes) on something
of the opposite type only becomes eligible once that entire chain has already been processed and
removed from contention - it is never in the "ready" set at the same time as a node it has a real
(direct or transitive) constraint against. Verified directly with a 4-node cross-type chain
(`FuncG -> ClassC -> ClassD`, plus an unrelated independent `FuncH`): the tie-break never applies
between `ClassC` and `ClassD` (each becomes ready at a different point, strictly enforced by the
existing in-degree mechanics), while the independent `FuncH` is correctly free to land anywhere
relative to the chain. The identical argument applies to the alphabetical same-type tie-break, and
was verified the same way with a same-type chain (`ClassX : ClassY`, deliberately named so
alphabetical order and the real required order disagree - see Motivation's `SameTypeTransitive`
result).

This keeps `PSScriptBuilderCrossDependencyDetector` and its existing unit tests completely
unchanged - the detector's contract ("scan a given order for a Function-then-Class transition") is
still correct, once the sort itself guarantees it never produces a transition that isn't backed by
a real edge. `StabilizeEnumsFirst` also requires no change: it runs after the sort, only
repositions enum names (identified by name lookup, not by touching the Class/Function tie-break),
and already preserves the relative order of all non-enum components untouched - composes correctly
with a sort that now produces a better non-enum relative order to begin with.

## Rationale and Alternatives

**Considered and rejected: unconditionally stabilize all classes before all functions** as a
post-sort pass, mirroring `StabilizeEnumsFirst`'s unconditional approach exactly. Verified this is
unsafe with a concrete counter-example built on the real, existing `ClassCallsFuncA`/`Get-FuncA`
fixture (a genuine Class-depends-on-Function edge, correctly ordered today as
`Get-FuncA, ClassCallsFuncA`): naively moving all classes first would produce
`ClassCallsFuncA, Get-FuncA` - the class before the function it actually calls, silently breaking a
real, currently-correct dependency. Enums are safe to unconditionally move because they can never
depend on anything; classes and functions can depend on each other in both directions, so the enum
precedent does not transfer to a blanket post-sort move.

**Considered a narrower post-sort reordering pass**, limited to components with zero direct edges
to the opposite type (using the graph's existing `GetDependencies`/`GetDependents` methods),
applied only after the sort completes. This was the first revision of this RFC's design. Superseded
by the in-sort tie-break (this section's Decision) once the transitive-ordering question below was
raised: a post-sort pass reasons only about *direct* edges, so it must separately re-verify that
moving an "isolated" component never disturbs an existing, correct relative order it has with a
same-type component through an indirect chain (see the `FuncG -> ClassC -> ClassD` example in
Decision). Fixing the tie-break at the point Kahn's algorithm actually makes its selection decision
avoids this class of question entirely, by construction, rather than requiring a separate proof for
every possible chain shape - confirmed empirically (see Decision).

**Considered "original declaration/scan order" as the same-type tie-break**, matching the
convention most module bundlers and package managers use (Webpack/Rollup/esbuild, Python's
`graphlib.TopologicalSorter`). Rejected in favor of alphabetical order for two project-specific
reasons (see Decision for full detail): (1) it would introduce a second, different tie-break
convention alongside `StabilizeEnumsFirst`'s already-established alphabetical one, rather than
generalizing the existing precedent; (2) verified that "declaration order" is not actually a stable
concept here - file discovery goes through `Get-ChildItem`, whose directory-enumeration order is an
OS/filesystem detail that differs between Windows (NTFS) and Linux (ext4) and is not alphabetical on
either, which would make the same source tree produce different component orders depending on which
OS performed the build - a new cross-platform reproducibility bug in a project that explicitly
supports Windows/Linux/macOS.

**Considered detecting cross-dependencies directly from graph edges** (`HasCrossDependencies = true`
iff a genuine Class→Function edge exists anywhere in the graph) **instead of** fixing the sort.
Rejected: it would require changing `PSScriptBuilderCrossDependencyDetector`'s contract and
rewriting its existing, currently-correct unit tests (which test the detector's position-scanning
behavior given a hand-supplied order, a reasonable contract in isolation) rather than only fixing
the tie-break the sorter already needs internally regardless.

## Scope

**In scope:** `PSScriptBuilderTopologicalSorter` (new constructor overload accepting a node-type map;
`RunKahnsAlgorithm` delegates the tie-break to a ready queue instead of implementing it inline);
`PSScriptBuilderTopologicalSortReadyQueue` (new class, own file - encapsulates the two-level
tie-break: type priority, then alphabetical among same-type ties);
`PSScriptBuilderContentCollector.GetDefinedComponentTypes()` (new method, structurally parallel to
`GetDefinedComponentNames()` - builds the node-type map in one pass); `PSScriptBuilderDependencyAnalyzer.SortTopologically`
(now just asks the ContentCollector for the map and passes it to the new constructor); regression tests for the zero-edge case (already added, currently red, in
`PSScriptBuilderDependencyAnalyzer.Tests.ps1`); new unit tests on
`PSScriptBuilderTopologicalSorter.Tests.ps1` directly covering both tie-break levels through
`Sort()` (independent class(es)+function(s), multiple independent same-type components, the
cross-type transitive chain, the same-type transitive chain, and Enum/Class/Function composition);
a new `PSScriptBuilderTopologicalSortReadyQueue.Tests.ps1` covering `Add`/`Dequeue`/`Count` in
isolation; non-regression tests confirming `ClassCallsFuncA`/`Get-FuncA`-style real
cross-dependencies remain correctly detected, and confirming the existing single-argument
constructor (no type map) keeps today's behavior unchanged.

**Out of scope:** `PSScriptBuilderCrossDependencyDetector` (no change - see Decision);
`PSScriptBuilderDependencyAnalyzer.StabilizeEnumsFirst` itself (no change - composes correctly as-is,
verified - see Decision); the `tool-integrations.md` Pester example that surfaced this (tracked
separately - either pick example names that happen to avoid the false positive today, or simply
rely on this fix once implemented).

## Relationship to Other RFCs

Independent of RFC 0001-0016 (all release-management/template-escaping concerns). No known
interaction with the Source Maps or Code Analysis guides' own dependency-analysis usage - both
consume `Get-PSScriptBuilderDependencyAnalysis`'s result as-is and would simply see a corrected
`HasCrossDependencies` value.

## Test Plan

- Regression test (already added, confirmed red under PS 5.1, `PSScriptBuilderDependencyAnalyzer.Tests.ps1`):
  two independent classes + one independent function (zero edges) → `HasCrossDependencies = false`.
- New `PSScriptBuilderTopologicalSorter.Tests.ps1` tests, directly on `Sort()`:
  - Independent class(es) + independent function(s), no edges at all → classes sorted before
    functions.
  - Multiple independent classes only, and multiple independent functions only → each group sorted
    alphabetically (ascending, case-insensitive).
  - The cross-type transitive chain case (`FuncG -> ClassC -> ClassD`, plus an unrelated independent
    `FuncH`) → `FuncG` before `ClassC` before `ClassD` (the real chain, unaffected), `FuncH` anywhere
    relative to it.
  - The same-type transitive chain case (`ClassX : ClassY`, names deliberately chosen so alphabetical
    order and the real required order disagree) → `ClassY` before `ClassX`, unaffected by the
    alphabetical tie-break.
  - A real cross-dependency (`ClassCallsFuncA`/`Get-FuncA`) mixed with additional, genuinely
    independent classes/functions of both types in the same project → the real cross-dependency's
    relative order is preserved exactly, independent components are unaffected by it and vice versa,
    and are themselves correctly alphabetized within their own type.
  - A chain that flips dependency direction twice (Class needs Function, that Function needs
    another Class) → all three components in strict required order, no ties involved.
  - Both dependency directions (Class→Function and Function→Class) present simultaneously via two
    unrelated real dependencies, plus independent noise of both types → each real dependency's
    order preserved independently of the other and of the noise.
  - Enum/Class/Function composition: independent enums + a real enum→class dependency + a real
    cross-type chain + independent classes/functions, all in one graph → enums correctly stabilized
    to the front (unaffected by the new tie-break), the real chain preserved, independent components
    of each type alphabetized within their own group.
- Non-regression test: the existing single-argument `PSScriptBuilderTopologicalSorter` constructor
  (no type map) continues to behave exactly as today - required since 17 existing tests in
  `PSScriptBuilderTopologicalSorter.Tests.ps1` construct the sorter this way.
- New test: a graph combining a real TypeReference cycle (triggering the "stuck node" sub-graph
  pass, i.e. a second internal `RunKahnsAlgorithm` invocation within one `Sort()` call) with
  independent, tied nodes processed in the main pass → both passes resolve correctly and
  independently, and `Sort()` called twice on the same instance returns identical results (guards
  against accidentally implementing the ready structures as instance fields instead of
  `RunKahnsAlgorithm`-local variables).
- Non-regression test: `ClassCallsFuncA` calling `Get-FuncA` (real Class→Function edge) continues to
  report `HasCrossDependencies = true`.
- Non-regression test: a function depending on a class (real Function→Class edge) continues to
  report `HasCrossDependencies = false`.
- Full suite re-run after implementation (target: all previously-passing tests remain green, the new
  regression test turns green).

## Unresolved Questions

None remaining - see Revision Log's "Implemented" entry for the resolution of the one open item
(the `tool-integrations.md` Pester example needs no change).

## Revision Log

- 2026-09-09 — Third post-implementation design review: considered, and deliberately rejected,
  also having `StabilizeEnumsFirst` reuse the new `GetDefinedComponentTypes()` (it independently
  derives its own enum-name set via `GetEnumCollectors()`, a second, overlapping collector scan per
  `Analyze()` call). Rejected unifying this for two reasons: (1) `PSScriptBuilderDependencyAnalyzer`'s
  own class-level documentation explicitly designs each pipeline step (`BuildDependencyGraph`,
  `SortTopologically`, `StabilizeEnumsFirst`, `DetectCrossDependencies`) as independently callable
  and testable (all public, each with its own standalone `.EXAMPLE`) - threading a
  precomputed type map from `Analyze()` into `StabilizeEnumsFirst` would break that already-stated,
  deliberate independence; (2) the duplicated scan is a linear pass over a few hundred components
  at most, once per build - a constant-factor cost, not the kind of repeated-per-iteration
  complexity-class issue the `SortedSet`/`TryGetValue` decisions were about. Not a risky DRY
  violation either: both derivations read the same immutable collector state independently and
  correctly, with no risk of drifting out of sync. No code change from this review.
- 2026-09-09 — Second post-implementation design review: `PSScriptBuilderDependencyAnalyzer.SortTopologically`
  was doing two things - building the node-type map (iterating `GetClassCollectors()`/
  `GetFunctionCollectors()` itself) and orchestrating the sort - even though it never uses the map
  for anything but handing it to the sorter. Per the Information Expert principle (GRASP) and this
  exact class's own existing precedent (`GetDefinedComponentNames()` already aggregates
  cross-collector data in one pass), moved the map-building logic to a new
  `PSScriptBuilderContentCollector.GetDefinedComponentTypes()` method - structurally identical to
  `GetDefinedComponentNames()`, just capturing each name's `PSScriptBuilderCollectorType` alongside
  it, covering Enum/Class/Function like its sibling (not just Class/Function) for scope parallelism,
  even though only Class/Function currently affect the tie-break. Considered and rejected reusing
  the existing `GetComponentType(name)` (single-name lookup, scans all collectors per call) in a
  loop over all names - would repeat the same full collector scan once per component instead of
  once total, the same "avoid needless O(n) repetition" reasoning already applied to the
  `SortedSet`/`TryGetValue` decisions. `SortTopologically` is now two lines: ask the ContentCollector
  for the map, hand it to the sorter. Added 2 new `PSScriptBuilderContentCollector.Tests.ps1` tests
  (sibling `Context` to the existing `GetDefinedComponentNames` tests). Full suite, PowerShell 5.1:
  1874 passed (1872 + 2 new), 0 failed.
- 2026-09-09 — Post-implementation design review: extracted the ready-structure handling from
  `RunKahnsAlgorithm`/a 4-parameter `AddReadyNode` helper into a new, dedicated class,
  `PSScriptBuilderTopologicalSortReadyQueue` (own file, matching this directory's one-class-per-file
  convention), exposing only `Add(node)`/`Dequeue()`/`Count()`. Raised because the three parallel
  "ready" structures (`readyFunctions`/`readyClasses`/`readyOther`) were a **data clump** (Fowler) -
  always passed and mutated together - and the priority/routing decision was duplicated between
  where a node was added and where it was dequeued; `RunKahnsAlgorithm` no longer has any
  Function/Class-awareness of its own; the tie-break policy lives in exactly one place.
  Also considered switching `Add()`'s `ContainsKey` + indexer lookup to a single `TryGetValue` call -
  verified this is a **worse** choice here: `PSScriptBuilderCollectorType`'s zero value is a real,
  named member (`UsingCollector = 0`, confirmed via the enum source), so `TryGetValue`'s
  fill-on-miss behavior would set the output variable to a *meaningful-looking* value on a miss,
  not a safe empty sentinel - correct usage would require an extra `$found`-gated placeholder
  variable and an explanatory comment, for a saved lookup that only ever runs a few hundred times
  per build. Kept `ContainsKey` + indexer: negligible performance difference, meaningfully clearer.
  Added a dedicated `PSScriptBuilderTopologicalSortReadyQueue.Tests.ps1` (9 new tests covering
  `Add`/`Dequeue`/`Count` in isolation, not just through `Sort()`). Full suite, PowerShell 5.1:
  1872 passed (1863 + 9 new), 0 failed - both before and after the extraction, confirming
  behavior-preserving refactor.
- 2026-09-09 — Post-implementation, pre-commit scope clarification: raised whether the fix is
  Free-Mode-only. Verified directly (`git stash`/rebuild/compare) that it is not: the identical
  independent-component project, built against an `{{ORDERED_COMPONENTS}}` template, is classified
  `Ordered` pre-fix and `Hybrid` post-fix, with a different literal component order in the actual
  output file in both cases - even though neither build ever fails (only Free-Mode-shaped
  templates were ever capable of the outright failure). Updated Summary and Motivation with the
  concrete before/after comparison.
- 2026-09-09 — Implemented, exactly per the verified Decision:
  - `PSScriptBuilderTopologicalSorter`: added the second constructor overload
    (`graph, [Dictionary[string, PSScriptBuilderCollectorType]] $nodeTypes`); `RunKahnsAlgorithm`
    rewritten to use two `SortedSet[string]` (`OrdinalIgnoreCase`, one per type) plus a fallback
    `Queue[string]`, all method-local (never instance fields, per the critical constraint above);
    added the `AddReadyNode` helper method. Docstrings rewritten to describe the real tie-break
    behavior and the non-intuitive pre-reversal direction, replacing the old (now-incorrect)
    "prevents accidental interleaving" comment.
  - `PSScriptBuilderDependencyAnalyzer.SortTopologically`: builds the node-type map from
    `GetClassCollectors()`/`GetFunctionCollectors()` and passes it to the new constructor.
  - Regression test (`PSScriptBuilderDependencyAnalyzer.Tests.ps1`, added pre-implementation) now
    passes. Added 10 new tests directly to `PSScriptBuilderTopologicalSorter.Tests.ps1` covering
    every scenario established in this RFC: independent class-before-function, alphabetical
    ordering within each type, the cross-type and same-type transitive chains, the
    direction-flipping chain, both directions simultaneously, the stuck-node-pass +
    independent-ties idempotency case, the untyped/enum fallback, and the null-map
    backward-compatibility case.
  - **Full suite, PowerShell 5.1**: 1863 passed (1853 + 10 new), 0 failed, 0 skipped - both via
    `build.ps1` (bootstrap) and `Build-Module.ps1` (authoritative), per
    [[authoritative-build-artifact]].
  - Re-verified the original reported bug end-to-end against the real, fixed module: independent
    `ClassA`/`ClassB`/`Get-FuncA` now correctly returns `OrderedComponents: ClassA, ClassB,
    Get-FuncA`, `HasCrossDependencies: False`; the real `ClassCallsFuncA`/`Get-FuncA` dependency
    remains correctly detected (`HasCrossDependencies: True`, unaffected).
  - `CHANGELOG.md`: added a `Fixed` entry under `[Unreleased]` (newest-first), describing the
    observable behavior fix.
  - Left as noted in Unresolved Questions: `docs/guides/tool-integrations.md`'s Pester example
    needs no change - it is now simply correct as originally written, since the bug it
    inadvertently exercised is fixed.
- 2026-09-09 — Second final pre-implementation review, same session (requested again during review):
  considered implementation efficiency, not previously examined. The verified design as prototyped
  re-filters and re-sorts the entire ready set on every dequeue (O(n log n) per pick, O(n² log n)
  overall) - correct but avoidably expensive for a mechanism this foundational. Designed an
  efficient alternative (a `SortedSet[string]` per type instead of a single `Queue`, O(log n) per
  operation, O(n log n) total) and re-ran all 11 previously-established scenarios against it -
  identical output in every case. Updated Decision with the concrete, efficient data-structure
  design to implement.
- 2026-09-09 — Third final pre-implementation review, same session: two more aspects checked.
  (1) **Same-type case-collision risk with `SortedSet`**: verified this is not a *new* risk -
  `GetDefinedComponentNames()` (`PSScriptBuilderContentCollector.ps1:277`) already uses a
  case-insensitive `HashSet` today, and its own docstring already documents silent collision
  absorption; `ValidateComponentNameUniqueness()` only guards Class-vs-Function conflicts, never
  same-type ones. Using the same `OrdinalIgnoreCase` comparer for the new `SortedSet`s inherits
  identical, pre-existing (out-of-scope) behavior, not a new one. (2) **Idempotency /
  double-invocation risk, more urgent than initially framed**: `Sort()` already calls
  `RunKahnsAlgorithm` twice within a single invocation whenever a TypeReference cycle triggers the
  "stuck node" sub-graph pass (`PSScriptBuilderTopologicalSorter.ps1:89-137`) - confirmed against
  the real, current module with independent nodes alongside a real `TypeRefCycleA`/`TypeRefCycleB`
  cycle (baseline result: `TypeRefCycleB, TypeRefCycleA, AClass2, ZClass2`, stable across two
  `Sort()` calls). This means a careless implementation that stores the new `SortedSet` ready
  structures as instance fields instead of `RunKahnsAlgorithm`-local variables would break on the
  very first ordinary build containing a TypeReference cycle, not just on an external repeated
  `Sort()` call. Added an explicit implementation constraint to Decision to prevent this, and a
  dedicated Test Plan entry combining a TypeReference cycle with independent tied nodes in the same
  graph.
- 2026-09-09 — Final pre-implementation review, same session (one more full check explicitly
  requested before writing code): found that `PSScriptBuilderTopologicalSorter` operates on a
  type-agnostic graph (confirmed by reading all 17 existing tests in
  `PSScriptBuilderTopologicalSorter.Tests.ps1` - no Class/Function distinction anywhere), so the
  type-priority tie-break cannot be purely internal as originally scoped - it needs a node-type map
  passed in. Revised Decision/Scope to add a second constructor overload (graph + type map),
  updated `SortTopologically` to build and pass the map, and verified the existing single-argument
  constructor's behavior is preserved unchanged for callers that don't provide one (confirmed no
  existing sorter test asserts order among genuinely tied nodes, only among nodes fully constrained
  by real edges). Also verified, previously untested: (1) both dependency directions
  (Class→Function and Function→Class) present together, including a chain that flips direction
  twice and a function shared by two classes - all correct, one case additionally cross-checked
  against the real, current module; (2) the full pipeline (new tie-break + existing
  `StabilizeEnumsFirst`) with Enums mixed into independent noise, a real enum→class dependency, and
  a real cross-type chain, all in one graph - composes correctly. Noted the "stuck node"
  TypeReference-cycle sub-graph pass automatically inherits the same tie-break (type map stored as
  an instance field) and reasoned through why this is safe (TypeReference edges can only target
  Classes/Enums, never Functions, so the type-priority tie-break rarely applies there, and the
  alphabetical same-type tie-break composes by the same already-proven argument).
- 2026-09-09 — Scope broadened, same session: raised whether this mechanism - being
  foundational to the whole project - deserves a fully worked-out, best-practice-grounded
  solution rather than just the minimum fix for the reported bug. Investigated same-type
  non-determinism (two independent classes' relative order flips when their file scan order is
  reversed) and confirmed it stems from the identical root cause. Researched how comparable tools
  handle this class of problem (Webpack/Rollup/esbuild, Python's `graphlib.TopologicalSorter` - all
  use an explicit, deterministic tie-break) and extended the Decision to a two-level tie-break: type
  priority (already decided) plus alphabetical order for same-type ties - chosen over the more
  common "declaration order" convention for two project-specific reasons (generalizes the existing
  `StabilizeEnumsFirst` alphabetical precedent; "declaration order" is not actually stable
  cross-platform here, since it would resolve to OS-specific `Get-ChildItem` directory-enumeration
  order, verified to differ between NTFS and ext4). Verified the complete two-level design
  empirically with an extended prototype across 8 scenarios plus a control, including two
  deliberately adversarial cases (a same-type real dependency chain named so alphabetical order
  disagrees with the required real order; a full combined graph mixing both real chains and
  independent noise of both types) - all passed. Updated Decision, Rationale and Alternatives,
  Scope, and Test Plan accordingly.
- 2026-09-09 — Design revised and settled (Status: Draft → Decided). The initial draft's post-sort
  reordering approach was superseded before implementation once the question of how comparable
  tools solve this class of problem was raised: module bundlers and package managers use a **stable topological
  sort** (a type/priority-aware tie-break inside the sort itself, at the point multiple nodes are
  simultaneously eligible) rather than patching the sorted output afterward. Verified the exact
  tie-break direction empirically with a standalone prototype mirroring
  `RunKahnsAlgorithm`'s real in-degree/queue/reversal mechanics (not the real source, to keep
  verification isolated): confirmed "prefer Function over Class when both are ready" in the
  pre-reversal pass is the correct direction (the naive opposite direction was tested as a control
  and confirmed wrong) - non-intuitive because of the method's internal dependents-first-then-
  reverse structure. This also fully resolves the previously-open transitive-ordering question
  (not just avoids it): verified with a 4-node chain (`FuncG -> ClassC -> ClassD` plus unrelated
  independent `FuncH`) that two nodes are only ever tie-broken against each other when the graph has
  already established no dependency path exists between them, so a real chain can never be disturbed
  by the tie-break. Updated Decision, Rationale and Alternatives, Scope, and Test Plan accordingly;
  removed the now-resolved transitive-ordering item from Unresolved Questions.
- 2026-09-09 — Initial draft. Found while verifying `docs/guides/tool-integrations.md`'s Pester
  example against a real scratch build. Reproduced with the project's own existing test fixtures,
  traced the root cause through `GetDefinedComponentNames` → `DependencyGraphBuilder.Build` →
  `TopologicalSorter` → `CrossDependencyDetector`, confirmed real cross-dependencies (both
  directions) are unaffected, confirmed zero prior test coverage for the zero-edge case, added a
  regression test (red) and verified it is the only failure across the full 1853-test suite under
  PowerShell 5.1. Initially proposed an unconditional class-before-function stabilization mirroring
  `StabilizeEnumsFirst`; rejected after building a concrete counter-example
  (`ClassCallsFuncA`/`Get-FuncA`) proving it would silently break a real, currently-correct
  dependency. Revised design: scope the stabilization to only edge-free components, using
  `PSScriptBuilderDependencyGraph`'s existing `GetDependencies`/`GetDependents` methods. Status left
  at Draft pending resolution of the transitive-dependency question and final method
  naming/placement.
