# Example 01 - Functions Only

This example shows the simplest possible PSScriptBuilder build: three standalone PowerShell
functions collected from separate source files and merged into a single output script using
a template. No configuration file, no classes, no enums - just functions and hardcoded paths.

## New in this example

- `New-PSScriptBuilderContentCollector` - creates the content collector
- `Add-PSScriptBuilderCollector -Type Function` - scans a directory for function definitions
- `Invoke-PSScriptBuilderBuild` - runs the build and writes the output file
- `Set-PSScriptBuilderProjectRoot` - sets the project root for path resolution
- Template placeholder `{{FUNCTION_DEFINITIONS}}` - replaced with collected function source code

## Key concepts

**FunctionCollector** scans the specified directory recursively, finds all `Function` definitions
using PowerShell AST parsing, and makes them available as a named placeholder in the template.

**Hardcoded paths** are used intentionally in this first example to keep the focus on the build
pipeline itself. Example 03 introduces `psscriptbuilder.config.json` to replace them.

**The template** is a plain `.ps1` file with one placeholder. PSScriptBuilder replaces
`{{FUNCTION_DEFINITIONS}}` with the collected and sorted function source code.

## Project structure

```
01-functions-only/
+-- Run-Example.ps1                 Entry point
+-- README.md                       This file
+-- src/
|   +-- Get-FormattedName.ps1       Returns "FirstName LastName"
|   +-- Get-YearsOfService.ps1      Returns years of service as a string
|   +-- Format-Salary.ps1           Formats a decimal as a US currency string
+-- build/
    +-- Templates/
    |   +-- HRUtils.ps1.template    Template with {{FUNCTION_DEFINITIONS}} placeholder
    +-- Output/                     Generated output (not committed to source control)
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
2. A `ContentCollector` is created and a `FunctionCollector` is added pointing at `src\`
3. `Invoke-PSScriptBuilderBuild` collects all three functions, fills the template, and writes `build\Output\HRUtils.ps1`
4. The generated script is dot-sourced and three demo calls are made

## Expected output

```
Build Summary
  Output: ...\build\Output\HRUtils.ps1
  Size  : xxx bytes
  Time  : xxx.xx ms

Components
  Functions: 3
  Total    : 3

--- Running generated script ---
Anna Schmidt
7 years
$55,000.00
```
