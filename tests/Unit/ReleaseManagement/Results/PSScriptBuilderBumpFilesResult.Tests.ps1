using namespace System.Collections.Specialized

Describe 'PSScriptBuilderBumpFilesResult' {

    BeforeAll {
        Function New-BumpDetail {
            param([string] $Path = 'C:\project\file.ps1')
            return [PSCustomObject]@{
                Path         = $Path
                ChangedItems = @(
                    [PSCustomObject]@{ Token = '{{VERSION}}'; OldValue = '1.0.0'; NewValue = '1.1.0' }
                )
            }
        }

        Function New-Result {
            param(
                [int]             $TotalFilesProcessed = 0,
                [int]             $TotalFilesModified  = 0,
                [PSCustomObject[]] $BumpDetails        = @()
            )
            return [PSScriptBuilderBumpFilesResult]::new($TotalFilesProcessed, $TotalFilesModified, $BumpDetails)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set TotalFilesProcessed' {
            $result = New-Result -TotalFilesProcessed 5

            $result.TotalFilesProcessed | Should -Be 5
        }

        It 'Should set TotalFilesModified' {
            $result = New-Result -TotalFilesModified 3

            $result.TotalFilesModified | Should -Be 3
        }

        It 'Should set BumpDetails' {
            $details = @(New-BumpDetail -Path 'C:\project\module.psd1')
            $result  = New-Result -BumpDetails $details

            $result.BumpDetails.Count    | Should -Be 1
            $result.BumpDetails[0].Path  | Should -Be 'C:\project\module.psd1'
        }

        It 'Should set TotalFilesProcessed to 0 by default' {
            $result = New-Result

            $result.TotalFilesProcessed | Should -Be 0
        }

        It 'Should set TotalFilesModified to 0 by default' {
            $result = New-Result

            $result.TotalFilesModified | Should -Be 0
        }

        It 'Should set BumpDetails to empty array by default' {
            $result = New-Result

            $result.BumpDetails | Should -BeNullOrEmpty
        }

        It 'Should allow TotalFilesModified to be less than TotalFilesProcessed' {
            $result = New-Result -TotalFilesProcessed 5 -TotalFilesModified 2

            $result.TotalFilesProcessed | Should -Be 5
            $result.TotalFilesModified  | Should -Be 2
        }

        It 'Should preserve multiple BumpDetails entries' {
            $details = @(
                New-BumpDetail -Path 'C:\project\module.psd1'
                New-BumpDetail -Path 'C:\project\CHANGELOG.md'
            )
            $result = New-Result -TotalFilesProcessed 2 -TotalFilesModified 2 -BumpDetails $details

            $result.BumpDetails.Count | Should -Be 2
        }
    }
}
