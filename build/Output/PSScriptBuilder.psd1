@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSScriptBuilder.psm1'

# Version number of this module.
ModuleVersion = '1.4.0'

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
v1.4.0

Added:
- Source maps now record a format version; a source map in a newer, incompatible format is rejected with a clear error
- Resolve-PSScriptBuilderSourceLocation: ComponentLineCount property (number of lines the component spans in the output script)

Changed:
- Update-PSScriptBuilderBumpFiles / Update-PSScriptBuilderReleaseData / New-PSScriptBuilderReleaseData: a run either updates every file or leaves all of them unchanged; a file changed in the meantime is not overwritten; a backup left next to a file by an interrupted run stops the next run
- Update-PSScriptBuilderBumpFiles / Update-PSScriptBuilderReleaseData / New-PSScriptBuilderReleaseData: -Confirm asks once per run and names every file that will change; -WhatIf shows the same
- Update-PSScriptBuilderBumpFiles: bump files are processed and reported in the configured order, with their full paths
- Update-PSScriptBuilderBumpFiles / Test-PSScriptBuilderBumpConfiguration: a token listed more than once is rejected before any file is processed

Deprecated:
- Update-PSScriptBuilderBumpFiles / Update-PSScriptBuilderReleaseData / New-PSScriptBuilderReleaseData: the result returned after -WhatIf or a declined confirmation; version 2.0.0 will return nothing in these cases
- Update-PSScriptBuilderReleaseData: TotalOperationsPerformed; will be removed in version 2.0.0

Fixed:
- Update-PSScriptBuilderBumpFiles: a file configured with differently written paths no longer loses the changes of one entry
- Update-PSScriptBuilderBumpFiles: a placeholder in another letter case whose token has no value now stops the run with an error instead of being silently replaced with nothing
- Update-PSScriptBuilderBumpFiles / Update-PSScriptBuilderReleaseData: a value that changes in letter case only is now written and reported
- Update-PSScriptBuilderBumpFiles: bump files with the same name in different folders each keep their own content when restored after an error
- Update-PSScriptBuilderBumpFiles: a file that cannot be written no longer leaves the project partially bumped
- Update-PSScriptBuilderBumpFiles: a token listed twice in different letter case is now rejected as a duplicate
- Update-PSScriptBuilderReleaseData: a failed update no longer rewrites the release data file
- Update-PSScriptBuilderBumpFiles / New-PSScriptBuilderReleaseData: -Confirm and -WhatIf no longer refer to internal steps
- Resolve-PSScriptBuilderSourceLocation / Get-PSScriptBuilderSourceCoverage: a missing or locked output script now causes a single warning instead of an error
- Resolve-PSScriptBuilderSourceLocation / Get-PSScriptBuilderSourceCoverage: a damaged source map is now rejected with an error that names the problem
- Resolve-PSScriptBuilderSourceLocation: -ErrorRecord now only resolves errors that originated in the output script
- Resolve-PSScriptBuilderSourceLocation / Get-PSScriptBuilderSourceCoverage: lines outside any component are now reported as not resolvable instead of being attributed to the preceding component
- Invoke-PSScriptBuilderBuild / Watch-PSScriptBuilderProject: source map line numbers now match PowerShell's for output scripts with CR-only line endings or an extra carriage return before a line break
- New-PSScriptBuilderConfiguration / New-PSScriptBuilderProject: a relative -Path is now resolved against the current PowerShell location
- Set-PSScriptBuilderProjectRoot: -Path is no longer read as a wildcard pattern
- Project root discovery: now fails with a clear error when the current location is on another provider's drive

Full changelog: https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/CHANGELOG.md
'@

    } # End of PSData hashtable

} # End of PrivateData hashtable

}
