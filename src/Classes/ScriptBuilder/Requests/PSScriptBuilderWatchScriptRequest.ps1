using namespace System

#region Class PSScriptBuilderWatchScriptRequest
<#
.SYNOPSIS
    Encapsulates parameters for a script-mode file watcher.
.DESCRIPTION
    The PSScriptBuilderWatchScriptRequest class holds all configuration needed to start
    PSScriptBuilderProjectWatcher in Script mode: source collection, optional template path,
    debounce, extension filtering, and the script block to invoke on changes.
#>
class PSScriptBuilderWatchScriptRequest {
    #region Properties
    <#
    .SYNOPSIS
        The content collector used for deriving watch paths.
    .DESCRIPTION
        The ContentCollector property holds the PSScriptBuilderContentCollector instance
        that provides the collectors and their include paths used to determine which directories to watch.
    #>
    [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The absolute path to the template file.
    .DESCRIPTION
        The TemplatePath property holds the resolved absolute path to the template file. If provided,
        the directory containing the template is added to the watch list. May be empty.
    #>
    [string] $TemplatePath

    <#
    .SYNOPSIS
        The debounce interval in milliseconds.
    .DESCRIPTION
        The Debounce property holds the number of milliseconds to wait after the last detected
        file change before invoking the script block.
    #>
    [int] $Debounce

    <#
    .SYNOPSIS
        The file extensions to include when filtering file system events.
    .DESCRIPTION
        The IncludeExtensions property holds the list of file extensions (e.g. '.ps1') that are
        allowed to trigger script block execution. The template file is always exempt from this filter.
        If empty, all file system events trigger execution regardless of extension.
    #>
    [string[]] $IncludeExtensions

    <#
    .SYNOPSIS
        The script block to invoke when file changes are detected.
    .DESCRIPTION
        The ScriptBlock property holds the user-provided script block that is invoked when changes
        are detected. Receives the changed file paths as a string array via the first argument.
    #>
    [scriptblock] $ScriptBlock
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance with the specified script watch configuration.
    .DESCRIPTION
        Creates a fully configured PSScriptBuilderWatchScriptRequest.
        Throws ArgumentNullException if scriptBlock is null.
    .PARAMETER contentCollector
        The PSScriptBuilderContentCollector instance that provides the collectors and their include paths.
    .PARAMETER templatePath
        The resolved absolute path to the template file. May be empty if no template directory should be watched.
    .PARAMETER debounce
        The number of milliseconds to wait after the last file change before triggering the script block.
    .PARAMETER includeExtensions
        The file extensions that are allowed to trigger execution. Pass an empty array to allow all extensions.
    .PARAMETER scriptBlock
        The script block to invoke when changes are detected. Must not be null.
    #>
    PSScriptBuilderWatchScriptRequest(
        [PSScriptBuilderContentCollector] $contentCollector,
        [string]                          $templatePath,
        [int]                             $debounce,
        [string[]]                        $includeExtensions,
        [scriptblock]                     $scriptBlock
    ) {
        if ($null -eq $scriptBlock) {
            throw [ArgumentNullException]::new('scriptBlock', 'A ScriptBlock must be provided when using Script mode.')
        }

        $this.ContentCollector  = $contentCollector
        $this.TemplatePath      = $templatePath
        $this.Debounce          = $debounce
        $this.IncludeExtensions = $includeExtensions
        $this.ScriptBlock       = $scriptBlock
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderWatchScriptRequest
