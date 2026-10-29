using namespace System.Collections.Specialized

Describe 'PSScriptBuilderReleaseDataResult' {

    BeforeAll {
        Function New-Changes {
            param(
                [string] $OldVersion = '1.0.0',
                [string] $NewVersion = '1.1.0'
            )
            $changes = [OrderedDictionary]::new()
            $changes['Version'] = @(
                [PSCustomObject]@{ Property = 'Version'; OldValue = $OldVersion; NewValue = $NewVersion }
            )
            return $changes
        }

        Function New-Result {
            param(
                [int]               $TotalOperationsPerformed = 0,
                [OrderedDictionary] $Changes                  = $null
            )
            if ($null -eq $Changes) { $Changes = [OrderedDictionary]::new() }
            return [PSScriptBuilderReleaseDataResult]::new($TotalOperationsPerformed, $Changes)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set TotalOperationsPerformed' {
            $result = New-Result -TotalOperationsPerformed 3

            $result.TotalOperationsPerformed | Should -Be 3
        }

        It 'Should set Changes' {
            $changes = New-Changes -OldVersion '1.0.0' -NewVersion '1.1.0'
            $result  = New-Result -TotalOperationsPerformed 1 -Changes $changes

            $result.Changes | Should -Not -BeNullOrEmpty
            $result.Changes['Version'] | Should -Not -BeNullOrEmpty
        }

        It 'Should set TotalOperationsPerformed to 0 by default' {
            $result = New-Result

            $result.TotalOperationsPerformed | Should -Be 0
        }

        It 'Should set Changes to empty OrderedDictionary by default' {
            $result = New-Result

            $result.Changes.Count | Should -Be 0
        }

        It 'Should preserve Changes content' {
            $changes = New-Changes -OldVersion '1.0.0' -NewVersion '2.0.0'
            $result  = New-Result -Changes $changes

            $result.Changes['Version'][0].OldValue | Should -Be '1.0.0'
            $result.Changes['Version'][0].NewValue | Should -Be '2.0.0'
        }

        It 'Should support multiple change categories' {
            $changes = [OrderedDictionary]::new()
            $changes['Version'] = @([PSCustomObject]@{ Property = 'Version'; OldValue = '1.0.0'; NewValue = '1.1.0' })
            $changes['Build']   = @([PSCustomObject]@{ Property = 'BuildDate'; OldValue = '2026-01-01'; NewValue = '2026-04-21' })
            $result = New-Result -TotalOperationsPerformed 2 -Changes $changes

            $result.Changes.Count              | Should -Be 2
            $result.Changes['Version']         | Should -Not -BeNullOrEmpty
            $result.Changes['Build']           | Should -Not -BeNullOrEmpty
        }

        It 'Should preserve category order in Changes' {
            $changes = [OrderedDictionary]::new()
            $changes['Version'] = @()
            $changes['Build']   = @()
            $changes['Git']     = @()
            $result = New-Result -Changes $changes

            $keys = @($result.Changes.Keys)
            $keys[0] | Should -Be 'Version'
            $keys[1] | Should -Be 'Build'
            $keys[2] | Should -Be 'Git'
        }
    }
}
