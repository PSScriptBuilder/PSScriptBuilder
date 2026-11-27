using namespace System.Collections.Generic

#region Cmdlet Format-PSScriptBuilderSourceCoverage
function Format-PSScriptBuilderSourceCoverage {
    <#
    .SYNOPSIS
        Formats and displays per-source-file code coverage results.
    .DESCRIPTION
        The Format-PSScriptBuilderSourceCoverage cmdlet takes one or more
        PSScriptBuilderSourceCoverageResult objects, as returned by
        Get-PSScriptBuilderSourceCoverage, and displays them as an aligned table showing
        each source file's coverage percentage and hit/total command count. SourceFile is
        shown relative to the project root (falling back to the original path for files
        outside it, e.g. a collector IncludePath pointed at a network share).

        By default, displays only the summary table. Use -Detailed to additionally list, beneath
        each file's row, every distinct source line not covered by any test - consecutive lines
        are collapsed into a single range (e.g. "uncovered: lines 12-14, 20"), and a file with
        0% coverage shows "uncovered: entire file" instead of enumerating every line. Long lists
        wrap at a fixed width with a hanging indent.
    .PARAMETER CoverageResult
        A PSScriptBuilderSourceCoverageResult object, as returned by
        Get-PSScriptBuilderSourceCoverage. Accepts pipeline input; all piped objects are
        collected and rendered together as a single aligned table.
    .PARAMETER Detailed
        When specified, lists the source lines not covered by any test beneath its file's row,
        with consecutive lines collapsed into a range. Without this switch, only the summary
        table is shown.
    .OUTPUTS
        None
    .EXAMPLE
        $buildResult | Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
            Format-PSScriptBuilderSourceCoverage

        Displays a compact coverage table, one row per source file.
    .EXAMPLE
        $coverage | Format-PSScriptBuilderSourceCoverage -Detailed

        Displays the coverage table together with the source lines not covered per file.
    .NOTES
        This cmdlet displays coverage results using Write-Host. It does not return any values.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderSourceCoverageResult] $CoverageResult,

        [Parameter()]
        [switch] $Detailed
    )

    begin {
        $collected = [List[PSScriptBuilderSourceCoverageResult]]::new()
    }

    process {
        $collected.Add($CoverageResult)
    }

    end {
        if ($collected.Count -eq 0) {
            Write-Host "No coverage results to display."
            return
        }

        # Project-relative paths are shorter and match how other coverage tools display file
        # paths (coverage.py, nyc); falls back to the original absolute path for files outside
        # the project (e.g. a collector IncludePath pointed at a network share), which
        # GetProjectRelativePath already handles - it returns the input unchanged in that case.
        #
        # Column widths must account for both the data and the header word itself - PadRight/
        # PadLeft never truncate, so if every SourceFile were shorter than the word
        # "SourceFile" (10 chars), the header would overflow a width computed from data alone.
        #
        # @() around each ForEach-Object result is required, not cosmetic: PowerShell unwraps
        # a single-item pipeline result to a bare scalar. With exactly one coverage result,
        # $fileTexts would otherwise be a plain string, and "$fileTexts + 'SourceFile'" would
        # silently become string concatenation ("a.ps1" + "SourceFile") instead of array
        # concatenation - producing one 15-character "item" instead of two items to compare.
        $fileTexts     = @($collected | ForEach-Object { [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($_.SourceFile) })
        $maxFileLength = ($fileTexts + 'SourceFile' | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

        # Hit/Total is unbounded (unlike CoveragePercent, which is always 0-100 and therefore
        # fits a fixed width) - compute its width from the actual data, same as SourceFile,
        # so large command counts (e.g. "12345/12345") don't overflow a hardcoded column width.
        $ratioTexts     = @($collected | ForEach-Object { "$($_.HitCommands)/$($_.TotalCommands)" })
        $maxRatioLength = ($ratioTexts + 'Hit/Total' | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

        $fileHeader  = 'SourceFile'.PadRight($maxFileLength)
        $ratioHeader = 'Hit/Total'.PadLeft($maxRatioLength)

        Write-Host ""
        Write-Host "$fileHeader  Coverage  $ratioHeader"
        Write-Host "$('-' * $maxFileLength)  --------  $('-' * $maxRatioLength)"

        foreach ($result in $collected) {
            $displayPath = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($result.SourceFile)
            $percentText = "{0,6:N1} %" -f $result.CoveragePercent
            $ratioText   = "$($result.HitCommands)/$($result.TotalCommands)"

            Write-Host "$($displayPath.PadRight($maxFileLength))  $percentText  $($ratioText.PadLeft($maxRatioLength))"

            if ($Detailed -and $result.MissedLocations.Count -gt 0) {
                # At 0% coverage, enumerating lines would always be "the entire file" - no
                # partial hit/miss distinction exists, so the list adds nothing the Coverage
                # column doesn't already say.
                if ($result.HitCommands -eq 0) {
                    Write-Host "  uncovered: entire file"
                }
                else {
                    # Pester tracks coverage per AST command, not per line - a single source
                    # line with several commands (e.g. a pipeline inside a subexpression)
                    # produces one MissedLocations entry per command, all sharing the same
                    # SourceLineNumber. Deduplicate and group consecutive lines into ranges
                    # (e.g. "12-14") for a readable summary; MissedCommands/
                    # MissedLocations.Count must stay command-accurate for the coverage
                    # percentage, so this is display-only.
                    $lineNumbers = @($result.MissedLocations |
                        Select-Object -ExpandProperty SourceLineNumber -Unique |
                        Sort-Object)

                    $ranges     = [List[string]]::new()
                    $rangeStart = $lineNumbers[0]
                    $rangeEnd   = $lineNumbers[0]

                    for ($i = 1; $i -lt $lineNumbers.Count; $i++) {
                        if ($lineNumbers[$i] -eq ($rangeEnd + 1)) {
                            $rangeEnd = $lineNumbers[$i]
                            continue
                        }

                        if ($rangeStart -eq $rangeEnd) {
                            $ranges.Add("$rangeStart")
                        }
                        else {
                            $ranges.Add("$rangeStart-$rangeEnd")
                        }

                        $rangeStart = $lineNumbers[$i]
                        $rangeEnd   = $lineNumbers[$i]
                    }

                    if ($rangeStart -eq $rangeEnd) {
                        $ranges.Add("$rangeStart")
                    }
                    else {
                        $ranges.Add("$rangeStart-$rangeEnd")
                    }

                    if ($lineNumbers.Count -eq 1) {
                        $label = 'line'
                    }
                    else {
                        $label = 'lines'
                    }

                    # Wrap at a fixed width (not the actual console width, so output stays
                    # deterministic/testable) with a hanging indent aligned under the "l" of
                    # "line(s)" - that column position is the same for both words, since they
                    # differ only at the end, so a single constant indent covers both cases.
                    # Continuation lines don't repeat "line(s)": this cmdlet only writes to
                    # Write-Host for interactive display, never for machine parsing, so nothing
                    # depends on every line being independently self-describing.
                    $maxWidth           = 80
                    $continuationIndent = ' ' * 13

                    $outputLines = [List[string]]::new()
                    $currentLine = "  uncovered: $label $($ranges[0])"

                    for ($i = 1; $i -lt $ranges.Count; $i++) {
                        $candidate = "$currentLine, $($ranges[$i])"

                        if ($candidate.Length -gt $maxWidth) {
                            $outputLines.Add("$currentLine,")
                            $currentLine = "$continuationIndent$($ranges[$i])"
                        }
                        else {
                            $currentLine = $candidate
                        }
                    }

                    $outputLines.Add($currentLine)

                    foreach ($outputLine in $outputLines) {
                        Write-Host $outputLine
                    }
                }
            }
        }

        Write-Host ""
    }
}
#endregion Cmdlet Format-PSScriptBuilderSourceCoverage
