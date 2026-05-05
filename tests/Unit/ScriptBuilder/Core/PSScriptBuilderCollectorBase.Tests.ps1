using namespace System
using namespace System.IO

Describe 'PSScriptBuilderCollectorBase' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content, [string] $SubDir = '')
            $dir = if ($SubDir) { Join-Path $TestDrive $SubDir } else { $TestDrive }
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
            $path = Join-Path $dir $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        # Returns a concrete ClassCollector (as stand-in for CollectorBase) with IncludeFiles set
        Function New-Collector {
            param(
                [string[]] $Files      = @(),
                [string[]] $Paths      = @(),
                [string]   $Key        = 'Classes'
            )
            $collector = [PSScriptBuilderClassCollector]::new($Key)
            if ($Files.Count -gt 0) { $collector.IncludeFiles  = $Files }
            if ($Paths.Count -gt 0) { $collector.IncludePaths  = $Paths }
            return $collector
        }

        $script:SimpleClass = @'
class SimpleClass {
    [string] $Name
}
'@
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Constructor - abstract guard' {

        It 'Should throw when instantiated directly as PSScriptBuilderCollectorBase' {
            { [PSScriptBuilderCollectorBase]::new() } | Should -Throw
        }
    }

    Context 'Collect - validation' {

        It 'Should throw when neither IncludePaths nor IncludeFiles is set' {
            $collector = [PSScriptBuilderClassCollector]::new()

            { $collector.Collect() } | Should -Throw
        }
    }

    Context 'Collect - IncludeFiles' {

        It 'Should collect from explicitly listed files' {
            $file = New-TestFile 'Explicit.ps1' $script:SimpleClass
            $collector = New-Collector -Files @($file)

            $collector.Collect()

            $collector.ClassData.Count | Should -Be 1
        }

        It 'Should throw FileNotFoundException for a non-existent explicit file' {
            $missing = Join-Path $TestDrive 'DoesNotExist.ps1'
            $collector = New-Collector -Files @($missing)

            { $collector.Collect() } | Should -Throw
        }
    }

    Context 'Collect - IncludePaths' {

        It 'Should collect all .ps1 files in the path' {
            $subDir = Join-Path $TestDrive 'pathscan'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            New-TestFile 'A.ps1' 'class PathClassA { }' -SubDir 'pathscan' | Out-Null
            New-TestFile 'B.ps1' 'class PathClassB { }' -SubDir 'pathscan' | Out-Null

            $collector = New-Collector -Paths @($subDir)

            $collector.Collect()

            $collector.ClassData.Count | Should -Be 2
        }

        It 'Should throw for a non-existent path' {
            $missing = Join-Path $TestDrive 'nonexistent-dir'
            $collector = New-Collector -Paths @($missing)

            { $collector.Collect() } | Should -Throw
        }
    }

    Context 'Collect - ExcludeFiles' {

        It 'Should exclude files matching pattern' {
            $subDir = Join-Path $TestDrive 'exclude-files'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            New-TestFile 'Keep.ps1'          'class KeepClass { }'      -SubDir 'exclude-files' | Out-Null
            New-TestFile 'Legacy.exclude.ps1' 'class ExcludedClass { }' -SubDir 'exclude-files' | Out-Null

            $collector = New-Collector -Paths @($subDir)
            $collector.ExcludeFiles = @('*.exclude.ps1')
            $collector.Collect()

            $collector.ClassData.ContainsKey('KeepClass')     | Should -BeTrue
            $collector.ClassData.ContainsKey('ExcludedClass') | Should -BeFalse
        }
    }

    Context 'Collect - ExcludePaths' {

        It 'Should exclude all files beneath an excluded subdirectory' {
            $root   = Join-Path $TestDrive 'excludepath-root'
            $normal = Join-Path $root 'normal'
            $hidden = Join-Path $root 'hidden'
            @($root, $normal, $hidden) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

            New-TestFile 'Visible.ps1'  'class VisibleClass { }'  -SubDir 'excludepath-root\normal' | Out-Null
            New-TestFile 'Hidden.ps1'   'class HiddenClass { }'   -SubDir 'excludepath-root\hidden' | Out-Null

            $collector = New-Collector -Paths @($root)
            $collector.ExcludePaths = @($hidden)
            $collector.Collect()

            $collector.ClassData.ContainsKey('VisibleClass') | Should -BeTrue
            $collector.ClassData.ContainsKey('HiddenClass')  | Should -BeFalse
        }
    }

    Context 'Collect - FileExtensions' {

        It 'Should include only files with the specified extension' {
            $subDir = Join-Path $TestDrive 'ext-filter'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            New-TestFile 'Script.ps1'  'class ExtClass { }'  -SubDir 'ext-filter' | Out-Null
            New-TestFile 'Module.psm1' 'class PsmClass { }' -SubDir 'ext-filter' | Out-Null

            $collector = New-Collector -Paths @($subDir)
            $collector.FileExtensions = @('.psm1')
            $collector.Collect()

            $collector.ClassData.ContainsKey('PsmClass') | Should -BeTrue
            $collector.ClassData.ContainsKey('ExtClass')  | Should -BeFalse
        }
    }

    Context 'Collect - Recurse' {

        It 'Should not scan subdirectories when Recurse is $false' {
            $root = Join-Path $TestDrive 'recurse-root'
            $sub  = Join-Path $root 'sub'
            @($root, $sub) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

            New-TestFile 'Root.ps1' 'class RootClass { }' -SubDir 'recurse-root' | Out-Null
            New-TestFile 'Sub.ps1'  'class SubClass { }'  -SubDir 'recurse-root\sub' | Out-Null

            $collector = New-Collector -Paths @($root)
            $collector.Recurse = $false
            $collector.Collect()

            $collector.ClassData.ContainsKey('RootClass') | Should -BeTrue
            $collector.ClassData.ContainsKey('SubClass')  | Should -BeFalse
        }

        It 'Should scan subdirectories when Recurse is $true (default)' {
            $root = Join-Path $TestDrive 'recurse-deep'
            $sub  = Join-Path $root 'deep'
            @($root, $sub) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

            New-TestFile 'Top.ps1'  'class TopClass { }'  -SubDir 'recurse-deep' | Out-Null
            New-TestFile 'Deep.ps1' 'class DeepClass { }' -SubDir 'recurse-deep\deep' | Out-Null

            $collector = New-Collector -Paths @($root)
            $collector.Collect()

            $collector.ClassData.ContainsKey('TopClass')  | Should -BeTrue
            $collector.ClassData.ContainsKey('DeepClass') | Should -BeTrue
        }
    }

    Context 'Collect - deduplication' {

        It 'Should include a file only once when listed in both IncludePaths and IncludeFiles' {
            $subDir = Join-Path $TestDrive 'dedup'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            $file = New-TestFile 'Dedup.ps1' 'class DedupClass { }' -SubDir 'dedup'

            $collector = New-Collector -Paths @($subDir) -Files @($file)
            $collector.Collect()

            $collector.ClassData.Count | Should -Be 1
        }
    }

    Context 'Reset' {

        It 'Should clear collected data when Collect is called a second time' {
            $file = New-TestFile 'ResetClass.ps1' 'class ResetClass { }'
            $collector = New-Collector -Files @($file)

            $collector.Collect()
            $collector.ClassData.Count | Should -Be 1

            $collector.Collect()
            $collector.ClassData.Count | Should -Be 1
        }
    }
}
