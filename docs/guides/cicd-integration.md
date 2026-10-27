# CI/CD Integration

PSScriptBuilder is a PowerShell module, so integrating it into a CI/CD pipeline follows the
same pattern as any other PowerShell-based build tool — no special CI-specific version or
plugin is needed, just a PowerShell-capable runner.

A CI environment differs from a developer's own machine in a few important ways: it starts
from a fresh, ephemeral runner with nothing pre-installed, runs entirely non-interactively —
so anything requiring a manual prompt or confirmation will hang or fail — and communicates
success or failure back to the pipeline exclusively through the process exit code, since
there's no person watching the console output.

This guide explains what PSScriptBuilder specifically needs to run under these conditions,
and illustrates it with a GitHub Actions example. The same principles apply to GitLab CI,
Azure DevOps, Jenkins, or any other system that can run PowerShell — only the surrounding
configuration syntax changes.

---

## What PSScriptBuilder Needs in CI

Integrating PSScriptBuilder into CI splits cleanly into two concerns: your CI configuration
and your build script. Keeping these separate — rather than inlining every PowerShell command
directly into the CI configuration file — is what makes the setup portable across CI systems
and testable on a developer's own machine before ever touching CI at all.

### In Your CI Configuration

1. **Install the module** — PSScriptBuilder must be available in the PowerShell module path.
   A fresh CI runner has nothing pre-installed, so this step runs on every single job.
2. **Run the build script** — invoke your `Build-MyScript.ps1` (or equivalent). The CI
   configuration's only remaining job is to call this one script; everything else happens
   inside it.

### Inside the Build Script

1. **Set the project root** — call
   [`Set-PSScriptBuilderProjectRoot`](../cmdlets/Set-PSScriptBuilderProjectRoot.md) at the
   start of your build script; PSScriptBuilder resolves all relative paths from this root.
   Calling it inside the build script, rather than passing paths explicitly from the CI
   configuration, keeps CI configuration minimal and the build locally reproducible.
2. **Run the build** — collect your project's content and call
   [`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md) to produce the
   output file.
3. **Handle the result** — the build throws a typed exception on failure, so a non-zero exit
   code alone is sufficient for most CI systems to detect a failed job. For more granular
   control, wrap the call in `try`/`catch` — see
   [Handling the Build Result](#handling-the-build-result).

!!! tip "Avoid platform-specific escaping issues"
    Complex PowerShell logic inlined directly into YAML (or another CI config format) is
    prone to quoting and escaping bugs that only surface once the pipeline actually runs.
    Keeping build logic in its own `.ps1` file avoids this entirely.

---

## Example: GitHub Actions

The following workflow illustrates the two CI configuration steps from
[In Your CI Configuration](#in-your-ci-configuration) using GitHub Actions. The workflow runs
on every push and pull request, installs PSScriptBuilder from the PowerShell Gallery, and
delegates the actual build logic to `Build-MyScript.ps1`. Keeping the build logic in a
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
        run: .\Build-MyScript.ps1
```

---

## Handling the Build Result

A build that fails in CI should fail loudly and stop the pipeline immediately —
`Invoke-PSScriptBuilderBuild` does exactly that, throwing a typed exception on any failure
(circular dependencies, missing files, name conflicts, syntax errors), which results in a
non-zero PowerShell exit code. Most CI systems treat this as a job failure automatically, so
no additional error handling is strictly required.

That said, wrapping the build in a `try/catch` block has two advantages in a CI context:
the error message is written explicitly to the error stream (making it easier to spot in
CI logs), and you have a single place to add cleanup logic or notifications if needed. This is
what `Build-MyScript.ps1` — the script called from
[Example: GitHub Actions](#example-github-actions) — typically contains, covering all three
steps from [Inside the Build Script](#inside-the-build-script):

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

try {
    $result = New-PSScriptBuilderContentCollector |
        Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
        Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
        Invoke-PSScriptBuilderBuild `
            -TemplatePath 'build\Templates\MyScript.ps1.template' `
            -OutputPath   'build\Output\MyScript.ps1'

    $result | Format-PSScriptBuilderBuildResult
}
catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
```

Piping to
[`Format-PSScriptBuilderBuildResult`](../cmdlets/Format-PSScriptBuilderBuildResult.md) doesn't
need a live audience — its output becomes part of the CI job's own log, which is exactly where
a developer looks first when investigating a failed or unexpectedly slow build afterward.

---

## Exporting the Build Report

Most CI systems can archive files as build artifacts — exporting the build summary this way
keeps it available for later inspection without digging through CI logs. Extending the same
script from [Handling the Build Result](#handling-the-build-result), pipe the result to
[`Export-PSScriptBuilderBuildResult`](../cmdlets/Export-PSScriptBuilderBuildResult.md) right
after formatting it:

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

try {
    $result = New-PSScriptBuilderContentCollector |
        Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
        Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
        Invoke-PSScriptBuilderBuild `
            -TemplatePath 'build\Templates\MyScript.ps1.template' `
            -OutputPath   'build\Output\MyScript.ps1'

    $result | Format-PSScriptBuilderBuildResult
    $result | Export-PSScriptBuilderBuildResult -Path 'build\reports\build.json' -Detailed -Force
}
catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
```

See [Build Pipeline: Exporting the Build Report](build-pipeline.md#exporting-the-build-report)
for the full JSON structure and the effect of `-Detailed`.

---

## Compressing Before Deploy

A CI pipeline is a natural place to strip comments, blank lines, and diagnostic output before
publishing — the deployed script never needs them. Extending the same script from
[Exporting the Build Report](#exporting-the-build-report), pass the build's output to
[`Compress-PSScriptBuilderScript`](../cmdlets/Compress-PSScriptBuilderScript.md) right after
exporting the report:

```powershell
Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

try {
    $result = New-PSScriptBuilderContentCollector |
        Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
        Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
        Invoke-PSScriptBuilderBuild `
            -TemplatePath 'build\Templates\MyScript.ps1.template' `
            -OutputPath   'build\Output\MyScript.ps1'

    $result | Format-PSScriptBuilderBuildResult
    $result | Export-PSScriptBuilderBuildResult -Path 'build\reports\build.json' -Detailed -Force

    Compress-PSScriptBuilderScript `
        -Path            $result.OutputPath `
        -RemoveComments `
        -RemoveBlankLines `
        -DestinationPath 'deploy\MyScript.ps1' `
        -Force
}
catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
```

See [Build Pipeline: Post-Processing](build-pipeline.md#post-processing) for what each
operation removes, how they combine, and how to get the result as a string instead of writing
a file.

---

## See Also

- [Build Pipeline](build-pipeline.md) — full build pipeline documentation
- [Cmdlet Reference: Set-PSScriptBuilderProjectRoot](../cmdlets/Set-PSScriptBuilderProjectRoot.md)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](../cmdlets/Invoke-PSScriptBuilderBuild.md)
- [Cmdlet Reference: Format-PSScriptBuilderBuildResult](../cmdlets/Format-PSScriptBuilderBuildResult.md)
- [Cmdlet Reference: Export-PSScriptBuilderBuildResult](../cmdlets/Export-PSScriptBuilderBuildResult.md)
- [Cmdlet Reference: Compress-PSScriptBuilderScript](../cmdlets/Compress-PSScriptBuilderScript.md)
