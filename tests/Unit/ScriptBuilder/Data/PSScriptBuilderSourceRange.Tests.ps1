Describe 'PSScriptBuilderSourceRange' {

    Context 'Constructor - property mapping' {

        It 'Should set StartLineNumber from the provided value' {
            $range = [PSScriptBuilderSourceRange]::new(5, 20)

            $range.StartLineNumber | Should -Be 5
        }

        It 'Should set EndLineNumber from the provided value' {
            $range = [PSScriptBuilderSourceRange]::new(5, 20)

            $range.EndLineNumber | Should -Be 20
        }

        It 'Should allow StartLineNumber and EndLineNumber to be equal (single-line component)' {
            $range = [PSScriptBuilderSourceRange]::new(7, 7)

            $range.StartLineNumber | Should -Be 7
            $range.EndLineNumber   | Should -Be 7
        }

        It 'Should allow StartLineNumber of 1 (first line of file)' {
            $range = [PSScriptBuilderSourceRange]::new(1, 10)

            $range.StartLineNumber | Should -Be 1
        }
    }
}
