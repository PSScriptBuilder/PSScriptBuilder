using namespace System
using namespace System.Collections.Generic

Describe 'PSScriptBuilderUsingData' {

    #region Constructor
    Context 'Constructor - parameter validation' {

        It 'Should throw ArgumentException when statement is null or empty' {
            { [PSScriptBuilderUsingData]::new($null, 'C:\file.ps1') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when statement is whitespace' {
            { [PSScriptBuilderUsingData]::new('   ', 'C:\file.ps1') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when sourceFile is null or empty' {
            { [PSScriptBuilderUsingData]::new('using namespace System', $null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when sourceFile is whitespace' {
            { [PSScriptBuilderUsingData]::new('using namespace System', '   ') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set Statement from the provided value' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\file.ps1')

            $data.Statement | Should -Be 'using namespace System'
        }

        It 'Should add the initial sourceFile to SourceFiles' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\file.ps1')

            $data.SourceFiles | Should -Contain 'C:\file.ps1'
        }

        It 'Should initialise SourceFiles with exactly one entry' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\file.ps1')

            $data.SourceFiles.Count | Should -Be 1
        }
    }
    #endregion Constructor

    #region AddSourceFile
    Context 'AddSourceFile - parameter validation' {

        It 'Should throw ArgumentException when sourceFile is null or empty' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\file.ps1')

            { $data.AddSourceFile($null) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when sourceFile is whitespace' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\file.ps1')

            { $data.AddSourceFile('   ') } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'AddSourceFile - behaviour' {

        It 'Should add a new source file to the collection' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\file1.ps1')

            $data.AddSourceFile('C:\file2.ps1')

            $data.SourceFiles.Count | Should -Be 2
            $data.SourceFiles       | Should -Contain 'C:\file2.ps1'
        }

        It 'Should not add a duplicate source file' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\file.ps1')

            $data.AddSourceFile('C:\file.ps1')

            $data.SourceFiles.Count | Should -Be 1
        }

        It 'Should treat source file paths case-insensitively' {
            $data = [PSScriptBuilderUsingData]::new('using namespace System', 'C:\File.ps1')

            $data.AddSourceFile('C:\file.ps1')

            $data.SourceFiles.Count | Should -Be 1
        }
    }
    #endregion AddSourceFile
}
