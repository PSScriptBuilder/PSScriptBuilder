Describe 'Format-PSScriptBuilderSourceCoverage' {

    BeforeAll {
        # Isolate from whatever a prior test file may have left set - GetProjectRelativePath
        # falls back to the original absolute path when this is unset, which is what every
        # test below expects unless a Context explicitly sets its own project root.
        $Global:PSScriptBuilderProjectRoot = $null

        Function New-CoverageResult {
            param(
                [string]                          $SourceFile      = 'C:\src\Foo.ps1',
                [int]                              $TotalCommands   = 10,
                [int]                              $HitCommands     = 7,
                [int]                              $MissedCommands  = 3,
                [double]                           $CoveragePercent = 70.0,
                [PSScriptBuilderSourceLocation[]] $MissedLocations = @()
            )
            return [PSScriptBuilderSourceCoverageResult]::new(
                $SourceFile, $TotalCommands, $HitCommands, $MissedCommands, $CoveragePercent, $MissedLocations)
        }

        Function New-MissedLocation {
            param([int] $SourceLineNumber = 42)
            return [PSScriptBuilderSourceLocation]::new(
                'Foo', 'Class', 'C:\src\Foo.ps1', $SourceLineNumber, 1, 1, ($SourceLineNumber - 1))
        }

        <#
        Captures Write-Host output as text via the Information stream (6), which is where
        Write-Host writes since PowerShell 5 - a plain variable assignment does not capture it.

        Deliberately NOT a function wrapping the cmdlet call with its own pipeline parameter:
        an array-typed ValueFromPipeline parameter is invoked once per piped item (verified:
        Count=1 on every call), not once with the full set, which would silently break every
        test that pipes multiple results through in one call. Piping directly into the real
        cmdlet is the only way to exercise its actual begin/process/end accumulation.
        #>
        Function ConvertTo-TextLines {
            param([Parameter(ValueFromPipeline)] $InputObject)
            process { $InputObject.ToString() }
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Empty input' {

        It 'Should display a message when there are no results to show' {
            $output = @() | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'No coverage results to display'
        }
    }

    Context 'Compact output' {

        It 'Should include a header row with column titles' {
            $output = (New-CoverageResult) | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'SourceFile'
            ($output -join "`n") | Should -Match 'Coverage'
            ($output -join "`n") | Should -Match 'Hit/Total'
        }

        It 'Should include the source file path in a data row' {
            $output = (New-CoverageResult -SourceFile 'C:\src\MyThing.ps1') |
                Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match ([regex]::Escape('C:\src\MyThing.ps1'))
        }

        It 'Should include the hit/total ratio in a data row' {
            $output = (New-CoverageResult -HitCommands 4 -TotalCommands 9) |
                Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match '4/9'
        }

        It 'Should not display missed line detail without -Detailed' {
            $result = New-CoverageResult -MissedLocations @(New-MissedLocation -SourceLineNumber 42)
            $output = $result | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'uncovered:'
        }

        It 'Should render one row per result when multiple results are piped in together' {
            $results = @((New-CoverageResult -SourceFile 'C:\src\A.ps1'), (New-CoverageResult -SourceFile 'C:\src\B.ps1'))

            $output = $results | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match ([regex]::Escape('C:\src\A.ps1'))
            ($output -join "`n") | Should -Match ([regex]::Escape('C:\src\B.ps1'))
        }
    }

    Context 'Detailed output' {

        It 'Should display the source line of each missed location with -Detailed' {
            $result = New-CoverageResult -MissedLocations @(New-MissedLocation -SourceLineNumber 42)

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'uncovered:.*42'
        }

        It 'Should display nothing extra with -Detailed when there are no missed locations' {
            $result = New-CoverageResult -MissedLocations @()

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'uncovered:'
        }

        It 'Should list each distinct missed line only once, even when several commands share it' {
            <#
            Pester's CommandsMissed tracks coverage per AST command, not per line - a single
            source line with multiple commands (e.g. a pipeline inside a subexpression) produces
            several MissedLocations entries that all share the same SourceLineNumber. Regression
            for a real report: line 124 appeared four times in -Detailed output.
            #>
            $result = New-CoverageResult -MissedCommands 4 -MissedLocations @(
                (New-MissedLocation -SourceLineNumber 124),
                (New-MissedLocation -SourceLineNumber 124),
                (New-MissedLocation -SourceLineNumber 124),
                (New-MissedLocation -SourceLineNumber 124)
            )

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'uncovered: line 124'
            $notCoveredLines = $output | Where-Object { $_ -match 'uncovered:' }
            @($notCoveredLines).Count | Should -Be 1
        }

        It 'Should use singular "line" for a single distinct missed line' {
            $result = New-CoverageResult -MissedLocations @(New-MissedLocation -SourceLineNumber 42)

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'uncovered: line 42'
            ($output -join "`n") | Should -Not -Match 'uncovered: lines'
        }

        It 'Should list non-consecutive missed lines as a comma-separated list, in ascending order' {
            $result = New-CoverageResult -MissedCommands 3 -MissedLocations @(
                (New-MissedLocation -SourceLineNumber 30),
                (New-MissedLocation -SourceLineNumber 10),
                (New-MissedLocation -SourceLineNumber 20)
            )

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'uncovered: lines 10, 20, 30'
        }

        It 'Should collapse consecutive missed lines into a single range' {
            $result = New-CoverageResult -MissedCommands 3 -MissedLocations @(
                (New-MissedLocation -SourceLineNumber 12),
                (New-MissedLocation -SourceLineNumber 13),
                (New-MissedLocation -SourceLineNumber 14)
            )

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'uncovered: lines 12-14'
        }

        It 'Should mix ranges and single lines in one consolidated line, matching a real multi-gap report' {
            <#
            Regression for a real Get-PSScriptBuilderCollector.ps1 report: several separate
            runs of consecutive missed lines (109-111, 115-117, 121-124, 128-130, 133-135)
            printed as 19 individual lines before consolidation.
            #>
            $lineNumbers = @(109, 110, 111, 115, 116, 117, 121, 122, 123, 124, 128, 129, 130, 133, 134, 135)
            $result = New-CoverageResult -MissedCommands $lineNumbers.Count -MissedLocations @(
                $lineNumbers | ForEach-Object { New-MissedLocation -SourceLineNumber $_ }
            )

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'uncovered: lines 109-111, 115-117, 121-124, 128-130, 133-135'
        }
    }

    Context '0% coverage' {

        It 'Should show "entire file" instead of enumerating lines when HitCommands is 0' {
            <#
            At 0% coverage, every command is missed - enumerating lines would always resolve
            to "the whole file", which the Coverage/Hit-Total columns already say. Listing
            them anyway adds no information, just noise (e.g. hundreds of lines for a large,
            completely untested file).
            #>
            $result = New-CoverageResult -HitCommands 0 -MissedCommands 5 -TotalCommands 5 -CoveragePercent 0.0 -MissedLocations @(
                (New-MissedLocation -SourceLineNumber 10),
                (New-MissedLocation -SourceLineNumber 20)
            )

            $output = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'uncovered: entire file'
            ($output -join "`n") | Should -Not -Match 'uncovered: line(s)? \d'
        }
    }

    Context 'SourceFile path shortening' {

        BeforeAll {
            $script:FakeProjectRoot = 'C:\FakeProject'
            $Global:PSScriptBuilderProjectRoot = $script:FakeProjectRoot
        }

        AfterAll {
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should show the path relative to the project root for a file under it' {
            $result = New-CoverageResult -SourceFile 'C:\FakeProject\src\Public\Get-Foo.ps1'

            $output = $result | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match ([regex]::Escape('src\Public\Get-Foo.ps1'))
            ($output -join "`n") | Should -Not -Match ([regex]::Escape('C:\FakeProject'))
        }

        It 'Should fall back to the original absolute path for a file outside the project root' {
            <#
            A collector's IncludePath can point at an absolute location outside the project
            (e.g. a network share) - GetProjectRelativePath returns such paths unchanged
            rather than throwing or producing a misleading relative path.
            #>
            $result = New-CoverageResult -SourceFile 'Z:\Extern\Get-Foo.ps1'

            $output = $result | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match ([regex]::Escape('Z:\Extern\Get-Foo.ps1'))
        }
    }

    Context 'Line wrapping' {

        It 'Should wrap the uncovered-lines list at 80 characters with a hanging indent' {
            <#
            Regression for a real report (PSScriptBuilderReleaseManagementOrchestrator.ps1,
            47 ranges): a single unwrapped line became unreadable. Continuation lines align
            under the "l" of "line(s)" (13 spaces: "  uncovered: " is 13 characters) rather
            than repeating the word, since this cmdlet is Write-Host-only display, never
            machine-parsed.
            #>
            $lineNumbers = @(
                117, 125, 129, 189, 190, 191, 197, 198, 199, 202, 203, 204, 220, 221, 222,
                232, 233, 234, 243, 244, 245, 260, 261, 262, 287, 290, 323, 324, 325, 365,
                368, 425, 478, 545, 546, 547, 548, 549, 550, 552, 590, 593, 595, 596, 597,
                598, 601, 605, 608, 611, 613, 614, 615, 616, 619, 622, 623, 645, 677, 678,
                679, 720, 721, 757, 758, 762, 765, 766, 769, 782, 783, 787, 790, 792, 793,
                795, 799, 803, 804, 851, 852, 886, 950, 951, 977, 978, 979, 980
            )
            $result = New-CoverageResult -MissedCommands $lineNumbers.Count -MissedLocations @(
                $lineNumbers | ForEach-Object { New-MissedLocation -SourceLineNumber $_ }
            )

            $output          = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines
            $uncoveredLines  = $output | Where-Object { $_ -match '^(  uncovered:|             )' }

            $uncoveredLines.Count | Should -BeGreaterThan 1

            foreach ($line in $uncoveredLines) {
                $line.Length | Should -BeLessOrEqual 80
            }

            # Continuation lines start with exactly 13 spaces, then a digit - no repeated label.
            for ($i = 1; $i -lt $uncoveredLines.Count; $i++) {
                $uncoveredLines[$i] | Should -Match '^             \d'
            }

            ($output -join "`n") | Should -Match '243-245'
        }

        It 'Should not wrap a short uncovered-lines list' {
            $result = New-CoverageResult -MissedCommands 3 -MissedLocations @(
                (New-MissedLocation -SourceLineNumber 51),
                (New-MissedLocation -SourceLineNumber 52),
                (New-MissedLocation -SourceLineNumber 56)
            )

            $output         = $result | Format-PSScriptBuilderSourceCoverage -Detailed 6>&1 | ConvertTo-TextLines
            $uncoveredLines = $output | Where-Object { $_ -match 'uncovered:' }

            @($uncoveredLines).Count | Should -Be 1
            ($output -join "`n") | Should -Match 'uncovered: lines 51-52, 56'
        }
    }

    Context 'Column alignment regressions' {

        <#
        PadRight/PadLeft never truncate, so a column's width must be computed from the wider
        of (a) the header word and (b) the actual data - using only one or the other breaks
        alignment. Both bugs below were originally found by manual testing, before these
        automated tests existed.
        #>

        It 'Should widen the SourceFile column to fit the header word even when all file names are shorter' {
            $result = New-CoverageResult -SourceFile 'a.ps1'

            $output    = $result | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines
            $header    = $output[1]
            $separator = $output[2]

            $fileColumnWidth        = ($header    -split '\s{2,}')[0].Length
            $separatorSegmentLength = ($separator -split '\s{2,}')[0].Length

            $fileColumnWidth        | Should -BeGreaterOrEqual 'SourceFile'.Length
            $separatorSegmentLength | Should -Be $fileColumnWidth
        }

        It 'Should widen the Hit/Total column to fit large command counts' {
            $result = New-CoverageResult -HitCommands 12345 -TotalCommands 12345

            $output  = $result | Format-PSScriptBuilderSourceCoverage 6>&1 | ConvertTo-TextLines
            $dataRow = $output[3]

            $dataRow | Should -Match '12345/12345'
            # If the column were still hardcoded to 9 characters, this longer ratio would
            # have been left un-padded and appended directly without the expected separation.
            $dataRow | Should -Match '\s{2,}12345/12345$'
        }
    }
}