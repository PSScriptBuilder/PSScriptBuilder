# Example 04 - Flexible File Structure

This example demonstrates that PSScriptBuilder does not care how source files are organized.
Enums, classes, and functions can coexist in the same file - PSScriptBuilder uses AST parsing
to extract exactly what each collector needs, regardless of file layout.

## New in this example

- Mixed file content: multiple types (enum, class, function) in a single `.ps1` file
- All collectors point to the same `src\` directory - PSScriptBuilder picks the right components

## Key concepts

**AST-based extraction** means PSScriptBuilder parses each file as a PowerShell syntax tree and
extracts only the definitions relevant to each collector. The `EnumCollector` finds enum
definitions, the `ClassCollector` finds class definitions, and the `FunctionCollector` finds
standalone function definitions - all from the same set of files.

**File organization is your choice.** You can group files by type (as in Examples 02-03),
by feature, or mix everything together. The build result is identical either way.

## Project structure

```
04-flexible-file-structure/
+-- Run-Example.ps1                         Entry point
+-- README.md                               This file
+-- psscriptbuilder.config.json             Build configuration
+-- src/
|   +-- Domain.ps1                          Contains: EmploymentStatus (enum), Department (enum), Person (class)
|   +-- Employment.ps1                      Contains: Address (class), Employee : Person (class)
|   +-- HRFunctions.ps1                     Contains: New-Employee, Get-EmployeesByDepartment
+-- build/
    +-- Templates/
    |   +-- HRTools.ps1.template
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
2. All three collectors (`Enum`, `Class`, `Function`) point to the same `src\` directory
3. PSScriptBuilder scans all `.ps1` files in `src\` and each collector extracts its own type
4. Dependency ordering ensures `Person` appears before `Employee`, enums before classes
5. The generated output is identical to Example 03 despite the different file organization

## Expected output

```
Build Summary
  Output: ...\build\Output\HRTools.ps1
  Size  : 2.50 KB
  Time  : xxx.xx ms

Components
  Enums    : 2
  Classes  : 3
  Functions: 2
  Total    : 7

--- Running generated script ---
Employees in Engineering:
  Anna Schmidt
```
