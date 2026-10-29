# Troubleshooting

Common problems and their solutions. Entries under Build and Runtime Errors, Configuration and
Session Errors, and Template Errors follow the same structure: **Symptom:** what you observe,
**Cause:** why it happens, **Fix:** how to resolve it. Entries under Diagnosing Your
Environment are direct how-to answers instead, since they are not tied to a specific error.

Problems are grouped by area — build and runtime errors, configuration and session errors,
template errors, and environment diagnostics. Use the table of contents on the right to jump
directly to the relevant section.

If your problem is not listed here, run the failing command with `-Verbose` for detailed
execution output. Most collection and build failures include the source file and the exact
component that caused the issue. For environment information to include in a bug report, see
[How do I check which version of PSScriptBuilder is loaded?](#how-do-i-check-which-version-of-psscriptbuilder-is-loaded).

If you cannot resolve the issue, open a
[GitHub issue](https://github.com/PSScriptBuilder/PSScriptBuilder/issues) with the error
message, the `-Verbose` output, and the version information.

---

## Build and Runtime Errors

### Parse errors at build time: invalid UTF-8 encoding

**Symptom:**  
`Invoke-PSScriptBuilderBuild` fails with an `InvalidOperationException`
whose message contains "due to invalid UTF-8 encoding", naming the
offending source file.

**Cause:**  
The source file is not valid UTF-8 — for example, it was saved in a
legacy codepage (e.g. Windows-1252) instead of UTF-8. PSScriptBuilder
reads every source file explicitly as UTF-8, regardless of byte order
mark (BOM) presence, so a file that genuinely isn't valid UTF-8 fails
clearly instead of silently producing corrupted output.

**Fix:**  
Re-save the file as UTF-8 (with or without a BOM — both are read
correctly) in your editor, then re-run the build.

### Duplicate class or function name: InvalidOperationException at collection time

**Symptom:**  
Collection or dependency analysis fails with `InvalidOperationException`, for example
`Duplicate class 'X' found in file: ...`, `Component name conflict: 'X' is defined as a Class
more than once - in '...' and '...'`, or `Component name conflict: 'X' is defined as both a
Class (in '...') and a Function (in '...')`.

**Cause:**  
Two source files define a class, enum, or function with the same name (case-insensitive) -
either within the same collector's scanned files, across two different collectors of the same
type (e.g. two Class collectors scanning separate directories), or as both a Class and a
Function. PSScriptBuilder uses fail-fast duplicate detection at every level: the build stops
immediately rather than silently dropping one component's source code or producing ambiguous
output.

**Fix:**  
Rename one of the conflicting definitions. Use `-Verbose` to see which
files are being scanned by which collector.

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
accordingly. See the [Dependency Analysis Guide](guides/dependency-analysis.md#dependencies-across-collectors)
for a full explanation.

### Runtime error in compiled output: line number points to generated file

**Symptom:**  
An error thrown when running or importing the compiled output script shows a line number
(e.g. `At line:1042 char:5`) that refers to the generated file. Finding the actual source
requires manually searching through the combined output.

**Cause:**  
PSScriptBuilder merges components from multiple source files into a single output script.
All error line numbers refer to that generated file, not to the original source files.

**Fix:**  
Build with `-WriteSourceMap` to generate a sidecar `.sourcemap.json` alongside the output
script. Then use
[`Resolve-PSScriptBuilderSourceLocation`](cmdlets/Resolve-PSScriptBuilderSourceLocation.md)
to map the error back to its original source file and line.

Resolve a specific line number obtained from the error message:

```powershell
Resolve-PSScriptBuilderSourceLocation `
    -OutputPath 'build\Output\MyProject.ps1' `
    -LineNumber  1042
```

Resolve an `ErrorRecord` directly — the most common case when the error is caught in a
`try/catch` block. The cmdlet extracts the line number from `InvocationInfo.ScriptLineNumber`
automatically:

```powershell
$result = ... | Invoke-PSScriptBuilderBuild -OutputPath 'build\Output\MyProject.ps1' -WriteSourceMap

try { . $result.OutputPath }
catch { $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_ }
```

The output shows the component name, its source file, and the corresponding source line:

```text
ComponentName       : Employee
ComponentType       : Class
SourceFile          : C:\MyProject\src\Classes\Employee.ps1
SourceLineNumber    : 18
ComponentLineNumber : 18
OutputLineNumber    : 1042
Offset              : 0
```

A warning is emitted if the output script has been modified since the source map was written.
Resolution still proceeds but line numbers may be inaccurate — rebuild with `-WriteSourceMap`
to refresh the sidecar.

For the complete workflow including the configuration file option and full source map
inspection, see [Source Maps](guides/source-maps.md) in the Source Maps Guide.

### Code coverage reports 0% or "referenced a file other than the build output"

**Symptom:**  
Pester's `CodeCoverage` result shows 0% coverage for every file, or
`Get-PSScriptBuilderSourceCoverage` emits a warning such as:
`214 coverage entr(y/ies) referenced a file other than the build output.`

**Cause:**  
`CodeCoverage.Path` was pointed at the original source files (e.g. `src\Classes`) instead of
the built output script. Pester only has execution records for files it actually loaded — for
class-based projects loaded via `using module`, or any project tested by dot-sourcing the
built output, that is the merged file, not the individual source files.

**Fix:**  
Set `CodeCoverage.Path` to the same output path used when building:

```powershell
$config.CodeCoverage.Path = $buildResult.OutputPath
```

Then translate the results back to per-source-file coverage with
`Get-PSScriptBuilderSourceCoverage`. See
[Translating Pester Code Coverage](guides/source-maps.md#translating-pester-code-coverage) in
the Source Maps Guide for the complete workflow.

### Runtime error due to undetected dynamic type dependency

**Symptom:**  
The output script loads successfully but fails at runtime with an error such as:
`Cannot find type [PluginClass]` or `New-Object : Cannot find type [PluginClass]`.
The class exists in the project and is present in the build output.

**Cause:**  
The class is referenced through a dynamic type name — for example, `New-Object $typeName` or
`New-Object "PluginClass"`. PSScriptBuilder's static AST analysis cannot detect this
dependency and may place the referenced class after the class that uses it. The missing
dependency is only exposed at runtime when the dynamic reference is resolved.

**Fix:**  
**Step 1 — Identify the source file using the source map.**  
Build with `-WriteSourceMap`, then resolve the failing line number back to the originating
source file:

```powershell
Resolve-PSScriptBuilderSourceLocation `
    -OutputPath 'build\Output\MyProject.ps1' `
    -LineNumber  <line from error message>
```

**Step 2 — Fix the load order.**  
Assign the dynamically-referenced class its own collector with a dedicated key, then place
that placeholder before the placeholder whose components depend on it:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "PLUGINS"     -IncludePath "src\Plugins"  |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "APP_CLASSES" -IncludePath "src\Classes"  |
    Add-PSScriptBuilderCollector -Type Function                           -IncludePath "src\Public"
```

```powershell title="Template — PLUGINS must appear before APP_CLASSES"
{{PLUGINS}}
{{APP_CLASSES}}
{{FUNCTION_DEFINITIONS}}
```

!!! note "Ordered Mode"
    This fix requires explicit placeholder control and only works in **Free Mode**. In
    Ordered Mode all Class, Enum, and Function collector placeholders — including custom keys
    like `{{PLUGINS}}` — are forbidden. All components are merged into `{{ORDERED_COMPONENTS}}`
    and sorted by the dependency graph. Because the dynamic dependency is not in the graph, the
    relative order of the two classes remains unpredictable and cannot be controlled through
    template placement. The only resolution in this case is to replace the dynamic type
    reference with a direct reference so PSScriptBuilder can include it in the dependency
    graph.

See [Static Analysis Only](limitations.md#static-analysis-only) for the full explanation
of this limitation.

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

### How do I make a CurrentUser install visible to both PowerShell editions on Windows?

This applies to Windows only. Windows is the only platform where PowerShell exists as two
separate editions side by side — Windows PowerShell (`powershell.exe`) and PowerShell 7+
(`pwsh.exe`) — each with its own default module folder. Linux and macOS only ever run
PowerShell 7+, so there is nothing to unify there.

On Windows, `Install-Module` run from one edition is not automatically visible to `Get-Module`
in the other, even though both point at the same user account. Both editions start from the
same persisted `PSModulePath` value at startup and layer their own default module folders on
top of it, so you can permanently add one edition's module folder to the other's search path
instead of installing PSScriptBuilder twice:

```powershell
# 1. Read the current persistent PSModulePath for this user account — often empty by
#    default, since most machines never set it explicitly
$currentPath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')

# 2. Append the PowerShell 7+ module folder, keeping whatever was already there
if ($currentPath) {
    $newPath = "$currentPath;$HOME\Documents\PowerShell\Modules"
}
else {
    $newPath = "$HOME\Documents\PowerShell\Modules"
}

# 3. Save it back, permanently, for this user account
[Environment]::SetEnvironmentVariable('PSModulePath', $newPath, 'User')
```

Run this once, from either edition, then open a new PowerShell window for it to take effect.
From then on, a `-Scope CurrentUser` install done from either edition is visible to both.

Two things worth knowing before using it:

- **It is a permanent, global change**, not something scoped to one script or session. It sets
  a `User`-level environment variable that every future PowerShell session on this account —
  of either edition — will read from then on.
- **It only unifies `-Scope CurrentUser`.** `-Scope AllUsers` installs to a separate,
  edition-specific folder under `Program Files` for each edition; unifying that as well
  requires the same change at `Machine` scope, which needs administrator rights and affects
  every account on the machine, not just yours.
