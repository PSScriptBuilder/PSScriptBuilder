# New-PSScriptBuilderProject

Scaffolds a new PSScriptBuilder project structure.

## Description

Creates a complete project directory structure for a new PSScriptBuilder project: a
configuration file, a template, a build script, and all required source directories.

If `-IncludeReleaseManagement` is specified, the cmdlet also creates release management files —
`psscriptbuilder.releasedata.json` and `psscriptbuilder.bumpconfig.json` — and a release script
with `-Major`, `-Minor`, and `-Patch` switches.

If the target directory already exists and is not empty, the cmdlet fails with an error unless
`-Force` is specified. To add release management to an existing project, run the cmdlet again
with `-IncludeReleaseManagement -Force` — this overwrites all existing project files, including
the configuration file, the build script, and the template.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Name` | string | **Required.** The name of the project to scaffold. Used to derive file and directory names. |
| `-Path` | string | The directory in which to create the project folder. Defaults to the current working directory. |
| `-IncludeReleaseManagement` | switch | Also creates release management files (see Description). |
| `-NoSampleFiles` | switch | Suppresses creation of the sample source files that by default demonstrate enum, class, and function definitions with dependency relationships. |
| `-Force` | switch | Overwrites existing files in the target directory instead of failing with an error. |

## Examples

### Scaffold a new project

```powershell
New-PSScriptBuilderProject -Name "MyProject"
```

Creates a new project named "MyProject" in the current working directory, including the
configuration file, a template, a build script, and sample source files.

### Scaffold a project with release management

```powershell
New-PSScriptBuilderProject -Name "MyModule" -Path "C:\Projects" -IncludeReleaseManagement
```

Creates a new project in `C:\Projects\MyModule` with full release management support:
`psscriptbuilder.releasedata.json`, `psscriptbuilder.bumpconfig.json`, and a release script with
`-Major`, `-Minor`, and `-Patch` switches.

### Recreate a project, overwriting existing files

```powershell
New-PSScriptBuilderProject -Name "MyProject" -Force
```

Resets an existing project's scaffolding back to its default state.

### Scaffold a project without sample source files

```powershell
New-PSScriptBuilderProject -Name "MyProject" -NoSampleFiles
```

Useful when starting from scratch, or in automated environments where the sample code would
need to be removed anyway.

## Output

Returns a
[`PSScriptBuilderScaffoldingResult`](../reference/types.md#psscriptbuilderscaffoldingresult)
object describing what was created.

## See Also

- [Quick Start Guide](../getting-started/quick-start.md)
- [Building Your First Project (Tutorial)](../tutorials/building-your-first-project.md)
- [Configuration Guide](../guides/configuration.md)
- [Release Management Guide](../guides/release-management.md)
- [Cmdlet Reference: New-PSScriptBuilderTemplate](New-PSScriptBuilderTemplate.md)
