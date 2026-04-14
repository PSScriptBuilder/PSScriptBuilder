# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.0.0
