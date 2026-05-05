# Troubleshooting

Common problems and their solutions. Each entry follows the same structure:
**Symptom:** what you observe, **Cause:** why it happens, **Fix:** how to resolve it.

Problems are grouped by area — build errors, configuration and session errors, template errors,
and environment diagnostics. Use the table of contents on the right to jump directly to the
relevant section.

If your problem is not listed here, run the failing command with `-Verbose` for detailed
execution output. Most collection and build failures include the source file and the exact
component that caused the issue. For environment information to include in a bug report, see
[How do I check which version of PSScriptBuilder is loaded?](#how-do-i-check-which-version-of-psscriptbuilder-is-loaded).

If you cannot resolve the issue, open a
[GitHub issue](https://github.com/PSScriptBuilder/PSScriptBuilder/issues) with the error
message, the `-Verbose` output, and the version information.

---

## Build errors

### Parse errors at build time: unexpected token or missing closing brace

**Symptom:**  
`Invoke-PSScriptBuilderBuild` fails with PowerShell parse errors
pointing to lines that look correct in the source file.

**Cause:**  
The source file contains non-ASCII characters such as em dashes
(`—`), smart quotes, or other typographic characters in comments or
strings. PSScriptBuilder reads files via the PowerShell AST, which requires
valid UTF-8. Non-ASCII characters in comments can produce unexpected byte
sequences that confuse the parser.

**Fix:**  
Replace typographic characters with ASCII equivalents:

| Character | Replace with |
|---|---|
| Em dash (U+2014 `—`) | `--` |
| Smart quotes (U+201C `"`, U+201D `"`) | `"` |
| Ellipsis (U+2026 `…`) | `...` |

To find non-ASCII characters across all source files:

```powershell
Get-ChildItem src -Recurse -Filter "*.ps1" | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    $hits    = [regex]::Matches($content, '[^\x00-\x7F]')
    if ($hits.Count -gt 0) {
        Write-Host "$($_.Name): $($hits.Count) non-ASCII character(s)"
    }
}
```

### Duplicate class or function name: InvalidOperationException at collection time

**Symptom:**  
Collection fails with `InvalidOperationException: Duplicate class 'X'
found in file: ...`

**Cause:**  
Two source files define a class, enum, or function with the same name.
PSScriptBuilder uses fail-fast duplicate detection: the build stops immediately
rather than silently producing ambiguous output.

**Fix:**  
Rename one of the conflicting definitions. Use `-Verbose` to see which
files are being scanned.

### Generated script fails at load time: type-not-found error for a type that exists in the project

**Symptom:**  
The build succeeds but running or importing the generated script fails
immediately with an error such as:
`Unable to find type [BaseClass]` or `Cannot convert null to type [BaseClass]`

**Cause:**  
The generated script contains a class or function that references a type
defined later in the file. This happens when multiple collectors of the same type
are used with custom keys, and the template placeholders are in the wrong order.
PSScriptBuilder sorts components correctly **within** each placeholder block, but it
cannot reorder placeholders in your template. If `{{DOMAIN_CLASSES}}` appears before
`{{CORE_CLASSES}}` in the template, and a class in `DOMAIN_CLASSES` inherits from a
class in `CORE_CLASSES`, the generated script is invalid — even though each individual
collector has the correct internal order.

**Fix:**  
Reorder the template placeholders so that dependencies appear before the
components that depend on them. Use `Get-PSScriptBuilderDependencyAnalysis` to
identify which components depend on which:

```powershell
$result = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector
$result.OrderedComponents  # shows the globally correct dependency order
```

Compare the order of component names against the template placeholder order and adjust
accordingly. See the [Dependency Analysis Guide](guides/dependency-analysis.md#cross-collector-dependencies)
for a full explanation.

---

## Configuration and session errors

### Wrong configuration loaded: tokens unreplaced or build path incorrect

**Symptom:**  
After running one example (or project), a second run in the same
PowerShell session produces errors such as unreplaced `{{VERSION_FULL}}` placeholders,
or files are read from or written to the wrong directory.

**Cause:**  
PSScriptBuilder stores the project root as a process-level global
(`$Global:PSScriptBuilderProjectRoot`). If `Set-PSScriptBuilderProjectRoot` was
called earlier in the same session for a different directory, the cached value
still points to the previous project.

**Fix:**  
Always run each project or example in a **fresh PowerShell session**, or
call `Set-PSScriptBuilderProjectRoot` explicitly at the start of your script:

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot
```

### Build script warning: "has already been executed in this session"

**Symptom:**  
Running the build script scaffolded by `New-PSScriptBuilderProject` (`Build-MyProject.ps1`) a second time in the same
PowerShell session displays:

```text
WARNING: Build-MyProject.ps1 has already been executed in this session.
Start a new PowerShell session to run it again.
```

**Cause:**  
The build script uses `using module PSScriptBuilder` to load the module. In PowerShell 5.1,
module types loaded via `using module` cannot be unloaded or refreshed within the same
process. A second run would silently continue using the type definitions from the first
load — even if `build.ps1` has since produced a newer module on disk. The session guard
prevents this silent stale-type scenario.

**Fix:**  
Start a new PowerShell session and run the build script again. In CI/CD pipelines this
is never an issue — each job starts in a fresh process.

See [The Scaffolded Build Script](guides/build.md#the-scaffolded-build-script) for a
full explanation of the session guard.

### Release data validation fails: git.branch or git.tag too short

**Symptom:**  
`Test-PSScriptBuilderReleaseData` reports:
`Value at path 'git.branch' is shorter than the minimum allowed length of 1`

**Cause:**  
The `psscriptbuilder.releasedata.json` file contains empty strings
(`""`) for optional git fields. The validator accepts `null` for optional fields,
but rejects empty strings because a branch or tag name of length zero is not a
valid value.

**Fix:**  
Set unused git fields to `null`, not `""`:

```json
"git": {
    "commit":      null,
    "commitShort": null,
    "branch":      null,
    "tag":         null
}
```

Git fields are populated automatically when `Update-PSScriptBuilderReleaseData -UpdateGitDetails` is run in a Git repository.

---

## Template errors

### Template placeholder not replaced: remains as {{PlaceholderName}} in output

**Symptom:**  
The generated output file still contains a literal `{{PlaceholderName}}`
instead of the expected content.

**Cause:**  
The placeholder name in the template does not match the `CollectionKey`
of any registered collector. Matching is case-sensitive.

**Fix:**  
Verify that the collector's `CollectionKey` matches the placeholder exactly.
Use `Get-PSScriptBuilderTemplateAnalysis` or `Test-PSScriptBuilderTemplate` to list
all placeholders found in the template and compare them against the registered
collectors:

```powershell
Test-PSScriptBuilderTemplate -TemplatePath $templatePath -ContentCollector $contentCollector
```

### Bump files not updated: {{VERSION_FULL}} remains in template after bumping

**Symptom:**  
After running `Update-PSScriptBuilderBumpFiles`, the template still
contains `{{VERSION_FULL}}` or `{{BUILD_DATE}}` and the subsequent build fails.

**Cause:**  
The bump step ran in a different session from the one that set the
project root, or the bumpconfig file path is relative and was resolved against
the wrong working directory.

**Fix:**  
Ensure `Set-PSScriptBuilderProjectRoot` is called before any release
management or bump cmdlets in the same script.

---

## Diagnosing your environment

### How do I check which version of PSScriptBuilder is loaded?

When reporting a bug or diagnosing unexpected behaviour, it helps to include the
module version and runtime details. PSScriptBuilder exposes two read-only global
variables after import:

```powershell
# Module version, build number, Git commit details
$Global:PSScriptBuilderModuleInfo

# PowerShell version, host application, computer name
$Global:PSScriptBuilderRuntimeInfo
```

Both variables are populated automatically when `using module PSScriptBuilder` is
executed. Do not modify them directly.
