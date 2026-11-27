---
title: From script to module — building a deployable PowerShell module with PSScriptBuilder
series: Building real PowerShell projects with PSScriptBuilder
tags: powershell, automation, devops, tutorial
cover_image: 
published: false
---

*In Part 1 and Part 2 we built standalone `.ps1` scripts. In this part we switch to a proper PowerShell module — a `.psm1` file that gives callers access to strongly-typed objects.*

---

## Script vs. module

A standalone `.ps1` script works well for simple automation. But once your project has classes, there's a meaningful difference:

- A **script** dot-sourced with `. .\HRUtils.ps1` loads functions into the current scope, but the types are not accessible as first-class PowerShell types in other scripts.
- A **module** loaded with `using module AppConfig.psd1` does — `[ConfigEntry]` and `[AppConfig]` become real types you can use in parameter declarations, type checks, and casts.

PSScriptBuilder handles both. Switching from script to module output is just a matter of using a `.psm1` template.

---

## The project

This example builds an application configuration module — `AppConfig`. Two classes, three factory functions:

```
09-module-build/
├── src/
│   ├── Classes/
│   │   ├── ConfigEntry.ps1     Key, Value, Description
│   │   └── AppConfig.ps1       Name, Entries; Add(), Get(), Contains(), Count()
│   └── Functions/
│       ├── New-ConfigEntry.ps1
│       ├── New-AppConfig.ps1
│       └── Get-ConfigValue.ps1
└── build/
    ├── Templates/
    │   └── AppConfig.psm1.template
    └── Output/
        └── AppConfig.psd1      ← manifest (pre-existing, not generated)
```

The module manifest (`AppConfig.psd1`) is committed to source control and stays unchanged across builds. PSScriptBuilder only generates the `.psm1` body.

---

## The source files

**`ConfigEntry.ps1`** and **`AppConfig.ps1`**:

```powershell
class ConfigEntry {
    [string] $Key
    [string] $Value
    [string] $Description
    # ...
}

class AppConfig {
    [string]        $Name
    [ConfigEntry[]] $Entries

    [void]        Add([ConfigEntry] $entry) { # ... }
    [ConfigEntry] Get([string] $key)        { # ... }
    [bool]        Contains([string] $key)   { # ... }
    [int]         Count()                   { # ... }
}
```

Three factory and utility functions:

```powershell
Function New-ConfigEntry {
    [OutputType([ConfigEntry])]
    param([string] $Key, [string] $Value, [string] $Description = '') { # ... }
}

Function New-AppConfig {
    [OutputType([AppConfig])]
    param([string] $Name) { # ... }
}

Function Get-ConfigValue {
    [OutputType([string])]
    param([AppConfig] $Config, [string] $Key, [string] $Default = '') { # ... }
}
```

`AppConfig` depends on `ConfigEntry` — PSScriptBuilder detects this and places `ConfigEntry` first in the output.

---

## The template

The template content looks no different from a script template. Whether PSScriptBuilder produces a `.ps1` or `.psm1` file depends entirely on the output path in the build script.

**`AppConfig.psm1.template`**

```powershell
{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

---

## The build

```powershell
using module PSScriptBuilder

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$templatePath  = Join-Path $PSScriptRoot "build\Templates\AppConfig.psm1.template"
$outputPath    = Join-Path $PSScriptRoot "build\Output\AppConfig.psm1"

$classesPath   = Join-Path $PSScriptRoot "src\Classes"
$functionsPath = Join-Path $PSScriptRoot "src\Functions"

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = $templatePath
    OutputPath       = $outputPath
}

$result = Invoke-PSScriptBuilderBuild @buildParams

Format-PSScriptBuilderBuildResult -BuildResult $result

& "$PSScriptRoot\Demo-Module.ps1"
```

---

## Why a separate demo script?

The `using module` statement must appear **at the top of a script file**, before any executable code. Because `Run-Example.ps1` has already run the build, it cannot issue `using module` itself.

The solution: call a child script with `&`. This starts a clean parsing scope where `using module` is valid.

**`Demo-Module.ps1`**

```powershell
using module .\build\Output\AppConfig.psd1

$config = New-AppConfig -Name "AppSettings"

$config.Add((New-ConfigEntry -Key "Environment" -Value "Production" -Description "Deployment environment"))
$config.Add((New-ConfigEntry -Key "LogLevel"    -Value "Warning"    -Description "Minimum log level"))
$config.Add((New-ConfigEntry -Key "MaxRetries"  -Value "3"          -Description "Maximum retry attempts"))
$config.Add((New-ConfigEntry -Key "Timeout"     -Value "30"))

Write-Host "Config  : $($config.Name)"
Write-Host "Entries : $($config.Count())"

foreach ($entry in $config.Entries) {
    $desc = if ($entry.Description) { "  # $($entry.Description)" } else { '' }
    Write-Host ("  {0,-12} = {1}{2}" -f $entry.Key, $entry.Value, $desc)
}

$env     = Get-ConfigValue -Config $config -Key "Environment"
$missing = Get-ConfigValue -Config $config -Key "ApiKey" -Default "(not set)"

Write-Host "Environment : $env"
Write-Host "ApiKey      : $missing"
```

Because `Demo-Module.ps1` uses `using module`, `$entry` is a real `[ConfigEntry]` object — not a `PSCustomObject`. Parameter type constraints like `[ConfigEntry] $entry` work correctly.

---

## The result

```
Build Summary
  Output : ...\build\Output\AppConfig.psm1
  Size   : 2.02 KB
  Time   : 12 ms

Components
  Classes   : 2
  Functions : 3
  Total     : 5

Config  : AppSettings
Entries : 4

  Environment  = Production  # Deployment environment
  LogLevel     = Warning     # Minimum log level
  MaxRetries   = 3           # Maximum retry attempts
  Timeout      = 30

Environment : Production
ApiKey      : (not set)
```

The `Get-ConfigValue` call with `-Default "(not set)"` shows that the module functions work with the module's own types correctly — `[AppConfig]` is recognized as a parameter type.

---

## What's next

In **Part 4**, we bring everything together: version bump, build, and release in a single automated workflow — from source files to a versioned, deployable output in one step.

➡️ *[Part 4: The full workflow — version bump, build, and release with PSScriptBuilder]*

---

*The complete example is available in the [PSScriptBuilder repository](https://github.com/PSScriptBuilder/PSScriptBuilder/tree/main/examples/09-module-build).*
