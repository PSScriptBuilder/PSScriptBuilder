# Quick Start

This guide walks you through building your first single-file PowerShell script from a multi-file project.

## Prerequisites

- PSScriptBuilder installed — see [Installation](installation.md)
- A PowerShell project with source files to combine

## Example Project Structure

This guide uses a simple project as example:

```
MyModule/
├── psscriptbuilder.config.json
├── build/
│   ├── Templates/
│   │   └── MyModule.psm1.template
│   └── Output/           ← generated files go here
└── src/
    ├── Classes/
    │   ├── Person.ps1
    │   └── Employee.ps1
    └── Public/
        └── Get-EmployeeInfo.ps1
```

---

## Walkthrough

### 1. Add the Configuration File

Run the following cmdlet to generate `psscriptbuilder.config.json` in your project root:

```powershell
New-PSScriptBuilderConfiguration
```

PSScriptBuilder searches for this file starting from the current directory upward, so you only need to place it once at the project root. For the full field reference, see [Installation](installation.md#4-add-the-configuration-file).

### 2. Create a Template

Create `build/Templates/MyModule.psm1.template`:

```powershell title="MyModule.psm1.template"
{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

Each `{{Token}}` placeholder is replaced with the collected and dependency-ordered source code
of the corresponding collector. The default token per collector type is:

| Collector Type | Default Token |
|---|---|
| `Using` | `{{USING_STATEMENTS}}` |
| `Enum` | `{{ENUM_DEFINITIONS}}` |
| `Class` | `{{CLASS_DEFINITIONS}}` |
| `Function` | `{{FUNCTION_DEFINITIONS}}` |
| `File` | `{{FILE_CONTENTS}}` |

### 3. Run a Build Script

Create a `Build-MyModule.ps1` at the project root:

```powershell title="Build-MyModule.ps1"
using module PSScriptBuilder

$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath '.\src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath '.\src\Public'

Invoke-PSScriptBuilderBuild `
    -ContentCollector $cc `
    -TemplatePath     '.\build\Templates\MyModule.psm1.template' `
    -OutputPath       '.\build\Output\MyModule.psm1'
```

Run it from your project directory:

```powershell
.\Build-MyModule.ps1
```

### 4. Check the Output

The generated `build/Output/MyModule.psm1` contains all classes (in correct dependency order)
followed by all functions — ready to deploy as a single file.

PSScriptBuilder automatically resolves the load order: if `Employee` inherits from `Person`,
`Person` is always placed before `Employee` in the output, regardless of file order.

## Tips

!!! tip "Ordered Mode"
    When classes reference functions and functions reference classes, PSScriptBuilder detects this
    and switches to **Ordered Mode** automatically. In this mode, use the
    `ORDERED_COMPONENTS` placeholder instead of separate per-type tokens:

    ```powershell title="Ordered Mode template"
    {{ORDERED_COMPONENTS}}
    ```

    The `ORDERED_COMPONENTS` key is configured in `psscriptbuilder.config.json` under
    `build.orderedComponentsKey` (default: `"ORDERED_COMPONENTS"`).
    See the [Templates Guide](../guides/templates.md) for all available placeholder options.

!!! tip "Validate the template before building"
    Use `Test-PSScriptBuilderTemplate` to validate your template before building:

    ```powershell
    $isValid = Test-PSScriptBuilderTemplate -ContentCollector $cc -TemplatePath '.\build\Templates\MyModule.psm1.template'

    if ($isValid) {
        Invoke-PSScriptBuilderBuild -ContentCollector $cc `
            -TemplatePath '.\build\Templates\MyModule.psm1.template' `
            -OutputPath   '.\build\Output\MyModule.psm1'
    }
    ```

## See Also

- [Templates Guide](../guides/templates.md) — advanced template patterns and validation modes
- [Cmdlet Reference](../cmdlets/index.md) — full parameter documentation for all cmdlets
