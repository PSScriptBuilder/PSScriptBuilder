Describe 'PSScriptBuilderSourceLocation' {

    BeforeAll {
        Function New-Location {
            param(
                [string] $ComponentName       = 'MyComponent',
                [string] $ComponentType       = 'Class',
                [string] $SourceFile          = 'C:\src\MyComponent.ps1',
                [int]    $SourceLineNumber    = 14,
                [int]    $ComponentLineNumber = 14,
                [int]    $OutputLineNumber    = 100,
                [int]    $Offset              = 0
            )
            return [PSScriptBuilderSourceLocation]::new(
                $ComponentName, $ComponentType, $SourceFile,
                $SourceLineNumber, $ComponentLineNumber, $OutputLineNumber, $Offset)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set ComponentName' {
            $loc = New-Location -ComponentName 'BaseService'

            $loc.ComponentName | Should -Be 'BaseService'
        }

        It 'Should set ComponentType' {
            $loc = New-Location -ComponentType 'Enum'

            $loc.ComponentType | Should -Be 'Enum'
        }

        It 'Should set SourceFile' {
            $loc = New-Location -SourceFile 'C:\project\src\BaseService.ps1'

            $loc.SourceFile | Should -Be 'C:\project\src\BaseService.ps1'
        }

        It 'Should set SourceLineNumber' {
            $loc = New-Location -SourceLineNumber 42

            $loc.SourceLineNumber | Should -Be 42
        }

        It 'Should set ComponentLineNumber' {
            $loc = New-Location -ComponentLineNumber 10

            $loc.ComponentLineNumber | Should -Be 10
        }

        It 'Should set OutputLineNumber' {
            $loc = New-Location -OutputLineNumber 4510

            $loc.OutputLineNumber | Should -Be 4510
        }

        It 'Should set Offset' {
            $loc = New-Location -Offset 15

            $loc.Offset | Should -Be 15
        }

        It 'Should allow Offset of zero (source map entry before resolution)' {
            $loc = New-Location -Offset 0

            $loc.Offset | Should -Be 0
        }
    }

    Context 'Constructor - ComponentLineCount' {

        It 'Should set ComponentLineCount to 0 when created without it' {
            $loc = New-Location

            $loc.ComponentLineCount | Should -Be 0
        }

        It 'Should set ComponentLineCount and all other properties when created with it' {
            $loc = [PSScriptBuilderSourceLocation]::new('BaseService', 'Class', 'C:\src\BaseService.ps1', 42, 40, 4510, 2, 25)

            $loc.ComponentLineCount  | Should -Be 25
            $loc.ComponentName       | Should -Be 'BaseService'
            $loc.ComponentType       | Should -Be 'Class'
            $loc.SourceFile          | Should -Be 'C:\src\BaseService.ps1'
            $loc.SourceLineNumber    | Should -Be 42
            $loc.ComponentLineNumber | Should -Be 40
            $loc.OutputLineNumber    | Should -Be 4510
            $loc.Offset              | Should -Be 2
        }
    }
}
