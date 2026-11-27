# Tool Integrations

PSScriptBuilder focuses on one job: assembling your project's source files in dependency order.
Task running, linting, and testing are already solved problems in the PowerShell ecosystem —
PSScriptBuilder doesn't try to replace them. Since its output is a plain PowerShell file, the
same established tools you'd use on any other PowerShell project work on it directly, with no
special adapter needed.

This guide shows how to combine PSScriptBuilder with the most common ones:

- **Invoke-Build** orchestrates the build as one task among others — testing, linting, or publishing.
- **PSScriptAnalyzer** lints the assembled output script for style and correctness issues.
- **Pester** tests the assembled output script to confirm it loads and behaves correctly.

A brief comparison with ModuleBuilder explains when each tool is the better fit.

---

## Invoke-Build

A build is rarely the only step — testing, linting, and publishing usually follow it, often
with dependencies between them (testing should only run after a successful build, for example).

[Invoke-Build](https://github.com/nightroman/Invoke-Build) is a task runner for PowerShell that
handles exactly this: define named tasks with dependencies and run them selectively — similar
to `make` or `rake`, but in pure PowerShell.

PSScriptBuilder works as an assembly step inside an Invoke-Build pipeline: one task assembles
the output script, other tasks handle testing, linting, or publishing. Each task remains
independently runnable.

```powershell title=".build.ps1"
#Requires -Modules PSScriptBuilder, InvokeBuild

task SetRoot {
    Set-PSScriptBuilderProjectRoot -Path $BuildRoot
}

task Build SetRoot, {
    $script:result = New-PSScriptBuilderContentCollector |
        Add-PSScriptBuilderCollector -Type Class -IncludePath 'src\Classes' |
        Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions' |
        Invoke-PSScriptBuilderBuild -TemplatePath 'build\MyProject.ps1.template' `
                                    -OutputPath   'build\Output\MyProject.ps1'
}

task Analyze Build, {
    $issues = Invoke-ScriptAnalyzer -Path 'build\Output\MyProject.ps1'
    if ($issues) { throw "PSScriptAnalyzer found $($issues.Count) issue(s)." }
}

task Test Build, {
    Invoke-Pester -Path 'tests' -CI
}

task . Build, Analyze, Test
```

Run the default task (Build → Analyze → Test):

```powershell
Invoke-Build
```

Run only the build step:

```powershell
Invoke-Build Build
```

Any task can be run in isolation during development, or the full chain in CI — the same
`.build.ps1` file serves both.

---

## PSScriptAnalyzer

Static analysis catches issues before they reach production — but only if you point it at what
actually ships.

[PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) is PowerShell's standard tool
for this, checking for common coding issues, style violations, and potential bugs using a set
of built-in and customizable rules.

Running PSScriptAnalyzer against the assembled output script — rather than the individual
source files — verifies the final artifact, including any generated or injected content from
the template.

```powershell
$outputPath = 'build\Output\MyProject.ps1'

# Run with default rules
$issues = Invoke-ScriptAnalyzer -Path $outputPath

# Show results
$issues | Format-Table RuleName, Severity, Line, Message -AutoSize

# Fail if any errors or warnings found
$blocking = $issues | Where-Object { $_.Severity -in 'Error', 'Warning' }
if ($blocking) {
    throw "PSScriptAnalyzer: $($blocking.Count) blocking issue(s) found."
}
```

Some default rules don't fit assembled output the way they would hand-written source — a
template might intentionally inject a `Write-Host` banner, which `PSAvoidUsingWriteHost` would
otherwise flag. To suppress specific rules for the entire output file, use a PSScriptAnalyzer
settings file:

```powershell title="PSScriptAnalyzerSettings.psd1"
@{
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSAvoidTrailingWhitespace'
    )
}
```

Pass it to the analysis run:

```powershell
$issues = Invoke-ScriptAnalyzer -Path $outputPath -Settings .\PSScriptAnalyzerSettings.psd1
```

!!! tip "Analyze source files during development"
    For fast feedback during development, run PSScriptAnalyzer against the individual source
    files in `src\`. Reserve the output-file analysis for CI — it catches issues introduced
    by the assembly process itself (e.g. template injection, ordering artifacts).

Add it as its own step in your workflow — an Invoke-Build task, for example — so linting
failures are caught before a broken script reaches CI or production.

---

## Pester

Testing the assembled output — not just the individual source files — confirms that dependency
ordering, template rendering, and everything else the build does actually produced a working
script.

[Pester](https://pester.dev), the standard testing framework for PowerShell, can target it
directly: dot-sourcing the output in a `BeforeAll` block, then testing normally, confirms that
all components load without errors and behave as expected.

```powershell title="tests\MyProject.Tests.ps1"
BeforeAll {
    . $PSScriptRoot\..\build\Output\MyProject.ps1
}

Describe 'MyProject' {
    Context 'Class loading' {
        It 'loads without errors' {
            { [MyClass]::new() } | Should -Not -Throw
        }
    }

    Context 'Functions' {
        It 'Get-MyData returns a result' {
            Get-MyData | Should -Not -BeNullOrEmpty
        }
    }
}
```

Run the tests:

```powershell
Invoke-Pester -Path 'tests' -Output Detailed
```

!!! warning "Run tests in a fresh PowerShell session"
    PowerShell class type definitions loaded via dot-sourcing cannot be unloaded from the
    session. If you rebuild and retest in the same session, stale types may cause unexpected
    failures. Use `pwsh -NoProfile -Command "Invoke-Pester -Path tests"` in CI or open a new
    terminal for each test run locally.

Combined with a file watcher, tests can rerun automatically after every rebuild — see
[Reacting to Build Results](file-watching.md#reacting-to-build-results) in the File Watching
Guide.

Running Pester with `CodeCoverage.Enabled` against the assembled output reports coverage in
output-script line numbers, not source file lines — see
[Translating Pester Code Coverage](source-maps.md#translating-pester-code-coverage) in the
Source Maps Guide for mapping the results back to your original multi-file source.

---

## ModuleBuilder

Not every project has classes or enums with dependencies to resolve — sometimes a naming
convention like `01-ClassName.ps1`, `02-AnotherClass.ps1` is all the ordering a project needs.

[ModuleBuilder](https://github.com/PoshCode/ModuleBuilder) is a well-established tool built
around exactly that: assembling PowerShell modules from multiple files, handling dot-sourcing,
manifest management, and file ordering via naming convention.

**When ModuleBuilder is the better fit:**

- Your project uses only functions — no classes or enums
- You prefer convention-based ordering (file prefixes) over automatic dependency analysis
- You need tight integration with the PowerShell module manifest (`.psd1`) during the build

**When PSScriptBuilder is the better fit:**

- Your project has components (classes, enums, functions) with dependencies that require a specific load order
- You want automatic dependency resolution without manual file naming conventions
- You need template-based output, release management, or post-build analysis as part of
  the same tool

The two tools are not mutually exclusive — ModuleBuilder can handle module structure and
manifest management while PSScriptBuilder handles dependency-ordered assembly of the script
body.

---

## See Also

- [Build Pipeline Guide](build-pipeline.md) — running a build and interpreting its result
- [Source Maps Guide](source-maps.md) — translating Pester code coverage back to source
- [File Watching Guide](file-watching.md) — rerun Pester automatically via `-OnSuccess` on every rebuild
