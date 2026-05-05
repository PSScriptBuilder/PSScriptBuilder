# Plan: {{ORDERED_COMPONENTS}} in Free Mode

**Status:** Planning  
**Created:** 2026-03-26  
**Revised:** 2026-03-26

---

## 1. Goal

Allow `{{ORDERED_COMPONENTS}}` as an optional placeholder in Free Mode templates. A user who
wants a stable, mode-agnostic template can use `{{ORDERED_COMPONENTS}}` unconditionally — even
when no cross-dependencies exist yet. If cross-dependencies are introduced later, the build
continues to work without any template change.

---

## 2. Background

### Current Mode Selection

The mode is derived automatically from the dependency analysis result:

```
DependencyAnalyzer.Analyze() → HasCrossDependencies
    → true  → CrossDependencies mode → template must use {{ORDERED_COMPONENTS}}
    → false → Free mode              → template must use individual collector placeholders
```

The mode is a **consequence of the code structure**, not a configuration value.

### The Problem

CrossDependencies mode switches silently. A project starts in Free mode with individual
placeholders (`{{ClassDefinitions}}`, `{{FunctionDefinitions}}`). As soon as one function
references a class type — a normal OOP pattern — the mode switches and the build fails because
the template still uses individual placeholders.

### The Core Design Issue (identified during planning)

The current code conflates two different concepts under the same name:

| Concept | Question answered | Source |
|---|---|---|
| `HasCrossDependencies` | *How is the code structured?* | `DependencyAnalyzer` |
| *(no explicit name)* | *Which rendering strategy does the template require?* | implicitly = Concept 1 |

Currently they are always identical. With this feature they diverge: a Free-mode codebase
(`HasCrossDependencies = false`) with an Ordered template (`{{ORDERED_COMPONENTS}}` present)
requires `UseOrderedMode = true`.

**The renderer must not detect its own strategy. That decision belongs one level up.**

---

## 3. Architecture Decision

The strategy decision (`UseOrderedMode`) is computed by the two coordinators that have access
to both the dependency result and the template content: `BuildOrchestrator` and
`TemplateAnalyzer`. They pass the decision downward as an explicit parameter.

```
HasCrossDependencies (code structure)
templateHasOrderedPlaceholder (template structure)
    → $validationMode = HasCrossDeps → Ordered | templateHasOrdered → Hybrid | else → Free
    → $useOrderedMode = $hasCrossDeps -or $templateHasOrderedPlaceholder
        → $validationMode  passed to TemplateAnalysisResult (reporting)
        → $useOrderedMode  passed to TemplateValidator.Validate($useOrderedMode, ...)
        → $useOrderedMode  passed to TemplateProcessor.new(..., $useOrderedMode)
```

`TemplateProcessor` and `TemplateValidator` are strategy-executors. They receive `$useOrderedMode`
and do not inspect the template content to determine their own behavior.
The three-value enum serves reporting only — `Hybrid` and `Ordered` behave identically
for validation and rendering.

---

## 4. Scope of Changes

Six source files are affected. No public cmdlet signatures change.

| File | Change type |
|---|---|
| `PSScriptBuilderTemplateValidationMode.ps1` | Add `Hybrid = 1`; `Ordered` moves to `= 2`; rename `CrossDependencies` |
| `PSScriptBuilderTemplateValidator.ps1` | Parameter rename + method rename + error text |
| `PSScriptBuilderTemplateProcessor.ps1` | Property/parameter rename + method rename |
| `PSScriptBuilderTemplateAnalyzer.ps1` | `$useOrderedMode` derivation + `BuildExpectedPlaceholders` refactor |
| `PSScriptBuilderBuildOrchestrator.ps1` | `$useOrderedMode` derivation in `ExecuteBuild()` |
| `Test-PSScriptBuilderTemplate.ps1` | `$useOrderedMode` derivation |

Test files affected:
- `PSScriptBuilderTemplateValidator.Tests.ps1` — new context + context name updates
- `PSScriptBuilderTemplateProcessor.Tests.ps1` — new context + constructor parameter name
- `PSScriptBuilderTemplateAnalyzer.Tests.ps1` — new items + enum reference updates
- `PSScriptBuilderTemplateAnalysisResult.Tests.ps1` — enum reference update (2 lines)

---

## 5. Detailed Changes

### 5.1 `PSScriptBuilderTemplateValidationMode` — Add `Hybrid`; rename `CrossDependencies` → `Ordered`

**Rationale:** The three-value enum explicitly names all three observable modes. `Hybrid` and
`Ordered` render and validate identically; the distinction is for reporting only.
`Ordered` replaces `CrossDependencies` because the value names a rendering strategy,
not a code-structure cause.

```powershell
// Before:
Free              = 0
CrossDependencies = 1

// After:
Free    = 0   // unchanged
Hybrid  = 1   // new — Free mode codebase + {{ORDERED_COMPONENTS}} explicit in template
Ordered = 2   // was CrossDependencies = 1
```

**`Ordered` integer value changes from `1` to `2`** — no serialization impact
(internal enum, never persisted to disk).

**All reference sites** (grep `CrossDependencies` in non-Detector files):
- `PSScriptBuilderTemplateAnalyzer.ps1` — 2 code occurrences (now route to `::Hybrid` or `::Ordered`)
- `PSScriptBuilderTemplateAnalysisResult.ps1` — docstring only
- Tests: `PSScriptBuilderTemplateAnalysisResult.Tests.ps1` lines 65+67 (2 code occurrences)

---

### 5.2 `PSScriptBuilderTemplateValidator` — 5 changes

#### 5.2.1 Rename `$hasCrossDependencies` → `$useOrderedMode` in public API

Affected signatures:
- `static [void] Validate(...)` — public
- `static [bool] IsValid(...)` — public

All callers of `Validate()` outside this file:
- `Test-PSScriptBuilderTemplate.ps1` — see 5.6
- `PSScriptBuilderTemplateProcessor.ValidateTemplate()` — body passes `$this.HasCrossDependencies`; must be updated to `$this.UseOrderedMode` (handled explicitly in 5.3.1)
- `PSScriptBuilderTemplateAnalyzer.Analyze()` — see 5.4.1

Also update the `Write-Verbose` log label inside `Validate()`:
```powershell
// Before:
Write-Verbose "Validating template (HasCrossDependencies: $hasCrossDependencies)..."

// After:
Write-Verbose "Validating template (UseOrderedMode: $useOrderedMode)..."
```

#### 5.2.2 Rename `ValidateInCrossDependenciesMode` → `ValidateInOrderedMode`

`hidden` method called from exactly one place (`Validate()`). Functional logic: **unchanged**.

Also update the `Write-Verbose` label at the top of the method:
```powershell
// Before:
Write-Verbose "  Cross-dependencies mode: Validating template placeholders..."

// After:
Write-Verbose "  Ordered/Hybrid mode: Validating template placeholders..."
```

This label is read by users running with `-Verbose`. After the rename the method handles both Ordered
(`HasCrossDependencies = true`) and Hybrid (`HasCrossDependencies = false`, `{{ORDERED_COMPONENTS}}` present).
A label that says "Cross-dependencies" would be factually wrong for the Hybrid case.

#### 5.2.3 `ValidateNoUnknownPlaceholders` — remove `$hasCrossDependencies` parameter

**New signature:**
```powershell
static hidden [void] ValidateNoUnknownPlaceholders(
    [string]                         $templateContent,
    [string]                         $orderedComponentsKey,
    [PSScriptBuilderCollectorBase[]] $collectors
)
```

**Changes inside the method:**

1. Remove conditional guard; `{{ORDERED_COMPONENTS}}` is always known:
   ```powershell
   $knownPlaceholders.Add("{{{{{0}}}}}" -f $orderedComponentsKey) | Out-Null
   ```

2. Replace conditional `$knownKeysInfo` block with single unconditional assignment:
   ```powershell
   $knownKeysInfo = "a registered collector or '{0}'" -f ("{{{{{0}}}}}" -f $orderedComponentsKey)
   ```

**Call sites to update (within same file):**
- `ValidateInOrderedMode()`: remove `$true` argument
- `ValidateInFreeMode()`: remove `$false` argument

**Rationale:** `ValidateNoUnknownPlaceholders` enforces typo-checking, not mode rules.
Mode enforcement is the job of `ValidateCollectorPlaceholdersExist` and
`ValidateNoForbiddenPlaceholders`. One method, one responsibility.

#### 5.2.4 `ValidateNoForbiddenPlaceholders` — generalize error text

This method is called from `ValidateInOrderedMode`, which now handles both `Ordered` mode
(`HasCrossDependencies = true`) and `Hybrid` mode (`HasCrossDependencies = false`,
`templateHasOrderedPlaceholder = true`). The current error text references
"cross-dependencies mode" — factually wrong for the Hybrid case.

**Current text:**
```
"Template validation failed: In cross-dependencies mode, Enum/Class/Function placeholders
are forbidden (components are in {{ORDERED_COMPONENTS}}). Found: {0}"
```

**New text** (mode-neutral):
```
"Template validation failed: Enum/Class/Function placeholders are forbidden when
{{ORDERED_COMPONENTS}} is used (components must share the single ordered placeholder). Found: {0}"
```

Method signature and logic: **unchanged**.

#### 5.2.5 `ValidateInFreeMode` — NO CHANGE

`ValidateInFreeMode` is only called when `$useOrderedMode = false`, which means
`templateHasOrderedPlaceholder` is also `false` by definition. A Hybrid-branch inside
`ValidateInFreeMode` would be unreachable dead code — the Hybrid case is already handled
correctly by `ValidateInOrderedMode`.

`ValidateInOrderedMode` (renamed from `ValidateInCrossDependenciesMode`) already verifies:
- `{{ORDERED_COMPONENTS}}` is present
- No forbidden Enum/Class/Function placeholders
- Using placeholder order
- No duplicates
- No unknown placeholders

All of these are the correct rules for both `Ordered` and `Hybrid` mode.

The only change to `ValidateInFreeMode` is that the `$false` argument to
`ValidateNoUnknownPlaceholders` is removed (covered by 5.2.3). No logic change.

---

### 5.3 `PSScriptBuilderTemplateProcessor` — 2 changes

#### 5.3.1 Rename property, parameter, and method

| Old | New | Location |
|---|---|---|
| `[bool] $HasCrossDependencies` | `[bool] $UseOrderedMode` | Property declaration |
| `$this.HasCrossDependencies = $hasCrossDependencies` | `$this.UseOrderedMode = $useOrderedMode` | Constructor body (property assignment) |
| `$hasCrossDependencies` | `$useOrderedMode` | Constructor parameter (signature) |
| `$this.HasCrossDependencies` | `$this.UseOrderedMode` | `ValidateTemplate()` body — explicit property reference that must be updated |
| `RenderCrossDependenciesMode` | `RenderOrderedMode` | Method definition + call site in `Render()` |

**Note on `ValidateTemplate()`:** The current body passes `$this.HasCrossDependencies` to
`PSScriptBuilderTemplateValidator::Validate()`. After the property rename this reference would
silently pass `$null`/`$false` at runtime — PowerShell 5.1 does not throw on a missing property
via `$this.` in all contexts. This change is NOT automatic; it must be made explicitly.

Also update the constructor `Write-Verbose` log label:
```powershell
// Before:
Write-Verbose "TemplateProcessor initialized with ordered components key: $orderedComponentsKey (HasCrossDependencies: $hasCrossDependencies)"

// After:
Write-Verbose "TemplateProcessor initialized with ordered components key: $orderedComponentsKey (UseOrderedMode: $useOrderedMode)"
```

#### 5.3.2 `Render()` — routing based on `$this.UseOrderedMode`

**Current:**
```powershell
Write-Verbose "Rendering template (HasCrossDependencies: $($this.HasCrossDependencies))..."
$result = $this.TemplateContent
if ($this.HasCrossDependencies) {
    $result = $this.RenderCrossDependenciesMode($result, $orderedComponents)
} else {
    $result = $this.RenderFreeMode($result, $orderedComponents)
}
```

**New:**
```powershell
Write-Verbose "Rendering template (UseOrderedMode: $($this.UseOrderedMode))..."
$result = $this.TemplateContent
if ($this.UseOrderedMode) {
    $result = $this.RenderOrderedMode($result, $orderedComponents)
} else {
    $result = $this.RenderFreeMode($result, $orderedComponents)
}
```

`RenderFreeMode()` body: **NO CHANGE**.  
`RenderOrderedMode()` — functional logic: **NO CHANGE**; but also update the `Write-Verbose` label at the top:
```powershell
// Before:
Write-Verbose "  Mode: Cross-Dependencies (flexible)"

// After:
Write-Verbose "  Mode: Ordered/Hybrid (flexible)"
```
This label is read by users running with `-Verbose`. The method now handles both Ordered and Hybrid mode.
`DiscoverReplacements()`, `AssembleFromReplacements()`, `ReplaceOrderedComponentsPlaceholder()`: **NO CHANGE**.

---

### 5.4 `PSScriptBuilderTemplateAnalyzer` — 2 changes

#### 5.4.1 `Analyze()` — derive `$validationMode` and `$useOrderedMode`

The existing Step 5 block must be **replaced** (not extended). It currently runs before
Step 6 and cannot reference `$placeholdersFound`. The replacement block moves logically
between Step 6 and Step 7, and derives both `$validationMode` and `$useOrderedMode`
before either is used downstream.

Derive `$validationMode` (reporting) and `$useOrderedMode` (routing) separately:
```powershell
// Before:
if ($dependencyResult.HasCrossDependencies) {
    $validationMode = [PSScriptBuilderTemplateValidationMode]::CrossDependencies
} else {
    $validationMode = [PSScriptBuilderTemplateValidationMode]::Free
}

// After:
$orderedPlaceholderToken       = "{{{{{0}}}}}" -f $this.OrderedComponentsKey
$templateHasOrderedPlaceholder = $placeholdersFound -contains $orderedPlaceholderToken
$useOrderedMode                = $dependencyResult.HasCrossDependencies -or $templateHasOrderedPlaceholder

if ($dependencyResult.HasCrossDependencies) {
    $validationMode = [PSScriptBuilderTemplateValidationMode]::Ordered
} elseif ($templateHasOrderedPlaceholder) {
    $validationMode = [PSScriptBuilderTemplateValidationMode]::Hybrid
} else {
    $validationMode = [PSScriptBuilderTemplateValidationMode]::Free
}
```

The old `# Step 5: Determine validation mode` inline comment and its 3-line `if/else` block are
**completely removed**. The old Step 6 through Step 10 labels keep their current text unchanged
(no renumbering of what stays). The replacement block above is inserted between Step 6 and Step 7
with a **non-numbered** comment to avoid mis-ordering:
```powershell
# Derive $useOrderedMode and $validationMode (placeholders must be known first)
```

Do **not** use `# Step 5 (replaced):` — it would produce the nonsensical sequence
`# Step 6`, `# Step 5 (replaced):`, `# Step 7` in the final file.

**`$validationMode`** carries the three-way distinction for the Result object (reporting).
**`$useOrderedMode`** is the bool used for all routing decisions downstream — Hybrid and Ordered
are indistinguishable at the rendering/validation layer.

Update `BuildExpectedPlaceholders` call (Step 7):
```powershell
$placeholdersExpected = $this.BuildExpectedPlaceholders($useOrderedMode, $collectors)
```

Update `Validate()` call (Step 9):
```powershell
[PSScriptBuilderTemplateValidator]::Validate(
    $templateContent,
    $this.OrderedComponentsKey,
    $useOrderedMode,          // was: $dependencyResult.HasCrossDependencies
    $collectors
)
```

**Note:** `$dependencyResult.HasCrossDependencies` is still passed to the result object
unchanged — it reflects code structure, not rendering strategy.

#### 5.4.2 `BuildExpectedPlaceholders()` — parameter + Hybrid branch

**Signature change:** replace `$validationMode` with `$useOrderedMode`:

```powershell
hidden [string[]] BuildExpectedPlaceholders(
    [bool]                           $useOrderedMode,
    [PSScriptBuilderCollectorBase[]] $collectors
)
```

**Logic:**
```powershell
if ($useOrderedMode) {
    # Ordered mode (CrossDependencies or Hybrid Free+Ordered):
    # ORDERED_COMPONENTS required; Using and File allowed; Enum/Class/Function in ORDERED_COMPONENTS
    $expectedList.Add("{{{{{0}}}}}" -f $this.OrderedComponentsKey)
    foreach ($collector in $collectors) {
        $type = $collector.CollectorType
        if ($type -eq [PSScriptBuilderCollectorType]::UsingCollector -or
            $type -eq [PSScriptBuilderCollectorType]::FileCollector) {
            $expectedList.Add("{{{{{0}}}}}" -f $collector.CollectionKey)
        }
    }
} else {
    # Traditional Free mode: all collectors expected individually
    foreach ($collector in $collectors) {
        $expectedList.Add("{{{{{0}}}}}" -f $collector.CollectionKey)
    }
}
```

---

### 5.5 `PSScriptBuilderBuildOrchestrator` — derive `$useOrderedMode`

In `ExecuteBuild()`, after template loading and dependency analysis:

```powershell
$orderedPlaceholderToken       = "{{{{{0}}}}}" -f $this.OrderedComponentsKey
$templateHasOrderedPlaceholder = $this.TemplateContent -match [Regex]::Escape($orderedPlaceholderToken)
$useOrderedMode                = $analysisResult.HasCrossDependencies -or $templateHasOrderedPlaceholder

$finalScript = $this.ProcessTemplate(
    $analysisResult.OrderedComponents,
    $useOrderedMode               // was: $analysisResult.HasCrossDependencies
)
```

`ProcessTemplate()` parameter rename: `$hasCrossDependencies` → `$useOrderedMode`.

**Note:** `BuildResult` still receives `$analysisResult.HasCrossDependencies` unchanged —
this property reflects code structure and remains meaningful to the user.

---

### 5.6 `Test-PSScriptBuilderTemplate` — derive `$useOrderedMode`

`Test-PSScriptBuilderTemplate` uses `PSScriptBuilderDependencyAnalyzer` directly (not
`TemplateAnalyzer`). The result is a `PSScriptBuilderDependencyAnalysisResult`, which has
no `ValidationMode` property. The bool must be derived from the two raw inputs:

```powershell
// After $analyzer.Analyze():
$orderedPlaceholderToken = "{{{{{0}}}}}" -f $OrderedComponentsKey
$useOrderedMode = $analysisResult.HasCrossDependencies -or ($templateContent -match [Regex]::Escape($orderedPlaceholderToken))

[PSScriptBuilderTemplateValidator]::Validate(
    $templateContent,
    $OrderedComponentsKey,
    $useOrderedMode,          // was: $analysisResult.HasCrossDependencies
    $collectors
)
```

---

## 6. What Is NOT Changed

| File | Reason |
|---|---|
| `PSScriptBuilderDependencyAnalyzer.ps1` | `HasCrossDependencies` = code structure fact — correct name |
| `PSScriptBuilderCrossDependencyDetector.ps1` | Detector name describes what it detects — correct |
| `PSScriptBuilderDependencyAnalysisResult.ps1` | `HasCrossDependencies` is a code-structure property — correct |
| `PSScriptBuilderBuildResult.ps1` | `HasCrossDependencies` reported to user as code-structure fact — correct |
| `PSScriptBuilderTemplateAnalysisResult.ps1` | `HasCrossDependencies` property retained; `ValidationMode` docstring updated |
| `Format-PSScriptBuilderBuildResult.ps1` | Uses `HasCrossDependencies` from `BuildResult` — correct |
| `Get-PSScriptBuilderDependencyAnalysis.ps1` | Uses `HasCrossDependencies` from `DependencyAnalysisResult` — correct |
| `RenderFreeMode()` body | Unchanged — individual placeholder replacement, injection-safe two-phase |
| `RenderOrderedMode()` body | Unchanged — Using → File → ORDERED_COMPONENTS sequence |
| All collectors | No mode awareness |
| All other cmdlets | No change |

---

## 7. Edge Cases

### 7.1 `{{ORDERED_COMPONENTS}}` + individual Enum/Class/Function in Free mode

Template: `{{ClassDefinitions}}\n{{ORDERED_COMPONENTS}}`

`$templateHasOrderedPlaceholder = true` → `$useOrderedMode = true` → Hybrid path →
`ValidateNoForbiddenPlaceholders()` throws: `{{ClassDefinitions}}` is a forbidden Class placeholder. ✓

### 7.2 `{{ORDERED_COMPONENTS}}` only, no collectors

`ValidateInOrderedMode` → `ValidateOrderedPlaceholderExists` passes. `ValidateNoForbiddenPlaceholders` — no collector placeholders present, nothing to forbid.
`RenderOrderedMode()` → `ReplaceOrderedComponentsPlaceholder()` with empty list
→ renders `# No components (enums, classes, functions)`. ✓

### 7.3 `{{ORDERED_COMPONENTS}}` + Using, correct order

`ValidateUsingPlaceholderOrder(..., $orderedComponentsKey)` → Using before ORDERED_COMPONENTS → passes. ✓

### 7.4 `{{ORDERED_COMPONENTS}}` + Using, wrong order

`ValidateUsingPlaceholderOrder` → Using after ORDERED_COMPONENTS → throws. ✓

### 7.5 `{{ORDERED_COMPONENTS}}` + File collector

`ValidateNoForbiddenPlaceholders` — File is allowed. ✓

### 7.6 Using registered but no `{{UsingStatements}}` in Hybrid template

`ValidateInOrderedMode` does not call `ValidateCollectorPlaceholdersExist` — this is
consistent with existing Ordered mode behavior (same gap exists today). The missing
Using placeholder is not caught. **Does NOT throw.** ✓

Note: Plugging this gap is out of scope for this plan.

### 7.7 Traditional Free mode (no `{{ORDERED_COMPONENTS}}`)

`$useOrderedMode = false` → existing Free mode path, completely unchanged. ✓

### 7.8 CrossDependencies mode, `{{ORDERED_COMPONENTS}}` missing from template

`$HasCrossDependencies = true`, `$templateHasOrderedPlaceholder = false`
→ `$useOrderedMode = true` → Ordered validation → `ValidateOrderedPlaceholderExists` throws.
Same behavior as before. ✓

### 7.9 CrossDependencies mode, `{{ORDERED_COMPONENTS}}` present

`$useOrderedMode = true` → `RenderOrderedMode()` called. Same behavior as before. ✓

### 7.10 Hybrid: Free code + Ordered template

`$HasCrossDependencies = false`, `$templateHasOrderedPlaceholder = true`
→ `$useOrderedMode = true` → Ordered validation + Ordered rendering.
`ValidationMode = Hybrid`, `HasCrossDependencies = false` in result. ✓

---

## 8. `PSScriptBuilderTemplateAnalysisResult` — Documentation Update Only

The `ValidationMode` property docstring update:
```
// Before:
- CrossDependencies: Only ORDERED_COMPONENTS placeholder allowed

// After:
- Hybrid: Free mode codebase (HasCrossDependencies = false) with explicit
  {{ORDERED_COMPONENTS}} in the template. Renders identically to Ordered mode.
- Ordered: HasCrossDependencies = true. {{ORDERED_COMPONENTS}} placeholder required.
  Individual Enum/Class/Function placeholders are forbidden.
```

The `HasCrossDependencies` property docstring is unchanged — it correctly describes code structure.

---

## 9. Test Impact

### 9.1 Existing Tests — Required Updates

**`PSScriptBuilderTemplateAnalysisResult.Tests.ps1`** (3 items):
- `It` description: `'Should set ValidationMode to CrossDependencies'` → `'Should set ValidationMode to Ordered'`
- Line 65: `[PSScriptBuilderTemplateValidationMode]::CrossDependencies` → `::Ordered`
- Line 67: `[PSScriptBuilderTemplateValidationMode]::CrossDependencies` → `::Ordered`

**`PSScriptBuilderTemplateAnalyzer.Tests.ps1`:**
- Context name `'Analyze - CrossDependencies mode'` → `'Analyze - Ordered mode'`
- Any `::CrossDependencies` code references → `::Ordered`

**`PSScriptBuilderTemplateProcessor.Tests.ps1`:**
- Constructor calls: positional args unchanged; parameter name changes only affect readability
- Context name `'Render - CrossDependencies mode'` → `'Render - Ordered mode'`
- `It` description: `'Should replace Using placeholder before ORDERED_COMPONENTS in CrossDependencies mode'` → `'...in Ordered mode'`

**`PSScriptBuilderTemplateValidator.Tests.ps1`:**
- Context name `'Validate - CrossDependencies mode'` → `'Validate - Ordered mode'`
- `It` description: `'Should throw when a Class collector placeholder is present (forbidden in CrossDependencies)'` → `'...forbidden when {{ORDERED_COMPONENTS}} is used'`
- `It` description: `'Should throw when an Enum collector placeholder is present (forbidden in CrossDependencies)'` → `'...forbidden when {{ORDERED_COMPONENTS}} is used'`
- `It` description: `'Should throw when a Function collector placeholder is present (forbidden in CrossDependencies)'` → `'...forbidden when {{ORDERED_COMPONENTS}} is used'`
- `It` description: `'Should NOT throw for a valid CrossDependencies template with only ORDERED_COMPONENTS'` → `'Should NOT throw for a valid Ordered mode template with only ORDERED_COMPONENTS'`

**`PSScriptBuilderTemplateValidation.Integration.Tests.ps1`:**
- Context name `'Example 06: CrossDependencies Mode - valid template with ORDERED_COMPONENTS placeholder'` → `'Example 06: Ordered Mode - valid template with ORDERED_COMPONENTS placeholder'`
- `It` description: `'Should return true for a valid CrossDependencies Mode template'` → `'Should return true for a valid Ordered Mode template'`

**`PSScriptBuilderBuild.Integration.Tests.ps1`:**
- Context name `'Example 06: CrossDependencies Mode - dependency order respected in output'` → `'Example 06: Ordered Mode - dependency order respected in output'`

### 9.2 New Tests Required

**`PSScriptBuilderTemplateValidator.Tests.ps1` — new context:**
```
Context 'Validate - Hybrid mode ($useOrderedMode = $true, HasCrossDependencies = $false)'
```

| Scenario | Expected |
|---|---|
| `{{ORDERED_COMPONENTS}}` only, no collectors | Should NOT throw |
| `{{ORDERED_COMPONENTS}}` + Using before it | Should NOT throw |
| `{{ORDERED_COMPONENTS}}` + Using after it | Should throw |
| `{{ORDERED_COMPONENTS}}` + File present | Should NOT throw |
| `{{ORDERED_COMPONENTS}}` + Class registered, no `{{ClassDefinitions}}` in template | Should NOT throw |
| `{{ORDERED_COMPONENTS}}` + `{{ClassDefinitions}}` also present | Should throw (forbidden) |
| `{{ORDERED_COMPONENTS}}` + `{{EnumDefinitions}}` also present | Should throw (forbidden) |
| `{{ORDERED_COMPONENTS}}` + `{{FunctionDefinitions}}` also present | Should throw (forbidden) |
| `{{ORDERED_COMPONENTS}}` + Using registered, no `{{UsingStatements}}` in template | Should NOT throw (consistent with Ordered mode — out of scope) |

**`PSScriptBuilderTemplateProcessor.Tests.ps1` — new context:**
```
Context 'Render - Hybrid Free+Ordered mode ($UseOrderedMode = $true, $HasCrossDependencies = $false)'
```

| Scenario | Expected |
|---|---|
| Class registered, template `{{ORDERED_COMPONENTS}}` | Class source in output, placeholder replaced |
| Two classes with dependency, template `{{ORDERED_COMPONENTS}}` | Correct dependency order in output |
| Using + Class, `{{UsingStatements}}\n{{ORDERED_COMPONENTS}}` | Both placeholders replaced |

**`PSScriptBuilderTemplateAnalyzer.Tests.ps1` — new It items:**

| Scenario | Expected |
|---|---|
| Free mode code + `{{ORDERED_COMPONENTS}}` template, Class collector | `ValidationMode = Hybrid`; `PlaceholdersExpected = [{{ORDERED_COMPONENTS}}]`; `IsValid = true` |
| Free mode code + `{{ORDERED_COMPONENTS}}` template, Using + Class collectors | `ValidationMode = Hybrid`; `PlaceholdersExpected = [{{ORDERED_COMPONENTS}}, {{UsingStatements}}]` |
| Free mode code + `{{ORDERED_COMPONENTS}}` template | `HasCrossDependencies = false` in result (code structure unchanged) |
| Cross-dependencies code + `{{ORDERED_COMPONENTS}}` template | `ValidationMode = Ordered`; `HasCrossDependencies = true` |

---

## 10. Docstring Updates Required

| File | Location | Update |
|---|---|---|
| `PSScriptBuilderTemplateValidationMode.ps1` | Enum + all three value descriptions | Add `Hybrid = 1`; `Ordered = 2`; rename `CrossDependencies`; describe each value's cause and behavior |
| `PSScriptBuilderTemplateValidator.ps1` | Class `.DESCRIPTION` | Add Hybrid path; rename mode references |
| `PSScriptBuilderTemplateValidator.ps1` | `Validate()` `.PARAMETER hasCrossDependencies` | → `$useOrderedMode` |
| `PSScriptBuilderTemplateValidator.ps1` | `IsValid()` `.PARAMETER hasCrossDependencies` | → `$useOrderedMode` |
| `PSScriptBuilderTemplateValidator.ps1` | `ValidateInOrderedMode` `.DESCRIPTION` | New name + note handles CrossDeps and Hybrid |
| `PSScriptBuilderTemplateValidator.ps1` | `ValidateInFreeMode` `.PARAMETER orderedComponentsKey` | Remove `(not used in free mode, but needed...)` note — the text lives in the parameter description, not in `.DESCRIPTION`; `$orderedComponentsKey` is now always relevant for `ValidateNoUnknownPlaceholders` |
| `PSScriptBuilderTemplateValidator.ps1` | `ValidateNoUnknownPlaceholders` `.DESCRIPTION` + `.PARAMETER` + `.EXAMPLE` | Remove `$hasCrossDependencies` param + update `.EXAMPLE` to 3-argument call: `ValidateNoUnknownPlaceholders($template, "ORDERED_COMPONENTS", $collectors)` |
| `PSScriptBuilderTemplateValidator.ps1` | `ValidateNoForbiddenPlaceholders` `.DESCRIPTION` + error text | Mode-neutral language |
| `PSScriptBuilderTemplateProcessor.ps1` | Class `.DESCRIPTION` | Routing by `$UseOrderedMode`; update mode descriptions |
| `PSScriptBuilderTemplateProcessor.ps1` | `$UseOrderedMode` property `.SYNOPSIS` + `.DESCRIPTION` | Rename from `$HasCrossDependencies`; update description (was "True for cross-dependencies mode...") |
| `PSScriptBuilderTemplateProcessor.ps1` | Constructor `.PARAMETER hasCrossDependencies` | → `.PARAMETER useOrderedMode`; update description |
| `PSScriptBuilderTemplateProcessor.ps1` | `Render()` `.DESCRIPTION` | Routing by `$UseOrderedMode` property |
| `PSScriptBuilderTemplateProcessor.ps1` | `Render()` `.PARAMETER orderedComponents` | Remove "Cross-Dependencies Mode" / "Free Mode" bullet labels; use "Ordered/Hybrid mode" / "Free mode" |
| `PSScriptBuilderTemplateProcessor.ps1` | `RenderOrderedMode` `.DESCRIPTION` | New name + handles CrossDeps and Hybrid |
| `PSScriptBuilderTemplateAnalyzer.ps1` | `Analyze()` `.DESCRIPTION` | Document `$useOrderedMode` derivation |
| `PSScriptBuilderTemplateAnalyzer.ps1` | `BuildExpectedPlaceholders` `.DESCRIPTION` | Bool parameter; Hybrid branch |
| `PSScriptBuilderTemplateAnalysisResult.ps1` | `ValidationMode` property description | `Ordered` + Hybrid note |
| `PSScriptBuilderTemplateAnalysisResult.ps1` | Constructor `.PARAMETER validationMode` | "Free or CrossDependencies" → "Free, Hybrid, or Ordered" |
| `PSScriptBuilderBuildOrchestrator.ps1` | `ProcessTemplate()` parameter + `ExecuteBuild()` comment | `$useOrderedMode` derivation |
| `Test-PSScriptBuilderTemplate.ps1` | Inline comment | Document `$useOrderedMode` derivation |
| `Test-PSScriptBuilderTemplate.ps1` | `.DESCRIPTION` (Free Mode bullet list) | "ORDERED_COMPONENTS placeholder forbidden" → "ORDERED_COMPONENTS placeholder is optional (triggers Hybrid mode)" |
| `Test-PSScriptBuilderTemplate.ps1` | `.NOTES` (mode descriptions) | Update 2-mode list (Cross-Dependencies, Free) to include the new Hybrid mode |
| `PSScriptBuilderTemplateValidator.ps1` | `ValidateCollectorPlaceholdersExist` `.SYNOPSIS` + `.DESCRIPTION` | `"registered collectors"` → `"provided collectors"` — the method iterates what it receives; the caller decides the scope |

---

## 11. Implementation Order

1. **`PSScriptBuilderTemplateValidationMode.ps1`** — rename `CrossDependencies` → `Ordered`; add `Hybrid = 1`; `Ordered` moves to `= 2`
2. **`PSScriptBuilderTemplateValidator.ps1`** — `ValidateNoForbiddenPlaceholders` error text (mode-neutral)
3. **`PSScriptBuilderTemplateValidator.ps1`** — `ValidateNoUnknownPlaceholders`: remove `$hasCrossDependencies`, unconditional `$knownKeysInfo`, update 2 internal call sites
4. **`PSScriptBuilderTemplateValidator.ps1`** — rename `$hasCrossDependencies` → `$useOrderedMode` in `Validate()`, `IsValid()`; update `Validate()` `Write-Verbose` label; rename `ValidateInCrossDependenciesMode` → `ValidateInOrderedMode`
5. **`PSScriptBuilderTemplateValidator.ps1`** — `ValidateInFreeMode`: NO CHANGE to method body; internal call to `ValidateNoUnknownPlaceholders` loses `$false` argument (done as part of step 3)
6. **`PSScriptBuilderTemplateProcessor.ps1`** — rename `$HasCrossDependencies` → `$UseOrderedMode` (property + constructor parameter); rename `RenderCrossDependenciesMode` → `RenderOrderedMode` (definition + call site)
7. **`PSScriptBuilderTemplateProcessor.ps1`** — `Render()`: update routing condition + `Write-Verbose`
8. **`PSScriptBuilderTemplateAnalyzer.ps1`** — `BuildExpectedPlaceholders`: `$validationMode` → `$useOrderedMode` bool; Hybrid branch
9. **`PSScriptBuilderTemplateAnalyzer.ps1`** — `Analyze()`: derive `$useOrderedMode`; update `$validationMode` assignment; update `BuildExpectedPlaceholders` + `Validate` call sites
10. **`PSScriptBuilderBuildOrchestrator.ps1`** — derive `$useOrderedMode` in `ExecuteBuild()`; rename `ProcessTemplate()` parameter
11. **`Test-PSScriptBuilderTemplate.ps1`** — derive `$useOrderedMode`; update `Validate()` call

> **Reminder for Step 6**: The `$HasCrossDependencies` → `$UseOrderedMode` property rename requires
> updating `ValidateTemplate()` body explicitly: `$this.HasCrossDependencies` → `$this.UseOrderedMode`.
> Also update the `Write-Verbose` label inside `RenderCrossDependenciesMode` (→ `RenderOrderedMode`)
> and inside `ValidateInCrossDependenciesMode` (→ `ValidateInOrderedMode`) per sections 5.2.2 and 5.3.2.
12. **`PSScriptBuilderTemplateAnalysisResult.ps1`** — docstring update for `ValidationMode`
13. **New unit tests** (Validator Hybrid context, Processor Hybrid context, Analyzer items)
14. **Existing test updates** (enum rename + context name updates)
15. **Build + full test run**
