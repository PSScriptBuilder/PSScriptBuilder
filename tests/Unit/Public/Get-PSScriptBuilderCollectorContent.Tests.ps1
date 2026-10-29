using namespace System.IO

Describe 'Get-PSScriptBuilderCollectorContent' {

    BeforeAll {
        # Helper: writes a .ps1 file to TestDrive: and returns the full path as string
        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }
    }

    Context 'Type dispatch' {

        It 'Should return PSScriptBuilderClassData for a ClassCollector' {
            $file = New-TestFile 'Class.ps1' 'class MyClass { [string] $Name }'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector

            $result.Count | Should -Be 1
            $result[0].GetType().Name | Should -Be 'PSScriptBuilderClassData'
            $result[0].Name | Should -Be 'MyClass'
        }

        It 'Should return PSScriptBuilderFunctionData for a FunctionCollector' {
            $file = New-TestFile 'Function.ps1' 'function Get-Thing { return 1 }'
            $collector = [PSScriptBuilderFunctionCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector

            $result.Count | Should -Be 1
            $result[0].GetType().Name | Should -Be 'PSScriptBuilderFunctionData'
            $result[0].Name | Should -Be 'Get-Thing'
        }

        It 'Should return PSScriptBuilderEnumData for an EnumCollector' {
            $file = New-TestFile 'Enum.ps1' 'enum MyEnum { First; Second }'
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector

            $result.Count | Should -Be 1
            $result[0].GetType().Name | Should -Be 'PSScriptBuilderEnumData'
            $result[0].Name | Should -Be 'MyEnum'
        }

        It 'Should return PSScriptBuilderUsingData for a UsingCollector' {
            $file = New-TestFile 'Using.ps1' 'using namespace System.Text'
            $collector = [PSScriptBuilderUsingCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector

            $result.Count | Should -Be 1
            $result[0].GetType().Name | Should -Be 'PSScriptBuilderUsingData'
            $result[0].Statement | Should -Be 'using namespace System.Text'
        }

        It 'Should return PSScriptBuilderFileData for a FileCollector' {
            $file = New-TestFile 'Raw.ps1' '# just a comment'
            $collector = [PSScriptBuilderFileCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector

            $result.Count | Should -Be 1
            $result[0].GetType().Name | Should -Be 'PSScriptBuilderFileData'
            $result[0].FileName | Should -Be 'Raw.ps1'
        }
    }

    Context 'Automatic Collect() invocation' {

        It 'Should collect data itself without requiring the caller to call Collect() first' {
            $file = New-TestFile 'AutoCollect.ps1' 'class AutoClass { [string] $Name }'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.IncludeFiles = @($file)

            $collector.ClassData.Count | Should -Be 0

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector

            $result.Count | Should -Be 1
            $collector.ClassData.Count | Should -Be 1
        }
    }

    Context '-ItemName filtering' {

        It 'Should return only the matching class by name' {
            $file = New-TestFile 'TwoClasses.ps1' 'class ClassA { [string] $Name }
class ClassB { [string] $Name }'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector -ItemName 'ClassB'

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'ClassB'
        }

        It 'Should match case-insensitively' {
            $file = New-TestFile 'CaseClass.ps1' 'class MyClass { [string] $Name }'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector -ItemName 'myclass'

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'MyClass'
        }

        It 'Should filter a FileCollector by FileName' {
            $file = New-TestFile 'Target.ps1' '# content'
            $collector = [PSScriptBuilderFileCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector -ItemName 'Target.ps1'

            $result.Count | Should -Be 1
            $result[0].FileName | Should -Be 'Target.ps1'
        }

        It 'Should filter a UsingCollector by Statement' {
            $file = New-TestFile 'UsingFilter.ps1' 'using namespace System.Text'
            $collector = [PSScriptBuilderUsingCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector -ItemName 'using namespace System.Text'

            $result.Count | Should -Be 1
            $result[0].Statement | Should -Be 'using namespace System.Text'
        }

        It 'Should return zero items when no item matches ItemName' {
            $file = New-TestFile 'NoMatch.ps1' 'class ClassA { [string] $Name }'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = Get-PSScriptBuilderCollectorContent -Collector $collector -ItemName 'DoesNotExist'

            @($result).Count | Should -Be 0
        }
    }

    Context 'Return shape' {

        <#
        The cmdlet's internal `return @(...)` does not, by itself, guarantee the caller receives
        an array - PowerShell's pipeline unwraps a single emitted object back to a scalar on
        `$result = Cmdlet ...` regardless of what the function returned internally. Wrapping the
        call itself in `@(...)` is the idiomatic way a caller guards against that unwrapping, and
        is what these tests verify.
        #>

        It 'Should behave as a single-element collection when the caller wraps the call in @()' {
            $file = New-TestFile 'SingleItem.ps1' 'class OnlyClass { [string] $Name }'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.IncludeFiles = @($file)

            $result = @(Get-PSScriptBuilderCollectorContent -Collector $collector)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'OnlyClass'
        }
    }

    Context 'Multiple collectors piped in together' {

        It 'Should return independent results for each collector piped through in one call' {
            $classFile = New-TestFile 'PipedClass.ps1' 'class PipedClass { [string] $Name }'
            $functionFile = New-TestFile 'PipedFunction.ps1' 'function Get-Piped { return 1 }'

            $classCollector = [PSScriptBuilderClassCollector]::new()
            $classCollector.IncludeFiles = @($classFile)

            $functionCollector = [PSScriptBuilderFunctionCollector]::new()
            $functionCollector.IncludeFiles = @($functionFile)

            $results = @($classCollector, $functionCollector) | Get-PSScriptBuilderCollectorContent

            $results.Count | Should -Be 2
            ($results | Where-Object { $_.GetType().Name -eq 'PSScriptBuilderClassData' }).Name | Should -Be 'PipedClass'
            ($results | Where-Object { $_.GetType().Name -eq 'PSScriptBuilderFunctionData' }).Name | Should -Be 'Get-Piped'
        }
    }
}
