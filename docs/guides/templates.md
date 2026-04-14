# Templates

A **template** is a plain text file that defines the structure of the generated output script.
PSScriptBuilder replaces `{{Token}}` placeholders with the collected and dependency-ordered
source code from configured collectors. Static text before, between, and after placeholders
is preserved as-is.

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
as the placeholder:

```powershell title="Register a collector with a custom key"
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN_CLASSES" -IncludePath "src\Domain"
```

```powershell title="Matching template token"
{{DOMAIN_CLASSES}}
```

Custom keys are case-insensitive at match time but preserved as written in the template output.

### 3. Validate Your Template

Always validate your template before running a build.
[`Test-PSScriptBuilderTemplate`](../cmdlets/Test-PSScriptBuilderTemplate.md) returns `$true`
if the template is valid for the current collector configuration:

```powershell title="Validate before building"
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

```powershell title="Analyze template"
$result = Get-PSScriptBuilderTemplateAnalysis -ContentCollector $contentCollector -TemplatePath "template.psm1"

Write-Host "Valid:   $($result.IsValid)"
Write-Host "Mode:    $($result.ValidationMode)"
Write-Host "Found:   $($result.PlaceholdersFound -join ', ')"
Write-Host "Missing: $($result.MissingPlaceholders -join ', ')"
Write-Host "Unknown: $($result.UnknownPlaceholders -join ', ')"
```

### 4. Ordered Mode and Hybrid Mode

**Ordered Mode** is activated automatically when classes and functions have mutual dependencies
that require them to be interleaved. **Hybrid Mode** is activated manually — by placing the
ordered components placeholder (default: `{{ORDERED_COMPONENTS}}`) in a template whose code
has no cross-dependencies. Both modes use the same template structure and validation rules:

```powershell title="Ordered / Hybrid Mode template"
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

```powershell title="Build with custom key"
$config = Get-PSScriptBuilderConfiguration
Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath "template.psm1" `
    -OutputPath   "output.psm1" `
    -OrderedComponentsKey $config.Build.OrderedComponentsKey
```

### 5. Combining with Release Management Tokens

A build template can also be configured as a bump file in `psscriptbuilder.bumpconfig.json`.
This allows release metadata — version numbers, build timestamps, Git commit hashes — to be
injected directly into the template using the same `{{Token}}` syntax:

```powershell title="Template with release tokens"
# Version {{VERSION}} — built {{BUILD_DATE}}
{{USING_STATEMENTS}}
{{CLASS_DEFINITIONS}}
{{FUNCTION_DEFINITIONS}}
```

```json title="psscriptbuilder.bumpconfig.json (excerpt)"
{
    "bumpFiles": [
        {
            "description": "Module template — first run: inject release metadata as {{TOKEN}} placeholders",
            "path": "build\\Templates\\MyModule.psm1.template",
            "tokens": ["VERSION", "BUILD_DATE"]
        },
        {
            "description": "Module template — subsequent runs: update already-substituted values via regex",
            "path": "build\\Templates\\MyModule.psm1.template",
            "items": [
                {
                    "pattern": "Version\\s+({REGEX_VERSION})",
                    "tokens": ["VERSION"]
                },
                {
                    "pattern": "built\\s+({REGEX_BUILD_DATE})",
                    "tokens": ["BUILD_DATE"]
                }
            ]
        }
    ]
}
```

`Update-PSScriptBuilderBumpFiles` replaces the release tokens **before** the build runs.

**Entry 1** handles the first release: it finds `{{VERSION}}` and `{{BUILD_DATE}}` in the
template and replaces them with the actual values — for example `1.2.0` and `2026-03-24`.
After this step, those placeholders no longer exist in the template file. The build validator
only sees the remaining collector placeholders and proceeds without error.

**Entry 2** handles all subsequent releases: since the `{{TOKEN}}` placeholders are gone, the
simple token mode from Entry 1 has nothing to match. Entry 2 instead uses regex patterns that
target the already-substituted values — `Version 1.2.0` or `built 2026-03-24` — and replaces
them with the new values on every bump. Both entries target the same file and are applied
sequentially in the order they appear in `bumpFiles`.

See the [Release Management Guide](release-management.md) for the full token list and all
available regex placeholders like `{REGEX_VERSION}` and `{REGEX_BUILD_DATE}`.

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
    Use `Test-PSScriptBuilderTemplate` in your build script to catch configuration mismatches
    early. A validation failure here is far easier to diagnose than a malformed output script.

!!! tip "Use `-Verbose` during development"
    Both `Test-PSScriptBuilderTemplate` and `Get-PSScriptBuilderTemplateAnalysis` emit verbose
    messages that show exactly which placeholders were found, expected, and missing.

!!! warning "Custom `OrderedComponentsKey` must match in template and build call"
    If you override the default `ORDERED_COMPONENTS` key, the placeholder in the template and
    the `-OrderedComponentsKey` argument must use the same value. Storing it in
    `psscriptbuilder.config.json` is the safest way to keep them in sync.

---

## See Also

- [Collectors Guide](collectors.md) — configure collectors and custom collection keys
- [Dependency Analysis Guide](dependency-analysis.md) — how cross-dependencies are detected
- [Release Management Guide](release-management.md) — version tokens and bump file configuration
