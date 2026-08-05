# Known Limitations

PSScriptBuilder analyses source code by parsing PowerShell as an abstract syntax tree (AST).
It requires no module imports, no code execution, and no runtime environment during the build.
The following constraints follow from this design and from the tool's scope.

---

## No Source Maps

All collected source files are merged into a single output script. Line numbers in the output
do not correspond to line numbers in any source file.

**Implication:** When the output script throws an error at line 2340, tracing that line back to
a specific source file requires manual searching.

**Workaround:** Build a source map by searching the output file for each component's definition.
The `ComponentDetails` property of the build result provides the component name, type, and
source file. Searching the output lines for the definition pattern gives the exact line number:

```powershell
$result = Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath 'build\Templates\MyProject.ps1.template' `
    -OutputPath   'build\Output\MyProject.ps1'

$outputLines = Get-Content $result.OutputPath

$result.ComponentDetails | ForEach-Object {
    $pattern = switch ($_.Type) {
        'Class'    { "^class\s+$([regex]::Escape($_.Name))\b" }
        'Function' { "^function\s+$([regex]::Escape($_.Name))\b" }
        'Enum'     { "^enum\s+$([regex]::Escape($_.Name))\b" }
        default    { $null }
    }
    if ($null -ne $pattern) {
        $line = ($outputLines | Select-String -Pattern $pattern | Select-Object -First 1).LineNumber
        [PSCustomObject]@{ Name = $_.Name; OutputLine = $line; SourceFile = $_.SourceFile }
    }
} | Format-Table -AutoSize
```

This produces a complete mapping: component name, line number in the output script, and source
file. `Using` and `File` entries are excluded — they have no named definition pattern and are
rarely the source of debugging problems. The map does not add source information to the output
file itself.

---

## Static Analysis Only

The AST parser reads source code as text — it does not execute code at build time. Dependencies
that are only knowable at runtime are not detected.

**Not detected:**

```powershell
# String-based type name passed to New-Object — not detected
$typeName = 'MyClass'
$instance = New-Object $typeName

# Dynamically constructed type name — not detected
$instance = New-Object "My$($suffix)Class"

# Type reference inside Invoke-Expression — not detected
$instance = Invoke-Expression '[MyClass]::new()'
```

**Detected:**

```powershell
# Direct type reference — detected
$instance = [MyClass]::new()

# Typed parameter — detected
param([MyClass] $obj)

# Inheritance — detected
class DerivedClass : MyClass { }
```

**Implication:** If a project uses dynamic type loading, the dependency graph may be incomplete.
In most cases the output script is still collected correctly — the risk is incorrect load order:
if a dynamically referenced class appears after its dependent in the output, the script fails
at load time with a type-not-found error.

**Workaround:** Replace dynamic type references with direct references where possible. If that is
not feasible, assign the dynamically-loaded class its own collector with a dedicated key, then
position that placeholder before any placeholder whose components depend on it:

```powershell
# DynamicallyLoaded is referenced via New-Object — assign it a dedicated key so its
# placeholder can be positioned before all classes that depend on it.
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey "DYNAMICALLY_LOADED" -IncludePath "src\Shared"  |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey "APP_CLASSES"        -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function                                     -IncludePath "src\Public"
```

```powershell title="Template — DYNAMICALLY_LOADED must appear before APP_CLASSES"
{{DYNAMICALLY_LOADED}}
{{APP_CLASSES}}
{{FUNCTION_DEFINITIONS}}
```

---

## No Conditional Compilation

PSScriptBuilder includes all components that match the configured collectors. There is no
mechanism to conditionally include or exclude individual components based on a build target,
environment variable, or flag.

**Implication:** Projects that need different builds for different targets — for example, a
debug build with diagnostic helpers and a production build without them — cannot express this
in a single build configuration.

**Workaround:** Maintain separate build scripts with separate collector configurations per
target. Both can share the same template and the same core source directory:

```powershell title="build-debug.ps1"
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"      |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Diagnostics"

Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath 'build\Templates\MyProject.ps1.template' `
    -OutputPath   'build\Output\MyProject.debug.ps1'
```

```powershell title="build-release.ps1"
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"

Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector `
    -TemplatePath 'build\Templates\MyProject.ps1.template' `
    -OutputPath   'build\Output\MyProject.ps1'
```

The debug build includes `src\Diagnostics`; the release build does not.

---

## No Incremental Builds

Every build re-parses all collected source files from scratch. There is no change detection
and no caching layer.

**Implication:** For the intended target — module-level projects with tens to low hundreds of
source files — full builds complete in well under a second. This is not a practical constraint
at that scale.

For projects that grow significantly beyond this range, consider splitting into independent
sub-modules, each with its own `psscriptbuilder.config.json` and build script. Each sub-module
then builds only its own components, and the overall build time stays proportional to the
size of each individual module rather than the total project size.
