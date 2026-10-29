using namespace System
using namespace System.Management.Automation

#region Class PSScriptBuilderSourceLocationResolver
<#
.SYNOPSIS
    Resolves output script line numbers back to their source file locations.
.DESCRIPTION
    The PSScriptBuilderSourceLocationResolver class accepts a PSScriptBuilderSourceMapData
    instance returned by PSScriptBuilderSourceMapFileManager.ReadSourceMapData() and provides
    methods to resolve a line number or ErrorRecord from the built output script back to the
    originating source file and line. The component entries are sorted by OutputLineNumber on
    construction.
#>
class PSScriptBuilderSourceLocationResolver {
    #region Properties
    <#
    .SYNOPSIS
        The source map sorted by OutputLineNumber ascending.
    .DESCRIPTION
        The SourceMap property holds all source location entries produced by
        PSScriptBuilderSourceMapGenerator, sorted by OutputLineNumber for efficient
        linear scan in Resolve(). All entries have Offset=0 at this point.
    #>
    hidden [PSScriptBuilderSourceLocation[]] $SourceMap

    <#
    .SYNOPSIS
        The total number of lines in the output script, or 0 if unknown.
    .DESCRIPTION
        When greater than 0, Resolve() rejects line numbers that exceed the output file length.
    #>
    hidden [int] $TotalOutputLines
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes the resolver from a deserialized source map data object.
    .DESCRIPTION
        The constructor sorts the component entries by OutputLineNumber ascending and stores
        the total output line count for upper-bound validation in Resolve().
    .PARAMETER sourceMapData
        The deserialized sidecar content returned by PSScriptBuilderSourceMapFileManager.ReadSourceMapData().
    #>
    PSScriptBuilderSourceLocationResolver([PSScriptBuilderSourceMapData] $sourceMapData) {
        if ($null -eq $sourceMapData) {
            $message = "Parameter 'sourceMapData' cannot be null."
            throw [ArgumentException]::new($message, "sourceMapData")
        }

        $sorted                = $sourceMapData.Components | Sort-Object -Property OutputLineNumber
        $this.SourceMap        = [PSScriptBuilderSourceLocation[]] $sorted
        $this.TotalOutputLines = $sourceMapData.OutputLineCount
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Returns the full source map.
    .DESCRIPTION
        The GetSourceMap method returns all source location entries. All entries have
        Offset=0 and SourceLineNumber=ComponentLineNumber, as no specific target line
        within a component has been resolved.
    .OUTPUTS
        Returns all source location entries as PSScriptBuilderSourceLocation[].
    #>
    [PSScriptBuilderSourceLocation[]] GetSourceMap() {
        return $this.SourceMap
    }

    <#
    .SYNOPSIS
        Resolves an output script line number to a source file location.
    .DESCRIPTION
        The Resolve method finds the last source map entry whose OutputLineNumber is less
        than or equal to lineNumber, then computes the offset within that component and
        returns a new PSScriptBuilderSourceLocation with the exact source file line.
        Returns $null and emits a warning if no entry covers the given line number.

        Delegates the lookup itself to TryResolve()/FindLocation() - this method's only
        additional responsibility beyond TryResolve() is emitting the appropriate warning
        message on failure.
    .PARAMETER lineNumber
        The 1-based line number in the output script to resolve.
    .OUTPUTS
        Returns the resolved source location as PSScriptBuilderSourceLocation, or $null
        if the line is not covered by any tracked component.
    #>
    [PSScriptBuilderSourceLocation] Resolve([int] $lineNumber) {
        $location = $null
        $resolved = $this.TryResolve($lineNumber, [ref] $location)

        if (-not $resolved) {
            if ($this.TotalOutputLines -gt 0 -and $lineNumber -gt $this.TotalOutputLines) {
                $format  = "Line number {0} exceeds the output file length ({1} lines). No source location found."
                $message = $format -f $lineNumber, $this.TotalOutputLines
            }
            else {
                $format  = "No source location found for line {0}. " +
                           "The line may be in a section not covered by any collector " +
                           "(e.g., a 'using' statement or template boilerplate)."
                $message = $format -f $lineNumber
            }

            Write-Warning $message
        }

        return $location
    }

    <#
    .SYNOPSIS
        Resolves an ErrorRecord to a source file location.
    .DESCRIPTION
        The Resolve method extracts the script line number from the ErrorRecord's
        InvocationInfo and delegates to Resolve([int]).
    .PARAMETER errorRecord
        The ErrorRecord from a caught exception. Must have a non-null InvocationInfo
        with a valid ScriptLineNumber.
    .OUTPUTS
        Returns the resolved source location as PSScriptBuilderSourceLocation, or $null
        if the line is not covered by any tracked component.
    #>
    [PSScriptBuilderSourceLocation] Resolve([ErrorRecord] $errorRecord) {
        if ($null -eq $errorRecord) {
            $message = "Parameter 'errorRecord' cannot be null."
            throw [ArgumentException]::new($message, "errorRecord")
        }

        if ($null -eq $errorRecord.InvocationInfo) {
            $message = "Parameter 'errorRecord' has no InvocationInfo. " +
                       "The error may not have originated from a script file."
            throw [ArgumentException]::new($message, "errorRecord")
        }

        if ($errorRecord.InvocationInfo.ScriptLineNumber -le 0) {
            $message = "Parameter 'errorRecord' InvocationInfo has no valid script line number. " +
                       "The error may not have originated from a script file."
            throw [ArgumentException]::new($message, "errorRecord")
        }

        return $this.Resolve($errorRecord.InvocationInfo.ScriptLineNumber)
    }

    <#
    .SYNOPSIS
        Attempts to resolve an output script line number to a source file location.
    .DESCRIPTION
        The TryResolve method performs the same lookup as Resolve(), but never emits a
        warning for a line that cannot be resolved - it only reports whether resolution
        succeeded. Intended for callers that want to handle and report unresolved lines
        themselves, e.g. PSScriptBuilderCodeCoverageTranslator, which aggregates many
        unresolved lines into a single consolidated warning instead of one per line.
    .PARAMETER lineNumber
        The 1-based line number in the output script to resolve.
    .PARAMETER location
        Output parameter. Set to the resolved PSScriptBuilderSourceLocation on success, or
        $null if the line could not be resolved.
    .OUTPUTS
        Returns $true if the line was resolved, $false otherwise.
    #>
    [bool] TryResolve([int] $lineNumber, [ref] $location) {
        if ($lineNumber -le 0) {
            $message = "Parameter 'lineNumber' must be greater than 0."
            throw [ArgumentException]::new($message, "lineNumber")
        }

        $location.Value = $this.FindLocation($lineNumber)

        $isResolved = ($null -ne $location.Value)
        return $isResolved
    }

    <#
    .SYNOPSIS
        Finds the source location for a line number without emitting any warning.
    .DESCRIPTION
        Shared lookup logic used by both Resolve() and TryResolve(): performs the upper-bound
        check against TotalOutputLines, then a linear scan for the last entry whose
        OutputLineNumber is less than or equal to lineNumber, and computes the resolved
        location. Purely a lookup - has no side effects, so it is safe to call from contexts
        (like a loop over many coverage entries) that want to decide for themselves how to
        report failures instead of one warning per call.
    .PARAMETER lineNumber
        The 1-based line number in the output script to resolve. Assumed already validated
        as greater than 0 by the caller.
    .OUTPUTS
        Returns the resolved PSScriptBuilderSourceLocation, or $null if not found.
    #>
    hidden [PSScriptBuilderSourceLocation] FindLocation([int] $lineNumber) {
        if ($this.TotalOutputLines -gt 0 -and $lineNumber -gt $this.TotalOutputLines) {
            return $null
        }

        $found = $null
        foreach ($entry in $this.SourceMap) {
            if ($entry.OutputLineNumber -le $lineNumber) {
                $found = $entry
            }
            else {
                break
            }
        }

        if ($null -eq $found) {
            return $null
        }

        $offset           = $lineNumber - $found.OutputLineNumber
        $sourceLineNumber = $found.ComponentLineNumber + $offset

        return [PSScriptBuilderSourceLocation]::new(
            $found.ComponentName,
            $found.ComponentType,
            $found.SourceFile,
            $sourceLineNumber,
            $found.ComponentLineNumber,
            $found.OutputLineNumber,
            $offset
        )
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderSourceLocationResolver
