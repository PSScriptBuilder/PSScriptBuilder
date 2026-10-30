using namespace System

Describe 'Add-PSScriptBuilderCollector' {

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

    Context 'Pipeline chaining' {

        It 'Should return the same ContentCollector instance for chaining' {
            $cc = New-PSScriptBuilderContentCollector

            $result = $cc | Add-PSScriptBuilderCollector -Type Class

            $result | Should -Be $cc
        }

        It 'Should support fluent chaining of multiple collectors' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CLASSES' |
                Add-PSScriptBuilderCollector -Type Function -CollectionKey 'FUNCTIONS'

            $cc.GetCollectors().Count | Should -Be 2
        }
    }

    Context 'Parameter - Type and CollectionKey' {

        It 'Should add a ClassCollector with the default key' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class

            $collectors = $cc.GetCollectors()
            $collectors.Count                | Should -Be 1
            $collectors[0].CollectionKey     | Should -Be 'CLASS_DEFINITIONS'
        }

        It 'Should add a collector with the provided CollectionKey' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'DOMAIN'

            $collectors = $cc.GetCollectors()
            $collectors[0].CollectionKey | Should -Be 'DOMAIN'
        }

        It 'Should throw when adding a collector with a duplicate CollectionKey' {
            {
                New-PSScriptBuilderContentCollector |
                    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'DOMAIN' |
                    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'DOMAIN'
            } | Should -Throw "*already exists*"
        }
    }

    Context 'Parameter - NoRecurse' {

        It 'Should set Recurse to $true on the added collector by default' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class

            $collectors = $cc.GetCollectors()
            $collectors[0].Recurse | Should -BeTrue
        }

        It 'Should set Recurse to $false on the added collector when -NoRecurse is specified' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -NoRecurse

            $collectors = $cc.GetCollectors()
            $collectors[0].Recurse | Should -BeFalse
        }

        It 'Should only affect the collector that has -NoRecurse — other collectors remain recursive' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CLASSES'   -NoRecurse |
                Add-PSScriptBuilderCollector -Type Function -CollectionKey 'FUNCTIONS'

            $collectors = $cc.GetCollectors()
            $classCollector    = $collectors | Where-Object { $_.CollectionKey -eq 'CLASSES' }
            $functionCollector = $collectors | Where-Object { $_.CollectionKey -eq 'FUNCTIONS' }

            $classCollector.Recurse    | Should -BeFalse
            $functionCollector.Recurse | Should -BeTrue
        }

        It 'Should not collect files in subdirectories when -NoRecurse is specified' {
            $root = Join-Path $TestDrive 'add-recurse-off'
            New-Item -ItemType Directory -Path (Join-Path $root 'sub') -Force | Out-Null
            New-TestFile 'Root.ps1' 'class RootClass { }' -SubDir 'add-recurse-off'     | Out-Null
            New-TestFile 'Sub.ps1'  'class SubClass { }'  -SubDir 'add-recurse-off\sub' | Out-Null

            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -IncludePath $root -NoRecurse

            $cc.Execute()

            $classCollector = $cc.GetCollectors() | Where-Object { $_.GetType().Name -eq 'PSScriptBuilderClassCollector' }
            $classCollector.ClassData.ContainsKey('RootClass') | Should -BeTrue
            $classCollector.ClassData.ContainsKey('SubClass')  | Should -BeFalse
        }

        It 'Should collect files in subdirectories when -NoRecurse is not specified' {
            $root = Join-Path $TestDrive 'add-recurse-on'
            New-Item -ItemType Directory -Path (Join-Path $root 'sub') -Force | Out-Null
            New-TestFile 'Root.ps1' 'class RootClass { }' -SubDir 'add-recurse-on'     | Out-Null
            New-TestFile 'Sub.ps1'  'class SubClass { }'  -SubDir 'add-recurse-on\sub' | Out-Null

            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -IncludePath $root

            $cc.Execute()

            $classCollector = $cc.GetCollectors() | Where-Object { $_.GetType().Name -eq 'PSScriptBuilderClassCollector' }
            $classCollector.ClassData.ContainsKey('RootClass') | Should -BeTrue
            $classCollector.ClassData.ContainsKey('SubClass')  | Should -BeTrue
        }
    }
}
