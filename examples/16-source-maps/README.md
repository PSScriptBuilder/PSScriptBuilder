# Example 16 - Source Maps

This example demonstrates the source map feature introduced in PSScriptBuilder 1.3.0.

A source map links every line in the compiled output script back to the source file and line
it was generated from. When a runtime error occurs in the output script, error messages show
a line number in the generated file — which is often hundreds or thousands of lines long and
hard to navigate manually. With a source map, `Resolve-PSScriptBuilderSourceLocation` maps
those line numbers back to the original source files in one call.

## New in this example

- `Invoke-PSScriptBuilderBuild -WriteSourceMap` — generates a `.sourcemap.json` sidecar alongside the output script after each successful build
- `Resolve-PSScriptBuilderSourceLocation` — resolves output line numbers or `ErrorRecord` objects back to their originating source file and line

## Key concepts

**Source map generation** is opt-in: pass `-WriteSourceMap` to `Invoke-PSScriptBuilderBuild`.
A sidecar file is written next to the output script with `.sourcemap.json` appended to its
name. It records the source file, line range, and output line for every Class and Function
component in the build.

**Three resolution modes:**

| Mode | Use case |
|------|----------|
| `-LineNumber <int>` | Resolve a specific line number (e.g. copied from an error message) |
| `-ErrorRecord <ErrorRecord>` | Resolve directly from a caught exception — line is extracted from `InvocationInfo` automatically |
| No parameters | Return the full source map as a `PSScriptBuilderSourceLocation[]` for inspection |

**Two input modes** for the output path:

- Via pipeline from a `PSScriptBuilderBuildResult` — no `-OutputPath` needed when the build result is in scope
- Via `-OutputPath` — useful when calling the resolver independently from the build

**Stale detection:** A SHA-256 hash of the output file is stored in the sidecar at build
time. If the output script is modified or rebuilt without `-WriteSourceMap` afterward, a
warning is emitted — resolved line numbers may no longer be accurate.

## Project structure

```
16-source-maps/
+-- Run-Example.ps1                       Entry point
+-- README.md                             This file
+-- src/
|   +-- Classes/
|   |   +-- Person.ps1                    Class: FirstName, LastName
|   |   +-- Employee.ps1                  Class: inherits Person, adds Id and Department
|   +-- Functions/
|       +-- New-Employee.ps1              Factory function for Employee
|       +-- Get-EmployeeById.ps1          Lookup by Id; throws KeyNotFoundException if not found
+-- build/
    +-- Templates/
    |   +-- HRTools.ps1.template          Template with class and function placeholders
    +-- Output/                           Generated output (not committed to source control)
```

## Scenarios

| # | What it shows |
|---|---------------|
| 1 | Full source map — all components with their output line, source file, and source line |
| 2 | Resolve a specific output line number (10 lines into `Get-EmployeeById`) |
| 3 | Catch a `KeyNotFoundException` from `Get-EmployeeById`, resolve its `ErrorRecord` back to source |

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

## Expected output

```
Build Summary
  Output : ...\build\Output\HRTools.ps1
  Size   : x.xx KB
  Time   : xxx ms

Components
  Classes   : 2
  Functions : 2

Source map : ...\build\Output\HRTools.ps1.sourcemap.json

=== Scenario 1: Inspect the full source map ===

ComponentName    ComponentType SourceFile               SourceLineNumber OutputLineNumber
-------------    ------------- ----------               ---------------- ----------------
Person           Class         ...\Person.ps1           1                5
Employee         Class         ...\Employee.ps1         1                16
New-Employee     Function      ...\New-Employee.ps1     1                32
Get-EmployeeById Function      ...\Get-EmployeeById.ps1 1                53

=== Scenario 2: Resolve a specific line number ===

Resolving output line 63 (inside Get-EmployeeById)...

ComponentName       : Get-EmployeeById
ComponentType       : Function
SourceFile          : ...\Get-EmployeeById.ps1
SourceLineNumber    : 11
ComponentLineNumber : 11
OutputLineNumber    : 63
Offset              : 10

=== Scenario 3: Resolve an ErrorRecord ===

Calling Get-EmployeeById with Id=999 (not found) - this throws...

Error at output line 65: Employee with Id 999 was not found.

Resolving to source location:

ComponentName       : Get-EmployeeById
ComponentType       : Function
SourceFile          : ...\Get-EmployeeById.ps1
SourceLineNumber    : 13
ComponentLineNumber : 13
OutputLineNumber    : 65
Offset              : 12
```

The exact line numbers depend on the template and source files. The component-to-source
mapping is what matters — `Get-EmployeeById.ps1 line 13` instead of `HRTools.ps1 line 65`.
