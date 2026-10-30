using namespace System.Collections.Generic

Describe 'Get-PSScriptBuilderCollector' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'No filters' {

        It 'Should return all registered collectors' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CLASSES' |
                Add-PSScriptBuilderCollector -Type Function -CollectionKey 'FUNCTIONS'

            $result = $cc | Get-PSScriptBuilderCollector

            $result.Count | Should -Be 2
        }

        It 'Should return the collectors sorted by CollectorType' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Function -CollectionKey 'FUNCTIONS' |
                Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CLASSES'

            $result = Get-PSScriptBuilderCollector -ContentCollector $cc

            $result[0].CollectorType | Should -Be 'ClassCollector'
            $result[1].CollectorType | Should -Be 'FunctionCollector'
        }
    }

    Context 'Parameter - CollectionKey' {

        It 'Should return a single collector matching the given key' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES'

            $result = Get-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey 'CLASSES'

            $result.CollectionKey | Should -Be 'CLASSES'
            $result.CollectorType | Should -Be 'ClassCollector'
        }

        It 'Should write a non-terminating error and return $null when the key does not exist' {
            $cc = New-PSScriptBuilderContentCollector

            $result = Get-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey 'MISSING' -ErrorAction SilentlyContinue -ErrorVariable errors

            $result   | Should -BeNullOrEmpty
            $errors   | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter - Type' {

        It 'Should return every collector matching the given type' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES_DOMAIN' |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES_UTILS' |
                Add-PSScriptBuilderCollector -Type Function -CollectionKey 'FUNCTIONS'

            $result = Get-PSScriptBuilderCollector -ContentCollector $cc -Type ClassCollector

            $result.Count | Should -Be 2
            $result.CollectionKey | Should -Contain 'CLASSES_DOMAIN'
            $result.CollectionKey | Should -Contain 'CLASSES_UTILS'
        }

        It 'Should return an empty array when no collector matches the given type' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES'

            $result = @(Get-PSScriptBuilderCollector -ContentCollector $cc -Type FunctionCollector)

            $result.Count | Should -Be 0
        }
    }

    Context 'CollectionKey and Type are mutually exclusive' {

        It 'Should throw a parameter binding error when both -CollectionKey and -Type are specified' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES'

            {
                Get-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey 'CLASSES' -Type ClassCollector
            } | Should -Throw '*parameter set*'
        }
    }

    Context 'Pipeline input' {

        It 'Should accept the ContentCollector via the pipeline' {
            $cc = New-PSScriptBuilderContentCollector |
                Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES'

            $result = $cc | Get-PSScriptBuilderCollector -CollectionKey 'CLASSES'

            $result.CollectionKey | Should -Be 'CLASSES'
        }
    }
}
