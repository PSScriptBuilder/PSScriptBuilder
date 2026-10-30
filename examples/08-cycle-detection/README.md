# Example 08 - Cycle Detection

This example demonstrates how PSScriptBuilder detects and reports circular dependencies.
Three service classes form an **Inheritance cycle** (`ServiceA : ServiceB`, `ServiceB : ServiceC`, `ServiceC : ServiceA`).
PSScriptBuilder catches this early and fails with a descriptive error — no broken output is produced.

## New in this example

- **Cycle detection**: PSScriptBuilder detects circular dependencies during dependency analysis
- `HasCycles` and `CyclePath` properties on the `DependencyAnalysisResult`
- `Invoke-PSScriptBuilderBuild` fails fast with `"Circular dependency detected: ..."` when cycles exist
- Use `Get-PSScriptBuilderDependencyAnalysis` to diagnose cycles before attempting a build

## Key concepts

**Cycle detection** runs automatically as part of dependency analysis. If a circular dependency
is found, `HasCycles` is `True` and `CyclePath` contains the component names forming the cycle.

**Fail-fast build**: `Invoke-PSScriptBuilderBuild` runs dependency analysis internally and throws
an `InvalidOperationException` with the cycle path if cycles are detected. No partial output file
is written.

**How to fix a cycle**: Break the dependency chain by introducing an interface (abstraction),
extracting shared state into a separate class, or inverting one of the dependencies.

## Project structure

```
08-cycle-detection/
+-- Run-Example.ps1                         Entry point
+-- README.md                               This file
+-- psscriptbuilder.config.json             Build configuration
+-- src/
|   +-- Classes/
|       +-- ServiceA.ps1                    Inherits from ServiceB
|       +-- ServiceB.ps1                    Inherits from ServiceC
|       +-- ServiceC.ps1                    Inherits from ServiceA  <- closes the cycle
+-- build/
    +-- Templates/
    |   +-- Services.ps1.template           Contains {{CLASS_DEFINITIONS}}
    +-- Output/                             Generated output (not committed to source control)
```

## How to run

> **Warning:** Run in a fresh PowerShell session  
> The `using module` statement loads types into the current session.  
> Reloading or switching between examples in the same session can cause type conflicts.

```powershell
.\Run-Example.ps1
```

For detailed build output:

```powershell
.\Run-Example.ps1 -Verbose
```

## How it works

1. `Set-PSScriptBuilderProjectRoot` sets the project root to the example folder
2. The `ContentCollector` is built with one collector (Class)
3. `Get-PSScriptBuilderDependencyAnalysis` detects `HasCycles: True` and reports the cycle path
4. `Invoke-PSScriptBuilderBuild` is called inside a `try/catch` - it throws immediately with the
   cycle path in the error message
5. The catch block displays the error - no output file is produced

## Expected output

```
Has cycles: True
Cycle path: ServiceA -> ServiceB -> ServiceC -> ServiceA

Attempting build...

Build failed: Build failed. Error: Script building failed. Error: Circular dependency detected: ServiceA -> ServiceB -> ServiceC -> ServiceA
```

> **Note:** The exact cycle path reported may start at a different node depending on DFS traversal
> order, but the same three components will always appear.
