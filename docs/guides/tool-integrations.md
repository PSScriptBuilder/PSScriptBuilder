# Tool Integrations

PSScriptBuilder fits naturally into existing PowerShell toolchains. This guide shows how to
combine PSScriptBuilder with the most common tools in the PowerShell ecosystem — Invoke-Build
as a task runner, PSScriptAnalyzer for post-build linting, and Pester for testing the generated
output. A brief comparison with ModuleBuilder explains when each tool is the better fit.

---

## Invoke-Build

[Invoke-Build](https://github.com/nightroman/Invoke-Build) is a task runner for PowerShell.
It lets you define named tasks with dependencies and execute them selectively — similar to
`make` or `rake`, but in pure PowerShell.

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

---

## PSScriptAnalyzer

[PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) is a static analysis tool
for PowerShell scripts. It checks for common coding issues, style violations, and potential
bugs using a set of built-in and customizable rules.

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

To suppress specific rules for the entire output file, use a PSScriptAnalyzer
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

---

## Pester

[Pester](https://pester.dev) is the standard testing framework for PowerShell. Tests can
target the assembled output script directly — dot-sourcing it in a `BeforeAll` block
confirms that all components load without errors and behave as expected.

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

---

## ModuleBuilder

[ModuleBuilder](https://github.com/PoshCode/ModuleBuilder) is a well-established tool for
assembling PowerShell modules from multiple files. It handles dot-sourcing, manifest
management, and file ordering using a naming convention (`01-ClassName.ps1`,
`02-AnotherClass.ps1`, etc.).

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
