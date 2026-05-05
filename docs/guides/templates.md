# Templates

A **template** is a plain text file that defines the structure of the generated output script.
PSScriptBuilder replaces `{{Token}}` placeholders with the collected and dependency-ordered
source code from configured collectors. Static text before, between, and after placeholders
is preserved as-is.

The template is what separates PSScriptBuilder from a simple file concatenation tool. It gives
you full control over the structure of the output script — module header comments, `#Requires`
statements, fixed boilerplate, and the order of component blocks are all defined in the
template, not in the build script.

Placeholders use double curly braces around the collector's `CollectionKey`:

```
{{CollectionKey}}
```

PSScriptBuilder supports three validation modes — **Free Mode**, **Hybrid Mode**, and
**Ordered Mode** — which determine which placeholders are required or forbidden in the template.
Free Mode is the default. Ordered Mode is activated automatically when cross-dependencies are
detected. Hybrid Mode is activated manually by placing the ordered components placeholder
(default: `{{ORDERED_COMPONENTS}}`) in a template whose code has no cross-dependencies.

---

## Walkthrough

### 1. Your First Template

The simplest template maps each collector type to a separate placeholder in the expected order:

```powershell title="MyModule.psm1.template"
{{USING_STATEMENTS}}

{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}

{{FILE_CONTENTS}}
```

Each placeholder is replaced with the correctly ordered source code collected by the
corresponding collector. The token names match the default `CollectionKey` for each collector
type — see the [Collectors Guide](collectors.md) for the full list.

### 2. Custom Collection Keys

When you register a collector with a custom `-CollectionKey`, the template must use that key
as the placeholder — e.g. `{{DOMAIN_CLASSES}}` for a collector registered with
`-CollectionKey "DOMAIN_CLASSES"`:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN_CLASSES" -IncludePath "src\Domain"
```

Custom keys are case-insensitive at match time but preserved as written in the template output.

### 3. Validate Your Template

A mismatch between the collectors you registered and the placeholders in the template — a
missing token, a typo in a key, or a wrong ordering — will cause the build to fail with a
validation error. [`Test-PSScriptBuilderTemplate`](../cmdlets/Test-PSScriptBuilderTemplate.md)
catches these problems before the collection and output steps run, without requiring a full build.

Validate your template whenever you add or rename a collector, change a `-CollectionKey`, or
edit the template file:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"

if (Test-PSScriptBuilderTemplate -ContentCollector $contentCollector -TemplatePath "template.psm1") {
    Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
        -TemplatePath "template.psm1" `
        -OutputPath   "output.psm1"
}
```

Add `-Verbose` to see detailed validation messages.

For a full analysis result object, use
[`Get-PSScriptBuilderTemplateAnalysis`](../cmdlets/Get-PSScriptBuilderTemplateAnalysis.md):

```powershell
$analysis = Get-PSScriptBuilderTemplateAnalysis -ContentCollector $contentCollector -TemplatePath "template.psm1"

Write-Host "Valid:   $($analysis.IsValid)"
Write-Host "Mode:    $($analysis.ValidationMode)"
Write-Host "Found:   $($analysis.PlaceholdersFound -join ', ')"
Write-Host "Missing: $($analysis.MissingPlaceholders -join ', ')"
Write-Host "Unknown: $($analysis.UnknownPlaceholders -join ', ')"
```

### 4. Ordered Mode and Hybrid Mode

**Ordered Mode** is activated automatically when classes and functions have mutual dependencies
that require them to be interleaved. In this case PSScriptBuilder cannot emit classes and
functions in separate blocks — they must be interleaved in a single dependency-ordered sequence.

**Hybrid Mode** is activated manually, by placing the ordered components placeholder in a
template whose code has *no* cross-dependencies yet. Use it when you want a template that
remains valid regardless of whether cross-dependencies are introduced later — for example,
when your project is still growing and you want to avoid restructuring the template at the
moment cross-dependencies first appear.

Both modes use the same placeholder:

```powershell
{{USING_STATEMENTS}}
{{ORDERED_COMPONENTS}}
```

All Enum, Class, and Function components are emitted in a single topologically ordered block
at `{{ORDERED_COMPONENTS}}`. Per-type placeholders for those collector types are forbidden in
both modes. `Using` and `File` placeholders remain valid and optional, and `Using` must appear
before `{{ORDERED_COMPONENTS}}`.

Hybrid Mode is useful for mode-agnostic templates: a template using the ordered components
placeholder remains valid regardless of whether cross-dependencies are introduced later,
avoiding the need to restructure the template when the codebase grows.

!!! tip "Protect Free Mode templates from future breakage"
    A Free Mode template will fail validation the moment cross-dependencies are introduced —
    for example, when a new function references a class that also references that function.
    Adding the ordered components placeholder to the template now converts it to Hybrid Mode
    and makes it resilient to such changes without any further restructuring.

The same template before and after converting to Hybrid Mode:

```powershell title="MyModule.psm1.template (Free Mode)"
{{USING_STATEMENTS}}

{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

```powershell title="MyModule.psm1.template (Hybrid Mode)"
{{USING_STATEMENTS}}

{{ORDERED_COMPONENTS}}
```

The placeholder name defaults to `ORDERED_COMPONENTS` and can be overridden with
`-OrderedComponentsKey` on
[`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md) and
[`Test-PSScriptBuilderTemplate`](../cmdlets/Test-PSScriptBuilderTemplate.md). To keep the
template and the build call in sync, store a custom key in `psscriptbuilder.config.json`:

```json title="psscriptbuilder.config.json"
{
    "build": {
        "orderedComponentsKey": "MY_COMPONENTS"
    }
}
```

```powershell
$config = Get-PSScriptBuilderConfiguration
Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath "template.psm1" `
    -OutputPath   "output.psm1" `
    -OrderedComponentsKey $config.Build.OrderedComponentsKey
```

### 5. Combining with Release Management Tokens

A build template can also contain release metadata tokens — version numbers, build timestamps,
Git commit hashes — using the same `{{Token}}` syntax. These tokens are replaced by
[`Update-PSScriptBuilderBumpFiles`](../cmdlets/Update-PSScriptBuilderBumpFiles.md) *before*
the build runs:

```powershell
# Version {{VERSION}} — built {{BUILD_DATE}}
{{USING_STATEMENTS}}
{{CLASS_DEFINITIONS}}
{{FUNCTION_DEFINITIONS}}
```

The release tokens (`{{VERSION}}`, `{{BUILD_DATE}}`) are injected by the bump step and are
gone by the time `Invoke-PSScriptBuilderBuild` validates the template — the build validator
only sees the collector placeholders. The corresponding bump file entry looks like this:

```json title="psscriptbuilder.bumpconfig.json"
{
    "bumpFiles": [
        {
            "description": "Module template — inject version and build date",
            "path": "build\\Templates\\MyModule.psm1.template",
            "tokens": ["VERSION", "BUILD_DATE"]
        }
    ]
}
```

On subsequent releases, the `{{TOKEN}}` placeholders are already gone — use a regex-based
entry to update the already-substituted values. See the
[Release Management Guide](release-management.md) for the full token list, regex placeholder
syntax (`{REGEX_VERSION}`, `{REGEX_BUILD_DATE}`), and multi-entry bump file configuration.

!!! warning "Run bump before build"
    If release tokens are still present in the template when `Invoke-PSScriptBuilderBuild`
    runs, the validator will report them as unknown placeholders and fail. Always call
    `Update-PSScriptBuilderBumpFiles` before `Invoke-PSScriptBuilderBuild`.

---

## Reference

### Placeholder Rules

- Keys are **case-insensitive** at match time
- **No whitespace** inside the braces — `{{ Key }}` is invalid and causes a validation error
- Each placeholder may appear **only once** in the template
- Only keys matching a registered collector (or `{{ORDERED_COMPONENTS}}`) are valid

### Validation Modes

| Mode | When activated | Required | Forbidden |
|---|---|---|---|
| **Free** | No cross-dependencies and no ordered components placeholder in template | One placeholder per collector | — |
| **Hybrid** | No cross-dependencies, but ordered components placeholder present in template | Ordered components placeholder | Per-type placeholders for `Enum`, `Class`, `Function` |
| **Ordered** | Classes and functions have mutual dependencies (automatic) | Ordered components placeholder | Per-type placeholders for `Enum`, `Class`, `Function` |

In Free Mode, two ordering rules are enforced: `Using` placeholders must appear before all
others; `Enum` placeholders must appear before all `Class` and `Function` placeholders. The
position of `File` placeholders is unrestricted relative to `Enum`, `Class`, and `Function`.

In Ordered and Hybrid mode, `Using` placeholders must appear before the ordered components placeholder.

### Validation Error Reference

| Error | Cause | Fix |
|---|---|---|
| Whitespace in placeholder | `{{ Key }}` instead of `{{Key}}` | Remove whitespace inside braces |
| Missing ordered components placeholder | Ordered or Hybrid mode but placeholder absent | Add the ordered components placeholder to the template |
| Forbidden placeholder in Ordered/Hybrid mode | `{{CLASS_DEFINITIONS}}` etc. present when the ordered components placeholder is used | Remove per-type placeholders; use only the ordered components placeholder |
| Collector placeholder missing | A registered collector has no matching placeholder | Add `{{CollectionKey}}` for each collector |
| Wrong placeholder order (Using) | A non-`Using` placeholder appears before `{{USING_STATEMENTS}}` | Move `Using` placeholders before all others |
| Wrong placeholder order (Enum) | A `Class` or `Function` placeholder appears before `{{ENUM_DEFINITIONS}}` | Move `Enum` placeholders before all `Class` and `Function` placeholders |
| Duplicate placeholder | Same `{{Key}}` appears more than once | Remove the duplicate |
| Unknown placeholder | `{{UNKNOWN}}` has no corresponding collector | Remove it or register a matching collector |

### Analysis Result Properties

`Get-PSScriptBuilderTemplateAnalysis` returns a `PSScriptBuilderTemplateAnalysisResult` with:

| Property | Description |
|---|---|
| `IsValid` | Whether the template passed all validation rules |
| `ValidationErrors` | Array of error messages (empty when valid) |
| `ValidationMode` | `Free`, `Hybrid`, or `Ordered` |
| `OrderedComponentsKey` | The placeholder key used for the ordered components block (default: `ORDERED_COMPONENTS`) |
| `HasCrossDependencies` | Whether cross-dependencies were detected |
| `PlaceholdersFound` | All `{{...}}` tokens found in the template (sorted, unique) |
| `PlaceholdersExpected` | Tokens expected based on collectors and mode |
| `MissingPlaceholders` | Expected but not found in template |
| `UnknownPlaceholders` | Found in template but not matching any collector |
| `TemplatePath` | Resolved absolute path to the template file |
| `TemplateSize` | Template character count |

---

## Tips

!!! tip "Always validate before building"
    Use `Test-PSScriptBuilderTemplate` to validate the template without running a full build.
    This gives fast feedback during development and makes template mismatches explicit
    before the collection and output steps run.

!!! tip "Use `-Verbose` during development"
    Both `Test-PSScriptBuilderTemplate` and `Get-PSScriptBuilderTemplateAnalysis` emit verbose
    messages that show exactly which placeholders were found, expected, and missing.

!!! warning "Custom `OrderedComponentsKey` must match in template and build call"
    If you override the default `ORDERED_COMPONENTS` key, the placeholder in the template and
    the `-OrderedComponentsKey` argument must use the same value. Storing it in
    `psscriptbuilder.config.json` is the safest way to keep them in sync.

---

## See Also

- [Release Management Guide](release-management.md) — version tokens and bump file configuration
- [Dependency Analysis Guide](dependency-analysis.md) — how cross-dependencies are detected
