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
        ComponentLineCount is the number of lines in sourceCode, not counting a single trailing
        line break (File components are read verbatim and usually end with one).
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

        $componentLineCount = [PSScriptBuilderSourceMapGenerator]::CountLines($sourceCode)

        $result.Add([PSScriptBuilderSourceLocation]::new(
            $componentName,
            $componentType,
            $sourceFile,
            $componentLineNumber,
            $componentLineNumber,
            $outputLineNumber,
            0,
            $componentLineCount
        ))

        Write-Verbose "  Mapped '$componentName' ($componentType): source line $componentLineNumber -> output line $outputLineNumber ($componentLineCount line(s))"
    }

    <#
    .SYNOPSIS
        Finds the 1-based line number of the first occurrence of content in script.
    .DESCRIPTION
        The FindLine method searches for content in script using an ordinal string comparison
        and returns the 1-based line number of the match. Returns 0 if content is not found.
        Lines are counted with CountLineBreaks, so the result matches the line numbers
        PowerShell reports for the output script.
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

        $prefix     = $script.Substring(0, $matchIndex)
        $lineNumber = [PSScriptBuilderSourceMapGenerator]::CountLineBreaks($prefix) + 1
        return $lineNumber
    }

    <#
    .SYNOPSIS
        Counts the line breaks in text the way PowerShell's parser does.
    .DESCRIPTION
        The CountLineBreaks method counts CRLF, CR and LF as one line break each - the same
        definition PowerShell uses for InvocationInfo.ScriptLineNumber and AST extents, so
        output line numbers in the source map match the line numbers PowerShell reports.
    .PARAMETER text
        The text to count line breaks in.
    .OUTPUTS
        Returns the number of line breaks as int.
    #>
    static hidden [int] CountLineBreaks([string] $text) {
        # Literal CR/LF on purpose: this recognizes line endings in existing text, it does not
        # produce them, so [Environment]::NewLine would be wrong here.
        $normalizedText    = $text.Replace("`r`n", "`n").Replace("`r", "`n")
        $textWithoutBreaks = $normalizedText.Replace("`n", '')

        # Each remaining LF is exactly one line break, so removing them all shortens the text by their count
        $lineBreakCount = $normalizedText.Length - $textWithoutBreaks.Length
        return $lineBreakCount
    }

    <#
    .SYNOPSIS
        Counts the lines of text the way PowerShell's parser does.
    .DESCRIPTION
        The CountLines method returns the number of lines in text, using the line break
        definition of CountLineBreaks. A single trailing line break ends the last line and does
        not start a new one, so "a`nb`n" counts as two lines. Empty text counts as one line.
    .PARAMETER text
        The text to count lines in.
    .OUTPUTS
        Returns the number of lines as int.
    #>
    static hidden [int] CountLines([string] $text) {
        $lineBreakCount    = [PSScriptBuilderSourceMapGenerator]::CountLineBreaks($text)
        $endsWithLineBreak = $text.EndsWith("`n", [StringComparison]::Ordinal) -or $text.EndsWith("`r", [StringComparison]::Ordinal)

        # A trailing line break ends the last line, it does not start a new one
        $lineCount = $lineBreakCount + 1
        if ($endsWithLineBreak) {
            $lineCount = $lineBreakCount
        }

        return $lineCount
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderSourceMapGenerator
