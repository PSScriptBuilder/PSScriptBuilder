# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-05-05

### Added

- `New-PSScriptBuilderProject`  
  Scaffolds a complete PSScriptBuilder project structure including configuration file, template,
  build script, and source directories; sample source files demonstrating dependency resolution
  are created by default and can be suppressed with `-NoSampleFiles`; optional
  `-IncludeReleaseManagement` switch adds release data file, bump configuration, and a release
  script with `-Major`, `-Minor`, and `-Patch` switches.

- `Compress-PSScriptBuilderScript`  
  Post-processes a built PowerShell script by removing comments, blank lines, and/or output
  statements; `-RemoveOutputStatements` accepts any combination of `Write-Verbose`,
  `Write-Debug`, `Write-Host`, `Write-Warning`, and `Write-Information`; accepts pipeline
  input from `Invoke-PSScriptBuilderBuild` via the `OutputPath` property; optional `-Force`
  switch overwrites an existing output file.

- `Export-PSScriptBuilderDependencyGraph`  
  Exports the dependency graph as a Mermaid or Graphviz DOT diagram; Mermaid output is
  automatically wrapped in a fenced code block when writing to `.md` / `.markdown` files;
  optional `-Force` switch overwrites an existing output file.

- `Get-PSScriptBuilderComponentDependency`  
  Traverses the dependency graph from a named component and returns all reachable components
  as `PSScriptBuilderComponentDependencyEntry` objects, including depth and full dependency path;
  supports both `Dependencies` and `Dependents` direction; optional `-EdgeType` parameter
  restricts traversal to one or more specific relationship types (union).

- `ConvertTo-PSScriptBuilderComponentDependencyTree`  
  Converts `PSScriptBuilderComponentDependencyEntry` objects to a hierarchical tree string using
  Unicode box-drawing characters; accepts pipeline input from `Get-PSScriptBuilderComponentDependency`.

- `-FileExtension` parameter for `New-PSScriptBuilderCollector`  
  Filters scanned files by extension when using `-IncludePath` (default: `.ps1`).

- `-FileExtension` parameter for `Add-PSScriptBuilderCollector`  
  Filters scanned files by extension when using `-IncludePath` (default: `.ps1`).

- Examples 13 and 14  
  New standalone runnable examples: **13 - Dependency Analysis** (inspecting the dependency
  graph, cross-dependency detection, and cycle reporting) and **14 - Scaffolding** (cold-start
  workflow with `New-PSScriptBuilderProject` including release management).

### Changed

- `Format-PSScriptBuilderReleaseDataResult`  
  Null or empty values in `Old Value` and `New Value` are now displayed as `<none>` instead of
  a blank line; this makes it clear whether a property was unset before or after an operation
  (e.g., first update from new release data, or `-ClearPrerelease`).

- A Class and a Function with the same name within the same project are now explicitly forbidden — the build now fails with a clear error message; this was previously a silent error that could cause incorrect dependency ordering in the build output

### Fixed

- `Update-PSScriptBuilderReleaseData` — `Format-PSScriptBuilderReleaseDataResult` no longer reports
  properties as changed (showing `<none>` → `<none>`) when those fields are stored as empty strings
  in the release data JSON and the operation leaves them as `$null`; null and empty string are now
  treated as equivalent in change tracking.

- `Update-PSScriptBuilderReleaseData -Version` combined with `-Prerelease` / `-BuildMetadata`  
  Explicit `-Prerelease` and `-BuildMetadata` parameters now correctly override any prerelease
  or build metadata contained in the `-Version` string; previously `-Version` was applied last
  and silently overwrote the values set by the explicit parameters.

- `Update-PSScriptBuilderReleaseData -BuildMetadata` / `-ClearBuildMetadata`  
  Changes to `buildmetadata` are now correctly tracked and displayed by
  `Format-PSScriptBuilderReleaseDataResult`; previously the property name was misspelled
  (`build` instead of `buildmetadata`) in the change-tracking logic, causing it to always
  report no change.

- `Update-PSScriptBuilderReleaseData -Version`  
  Optional version components (`prerelease`, `buildmetadata`) are now correctly preserved as
  `$null` when absent from the version string; previously they were set to an empty string,
  causing `Format-PSScriptBuilderReleaseDataResult` to report them as changed.

- `Update-PSScriptBuilderBumpFiles`  
  Items-mode token validation now always runs regardless of whether the pattern matches the
  file content; previously, an empty token value combined with a non-matching pattern caused
  a silent skip instead of a clear error.

## [1.0.0] - 2026-04-14

First public release.

### Added

**Collector System**

- Five collector types: `Using`, `Enum`, `Class`, `Function`, `File`
- `New-PSScriptBuilderCollector` for standalone collector creation
- `New-PSScriptBuilderContentCollector` as the container for all collectors
- `Add-PSScriptBuilderCollector` for fluent pipeline-based collector registration
- `Remove-PSScriptBuilderCollector` to remove a registered collector by key
- `Get-PSScriptBuilderCollector` to inspect registered collectors
- `Get-PSScriptBuilderCollectorContent` to inspect collected data per collector
- Custom `CollectionKey` support for multiple collectors of the same type
- File filtering via `-IncludePath`, `-IncludeFile`, `-ExcludePath`, `-ExcludeFile`, `-NoRecurse`
- AST-based extraction — mixed-type source files (class and function in the same file) handled correctly

**Dependency Analysis**

- `Get-PSScriptBuilderDependencyAnalysis` for a full analysis without producing output
- Topological sorting using Kahn's algorithm to guarantee correct load order
- Circular dependency detection with full cycle path
- Cross-dependency detection (Function→Class transitions requiring interleaved output)
- Dependency graph with forward (`GetDependencies`) and reverse (`GetDependents`) queries
- Automatic Free Mode, Hybrid Mode, and Ordered Mode detection

**Template System**

- `{{Token}}` placeholder syntax mapped to collector `CollectionKey` values
- `Test-PSScriptBuilderTemplate` for pre-build template validation
- `Get-PSScriptBuilderTemplateAnalysis` for a detailed template analysis result object
- Free Mode, Hybrid Mode, and Ordered Mode with full validation rule enforcement
- `{{ORDERED_COMPONENTS}}` placeholder for dependency-ordered output across all component types (name configurable via `-OrderedComponentsKey` and `psscriptbuilder.config.json`, default: `ORDERED_COMPONENTS`)

**Build**

- `Invoke-PSScriptBuilderBuild` orchestrating the full build pipeline
- Optional output file backup via `-EnableBackup` and `-BackupPath`
- `Format-PSScriptBuilderBuildResult` for a formatted build summary

**Release Management**

- `New-PSScriptBuilderReleaseData` to create a release data file with default values
- `Update-PSScriptBuilderReleaseData` for SemVer bumping (`-Major`, `-Minor`, `-Patch`) and explicit version via `-Version`
- Prerelease identifier and build metadata support (`-Prerelease`, `-BuildMetadata`, `-ClearPrerelease`, `-ClearBuildMetadata`)
- `-UpdateBuildDetails` to re-stamp build timestamp and increment build number
- `-UpdateGitDetails` to capture current Git branch, commit hash, and tag
- `-WhatIf` support and automatic rollback on write errors
- `Get-PSScriptBuilderReleaseData` with hierarchical and flat (`-Flat`) output modes
- `Get-PSScriptBuilderReleaseDataTokens` to list all current token values
- `Format-PSScriptBuilderReleaseDataResult` for a formatted change summary
- `Update-PSScriptBuilderBumpFiles` to propagate release metadata to all configured project files
- Simple token mode, Regex pattern mode, and Mixed mode in bump file configuration
- Automatic backup and rollback on error in `Update-PSScriptBuilderBumpFiles`
- `Get-PSScriptBuilderBumpConfiguration` to read the bump configuration
- `Test-PSScriptBuilderReleaseData` and `Test-PSScriptBuilderBumpConfiguration` for pre-release validation
- `Format-PSScriptBuilderBumpResult` for a formatted bump change report

**Configuration**

- `psscriptbuilder.config.json` support for template paths, output paths, and release file locations
- `New-PSScriptBuilderConfiguration` to generate a default `psscriptbuilder.config.json` in the project root
- `Get-PSScriptBuilderConfiguration` to load project configuration
- `Set-PSScriptBuilderProjectRoot` to configure the project root

**Examples & Documentation**

- 12 standalone runnable examples covering the complete feature set
- Guides: Configuration, Collectors, Templates, Dependency Analysis, Release Management, Code Analysis
- Full cmdlet reference documentation

**Platform**

- Full compatibility with PowerShell 5.1 and PowerShell 7+
- Verbose logging throughout the full build and release pipeline

## [0.1.0] - 2026-01-21

Initial development milestone. Not publicly released.

[1.1.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.1.0
[1.0.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.0.0
