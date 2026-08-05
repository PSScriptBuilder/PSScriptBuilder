@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSScriptBuilder.psm1'

# Version number of this module.
ModuleVersion = '1.2.0'

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
    "Format-PSScriptBuilderReleaseDataResult",
    "Get-PSScriptBuilderBumpConfiguration",
    "Get-PSScriptBuilderCollector",
    "Get-PSScriptBuilderCollectorContent",
    "Get-PSScriptBuilderComponentDependency",
    "Get-PSScriptBuilderConfiguration",
    "Get-PSScriptBuilderDependencyAnalysis",
    "Get-PSScriptBuilderReleaseData",
    "Get-PSScriptBuilderReleaseDataTokens",
    "Get-PSScriptBuilderTemplateAnalysis",
    "Invoke-PSScriptBuilderBuild",
    "New-PSScriptBuilderCollector",
    "New-PSScriptBuilderConfiguration",
    "New-PSScriptBuilderContentCollector",
    "New-PSScriptBuilderProject",
    "New-PSScriptBuilderReleaseData",
    "New-PSScriptBuilderTemplate",
    "Remove-PSScriptBuilderCollector",
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
v1.2.0

Added:
- Export-PSScriptBuilderBuildResult
- New-PSScriptBuilderTemplate
- Find-PSScriptBuilderUnusedComponent
- Watch-PSScriptBuilderProject (Build mode and Script mode)
- Example 15 (Watcher)

Changed:
- PSScriptBuilderAstEngine: ParseFile now returns PSScriptBuilderParseResult with AST and parse errors
- Collectors (Class, Enum, Function, Using): structural parse errors throw InvalidOperationException
- PSScriptBuilderConfigValidator: values are now type-validated against the schema
- Invoke-PSScriptBuilderBuild: consolidated cross-collector dependency warnings; encoding pre-flight check for PS 5.1 compatibility

Fixed:
- New-PSScriptBuilderProject: session guard removed from scaffolded build script
- PSScriptBuilderReleaseDataValidator: type names now rendered correctly in validation error messages

Full changelog: https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/CHANGELOG.md
'@

    } # End of PSData hashtable

} # End of PrivateData hashtable

}
