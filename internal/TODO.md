# TODO

## Planned Features

- **Integrations documentation page** — create `docs/guides/integrations.md` covering Invoke-Build (PSScriptBuilder as assembly step in task runner pipeline), PSScriptAnalyzer (post-build linting), and Pester (testing generated output). Add entry to `mkdocs.yml` under `guides:`.

- **Move `PSScriptBuilder.psd1` to project root** — currently lives in `build/Output/` (source and artifact in same location). Move to project root, extend `Build-Module.ps1` to copy it to `build/Output/` during build. Affected files: `Build-Module.ps1` (2x), `build/Release/psscriptbuilder.bumpconfig.json`, `scripts/publish.ps1`, `RELEASING.md` (3x), `docs/guides/release-management.md`, `internal/example-planning.md`.

- **`Compress-PSScriptBuilderScript`** ✅ — implemented
  - `-Path` (Mandatory, `[Alias('OutputPath')]`) — accepts pipeline input from `Invoke-PSScriptBuilderBuild`
  - `-RemoveComments` (switch)
  - `-RemoveBlankLines` (switch)
  - `-RemoveOutputStatements [string[]]` — `ValidateSet`: `Write-Verbose`, `Write-Debug`, `Write-Host`, `Write-Warning`, `Write-Information`
  - `-Destination` (optional) — writes result to file; when omitted, returns string to pipeline
  - `-Force` (switch) — overwrites existing `-Destination` file
  - Backing class: `PSScriptBuilderScriptPostProcessor`

- **Dependency Analysis Guide — Advanced Use Cases** ✅ — documented in `docs/guides/dependency-analysis.md`

- **Automatic ReleaseNotes extraction** — extend the Release build (`Build-Module.ps1 -Release`) to automatically extract the current version's section from `CHANGELOG.md` and write it to `ReleaseNotes` in `PSScriptBuilder.psd1`. Single source of truth: CHANGELOG feeds both the `.psd1` and `release_notes.md` (GitHub Release). Natural candidate for a PSScriptBuilder feature itself (CHANGELOG token support in build pipeline).
- **Website download page** — hybrid static link (releases/latest fallback button) + dynamic GitHub API table (all releases with version, date, download link) via `https://api.github.com/repos/PSScriptBuilder/PSScriptBuilder/releases`

- **Verbose Renderer** — introduce a central `PSScriptBuilderVerboseRenderer` class with static `Write([string] $message)`, `Indent()`, and `Outdent()` methods. Migrate all ~215 `Write-Verbose` calls to `[PSScriptBuilderVerboseRenderer]::Write(...)`, remove hardcoded leading spaces from message strings, and add `Indent/Outdent` pairs (with `try/finally`) at all operation boundaries. This eliminates the current convention-only indentation and makes depth structural. See `internal/logging-strategy.md` for full rationale and scope.

## Planned Breaking Changes (2.0.0)

- **Rename plural cmdlets to singular** — two released cmdlets violate the PowerShell singular-noun convention; to be bundled with other breaking changes into a single 2.0.0 release:
  - `Get-PSScriptBuilderReleaseDataTokens` → `Get-PSScriptBuilderReleaseDataToken`
  - `Update-PSScriptBuilderBumpFiles` → `Update-PSScriptBuilderBumpFile`
- **Rename plural class to singular** — the result class for bump file operations violates the singular-type-name convention:
  - `PSScriptBuilderBumpFilesResult` → `PSScriptBuilderBumpFileResult`


## Bugs
- [ ] None reported yet
