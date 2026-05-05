using namespace System

Describe 'PSScriptBuilderScriptPostProcessor' {

    #region RemoveComments
    Context 'RemoveComments' {

        It 'Should return empty string unchanged' {
            [PSScriptBuilderScriptPostProcessor]::RemoveComments('') | Should -Be ''
        }

        It 'Should remove a single-line comment' {
            $script = "# This is a comment`n`$x = 1"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result | Should -Not -Match '#'
            $result | Should -Match '\$x = 1'
        }

        It 'Should remove an inline comment' {
            $script = '$x = 1 # inline comment'
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result | Should -Not -Match '# inline'
            $result | Should -Match '\$x = 1'
        }

        It 'Should remove a block comment' {
            $script = "<#`nThis is a block comment`n#>`n`$x = 1"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result | Should -Not -Match 'block comment'
            $result | Should -Match '\$x = 1'
        }

        It 'Should remove #region and #endregion markers' {
            $script = "#region MyRegion`n`$x = 1`n#endregion MyRegion"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result | Should -Not -Match '#region'
            $result | Should -Not -Match '#endregion'
            $result | Should -Match '\$x = 1'
        }

        It 'Should preserve #Requires statements' {
            $script = "#Requires -Version 5.1`n`$x = 1"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result | Should -Match '#Requires'
        }

        It 'Should not remove a hash symbol inside a string' {
            $script = '$x = "value # not a comment"'
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result | Should -Be $script
        }

        It 'Should handle a script with no comments' {
            $script = '$x = 1'
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result | Should -Be $script
        }
    }
    #endregion RemoveComments

    Context 'RemoveComments - RemovedCount' {

        It 'Should set removedCount to 0 for empty string' {
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveComments('', [ref] $count) | Out-Null
            $count | Should -Be 0
        }

        It 'Should set removedCount to 0 when no comments are present' {
            $script = '$x = 1'
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveComments($script, [ref] $count) | Out-Null
            $count | Should -Be 0
        }

        It 'Should set removedCount to the number of comments removed' {
            $script = "# comment one`n`$x = 1`n# comment two"
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveComments($script, [ref] $count) | Out-Null
            $count | Should -Be 2
        }

        It 'Should not count #Requires statements in removedCount' {
            $script = "#Requires -Version 5.1`n# regular comment"
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveComments($script, [ref] $count) | Out-Null
            $count | Should -Be 1
        }

        It 'Should return the same result as the non-ref overload' {
            $script = "# comment`n`$x = 1"
            $count = 0
            $refResult    = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script, [ref] $count)
            $nonRefResult = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $refResult | Should -Be $nonRefResult
        }
    }

    #region RemoveBlankLines
    Context 'RemoveBlankLines' {

        It 'Should return empty string unchanged' {
            [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines('') | Should -Be ''
        }

        It 'Should remove a blank line between statements' {
            $script = "`$x = 1`n`n`$y = 2"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script)
            $result | Should -Not -Match '\n\n'
        }

        It 'Should remove leading blank lines' {
            $script = "`n`n`$x = 1"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script)
            $result | Should -Not -Match '^\s*\n'
        }

        It 'Should remove trailing blank lines' {
            $script = "`$x = 1`n`n"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script)
            ($result -split '\r?\n') | Where-Object { [string]::IsNullOrWhiteSpace($_) } | Should -BeNullOrEmpty
        }

        It 'Should remove lines containing only whitespace' {
            $script = "`$x = 1`n   `n`$y = 2"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script)
            ($result -split '\r?\n') | Where-Object { [string]::IsNullOrWhiteSpace($_) } | Should -BeNullOrEmpty
        }

        It 'Should handle a script with no blank lines' {
            $script = "`$x = 1`n`$y = 2"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script)
            $result | Should -Match '\$x = 1'
            $result | Should -Match '\$y = 2'
        }
    }
    #endregion RemoveBlankLines

    Context 'RemoveBlankLines - RemovedCount' {

        It 'Should set removedCount to 0 for empty string' {
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines('', [ref] $count) | Out-Null
            $count | Should -Be 0
        }

        It 'Should set removedCount to 0 when no blank lines are present' {
            $script = "`$x = 1`n`$y = 2"
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script, [ref] $count) | Out-Null
            $count | Should -Be 0
        }

        It 'Should set removedCount to the number of blank lines removed' {
            $script = "`$x = 1`n`n`n`$y = 2"
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script, [ref] $count) | Out-Null
            $count | Should -Be 2
        }

        It 'Should return the same result as the non-ref overload' {
            $script = "`$x = 1`n`n`$y = 2"
            $count = 0
            $refResult    = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script, [ref] $count)
            $nonRefResult = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script)
            $refResult | Should -Be $nonRefResult
        }
    }

    #region RemoveOutputStatements
    Context 'RemoveOutputStatements - Guard Clauses' {

        It 'Should return empty string unchanged' {
            [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements('', @('Write-Verbose')) | Should -Be ''
        }

        It 'Should return script unchanged when cmdletNames is empty' {
            $script = 'Write-Verbose "test"'
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @())
            $result | Should -Be $script
        }

        It 'Should return script unchanged when cmdletNames is null' {
            $script = 'Write-Verbose "test"'
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, $null)
            $result | Should -Be $script
        }
    }
    #endregion RemoveOutputStatements

    #region RemoveOutputStatements - Isolated Calls
    Context 'RemoveOutputStatements - Isolated Calls' {

        It 'Should remove an isolated Write-Verbose call' {
            $script = "`$x = 1`nWrite-Verbose `"Processing...`"`n`$y = 2"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'))
            $result | Should -Not -Match 'Write-Verbose'
            $result | Should -Match '\$x = 1'
            $result | Should -Match '\$y = 2'
        }

        It 'Should remove an isolated Write-Debug call' {
            $script = "`$x = 1`nWrite-Debug `"debug info`"`n`$y = 2"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Debug'))
            $result | Should -Not -Match 'Write-Debug'
        }

        It 'Should remove multiple different isolated output statements' {
            $script = "Write-Verbose `"v`"`nWrite-Debug `"d`"`n`$x = 1"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose', 'Write-Debug'))
            $result | Should -Not -Match 'Write-Verbose'
            $result | Should -Not -Match 'Write-Debug'
            $result | Should -Match '\$x = 1'
        }

        It 'Should not remove a call that is not in the cmdletNames list' {
            $script = "Write-Verbose `"test`""
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Debug'))
            $result | Should -Match 'Write-Verbose'
        }

        It 'Should not remove the entire line when call is part of a pipeline' {
            $script = "`$x | Write-Verbose"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'))
            $result | Should -Match 'Write-Verbose'
        }

        It 'Should not remove the entire line when call is inside an if statement' {
            $script = "if (`$true) { Write-Verbose `"test`" }"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'))
            $result | Should -Match 'Write-Verbose'
        }

        It 'Should remove the entire line including line ending' {
            $script = "`$x = 1`nWrite-Verbose `"test`"`n`$y = 2"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'))
            $lines  = $result -split '\r?\n'
            $lines.Count | Should -Be 2
        }
    }
    #endregion RemoveOutputStatements - Isolated Calls

    Context 'RemoveOutputStatements - RemovedCount' {

        It 'Should set removedCount to 0 for empty string' {
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements('', @('Write-Verbose'), [ref] $count) | Out-Null
            $count | Should -Be 0
        }

        It 'Should set removedCount to 0 when cmdletNames is empty' {
            $script = 'Write-Verbose "test"'
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @(), [ref] $count) | Out-Null
            $count | Should -Be 0
        }

        It 'Should set removedCount to the number of removed output statements' {
            $script = "Write-Verbose `"a`"`n`$x = 1`nWrite-Verbose `"b`""
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'), [ref] $count) | Out-Null
            $count | Should -Be 2
        }

        It 'Should not count non-isolated calls in removedCount' {
            $script = '`$x | Write-Verbose'
            $count = 0
            [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'), [ref] $count) | Out-Null
            $count | Should -Be 0
        }

        It 'Should return the same result as the non-ref overload' {
            $script = "`$x = 1`nWrite-Verbose `"test`"`n`$y = 2"
            $count = 0
            $refResult    = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'), [ref] $count)
            $nonRefResult = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'))
            $refResult | Should -Be $nonRefResult
        }
    }

    #region Combined Operations
    Context 'Combined Operations' {

        It 'Should handle RemoveComments followed by RemoveBlankLines' {
            $script = "# comment`n`n`$x = 1"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script)
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($result)
            ($result -split '\r?\n').Count | Should -Be 1
            $result | Should -Match '\$x = 1'
        }

        It 'Should handle RemoveOutputStatements followed by RemoveBlankLines' {
            $script = "`$x = 1`nWrite-Verbose `"test`"`n`$y = 2"
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, @('Write-Verbose'))
            $result = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($result)
            ($result -split '\r?\n').Count | Should -Be 2
        }
    }
    #endregion Combined Operations
}
