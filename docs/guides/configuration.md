# Configuration

PSScriptBuilder centralizes build and release settings in a single configuration file, rather
than scattering hardcoded paths and options across your build scripts. Define a value once,
reference it everywhere it's needed, and update it in one place when it changes.

This guide covers creating and reading the configuration file, its full field reference, and how
paths and the project root are resolved. Some of these fields configure settings that
collectors, templates, and release management actually use — this guide explains the fields
themselves, not what those features do with them; see the [Collectors](collectors.md),
[Templates](templates.md), and [Release Management](release-management.md) guides for that.

The configuration file is optional for building a script — every build path can also be passed
directly as a cmdlet parameter, without a configuration file at all. Release management,
however, requires a configuration file.

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
        "templatePath":            ".\\build\\Templates",
        "backupPath":              ".\\build\\Output\\Backup",
        "orderedComponentsKey":    "ORDERED_COMPONENTS",
        "backupEnabled":           false,
        "syntaxValidationEnabled": true,
        "writeSourceMap":          false
    },
    "release": {
        "dataFile":       ".\\build\\Release\\psscriptbuilder.releasedata.json",
        "bumpConfigFile": ".\\build\\Release\\psscriptbuilder.bumpconfig.json"
    }
}
```

---

## Build Options Reference

If you use a configuration file, only `outputPath` and `templatePath` are required — they tell
PSScriptBuilder where to find the template and where to write the output. Everything else is
optional: the remaining fields either have sensible built-in defaults (for example,
`syntaxValidationEnabled` is `true` and `backupEnabled` is `false`) or are only relevant when you
enable a specific feature (such as `backupPath`, which is only needed when `backupEnabled` is
`true`).

A minimal configuration for a new project therefore only needs two fields:

```json
{
    "build": {
        "outputPath":  ".\\build\\Output",
        "templatePath": ".\\build\\Templates"
    }
}
```

You can add optional fields later as your project grows. PSScriptBuilder rejects unknown
fields with a clear error message identifying the unexpected key.

| Field | Type | Required | Description |
|---|---|---|---|
| `outputPath` | string | Yes | Directory where the built script is written. |
| `templatePath` | string | Yes | Directory containing the template file(s). |
| `backupPath` | string | No | Directory where backup files are stored when `backupEnabled` is `true`. |
| `orderedComponentsKey` | string | No | Template placeholder key for dependency-ordered components. Default: `ORDERED_COMPONENTS`. |
| `backupEnabled` | boolean | No | If `true`, a timestamped backup of the existing output file is created before each build. Default: `false`. |
| `syntaxValidationEnabled` | boolean | No | If `true`, the output file is parsed after the build and a syntax error fails the build. Default: `true`. |
| `writeSourceMap` | boolean | No | If `true`, a `.sourcemap.json` sidecar file is written alongside the output script after each successful build. Default: `false`. |

The following sections explain each field in more depth, including any special behavior and,
where relevant, its corresponding `Invoke-PSScriptBuilderBuild` parameter.

### `outputPath`

The directory where the built script is written. The actual output file path is constructed in
your build script by joining this directory with the desired filename:

```powershell
$outputPath = Join-Path $config.Build.OutputPath "MyProject.ps1"
```

If the output directory does not exist, PSScriptBuilder creates it automatically.

### `templatePath`

The directory containing the template file(s). The actual template file path is constructed in
your build script by joining this directory with the template filename:

```powershell
$templatePath = Join-Path $config.Build.TemplatePath "MyProject.ps1.template"
```

See the [Templates Guide](templates.md) for details on template syntax and placeholder tokens.

### `backupPath` *(optional)*

The directory where backup files are stored when `backupEnabled` is `true`. Backup files are
named after the output file with a timestamp appended. If the output file does not yet exist
when a build runs, no backup is created even if `backupEnabled` is `true`.

### `orderedComponentsKey` *(optional)*

The placeholder key used for dependency-ordered components in Ordered and Hybrid Mode. The
default is `ORDERED_COMPONENTS`, which maps to the `{{ORDERED_COMPONENTS}}` token in the
template. Change this only if your template already uses `ORDERED_COMPONENTS` for a different
purpose.

See the [Templates Guide](templates.md) for an explanation of Free Mode, Ordered Mode, and
Hybrid Mode.

### `backupEnabled` *(optional, default: `false`)*

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

### `syntaxValidationEnabled` *(optional, default: `true`)*

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

### `writeSourceMap` *(optional, default: `false`)*

When `true`, PSScriptBuilder writes a `.sourcemap.json` sidecar file alongside the output script
after each successful build. The source map records which line ranges in the output file originate
from which source files, enabling
[`Resolve-PSScriptBuilderSourceLocation`](../cmdlets/Resolve-PSScriptBuilderSourceLocation.md)
to translate output line numbers — including those in `ErrorRecord` stack traces — back to the
originating source file and line number.

The corresponding cmdlet parameter is `-WriteSourceMap`:

```powershell
Invoke-PSScriptBuilderBuild ... -WriteSourceMap:$config.Build.WriteSourceMap
```

See [Source Maps](source-maps.md) in the Source Maps Guide for usage examples.

---

## Release Options Reference

| Field | Type | Description |
|---|---|---|
| `dataFile` | string | Path to the release data JSON file (`psscriptbuilder.releasedata.json`). |
| `bumpConfigFile` | string | Path to the bump configuration JSON file (`psscriptbuilder.bumpconfig.json`). |

The following sections cover how each file is created, since that differs between the two.

### `dataFile`

The release data file stores the project's version, build number, and Git context between
releases. Create it with
[`New-PSScriptBuilderReleaseData`](../cmdlets/New-PSScriptBuilderReleaseData.md), which also
creates the file's directory automatically if it doesn't exist yet.

### `bumpConfigFile`

Unlike the release data file, there is no cmdlet to create the bump configuration file — write
it, and its containing directory if needed, by hand.

For a complete, end-to-end example of creating and using both files, see
[Setting Up Release Management](../tutorials/setting-up-release-management.md).

---

## Path Resolution

All paths in `psscriptbuilder.config.json` are resolved **relative to the project root**. The
project root is the directory that contains `psscriptbuilder.config.json`. PSScriptBuilder sets
it automatically when it discovers the configuration file.

For example, with a project root of `C:\Projects\MyProject`, this configuration value:

```json
"outputPath": ".\\build\\Output"
```

resolves to `C:\Projects\MyProject\build\Output`. Absolute paths are also accepted and used as-is.

---

## Path Separators

Path separators are normalized automatically. Every path example in this documentation uses
Windows-style backslashes (`\`), but PSScriptBuilder runs on Windows, Linux, and macOS —
backslashes in configuration files and cmdlet parameters (like `-IncludePath`) are converted
to the correct separator for whichever platform PSScriptBuilder is running on. Forward slashes
work identically, on any platform.

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
WriteSourceMap          : False

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
BuildTemplatePath              C:\Projects\MyProject\build\Templates
BuildOutputPath                C:\Projects\MyProject\build\Output
BuildBackupPath                C:\Projects\MyProject\build\Output\Backup
BuildOrderedComponentsKey      ORDERED_COMPONENTS
BuildBackupEnabled             False
BuildSyntaxValidationEnabled   True
BuildWriteSourceMap            False
```

The next section shows how a loaded configuration's structured object is used to drive a build.

---

## Passing Config Values to the Build

A typical build script reads the configuration once, then passes every relevant value through to
[`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md) — not just the
template and output paths, but also the backup, syntax validation, and source map settings:

```powershell title="Build-MyProject.ps1"
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
    WriteSourceMap       = $config.Build.WriteSourceMap
}

Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult
```

`$buildParams` collects every value into a single hashtable instead of writing out each
`-Parameter value` pair by hand. `Join-Path` builds the two file paths from the configured
directories; the remaining four values are passed through from `$config.Build` as-is, negating
`SyntaxValidationEnabled` into `SkipSyntaxValidation` since the config field and the cmdlet
parameter express the same setting in opposite polarity.

`Invoke-PSScriptBuilderBuild @buildParams` then runs the build. The `@` triggers
[splatting](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-5.1)
— it passes each hashtable key as a matching named parameter, equivalent to writing
`-ContentCollector $contentCollector -TemplatePath ... -OutputPath ...` directly.

---

## See Also

- [Templates Guide](templates.md) — `templatePath` and collector placeholder keys
- [Release Management Guide](release-management.md) — release options and bump configuration
- [Source Maps Guide](source-maps.md) — `writeSourceMap` usage and resolving output line numbers
- [Cmdlet Reference: New-PSScriptBuilderConfiguration](../cmdlets/New-PSScriptBuilderConfiguration.md)
- [Cmdlet Reference: Get-PSScriptBuilderConfiguration](../cmdlets/Get-PSScriptBuilderConfiguration.md)
