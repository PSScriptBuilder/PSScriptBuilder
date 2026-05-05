# Migrating to PSScriptBuilder

This tutorial covers two scenarios: starting from a single monolithic file that contains all
your code, and starting from a project that already uses separate files but has no build system
yet. Both end in the same place — a working PSScriptBuilder project that generates a single
deployable output file.

**Prerequisites:** PSScriptBuilder installed — see [Installation](../getting-started/installation.md).

---

## Scenario A: Starting from a Single File

This is the most common starting point. A single `.psm1` or `.ps1` contains everything —
enums, classes, and functions in one place. It works, but as the file grows it becomes harder
to navigate, test, and maintain. The recommended PSScriptBuilder project structure uses one
file per component — easier to navigate and version-control — so the first step is splitting.

!!! tip "Automated inventory available"
    PSScriptBuilder can identify all components in a monolithic script automatically —
    enums, classes, and functions by name. This saves the manual inventory step and
    ensures nothing is missed. See
    [Analysing a Monolithic Script](../guides/code-analysis.md#analysing-a-monolithic-script)
    in the Code Analysis Guide.

### 1. Identify the Components

Open your file and identify every component: enums, classes, and functions. A monolithic HR
module might look like this:

```powershell title="HRModule.psm1 — before migration"
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

    Employee([string] $firstName, [string] $lastName,
             [Address] $address, [Department] $department) : base($firstName, $lastName) {
        $this.Address    = $address
        $this.Department = $department
        $this.Status     = [EmploymentStatus]::Active
    }
}

Function New-Employee {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]     $FirstName,
        [Parameter(Mandatory)] [string]     $LastName,
        [Parameter(Mandatory)] [Address]    $Address,
        [Parameter(Mandatory)] [Department] $Department
    )

    return [Employee]::new($FirstName, $LastName, $Address, $Department)
}
```

Note which components depend on which — you will need this later to verify that the generated
output is correct. `Employee` inherits from `Person` and references `Address`, `Department`,
and `EmploymentStatus`. PSScriptBuilder will detect all of these automatically.

### 2. Plan the Directory Structure

PSScriptBuilder uses separate collectors per component type. The recommended directory layout
maps directly to those types:

```
HRModule/
├── psscriptbuilder.config.json
├── Build-HRModule.ps1
├── src/
│   ├── Enums/      ← one file per enum
│   ├── Classes/    ← one file per class
│   └── Public/     ← one file per public function
└── build/
    ├── Templates/
    └── Output/
```

Functions that are not part of the public API belong in `src/Private/` and get their own
collector with `-IncludePath 'src\Private'`.

### 3. Split the File

Create the directories and move each component into its own file. The file name should match
the component name — this is not enforced but makes the project easier to navigate:

```
src/Enums/Department.ps1
src/Enums/EmploymentStatus.ps1
src/Classes/Address.ps1
src/Classes/Person.ps1
src/Classes/Employee.ps1
src/Public/New-Employee.ps1
```

Each file contains exactly one component — the same code as in the original, just separated.
PSScriptBuilder handles the load order automatically.

!!! note "No parse warnings"
    PSScriptBuilder parses each file in isolation. `Unable to find type` warnings that
    PowerShell would normally emit when a class references types from other files are
    suppressed internally — they are expected and not actionable.

### 4. Set Up PSScriptBuilder

From the project root, generate the configuration file:

```powershell
New-PSScriptBuilderConfiguration
```

Create the template at `build/Templates/HRModule.psm1.template`:

```powershell title="build/Templates/HRModule.psm1.template"
{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

Create the build script at the project root:

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

For a detailed walkthrough of each step, see
[Building Your First Project](building-your-first-project.md).

### 5. Run the First Build and Verify

```powershell
.\Build-HRModule.ps1
```

Open `build/Output/HRModule.psm1` and compare it with your original file. The content should
be equivalent — same components, same logic — but in a PSScriptBuilder-determined load order:
enums first, then classes in dependency order, then functions.

---

## Scenario B: Starting from Separate Files

If your project already has separate files per component, the migration is straightforward —
you only need to add PSScriptBuilder configuration and a build script. No file changes required.

### 1. Map Your Directories to Collector Types

PSScriptBuilder collects components by type, each from its own directory. Check whether your
existing structure maps cleanly:

| What you have | Collector type | Recommended path |
|---|---|---|
| Enum definitions | `Enum` | `src\Enums` |
| Class definitions | `Class` | `src\Classes` |
| Exported functions | `Function` | `src\Public` |
| Internal functions | `Function` | `src\Private` |
| Raw files (headers, footers) | `File` | `src\Files` |

If your files are in a flat structure with mixed types — for example a single `src/` folder
containing both classes and functions — you have two options:

- **Reorganise** into type-specific subdirectories (recommended — cleaner, matches PSScriptBuilder's model)
- **Use file-level filtering** — `Add-PSScriptBuilderCollector` supports `-IncludeFile` and
  `-ExcludeFile` patterns to include only specific files from a directory. See the
  [Collectors Guide](../guides/collectors.md) for details.

### 2. Set Up PSScriptBuilder

Follow steps 4 and 5 from [Scenario A](#4-set-up-psscriptbuilder) — generate the
configuration file, create the template, write the build script, and run the first build.
The only difference is that the `-IncludePath` values in the build script point to your
existing directories.

Once the first build succeeds, the migration is complete — your project is fully managed by
PSScriptBuilder.

---

## See Also

- [Collectors Guide](../guides/collectors.md) — file filters, collector types, and directory configuration
- [Dependency Analysis Guide](../guides/dependency-analysis.md) — verify detected dependencies and load order
