# Example 07 - Ordered Mode

This example introduces Ordered Mode. `Employee`'s own `ToString()` method calls
`Format-EmployeeDisplayName`, a standalone function. PSScriptBuilder detects that the topological
sort places `Format-EmployeeDisplayName` between class definitions, recognizes this as a
cross-dependency, and automatically activates Ordered Mode to emit all components in the correct
interleaved sequence.

## New in this example

- **Ordered Mode**: `{{ORDERED_COMPONENTS}}` + cross-dependencies = Ordered Mode
- `Get-PSScriptBuilderDependencyAnalysis` - analyzes and reports cross-dependencies before building
- Cross-dependency pattern: a class method calls a standalone function

## Key concepts

**Ordered Mode** is activated when the template contains `{{ORDERED_COMPONENTS}}` and
cross-dependencies are detected. PSScriptBuilder uses the topologically-sorted order and emits
all components (classes, functions, enums) interleaved in a single block - in exactly the sequence
required for the script to load correctly.

**Why cross-dependencies arise** in this example:

```
Person                        (no deps)
Employee                   -> Person, Format-EmployeeDisplayName
Contractor                 -> Person
Format-EmployeeDisplayName -> Person
New-Person                 -> Person
New-Employee                -> New-Person, Employee
New-Contractor              -> New-Person, Contractor
```

Free Mode's fixed layout - all classes first, then all functions - already handles every one of
these dependencies except one: `Employee`'s own `ToString()` method calls
`Format-EmployeeDisplayName`. That function needs `Person` (a class) but is itself needed by
`Employee` (another class) - so it has to be emitted *after* `Person` but *before* `Employee`,
which is only possible with a single interleaved block. `Contractor` also extends `Person` but
calls no function, so its position relative to `Format-EmployeeDisplayName` is unconstrained.
Separate `{{CLASS_DEFINITIONS}}` and `{{FUNCTION_DEFINITIONS}}` placeholders would not work here -
only `{{ORDERED_COMPONENTS}}` supports the required interleaved order.

A function depending on a class - however indirectly, including `New-Employee` and
`New-Contractor` calling `New-Person` which itself references `Person` - never has this problem:
Free Mode already emits all classes before any function. Only the opposite direction, a class
calling a function, forces interleaving.

**`Get-PSScriptBuilderDependencyAnalysis`** runs the full dependency pipeline (graph building,
topological sort, cross-dependency detection) and returns a result object. Use it before building to
understand your component graph and to verify that cross-dependencies are detected as expected.

## Project structure

```
07-ordered-mode/
+-- Run-Example.ps1                         Entry point
+-- README.md                               This file
+-- psscriptbuilder.config.json             Build configuration
+-- src/
|   +-- Classes/
|   |   +-- Contractor.ps1                 Contractor : Person
|   |   +-- Employee.ps1                   Employee : Person, ToString() calls Format-EmployeeDisplayName
|   |   +-- Person.ps1                     Base class (no dependencies)
|   +-- Functions/
|       +-- Format-EmployeeDisplayName.ps1 Uses Person type - called from Employee.ToString()
|       +-- New-Contractor.ps1             Calls New-Person, uses Contractor type
|       +-- New-Employee.ps1               Calls New-Person, uses Employee type
|       +-- New-Person.ps1                 Uses Person type
+-- build/
    +-- Templates/
    |   +-- HRWorkforce.ps1.template        Contains only {{ORDERED_COMPONENTS}}
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
2. The `ContentCollector` is built with two collectors (Class, Function)
3. `Get-PSScriptBuilderDependencyAnalysis` detects `HasCrossDependencies: True` and shows the
   interleaved `OrderedComponents` sequence
4. `Get-PSScriptBuilderTemplateAnalysis` analyzes the template and reports `Ordered` mode
5. `Invoke-PSScriptBuilderBuild` emits all components in the required interleaved sequence via
   `{{ORDERED_COMPONENTS}}`
6. The generated script is dot-sourced and three workforce members are created

## Expected output

```
Has cross-dependencies: True
Ordered components    : Person, Contractor, Format-EmployeeDisplayName, Employee, New-Person, New-Contractor, New-Employee

Template mode: Ordered

Build Summary
  Output: ...\build\Output\HRWorkforce.ps1
  Size  : 2.23 KB
  Time  : xxx.xx ms

Components
  Classes  : 3
  Functions: 4
  Total    : 7

--- Running generated script ---
Employees:
  Anna Schmidt (Engineering, started 2019-03-15)
  James Okafor (Finance, started 2021-07-01)

Contractors:
  Priya Sharma (TechSolutions, 2023-01-01 to 2024-12-31)
```

> **Note:** `Format-EmployeeDisplayName` will always appear between `Contractor` and `Employee` -
> it is genuinely required to load after `Person` and before `Employee`, confirming the
> cross-dependency. `Contractor`'s position right after `Person` is not itself required by any
> dependency (`Contractor` never calls `Format-EmployeeDisplayName`), but PSScriptBuilder still
> orders independent components deterministically - classes before functions - so it reliably
> lands there rather than varying between builds.
