# Building Your First Project

This tutorial walks you through building a complete PSScriptBuilder project from scratch. You
will create the source files, configure PSScriptBuilder, write a template and a build script,
and run your first build. By the end, you have a single deployable `.ps1` script generated
from multiple source files — with all dependencies automatically resolved.

If you already have an existing project and want to adopt PSScriptBuilder, see
[Migrating to PSScriptBuilder](migrating-to-psscriptbuilder.md) instead.

**Prerequisites:** PSScriptBuilder installed — see [Installation](../getting-started/installation.md).

---

## What We're Building

A small HR project with two enums, three classes, and one function — enough to demonstrate
dependency resolution and multi-collector builds. The final project structure looks like this:

```
HRTools/
├── psscriptbuilder.config.json
├── Build-HRTools.ps1
├── src/
│   ├── Enums/
│   │   ├── Department.ps1
│   │   └── EmploymentStatus.ps1
│   ├── Classes/
│   │   ├── Address.ps1
│   │   ├── Person.ps1
│   │   └── Employee.ps1
│   └── Public/
│       └── New-Employee.ps1
└── build/
    ├── Templates/
    │   └── HRTools.ps1.template
    └── Output/
```

---

## 1. Create the Directory Structure

PSScriptBuilder collects each component type from its own directory — one collector per type:

- `src\Enums` — this project's enums
- `src\Classes` — this project's classes
- `src\Public` — this project's functions

Two more directories hold the build's own files, not source code:

- `build\Templates` — the template you write
- `build\Output` — the generated script it produces

Create all five in one call — `-Path` accepts multiple values, and creates any missing
intermediate folders along the way:

```powershell
New-Item -ItemType Directory -Path "HRTools\src\Enums",
                                   "HRTools\src\Classes",
                                   "HRTools\src\Public",
                                   "HRTools\build\Templates",
                                   "HRTools\build\Output"
Set-Location HRTools
```

`Set-Location HRTools` at the end puts you there — every remaining command in this tutorial
assumes you're working from the project root.

---

## 2. Write the Source Files

Each source file contains exactly one component, saved into the matching folder you created
in [Create the Directory Structure](#1-create-the-directory-structure) — the path shown in each
code block's title is exactly where it goes. PSScriptBuilder
discovers the files automatically — file names do not need to match class or enum names, but
it is good practice.

### Enums

Two independent enums, with no dependencies on anything else in the project:

```powershell title="src\Enums\Department.ps1"
enum Department {
    Engineering
    HumanResources
    Finance
    Marketing
}
```

```powershell title="src\Enums\EmploymentStatus.ps1"
enum EmploymentStatus {
    Active
    OnLeave
    Terminated
    Retired
}
```

### Classes

`Address` and `Person` are likewise independent — plain data classes with no references to
other components:

```powershell title="src\Classes\Address.ps1"
class Address {
    [string] $Street
    [string] $City
    [string] $PostalCode
    [string] $Country

    Address([string] $street, [string] $city, [string] $postalCode, [string] $country) {
        $this.Street     = $street
        $this.City       = $city
        $this.PostalCode = $postalCode
        $this.Country    = $country
    }
}
```

```powershell title="src\Classes\Person.ps1"
class Person {
    [string] $FirstName
    [string] $LastName

    Person([string] $firstName, [string] $lastName) {
        $this.FirstName = $firstName
        $this.LastName  = $lastName
    }
}
```

`Employee` inherits from `Person` and references `Address`, `Department`, and `EmploymentStatus`.

PSScriptBuilder detects these dependencies automatically and ensures that all prerequisites appear
before `Employee` in the output — regardless of the order files are on disk.

```powershell title="src\Classes\Employee.ps1"
class Employee : Person {
    [Address]          $Address
    [Department]       $Department
    [EmploymentStatus] $Status
    [DateTime]         $HireDate
    [decimal]          $Salary

    Employee(
        [string]           $firstName,
        [string]           $lastName,
        [Address]          $address,
        [Department]       $department,
        [DateTime]         $hireDate,
        [decimal]          $salary
    ) : base($firstName, $lastName) {
        $this.Address    = $address
        $this.Department = $department
        $this.Status     = [EmploymentStatus]::Active
        $this.HireDate   = $hireDate
        $this.Salary     = $salary
    }
}
```

### Functions

`New-Employee` in turn depends on `Employee` — completing a dependency chain that spans all
three collector types (Enum, Class, Function):

```powershell title="src\Public\New-Employee.ps1"
Function New-Employee {
    [CmdletBinding()]
    [OutputType([Employee])]
    param(
        [Parameter(Mandatory)]
        [string] $FirstName,

        [Parameter(Mandatory)]
        [string] $LastName,

        [Parameter(Mandatory)]
        [Address] $Address,

        [Parameter(Mandatory)]
        [Department] $Department,

        [Parameter(Mandatory)]
        [DateTime] $HireDate,

        [Parameter(Mandatory)]
        [decimal] $Salary
    )

    return [Employee]::new($FirstName, $LastName, $Address, $Department, $HireDate, $Salary)
}
```

---

## 3. Add the Configuration File

Run the following cmdlet to generate `psscriptbuilder.config.json`:

```powershell
New-PSScriptBuilderConfiguration
```

The generated file contains all required fields pre-filled with sensible defaults. The two
fields you will use most are `build.templatePath` and `build.outputPath` — both already point
to the `build\Templates` and `build\Output` directories you created in
[Create the Directory Structure](#1-create-the-directory-structure).

For a full explanation of all fields, see the [Configuration Guide](../guides/configuration.md).

---

## 4. Create the Template

The template defines the structure of the generated output file. Each `{{Token}}` placeholder
is replaced with the collected and dependency-ordered source code of the corresponding collector.

Create `build\Templates\HRTools.ps1.template`:

```powershell title="build\Templates\HRTools.ps1.template"
{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

The placeholders map to the collectors you will configure in the next step:

| Placeholder | Collector type |
|---|---|
| `{{ENUM_DEFINITIONS}}` | `Enum` |
| `{{CLASS_DEFINITIONS}}` | `Class` |
| `{{FUNCTION_DEFINITIONS}}` | `Function` |

For a full explanation of placeholder syntax and the three validation modes, see the
[Templates Guide](../guides/templates.md).

---

## 5. Write the Build Script

Create `Build-HRTools.ps1`. The build script loads the module, sets the project root, reads
the configuration, configures the collectors, and invokes the build:

```powershell title="Build-HRTools.ps1"
using module PSScriptBuilder

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$config = Get-PSScriptBuilderConfiguration

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = Join-Path $config.Build.TemplatePath 'HRTools.ps1.template'
    OutputPath       = Join-Path $config.Build.OutputPath   'HRTools.ps1'
}

Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult
```

Here's what each part does, in detail:

### Loading the Module

`using module PSScriptBuilder` is the correct way to load PSScriptBuilder for any script, and
must be the very first statement in it — see
[Installation](../getting-started/installation.md#step-3-import-the-module) for why
`Import-Module` doesn't work the same way, and what happens if something precedes it.

### Setting the Project Root

PSScriptBuilder needs to know where relative paths (like the collector `-IncludePath` values)
should resolve from — that's set with `Set-PSScriptBuilderProjectRoot`. Passing `$PSScriptRoot`
(the directory of the currently running script) is always the correct value when calling this
from a build script, since it points to that same directory regardless of where you run the
script from or where the project is later moved to.

### Reading the Configuration

Rather than hardcoding the template and output paths, the build script reads them from
`psscriptbuilder.config.json` — generated in
[Add the Configuration File](#3-add-the-configuration-file) — via `Get-PSScriptBuilderConfiguration`,
which returns a typed object.

Using `$config.Build.TemplatePath` and `$config.Build.OutputPath` means you only need to
update the config file if the directories change — not the build script.

### Configuring the Collectors

Every component type (enums, classes, functions) needs its own collector to scan its source
directory. Here is that part of the script again, to keep the explanation next to the code it
describes:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'
```

`New-PSScriptBuilderContentCollector` creates the container that holds all the collectors
together, and each `Add-PSScriptBuilderCollector` call registers one collector on it:

- **`-Type`** determines which kind of component the collector looks for — `Enum`, `Class`, or
  `Function` — which in turn determines which template placeholder its output fills:
    - `Enum` → `{{ENUM_DEFINITIONS}}`
    - `Class` → `{{CLASS_DEFINITIONS}}`
    - `Function` → `{{FUNCTION_DEFINITIONS}}`
- **`-IncludePath`** tells it which directory to scan for source files

Piping the three `Add-PSScriptBuilderCollector` calls together registers all three on the
same container.

### Assembling and Invoking the Build

Two things remain: bundling all the parameters together, then invoking the build with them.

```powershell
$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = Join-Path $config.Build.TemplatePath 'HRTools.ps1.template'
    OutputPath       = Join-Path $config.Build.OutputPath   'HRTools.ps1'
}

Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult
```

`$buildParams` collects every parameter into a single hashtable — the collector container from
above, plus the template and output file paths built from the same `$config` values already
read — instead of passing each one to `Invoke-PSScriptBuilderBuild` individually. `Join-Path`
combines each configured directory with the specific file name (`HRTools.ps1.template`,
`HRTools.ps1`).

`Invoke-PSScriptBuilderBuild @buildParams` then runs the build. The `@` triggers
[splatting](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-5.1)
— it passes each hashtable key as a matching named parameter, equivalent to writing
`-ContentCollector $contentCollector -TemplatePath ... -OutputPath ...` directly.

Piping the result into `Format-PSScriptBuilderBuildResult` turns the raw result object into the
readable Build Summary shown in [Run the Build](#6-run-the-build).

---

## 6. Run the Build

With the source files, configuration, template, and build script all in place, run the build:

```powershell
.\Build-HRTools.ps1
```

Expected output:

```
WARNING: 5 cross-collector dependency(s) detected. Verify template placeholder order. Run with -Verbose for details.

Build Summary
  Output : ...\build\Output\HRTools.ps1
  Size   : 2.14 KB
  Time   : 312.45 ms

Components
  Enums     : 2
  Classes   : 3
  Functions : 1
  Total     : 6
```

The warning is a feature, not a problem to fix: PSScriptBuilder sorts components correctly
*within* each collector's placeholder, but it cannot reorder placeholders *across* collectors in
your template — so instead of silently risking the wrong output order, it flags cross-collector
dependencies and asks you to confirm the template placeholder order yourself.

Here are the five cross-collector dependencies it found:

- `Employee` (Class) references `Department` (Enum)
- `Employee` (Class) references `EmploymentStatus` (Enum)
- `New-Employee` (Function) references `Address` (Class)
- `New-Employee` (Function) references `Department` (Enum)
- `New-Employee` (Function) references `Employee` (Class)

The generated `build\Output\HRTools.ps1` contains all components in the correct load order:
enums first, then classes in dependency order (`Address` and `Person` before `Employee`), then
functions.

That correctness comes from two different places. PSScriptBuilder resolved the *within-collector*
class order automatically by analyzing the actual code — you never told it `Address` and
`Person` come before `Employee`. The *across-collector* order — enums before classes before
functions — came from the template's placeholder arrangement written in
[Create the Template](#4-create-the-template), which already
lists `{{ENUM_DEFINITIONS}}` before `{{CLASS_DEFINITIONS}}` before `{{FUNCTION_DEFINITIONS}}`.

---

## Summary

You now have a complete PSScriptBuilder project that builds a dependency-ordered script from
six separate source files, with no manual ordering required. Along the way, you configured
three collectors, wrote a template with placeholder tokens, and saw PSScriptBuilder resolve
dependencies automatically — both within a single collector and across collector boundaries,
the same mechanism that produced the cross-collector warning earlier.

In short: you never had to think about component order yourself — PSScriptBuilder handled it
every time, whether the dependency stayed within one collector or crossed into another.

---

## See Also

- [Setting Up Release Management](setting-up-release-management.md) — version bumping, build timestamps, and Git metadata
- [Collectors Guide](../guides/collectors.md) — all collector types and configuration options
- [Templates Guide](../guides/templates.md) — template syntax and available tokens
- [Dependency Analysis Guide](../guides/dependency-analysis.md) — how PSScriptBuilder resolves your project's dependencies
- [CI/CD Integration Guide](../guides/cicd-integration.md) — automating builds in a pipeline
