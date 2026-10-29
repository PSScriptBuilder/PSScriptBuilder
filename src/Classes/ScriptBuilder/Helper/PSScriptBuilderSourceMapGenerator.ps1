using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderSourceMapGenerator
<#
.SYNOPSIS
    Generates a source map from a built output script and its content collector.
.DESCRIPTION
    The PSScriptBuilderSourceMapGenerator class locates each collected component
    (enum, class, function, file) within the final built script by searching for its
    source code verbatim, then records the output line number and source file position
    as a PSScriptBuilderSourceLocation entry. The resulting source map is used by
    PSScriptBuilderSourceLocationResolver to map output line numbers back to source files.
#>
class PSScriptBuilderSourceMapGenerator {
    #region Methods
    <#
    .SYNOPSIS
        Creates a source map from the final built script and its content collector.
    .DESCRIPTION
        The CreateSourceMap method iterates all collectors managed by the ContentCollector,
        locates each component in the final script by verbatim string search, and creates a
        PSScriptBuilderSourceLocation entry per component. UsingCollectors are skipped.
        Components not found in the script (no template placeholder match) are omitted and
        a warning is emitted for each missing component.
        The returned array is not sorted — PSScriptBuilderSourceLocationResolver sorts on construction.
    .PARAMETER finalScript
        The complete built output script as a single string.
    .PARAMETER contentCollector
        The ContentCollector that managed all collectors during the build.
    .OUTPUTS
        Returns the generated source map as a PSScriptBuilderSourceLocation array.
    #>
    static [PSScriptBuilderSourceLocation[]] CreateSourceMap([string] $finalScript, [PSScriptBuilderContentCollector] $contentCollector) {
        $result = [List[PSScriptBuilderSourceLocation]]::new()

        Write-Verbose "Generating source map..."

        foreach ($collector in $contentCollector.GetCollectors()) {
            $componentType = [PSScriptBuilderTextHelper]::FormatCollectorType($collector.CollectorType)

            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::EnumCollector) {
                    foreach ($data in $collector.EnumData.Values) {
                        [PSScriptBuilderSourceMapGenerator]::AddEntry(
                            $result,
                            $finalScript,
                            $data.Name,
                            $componentType,
                            $data.SourceFile,
                            $data.SourceCode,
                            $collector.SourceRanges[$data.Name].StartLineNumber
                        )
                    }
                }
                ([PSScriptBuilderCollectorType]::ClassCollector) {
                    foreach ($data in $collector.ClassData.Values) {
                        [PSScriptBuilderSourceMapGenerator]::AddEntry(
                            $result,
                            $finalScript,
                            $data.Name,
                            $componentType,
                            $data.SourceFile,
                            $data.SourceCode,
                            $collector.SourceRanges[$data.Name].StartLineNumber
                        )
                    }
                }
                ([PSScriptBuilderCollectorType]::FunctionCollector) {
                    foreach ($data in $collector.FunctionData.Values) {
                        [PSScriptBuilderSourceMapGenerator]::AddEntry(
                            $result,
                            $finalScript,
                            $data.Name,
                            $componentType,
                            $data.SourceFile,
                            $data.SourceCode,
                            $collector.SourceRanges[$data.Name].StartLineNumber
                        )
                    }
                }
                ([PSScriptBuilderCollectorType]::FileCollector) {
                    foreach ($data in $collector.FileData.Values) {
                        [PSScriptBuilderSourceMapGenerator]::AddEntry(
                            $result,
                            $finalScript,
                            $data.FileName,
                            $componentType,
                            $data.FullPath,
                            $data.Content,
                            $collector.SourceRanges[$data.FileName].StartLineNumber
                        )
                    }
                }
                # UsingCollector: no source location tracking needed
            }
        }

        Write-Verbose "Source map complete: $($result.Count) component(s)"
        return $result.ToArray()
    }

    <#
    .SYNOPSIS
        Adds a source location entry to the result list if the component is found in the script.
    .DESCRIPTION
        The AddEntry method locates the component's source code in the final script, computes
        the output line number, and appends a PSScriptBuilderSourceLocation entry to the result
        list. Silently skips the component if it is not found in the script.
        SourceLineNumber is set equal to ComponentLineNumber (Offset=0) because no specific
        target line within the component is known at build time. PSScriptBuilderSourceLocationResolver
        computes the actual Offset and SourceLineNumber when Resolve() is called.
    .PARAMETER result
        The list to append the new entry to.
    .PARAMETER finalScript
        The complete built output script.
    .PARAMETER componentName
        The name of the component.
    .PARAMETER componentType
        The formatted type string (Enum, Class, Function, or File).
    .PARAMETER sourceFile
        The absolute path to the source file containing the component.
    .PARAMETER sourceCode
        The verbatim source code to locate in the final script.
    .PARAMETER componentLineNumber
        The 1-based line number where the component begins in the source file.
    #>
    static hidden [void] AddEntry(
        [List[PSScriptBuilderSourceLocation]] $result,
        [string] $finalScript,
        [string] $componentName,
        [string] $componentType,
        [string] $sourceFile,
        [string] $sourceCode,
        [int]    $componentLineNumber
    ) {
        $outputLineNumber = [PSScriptBuilderSourceMapGenerator]::FindLine($finalScript, $sourceCode)
        if ($outputLineNumber -eq 0) {
            Write-Warning "Source map: '$componentName' ($componentType) not found in output script and will be missing from the source map."
            return
        }

        $result.Add([PSScriptBuilderSourceLocation]::new(
            $componentName,
            $componentType,
            $sourceFile,
            $componentLineNumber,
            $componentLineNumber,
            $outputLineNumber,
            0
        ))

        Write-Verbose "  Mapped '$componentName' ($componentType): source line $componentLineNumber -> output line $outputLineNumber"
    }

    <#
    .SYNOPSIS
        Finds the 1-based line number of the first occurrence of content in script.
    .DESCRIPTION
        The FindLine method searches for content in script using an ordinal string comparison
        and returns the 1-based line number of the match. Returns 0 if content is not found.
    .PARAMETER script
        The complete output script to search in.
    .PARAMETER content
        The verbatim content to locate.
    .OUTPUTS
        Returns the 1-based line number, or 0 if not found.
    #>
    static hidden [int] FindLine([string] $script, [string] $content) {
        $matchIndex = $script.IndexOf($content, [StringComparison]::Ordinal)
        if ($matchIndex -lt 0) {
            return 0
        }

        $prefix = $script.Substring(0, $matchIndex)
        $lines  = $prefix -split '\r?\n'
        return $lines.Count
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderSourceMapGenerator
