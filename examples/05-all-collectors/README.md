# Example 05 - All Collectors

This example introduces the two remaining collector types: `UsingCollector` for `using namespace`
statements and `FileCollector` for injecting raw file content. It also demonstrates custom
`CollectionKey` values that map directly to template placeholders.

## New in this example

- `Add-PSScriptBuilderCollector -Type Using` - collects `using namespace` statements
- `Add-PSScriptBuilderCollector -Type File -CollectionKey "..."` - injects raw file content with a custom key
- Custom `CollectionKey`: the key name must exactly match the placeholder in the template (`{{Header}}`, `{{Configuration}}`)
- `using namespace` types used in functions: `List[Employee]`, `Regex`, `StringBuilder`

## Key concepts

**UsingCollector** scans source files for `using namespace` statements and deduplicates them.
All unique namespaces are collected into a single `{{USING_STATEMENTS}}` block at the top of the output.
The statements live in the function files where the namespaces are actually needed - the collector
extracts them automatically.

**FileCollector** injects the raw content of one or more files as-is, without any parsing.
This is useful for module headers, configuration blocks, or any content that should appear
verbatim in the output. Each `FileCollector` requires a unique `CollectionKey` that matches
the placeholder in the template.

**Custom CollectionKeys** replace the default key name with a name you choose. The template
placeholder `{{Header}}` maps to the `FileCollector` registered with `-CollectionKey "Header"`.

## Project structure

```
05-all-collectors/
+-- Run-Example.ps1                             Entry point
+-- README.md                                   This file
+-- psscriptbuilder.config.json                 Build configuration
+-- src/
|   +-- Files/
|   |   +-- Header.ps1                          Module comment block (injected verbatim)
|   |   +-- Configuration.ps1                   Script-scoped variables (injected verbatim)
|   +-- Enums/
|   |   +-- Department.ps1
|   |   +-- EmploymentStatus.ps1
|   +-- Classes/
|   |   +-- Address.ps1
|   |   +-- Employee.ps1
|   |   +-- Person.ps1
|   +-- Functions/
|       +-- Format-EmployeeReport.ps1           Uses StringBuilder (System.Text) - includes using namespace
|       +-- Get-EmployeesByDepartment.ps1       Returns List[Employee] (System.Collections.Generic) - includes using namespace
|       +-- New-Employee.ps1
|       +-- Set-EmployeeStatus.ps1
|       +-- Test-EmailAddress.ps1               Uses Regex (System.Text.RegularExpressions) - includes using namespace
+-- build/
    +-- Templates/
    |   +-- HRModule.ps1.template               Six placeholders including {{Header}} and {{Configuration}}
    +-- Output/                                 Generated output (not committed to source control)
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
2. Six collectors are added: Using, two File collectors (Header + Configuration), Enum, Class, Function
3. `Invoke-PSScriptBuilderBuild` fills all six template placeholders and writes the output
4. The generated script is dot-sourced and three demo calls are made

## Expected output

```
Build Summary
  Output: ...\build\Output\HRModule.ps1
  Size  : 4.27 KB
  Time  : xxx.xx ms

Components
  Using    : 3
  Enums    : 2
  Classes  : 3
  Functions: 5
  Files    : 2
  Total    : 15

Dependencies
  Total     : 12


--- Running generated script ---
Employee Report
  Name      : Anna Schmidt
  Department: Engineering
  Status    : Active
  Hire Date : 2019-03-15
  Salary    : $75,000.00

Test-EmailAddress 'anna.schmidt@example.com' : True
Test-EmailAddress 'not-an-email'             : False
```
