using namespace System

Describe 'PSScriptBuilderErrorOriginCheckResult' {

    Context 'FromMappedOutput' {

        It 'Should set IsFromMappedOutput to true' {
            $result = [PSScriptBuilderErrorOriginCheckResult]::FromMappedOutput()

            $result.IsFromMappedOutput | Should -BeTrue
        }

        It 'Should leave MismatchMessage $null' {
            $result = [PSScriptBuilderErrorOriginCheckResult]::FromMappedOutput()

            # Explicitly $null, not an empty string
            ($null -eq $result.MismatchMessage) | Should -BeTrue
        }

        It 'Should return a new instance on every call, so no caller can modify a shared result' {
            $first  = [PSScriptBuilderErrorOriginCheckResult]::FromMappedOutput()
            $first.IsFromMappedOutput = $false

            $second = [PSScriptBuilderErrorOriginCheckResult]::FromMappedOutput()

            $second.IsFromMappedOutput | Should -BeTrue
        }
    }

    Context 'NotFromMappedOutput' {

        It 'Should set IsFromMappedOutput to false' {
            $result = [PSScriptBuilderErrorOriginCheckResult]::NotFromMappedOutput('The error originated elsewhere.')

            $result.IsFromMappedOutput | Should -BeFalse
        }

        It 'Should set MismatchMessage from the provided value' {
            $result = [PSScriptBuilderErrorOriginCheckResult]::NotFromMappedOutput('The error originated elsewhere.')

            $result.MismatchMessage | Should -Be 'The error originated elsewhere.'
        }

        It 'Should throw ArgumentException when the mismatch message is <Name>' -ForEach @(
            @{ Name = 'null';       Value = $null }
            @{ Name = 'empty';      Value = '' }
            @{ Name = 'whitespace'; Value = '   ' }
        ) {
            { [PSScriptBuilderErrorOriginCheckResult]::NotFromMappedOutput($Value) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'Constructor - consistency of outcome and message' {

        It 'Should throw ArgumentException for a positive result with a mismatch message' {
            { [PSScriptBuilderErrorOriginCheckResult]::new($true, 'Unexpected message.') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for a negative result without a mismatch message' {
            { [PSScriptBuilderErrorOriginCheckResult]::new($false, $null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }
}
