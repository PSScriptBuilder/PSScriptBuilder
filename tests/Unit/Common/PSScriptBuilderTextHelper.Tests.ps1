using namespace System

Describe 'PSScriptBuilderTextHelper' {

    #region GetPluralForm
    Context 'GetPluralForm' {

        It 'Should return singular form when count is 1' {
            $result = [PSScriptBuilderTextHelper]::GetPluralForm(1, 'file', 'files')
            $result | Should -Be 'file'
        }

        It 'Should return plural form when count is 0' {
            $result = [PSScriptBuilderTextHelper]::GetPluralForm(0, 'file', 'files')
            $result | Should -Be 'files'
        }

        It 'Should return plural form when count is 2' {
            $result = [PSScriptBuilderTextHelper]::GetPluralForm(2, 'item', 'items')
            $result | Should -Be 'items'
        }

        It 'Should return plural form for large counts' {
            $result = [PSScriptBuilderTextHelper]::GetPluralForm(100, 'match', 'matches')
            $result | Should -Be 'matches'
        }

        It 'Should handle irregular plurals' {
            $result = [PSScriptBuilderTextHelper]::GetPluralForm(1, 'match', 'matches')
            $result | Should -Be 'match'
        }
    }
    #endregion GetPluralForm

    #region FormatCountedNoun
    Context 'FormatCountedNoun' {

        It 'Should return "1 file" for count 1' {
            $result = [PSScriptBuilderTextHelper]::FormatCountedNoun(1, 'file', 'files')
            $result | Should -Be '1 file'
        }

        It 'Should return "0 files" for count 0' {
            $result = [PSScriptBuilderTextHelper]::FormatCountedNoun(0, 'file', 'files')
            $result | Should -Be '0 files'
        }

        It 'Should return "42 matches" for count 42' {
            $result = [PSScriptBuilderTextHelper]::FormatCountedNoun(42, 'match', 'matches')
            $result | Should -Be '42 matches'
        }
    }
    #endregion FormatCountedNoun

    #region GetStringOrEmpty
    Context 'GetStringOrEmpty' {

        It 'Should return empty string when value is null' {
            $result = [PSScriptBuilderTextHelper]::GetStringOrEmpty($null)
            $result | Should -Be ''
        }

        It 'Should return the string unchanged when value is a string' {
            $result = [PSScriptBuilderTextHelper]::GetStringOrEmpty('hello')
            $result | Should -Be 'hello'
        }

        It 'Should return empty string unchanged when value is an empty string' {
            $result = [PSScriptBuilderTextHelper]::GetStringOrEmpty('')
            $result | Should -Be ''
        }

        It 'Should call ToString() on non-string objects' {
            $guid   = [Guid]::NewGuid()
            $result = [PSScriptBuilderTextHelper]::GetStringOrEmpty($guid)
            $result | Should -Be $guid.ToString()
        }

        It 'Should return integer as string' {
            $result = [PSScriptBuilderTextHelper]::GetStringOrEmpty(42)
            $result | Should -Be '42'
        }
    }
    #endregion GetStringOrEmpty

    #region FormatFileSize
    Context 'FormatFileSize' {

        It 'Should format bytes when size is less than 1 KB' {
            $result = [PSScriptBuilderTextHelper]::FormatFileSize(512)
            $result | Should -Be '512 bytes'
        }

        It 'Should format exactly 1023 bytes as bytes' {
            $result = [PSScriptBuilderTextHelper]::FormatFileSize(1023)
            $result | Should -Be '1023 bytes'
        }

        It 'Should format 1024 bytes as KB' {
            $result = [PSScriptBuilderTextHelper]::FormatFileSize(1024)
            $result | Should -Be '1.00 KB'
        }

        It 'Should format KB values with 2 decimal places' {
            $result = [PSScriptBuilderTextHelper]::FormatFileSize(2048)
            $result | Should -Be '2.00 KB'
        }

        It 'Should format 1 MB as MB' {
            $result = [PSScriptBuilderTextHelper]::FormatFileSize(1048576)
            $result | Should -Be '1.00 MB'
        }

        It 'Should format MB values with 2 decimal places' {
            $result = [PSScriptBuilderTextHelper]::FormatFileSize(2097152)
            $result | Should -Be '2.00 MB'
        }
    }
    #endregion FormatFileSize

    #region FormatDuration
    Context 'FormatDuration' {

        It 'Should format milliseconds when duration is less than 1 second' {
            $ts     = [TimeSpan]::FromMilliseconds(500)
            $result = [PSScriptBuilderTextHelper]::FormatDuration($ts)
            $result | Should -Be '500.00 ms'
        }

        It 'Should format 0 ms correctly' {
            $ts     = [TimeSpan]::FromMilliseconds(0)
            $result = [PSScriptBuilderTextHelper]::FormatDuration($ts)
            $result | Should -Be '0.00 ms'
        }

        It 'Should format 999 ms as milliseconds' {
            $ts     = [TimeSpan]::FromMilliseconds(999)
            $result = [PSScriptBuilderTextHelper]::FormatDuration($ts)
            $result | Should -Be '999.00 ms'
        }

        It 'Should format 1000 ms as seconds' {
            $ts     = [TimeSpan]::FromMilliseconds(1000)
            $result = [PSScriptBuilderTextHelper]::FormatDuration($ts)
            $result | Should -Be '1.00 s'
        }

        It 'Should format 2.5 seconds correctly' {
            $ts     = [TimeSpan]::FromSeconds(2.5)
            $result = [PSScriptBuilderTextHelper]::FormatDuration($ts)
            $result | Should -Be '2.50 s'
        }
    }
    #endregion FormatDuration

    #region FormatCollectorType
    Context 'FormatCollectorType' {

        It 'Should return "Class" for ClassCollector' {
            $result = [PSScriptBuilderTextHelper]::FormatCollectorType([PSScriptBuilderCollectorType]::ClassCollector)
            $result | Should -Be 'Class'
        }

        It 'Should return "Enum" for EnumCollector' {
            $result = [PSScriptBuilderTextHelper]::FormatCollectorType([PSScriptBuilderCollectorType]::EnumCollector)
            $result | Should -Be 'Enum'
        }

        It 'Should return "Function" for FunctionCollector' {
            $result = [PSScriptBuilderTextHelper]::FormatCollectorType([PSScriptBuilderCollectorType]::FunctionCollector)
            $result | Should -Be 'Function'
        }

        It 'Should return the enum name for unrecognised collector types' {
            $result = [PSScriptBuilderTextHelper]::FormatCollectorType([PSScriptBuilderCollectorType]::UsingCollector)
            $result | Should -Be 'UsingCollector'
        }
    }
    #endregion FormatCollectorType
}
