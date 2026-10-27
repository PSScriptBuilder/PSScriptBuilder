Describe 'PSScriptBuilderCodeCoverageTranslator' {

    BeforeAll {
        $separator = [System.IO.Path]::DirectorySeparatorChar
        $script:OutputPath = "C:${separator}build${separator}Output${separator}MyProject.psm1"

        # Foo starts at output line 10, Bar at output line 30 - leaves output lines 1-9 with
        # no covering component, needed to test the "unresolved line" path without tripping
        # PSScriptBuilderSourceLocationResolver.Resolve()'s own guard clause (throws for
        # lineNumber <= 0, so the gap must be created with valid positive line numbers instead).
        Function New-SampleComponents {
            return @(
                [PSScriptBuilderSourceLocation]::new('Foo', 'Class', 'C:\src\Foo.ps1', 10, 10, 10, 0),
                [PSScriptBuilderSourceLocation]::new('Bar', 'Class', 'C:\src\Bar.ps1', 5,  5,  30, 0)
            )
        }

        Function New-Resolver {
            param(
                [PSScriptBuilderSourceLocation[]] $Components = (New-SampleComponents),
                [int]                             $TotalOutputLines = 1000
            )
            $data = [PSScriptBuilderSourceMapData]::new($script:OutputPath, 'FAKEHASH', $TotalOutputLines, $Components)
            return [PSScriptBuilderSourceLocationResolver]::new($data)
        }

        Function New-Translator {
            param([PSScriptBuilderSourceLocationResolver] $Resolver = (New-Resolver))
            return [PSScriptBuilderCodeCoverageTranslator]::new($Resolver)
        }

        Function New-CoverageCommand {
            param(
                [string] $File     = $script:OutputPath,
                [int]    $Line     = 12,
                [int]    $HitCount = 1
            )
            return [PSCustomObject] @{ File = $File; Line = $Line; HitCount = $HitCount }
        }
    }

    Context 'Constructor' {

        It 'Should throw ArgumentNullException when resolver is null' {
            { [PSScriptBuilderCodeCoverageTranslator]::new($null) } |
                Should -Throw -ExceptionType ([System.ArgumentNullException])
        }
    }

    Context 'Translate - validation' {

        It 'Should throw ArgumentException when outputPath is null or empty' {
            $translator = New-Translator

            { $translator.Translate('', @(), @()) } |
                Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }

    Context 'Translate - basic aggregation' {

        It 'Should return one result per distinct source file' {
            $translator = New-Translator
            $hit    = @(New-CoverageCommand -Line 12)
            $missed = @(New-CoverageCommand -Line 32)

            $results = $translator.Translate($script:OutputPath, $hit, $missed)

            $results.Count | Should -Be 2
        }

        It 'Should correctly count hits and misses per file' {
            $translator = New-Translator
            $hit    = @((New-CoverageCommand -Line 12), (New-CoverageCommand -Line 13))
            $missed = @(New-CoverageCommand -Line 14)

            $results = $translator.Translate($script:OutputPath, $hit, $missed)
            $foo     = $results | Where-Object { $_.SourceFile -eq 'C:\src\Foo.ps1' }

            $foo.HitCommands    | Should -Be 2
            $foo.MissedCommands | Should -Be 1
            $foo.TotalCommands  | Should -Be 3
        }

        It 'Should compute CoveragePercent correctly' {
            $translator = New-Translator
            $hit    = @((New-CoverageCommand -Line 12), (New-CoverageCommand -Line 13), (New-CoverageCommand -Line 14))
            $missed = @(New-CoverageCommand -Line 15)

            $results = $translator.Translate($script:OutputPath, $hit, $missed)
            $foo     = $results | Where-Object { $_.SourceFile -eq 'C:\src\Foo.ps1' }

            $foo.CoveragePercent | Should -Be 75
        }

        It 'Should return CoveragePercent of 0 for a file with zero resolved commands' {
            # Not reachable via normal Translate() flow (a file only appears in the dictionary
            # once at least one command resolves to it), documents the zero-division guard
            # in isolation is covered by "no entries at all" returning an empty array instead.
            $translator = New-Translator

            $results = $translator.Translate($script:OutputPath, @(), @())

            $results.Count | Should -Be 0
        }

        It 'Should populate MissedLocations with resolved source line numbers' {
            $translator = New-Translator
            $missed = @(New-CoverageCommand -Line 32)

            $results = $translator.Translate($script:OutputPath, @(), $missed)
            $bar     = $results | Where-Object { $_.SourceFile -eq 'C:\src\Bar.ps1' }

            $bar.MissedLocations.Count               | Should -Be 1
            $bar.MissedLocations[0].SourceLineNumber | Should -Be 7
        }
    }

    Context 'Translate - file mismatch handling' {

        It 'Should skip entries referencing a file other than outputPath' {
            $translator = New-Translator
            $wrongFile  = @(New-CoverageCommand -File 'C:\some\other\file.ps1' -Line 12)

            $results = $translator.Translate($script:OutputPath, $wrongFile, @())

            $results.Count | Should -Be 0
        }

        It 'Should skip entries with a null or empty File' {
            $translator = New-Translator
            $missingFile = @(New-CoverageCommand -File '' -Line 12)

            $results = $translator.Translate($script:OutputPath, $missingFile, @())

            $results.Count | Should -Be 0
        }

        It 'Should normalize non-canonical outputPath before comparing (regression: literal .. segment)' {
            $translator = New-Translator
            $separator = [System.IO.Path]::DirectorySeparatorChar
            $unresolvedOutputPath = "C:${separator}build${separator}Output${separator}..${separator}Output${separator}MyProject.psm1"
            $hit = @(New-CoverageCommand -Line 12)

            $results = $translator.Translate($unresolvedOutputPath, $hit, @())

            $results.Count | Should -Be 1
        }

        It 'Should emit exactly one consolidated warning regardless of how many entries mismatch' {
            # -ModuleName is required, not optional: PSScriptBuilderCodeCoverageTranslator is a
            # class living inside the PSScriptBuilder module (loaded via 'using module'). Its
            # method body resolves Write-Warning through that module's own scope, not the test
            # file's - a Mock without -ModuleName silently never intercepts it, and the real
            # cmdlet fires instead (verified: Should -Invoke then reports 0 calls even though
            # a warning was genuinely written).
            Mock Write-Warning {} -ModuleName PSScriptBuilder
            $translator = New-Translator
            $wrongFile  = @((New-CoverageCommand -File 'C:\other.ps1' -Line 12), (New-CoverageCommand -File 'C:\other.ps1' -Line 13))

            $translator.Translate($script:OutputPath, $wrongFile, @()) | Out-Null

            Should -Invoke Write-Warning -Times 1 -ModuleName PSScriptBuilder
        }
    }

    Context 'Translate - unresolved line handling' {

        It 'Should skip entries whose line falls before the first tracked component' {
            $translator = New-Translator
            # Output lines 1-9 are not covered by any component (Foo starts at line 10).
            $beforeFirst = @(New-CoverageCommand -Line 3)

            $results = $translator.Translate($script:OutputPath, $beforeFirst, @())

            $results.Count | Should -Be 0
        }

        It 'Should emit exactly one consolidated warning regardless of how many lines are unresolved' {
            # -ModuleName is required: PSScriptBuilderCodeCoverageTranslator lives inside the
            # PSScriptBuilder module (loaded via 'using module'), and a Mock without
            # -ModuleName never intercepts calls made from within it.
            Mock Write-Warning {} -ModuleName PSScriptBuilder
            $translator  = New-Translator
            $beforeFirst = @((New-CoverageCommand -Line 3), (New-CoverageCommand -Line 5))

            $translator.Translate($script:OutputPath, $beforeFirst, @()) | Out-Null

            Should -Invoke Write-Warning -Times 1 -ModuleName PSScriptBuilder
        }
    }

    Context 'Translate - empty input' {

        It 'Should return an empty array when both hitCommands and missedCommands are empty' {
            $translator = New-Translator

            $results = $translator.Translate($script:OutputPath, @(), @())

            $results.Count | Should -Be 0
        }

        It 'Should return an empty array when both hitCommands and missedCommands are null' {
            $translator = New-Translator

            $results = $translator.Translate($script:OutputPath, $null, $null)

            $results.Count | Should -Be 0
        }
    }
}