# Configuration

PSScriptBuilder uses a single JSON file — `psscriptbuilder.config.json` — to centralize all
build and release settings. Instead of scattering hardcoded paths across your build scripts,
you define them once and reference them through a typed configuration object: your build script
uses `$config.Build.OutputPath` instead of a literal path, and when the directory changes,
you update one file instead of every script that references it.

The configuration file is optional — you can pass all paths directly to
[`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md) if you prefer.
See [`Example 02`](../examples.md#02-classes-and-enums) for a build without configuration
and [`Example 03`](../examples.md#03-with-configuration) for the same build driven by a
configuration file.

---

## Creating the Configuration File

Run [`New-PSScriptBuilderConfiguration`](../cmdlets/New-PSScriptBuilderConfiguration.md) in
your project root to generate the file with all required fields pre-filled:

```powershell
New-PSScriptBuilderConfiguration
```

To overwrite an existing file:

```powershell
New-PSScriptBuilderConfiguration -Force
```

To create the file in a specific directory:

```powershell
New-PSScriptBuilderConfiguration -Path "C:\Projects\MyProject"
```

---

## File Structure

`psscriptbuilder.config.json` has two top-level sections: `build` and `release`.

```json title="psscriptbuilder.config.json"
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
    Every field must be present. The validator rejects unknown fields and reports missing
    required fields with a clear error message — including the exact key that is missing or
    unexpected.

---

## Build Options Reference

| Field | Type | Description |
|---|---|---|
| `outputPath` | string | Directory where the built script is written. |
| `backupPath` | string | Directory where backup files are stored when `backupEnabled` is `true`. |
| `templatePath` | string | Directory containing the template file(s). |
| `orderedComponentsKey` | string | Template placeholder key for dependency-ordered components. Default is `ORDERED_COMPONENTS`. |
| `backupEnabled` | boolean | If `true`, a timestamped backup of the existing output file is created before each build. Default is `false`. |
| `syntaxValidationEnabled` | boolean | If `true`, the output file is parsed after the build and a syntax error fails the build. Default is `true`. |

### `outputPath`

The directory where the built script is written. The actual output file path is constructed in
your build script by joining this directory with the desired filename:

```powershell
$outputPath = Join-Path $config.Build.OutputPath "MyProject.ps1"
```

If the output directory does not exist, PSScriptBuilder creates it automatically.

### `backupPath`

The directory where backup files are stored when `backupEnabled` is `true`. Backup files are
named after the output file with a timestamp appended. If the output file does not yet exist
when a build runs, no backup is created even if `backupEnabled` is `true`.

### `templatePath`

The directory containing the template file(s). The actual template file path is constructed in
your build script by joining this directory with the template filename:

```powershell
$templatePath = Join-Path $config.Build.TemplatePath "MyProject.ps1.template"
```

See the [Templates guide](templates.md) for details on template syntax and placeholder tokens.

### `orderedComponentsKey`

The placeholder key used for dependency-ordered components in Ordered and Hybrid Mode. The
default is `ORDERED_COMPONENTS`, which maps to the `{{ORDERED_COMPONENTS}}` token in the
template. Change this only if your template already uses `ORDERED_COMPONENTS` for a different
purpose.

See the [Templates guide](templates.md) for an explanation of Free Mode, Ordered Mode, and
Hybrid Mode.

### `backupEnabled`

Controls whether a backup of the existing output file is created before each build. Backup
files are written to `backupPath`.

!!! tip "Git replaces file-based backups"
    Most projects do not need `backupEnabled`. When the output script is version-controlled,
    Git provides full history and instant rollback — a file backup adds no value and clutters
    the backup directory. Set `backupEnabled` to `false` unless you have a specific reason to
    keep file backups.

The corresponding [`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md)
parameter is `-EnableBackup`. When calling the cmdlet directly, use
`-EnableBackup:$config.Build.BackupEnabled` to pass the config value:

```powershell
Invoke-PSScriptBuilderBuild ... -EnableBackup:$config.Build.BackupEnabled
```

### `syntaxValidationEnabled`

Controls whether PSScriptBuilder validates the output file's syntax after writing it. When
enabled, the output script is parsed using the PowerShell parser. Any syntax error fails the
build with a clear message identifying the error.

TypeNotFound errors — which occur when the output script references types from external
assemblies not loaded during the build — are automatically ignored and do not fail the build.

The corresponding cmdlet parameter is `-SkipSyntaxValidation`. When calling the cmdlet directly
and you want to honour the config value, assign the negation to a variable first:

```powershell
$skipSyntax = -not $config.Build.SyntaxValidationEnabled
Invoke-PSScriptBuilderBuild ... -SkipSyntaxValidation:$skipSyntax
```

---

## Release Options Reference

| Field | Type | Description |
|---|---|---|
| `dataFile` | string | Path to the release data JSON file (`psscriptbuilder.releasedata.json`). |
| `bumpConfigFile` | string | Path to the bump configuration JSON file (`psscriptbuilder.bumpconfig.json`). |

These fields are only relevant when using the release management features. See the
[Release Management guide](release-management.md) for details.

---

## Path Resolution

All paths in `psscriptbuilder.config.json` are resolved **relative to the project root**. The
project root is the directory that contains `psscriptbuilder.config.json`. PSScriptBuilder sets
it automatically when it discovers the configuration file.

```json
"outputPath": ".\\build\\Output"
```

With a project root of `C:\Projects\MyProject`, this resolves to
`C:\Projects\MyProject\build\Output`. Absolute paths are also accepted and used as-is.

---

## Project Root Discovery

PSScriptBuilder discovers the project root automatically by searching upward from the current
working directory until it finds a directory containing `psscriptbuilder.config.json`. This
means you can run build scripts from any subdirectory of your project and PSScriptBuilder will
find the configuration file.

If automatic discovery fails — for example in CI environments or when running from an unrelated
directory — set the project root explicitly:

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot
```

Call this at the top of your build script, before any other PSScriptBuilder cmdlets. `$PSScriptRoot`
resolves to the directory of the currently running script, which is usually the correct value.

---

## Reading the Configuration

Use [`Get-PSScriptBuilderConfiguration`](../cmdlets/Get-PSScriptBuilderConfiguration.md) to
load the configuration into a structured object. The returned object exposes three properties:
`ConfigFileName` (the name of the config file), `Build` (build options), and `Release`
(release options):

```powershell title="Structured output"
$config = Get-PSScriptBuilderConfiguration
$config.ConfigFileName

psscriptbuilder.config.json

$config.Build | Format-List

OutputPath              : C:\Projects\MyProject\build\Output
BackupPath              : C:\Projects\MyProject\build\Output\Backup
TemplatePath            : C:\Projects\MyProject\build\Templates
OrderedComponentsKey    : ORDERED_COMPONENTS
BackupEnabled           : False
SyntaxValidationEnabled : True

$config.Release | Format-List

DataFile       : C:\Projects\MyProject\build\Release\psscriptbuilder.releasedata.json
BumpConfigFile : C:\Projects\MyProject\build\Release\psscriptbuilder.bumpconfig.json
```

For a flat single-level structure — useful for tabular display or diagnostic output — use the
`-Flat` switch:

```powershell title="Flat output"
Get-PSScriptBuilderConfiguration -Flat

Name                           Value
----                           -----
ReleaseDataFile                C:\Projects\MyProject\build\Release\psscriptbuilder.releasedata.json
ReleaseBumpConfigFile          C:\Projects\MyProject\build\Release\psscriptbuilder.bumpconfig.json
BuildTemplatePath              C:\Projects\MyModule\build\Templates
BuildOutputPath                C:\Projects\MyModule\build\Output
BuildBackupPath                C:\Projects\MyModule\build\Output\Backup
BuildOrderedComponentsKey      ORDERED_COMPONENTS
BuildBackupEnabled             False
BuildSyntaxValidationEnabled   True
```

---

## Passing Config Values to the Build

A typical build script reads the configuration, constructs the file paths from the directory
values, and passes them to
[`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md):

```powershell title="Build-Module.ps1"
using module PSScriptBuilder

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$config = Get-PSScriptBuilderConfiguration

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums"   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"

$buildParams = @{
    ContentCollector     = $contentCollector
    TemplatePath         = Join-Path $config.Build.TemplatePath "MyProject.ps1.template"
    OutputPath           = Join-Path $config.Build.OutputPath   "MyProject.ps1"
    BackupPath           = $config.Build.BackupPath
    EnableBackup         = $config.Build.BackupEnabled
    SkipSyntaxValidation = -not $config.Build.SyntaxValidationEnabled
}

Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult
```

---

## See Also

- [Templates Guide](templates.md) — `templatePath` and collector placeholder keys
- [Release Management Guide](release-management.md) — release options and bump configuration
