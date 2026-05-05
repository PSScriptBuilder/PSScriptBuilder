using namespace System.IO
using namespace System.Text

Describe 'PSScriptBuilderFileIOHelper' {

    #region Static Properties
    Context 'utf8EncodingWithBOM - static property' {

        It 'Should expose a UTF8Encoding instance' {
            [PSScriptBuilderFileIOHelper]::utf8EncodingWithBOM |
                Should -BeOfType ([UTF8Encoding])
        }

        It 'Should have BOM enabled' {
            [PSScriptBuilderFileIOHelper]::utf8EncodingWithBOM.GetPreamble().Length |
                Should -Be 3
        }
    }
    #endregion Static Properties

    #region ReadAllTextUTF8WithBOM
    Context 'ReadAllTextUTF8WithBOM' {

        It 'Should read the content of an existing file' {
            $filePath = Join-Path $TestDrive 'read-test.txt'
            $expected = 'Hello UTF8'
            [File]::WriteAllText($filePath, $expected, [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be $expected
        }

        It 'Should read multi-line content correctly' {
            $filePath = Join-Path $TestDrive 'read-multiline.txt'
            $expected = "line1`r`nline2`r`nline3"
            [File]::WriteAllText($filePath, $expected, [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be $expected
        }

        It 'Should read an empty file as empty string' {
            $filePath = Join-Path $TestDrive 'read-empty.txt'
            [File]::WriteAllText($filePath, '', [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be ''
        }
    }
    #endregion ReadAllTextUTF8WithBOM

    #region WriteAllTextUTF8WithBOM
    Context 'WriteAllTextUTF8WithBOM' {

        It 'Should write content to a new file' {
            $filePath = Join-Path $TestDrive 'write-test.txt'
            $content  = 'Written content'

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, $content)

            Test-Path $filePath | Should -BeTrue
        }

        It 'Should write content that can be read back correctly' {
            $filePath = Join-Path $TestDrive 'write-read-back.txt'
            $content  = 'round-trip content'

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, $content)
            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be $content
        }

        It 'Should overwrite existing file content' {
            $filePath = Join-Path $TestDrive 'write-overwrite.txt'
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'original')

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'overwritten')
            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be 'overwritten'
        }

        It 'Should write a BOM to the file' {
            $filePath = Join-Path $TestDrive 'write-bom.txt'

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'bom check')
            $rawBytes = [File]::ReadAllBytes($filePath)

            # UTF-8 BOM: EF BB BF
            $rawBytes[0] | Should -Be 0xEF
            $rawBytes[1] | Should -Be 0xBB
            $rawBytes[2] | Should -Be 0xBF
        }
    }
    #endregion WriteAllTextUTF8WithBOM

    #region AppendAllTextUTF8WithBOM
    Context 'AppendAllTextUTF8WithBOM' {

        It 'Should create a new file if it does not exist' {
            $filePath = Join-Path $TestDrive 'append-new.txt'

            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'first')

            Test-Path $filePath | Should -BeTrue
        }

        It 'Should append content to an existing file' {
            $filePath = Join-Path $TestDrive 'append-existing.txt'
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'first')

            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'second')
            $result = [File]::ReadAllText($filePath, [UTF8Encoding]::new($true, $true))

            $result | Should -Be 'firstsecond'
        }

        It 'Should append multiple times' {
            $filePath = Join-Path $TestDrive 'append-multiple.txt'
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'A')
            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'B')
            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'C')

            $result = [File]::ReadAllText($filePath, [UTF8Encoding]::new($true, $true))

            $result | Should -Be 'ABC'
        }
    }
    #endregion AppendAllTextUTF8WithBOM
}
