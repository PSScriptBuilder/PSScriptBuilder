# Planning: Optional Configuration Fields

## Background

All fields in `PSScriptBuilderConfigValidator` are currently marked `required = $true`. This
is inconsistent with `PSScriptBuilderBuildOptions`, which already defines property-level
defaults for several fields. The result: users must always specify fields they never need to
customize, and new optional features (e.g. `writeSourceMap`) cannot be added without
breaking existing config files.

## Goal

Align the validator schema with the actual necessity of each field: only fields without a
meaningful default remain required. Optional fields use the property initializer in
`PSScriptBuilderBuildOptions` as the authoritative default, and `SetOptions` only overrides
when the value is present in the config.

## No Breaking Change

Existing `psscriptbuilder.config.json` files that include all fields continue to work
unchanged. New or trimmed configs may omit optional fields.

## Field Classification

### `build` section

| Field | Required? | Default | Reason |
|---|---|---|---|
| `outputPath` | ✅ Yes | — | No sensible default; build cannot run without it |
| `templatePath` | ✅ Yes | — | No sensible default; build cannot run without it |
| `backupPath` | ❌ No | `""` | Only needed when `backupEnabled = true`; orchestrator falls back to output directory |
| `orderedComponentsKey` | ❌ No | `"ORDERED_COMPONENTS"` | Has property initializer default |
| `backupEnabled` | ❌ No | `$false` | Has property initializer default |
| `syntaxValidationEnabled` | ❌ No | `$true` | Has property initializer default |

### `release` section

No changes — all release fields remain required.

## Files

| # | File | Change |
|---|---|---|
| 1 | `PSScriptBuilderConfigValidator.ps1` | Schema: mark optional fields `required = $false` |
| 2 | `PSScriptBuilderBuildOptions.ps1` | `SetOptions`: conditional assignment for optional fields |

## 1. PSScriptBuilderConfigValidator — Change

In `InitializeSchema()`, the `build` section changes from:

```powershell
build = [PSCustomObject] @{
    outputPath              = @{ required = $true; type = "string"  }
    backupPath              = @{ required = $true; type = "string"  }
    templatePath            = @{ required = $true; type = "string"  }
    orderedComponentsKey    = @{ required = $true; type = "string"  }
    backupEnabled           = @{ required = $true; type = "boolean" }
    syntaxValidationEnabled = @{ required = $true; type = "boolean" }
}
```

to:

```powershell
build = [PSCustomObject] @{
    outputPath              = @{ required = $true;  type = "string"  }
    templatePath            = @{ required = $true;  type = "string"  }
    backupPath              = @{ required = $false; type = "string"  }
    orderedComponentsKey    = @{ required = $false; type = "string"  }
    backupEnabled           = @{ required = $false; type = "boolean" }
    syntaxValidationEnabled = @{ required = $false; type = "boolean" }
}
```

The `ValidateRecursive` method already skips the presence check when `required = $false`
(condition: `$schemaItem["required"] -eq $true`). However, the type check also lives inside
that same `if`-block — meaning optional fields that **are** present with the wrong type
would silently pass validation. `ValidateRecursive` therefore needs a second change: a new
`elseif` branch that runs the type check for optional fields when they are present.

## 2. PSScriptBuilderBuildOptions — Change

`SetOptions` currently assigns every field unconditionally, casting `$null` to the target
type. This breaks optional fields whose default is not the zero value of the type:

- `SyntaxValidationEnabled` defaults to `$true`, but `[bool] $null = $false` → **wrong**
- `OrderedComponentsKey` defaults to `"ORDERED_COMPONENTS"`, but `[string] $null = ""`  → **wrong**

### Rule

- **Required fields** (`outputPath`, `templatePath`): unconditional assignment (unchanged)
- **Optional bool fields with default `$false`** (`backupEnabled`): unconditional assignment is
  safe — `[bool] $null = $false` matches the default
- **Optional string fields with default `""`** (`backupPath`): unconditional assignment is safe
  — `[string] $null = ""` matches the fallback behavior
- **Optional fields where `$null` cast produces the wrong default**: conditional assignment —
  only override if the config value is present

### New `ValidateRecursive` — additional `elseif` branch

Appended after the existing `elseif ($schemaItem -is [PSCustomObject])` branch:

```powershell
# Type-check optional fields when they ARE present in the config
elseif ($schemaItem -is [Hashtable] -and $schemaItem["required"] -eq $false) {
    $configValue = $this.GetPropertyValue($obj, $schemaProperty.Name)

    if ($null -ne $configValue) {
        $expectedType = $schemaItem["type"]

        if (-not [string]::IsNullOrWhiteSpace($expectedType)) {
            $fullPath = $this.BuildPath($path, $schemaProperty.Name)

            $isTypeMismatch = switch ($expectedType) {
                "boolean" { $configValue -isnot [bool]   }
                "string"  { $configValue -isnot [string] }
                default   { $false }
            }

            if ($isTypeMismatch) {
                $format  = "Configuration option '{0}' must be of type '{1}'."
                $message = $format -f $fullPath, $expectedType
                throw [InvalidOperationException]::new($message)
            }
        }
    }
}
```

### New `SetOptions`

```powershell
[void] SetOptions([PSCustomObject] $config) {
    # Required fields — always assigned
    $this.OutputPath  = [string] $this.GetPropertyValue($config, "outputPath")
    $this.TemplatePath = [string] $this.GetPropertyValue($config, "templatePath")

    # Optional — null cast produces correct default (false / empty string)
    $this.BackupEnabled = [bool]   $this.GetPropertyValue($config, "backupEnabled")
    $this.BackupPath    = [string] $this.GetPropertyValue($config, "backupPath")

    # Optional — null cast produces wrong default; only override when present
    $orderedKey = $this.GetPropertyValue($config, "orderedComponentsKey")
    if (-not [string]::IsNullOrWhiteSpace($orderedKey)) {
        $this.OrderedComponentsKey = [string] $orderedKey
    }

    $syntaxValue = $this.GetPropertyValue($config, "syntaxValidationEnabled")
    if ($null -ne $syntaxValue) {
        $this.SyntaxValidationEnabled = [bool] $syntaxValue
    }
}
```

## Future: `writeSourceMap`

Once this refactoring is in place, adding `writeSourceMap` to the config is straightforward
and not a breaking change:

```powershell
# Validator schema (optional, default $false):
writeSourceMap = @{ required = $false; type = "boolean" }

# PSScriptBuilderBuildOptions property:
[bool] $WriteSourceMap = $false

# SetOptions (null cast produces correct default):
$this.WriteSourceMap = [bool] $this.GetPropertyValue($config, "writeSourceMap")
```

## Edge Cases

| Case | Behavior |
|---|---|
| Config omits `backupPath`, `backupEnabled = false` | `BackupPath = ""`, validation skipped — no error |
| Config omits `backupPath`, `backupEnabled = true` | `ValidateOptions` throws: backup enabled but no path |
| Config omits `syntaxValidationEnabled` | Property initializer default `$true` preserved |
| Config omits `orderedComponentsKey` | Property initializer default `"ORDERED_COMPONENTS"` preserved |
| Config sets `orderedComponentsKey = ""` | Treated as absent — default preserved (whitespace check) |
| Unknown field in config | `ValidateRecursive` still throws "Unknown configuration option" |
