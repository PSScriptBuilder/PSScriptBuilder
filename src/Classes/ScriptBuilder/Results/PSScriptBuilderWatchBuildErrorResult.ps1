using namespace System

#region Class PSScriptBuilderWatchBuildErrorResult
<#
.SYNOPSIS
    Represents a build error that occurred during a watched build operation.
.DESCRIPTION
    The PSScriptBuilderWatchBuildErrorResult class encapsulates information about a build failure
    that occurred during a file watcher session, including the exception, the files that triggered
    the build, and the timestamp of the failure. This object is passed to the OnError callback.
#>
class PSScriptBuilderWatchBuildErrorResult {
    #region Properties
    <#
    .SYNOPSIS
        The exception that caused the build failure.
    .DESCRIPTION
        The Exception property holds the exception that was thrown during the build operation.
    #>
    [Exception] $Exception

    <#
    .SYNOPSIS
        The files that triggered the failed build.
    .DESCRIPTION
        The ChangedFiles property contains the paths of the files whose changes triggered the
        build operation that subsequently failed.
    #>
    [string[]] $ChangedFiles

    <#
    .SYNOPSIS
        The timestamp of the build failure.
    .DESCRIPTION
        The Timestamp property holds the date and time at which the build failure occurred.
    #>
    [datetime] $Timestamp
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderWatchBuildErrorResult.
    .DESCRIPTION
        Creates a new PSScriptBuilderWatchBuildErrorResult with the specified error information.
    .PARAMETER exception
        The exception that caused the build failure.
    .PARAMETER changedFiles
        The paths of the files that triggered the failed build.
    .PARAMETER timestamp
        The date and time at which the build failure occurred.
    #>
    PSScriptBuilderWatchBuildErrorResult(
        [Exception] $exception,
        [string[]]  $changedFiles,
        [datetime]  $timestamp
    ) {
        $this.Exception     = $exception
        $this.ChangedFiles  = $changedFiles
        $this.Timestamp     = $timestamp
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderWatchBuildErrorResult
