#region Class PSScriptBuilderWatchBuildRequest
<#
.SYNOPSIS
    Encapsulates parameters for a build-mode file watcher.
.DESCRIPTION
    The PSScriptBuilderWatchBuildRequest class holds all configuration needed to start
    PSScriptBuilderProjectWatcher in Build mode: source collection, template, output, debounce,
    extension filtering, and optional backup and post-build action settings.
#>
class PSScriptBuilderWatchBuildRequest {
    #region Properties
    <#
    .SYNOPSIS
        The content collector used for collecting source files.
    .DESCRIPTION
        The ContentCollector property holds the PSScriptBuilderContentCollector instance
        that provides the collectors and their include paths used during each build cycle.
    #>
    [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The absolute path to the template file.
    .DESCRIPTION
        The TemplatePath property holds the resolved absolute path to the script template file
        used during each build cycle. The directory containing the template is added to the watch list.
    #>
    [string] $TemplatePath

    <#
    .SYNOPSIS
        The absolute path to the output file.
    .DESCRIPTION
        The OutputPath property holds the resolved absolute path to the generated output script file.
        File system events targeting this path are ignored to prevent build loops.
    #>
    [string] $OutputPath

    <#
    .SYNOPSIS
        The debounce interval in milliseconds.
    .DESCRIPTION
        The Debounce property holds the number of milliseconds to wait after the last detected
        file change before triggering a build.
    #>
    [int] $Debounce

    <#
    .SYNOPSIS
        The file extensions to include when filtering file system events.
    .DESCRIPTION
        The IncludeExtensions property holds the list of file extensions (e.g. '.ps1') that are
        allowed to trigger a build. The template file is always exempt from this filter.
        If empty, all file system events trigger a build regardless of extension.
    #>
    [string[]] $IncludeExtensions

    <#
    .SYNOPSIS
        The absolute path to the backup directory.
    .DESCRIPTION
        The BackupPath property holds the resolved absolute path to the directory where
        backup files are stored before overwriting the output file.
    #>
    [string] $BackupPath

    <#
    .SYNOPSIS
        The placeholder key for dependency-ordered components.
    .DESCRIPTION
        The OrderedComponentsKey property holds the template placeholder name used for
        dependency-ordered components (e.g., "ORDERED_COMPONENTS").
    #>
    [string] $OrderedComponentsKey

    <#
    .SYNOPSIS
        Indicates whether to create a backup before overwriting the output file.
    .DESCRIPTION
        The EnableBackup property is true if a timestamped backup of the existing output file
        should be created before each build overwrites it.
    #>
    [bool] $EnableBackup

    <#
    .SYNOPSIS
        Indicates whether output syntax validation is skipped.
    .DESCRIPTION
        The SkipSyntaxValidation property is true if the generated output file should not be
        validated for PowerShell syntax correctness after each build.
    #>
    [bool] $SkipSyntaxValidation

    <#
    .SYNOPSIS
        An optional script block invoked after each successful build.
    .DESCRIPTION
        The OnSuccess property holds an optional script block that is called after each successful
        build cycle. Receives the PSScriptBuilderBuildResult as its first argument.
    #>
    [scriptblock] $OnSuccess

    <#
    .SYNOPSIS
        An optional script block invoked after each failed build.
    .DESCRIPTION
        The OnError property holds an optional script block that is called after a build cycle
        fails. Receives a PSScriptBuilderWatchBuildErrorResult as its first argument.
    #>
    [scriptblock] $OnError
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance with the specified build watch configuration.
    .DESCRIPTION
        Creates a fully configured PSScriptBuilderWatchBuildRequest.
    .PARAMETER contentCollector
        The PSScriptBuilderContentCollector instance that provides the collectors and their include paths.
    .PARAMETER templatePath
        The resolved absolute path to the script template file.
    .PARAMETER outputPath
        The resolved absolute path to the generated output script file.
    .PARAMETER debounce
        The number of milliseconds to wait after the last file change before triggering a build.
    .PARAMETER includeExtensions
        The file extensions that are allowed to trigger a build. Pass an empty array to allow all extensions.
    .PARAMETER backupPath
        The resolved absolute path to the directory where backup files are stored. May be empty if backup is disabled.
    .PARAMETER orderedComponentsKey
        The template placeholder name used for dependency-ordered components.
    .PARAMETER enableBackup
        True if a backup of the existing output file should be created before each build.
    .PARAMETER skipSyntaxValidation
        True if the generated output file should not be validated for PowerShell syntax correctness.
    .PARAMETER onSuccess
        An optional script block invoked after each successful build. May be null if no callback is needed.
    .PARAMETER onError
        An optional script block invoked after each failed build. May be null if no callback is needed.
    #>
    PSScriptBuilderWatchBuildRequest(
        [PSScriptBuilderContentCollector] $contentCollector,
        [string]                          $templatePath,
        [string]                          $outputPath,
        [int]                             $debounce,
        [string[]]                        $includeExtensions,
        [string]                          $backupPath,
        [string]                          $orderedComponentsKey,
        [bool]                            $enableBackup,
        [bool]                            $skipSyntaxValidation,
        [scriptblock]                     $onSuccess,
        [scriptblock]                     $onError
    ) {
        $this.ContentCollector     = $contentCollector
        $this.TemplatePath         = $templatePath
        $this.OutputPath           = $outputPath
        $this.Debounce             = $debounce
        $this.IncludeExtensions    = $includeExtensions
        $this.BackupPath           = $backupPath
        $this.OrderedComponentsKey = $orderedComponentsKey
        $this.EnableBackup         = $enableBackup
        $this.SkipSyntaxValidation = $skipSyntaxValidation
        $this.OnSuccess            = $onSuccess
        $this.OnError              = $onError
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderWatchBuildRequest
