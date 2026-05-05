# Building Your First Project

This tutorial walks you through building a complete PSScriptBuilder project from scratch. You
will create the source files, configure PSScriptBuilder, write a template and a build script,
and run your first build. By the end, you have a single deployable `.psm1` generated from
multiple source files — with all dependencies automatically resolved.

If you already have an existing project and want to adopt PSScriptBuilder, see
[Migrating to PSScriptBuilder](migrating-to-psscriptbuilder.md) instead.

**Prerequisites:** PSScriptBuilder installed — see [Installation](../getting-started/installation.md).

---

## What We're Building

A small HR module with two enums, three classes, and one function — enough to demonstrate
dependency resolution and multi-collector builds. The final project structure looks like this:

```
HRModule/
├── psscriptbuilder.config.json
├── Build-HRModule.ps1
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
    │   └── HRModule.psm1.template
    └── Output/
```

---

## 1. Create the Directory Structure

Create the project folder and all subdirectories:

```powershell
New-Item -ItemType Directory -Path "HRModule\src\Enums",
                                   "HRModule\src\Classes",
                                   "HRModule\src\Public",
                                   "HRModule\build\Templates",
                                   "HRModule\build\Output"
Set-Location HRModule
```

---

## 2. Write the Source Files

Each source file contains exactly one component. PSScriptBuilder discovers the files
automatically — file names do not need to match class or enum names, but it is good practice.

### Enums

```powershell title="src/Enums/Department.ps1"
enum Department {
    Engineering
    HumanResources
    Finance
    Marketing
}
```

```powershell title="src/Enums/EmploymentStatus.ps1"
enum EmploymentStatus {
    Active
    OnLeave
    Terminated
    Retired
}
```

### Classes

```powershell title="src/Classes/Address.ps1"
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

```powershell title="src/Classes/Person.ps1"
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

```powershell title="src/Classes/Employee.ps1"
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

```powershell title="src/Public/New-Employee.ps1"
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

Run the following cmdlet from the project root to generate `psscriptbuilder.config.json`:

```powershell
New-PSScriptBuilderConfiguration
```

The generated file contains all required fields pre-filled with sensible defaults. The two
fields you will use most are `build.templatePath` and `build.outputPath` — both already point
to the `build\Templates` and `build\Output` directories you created in step 1.

For a full explanation of all fields, see the [Configuration Guide](../guides/configuration.md).

---

## 4. Create the Template

The template defines the structure of the generated output file. Each `{{Token}}` placeholder
is replaced with the collected and dependency-ordered source code of the corresponding collector.

Create `build/Templates/HRModule.psm1.template`:

```powershell title="build/Templates/HRModule.psm1.template"
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

Create `Build-HRModule.ps1` at the project root. The build script sets the project root,
configures the collectors, and invokes the build:

```powershell title="Build-HRModule.ps1"
using module PSScriptBuilder

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$config = Get-PSScriptBuilderConfiguration

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = Join-Path $config.Build.TemplatePath 'HRModule.psm1.template'
    OutputPath       = Join-Path $config.Build.OutputPath   'HRModule.psm1'
}

Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult
```

`Set-PSScriptBuilderProjectRoot` tells PSScriptBuilder where to resolve relative paths from.
`$PSScriptRoot` is the directory of the currently running script — always the correct value
when calling this from a build script.

`Get-PSScriptBuilderConfiguration` reads `psscriptbuilder.config.json` and returns a typed
object. Using `$config.Build.TemplatePath` and `$config.Build.OutputPath` means you only
need to update the config file if the directories change — not the build script.

---

## 6. Run the Build

From the project root:

```powershell
.\Build-HRModule.ps1
```

Expected output:

```
Build Summary
  Output : ...\build\Output\HRModule.psm1
  Size   : 2.14 KB
  Time   : 312.45 ms

Components
  Enums     : 2
  Classes   : 3
  Functions : 1
  Total     : 6
```

The generated `build/Output/HRModule.psm1` contains all components in the correct load order:
enums first, then classes in dependency order (`Address` and `Person` before `Employee`), then
functions. You did not specify any ordering — PSScriptBuilder resolved it automatically from
the AST.

---

## Next Steps

- **Set up release management** — version bumping, build timestamps, and Git metadata:
  [Setting Up Release Management](setting-up-release-management.md)
- **Understand dependency analysis** — learn how PSScriptBuilder resolves your project's dependencies:
  [Dependency Analysis Guide](../guides/dependency-analysis.md)

---

## See Also

- [Collectors Guide](../guides/collectors.md) — all collector types and configuration options
- [Templates Guide](../guides/templates.md) — template syntax and available tokens
- [CI/CD Integration Guide](../guides/cicd-integration.md) — automating builds in a pipeline
