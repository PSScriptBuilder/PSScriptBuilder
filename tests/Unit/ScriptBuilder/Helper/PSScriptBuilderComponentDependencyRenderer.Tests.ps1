using namespace System

Describe 'PSScriptBuilderComponentDependencyRenderer' {

    BeforeAll {
        Function New-Entry {
            param(
                [string]   $Name,
                [int]      $Depth,
                [string[]] $Path
            )
            return [PSScriptBuilderComponentDependencyEntry]::new($Name, $Depth, $Path)
        }
    }

    #region RenderTree - Empty Input
    Context 'RenderTree - Empty Input' {

        It 'Should return placeholder when entries is null' {
            $result = [PSScriptBuilderComponentDependencyRenderer]::RenderTree($null)
            $result | Should -Be '  (no components found)'
        }

        It 'Should return placeholder when entries is an empty array' {
            $result = [PSScriptBuilderComponentDependencyRenderer]::RenderTree(@())
            $result | Should -Be '  (no components found)'
        }
    }
    #endregion RenderTree - Empty Input

    #region RenderTree - Root Name
    Context 'RenderTree - Root Name' {

        It 'Should render the root name on the first line' {
            $entries = @(New-Entry 'ClassB' 1 @('ClassA', 'ClassB'))
            $result  = [PSScriptBuilderComponentDependencyRenderer]::RenderTree($entries)
            $lines   = $result -split "`n"
            $lines[0].Trim() | Should -Be 'ClassA'
        }
    }
    #endregion RenderTree - Root Name

    #region RenderTree - Single Child
    Context 'RenderTree - Single Child' {

        BeforeEach {
            $script:entries = @(New-Entry 'ClassB' 1 @('ClassA', 'ClassB'))
            $script:result  = [PSScriptBuilderComponentDependencyRenderer]::RenderTree($script:entries)
            $script:lines   = $script:result -split "`n"
        }

        It 'Should contain the child component name' {
            $script:result | Should -Match 'ClassB'
        }

        It 'Should use the corner connector for a single (last) child' {
            $corner = [string]([char]9492) + [string]([char]9472)
            $script:lines[1] | Should -Match ([regex]::Escape($corner))
        }
    }
    #endregion RenderTree - Single Child

    #region RenderTree - Multiple Direct Children
    Context 'RenderTree - Multiple Direct Children' {

        BeforeEach {
            # ClassA -> ClassB, ClassC (alphabetical: B before C)
            $script:entries = @(
                New-Entry 'ClassB' 1 @('ClassA', 'ClassB')
                New-Entry 'ClassC' 1 @('ClassA', 'ClassC')
            )
            $script:result = [PSScriptBuilderComponentDependencyRenderer]::RenderTree($script:entries)
            $script:lines  = $script:result -split "`n"
        }

        It 'Should use the branch connector for a non-last child' {
            $branch = [string]([char]9500) + [string]([char]9472)
            $lineWithClassB = $script:lines | Where-Object { $_ -match 'ClassB' }
            $lineWithClassB | Should -Match ([regex]::Escape($branch))
        }

        It 'Should use the corner connector for the last child' {
            $corner = [string]([char]9492) + [string]([char]9472)
            $lineWithClassC = $script:lines | Where-Object { $_ -match 'ClassC' }
            $lineWithClassC | Should -Match ([regex]::Escape($corner))
        }

        It 'Should sort children alphabetically' {
            $indexB = ($script:lines | Select-String 'ClassB').LineNumber
            $indexC = ($script:lines | Select-String 'ClassC').LineNumber
            $indexB | Should -BeLessThan $indexC
        }
    }
    #endregion RenderTree - Multiple Direct Children

    #region RenderTree - Transitive Dependency
    Context 'RenderTree - Transitive Dependency' {

        BeforeEach {
            # ClassA -> ClassB -> ClassC
            $script:entries = @(
                New-Entry 'ClassB' 1 @('ClassA', 'ClassB')
                New-Entry 'ClassC' 2 @('ClassA', 'ClassB', 'ClassC')
            )
            $script:result = [PSScriptBuilderComponentDependencyRenderer]::RenderTree($script:entries)
            $script:lines  = $script:result -split "`n"
        }

        It 'Should render the transitive dependency in the output' {
            $script:result | Should -Match 'ClassC'
        }

        It 'Should indent the transitive dependency deeper than the direct dependency' {
            $lineB   = ($script:lines | Where-Object { $_ -match 'ClassB' })[0]
            $lineC   = ($script:lines | Where-Object { $_ -match 'ClassC' })[0]
            $leadingB = ($lineB -replace '\S.*$').Length
            $leadingC = ($lineC -replace '\S.*$').Length
            $leadingC | Should -BeGreaterThan $leadingB
        }

        It 'Should render ClassB before ClassC' {
            $indexB = ($script:lines | Select-String 'ClassB').LineNumber
            $indexC = ($script:lines | Select-String 'ClassC').LineNumber
            $indexB | Should -BeLessThan $indexC
        }
    }
    #endregion RenderTree - Transitive Dependency

    #region RenderTree - Vertical Bar Prefix
    Context 'RenderTree - Vertical Bar Prefix' {

        It 'Should use vertical bar prefix for children of a non-last parent' {
            # ClassA -> ClassB (non-last), ClassD (last)
            # ClassB -> ClassC
            $entries = @(
                New-Entry 'ClassB' 1 @('ClassA', 'ClassB')
                New-Entry 'ClassD' 1 @('ClassA', 'ClassD')
                New-Entry 'ClassC' 2 @('ClassA', 'ClassB', 'ClassC')
            )
            $result         = [PSScriptBuilderComponentDependencyRenderer]::RenderTree($entries)
            $vertical       = [string]([char]9474)
            $lineWithClassC = ($result -split "`n") | Where-Object { $_ -match 'ClassC' }
            $lineWithClassC | Should -Match ([regex]::Escape($vertical))
        }
    }
    #endregion RenderTree - Vertical Bar Prefix
}
