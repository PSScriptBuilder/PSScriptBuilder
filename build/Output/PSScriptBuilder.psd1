@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSScriptBuilder.psm1'

# Version number of this module.
ModuleVersion = '1.3.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = '22c11119-0a25-447a-a78f-6d28552f1157'

# Author of this module
Author = 'Tim Hartling'

# Copyright statement for this module
Copyright = '(c) 2026 Tim Hartling. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Build a single deployable PowerShell script from a multi-file project. PSScriptBuilder resolves class inheritance and dependency order automatically using AST analysis - no manual ordering required. Supports classes, enums, functions, template-based output, and release management.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    "Add-PSScriptBuilderCollector",
    "Compress-PSScriptBuilderScript",
    "ConvertTo-PSScriptBuilderComponentDependencyTree",
    "Export-PSScriptBuilderBuildResult",
    "Export-PSScriptBuilderDependencyGraph",
    "Find-PSScriptBuilderUnusedComponent",
    "Format-PSScriptBuilderBuildResult",
    "Format-PSScriptBuilderBumpResult",
    "Format-PSScriptBuilderDependencyAnalysis",
    "Format-PSScriptBuilderReleaseDataResult",
    "Format-PSScriptBuilderSourceCoverage",
    "Format-PSScriptBuilderTemplateAnalysis",
    "Get-PSScriptBuilderBumpConfiguration",
    "Get-PSScriptBuilderCollector",
    "Get-PSScriptBuilderCollectorContent",
    "Get-PSScriptBuilderComponentDependency",
    "Get-PSScriptBuilderConfiguration",
    "Get-PSScriptBuilderDependencyAnalysis",
    "Get-PSScriptBuilderReleaseData",
    "Get-PSScriptBuilderReleaseDataTokens",
    "Get-PSScriptBuilderSourceCoverage",
    "Get-PSScriptBuilderTemplateAnalysis",
    "Invoke-PSScriptBuilderBuild",
    "New-PSScriptBuilderCollector",
    "New-PSScriptBuilderConfiguration",
    "New-PSScriptBuilderContentCollector",
    "New-PSScriptBuilderProject",
    "New-PSScriptBuilderReleaseData",
    "New-PSScriptBuilderTemplate",
    "Remove-PSScriptBuilderCollector",
    "Resolve-PSScriptBuilderSourceLocation",
    "Set-PSScriptBuilderProjectRoot",
    "Test-PSScriptBuilderBumpConfiguration",
    "Test-PSScriptBuilderReleaseData",
    "Test-PSScriptBuilderTemplate",
    "Update-PSScriptBuilderBumpFiles",
    "Update-PSScriptBuilderReleaseData",
    "Watch-PSScriptBuilderProject"
)
# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @(
            'PSScriptBuilder', 'Build', 'BuildTool', 'Classes', 'ClassDependency', 
            'DependencyResolution', 'TopologicalSort', 'AST', 'ReleaseManagement', 
            'SemVer', 'ModuleBuilder', 'Deployment', 'Automation', 
            'PowerShell5', 'PowerShell7', 
            'PSEdition_Desktop', 'PSEdition_Core', 
            'Windows', 'Linux', 'MacOS'
        )

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PSScriptBuilder/PSScriptBuilder'

        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/images/brand/logo-v2_64x64.png'

        # ReleaseNotes of this module
        ReleaseNotes = @'
v1.3.0

Added:
- Template escape syntax ({{{{KEY}}}}) for literal {{KEY}}-shaped text in templates
- Format-PSScriptBuilderSourceCoverage
- Get-PSScriptBuilderSourceCoverage
- Resolve-PSScriptBuilderSourceLocation
- -WriteSourceMap switch for Invoke-PSScriptBuilderBuild and Watch-PSScriptBuilderProject
- build.writeSourceMap configuration option
- Format-PSScriptBuilderTemplateAnalysis
- Format-PSScriptBuilderDependencyAnalysis
- Examples 16 (Source Maps) and 17 (Code Coverage)

Changed:
- Format-PSScriptBuilderBumpResult: Pattern line hidden when identical to Old Value
- Invoke-PSScriptBuilderBuild: per-phase durations reported via the verbose stream
- Configuration: build section's backupPath, orderedComponentsKey, backupEnabled, and syntaxValidationEnabled are now optional

Fixed:
- Format-PSScriptBuilderSourceCoverage: a backslash-style absolute path is now correctly shown relative to the project root on non-Windows systems
- Invoke-PSScriptBuilderBuild / Update-PSScriptBuilderBumpFiles / Update-PSScriptBuilderReleaseData / New-PSScriptBuilderProject: directory/file creation now fails clearly instead of silently doing nothing on a type collision
- Invoke-PSScriptBuilderBuild / Watch-PSScriptBuilderProject: Free Mode now consolidates Using collectors like Ordered/Hybrid Mode, preventing duplicate using statements
- Update-PSScriptBuilderBumpFiles: backup/rollback failures on PowerShell 7 no longer go undetected
- Invoke-PSScriptBuilderBuild / Watch-PSScriptBuilderProject: source files without a UTF-8 BOM are now read correctly regardless of the system codepage
- Compress-PSScriptBuilderScript: -RemoveBlankLines/-RemoveOutputStatements now preserve each line's original line ending
- Update-PSScriptBuilderBumpFiles: a pattern matching nothing now emits a warning naming the file
- Invoke-PSScriptBuilderBuild / Watch-PSScriptBuilderProject: Ordered/Hybrid Mode now validates that every Using placeholder is actually replaced
- Verbose and formatted output: file sizes and durations now format consistently regardless of system region settings
- Get-PSScriptBuilderCollector: -CollectionKey and -Type now belong to separate parameter sets
- Invoke-PSScriptBuilderBuild / Get-PSScriptBuilderDependencyAnalysis: duplicate component names (including case-only differences) now throw instead of silently collapsing
- Invoke-PSScriptBuilderBuild / Get-PSScriptBuilderDependencyAnalysis: components without dependencies are now ordered deterministically in all three modes
- Update-PSScriptBuilderBumpFiles: escaped literal braces and parentheses in patterns now work correctly; conflicting token/regex combinations now fail validation immediately
- Update-PSScriptBuilderBumpFiles: token matching is now case-insensitive; replacements no longer depend on processing order
- Invoke-PSScriptBuilderBuild / Test-PSScriptBuilderTemplate: placeholder matching is now case-insensitive everywhere, including duplicate detection
- Invoke-PSScriptBuilderBuild: inserted content is no longer re-scanned for further placeholder replacements
- Invoke-PSScriptBuilderBuild / Test-PSScriptBuilderTemplate / Get-PSScriptBuilderTemplateAnalysis: collector keys colliding with bump-file tokens or the ordered-components key now fail validation immediately
- Test-PSScriptBuilderTemplate: now collects content before analyzing dependencies, fixing false-positive cross-dependency results
- New-PSScriptBuilderConfiguration / New-PSScriptBuilderReleaseData: target/output directories are now created automatically if missing

Full changelog: https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/CHANGELOG.md
'@

    } # End of PSData hashtable

} # End of PrivateData hashtable

}
