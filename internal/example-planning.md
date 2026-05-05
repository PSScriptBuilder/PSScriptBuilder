# PSScriptBuilder Examples - Planning Document

**Status**: Approved  
**Date**: 2026-03-27

---

## Table of Contents

1. [Goals](#goals)
2. [Design Principles](#design-principles)
3. [Folder Structure Convention](#folder-structure-convention)
4. [HR Domain Reference](#hr-domain-reference)
5. [Example Catalog](#example-catalog)
6. [README Structure Convention](#readme-structure-convention)
7. [Console Output Convention](#console-output-convention)
8. [Reset Convention](#reset-convention)
9. [MkDocs Integration](#mkdocs-integration)

---

## Goals

- **New users**: Step-by-step introduction from the simplest possible build up to a complete module workflow
- **Experienced users**: Reference examples for specific features (modes, release management, flexible file structure)
- **Showcase**: One advanced example demonstrating PSScriptBuilder at full scale
- **Integration tests**: Example 09 serves as integration test fixture

---

## Design Principles

| Principle | Decision |
|-----------|----------|
| Progression | One new concept per example - each example builds on the previous |
| Independence | Each example is fully self-contained - no example references another |
| Domain | HR system (Person, Employee, Address, enums) for examples 01–09; separate domain for 10 |
| Simplicity | Generated scripts are runnable with minimal, readable demo output |
| File structure | Templates use section comments for readability; FileCollector for headers from example 05 onwards |
| Config usage | `psscriptbuilder.config.json` provides directory paths; `Run-Example.ps1` combines with `Join-Path` to get file paths. Every config file contains ALL options (release + build) - no partial configs. |
| Pipeline style | Examples 01-02 use explicit variables (`$contentCollector = New-...`) with idiomatic pipeline mutation (`$contentCollector \| Add-... \| Out-Null`); fluent chaining style introduced from example 03 onwards |
| WarningPreference | All examples with classes set `$WarningPreference = 'SilentlyContinue'` to suppress expected parse warnings (PSScriptBuilder parses files individually; cross-file types are not available at parse time) |
| Reset | Examples that modify files include a `Reset-Example.ps1` |
| Documentation | Each README is the single source - included in MkDocs via `pymdownx.snippets` |

---

## Folder Structure Convention

Every example folder follows this layout (only applicable parts are created):

```
examples/XX-name/
├── Run-Example.ps1                         # Entry point - runs the build and executes generated script
├── Reset-Example.ps1                       # Only for examples that modify files (09, 10)
├── README.md                               # Explanation - also used by MkDocs via snippets
├── psscriptbuilder.config.json             # Own config (from example 03 onwards)
├── src/                                    # PowerShell source files
│   ├── Enums/
│   ├── Classes/
│   └── Functions/
└── build/
    ├── Templates/
    │   └── *.template                      # Template file(s)
    ├── Output/                             # Generated output lands here (git-ignored)
    └── Release/                            # Only for examples 09 and 10
        ├── psscriptbuilder.releasedata.json
        └── psscriptbuilder.bumpconfig.json
```

**Notes:**

- `build/Output/` is git-ignored so generated files are not committed
- Every `Run-Example.ps1` starts with `Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot`
- Every `Run-Example.ps1` starts with `using module ..\..\build\Output\PSScriptBuilder.psd1`

---

## HR Domain Reference

All examples 01–09 draw from the same HR domain. Each example uses a subset of these components.

### Enums

| Name | Values | First used in |
|------|--------|---------------|
| `EmploymentStatus` | Active, OnLeave, Terminated, Retired | Example 02 |
| `Department` | Engineering, HumanResources, Finance, Marketing, Management | Example 02 |
| `ContractType` | FullTime, PartTime, Contractor, Intern | Example 09 |

### Classes

| Name | Base Class | Dependencies | First used in |
|------|-----------|--------------|---------------|
| `Person` | - | - | Example 02 |
| `Address` | - | - | Example 02 |
| `Employee` | `Person` | `Address`, `EmploymentStatus`, `Department` | Example 02 |
| `Manager` | `Employee` | `Employee` (via inheritance) | Example 09 |
| `Contractor` | `Person` | `Address`, `ContractType` | Example 07 |

### Functions

| Name | Dependencies | First used in |
|------|-------------|---------------|
| `Get-FormattedName` | - (string params only) | Example 01 |
| `Get-YearsOfService` | - (DateTime param) | Example 01 |
| `Format-Salary` | - (decimal param) | Example 01 |
| `New-Employee` | `Employee`, `EmploymentStatus`, `Department` | Example 02 |
| `Get-EmployeesByDepartment` | `Employee`, `Department` -> returns `List[Employee]` (`System.Collections.Generic`) | Example 02 |
| `Set-EmployeeStatus` | `Employee`, `EmploymentStatus` | Example 02 |
| `Test-EmailAddress` | `System.Text.RegularExpressions` (`Regex`) | Example 05 |
| `Format-EmployeeReport` | `Employee`, `System.Text` (`StringBuilder`) | Example 05 |
| `New-Person` | `Person` | Example 07 |
| `New-Contractor` | `Contractor`, `ContractType` | Example 07 |

### Demo Persons

The same persons appear consistently across all examples. Using recognizable names across multiple examples helps users follow the narrative without re-learning the data.

| Name | Department | HireDate | Role |
|------|-----------|----------|------|
| Anna Schmidt | Engineering | 2019-03-15 | Employee |
| James Okafor | Finance | 2021-07-01 | Employee |
| Priya Sharma | HumanResources | 2016-11-20 | Employee |

**Rules:**
- Names are clearly fictional but realistic and culturally diverse
- HireDate values are fixed — do not use dynamic dates like `(Get-Date).AddYears(-6)`
- Use the same persons in the same order wherever demo data appears

---

## Example Catalog

### Learning Examples

---

#### 01 - `functions-only`

**New concept**: FunctionCollector, minimal build, hardcoded paths  
**Learning goal**: Understand the basic build pipeline - source files -> template -> consolidated output

**HR components used:**

- Functions: `Get-FormattedName`, `Get-YearsOfService`, `Format-Salary`

**File structure:**
```
src/
    Get-FormattedName.ps1
    Get-YearsOfService.ps1
    Format-Salary.ps1
build/Templates/
    HRUtils.ps1.template
```

**Template placeholders:** `{{FunctionDefinitions}}`  
**Config:** not used (hardcoded paths)  
**Release Management:** no  
**Reset:** no

**Generated script demo output:**
```
Anna Schmidt
6 years
$55,000.00
```

---

#### 02 - `classes-and-enums`

**New concept**: EnumCollector + ClassCollector, automatic dependency ordering  
**Learning goal**: PSScriptBuilder analyzes class hierarchies and ensures correct load order - no manual ordering needed

**HR components used:**

- Enums: `EmploymentStatus`, `Department`
- Classes: `Person`, `Address`, `Employee : Person`
- Functions: `New-Employee`, `Get-EmployeesByDepartment`, `Set-EmployeeStatus`

**Template placeholders:** `{{EnumDefinitions}}`, `{{ClassDefinitions}}`, `{{FunctionDefinitions}}`  
**Config:** not used (hardcoded paths)  
**Release Management:** no  
**Reset:** no

---

#### 03 - `with-configuration`

**New concept**: `psscriptbuilder.config.json` - decouple build logic from file paths  
**Learning goal**: Use configuration to resolve template and output paths instead of hardcoding them

**HR components used:** same as example 02

**Key pattern:**

```powershell
$config       = Get-PSScriptBuilderConfiguration
$templatePath = Join-Path $config.Build.TemplatesPath "HRModule.ps1.template"
$outputPath   = Join-Path $config.Build.OutputPath    "HRModule.ps1"
```

**Template placeholders:** `{{EnumDefinitions}}`, `{{ClassDefinitions}}`, `{{FunctionDefinitions}}`  
**Config:** `psscriptbuilder.config.json`  
**Release Management:** no  
**Reset:** no

---

#### 04 - `flexible-file-structure`

**New concept**: Mixed types per file, multiple components per file - file organization is irrelevant  
**Learning goal**: PSScriptBuilder uses AST parsing - it extracts exactly what each collector needs, regardless of how source files are organized

**HR components used:**

- Enums: `EmploymentStatus`, `Department`
- Classes: `Person`, `Address`, `Employee : Person`
- Functions: `New-Employee`, `Get-EmployeesByDepartment`

**Deliberately unconventional file structure:**

```
src/
    Domain.ps1              # contains EmploymentStatus (enum) + Department (enum) + Person (class)
    Employment.ps1          # contains Address (class) + Employee (class)
    HRFunctions.ps1         # contains New-Employee + Get-EmployeesByDepartment
```

**Template placeholders:** `{{EnumDefinitions}}`, `{{ClassDefinitions}}`, `{{FunctionDefinitions}}`  
**Config:** `psscriptbuilder.config.json`  
**Release Management:** no  
**Reset:** no

---

#### 05 - `all-collectors`

**New concept**: UsingCollector + FileCollector with custom CollectionKeys  
**Learning goal**: Inject using statements and raw file content (headers, configuration) alongside parsed components

**HR components used:**

- Using statements: `System.Collections.Generic` (in `Get-EmployeesByDepartment.ps1`), `System.Text.RegularExpressions` (in `Test-EmailAddress.ps1`), `System.Text` (in `Format-EmployeeReport.ps1`) - each `using namespace` lives in the file that needs it; UsingCollector scans `src\Functions\` and deduplicates
- Files: `Header.ps1` (module comment block), `Configuration.ps1` (script variables)
- Enums: `EmploymentStatus`, `Department`
- Classes: `Person`, `Address`, `Employee : Person`
- Functions: `New-Employee`, `Get-EmployeesByDepartment`, `Test-EmailAddress`, `Format-EmployeeReport`

**Template structure:**

```
{{UsingStatements}}

{{Header}}

# --- Configuration ---
{{Configuration}}

# --- Enums ---
{{EnumDefinitions}}

# --- Classes ---
{{ClassDefinitions}}

# --- Functions ---
{{FunctionDefinitions}}
```

**Template placeholders:** `{{UsingStatements}}`, `{{Header}}`, `{{Configuration}}`, `{{EnumDefinitions}}`, `{{ClassDefinitions}}`, `{{FunctionDefinitions}}`  
**Config:** `psscriptbuilder.config.json`  
**Release Management:** no  
**Reset:** no

---

#### 06 - `hybrid-mode`

**New concept**: Hybrid Mode - `{{ORDERED_COMPONENTS}}` used without cross-dependencies  
**Learning goal**: Use `{{ORDERED_COMPONENTS}}` when you want full control over component order, even without cross-dependencies

**HR components used:**

- Enums: `EmploymentStatus`, `Department`
- Classes: `Person`, `Address`, `Employee : Person`
- Functions: `New-Employee`, `Get-EmployeesByDepartment`

**Why Hybrid Mode:** No cross-dependencies exist in this example, but `{{ORDERED_COMPONENTS}}` is explicitly used in the template -> PSScriptBuilder switches to Hybrid Mode and emits all components in topological order.

**Template placeholders:** `{{ORDERED_COMPONENTS}}`  
**Config:** `psscriptbuilder.config.json`  
**Release Management:** no  
**Reset:** no

---

#### 07 - `ordered-mode`

**New concept**: Ordered Mode - cross-dependencies force `{{ORDERED_COMPONENTS}}`  
**Learning goal**: Understand when and why cross-dependencies arise and how PSScriptBuilder handles them automatically

**HR components used:**

- Classes: `Person`, `Employee : Person`, `Contractor : Person`
- Functions: `New-Person`, `New-Employee`, `New-Contractor`

**Why cross-dependencies arise:**

```
Person          (no deps)
Employee -> Person
Contractor -> Person
New-Person -> Person
New-Employee -> New-Person, Employee     <- Function must appear between Classes
New-Contractor -> New-Person, Contractor <- Function must appear between Classes
```

Topological sort places `New-Person` (a Function) between Classes - PSScriptBuilder detects this automatically and requires `{{ORDERED_COMPONENTS}}`.

**Demonstrates:** `Get-PSScriptBuilderDependencyAnalysis` for pre-build diagnosis  
**Template placeholders:** `{{ORDERED_COMPONENTS}}`  
**Config:** `psscriptbuilder.config.json`  
**Release Management:** no  
**Reset:** no

---

#### 08 - `cycle-detection`

**New concept**: Circular dependency detection - expected build failure  
**Learning goal**: PSScriptBuilder detects cycles early and reports them clearly - build fails with a descriptive error

**HR components used (deliberately broken):**

- Classes: `ServiceA -> ServiceB -> ServiceC -> ServiceA` (circular)

**Demonstrates:**

- `Get-PSScriptBuilderDependencyAnalysis` - shows `HasCycles: true` and cycle path
- `Invoke-PSScriptBuilderBuild` - fails with descriptive error
- How to diagnose and fix circular dependencies

**Template placeholders:** `{{ClassDefinitions}}`  
**Config:** `psscriptbuilder.config.json`  
**Release Management:** no  
**Reset:** no

---

#### 09 - `full-workflow`

**New concept**: Complete build + release management pipeline  
**Learning goal**: See how PSScriptBuilder manages a full module lifecycle - version management, file bumping, and build in one workflow

**HR components used:** full set (Using, File, Enum, Class, Function)

**Workflow steps:**

1. `Update-PSScriptBuilderReleaseData -Patch` - increment version and build metadata
2. `Update-PSScriptBuilderBumpFiles` - apply version to template and module manifest
3. `Invoke-PSScriptBuilderBuild` - build the consolidated module
4. Execute generated script - demo output

**Demonstrates:**

- All bump modes: Simple, Regex, Mixed
- `Format-PSScriptBuilderReleaseDataResult`, `Format-PSScriptBuilderBumpResult`, `Format-PSScriptBuilderBuildResult`

**Template placeholders:** `{{UsingStatements}}`, `{{Header}}`, `{{ORDERED_COMPONENTS}}`  
**Config:** `psscriptbuilder.config.json`  
**Release Management:** yes - full pipeline  
**Reset:** yes (`Reset-Example.ps1`)

> **Integration Test anchor**: Example 09 is used as the integration test fixture.

---

### Showcase

---

#### 10 - `showcase`

**Type:** Showcase - not a learning example  
**Audience:** Experienced users who want to see PSScriptBuilder at full scale  
**Note:** This example assumes familiarity with all previous examples.

**Domain:** TBD (different from HR - e.g., ITSM or Library system)

**Goals:**

- Deep inheritance hierarchy (4+ levels)
- Large number of classes (20+) and enums (10+)
- All collector types
- Cross-dependencies (Ordered Mode)
- Full release management pipeline with all bump modes
- Multiple bump targets

**Reset:** yes (`Reset-Example.ps1`)

---

## README Structure Convention

Every `README.md` follows this structure - in this exact order:

```markdown
# Example XX - Name

One paragraph (max 3 sentences): what this example demonstrates and why.

## New in this example
- Bullet list of PSScriptBuilder concepts introduced for the first time

## Key concepts
Brief explanation of each new concept (1-3 sentences each).

## Project structure
Directory tree with short description of each file.

## How to run

!!! warning "Run in a fresh PowerShell session"
    The `using module` statement loads types into the current session.
    Reloading or switching between examples in the same session can cause type conflicts.

\`\`\`powershell
.\Run-Example.ps1
\`\`\`

For detailed build output:
\`\`\`powershell
.\Run-Example.ps1 -Verbose
\`\`\`

## How it works
Step-by-step explanation of what Run-Example.ps1 does internally.

## Expected output
Console output shown verbatim - what the user should see.
```

**Rules:**

- Do not repeat concepts already explained in previous examples
- Keep explanations short - the code speaks for itself
- `## Expected output` always shows the actual console output verbatim

---

## Console Output Convention

**Principle**: No noise. Minimal, focused output.

**Rules:**

- No `Write-Host "Starting..."` or progress messages during execution
- One summary block after the build completes
- Demo output from the generated script is clearly separated

**Standard build summary:**

```
Build complete
  Output    :  build\Output\HRModule.ps1
  Components:  Using: 0  Enums: 2  Classes: 3  Functions: 3
  Time      :  0.42s
```

**Demo output separator:**

```
--- Running generated script ---
Anna Schmidt
6 years
$55,000.00
```

---

## Reset Convention

Only examples that **modify files on disk** need a `Reset-Example.ps1`:

| Example | Modified files | Reset needed |
|---------|---------------|--------------|
| 01–08 | None (only write to `build/Output/`) | No |
| 09 | `build/Release/psscriptbuilder.releasedata.json`, bump target files | Yes |
| 10 | Same as 09 + additional bump targets | Yes |

`Reset-Example.ps1` restores all modified files to their original state using `git checkout` or by overwriting with hardcoded original content.

---

## MkDocs Integration

Each example README is the **single source of truth** - it is used both in the repository and on the documentation website.

**Integration via `pymdownx.snippets`:**

Each example gets a thin wrapper file in `docs/examples/`:

```
docs/examples/
    index.md
    01-functions-only.md        # contains only: --8<-- "examples/01-functions-only/README.md"
    02-classes-and-enums.md
    ...
```

**`mkdocs.yml` nav entry:**

```yaml
- Examples:
  - Overview: examples/index.md
  - 01 Functions Only: examples/01-functions-only.md
  - 02 Classes and Enums: examples/02-classes-and-enums.md
  ...
```

**`mkdocs.yml` snippets base path** (required):

```yaml
markdown_extensions:
  - pymdownx.snippets:
      base_path: ['.']
```

This ensures the snippet path `examples/XX/README.md` resolves correctly from the project root.
