# CI/CD Integration

PSScriptBuilder is a PowerShell module — integrating it into a CI/CD pipeline follows the
same pattern as any other PowerShell-based build tool. This guide explains what PSScriptBuilder
needs in any automated environment and illustrates it with a GitHub Actions example. The
principles apply to GitLab CI, Azure DevOps, Jenkins, or any other system that can run
PowerShell.

---

## What PSScriptBuilder Needs in CI

Regardless of the CI/CD system, every PSScriptBuilder build requires the same four steps:

1. **Install the module** — PSScriptBuilder must be available in the PowerShell module path
2. **Set the project root** — call `Set-PSScriptBuilderProjectRoot` at the start of your build
   script; PSScriptBuilder resolves all relative paths from this root. Calling it inside the
   build script keeps CI configuration minimal and the build locally reproducible.
3. **Run the build script** — invoke your `Build-MyModule.ps1` (or equivalent); the script
   runs `Invoke-PSScriptBuilderBuild` and produces the output file
4. **Check the result** — the build throws on failure, so a non-zero exit code is sufficient
   for most CI systems; use `$result.SyntaxValid` or `try/catch` for more granular control

!!! tip "Keep the build script outside CI configuration"
    Define your full build logic in a dedicated PowerShell script (e.g. `Build-MyModule.ps1`)
    rather than inlining it in the CI configuration file. This keeps your CI steps short,
    makes the build locally reproducible, and avoids platform-specific escaping issues.

---

## Example: GitHub Actions

The following workflow illustrates the four steps above using GitHub Actions. The workflow
runs on every push and pull request, installs PSScriptBuilder from the PowerShell Gallery,
and delegates the actual build logic to `Build-MyModule.ps1`. Keeping the build logic in a
script — rather than inline YAML — means the same script works locally and in CI without
any changes.

Adapt the YAML syntax to your CI/CD system. The PowerShell commands inside the steps remain
the same regardless of the platform:

```yaml title=".github/workflows/build.yml"
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install PSScriptBuilder
        shell: pwsh
        run: Install-Module PSScriptBuilder -Force -SkipPublisherCheck

      - name: Build
        shell: pwsh
        run: .\Build-MyModule.ps1
```

---

## Handling the Build Result

`Invoke-PSScriptBuilderBuild` throws a typed exception on any build failure — circular
dependencies, missing files, name conflicts, and syntax errors all result in a non-zero
PowerShell exit code. Most CI systems treat this as a job failure automatically, so no
additional error handling is strictly required.

That said, wrapping the build in a `try/catch` block has two advantages in a CI context:
the error message is written explicitly to the error stream (making it easier to spot in
CI logs), and you have a single place to add cleanup logic or notifications if needed:

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

try {
    $result = New-PSScriptBuilderContentCollector |
        Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
        Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
        Invoke-PSScriptBuilderBuild `
            -TemplatePath 'build\Templates\MyModule.psm1.template' `
            -OutputPath   'build\Output\MyModule.psm1'

    $result | Format-PSScriptBuilderBuildResult
}
catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
```

---

## Compressing Before Deploy

A standard build output preserves all comments, blank lines, and verbose logging — useful
during development, but unnecessary in a deployed script. Before copying the output to a
deploy location or publishing it to the PowerShell Gallery, you can reduce the file size
by stripping those elements with
[`Compress-PSScriptBuilderScript`](../cmdlets/Compress-PSScriptBuilderScript.md).

Chain it directly after `Invoke-PSScriptBuilderBuild` using the pipeline and write to a
separate deploy location — the original build output in `build\Output\` stays intact:

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
    Invoke-PSScriptBuilderBuild `
        -TemplatePath 'build\Templates\MyModule.psm1.template' `
        -OutputPath   'build\Output\MyModule.psm1' |
    Compress-PSScriptBuilderScript `
        -RemoveComments `
        -RemoveBlankLines `
        -DestinationPath 'deploy\MyModule.psm1' `
        -Force
```

The pipeline passes the build result directly into `Compress-PSScriptBuilderScript`, so
there is no `$result` variable to inspect. If you also need to log component counts or
handle errors explicitly, capture the result as shown in
[Handling the Build Result](#handling-the-build-result) and call
`Compress-PSScriptBuilderScript` separately.

---

## See Also

- [Build Guide](build.md) — full build pipeline documentation
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](../cmdlets/Invoke-PSScriptBuilderBuild.md)
- [Cmdlet Reference: Compress-PSScriptBuilderScript](../cmdlets/Compress-PSScriptBuilderScript.md)
