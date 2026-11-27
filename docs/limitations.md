# Known Limitations

PSScriptBuilder analyses source code by parsing PowerShell as an abstract syntax tree (AST).
It requires no module imports, no code execution, and no runtime environment during the build.
The following constraints follow from this design and from the tool's scope.

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

**Implication:**  
If a project uses dynamic type loading, the dependency graph may be incomplete.
In most cases the output script is still collected correctly — the risk is incorrect load order:
if a dynamically referenced class appears after its dependent in the output, the script fails
at load time with a type-not-found error.

**Workaround:**  
Replace dynamic type references with direct references where possible. If that is
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

This workaround requires **Free Mode**. In Ordered Mode, individual Class, Enum, and Function
placeholders are forbidden — dedicated collector keys have no effect there.

If a dynamic dependency causes a runtime error in the compiled output, see
[Runtime error due to undetected dynamic type dependency](troubleshooting.md#runtime-error-due-to-undetected-dynamic-type-dependency)
in the Troubleshooting guide for a diagnosis workflow and the Ordered Mode constraints.

---

## No Constant Dependency Tracking

PSScriptBuilder's five collectors extract dependency information for `Using` statements,
Enums, Classes, and Functions. Top-level module-scope variable assignments (`$Script:X = ...`),
commonly used as shared constants or lookup tables, have no dedicated collector. They can only
be captured via the generic `File` collector, which includes content verbatim without
AST-based dependency extraction.

**Not detected:**

```powershell
# Content of Constants.ps1, included via the File collector
$Script:StatusLookup = @{ [MyEnum]::Active = 'A' }   # dependency on MyEnum not tracked
```

**Detected** (for comparison — Class/Function type references are tracked):

```powershell
class MyService {
    [MyEnum] $Status   # detected: MyService depends on MyEnum
}
```

**Implication:**  
If a module-scope constant's initializer references an Enum, Class, or another constant,
PSScriptBuilder does not know about this dependency and cannot guarantee correct load order
automatically. If the constant ends up before the type it references in the merged output
script, the build succeeds but the output script fails at load time with a type-not-found
error — no warning is raised at build time, since `File`-collected content is never analyzed
for structural dependencies. Simple, literal constants (`$Script:DefaultTimeout = 30`) are
unaffected, since they have no dependency on other components.

**Workaround:**  
Same approach as for undetected dynamic type dependencies above: assign the file containing
the constants a dedicated `File` collector with its own `CollectionKey`, and manually position
that placeholder before any placeholder whose components the constant references:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum -IncludePath "src\Enums"     |
    Add-PSScriptBuilderCollector -Type File -CollectionKey "CONSTANTS" -IncludePath "src\Constants" |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes"
```

```powershell title="Template — CONSTANTS must appear after ENUM_DEFINITIONS, before CLASS_DEFINITIONS"
{{ENUM_DEFINITIONS}}

{{CONSTANTS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

This workaround requires **Free Mode**, the same constraint as the dynamic type dependency
workaround above.

---

## No Conditional Compilation

PSScriptBuilder includes all components that match the configured collectors. There is no
mechanism to conditionally include or exclude individual components based on a build target,
environment variable, or flag.

**Implication:**  
Projects that need different builds for different targets — for example, a
debug build with diagnostic helpers and a production build without them — cannot express this
in a single build configuration.

**Workaround:**  
Maintain separate build scripts with separate collector configurations per
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

**Implication:**  
For the intended target — module-level projects with tens to low hundreds of
source files — full builds complete in well under a second. This is not a practical constraint
at that scale.

For projects that grow significantly beyond this range, consider splitting into independent
sub-modules, each with its own `psscriptbuilder.config.json` and build script. Each sub-module
then builds only its own components, and the overall build time stays proportional to the
size of each individual module rather than the total project size.

---

## Warnings Not Collected by -WarningVariable

Most PSScriptBuilder warnings are raised inside the module's internal classes. PowerShell does not
pass warnings written inside class methods to the calling command's `-WarningVariable`, so the
variable stays empty even though the warning is displayed. This follows from PowerShell's design:
output streams are not part of class semantics (see
[about_Classes_Methods](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_classes_methods)).

**Affected:**  
`Invoke-PSScriptBuilderBuild`, `Watch-PSScriptBuilderProject`, `Update-PSScriptBuilderBumpFiles`,
`Find-PSScriptBuilderUnusedComponent`, `Resolve-PSScriptBuilderSourceLocation`,
`Get-PSScriptBuilderSourceCoverage`

**Not affected:**  
The warnings are still displayed, and `-WarningAction`, `$WarningPreference` and stream
redirection (`3>&1`) work as usual.

**Implication:**  
A script that checks `-WarningVariable` to detect warnings — for example to fail a CI build —
does not see them.

**Workaround:**  
Redirect the warning stream and separate the warning records from the result:

```powershell
$output   = Invoke-PSScriptBuilderBuild @buildParams 3>&1
$warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
$result   = $output | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }
```

To fail on the first warning instead, use `-WarningAction Stop`, which stops the command with a
terminating error at that warning. `Invoke-PSScriptBuilderBuild` then writes no output script, and
`Update-PSScriptBuilderBumpFiles` changes no bump file — except for the rare warning that a backup
could not be deleted, which is raised after all files were written.
