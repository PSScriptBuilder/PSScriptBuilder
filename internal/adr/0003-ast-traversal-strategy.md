# ADR 0003: AST Traversal Strategy - FindAll vs AstVisitor

## Status
**Accepted**

Date: 2026-02-21

## Context

The `PSScriptBuilderAstEngine` provides static utility methods for parsing and analyzing PowerShell AST (Abstract Syntax Tree) structures. Several methods need to traverse the AST to find specific node types:

- `FindClassDefinitions()`, `FindEnumDefinitions()`, `FindFunctionDefinitions()` - Single node type queries
- `GetTypeReferences()` - Searches for 5 different node types (TypeConstraintAst, TypeExpressionAst, ConvertExpressionAst, BinaryExpressionAst, CatchClauseAst)
- `GetFunctionCalls()` - Single node type query

PowerShell provides two primary approaches for AST traversal:

1. **FindAll with predicates** - `$ast.FindAll({ predicate }, $recurse)` - Simple, stateless queries
2. **AstVisitor pattern** - Custom visitor class implementing `Visit*()` methods - Single-pass traversal with state

The question is whether to use FindAll (current implementation) or refactor to AstVisitor for performance optimization.

## Decision

**Use FindAll with predicates for all AST traversal methods.** Do NOT refactor to AstVisitor at this time.

### Implementation Details

```powershell
# Example: Simple single-type query
static [TypeDefinitionAst[]] FindClassDefinitions([ScriptBlockAst] $ast) {
    $predicate = { 
        ($args[0] -is [TypeDefinitionAst]) -and 
        $args[0].IsClass -and 
        (-not ($args[0].Parent -is [TypeDefinitionAst]))
    }
    return $ast.FindAll($predicate, $true)
}

# Example: Multi-type query (5 separate passes)
static [string[]] GetTypeReferences([Ast] $ast) {
    # Pass 1: TypeConstraintAst
    $typeConstraints = $ast.FindAll({ $args[0] -is [TypeConstraintAst] }, $true)
    
    # Pass 2: TypeExpressionAst
    $typeExpressions = $ast.FindAll({ $args[0] -is [TypeExpressionAst] }, $true)
    
    # ... passes 3-5 for other node types
}
```

## Rationale

### Why FindAll

1. **Simplicity** - Each method is self-contained, stateless, and easy to understand
2. **Maintainability** - Adding new node types or modifying queries is straightforward
3. **PowerShell Idiom** - `FindAll` is the recommended approach in PowerShell documentation
4. **Testability** - Stateless methods are easier to test in isolation
5. **Sufficient Performance** - For typical PowerShell file sizes (50-500 lines), multi-pass traversal is acceptable

### Performance Analysis

**Typical Scenario:**
- File size: 500 lines
- AST traversal time: ~2ms per pass
- `GetTypeReferences()` uses 5 passes: **~10ms total**
- `ParseFile()` (I/O + parsing): **50-100ms**
- AST traversal is **~10%** of total processing time

**With AstVisitor Optimization:**
- Single pass for `GetTypeReferences()`: **~3ms**
- Savings: **7ms per file**
- Relative improvement: **~5%** of total file processing

**Conclusion:** The absolute time savings (7ms per file) is negligible for the typical use case.

### Why Not AstVisitor

1. **Premature Optimization** - No profiling data showing AST traversal as a bottleneck
2. **Increased Complexity** - Requires visitor classes with state management
3. **Boilerplate Code** - More code to write and maintain
4. **Limited Benefit** - Only `GetTypeReferences()` would benefit (multi-pass); other methods already use single pass
5. **YAGNI Principle** - "You Aren't Gonna Need It" until proven otherwise

## Performance Optimization Path

If profiling later shows AST traversal consuming >20% of execution time:

1. **Measure First** - Use `Measure-Command` to identify actual bottleneck
2. **Hybrid Approach** - Refactor only `GetTypeReferences()` to use AstVisitor
3. **Keep Simple Methods** - `FindClassDefinitions()`, `FindEnumDefinitions()`, etc. remain with FindAll
4. **Document Decision** - Update this ADR with profiling data justifying optimization

### Hybrid Implementation Example

```powershell
class TypeReferenceVisitor : AstVisitor {
    [HashSet[string]] $Types = [HashSet[string]]::new()
    
    [AstVisitAction] VisitTypeConstraint([TypeConstraintAst] $ast) {
        # Collect types
        return [AstVisitAction]::Continue
    }
    # ... other Visit methods
}
```

## Alternatives Considered

### 1. Full AstVisitor Implementation
**Description:** Refactor all methods to use visitor pattern

**Pros:**
- Consistent approach across all methods
- Potential performance improvement for `GetTypeReferences()`

**Cons:**
- Significant code complexity increase
- No benefit for single-type queries (FindClassDefinitions, etc.)
- Premature optimization without measured need

**Verdict:** Rejected - Violates YAGNI and unnecessarily complicates simple queries

### 2. Hybrid Approach (AstVisitor for GetTypeReferences only)
**Description:** Use visitor only for multi-pass methods

**Pros:**
- Performance benefit where it matters most
- Keeps simple methods simple

**Cons:**
- Inconsistent patterns in same class
- Added complexity for marginal gain (~7ms)
- No proven performance bottleneck

**Verdict:** Deferred - Implement only if profiling shows need

### 3. Combine Multiple FindAll Predicates
**Description:** Use single FindAll with complex predicate checking 5 types

```powershell
$allNodes = $ast.FindAll({ 
    $args[0] -is [TypeConstraintAst] -or 
    $args[0] -is [TypeExpressionAst] -or ...
}, $true)
```

**Pros:**
- Single pass
- No visitor boilerplate

**Cons:**
- Loses type safety in foreach loop
- Still requires type checking in processing logic
- Less readable than separate queries

**Verdict:** Rejected - Complexity without sufficient benefit

## Consequences

### Positive
- Simple, readable code that follows PowerShell conventions
- Easy to maintain and extend
- Minimal learning curve for contributors
- No performance issues for typical file sizes
- Clear optimization path if needs change

### Negative
- `GetTypeReferences()` performs 5 AST traversals instead of 1
- Potential performance impact for very large files (>10,000 lines)
- Would require refactoring if AST traversal becomes bottleneck

### Neutral
- Performance characteristics are predictable and acceptable for current use case
- Decision can be revisited with profiling data showing actual bottleneck

## Future Considerations

This decision should be revisited if:
1. Profiling shows AST traversal consuming >20% of total execution time
2. Module needs to process files >10,000 lines regularly
3. Build times become unacceptable (multiple minutes)
4. Performance requirements change significantly

**Monitoring:** Add optional timing output in debug mode to track AST traversal performance over time.
