# Example 03 - With Configuration

This example introduces `psscriptbuilder.config.json` to decouple build paths from the script
logic. Instead of hardcoding template and output paths, the script loads them from the
configuration file using `Get-PSScriptBuilderConfiguration`.

## New in this example

- `psscriptbuilder.config.json` - configuration file for build paths
- `Get-PSScriptBuilderConfiguration` - loads the configuration for the current project
- `$config.Build.TemplatePath` / `$config.Build.OutputPath` - path properties from config
- Fluent pipeline style: `New-PSScriptBuilderContentCollector | Add-... | Add-... | Invoke-...`

## Key concepts

**Configuration file** (`psscriptbuilder.config.json`) lives in the project root and defines
build-related paths. PSScriptBuilder resolves all paths relative to the project root set by
`Set-PSScriptBuilderProjectRoot`. The `syntaxValidationEnabled: true` setting enables
automatic syntax validation of the build output.

**Fluent pipeline** is introduced here. Instead of assigning the `ContentCollector` to a variable
and adding collectors one by one, collectors are chained directly into `Invoke-PSScriptBuilderBuild`
in a single expression. This is the idiomatic style for PSScriptBuilder from this example onwards.

**Source paths** are still resolved manually with `Join-Path $PSScriptRoot "src\..."`. Only
build output and template paths are managed via config - source file organization remains
the developer's responsibility.

## Project structure

```
03-with-configuration/
+-- Run-Example.ps1                         Entry point
+-- README.md                               This file
+-- psscriptbuilder.config.json             Build configuration (output and template paths)
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
    |   +-- HRModule.ps1.template
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
2. `Get-PSScriptBuilderConfiguration` reads `psscriptbuilder.config.json` and resolves all paths
3. Template and output paths are derived from the config using `Join-Path`
4. Collectors are added and `Invoke-PSScriptBuilderBuild` is called using fluent pipeline chaining
5. The generated script is dot-sourced and the same demo scenarios as in Example 02 are executed

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
