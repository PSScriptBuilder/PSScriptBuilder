# Installation

PSScriptBuilder is available on [PowerShell Gallery](https://www.powershellgallery.com/packages/PSScriptBuilder)
and supports PowerShell 5.1 and later on Windows, Linux, and macOS. It has no external
dependencies beyond the PowerShell runtime.

## Requirements

| Requirement | Version |
|---|---|
| PowerShell | 5.1 or later (Windows PowerShell and PowerShell 7+) |
| Operating System | Windows, Linux, macOS |

---

## Walkthrough

### 1. Install the Module

```powershell
Install-Module -Name PSScriptBuilder -Scope CurrentUser
```

To install for all users on the machine (requires elevated permissions):

```powershell
Install-Module -Name PSScriptBuilder -Scope AllUsers
```

### 2. Verify the Installation

```powershell
Get-Module -Name PSScriptBuilder -ListAvailable
```

### 3. Import the Module

!!! warning "Always use `using module`, not `Import-Module`"
    PSScriptBuilder exposes PowerShell classes and enums. PowerShell only makes class and enum
    definitions available when a module is loaded with `using module`. With `Import-Module`, cmdlets
    work but classes and enums are **not** accessible.

```powershell title="Correct — classes and enums are available"
using module PSScriptBuilder
```

```powershell title="Wrong — classes and enums will NOT be available"
Import-Module PSScriptBuilder
```

The `using module` statement must appear at the **very top** of your script, before any other code.

### 4. Add the Configuration File

Run the following cmdlet to generate `psscriptbuilder.config.json` in your project root:

```powershell
New-PSScriptBuilderConfiguration
```

This creates the file with all required fields pre-filled. If you prefer to create it manually,
use the following structure:

```json
{
    "build": {
        "outputPath":              ".\\build\\Output",
        "backupPath":              ".\\build\\Output\\Backup",
        "templatePath":            ".\\build\\Templates",
        "orderedComponentsKey":    "ORDERED_COMPONENTS",
        "backupEnabled":           false,
        "syntaxValidationEnabled": true
    },
    "release": {
        "dataFile":       ".\\build\\Release\\psscriptbuilder.releasedata.json",
        "bumpConfigFile": ".\\build\\Release\\psscriptbuilder.bumpconfig.json"
    }
}
```

!!! warning "All fields are required"
    Every field in the configuration file must be present. The validator enforces all fields
    as required — omitting any field causes an error when the configuration is loaded.

For a full reference of all configuration options, path resolution, and project root discovery,
see the [Configuration guide](../guides/configuration.md).

PSScriptBuilder automatically discovers this file by searching the current directory and its parents.

## Tips

!!! tip "Set the project root explicitly"
    If PSScriptBuilder cannot automatically discover the configuration file, set the project root
    at runtime:

    ```powershell
    Set-PSScriptBuilderProjectRoot -Path "C:\Projects\MyModule"
    ```

!!! tip "Keeping PSScriptBuilder up to date"
    ```powershell
    Update-Module -Name PSScriptBuilder
    ```

!!! tip "Building from source"
    ```powershell
    git clone https://github.com/PSScriptBuilder/PSScriptBuilder.git
    cd PSScriptBuilder
    .\build.ps1 -ProjectRoot .
    ```

## See Also

- [Quick Start](quick-start.md) — build your first script in minutes
- [Cmdlet Reference](../cmdlets/index.md) — all public cmdlets


