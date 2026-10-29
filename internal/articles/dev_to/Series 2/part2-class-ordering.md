---
title: PowerShell class ordering used to be your problem — PSScriptBuilder makes it automatic
series: Building real PowerShell projects with PSScriptBuilder
tags: powershell, automation, devops, tutorial
cover_image: 
published: false
---

*In Part 1 we built a single deployable script from three standalone functions. In this part we add classes and enums — and see how PSScriptBuilder handles the dependency ordering automatically.*

---

## The problem

PowerShell has a strict rule: a class must be defined **before** it is used. If `Employee` inherits from `Person`, `Person` must appear first in the script. Same for enums — if `Employee` uses a `Department` enum, that enum must be defined before `Employee`.

With a single file this is easy to manage. With multiple files it becomes a maintenance burden: you need to know the dependency graph and keep the file order in sync manually. Add a new base class, and you're back to manually adjusting the load order.

PSScriptBuilder solves this by analyzing the dependencies using PowerShell AST parsing and sorting everything automatically.

---

## The project

We're extending the HR utility library from Part 1 with types:

```
02-classes-and-enums/
├── src/
│   ├── Enums/
│   │   ├── Department.ps1
│   │   └── EmploymentStatus.ps1
│   ├── Classes/
│   │   ├── Address.ps1
│   │   ├── Person.ps1
│   │   └── Employee.ps1        ← inherits Person, uses Address + enums
│   └── Functions/
│       ├── New-Employee.ps1
│       ├── Get-EmployeesByDepartment.ps1
│       └── Set-EmployeeStatus.ps1
└── build/
    └── Templates/
        └── HRTools.ps1.template
```

The dependency chain PSScriptBuilder needs to resolve:

```
Employee : Person
Employee → Address
Employee → Department
Employee → EmploymentStatus
```

`Employee` depends on four other types. PSScriptBuilder detects all of this and sorts accordingly — without any configuration.

---

## The enums and classes

**`Department.ps1`**

```powershell
enum Department {
    Engineering
    HumanResources
    Finance
    Marketing
    Management
}
```

**`EmploymentStatus.ps1`**

```powershell
enum EmploymentStatus {
    Active
    OnLeave
    Terminated
    Retired
}
```

**`Person.ps1`**

```powershell
class Person {
    [string] $FirstName
    [string] $LastName

    Person([string] $firstName, [string] $lastName) {
        $this.FirstName = $firstName
        $this.LastName  = $lastName
    }
}
```

**`Address.ps1`**

```powershell
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

**`Employee.ps1`**

```powershell
class Employee : Person {
    [Address]          $Address
    [Department]       $Department
    [EmploymentStatus] $Status
    [DateTime]         $HireDate
    [decimal]          $Salary

    Employee(
        [string]     $firstName,
        [string]     $lastName,
        [Address]    $address,
        [Department] $department,
        [DateTime]   $hireDate,
        [decimal]    $salary
    ) : base($firstName, $lastName) {
        $this.Address    = $address
        $this.Department = $department
        $this.Status     = [EmploymentStatus]::Active
        $this.HireDate   = $hireDate
        $this.Salary     = $salary
    }
}
```

Two enums and three classes across five files. PSScriptBuilder will figure out the correct order.

---

## The functions

Three functions that use the types defined above as parameter types:

**`New-Employee.ps1`**

```powershell
Function New-Employee {
    [CmdletBinding()]
    [OutputType([Employee])]
    param(
        [Parameter(Mandatory = $true)] [string]     $FirstName,
        [Parameter(Mandatory = $true)] [string]     $LastName,
        [Parameter(Mandatory = $true)] [Address]    $Address,
        [Parameter(Mandatory = $true)] [Department] $Department,
        [Parameter(Mandatory = $true)] [DateTime]   $HireDate,
        [Parameter(Mandatory = $true)] [decimal]    $Salary
    )

    return [Employee]::new($FirstName, $LastName, $Address, $Department, $HireDate, $Salary)
}
```

**`Get-EmployeesByDepartment.ps1`**

```powershell
Function Get-EmployeesByDepartment {
    [CmdletBinding()]
    [OutputType([Employee[]])]
    param(
        [Parameter(Mandatory = $true)] [Employee[]] $Employees,
        [Parameter(Mandatory = $true)] [Department] $Department
    )

    return $Employees | Where-Object { $_.Department -eq $Department }
}
```

**`Set-EmployeeStatus.ps1`**

```powershell
Function Set-EmployeeStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Employee]         $Employee,
        [Parameter(Mandatory = $true)] [EmploymentStatus] $Status
    )

    $Employee.Status = $Status
}
```

All three functions reference `[Employee]`, `[Address]`, `[Department]`, or `[EmploymentStatus]`
as parameter types. PowerShell must have parsed those type definitions before it can load these
functions — another reason the load order matters, and another reason PSScriptBuilder handles it.

---

## The template

The template now has three placeholders — one per component type:

**`HRTools.ps1.template`**

```powershell
# HR Tools
# Generated by PSScriptBuilder - do not edit manually

# --- Enums ---
{{ENUM_DEFINITIONS}}

# --- Classes ---
{{CLASS_DEFINITIONS}}

# --- Functions ---
{{FUNCTION_DEFINITIONS}}
```

---

## The build

Two new collector types are added — `Enum` and `Class`:

```powershell
using module PSScriptBuilder

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$templatePath  = Join-Path $PSScriptRoot "build\Templates\HRTools.ps1.template"
$outputPath    = Join-Path $PSScriptRoot "build\Output\HRTools.ps1"
$enumsPath     = Join-Path $PSScriptRoot "src\Enums"
$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath $enumsPath     |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = $templatePath
    OutputPath       = $outputPath
}

$result = Invoke-PSScriptBuilderBuild @buildParams

Format-PSScriptBuilderBuildResult -BuildResult $result
```

The order in which collectors are registered does not affect the output — collectors always run in the sequence Enum → Class → Function. Within each type, PSScriptBuilder performs a topological sort based on the detected dependencies.

---

## The result

The generated `HRTools.ps1` contains the types in the correct load order:

```
# --- Enums ---
enum Department { ... }
enum EmploymentStatus { ... }

# --- Classes ---
class Person { ... }
class Address { ... }
class Employee : Person { ... }   ← after Person and Address

# --- Functions ---
Function New-Employee { ... }
...
```

`Employee` always appears after `Person`, `Address`, `Department`, and `EmploymentStatus` — regardless of how the source files are sorted on disk.

---

## Bonus: file layout doesn't matter

PSScriptBuilder uses AST parsing to extract definitions, not file naming or directory structure. This means you can put multiple types in a single file and the result is identical.

The following `Domain.ps1` is perfectly valid:

```powershell
enum EmploymentStatus { ... }
enum Department { ... }
class Person { ... }
```

Point all three collectors at the same `src/` directory and PSScriptBuilder sorts out the rest.

> **Want the technical deep-dive?** [How PSScriptBuilder Analyzes PowerShell Dependencies](https://dev.to/tim_hartling/how-psscriptbuilder-analyzes-powershell-dependencies-and-what-happens-when-they-form-a-cycle-1pkh) covers AST extraction, the dependency graph, and cycle detection in detail.

---

## What's next

So far we've been building standalone `.ps1` scripts. In **Part 3**, we switch to building a proper PowerShell **module** — a `.psm1` file with exported functions and strongly-typed objects that callers can use directly.

➡️ *[Part 3: Building a PowerShell module with PSScriptBuilder]*

---

*The complete example is available in the [PSScriptBuilder repository](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/02-classes-and-enums).*