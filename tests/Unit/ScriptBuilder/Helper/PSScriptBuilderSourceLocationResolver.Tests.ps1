using namespace System
using namespace System.IO
using namespace System.Management.Automation

Describe 'PSScriptBuilderSourceLocationResolver' {

    BeforeAll {
        Function New-Location {
            param(
                [string] $ComponentName       = 'MyClass',
                [string] $ComponentType       = 'Class',
                [string] $SourceFile          = 'C:\src\MyClass.ps1',
                [int]    $SourceLineNumber    = 1,
                [int]    $ComponentLineNumber = 1,
                [int]    $OutputLineNumber    = 1,
                [int]    $Offset              = 0
            )
            return [PSScriptBuilderSourceLocation]::new(
                $ComponentName, $ComponentType, $SourceFile,
                $SourceLineNumber, $ComponentLineNumber, $OutputLineNumber, $Offset)
        }

        Function New-SourceMapData {
            param(
                [PSScriptBuilderSourceLocation[]] $Components     = @(),
                [int]                             $OutputLineCount = 0
            )
            return [PSScriptBuilderSourceMapData]::new('C:\out.ps1', '', $OutputLineCount, $Components)
        }
    }

    #region Constructor

    Context 'Constructor' {

        It 'Should throw ArgumentException when sourceMapData is null' {
            { [PSScriptBuilderSourceLocationResolver]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should accept an empty source map without throwing' {
            { [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData)) } |
                Should -Not -Throw
        }

        It 'Should sort entries by OutputLineNumber ascending on construction' {
            $entries = @(
                (New-Location -ComponentName 'Last'  -OutputLineNumber 300),
                (New-Location -ComponentName 'First' -OutputLineNumber 100),
                (New-Location -ComponentName 'Mid'   -OutputLineNumber 200)
            )
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData $entries))

            $map = $resolver.GetSourceMap()
            $map[0].ComponentName | Should -Be 'First'
            $map[1].ComponentName | Should -Be 'Mid'
            $map[2].ComponentName | Should -Be 'Last'
        }
    }

    #endregion

    #region GetSourceMap

    Context 'GetSourceMap' {

        It 'Should return all entries in the source map' {
            $entries = @(
                (New-Location -ComponentName 'EnumA'   -OutputLineNumber 10),
                (New-Location -ComponentName 'ClassB'  -OutputLineNumber 50),
                (New-Location -ComponentName 'FuncC'   -OutputLineNumber 100)
            )
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData $entries))

            $result = $resolver.GetSourceMap()

            $result.Count | Should -Be 3
        }

        It 'Should return an empty array for an empty source map' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))

            $result = $resolver.GetSourceMap()

            $result.Count | Should -Be 0
        }

        It 'Should return entries with Offset 0 (build-time source map, not yet resolved)' {
            $entries = @(New-Location -Offset 0 -OutputLineNumber 1)
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entries)))

            $result = $resolver.GetSourceMap()

            $result[0].Offset | Should -Be 0
        }
    }

    #endregion

    #region Resolve(int)

    Context 'Resolve(int) - parameter validation' {

        It 'Should throw ArgumentException when lineNumber is 0' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))

            { $resolver.Resolve(0) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when lineNumber is negative' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))

            { $resolver.Resolve(-1) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'Resolve(int) - no match' {

        It 'Should return null when line is before all entries' {
            $entry    = New-Location -ComponentName 'MyClass' -OutputLineNumber 50
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(10)

            $result | Should -BeNullOrEmpty
        }

        It 'Should return null for an empty source map' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))

            $result = $resolver.Resolve(1)

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Resolve(int) - exact match' {

        It 'Should return the matching entry when line equals OutputLineNumber exactly' {
            $entry    = New-Location -ComponentName 'ExactClass' -ComponentLineNumber 5 -OutputLineNumber 100
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(100)

            $result.ComponentName | Should -Be 'ExactClass'
        }

        It 'Should set Offset to 0 when line equals OutputLineNumber' {
            $entry    = New-Location -OutputLineNumber 100
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(100)

            $result.Offset | Should -Be 0
        }

        It 'Should set SourceLineNumber to ComponentLineNumber when Offset is 0' {
            $entry    = New-Location -ComponentLineNumber 14 -OutputLineNumber 100
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(100)

            $result.SourceLineNumber | Should -Be 14
        }
    }

    Context 'Resolve(int) - offset calculation' {

        It 'Should set Offset to the difference between lineNumber and OutputLineNumber' {
            $entry    = New-Location -OutputLineNumber 100
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(110)

            $result.Offset | Should -Be 10
        }

        It 'Should set SourceLineNumber to ComponentLineNumber plus Offset' {
            $entry    = New-Location -ComponentLineNumber 14 -OutputLineNumber 100
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(110)

            $result.SourceLineNumber | Should -Be 24
        }

        It 'Should resolve to the last qualifying entry when multiple entries precede the line' {
            $entries = @(
                (New-Location -ComponentName 'First'  -OutputLineNumber 10),
                (New-Location -ComponentName 'Second' -OutputLineNumber 50),
                (New-Location -ComponentName 'Third'  -OutputLineNumber 200)
            )
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData $entries))

            # Line 80 is between Second (50) and Third (200) — should resolve to Second
            $result = $resolver.Resolve(80)

            $result.ComponentName | Should -Be 'Second'
        }

        It 'Should preserve ComponentName, ComponentType, and SourceFile from the matched entry' {
            $entry    = New-Location -ComponentName 'MyFunc' -ComponentType 'Function' -SourceFile 'C:\src\MyFunc.ps1' -OutputLineNumber 200
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(205)

            $result.ComponentName | Should -Be 'MyFunc'
            $result.ComponentType | Should -Be 'Function'
            $result.SourceFile    | Should -Be 'C:\src\MyFunc.ps1'
        }

        It 'Should preserve OutputLineNumber from the matched entry' {
            $entry    = New-Location -OutputLineNumber 300
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(310)

            $result.OutputLineNumber | Should -Be 300
        }
    }

    #endregion

    #region TryResolve(int)

    Context 'TryResolve(int) - parameter validation' {

        It 'Should throw ArgumentException when lineNumber is 0' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))
            $location = $null

            { $resolver.TryResolve(0, [ref] $location) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'TryResolve(int) - success' {

        It 'Should return true when a location is found' {
            $entry    = New-Location -OutputLineNumber 100
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))
            $location = $null

            $result = $resolver.TryResolve(100, [ref] $location)

            $result | Should -BeTrue
        }

        It 'Should set the location output parameter when found' {
            $entry    = New-Location -ComponentName 'MyClass' -OutputLineNumber 100
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))
            $location = $null

            $resolver.TryResolve(100, [ref] $location) | Out-Null

            $location.ComponentName | Should -Be 'MyClass'
        }
    }

    Context 'TryResolve(int) - failure' {

        It 'Should return false when no location is found' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))
            $location = $null

            $result = $resolver.TryResolve(1, [ref] $location)

            $result | Should -BeFalse
        }

        It 'Should set the location output parameter to null when not found' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))
            $location = $null

            $resolver.TryResolve(1, [ref] $location) | Out-Null

            $location | Should -BeNullOrEmpty
        }

        It 'Should not emit a warning when the line cannot be resolved' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))
            $location = $null

            $output   = & { $resolver.TryResolve(1, [ref] $location) } 3>&1
            $warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings | Should -BeNullOrEmpty
        }

        It 'Should not emit a warning even when lineNumber exceeds TotalOutputLines' {
            $entry    = New-Location -OutputLineNumber 10
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry) -OutputLineCount 50))
            $location = $null

            $output   = & { $resolver.TryResolve(100, [ref] $location) } 3>&1
            $warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings | Should -BeNullOrEmpty
        }

        It 'Should reset the location output parameter to null on failure, even if it held a value from a prior successful call' {
            $entry    = New-Location -OutputLineNumber 10
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))
            $location = $null

            $resolver.TryResolve(10, [ref] $location) | Out-Null
            $location | Should -Not -BeNullOrEmpty

            $resolver.TryResolve(1, [ref] $location) | Out-Null

            $location | Should -BeNullOrEmpty
        }
    }

    #endregion

    #region Resolve(ErrorRecord)

    Context 'Resolve(ErrorRecord) - parameter validation' {

        It 'Should throw ArgumentException when errorRecord is null' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))

            { $resolver.Resolve([ErrorRecord] $null) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when InvocationInfo is null' {
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData))
            $ex = [Exception]::new("test")
            $er = [ErrorRecord]::new($ex, "TestId", [ErrorCategory]::NotSpecified, $null)

            { $resolver.Resolve($er) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'Resolve(ErrorRecord) - resolution' {

        It 'Should resolve using ScriptLineNumber from InvocationInfo' {
            $entry    = New-Location -ComponentName 'MyFunc' -ComponentLineNumber 1 -OutputLineNumber 1
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            # Script that throws on line 1 — provides a real ErrorRecord with InvocationInfo
            $tmpScript = Join-Path $TestDrive 'error-source.ps1'
            Set-Content -Path $tmpScript -Value 'throw "test error"' -Encoding UTF8
            $errorRecord = $null
            try { . $tmpScript } catch { $errorRecord = $_ }

            $result = $resolver.Resolve($errorRecord)

            $result.ComponentName | Should -Be 'MyFunc'
        }
    }

    #endregion

    #region Constructor (with outputLineCount)

    Context 'Constructor (with outputLineCount)' {

        It 'Should accept a valid source map and output line count without throwing' {
            { [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData -OutputLineCount 100)) } |
                Should -Not -Throw
        }
    }

    #endregion

    #region Resolve(int) - upper bound

    Context 'Resolve(int) - upper bound check' {

        It 'Should emit a warning when lineNumber exceeds TotalOutputLines' {
            $entry    = New-Location -OutputLineNumber 10
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry) -OutputLineCount 50))

            $output   = & { $resolver.Resolve(100) } 3>&1
            $warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Should return null when lineNumber exceeds TotalOutputLines' {
            $entry    = New-Location -OutputLineNumber 10
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry) -OutputLineCount 50))

            $result = $resolver.Resolve(100) 3>$null

            $result | Should -BeNullOrEmpty
        }

        It 'Should not enforce the upper bound when TotalOutputLines is 0' {
            $entry    = New-Location -OutputLineNumber 10
            $resolver = [PSScriptBuilderSourceLocationResolver]::new((New-SourceMapData @($entry)))

            $result = $resolver.Resolve(10000) 3>$null

            $result | Should -Not -BeNullOrEmpty
        }
    }

    #endregion
}
