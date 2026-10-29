using namespace System

#region Class PSScriptBuilderSourceMapData
<#
.SYNOPSIS
    Represents the complete deserialized content of a source map sidecar file.
.DESCRIPTION
    The PSScriptBuilderSourceMapData class holds all fields read from a .sourcemap.json
    sidecar file: the output script path, its SHA-256 hash at build time, the total line
    count, and the component location entries.
    It is returned by PSScriptBuilderSourceMapFileManager.ReadSourceMapData() and consumed
    by PSScriptBuilderSourceLocationResolver to resolve output line numbers back to source.
#>
class PSScriptBuilderSourceMapData {
    #region Properties
    <#
    .SYNOPSIS
        The absolute path to the output script at the time the source map was created.
    .DESCRIPTION
        Stored in the sidecar file for informational purposes. Not used for staleness detection.
    #>
    [string] $OutputPath

    <#
    .SYNOPSIS
        The SHA-256 hash of the output script at the time the source map was created.
    .DESCRIPTION
        Used to detect whether the output script has changed since the source map was written.
    #>
    [string] $OutputHash

    <#
    .SYNOPSIS
        The total number of lines in the output script at the time the source map was created.
    .DESCRIPTION
        Used by PSScriptBuilderSourceLocationResolver to reject line numbers that exceed the
        output file length.
    #>
    [int] $OutputLineCount

    <#
    .SYNOPSIS
        The source location entries read from the sidecar file.
    .DESCRIPTION
        Each entry maps a component's first output line number back to its source file and
        line number. Passed to PSScriptBuilderSourceLocationResolver for resolution.
    #>
    [PSScriptBuilderSourceLocation[]] $Components
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new PSScriptBuilderSourceMapData with all sidecar fields.
    .DESCRIPTION
        Called by PSScriptBuilderSourceMapFileManager.ReadSourceMapData() after
        deserializing the sidecar JSON.
    .PARAMETER outputPath
        The absolute path to the output script.
    .PARAMETER outputHash
        The SHA-256 hash of the output script at build time.
    .PARAMETER outputLineCount
        The total number of lines in the output script.
    .PARAMETER components
        The source location entries from the sidecar file.
    #>
    PSScriptBuilderSourceMapData(
        [string]                          $outputPath,
        [string]                          $outputHash,
        [int]                             $outputLineCount,
        [PSScriptBuilderSourceLocation[]] $components
    ) {
        $this.OutputPath      = $outputPath
        $this.OutputHash      = $outputHash
        $this.OutputLineCount = $outputLineCount
        $this.Components      = $components
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderSourceMapData
