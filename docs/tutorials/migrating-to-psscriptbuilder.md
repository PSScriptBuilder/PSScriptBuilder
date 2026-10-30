# Migrating to PSScriptBuilder

This tutorial covers two scenarios: starting from a single monolithic file that contains all
your code, and starting from a project that already uses separate files but has no build system
yet. Both end in the same place — a working PSScriptBuilder project that generates a single
deployable output file.

**Prerequisites:** PSScriptBuilder installed — see [Installation](../getting-started/installation.md).

---

## Scenario A: Starting from a Single File

This is the most common starting point. A single `.psm1` or `.ps1` file contains everything —
enums, classes, and functions in one place. It works, but as the file grows it becomes harder
to navigate, test, and maintain. The recommended PSScriptBuilder project structure uses one
file per component — easier to navigate and version-control — so the first step is splitting.

This example reuses the same HR domain model as
[Building Your First Project](building-your-first-project.md) — the same `Department`,
`EmploymentStatus`, `Address`, `Person`, `Employee`, and `New-Employee` components, shown here
as a single monolithic file instead of already split into one file per component.

You do not need to have worked through Building Your First Project before this one — this
tutorial stands on its own. It does, however, explain the setup mechanics used here from
[Set Up PSScriptBuilder](#4-set-up-psscriptbuilder) onward — configuration, template, build
script — in much more depth than this tutorial does; if you want that depth, look there rather
than here.

If you've already worked through it, the components here will already look familiar, so you
can focus entirely on the migration steps rather than the domain model.

!!! tip "Automated inventory available"
    PSScriptBuilder can identify all components in a monolithic script automatically —
    enums, classes, and functions by name. This saves the manual inventory step and
    ensures nothing is missed. See
    [Analysing a Monolithic Script](../guides/code-analysis.md#analysing-a-monolithic-script)
    in the Code Analysis Guide.

### 1. Identify the Components

Open your file and identify every component: enums, classes, and functions. A monolithic HR
file might look like this:

```powershell title="HRTools.ps1 — before migration"
enum Department {
    Engineering
    HumanResources
    Finance
    Marketing
}

enum EmploymentStatus {
    Active
    OnLeave
    Terminated
    Retired
}

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

class Person {
    [string] $FirstName
    [string] $LastName

    Person([string] $firstName, [string] $lastName) {
        $this.FirstName = $firstName
        $this.LastName  = $lastName
    }
}

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

Note which components depend on which — you will need this later to verify that the generated
output is correct. `Employee` inherits from `Person` and references `Address`, `Department`,
and `EmploymentStatus`. PSScriptBuilder will detect all of these automatically.

### 2. Plan the Directory Structure

PSScriptBuilder uses separate collectors per component type. The recommended directory layout
maps directly to those types:

```
HRTools/
├── psscriptbuilder.config.json
├── Build-HRTools.ps1
├── src/
│   ├── Enums/      ← one file per enum
│   ├── Classes/    ← one file per class
│   └── Public/     ← one file per public function
└── build/
    ├── Templates/
    └── Output/
```

### 3. Split the File

Create the directories and move each component into its own file. The file name should match
the component name — this is not enforced but makes the project easier to navigate:

```
src/
├── Enums/
│   ├── Department.ps1
│   └── EmploymentStatus.ps1
├── Classes/
│   ├── Address.ps1
│   ├── Person.ps1
│   └── Employee.ps1
└── Public/
    └── New-Employee.ps1
```

Each file contains exactly one component — the same code as in the original, just separated.
PSScriptBuilder handles the load order automatically.

PSScriptBuilder parses each file in isolation. `Unable to find type` warnings that PowerShell
would normally emit when a class references types from other files are suppressed internally —
they are expected and not actionable.

### 4. Set Up PSScriptBuilder

From the project root, open a PowerShell session and import the module — none of the cmdlets
work without it:

```powershell
using module PSScriptBuilder
```

Then generate the configuration file:

```powershell
New-PSScriptBuilderConfiguration
```

Create the template at `build\Templates\HRTools.ps1.template`:

```powershell title="build\Templates\HRTools.ps1.template"
{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

Create the build script. It loads the module, sets the project root, reads the configuration,
configures the collectors, and invokes the build:

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

### 5. Run the First Build and Verify

```powershell
.\Build-HRTools.ps1
```

Open `build\Output\HRTools.ps1` and compare it with your original file. The content should
be equivalent — same components, same logic — but in a PSScriptBuilder-determined load order:
enums first, then classes in dependency order, then functions.

Once it matches, the migration is complete — your project is fully managed by PSScriptBuilder.

---

## Scenario B: Starting from Separate Files

If your project already has separate files per component, the migration is usually
straightforward — mostly configuration and a build script, with directory changes only if
your current layout doesn't already match PSScriptBuilder's per-type model (see
[Map Your Directories to Collector Types](#1-map-your-directories-to-collector-types)).

### 1. Map Your Directories to Collector Types

PSScriptBuilder collects components by type. Check whether your existing structure maps
cleanly:

| What you have | Collector type | Recommended path |
|---|---|---|
| Enum definitions | `Enum` | `src\Enums` |
| Class definitions | `Class` | `src\Classes` |
| Exported functions | `Function` | `src\Public` |
| Internal functions | `Function` | `src\Private` |
| Raw files (headers, footers) | `File` | `src\Files` |

If your files are already laid out this way, skip ahead to
[Set Up PSScriptBuilder](#2-set-up-psscriptbuilder). If they're in a flat
structure with mixed types instead — for example a single `src/` folder containing both
classes and functions — reorganising isn't required: a single directory can serve more than
one collector, since each one only picks out the component type it was configured for and
ignores everything else it finds there. Point one collector per type — `Enum`, `Class`, and
`Function` — at the same directory:

```powershell
Add-PSScriptBuilderCollector -Type Enum     -IncludePath 'src'
Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src'
Add-PSScriptBuilderCollector -Type Function -IncludePath 'src'
```

If you'd still prefer the cleaner, one-type-per-folder layout shown in the table — purely for
readability, not because it's required — move the files there and point each collector's
`-IncludePath` at its own dedicated folder (`src\Enums`, `src\Classes`, and so on) instead of
the shared folder shown above — the same per-type pattern shown in
[Scenario A's build script](#4-set-up-psscriptbuilder).

### 2. Set Up PSScriptBuilder

Follow steps 4 and 5 from [Scenario A](#4-set-up-psscriptbuilder) — generate the
configuration file, create the template, write the build script, and run the first build.
The only difference is the collector setup itself: use whichever `-IncludePath`/`-Type`
configuration you worked out in
[Map Your Directories to Collector Types](#1-map-your-directories-to-collector-types), rather
than Scenario A's example paths.

Once the first build succeeds, the migration is complete — your project is fully managed by
PSScriptBuilder.

---

## See Also

- [Collectors Guide](../guides/collectors.md) — file filters, collector types, and directory configuration
- [Dependency Analysis Guide](../guides/dependency-analysis.md) — verify detected dependencies and load order
