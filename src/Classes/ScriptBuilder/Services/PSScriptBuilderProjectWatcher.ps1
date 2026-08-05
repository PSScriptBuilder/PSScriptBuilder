using namespace System
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent

#region Class PSScriptBuilderProjectWatcher
class PSScriptBuilderProjectWatcher {
    #region Properties
    #region Watcher
    <#
    .SYNOPSIS
        The content collector used for collecting source files.
    .DESCRIPTION
        The ContentCollector property holds the PSScriptBuilderContentCollector instance
        that provides the collectors and their include paths used during each build cycle.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The absolute path to the template file.
    .DESCRIPTION
        The TemplatePath property holds the resolved absolute path to the script template file
        used during each build cycle.
    #>
    hidden [string] $TemplatePath

    <#
    .SYNOPSIS
        The absolute path to the output file.
    .DESCRIPTION
        The OutputPath property holds the resolved absolute path to the generated output script file.
        File system events targeting this path are ignored to prevent build loops.
    #>
    hidden [string] $OutputPath

    <#
    .SYNOPSIS
        The debounce interval in milliseconds.
    .DESCRIPTION
        The Debounce property holds the number of milliseconds to wait after the last detected
        file change before triggering a build. Default is 500ms.
    #>
    hidden [int] $Debounce

    <#
    .SYNOPSIS
        A script block executed instead of a build when running in Script mode.
    .DESCRIPTION
        The ScriptBlock property holds the user-provided script block that is invoked in place of
        a build cycle when the watcher operates in Script mode. Receives the changed file paths
        as a string array via the first argument.
    #>
    hidden [scriptblock] $ScriptBlock

    <#
    .SYNOPSIS
        The file extensions to include when filtering file system events.
    .DESCRIPTION
        The IncludeExtensions property holds the list of file extensions (e.g. '.ps1') that are
        allowed to trigger a build or script execution. The template file is always exempt from
        this filter. If empty, all file system events are passed through regardless of extension.
    #>
    hidden [string[]] $IncludeExtensions
    #endregion Watcher

    #region Build
    <#
    .SYNOPSIS
        The absolute path to the backup directory.
    .DESCRIPTION
        The BackupPath property holds the resolved absolute path to the directory where
        backup files are stored before overwriting the output file.
    #>
    hidden [string] $BackupPath

    <#
    .SYNOPSIS
        The placeholder key for dependency-ordered components.
    .DESCRIPTION
        The OrderedComponentsKey property holds the template placeholder name used for
        dependency-ordered components (e.g., "ORDERED_COMPONENTS").
    #>
    hidden [string] $OrderedComponentsKey

    <#
    .SYNOPSIS
        Indicates whether to create a backup before overwriting the output file.
    .DESCRIPTION
        The EnableBackup property is true if a timestamped backup of the existing output file
        should be created before each build overwrites it.
    #>
    hidden [bool] $EnableBackup

    <#
    .SYNOPSIS
        Indicates whether output syntax validation is skipped.
    .DESCRIPTION
        The SkipSyntaxValidation property is true if the generated output file should not be
        validated for PowerShell syntax correctness after each build.
    #>
    hidden [bool] $SkipSyntaxValidation

    <#
    .SYNOPSIS
        An optional script block invoked after each successful build.
    .DESCRIPTION
        The OnSuccess property holds an optional script block that is called after each successful
        build cycle. Receives the PSScriptBuilderBuildResult as its first argument.
    #>
    hidden [scriptblock] $OnSuccess

    <#
    .SYNOPSIS
        An optional script block invoked after each failed build.
    .DESCRIPTION
        The OnError property holds an optional script block that is called after a build cycle
        fails. Receives a PSScriptBuilderWatchBuildErrorResult as its first argument.
    #>
    hidden [scriptblock] $OnError
    #endregion Build

    #region Internal
    <#
    .SYNOPSIS
        The FileSystemWatcher event names to register.
    .DESCRIPTION
        The WatchEventNames static property holds the fixed list of FileSystemWatcher event names
        registered for each watched directory: Changed, Created, Deleted, and Renamed.
    #>
    static [string[]] $WatchEventNames = @('Changed', 'Created', 'Deleted', 'Renamed')

    <#
    .SYNOPSIS
        The active FileSystemWatcher instances.
    .DESCRIPTION
        The Watchers property holds the list of FileSystemWatcher instances created for each
        watched directory. Disposed during Cleanup().
    #>
    hidden [List[FileSystemWatcher]] $Watchers

    <#
    .SYNOPSIS
        The registered event subscription jobs.
    .DESCRIPTION
        The EventJobs property holds the list of background jobs returned by Register-ObjectEvent.
        Unregistered and removed during Cleanup().
    #>
    hidden [List[object]] $EventJobs

    <#
    .SYNOPSIS
        The unique prefix for event source identifiers.
    .DESCRIPTION
        The EventPrefix property holds a GUID-based prefix used to generate unique SourceIdentifier
        values for all registered events, preventing conflicts with other active watchers.
    #>
    hidden [string] $EventPrefix
    #endregion Internal
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderProjectWatcher in Build mode.
    .DESCRIPTION
        Creates a new PSScriptBuilderProjectWatcher that runs a full build cycle when file changes
        are detected. An optional OnSuccess script block can be invoked after each successful build,
        and an optional OnError script block can be invoked after each failed build.
    .PARAMETER request
        The PSScriptBuilderWatchBuildRequest containing all build watch configuration.
    #>
    PSScriptBuilderProjectWatcher([PSScriptBuilderWatchBuildRequest] $request) {
        $this.ContentCollector     = $request.ContentCollector
        $this.TemplatePath         = $request.TemplatePath
        $this.OutputPath           = $request.OutputPath
        $this.Debounce             = $request.Debounce
        $this.IncludeExtensions    = $request.IncludeExtensions
        $this.BackupPath           = $request.BackupPath
        $this.OrderedComponentsKey = $request.OrderedComponentsKey
        $this.EnableBackup         = $request.EnableBackup
        $this.SkipSyntaxValidation = $request.SkipSyntaxValidation
        $this.OnSuccess            = $request.OnSuccess
        $this.OnError              = $request.OnError
        $this.Watchers             = [List[FileSystemWatcher]]::new()
        $this.EventJobs            = [List[object]]::new()
        $this.EventPrefix          = "PSScriptBuilderWatch_$([Guid]::NewGuid().ToString('N'))"
    }

    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderProjectWatcher in Script mode.
    .DESCRIPTION
        Creates a new PSScriptBuilderProjectWatcher that invokes a user-provided script block
        instead of a build cycle when file changes are detected.
    .PARAMETER request
        The PSScriptBuilderWatchScriptRequest containing all script watch configuration.
    #>
    PSScriptBuilderProjectWatcher([PSScriptBuilderWatchScriptRequest] $request) {
        $this.ContentCollector  = $request.ContentCollector
        $this.TemplatePath      = $request.TemplatePath
        $this.Debounce          = $request.Debounce
        $this.ScriptBlock       = $request.ScriptBlock
        $this.IncludeExtensions = $request.IncludeExtensions
        $this.Watchers          = [List[FileSystemWatcher]]::new()
        $this.EventJobs         = [List[object]]::new()
        $this.EventPrefix       = "PSScriptBuilderWatch_$([Guid]::NewGuid().ToString('N'))"
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Starts the file system watcher and enters the watch loop.
    .DESCRIPTION
        Coordinates startup by resolving watch paths, initializing global state, registering
        watchers, and entering the run loop. Cleans up all watchers and events on exit.
        InitializeGlobalState() must always be called before RegisterWatchers() because the
        event action closures write to the global dictionary initialized by InitializeGlobalState().
    #>
    [void] Start() {
        $watchPaths = $this.GetWatchPaths()

        Write-Host "[$($this.GetTimestamp())] Watching $($watchPaths.Count) path(s). Press Ctrl+C to stop."

        $templateDir = $null
        if (-not [string]::IsNullOrEmpty($this.TemplatePath)) {
            $templateDir = [Path]::GetDirectoryName($this.TemplatePath)
        }

        foreach ($watchPath in $watchPaths) {
            if ($watchPath -eq $templateDir) {
                Write-Verbose "  $watchPath (Template)"
            }
            else {
                Write-Verbose "  $watchPath"
            }
        }

        if ($null -ne $this.IncludeExtensions -and $this.IncludeExtensions.Count -gt 0) {
            Write-Verbose "  Include extensions: $($this.IncludeExtensions -join ', ')"
        }

        if ($this.Debounce -ge 1000) {
            $debounceDisplay = "$([math]::Round($this.Debounce / 1000, 1))s"
        }
        else {
            $debounceDisplay = "$($this.Debounce)ms"
        }

        Write-Verbose "  Debounce: $debounceDisplay"

        $this.InitializeGlobalState()
        $this.RegisterWatchers($watchPaths)

        try {
            $this.RunLoop()
        }
        finally {
            $this.Cleanup()
        }
    }

    <#
    .SYNOPSIS
        Initializes the global debounce state variables.
    .DESCRIPTION
        The InitializeGlobalState() method sets the three global variables used by the event action
        closures and the run loop: the pending flag, the last-change timestamp, and the file
        dictionary. Must be called before RegisterWatchers() to ensure the dictionary exists before
        any file system event can fire.
    #>
    hidden [void] InitializeGlobalState() {
        $Global:_PSScriptBuilderWatchPending           = $false
        $Global:_PSScriptBuilderWatchTime              = [datetime]::MinValue
        $Global:_PSScriptBuilderWatchFiles             = [ConcurrentDictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
        $Global:_PSScriptBuilderWatchIncludeExtensions = $this.IncludeExtensions
        $Global:_PSScriptBuilderWatchTemplatePath      = $this.TemplatePath
    }

    <#
    .SYNOPSIS
        Creates FileSystemWatcher instances and registers event subscriptions.
    .DESCRIPTION
        The RegisterWatchers() method creates one FileSystemWatcher per watch path and registers
        the four file system events (Changed, Created, Deleted, Renamed) for each. Event
        subscriptions are stored in EventJobs and watcher instances in Watchers for cleanup.
        Requires InitializeGlobalState() to have been called first so the global file dictionary
        is available to the event action closures.
    .PARAMETER watchPaths
        The absolute directory paths to watch, as returned by GetWatchPaths().
    #>
    hidden [void] RegisterWatchers([string[]] $watchPaths) {
        $eventNames = [PSScriptBuilderProjectWatcher]::WatchEventNames -join ', '
        Write-Verbose "Registering watchers for $($watchPaths.Count) path(s). Events: $eventNames."

        $index = 0

        foreach ($watchPath in $watchPaths) {
            $watcher = [FileSystemWatcher]::new($watchPath)
            $watcher.IncludeSubdirectories = $true
            $watcher.EnableRaisingEvents   = $true
            $watcher.NotifyFilter          = [NotifyFilters]::LastWrite -bor [NotifyFilters]::FileName

            $eventAction = {
                $filePath   = $Event.SourceEventArgs.FullPath
                $changeType = $Event.SourceEventArgs.ChangeType.ToString()

                if ($filePath -eq $Event.MessageData) { return }

                $extensions = $Global:_PSScriptBuilderWatchIncludeExtensions

                if ($null -ne $extensions -and $extensions.Count -gt 0) {
                    $extension  = [Path]::GetExtension($filePath)
                    $isTemplate = $filePath -eq $Global:_PSScriptBuilderWatchTemplatePath

                    if (-not $isTemplate -and $extension -notin $extensions) {
                        return
                    }
                }

                $Global:_PSScriptBuilderWatchPending = $true
                $Global:_PSScriptBuilderWatchTime    = [datetime]::Now

                # The indexer setter is thread-safe on ConcurrentDictionary (equivalent to TryAddInternal
                # with updateIfExists: true). It overwrites the stored ChangeType with the latest value,
                # so a sequence like Created => Deleted is always recorded as Deleted. AddOrUpdate() with
                # a delegate is not used because .NET invokes the delegate on a thread-pool thread without
                # a PowerShell runspace, which would cause a runtime error.
                $Global:_PSScriptBuilderWatchFiles[$filePath] = $changeType
            }

            foreach ($eventName in [PSScriptBuilderProjectWatcher]::WatchEventNames) {
                $id = "$($this.EventPrefix)_${index}_${eventName}"

                $eventParams = @{
                    InputObject      = $watcher
                    EventName        = $eventName
                    SourceIdentifier = $id
                    MessageData      = $this.OutputPath
                    Action           = $eventAction
                }

                $job = Register-ObjectEvent @eventParams
                $this.EventJobs.Add($job)
            }

            $this.Watchers.Add($watcher)
            $index++
        }

        Write-Verbose "Watchers registered: $($this.Watchers.Count) watcher(s), $($this.EventJobs.Count) event subscription(s)."
    }

    <#
    .SYNOPSIS
        Runs the main watch loop.
    .DESCRIPTION
        The RunLoop() method blocks the current thread and continuously checks for pending file system
        changes. When a change is detected and the debounce period has elapsed, it triggers a build.
        Changes that arrive during a running build bypass the debounce period and trigger immediately
        after the current build completes.
    #>
    hidden [void] RunLoop() {
        while ($true) {
            Start-Sleep -Milliseconds 100

            if (-not $Global:_PSScriptBuilderWatchPending) {
                continue
            }

            $elapsed = ([datetime]::Now - $Global:_PSScriptBuilderWatchTime).TotalMilliseconds

            if ($elapsed -lt $this.Debounce) {
                continue
            }

            $Global:_PSScriptBuilderWatchPending = $false

            # Snapshot strategy: capture the current dictionary reference, then replace the global
            # with a new empty instance before processing. This avoids a race condition where .Clear()
            # would discard events arriving during the build. Events that arrive after the swap are
            # safely written to the new dictionary and processed in the next cycle.
            $watchFiles   = $Global:_PSScriptBuilderWatchFiles
            $changedFiles = @($watchFiles.Keys)
            $Global:_PSScriptBuilderWatchFiles = [ConcurrentDictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)

            $count = $changedFiles.Count
            Write-Host "[$($this.GetTimestamp())] $count change(s) detected."

            foreach ($keyValuePair in $watchFiles.GetEnumerator()) {
                Write-Host "[$($this.GetTimestamp())]   $($keyValuePair.Key) ($($keyValuePair.Value))"
            }

            if ($null -ne $this.ScriptBlock) {
                Write-Host "[$($this.GetTimestamp())] Executing ScriptBlock."
                $this.ExecuteScriptBlock($changedFiles)
            }
            else {
                Write-Host "[$($this.GetTimestamp())] Executing build."
                $this.RunBuild($changedFiles)
            }

            # If new changes arrived during the build or script, bypass debounce and trigger immediately
            if ($Global:_PSScriptBuilderWatchPending) {
                $Global:_PSScriptBuilderWatchTime = [datetime]::MinValue
            }
        }
    }

    <#
    .SYNOPSIS
        Coordinates a single build cycle.
    .DESCRIPTION
        The RunBuild() method orchestrates a single build cycle by delegating to ExecuteBuild(),
        WriteBuildResult(), and ExecuteOnSuccess() in sequence. Returns immediately if the build failed.
    .PARAMETER changedFiles
        The absolute paths of the files that triggered the current build cycle.
    #>
    hidden [void] RunBuild([string[]] $changedFiles) {
        $result = $this.ExecuteBuild($changedFiles)

        if ($null -eq $result) {
            return
        }

        $this.WriteBuildResult($result)
        $this.ExecuteOnSuccess($result)
    }

    <#
    .SYNOPSIS
        Executes the build pipeline.
    .DESCRIPTION
        The ExecuteBuild() method creates a new PSScriptBuilderBuildOrchestrator and runs the build
        pipeline. Returns the build result on success, or null if the build failed. Build failures
        are reported without stopping the watcher.
    .OUTPUTS
        Returns a PSScriptBuilderBuildResult on success, or null on failure.
    .PARAMETER changedFiles
        The absolute paths of the files that triggered the current build cycle.
    #>
    hidden [PSScriptBuilderBuildResult] ExecuteBuild([string[]] $changedFiles) {
        try {
            $orchestrator = [PSScriptBuilderBuildOrchestrator]::new(
                $this.ContentCollector,
                $this.TemplatePath,
                $this.OutputPath,
                $this.BackupPath,
                $this.OrderedComponentsKey,
                $this.EnableBackup,
                (-not $this.SkipSyntaxValidation)
            )

            return $orchestrator.ExecuteBuild()
        }
        catch {
            Write-Host "[$($this.GetTimestamp())] Build failed: $($_.Exception.Message)" -ForegroundColor Red
            $this.ExecuteOnError($changedFiles, $_.Exception)
            return $null
        }
    }

    <#
    .SYNOPSIS
        Writes the build result summary to the host.
    .DESCRIPTION
        The WriteBuildResult() method formats and outputs a multi-line build summary, oriented on
        the output format of Format-PSScriptBuilderBuildResult. The label column width is calculated
        dynamically from the longest label of non-zero component counts. Component counts are
        right-aligned to the width of the largest value.
    .PARAMETER result
        The PSScriptBuilderBuildResult returned by a successful build.
    #>
    hidden [void] WriteBuildResult([PSScriptBuilderBuildResult] $result) {
        $timestamp       = $this.GetTimestamp()
        $milliseconds    = [int] $result.ExecutionTime.TotalMilliseconds
        $kilobytes       = [math]::Round($result.OutputFileSize / 1KB, 1)
        $componentCounts = $result.ComponentCounts

        if ($result.SyntaxValid) {
            $syntax = 'valid'
        }
        else {
            $syntax = 'invalid'
        }

        $items = [List[PSCustomObject]]::new()
        if ($componentCounts.UsingStatements     -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Using';     Value = $componentCounts.UsingStatements })     }
        if ($componentCounts.EnumDefinitions     -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Enums';     Value = $componentCounts.EnumDefinitions })     }
        if ($componentCounts.ClassDefinitions    -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Classes';   Value = $componentCounts.ClassDefinitions })    }
        if ($componentCounts.FunctionDefinitions -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Functions'; Value = $componentCounts.FunctionDefinitions }) }
        if ($componentCounts.FileContents        -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Files';     Value = $componentCounts.FileContents })        }

        $maxLabel = ($items | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum
        $maxValue = "$($result.TotalComponents)".Length

        Write-Host "[$timestamp] Build succeeded. ($($milliseconds)ms)"
        Write-Host "[$timestamp]   $('Output'.PadRight($maxLabel)) : $($result.OutputPath) ($($kilobytes) KB)"

        foreach ($item in $items) {
            Write-Host "[$timestamp]   $($item.Label.PadRight($maxLabel)) : $("$($item.Value)".PadLeft($maxValue))"
        }

        Write-Host "[$timestamp]   $('Total'.PadRight($maxLabel)) : $("$($result.TotalComponents)".PadLeft($maxValue))"
        Write-Host "[$timestamp]   $('Syntax'.PadRight($maxLabel)) : $syntax"
    }

    <#
    .SYNOPSIS
        Invokes the optional OnSuccess script block after a successful build.
    .DESCRIPTION
        The ExecuteOnSuccess() method calls the OnSuccess script block with the build result as its
        first argument. Does nothing if no OnSuccess was provided. Errors in the script block are
        caught and reported without stopping the watcher.
    .PARAMETER result
        The PSScriptBuilderBuildResult to pass to the OnSuccess script block.
    #>
    hidden [void] ExecuteOnSuccess([PSScriptBuilderBuildResult] $result) {
        if ($null -eq $this.OnSuccess) { return }

        try {
            & $this.OnSuccess $result
        }
        catch {
            Write-Host "[$($this.GetTimestamp())] OnSuccess failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    <#
    .SYNOPSIS
        Invokes the optional OnError script block after a failed build.
    .DESCRIPTION
        The ExecuteOnError() method creates a PSScriptBuilderWatchBuildErrorResult and calls the
        OnError script block with it as its first argument. Does nothing if no OnError was provided.
        Errors in the script block are caught and reported without stopping the watcher.
    .PARAMETER changedFiles
        The absolute paths of the files that triggered the failed build.
    .PARAMETER exception
        The exception that caused the build failure.
    #>
    hidden [void] ExecuteOnError([string[]] $changedFiles, [Exception] $exception) {
        if ($null -eq $this.OnError) { return }

        $errorResult = [PSScriptBuilderWatchBuildErrorResult]::new($exception, $changedFiles, [datetime]::Now)

        try {
            & $this.OnError $errorResult
        }
        catch {
            Write-Host "[$($this.GetTimestamp())] OnError failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    <#
    .SYNOPSIS
        Executes the user-provided script block.
    .DESCRIPTION
        The ExecuteScriptBlock() method invokes the ScriptBlock with the changed file paths as a
        string array. Errors are caught and reported without stopping the watcher.
    .PARAMETER changedFiles
        The absolute paths of the files that triggered the current execution cycle.
    #>
    hidden [void] ExecuteScriptBlock([string[]] $changedFiles) {
        try {
            & $this.ScriptBlock $changedFiles
        }
        catch {
            Write-Host "[$($this.GetTimestamp())] ScriptBlock failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    <#
    .SYNOPSIS
        Collects all paths to watch.
    .DESCRIPTION
        The GetWatchPaths() method derives the set of directories to monitor from the IncludePaths
        of all registered collectors in the ContentCollector snapshot, and adds the directory
        containing the template file. Duplicate paths are excluded.
    .OUTPUTS
        Returns a string array of unique absolute directory paths to watch.
    #>
    hidden [string[]] GetWatchPaths() {
        $paths = [List[string]]::new()

        foreach ($collector in $this.ContentCollector.GetCollectors()) {
            foreach ($includePath in $collector.IncludePaths) {
                $resolved = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($includePath)

                if (-not $paths.Contains($resolved)) {
                    $paths.Add($resolved)
                }
            }
        }

        if (-not [string]::IsNullOrEmpty($this.TemplatePath)) {
            $templateDir = [Path]::GetDirectoryName($this.TemplatePath)

            if (-not [string]::IsNullOrEmpty($templateDir) -and -not $paths.Contains($templateDir)) {
                $paths.Add($templateDir)
            }
        }

        return $paths.ToArray()
    }

    <#
    .SYNOPSIS
        Returns the current time formatted as HH:mm:ss.
    .DESCRIPTION
        The GetTimestamp() method returns the current local time as a string in HH:mm:ss format,
        used as a prefix for all console output lines.
    .OUTPUTS
        Returns a string in HH:mm:ss format.
    #>
    hidden [string] GetTimestamp() {
        return [datetime]::Now.ToString('HH:mm:ss')
    }

    <#
    .SYNOPSIS
        Cleans up all watchers and event subscriptions.
    .DESCRIPTION
        The Cleanup() method unregisters all PowerShell event subscriptions, removes associated
        background jobs, disables and disposes all FileSystemWatcher instances, and clears the
        global debounce state variables. Called automatically via the finally block in Start().
    #>
    hidden [void] Cleanup() {
        foreach ($job in $this.EventJobs) {
            Unregister-Event -SourceIdentifier $job.Name -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }

        foreach ($watcher in $this.Watchers) {
            $watcher.EnableRaisingEvents = $false
            $watcher.Dispose()
        }

        $Global:_PSScriptBuilderWatchPending           = $null
        $Global:_PSScriptBuilderWatchTime              = $null
        $Global:_PSScriptBuilderWatchFiles             = $null
        $Global:_PSScriptBuilderWatchIncludeExtensions = $null
        $Global:_PSScriptBuilderWatchTemplatePath      = $null

        Write-Host "[$($this.GetTimestamp())] Watcher stopped."
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderProjectWatcher
