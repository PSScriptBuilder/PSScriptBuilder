using namespace System

Describe 'New-PSScriptBuilderCollector' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content, [string] $SubDir = '')
            $dir = if ($SubDir) { Join-Path $TestDrive $SubDir } else { $TestDrive }
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $path = Join-Path $dir $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Parameter - Type' {

        It 'Should create a PSScriptBuilderUsingCollector when Type is Using' {
            $collector = New-PSScriptBuilderCollector -Type Using

            $collector.GetType().Name | Should -Be 'PSScriptBuilderUsingCollector'
        }

        It 'Should create a PSScriptBuilderEnumCollector when Type is Enum' {
            $collector = New-PSScriptBuilderCollector -Type Enum

            $collector.GetType().Name | Should -Be 'PSScriptBuilderEnumCollector'
        }

        It 'Should create a PSScriptBuilderClassCollector when Type is Class' {
            $collector = New-PSScriptBuilderCollector -Type Class

            $collector.GetType().Name | Should -Be 'PSScriptBuilderClassCollector'
        }

        It 'Should create a PSScriptBuilderFunctionCollector when Type is Function' {
            $collector = New-PSScriptBuilderCollector -Type Function

            $collector.GetType().Name | Should -Be 'PSScriptBuilderFunctionCollector'
        }

        It 'Should create a PSScriptBuilderFileCollector when Type is File' {
            $collector = New-PSScriptBuilderCollector -Type File

            $collector.GetType().Name | Should -Be 'PSScriptBuilderFileCollector'
        }
    }

    Context 'Parameter - CollectionKey' {

        It 'Should use the default key when CollectionKey is not specified' {
            $collector = New-PSScriptBuilderCollector -Type Class

            $collector.CollectionKey | Should -Be 'CLASS_DEFINITIONS'
        }

        It 'Should use the provided key when CollectionKey is specified' {
            $collector = New-PSScriptBuilderCollector -Type Class -CollectionKey 'DOMAIN_CLASSES'

            $collector.CollectionKey | Should -Be 'DOMAIN_CLASSES'
        }
    }

    Context 'Parameter - IncludePath / ExcludePath / IncludeFile / ExcludeFile' {

        It 'Should set IncludePaths on the collector' {
            $collector = New-PSScriptBuilderCollector -Type Class -IncludePath 'src\Classes'

            $collector.IncludePaths | Should -Contain 'src\Classes'
        }

        It 'Should set ExcludePaths on the collector' {
            $collector = New-PSScriptBuilderCollector -Type Class -ExcludePath 'src\Classes\Legacy'

            $collector.ExcludePaths | Should -Contain 'src\Classes\Legacy'
        }

        It 'Should set IncludeFiles on the collector' {
            $file = New-TestFile 'MyClass.ps1' 'class MyClass { }'

            $collector = New-PSScriptBuilderCollector -Type Class -IncludeFile $file

            $collector.IncludeFiles | Should -Contain $file
        }

        It 'Should set ExcludeFiles on the collector' {
            $collector = New-PSScriptBuilderCollector -Type Class -ExcludeFile '*.Tests.ps1'

            $collector.ExcludeFiles | Should -Contain '*.Tests.ps1'
        }
    }

    Context 'Parameter - NoRecurse' {

        It 'Should set Recurse to $true by default' {
            $collector = New-PSScriptBuilderCollector -Type Class

            $collector.Recurse | Should -BeTrue
        }

        It 'Should set Recurse to $false when -NoRecurse is specified' {
            $collector = New-PSScriptBuilderCollector -Type Class -NoRecurse

            $collector.Recurse | Should -BeFalse
        }

        It 'Should collect files in subdirectories when -NoRecurse is not specified' {
            $root = Join-Path $TestDrive 'recurse-on'
            New-Item -ItemType Directory -Path (Join-Path $root 'sub') -Force | Out-Null
            New-TestFile 'Root.ps1' 'class RootClass { }' -SubDir 'recurse-on'      | Out-Null
            New-TestFile 'Sub.ps1'  'class SubClass { }'  -SubDir 'recurse-on\sub'  | Out-Null

            $collector = New-PSScriptBuilderCollector -Type Class -IncludePath $root
            $collector.Collect()

            $collector.ClassData.ContainsKey('RootClass') | Should -BeTrue
            $collector.ClassData.ContainsKey('SubClass')  | Should -BeTrue
        }

        It 'Should not collect files in subdirectories when -NoRecurse is specified' {
            $root = Join-Path $TestDrive 'recurse-off'
            New-Item -ItemType Directory -Path (Join-Path $root 'sub') -Force | Out-Null
            New-TestFile 'Root.ps1' 'class RootClass { }' -SubDir 'recurse-off'     | Out-Null
            New-TestFile 'Sub.ps1'  'class SubClass { }'  -SubDir 'recurse-off\sub' | Out-Null

            $collector = New-PSScriptBuilderCollector -Type Class -IncludePath $root -NoRecurse
            $collector.Collect()

            $collector.ClassData.ContainsKey('RootClass') | Should -BeTrue
            $collector.ClassData.ContainsKey('SubClass')  | Should -BeFalse
        }
    }
}
