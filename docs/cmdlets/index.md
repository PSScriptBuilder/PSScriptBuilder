# Cmdlet Reference

PSScriptBuilder provides 24 public cmdlets across four categories.

## Script Building

| Cmdlet | Description |
|---|---|
| [New-PSScriptBuilderContentCollector](New-PSScriptBuilderContentCollector.md) | Creates a new content collector for managing multiple component collectors |
| [New-PSScriptBuilderCollector](New-PSScriptBuilderCollector.md) | Creates a new collector for PowerShell script components |
| [Add-PSScriptBuilderCollector](Add-PSScriptBuilderCollector.md) | Adds a collector to a ContentCollector for fluent pipeline configuration |
| [Get-PSScriptBuilderCollector](Get-PSScriptBuilderCollector.md) | Retrieves collectors from a ContentCollector |
| [Get-PSScriptBuilderCollectorContent](Get-PSScriptBuilderCollectorContent.md) | Retrieves collected data from a collector |
| [Remove-PSScriptBuilderCollector](Remove-PSScriptBuilderCollector.md) | Removes a collector from a ContentCollector |
| [Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md) | Executes the complete PowerShell script build process |
| [Format-PSScriptBuilderBuildResult](Format-PSScriptBuilderBuildResult.md) | Formats and displays the result of a build operation |

## Analysis & Validation

| Cmdlet | Description |
|---|---|
| [Get-PSScriptBuilderDependencyAnalysis](Get-PSScriptBuilderDependencyAnalysis.md) | Analyzes dependencies between components without performing a build |
| [Get-PSScriptBuilderTemplateAnalysis](Get-PSScriptBuilderTemplateAnalysis.md) | Analyzes a template file for placeholders and structure |
| [Test-PSScriptBuilderTemplate](Test-PSScriptBuilderTemplate.md) | Validates a template file without performing a build |

## Configuration

| Cmdlet | Description |
|---|---|
| [Get-PSScriptBuilderConfiguration](Get-PSScriptBuilderConfiguration.md) | Retrieves the global PSScriptBuilder configuration |
| [New-PSScriptBuilderConfiguration](New-PSScriptBuilderConfiguration.md) | Creates a new PSScriptBuilder configuration file with default values |
| [Set-PSScriptBuilderProjectRoot](Set-PSScriptBuilderProjectRoot.md) | Sets the PSScriptBuilder project root directory |

## Release Management

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
