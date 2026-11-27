using namespace System
using namespace System.IO
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

    <#
    .SYNOPSIS
        The SHA256 hash of the output script the source map was created for.
    .DESCRIPTION
        Used by Resolve([ErrorRecord], [string]) to recognize an unmodified copy of the output
        script at a different path as the mapped output.
    #>
    hidden [string] $OutputHash
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes the resolver from a deserialized source map data object.
    .DESCRIPTION
        The constructor sorts the component entries by OutputLineNumber ascending and stores
        the total output line count for upper-bound validation in Resolve(), as well as the
        output hash for the origin check in Resolve([ErrorRecord], [string]).
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
        $this.OutputHash       = $sourceMapData.OutputHash
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
        than or equal to lineNumber and whose extent still covers lineNumber, then computes
        the offset within that component and returns a new PSScriptBuilderSourceLocation with
        the exact source file line.
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
        The Resolve method first verifies that the error originated in the mapped output
        script, then extracts the script line number from the ErrorRecord's InvocationInfo
        and delegates to Resolve([int]).

        The error counts as originating in the output script if InvocationInfo.ScriptName
        refers to outputPath, or to a file with the same content as the output script the
        source map was created for (e.g. an unmodified copy). Otherwise - including errors
        without a script file, e.g. raised interactively or via Invoke-Expression - a
        warning is emitted and $null is returned instead of mapping an unrelated line number.
    .PARAMETER errorRecord
        The ErrorRecord from a caught exception. Must have a non-null InvocationInfo
        with a valid ScriptLineNumber.
    .PARAMETER outputPath
        The absolute path to the output script the source map belongs to.
    .OUTPUTS
        Returns the resolved source location as PSScriptBuilderSourceLocation, or $null
        if the error did not originate in the output script or the line is not covered by
        any tracked component.
    #>
    [PSScriptBuilderSourceLocation] Resolve([ErrorRecord] $errorRecord, [string] $outputPath) {
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

        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $message = "Parameter 'outputPath' cannot be null or empty."
            throw [ArgumentException]::new($message, "outputPath")
        }

        $scriptName = $errorRecord.InvocationInfo.ScriptName
        $lineNumber = $errorRecord.InvocationInfo.ScriptLineNumber

        $origin = $this.CheckErrorOrigin($scriptName, $outputPath, $lineNumber)
        if (-not $origin.IsFromMappedOutput) {
            Write-Warning $origin.MismatchMessage
            return $null
        }

        $location = $this.Resolve($lineNumber)
        return $location
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
        OutputLineNumber is less than or equal to lineNumber, rejects lines beyond that
        entry's ComponentLineCount (when known), and computes the resolved location. Purely a lookup - has no side effects, so it is safe to call from contexts
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

        # ComponentLineCount 0 means unknown (source map written by an earlier version):
        # the component then extends to the start of the next one, as before.
        if ($found.ComponentLineCount -gt 0) {
            $lastComponentLine = $found.OutputLineNumber + $found.ComponentLineCount - 1
            if ($lineNumber -gt $lastComponentLine) {
                return $null
            }
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
            $offset,
            $found.ComponentLineCount
        )
    }

    <#
    .SYNOPSIS
        Checks whether a file has the same content as the mapped output script.
    .DESCRIPTION
        Compares the SHA256 hash of the file at path with the output hash stored in the
        source map. Returns $false if no output hash is known or the file does not exist.
        Throws IOException or UnauthorizedAccessException if the file exists but cannot be
        read - these are deliberately not caught here, so the caller can report them.
    .PARAMETER path
        The path to the file to compare.
    .OUTPUTS
        Returns $true if the file content matches the mapped output script, $false otherwise.
    #>
    hidden [bool] IsMappedOutputContent([string] $path) {
        if ([string]::IsNullOrWhiteSpace($this.OutputHash) -or -not [File]::Exists($path)) {
            return $false
        }

        $hash          = [PSScriptBuilderFileIOHelper]::ComputeSHA256Hash($path)
        $isSameContent = ($hash -eq $this.OutputHash)
        return $isSameContent
    }

    <#
    .SYNOPSIS
        Checks whether an error originated in the mapped output script.
    .DESCRIPTION
        The CheckErrorOrigin method applies the origin rule of Resolve([ErrorRecord], [string]):
        the error's script file counts as the output script if it is outputPath, or a file with
        the same content as the output script the source map was created for (e.g. an unmodified
        copy). An empty scriptName (error raised interactively or via Invoke-Expression) never
        counts as the output script. Emits no warning itself - the caller reports the result's
        MismatchMessage.
    .PARAMETER scriptName
        The script file the error originated in (InvocationInfo.ScriptName).
    .PARAMETER outputPath
        The absolute path to the output script the source map belongs to.
    .PARAMETER lineNumber
        The line number of the error, used in the message's -LineNumber hint.
    .OUTPUTS
        Returns the outcome as PSScriptBuilderErrorOriginCheckResult, including the warning
        message if the error did not originate in the output script.
    #>
    hidden [PSScriptBuilderErrorOriginCheckResult] CheckErrorOrigin([string] $scriptName, [string] $outputPath, [int] $lineNumber) {
        if ([string]::IsNullOrWhiteSpace($scriptName)) {
            $format          = "The error has no script file origin (e.g. raised interactively or via Invoke-Expression), " +
                               "so it cannot be verified to come from the output script '{0}'. No source location found. " +
                               "If the output script was loaded via Invoke-Expression, use -LineNumber {1} instead."
            $mismatchMessage = $format -f $outputPath, $lineNumber
            return [PSScriptBuilderErrorOriginCheckResult]::NotFromMappedOutput($mismatchMessage)
        }

        $isSamePath = ([Path]::GetFullPath($scriptName) -eq [Path]::GetFullPath($outputPath))
        if ($isSamePath) {
            return [PSScriptBuilderErrorOriginCheckResult]::FromMappedOutput()
        }

        $isSameContent = $false
        $compareError  = $null
        try {
            $isSameContent = $this.IsMappedOutputContent($scriptName)
        }
        catch [IOException], [UnauthorizedAccessException] {
            $compareError = $_.Exception.Message
        }

        if ($null -ne $compareError) {
            $format          = "The error originated in '{0}', not in the output script '{1}', and its content could not be " +
                               "compared with the output script ({3}). No source location found. " +
                               "If '{0}' is an unmodified copy of the output script, use -LineNumber {2} instead."
            $mismatchMessage = $format -f $scriptName, $outputPath, $lineNumber, $compareError
            return [PSScriptBuilderErrorOriginCheckResult]::NotFromMappedOutput($mismatchMessage)
        }

        if (-not $isSameContent) {
            $format          = "The error originated in '{0}', not in the output script '{1}'. No source location found. " +
                               "If '{0}' is a modified copy of the output script, line numbers may differ - use -LineNumber {2} only if they match."
            $mismatchMessage = $format -f $scriptName, $outputPath, $lineNumber
            return [PSScriptBuilderErrorOriginCheckResult]::NotFromMappedOutput($mismatchMessage)
        }

        Write-Verbose "'$scriptName' differs from the output path but matches the mapped output script by content."
        return [PSScriptBuilderErrorOriginCheckResult]::FromMappedOutput()
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderSourceLocationResolver
