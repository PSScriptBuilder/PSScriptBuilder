---
hide:
  - toc
---

# Cmdlet Reference

PSScriptBuilder provides 38 public cmdlets, grouped below into five categories that follow the
natural project lifecycle: scaffolding a new project, building and assembling scripts,
analyzing and validating a project's structure, managing shared configuration, and handling
releases. Each entry links to a full reference page generated directly from that cmdlet's own
comment-based help — the same syntax, parameter list, and usage examples `Get-Help -Full`
already shows you in the console, organized here for browsing instead.

Many of these cmdlets return PowerShell objects rather than plain values. For what those
objects actually contain — their properties, types, and how several of them relate to one
another — see the [Type Reference](../reference/types.md).

## Scaffolding

Start a brand-new project from nothing: folder structure, configuration file, and a first
template, ready for the first build.

| Cmdlet | Description |
|---|---|
| [New-PSScriptBuilderProject](New-PSScriptBuilderProject.md) | Scaffolds a new PSScriptBuilder project structure |
| [New-PSScriptBuilderTemplate](New-PSScriptBuilderTemplate.md) | Generates a PSScriptBuilder template file from a content collector configuration |

## Script Building

The core pipeline: define collectors, assemble a build, watch for source changes, post-process
the output, and trace results back to their original source files.

| Cmdlet | Description |
|---|---|
| [New-PSScriptBuilderContentCollector](New-PSScriptBuilderContentCollector.md) | Creates a new content collector for managing multiple component collectors |
| [New-PSScriptBuilderCollector](New-PSScriptBuilderCollector.md) | Creates a new collector for PowerShell script components |
| [Add-PSScriptBuilderCollector](Add-PSScriptBuilderCollector.md) | Adds a collector to a ContentCollector for fluent pipeline configuration |
| [Get-PSScriptBuilderCollector](Get-PSScriptBuilderCollector.md) | Retrieves collectors from a ContentCollector |
| [Get-PSScriptBuilderCollectorContent](Get-PSScriptBuilderCollectorContent.md) | Retrieves collected data from a collector |
| [Remove-PSScriptBuilderCollector](Remove-PSScriptBuilderCollector.md) | Removes a collector from a ContentCollector |
| [Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md) | Executes the complete PowerShell script build process |
| [Watch-PSScriptBuilderProject](Watch-PSScriptBuilderProject.md) | Watches project source files and triggers a build or custom script block on every change |
| [Compress-PSScriptBuilderScript](Compress-PSScriptBuilderScript.md) | Post-processes a built PowerShell script by removing comments, blank lines, or output statements |
| [Format-PSScriptBuilderBuildResult](Format-PSScriptBuilderBuildResult.md) | Formats and displays the result of a build operation |
| [Export-PSScriptBuilderBuildResult](Export-PSScriptBuilderBuildResult.md) | Exports a build result to a JSON file |
| [Resolve-PSScriptBuilderSourceLocation](Resolve-PSScriptBuilderSourceLocation.md) | Resolves an output script line number or ErrorRecord back to its source file location |
| [Get-PSScriptBuilderSourceCoverage](Get-PSScriptBuilderSourceCoverage.md) | Translates Pester code coverage data back to the original source files |
| [Format-PSScriptBuilderSourceCoverage](Format-PSScriptBuilderSourceCoverage.md) | Formats and displays per-source-file code coverage results |

## Analysis & Validation

Inspect a project's dependency graph, template structure, and collector configuration without
necessarily running a build — useful for debugging and for CI checks that should fail fast.

| Cmdlet | Description |
|---|---|
| [Get-PSScriptBuilderDependencyAnalysis](Get-PSScriptBuilderDependencyAnalysis.md) | Analyzes dependencies between components without performing a build |
| [Format-PSScriptBuilderDependencyAnalysis](Format-PSScriptBuilderDependencyAnalysis.md) | Formats and displays the result of a dependency analysis operation |
| [Get-PSScriptBuilderComponentDependency](Get-PSScriptBuilderComponentDependency.md) | Retrieves all dependencies or dependents of a named component from the dependency graph |
| [Find-PSScriptBuilderUnusedComponent](Find-PSScriptBuilderUnusedComponent.md) | Finds unused components in a PSScriptBuilder content collector configuration |
| [Export-PSScriptBuilderDependencyGraph](Export-PSScriptBuilderDependencyGraph.md) | Exports the dependency graph to a visual diagram format |
| [ConvertTo-PSScriptBuilderComponentDependencyTree](ConvertTo-PSScriptBuilderComponentDependencyTree.md) | Converts component dependency entries to a hierarchical tree string |
| [Get-PSScriptBuilderTemplateAnalysis](Get-PSScriptBuilderTemplateAnalysis.md) | Analyzes a template file for placeholders and structure |
| [Format-PSScriptBuilderTemplateAnalysis](Format-PSScriptBuilderTemplateAnalysis.md) | Formats and displays the result of a template analysis operation |
| [Test-PSScriptBuilderTemplate](Test-PSScriptBuilderTemplate.md) | Validates a template file without performing a build |

## Configuration

Read, create, and pin the project-wide settings — paths, defaults, and the project root — that
every other cmdlet relies on.

| Cmdlet | Description |
|---|---|
| [Get-PSScriptBuilderConfiguration](Get-PSScriptBuilderConfiguration.md) | Retrieves the global PSScriptBuilder configuration |
| [New-PSScriptBuilderConfiguration](New-PSScriptBuilderConfiguration.md) | Creates a new PSScriptBuilder configuration file with default values |
| [Set-PSScriptBuilderProjectRoot](Set-PSScriptBuilderProjectRoot.md) | Sets the PSScriptBuilder project root directory |

## Release Management

Track version numbers and other release metadata, then propagate them into the files that need
to reflect the current version — templates, manifests, and changelogs.

| Cmdlet | Description |
|---|---|
| [New-PSScriptBuilderReleaseData](New-PSScriptBuilderReleaseData.md) | Creates a new release data file with default values |
| [Get-PSScriptBuilderReleaseData](Get-PSScriptBuilderReleaseData.md) | Retrieves the current release data configuration |
| [Get-PSScriptBuilderReleaseDataTokens](Get-PSScriptBuilderReleaseDataTokens.md) | Retrieves available release data tokens for substitution in bump files |
| [Test-PSScriptBuilderReleaseData](Test-PSScriptBuilderReleaseData.md) | Tests the release data file for validity |
| [Update-PSScriptBuilderReleaseData](Update-PSScriptBuilderReleaseData.md) | Updates release data including version and metadata |
| [Format-PSScriptBuilderReleaseDataResult](Format-PSScriptBuilderReleaseDataResult.md) | Formats and displays the result of a release data update operation |
| [Get-PSScriptBuilderBumpConfiguration](Get-PSScriptBuilderBumpConfiguration.md) | Retrieves the bump configuration |
| [Test-PSScriptBuilderBumpConfiguration](Test-PSScriptBuilderBumpConfiguration.md) | Tests the bump configuration file for validity |
| [Update-PSScriptBuilderBumpFiles](Update-PSScriptBuilderBumpFiles.md) | Updates configured project files with current version information |
| [Format-PSScriptBuilderBumpResult](Format-PSScriptBuilderBumpResult.md) | Formats and displays the result of a bump operation |
