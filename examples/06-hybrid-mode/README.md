# Example 06 - Hybrid Mode

This example introduces Hybrid Mode. The template uses `{{ORDERED_COMPONENTS}}` instead of
individual placeholders. Since no cross-dependencies exist in this project, PSScriptBuilder
detects Hybrid Mode automatically and emits all components in topological order as a single block.

## New in this example

- Template placeholder `{{ORDERED_COMPONENTS}}` - replaces all individual Enum/Class/Function placeholders
- Hybrid Mode: `{{ORDERED_COMPONENTS}}` in template + no cross-dependencies = Hybrid Mode
- `Get-PSScriptBuilderTemplateAnalysis` - analyzes and reports the detected template mode before building

## Key concepts

**Hybrid Mode** is triggered when the template contains `{{ORDERED_COMPONENTS}}` but no
cross-dependencies exist between classes and functions. PSScriptBuilder emits all Enum,
Class, and Function definitions in a single topologically-sorted block in place of the placeholder.

**Why use Hybrid Mode?** When you want a single ordering placeholder without needing to define
separate `{{ENUM_DEFINITIONS}}`, `{{CLASS_DEFINITIONS}}`, and `{{FUNCTION_DEFINITIONS}}` sections.
It also prepares the project for future cross-dependencies without any template changes.

**`Get-PSScriptBuilderTemplateAnalysis`** returns a result object with a `ValidationMode`
property that shows which mode was selected: `Free`, `Hybrid`, or `Ordered`. Calling it before
the build makes the mode selection visible.

## Project structure

```
06-hybrid-mode/
+-- Run-Example.ps1                         Entry point
+-- README.md                               This file
+-- psscriptbuilder.config.json             Build configuration
+-- src/
|   +-- Enums/
|   |   +-- Department.ps1
|   |   +-- EmploymentStatus.ps1
|   +-- Classes/
|   |   +-- Address.ps1
|   |   +-- Employee.ps1
|   |   +-- Person.ps1
|   +-- Functions/
|       +-- Get-EmployeesByDepartment.ps1
|       +-- New-Employee.ps1
|       +-- Set-EmployeeStatus.ps1
+-- build/
    +-- Templates/
    |   +-- HRModule.ps1.template           Contains only {{ORDERED_COMPONENTS}}
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
2. The `ContentCollector` is built with three collectors (Enum, Class, Function)
3. `Get-PSScriptBuilderTemplateAnalysis` analyzes the template and reports `Hybrid` mode
4. `Invoke-PSScriptBuilderBuild` emits all components as one ordered block via `{{ORDERED_COMPONENTS}}`
5. The generated script is dot-sourced and the same demo scenarios as in Example 03 are executed

## Expected output

```
Template mode: Hybrid

Build Summary
  Output: ...\build\Output\HRModule.ps1
  Size  : 2.70 KB
  Time  : xxx.xx ms

Components
  Enums    : 2
  Classes  : 3
  Functions: 3
  Total    : 8

--- Running generated script ---
Employees in Engineering:
  Anna Schmidt

James Okafor is now: OnLeave
```
