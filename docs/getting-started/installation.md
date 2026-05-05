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

!!! note "Installation fails with a publisher verification error?"
    PSScriptBuilder is not Authenticode-signed. On some systems this causes `Install-Module`
    to fail with a publisher check error. Add `-SkipPublisherCheck` to bypass it:
    ```powershell
    Install-Module -Name PSScriptBuilder -Scope CurrentUser -SkipPublisherCheck
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

### 4. Scaffold Your First Project

The module is ready. Head to [Quick Start](quick-start.md) to scaffold a new project and run
your first build in under a minute.

## Tips

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

- [Cmdlet Reference](../cmdlets/index.md) — all public cmdlets


