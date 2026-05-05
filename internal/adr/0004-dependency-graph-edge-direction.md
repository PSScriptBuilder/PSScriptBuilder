# ADR 0004: Dependency Graph Edge Direction Convention

## Status
**Accepted**

Date: 2026-03-18

## Context

`PSScriptBuilderDependencyGraph` stores dependencies as an adjacency list. The central question is:
when `ClassA` depends on `ClassB` (e.g. via inheritance), which direction should the edge point?

Two conventions exist:

**Option A — Natural direction** (dependent → prerequisite):
```
ClassA → ClassB   # "ClassA depends on ClassB"
```

**Option B — Reversed direction** (prerequisite → dependent):
```
ClassB → ClassA   # "ClassB is required by ClassA"
```

The choice directly affects:
- The semantic correctness of `GetDependencies()` and `GetDependents()`
- Whether topological sort requires a final `Reverse()` step
- The readability of `TryAddEdge()` in `PSScriptBuilderDependencyGraphBuilder`

### Problem With the Initial Implementation

The original implementation used Option B (reversed edges). This meant:

- `GetDependencies('ClassB')` returned `{ 'ClassA' }` — semantically wrong (ClassB does not depend on ClassA)
- `GetDependents('ClassA')` returned `{}` — semantically wrong (ClassA has ClassB as a dependent)
- `TryAddEdge(dependent, prerequisite)` internally called `AddEdge(prerequisite, dependent)` — the inversion was hidden inside the builder, making the graph data counterintuitive

Kahn's algorithm on a reversed graph naturally yields dependents-first order, which happened to produce the correct sort output — but only because two wrongs cancelled each other out.

## Decision

Use **Option A: natural direction** (dependent → prerequisite). `AddEdge(from, to)` means: `from` depends on `to`.

### Implementation Details

**`PSScriptBuilderDependencyGraphBuilder.TryAddEdge`:**
```powershell
# ClassA depends on ClassB → store the natural edge
$this.CurrentGraph.AddEdge($from, $to)   # AddEdge('ClassA', 'ClassB')
```

**`PSScriptBuilderDependencyGraph.GetDependencies('ClassA')`:**
```
Returns: { 'ClassB' }   # ClassA depends on ClassB ✓
```

**`PSScriptBuilderDependencyGraph.GetDependents('ClassB')`:**
```
Returns: { 'ClassA' }   # ClassA depends on ClassB ✓
```

**`PSScriptBuilderTopologicalSorter.Sort()`:**

Kahn's algorithm on a natural-direction graph yields dependents-first order. A single `[Array]::Reverse()` call at the end produces the required prerequisites-first output:

```powershell
$arr = $result.ToArray()
[Array]::Reverse($arr)   # prerequisites first
return $arr
```

## Rationale

### Why Natural Direction

1. **Semantic correctness** — `GetDependencies()` and `GetDependents()` mean what their names say
2. **Industry standard** — npm, Gradle, Roslyn, and most dependency graph implementations use natural direction
3. **Transparency** — the inversion trick in `TryAddEdge` was a hidden side-effect; the new implementation has no surprises
4. **Testability** — tests can be written intuitively: `AddEdge('DerivedClass', 'BaseClass')` reads as natural English

### Why Not Reversed Direction

- Semantically incorrect method names (`GetDependencies` returning dependents)
- Hidden complexity in `TryAddEdge` with no visible benefit
- Confusing for future contributors unfamiliar with the trick

## Alternatives Considered

1. **Keep reversed edges, rename methods** — `GetSuccessors()` / `GetPredecessors()` would be semantically correct, but deviates from the established API contract and is less idiomatic
2. **Keep reversed edges, add documentation** — Documentation cannot fix a counterintuitive API; the semantic mismatch would remain a constant source of bugs

## Consequences

### Positive
- All graph methods are semantically correct
- `TryAddEdge` is straightforward and transparent
- Graph structure matches standard textbook representation
- Tests are readable without needing to understand an internal inversion convention

### Negative
- `Sort()` requires one additional `[Array]::Reverse()` call — negligible performance cost

### Migration
- `PSScriptBuilderDependencyGraphBuilder.TryAddEdge`: `AddEdge($to, $from)` → `AddEdge($from, $to)`
- `PSScriptBuilderTopologicalSorter.Sort()`: added `[Array]::Reverse($arr)` before return
- Existing tests required no semantic changes, only edge direction updates in setup code

## Related Decisions

- ADR 0003: AST Traversal Strategy
