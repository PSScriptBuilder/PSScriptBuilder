# Example 14 - Scaffolding

This example demonstrates `New-PSScriptBuilderProject` — the scaffolding cmdlet that creates a
complete PSScriptBuilder project structure from scratch in a single command. It shows the full
cold-start workflow: from an empty folder to a built output file in five phases.

## New in this example

- `New-PSScriptBuilderProject` — scaffolds a complete project with source directories, configuration file, build script, template, and (optionally) release management files
- `Set-PSScriptBuilderProjectRoot` — explicitly sets the project root after scaffolding, because the current working directory (the example folder) differs from the newly created project directory

## Key concepts

**`New-PSScriptBuilderProject` creates everything needed to start:**

| What is created | Location |
|-----------------|----------|
| Source directories | `src\Enums\`, `src\Classes\`, `src\Public\` |
| Build directories | `build\Templates\`, `build\Output\` |
| Configuration file | `psscriptbuilder.config.json` |
| Build script | `Build-MyProject.ps1` |
| Template | `build\Templates\MyProject.ps1.template` |
| Sample source files | `src\Enums\WorkStatus.ps1`, `src\Classes\Employee.ps1`, `src\Public\Get-EmployeeInfo.ps1` |
| Release data file | `build\Release\psscriptbuilder.releasedata.json` |
| Bump configuration | `build\Release\psscriptbuilder.bumpconfig.json` |
| Release script | `Release-MyProject.ps1` |

**Why `Set-PSScriptBuilderProjectRoot` is needed here:**
All PSScriptBuilder cmdlets resolve file paths relative to the registered project root. When
running `Run-Example.ps1` from the example folder, the project root is initially the example
folder — not the newly scaffolded `MyProject` subdirectory. `Set-PSScriptBuilderProjectRoot`
explicitly points PSScriptBuilder to the correct location before any further operations are
performed.

**The six phases:**

| Phase | Cmdlet(s) | What happens |
|-------|-----------|--------------|
| 1 - Scaffold | `New-PSScriptBuilderProject` | Creates full project structure with sample files and release management |
| 2 - Set root | `Set-PSScriptBuilderProjectRoot` | Points PSScriptBuilder to the scaffolded project |
| 3 - Release data | `Update-PSScriptBuilderReleaseData` | Bumps patch version and refreshes build timestamp |
| 4 - Bump files | `Update-PSScriptBuilderBumpFiles` | Writes version and timestamp into the template header |
| 5 - Build | `Invoke-PSScriptBuilderBuild` | Collects sample components, resolves dependencies, produces output file |
| 6 - Run | `& $outputPath` | Executes the generated script to verify the result |

> **Note:** In a real project, `.\Release-MyProject.ps1 -Patch` replaces phases 3-5 in a single
> command. The example runs them individually to make each step visible.

## How to run

```powershell
cd examples\14-scaffolding
.\Run-Example.ps1
```

For verbose collector and bump progress:

```powershell
.\Run-Example.ps1 -Verbose
```

## Project structure after running

```
14-scaffolding/
    Run-Example.ps1         # this file
    README.md
    MyProject/              # created by New-PSScriptBuilderProject
        psscriptbuilder.config.json
        Build-MyProject.ps1
        Release-MyProject.ps1
        src/
            Enums/
                WorkStatus.ps1
            Classes/
                Employee.ps1
            Public/
                Get-EmployeeInfo.ps1
        build/
            Templates/
                MyProject.ps1.template
            Output/
                MyProject.ps1       # produced by the build
            Release/
                psscriptbuilder.releasedata.json
                psscriptbuilder.bumpconfig.json
```

The `MyProject\` directory is removed and recreated on every run of the example.
`Reset-Example.ps1` removes it without running the example — useful for restoring a clean state.
