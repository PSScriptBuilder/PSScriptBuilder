#region Cmdlet Watch-PSScriptBuilderProject
function Watch-PSScriptBuilderProject {
    <#
    .SYNOPSIS
        Watches project source files and triggers a build or custom script block on every change.
    .DESCRIPTION
        The Watch-PSScriptBuilderProject cmdlet monitors the source directories of all registered
        collectors and optionally the template file for changes. When a change is detected, it
        either runs a full build (Build mode) or invokes a user-provided script block (Script mode).

        Multiple changes within the debounce window are collapsed into a single execution. Changes
        that arrive during a running build or script are collected and trigger exactly one additional
        execution after the current one completes - without waiting for the debounce period again.

        The watcher runs until stopped with Ctrl+C. Build failures and script errors do not stop the watcher.
    .PARAMETER ContentCollector
        The ContentCollector instance containing all registered collectors.
        Used in both Build and Script mode to derive the directories to watch.
    .PARAMETER TemplatePath
        The path to the template file. When provided, the directory containing this file is added
        to the watched paths. Changes to the template file always trigger a rebuild or script
        execution, regardless of the -IncludeExtension filter.
        Mandatory in Build mode. Optional in Script mode.
        Can be relative (to project root) or absolute.
    .PARAMETER Debounce
        The number of milliseconds to wait after a change before triggering the build or script block.
        Multiple changes within this window are collapsed into a single execution. Default: 500.
    .PARAMETER IncludeExtension
        The file extensions that are allowed to trigger a build or script execution (e.g. '.ps1').
        The template file is always exempt from this filter. Pass an empty array to allow all
        extensions. Applies to both Build and Script mode. Default: @('.ps1').
    .PARAMETER ScriptBlock
        A script block executed instead of a build when running in Script mode. Receives the changed
        file paths as a string array via the first argument. Script mode only.
    .PARAMETER OutputPath
        The path to the output file. Automatically excluded from the watch to prevent rebuild loops.
        Build mode only. Can be relative (to project root) or absolute.
    .PARAMETER BackupPath
        The directory where backup files are stored before overwriting the existing output file.
        Build mode only. Can be relative (to project root) or absolute.
    .PARAMETER OrderedComponentsKey
        The placeholder key in the template that will be replaced with the dependency-ordered
        components. Build mode only. Defaults to "ORDERED_COMPONENTS".
    .PARAMETER EnableBackup
        Enables backup creation of the existing output file before overwriting it. Build mode only.
    .PARAMETER SkipSyntaxValidation
        Skips the syntax validation step after writing the output file. Build mode only.
    .PARAMETER OnSuccess
        An optional script block to execute after each successful build. Receives the
        PSScriptBuilderBuildResult as the first argument. Build mode only.
    .PARAMETER OnError
        An optional script block to execute after each failed build. Receives a
        PSScriptBuilderWatchBuildErrorResult as the first argument. Build mode only.
    .OUTPUTS
        None
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
            Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'
        Watch-PSScriptBuilderProject -ContentCollector $cc `
                                     -TemplatePath     'build\MyModule.psm1.template' `
                                     -OutputPath       'build\Output\MyModule.psm1'

        Watches source directories and rebuilds on every change. Press Ctrl+C to stop.
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
            Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'
        Watch-PSScriptBuilderProject -ContentCollector $cc `
                                     -TemplatePath     'build\MyModule.psm1.template' `
                                     -OutputPath       'build\Output\MyModule.psm1' `
                                     -OnSuccess        { Invoke-Pester -Path 'tests' -Output Minimal }

        Rebuilds on change and runs Pester tests after each successful build.
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
            Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'
        Watch-PSScriptBuilderProject -ContentCollector $cc `
                                     -ScriptBlock      {
                                         param([string[]] $changedFiles)
                                         Write-Host "Changed: $($changedFiles -join ', ')"
                                         & '.\my-build.ps1'
                                     }

        Watches source directories and runs a custom script block on every change.
    .NOTES
        The watcher blocks the current thread until stopped with Ctrl+C. The ContentCollector
        cannot be modified while the watcher is running.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Build')]
    [OutputType([void])]
    param(
        # Watcher (both modes)
        [Parameter(Mandatory, ParameterSetName = 'Build')]
        [Parameter(Mandatory, ParameterSetName = 'Script')]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter(Mandatory, ParameterSetName = 'Build')]
        [Parameter(ParameterSetName = 'Script')]
        [string] $TemplatePath,

        [Parameter(ParameterSetName = 'Build')]
        [Parameter(ParameterSetName = 'Script')]
        [int] $Debounce = 500,

        [Parameter(ParameterSetName = 'Build')]
        [Parameter(ParameterSetName = 'Script')]
        [string[]] $IncludeExtension = @('.ps1'),

        # Script
        [Parameter(Mandatory, ParameterSetName = 'Script')]
        [scriptblock] $ScriptBlock,

        # Build
        [Parameter(Mandatory, ParameterSetName = 'Build')]
        [string] $OutputPath,

        [Parameter(ParameterSetName = 'Build')]
        [string] $BackupPath,

        [Parameter(ParameterSetName = 'Build')]
        [string] $OrderedComponentsKey = 'ORDERED_COMPONENTS',

        [Parameter(ParameterSetName = 'Build')]
        [switch] $EnableBackup,

        [Parameter(ParameterSetName = 'Build')]
        [switch] $SkipSyntaxValidation,

        [Parameter(ParameterSetName = 'Build')]
        [scriptblock] $OnSuccess,

        [Parameter(ParameterSetName = 'Build')]
        [scriptblock] $OnError
    )

    process {
        try {
            $resolvedTemplatePath = ''

            if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
                $resolvedTemplatePath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($TemplatePath)
            }

            if ($PSCmdlet.ParameterSetName -eq 'Build') {
                $resolvedOutputPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($OutputPath)

                $resolvedBackupPath = ''
                if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
                    $resolvedBackupPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($BackupPath)
                }

                $request = [PSScriptBuilderWatchBuildRequest]::new(
                    $ContentCollector,
                    $resolvedTemplatePath,
                    $resolvedOutputPath,
                    $Debounce,
                    $IncludeExtension,
                    $resolvedBackupPath,
                    $OrderedComponentsKey,
                    $EnableBackup.IsPresent,
                    $SkipSyntaxValidation.IsPresent,
                    $OnSuccess,
                    $OnError
                )

                $watcher = [PSScriptBuilderProjectWatcher]::new($request)
            }
            else {
                $request = [PSScriptBuilderWatchScriptRequest]::new(
                    $ContentCollector,
                    $resolvedTemplatePath,
                    $Debounce,
                    $IncludeExtension,
                    $ScriptBlock
                )

                $watcher = [PSScriptBuilderProjectWatcher]::new($request)
            }

            $watcher.Start()
        }
        catch {
            $format  = "Watcher failed. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Watch-PSScriptBuilderProject
