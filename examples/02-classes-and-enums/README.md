# Example 02 - Classes and Enums

This example extends the first by introducing enums and classes with inheritance. PSScriptBuilder
analyzes the type dependencies between `Person`, `Address`, `Employee`, and their enum dependencies
and ensures they appear in the correct order in the generated output - no manual ordering needed.

## New in this example

- `Add-PSScriptBuilderCollector -Type Enum` - collects enum definitions
- `Add-PSScriptBuilderCollector -Type Class` - collects class definitions, resolves inheritance order
- Template placeholders `{{ENUM_DEFINITIONS}}` and `{{CLASS_DEFINITIONS}}`
- Automatic dependency ordering: `Person` before `Employee`, enums before classes

## Key concepts

**Dependency ordering** is handled automatically. The source files can be in any order on disk -
PSScriptBuilder uses AST analysis to detect that `Employee` inherits from `Person` and depends on
`Address`, `EmploymentStatus`, and `Department`, then places them in the correct load order.

**Multiple collectors** of different types are registered on the same `ContentCollector`. Each
collector handles its own type and scans its own directory. The order collectors are added does
not affect the output order - collectors always run in the sequence: Enum, Class, Function.

## Project structure

```
02-classes-and-enums/
+-- Run-Example.ps1                         Entry point
+-- README.md                               This file
+-- src/
|   +-- Enums/
|   |   +-- Department.ps1                  Enum: Engineering, Finance, HumanResources, ...
|   |   +-- EmploymentStatus.ps1            Enum: Active, OnLeave, Terminated, Retired
|   +-- Classes/
|   |   +-- Address.ps1                     Class: Street, City, PostalCode, Country
|   |   +-- Employee.ps1                    Class: inherits Person, has Address + enums
|   |   +-- Person.ps1                      Class: FirstName, LastName
|   +-- Functions/
|       +-- Get-EmployeesByDepartment.ps1   Returns employees matching a given department
|       +-- New-Employee.ps1                Creates a new Employee instance
|       +-- Set-EmployeeStatus.ps1          Updates the status of an employee
+-- build/
    +-- Templates/
    |   +-- HRModule.ps1.template           Template with three placeholders
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
2. Three collectors are added: `Enum` for `src\Enums\`, `Class` for `src\Classes\`, `Function` for `src\Functions\`
3. `Invoke-PSScriptBuilderBuild` analyzes dependencies, sorts components, fills the template, and writes `build\Output\HRModule.ps1`
4. The generated script is dot-sourced and three demo scenarios are executed

## Expected output

```
Build Summary
  Output: ...\build\Output\HRModule.ps1
  Size  : 2.75 KB
  Time  : xxx.xx ms

Components
  Enums    : 2
  Classes  : 3
  Functions: 3
  Total    : 8

Dependencies
  Total     : 11


--- Running generated script ---
Employees in Engineering:
  Anna Schmidt

James Okafor is now: OnLeave
```
