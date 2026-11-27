using namespace System

Describe 'PSScriptBuilderBumpFileChange' {

    BeforeAll {
        $script:Bytes = [byte[]] (0xEF, 0xBB, 0xBF, 0x61)
    }

    Context 'Constructor' {

        It 'Should set all properties' {
            $items  = @([ordered] @{ Pattern = '{{VERSION}}'; Token = 'VERSION'; OldValue = '{{VERSION}}'; NewValue = '1.1.0' })
            $change = [PSScriptBuilderBumpFileChange]::new('C:\project\module.psd1', $script:Bytes, "V = '{{VERSION}}'", "V = '1.1.0'", $items)

            $change.FilePath                 | Should -Be 'C:\project\module.psd1'
            $change.OriginalBytes.Length     | Should -Be 4
            $change.OriginalContent          | Should -Be "V = '{{VERSION}}'"
            $change.NewContent               | Should -Be "V = '1.1.0'"
            $change.ChangedItems.Count       | Should -Be 1
            $change.ChangedItems[0].NewValue | Should -Be '1.1.0'
        }

        It 'Should keep the order of multiple replacements' {
            $items = @(
                [ordered] @{ Pattern = '{{A}}'; Token = 'A'; OldValue = '{{A}}'; NewValue = '1' }
                [ordered] @{ Pattern = '{{B}}'; Token = 'B'; OldValue = '{{B}}'; NewValue = '2' }
            )

            $change = [PSScriptBuilderBumpFileChange]::new('C:\project\file.txt', $script:Bytes, '{{A}}{{B}}', '12', $items)

            $change.ChangedItems.Count    | Should -Be 2
            $change.ChangedItems[0].Token | Should -Be 'A'
            $change.ChangedItems[1].Token | Should -Be 'B'
        }

        It 'Should store an empty array, not $null, for <Case> replacements' -ForEach @(
            @{ Case = 'missing'; Items = $null }
            @{ Case = 'empty';   Items = @() }
        ) {
            $change = [PSScriptBuilderBumpFileChange]::new('C:\project\file.txt', $script:Bytes, 'a', 'b', $Items)

            $null -eq $change.ChangedItems | Should -BeFalse
            $change.ChangedItems.Count     | Should -Be 0
        }

        It 'Should accept empty contents and empty bytes' {
            $change = [PSScriptBuilderBumpFileChange]::new('C:\project\file.txt', [byte[]]::new(0), '', '', @())

            $change.OriginalBytes.Length | Should -Be 0
            $change.OriginalContent      | Should -Be ''
            $change.NewContent           | Should -Be ''
        }

        It 'Should throw ArgumentException when filePath is <Case>' -ForEach @(
            @{ Case = 'null';       FilePath = $null }
            @{ Case = 'empty';      FilePath = '' }
            @{ Case = 'whitespace'; FilePath = '   ' }
        ) {
            { [PSScriptBuilderBumpFileChange]::new($FilePath, $script:Bytes, 'a', 'b', @()) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentNullException when originalBytes is $null' {
            { [PSScriptBuilderBumpFileChange]::new('C:\project\file.txt', $null, 'a', 'b', @()) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }
}
