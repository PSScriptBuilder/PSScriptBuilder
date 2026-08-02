# Example 07 - Ordered Mode

This example introduces Ordered Mode. The `Person` class is used by both derived classes (`Employee`,
`Contractor`) and the factory function `New-Person`. PSScriptBuilder detects that the topological sort
places `New-Person` (a function) between class definitions, recognizes this as a cross-dependency, and
automatically activates Ordered Mode to emit all components in the correct interleaved sequence.

## New in this example

- **Ordered Mode**: `{{ORDERED_COMPONENTS}}` + cross-dependencies = Ordered Mode
- `Get-PSScriptBuilderDependencyAnalysis` - analyzes and reports cross-dependencies before building
- Cross-dependency pattern: a function depends on a base type that is also inherited by other classes

## Key concepts

**Ordered Mode** is activated when the template contains `{{ORDERED_COMPONENTS}}` and
cross-dependencies are detected. PSScriptBuilder uses the topologically-sorted order and emits
all components (classes, functions, enums) interleaved in a single block - in exactly the sequence
required for the script to load correctly.

**Why cross-dependencies arise** in this example:

```
Person            (no deps)
Employee       -> Person
Contractor     -> Person
New-Person     -> Person
New-Employee   -> New-Person, Employee     <- function appears between classes
New-Contractor -> New-Person, Contractor   <- function appears between classes
```

`New-Person` is depended upon by both `New-Employee` and `New-Contractor`. Because `Person` is also
the base class of `Employee` and `Contractor`, the topological sort is forced to place `New-Person`
between class definitions. Separate `{{CLASS_DEFINITIONS}}` and `{{FUNCTION_DEFINITIONS}}` placeholders
would not work here - only `{{ORDERED_COMPONENTS}}` supports the required interleaved order.

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
|   |   +-- Employee.ps1                   Employee : Person
|   |   +-- Person.ps1                     Base class (no dependencies)
|   +-- Functions/
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
Ordered components    : Person, Employee, New-Person, Contractor, New-Employee, New-Contractor

Template mode: Ordered

Build Summary
  Output: ...\build\Output\HRWorkforce.ps1
  Size  : 2.01 KB
  Time  : xxx.xx ms

Components
  Classes  : 3
  Functions: 3
  Total    : 6

--- Running generated script ---
Employees:
  Anna Schmidt (Engineering, started 2019-03-15)
  James Okafor (Finance, started 2021-07-01)

Contractors:
  Priya Sharma (TechSolutions, 2023-01-01 to 2024-12-31)
```

> **Note:** The exact ordered components sequence may vary slightly depending on dictionary
> iteration order, but `New-Person` will always appear between class definitions, confirming
> the cross-dependency.
