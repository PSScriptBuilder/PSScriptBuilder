using namespace System

Describe 'New-PSScriptBuilderContentCollector' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Return type' {

        It 'Should return a PSScriptBuilderContentCollector' {
            $result = New-PSScriptBuilderContentCollector

            $result.GetType().Name | Should -Be 'PSScriptBuilderContentCollector'
        }

        It 'Should return a new instance on each call' {
            $cc1 = New-PSScriptBuilderContentCollector
            $cc2 = New-PSScriptBuilderContentCollector

            $cc1 | Should -Not -Be $cc2
        }
    }

    Context 'Empty ContentCollector' {

        It 'Should create a ContentCollector with no collectors' {
            $cc = New-PSScriptBuilderContentCollector

            $cc.GetCollectors().Count | Should -Be 0
        }
    }

    Context 'Parameter - Collector' {

        It 'Should pre-populate with a single collector' {
            $collector = New-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES'
            $cc        = New-PSScriptBuilderContentCollector -Collector $collector

            $cc.GetCollectors().Count | Should -Be 1
        }

        It 'Should pre-populate with multiple collectors' {
            $collectors = @(
                New-PSScriptBuilderCollector -Type Enum     -CollectionKey 'ENUMS'
                New-PSScriptBuilderCollector -Type Class    -CollectionKey 'CLASSES'
                New-PSScriptBuilderCollector -Type Function -CollectionKey 'FUNCTIONS'
            )
            $cc = New-PSScriptBuilderContentCollector -Collector $collectors

            $cc.GetCollectors().Count | Should -Be 3
        }

        It 'Should throw when duplicate CollectionKeys are provided' {
            $collectors = @(
                New-PSScriptBuilderCollector -Type Class -CollectionKey 'DUPLICATE'
                New-PSScriptBuilderCollector -Type Class -CollectionKey 'DUPLICATE'
            )

            { New-PSScriptBuilderContentCollector -Collector $collectors } | Should -Throw
        }
    }

    Context 'Pipeline compatibility with Add-PSScriptBuilderCollector' {

        It 'Should be usable as pipeline source for Add-PSScriptBuilderCollector' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES'

            $cc.GetCollectors().Count | Should -Be 1
        }

        It 'Should support fluent chaining of multiple Add-PSScriptBuilderCollector calls' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'ENUMS'     |
                Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CLASSES'   |
                Add-PSScriptBuilderCollector -Type Function -CollectionKey 'FUNCTIONS'

            $cc.GetCollectors().Count | Should -Be 3
        }
    }
}
