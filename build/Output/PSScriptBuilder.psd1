@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSScriptBuilder.psm1'

# Version number of this module.
ModuleVersion = '1.0.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = '22c11119-0a25-447a-a78f-6d28552f1157'

# Author of this module
Author = 'Tim Hartling'

# Copyright statement for this module
Copyright = '(c) 2026 Tim Hartling. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Build a single deployable PowerShell script from a multi-file project. PSScriptBuilder resolves class inheritance and dependency order automatically using AST analysis — no manual ordering required. Supports classes, enums, functions, template-based output, and release management.'

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
    "Format-PSScriptBuilderBuildResult", 
    "Format-PSScriptBuilderBumpResult", 
    "Format-PSScriptBuilderReleaseDataResult", 
    "Get-PSScriptBuilderBumpConfiguration", 
    "Get-PSScriptBuilderCollector", 
    "Get-PSScriptBuilderCollectorContent",  
    "Get-PSScriptBuilderConfiguration", 
    "Get-PSScriptBuilderDependencyAnalysis", 
    "Get-PSScriptBuilderReleaseData", 
    "Get-PSScriptBuilderReleaseDataTokens", 
    "Get-PSScriptBuilderTemplateAnalysis", 
    "Invoke-PSScriptBuilderBuild", 
    "New-PSScriptBuilderCollector", 
    "New-PSScriptBuilderConfiguration", 
    "New-PSScriptBuilderContentCollector", 
    "New-PSScriptBuilderReleaseData", 
    "Remove-PSScriptBuilderCollector", 
    "Set-PSScriptBuilderProjectRoot", 
    "Test-PSScriptBuilderBumpConfiguration", 
    "Test-PSScriptBuilderReleaseData", 
    "Test-PSScriptBuilderTemplate", 
    "Update-PSScriptBuilderBumpFiles", 
    "Update-PSScriptBuilderReleaseData"
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
        IconUri = 'https://raw.githubusercontent.com/PSScriptBuilder/PSScriptBuilder/main/assets/logo_64x64.png'

        # ReleaseNotes of this module
        ReleaseNotes = @'
## v1.0.0 — Initial Release

PSScriptBuilder is a PowerShell module that builds a single deployable script from multi-file projects —
with automatic dependency resolution, topological sorting, cycle detection, template-based output,
and integrated release management.

- Collector-based script building (Using, Enum, Class, Function, File)
- AST-based extraction with automatic dependency resolution
- Topological sorting using Kahn's algorithm
- Circular and cross-dependency detection
- Template system with Free, Hybrid and Ordered Mode
- Full release management pipeline with SemVer bumping
- Bump file propagation with token and regex mode
- Compatible with PowerShell 5.1 and PowerShell 7+
- Full documentation with guides and cmdlet reference at https://docs.psscriptbuilder.com
'@

    } # End of PSData hashtable

} # End of PrivateData hashtable

}
