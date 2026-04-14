using namespace System
using namespace System.IO
using namespace System.Management.Automation.Language

Describe 'PSScriptBuilderAstEngine' {

    BeforeAll {
        Function New-TempFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }
    }

    Context 'ParseFile' {

        It 'Should return a ScriptBlockAst for a valid file' {
            $file = New-TempFile 'Valid.ps1' '# empty script'

            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $ast | Should -Not -BeNullOrEmpty
            $ast -is [ScriptBlockAst] | Should -BeTrue
        }

        It 'Should throw FileNotFoundException for a non-existent file' {
            $missing = Join-Path $TestDrive 'DoesNotExist.ps1'

            { [PSScriptBuilderAstEngine]::ParseFile($missing) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }
    }

    Context 'FindUsingStatements' {

        It 'Should return an empty array when no using statements are present' {
            $file = New-TempFile 'NoUsing.ps1' '# no using'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindUsingStatements($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a single using statement' {
            $file = New-TempFile 'OneUsing.ps1' "using namespace System"
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindUsingStatements($ast)

            $result.Count | Should -Be 1
        }

        It 'Should find multiple using statements' {
            $file = New-TempFile 'MultiUsing.ps1' @'
using namespace System
using namespace System.IO
using namespace System.Collections.Generic
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindUsingStatements($ast)

            $result.Count | Should -Be 3
        }
    }

    Context 'FindEnumDefinitions' {

        It 'Should return an empty array when no enums are present' {
            $file = New-TempFile 'NoEnum.ps1' '# no enums'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a single enum definition' {
            $file = New-TempFile 'OneEnum.ps1' "enum MyStatus { Active; Inactive }"
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'MyStatus'
        }

        It 'Should find multiple enum definitions' {
            $file = New-TempFile 'MultiEnum.ps1' @'
enum Color { Red; Blue }
enum Size  { Small; Large }
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 2
        }

        It 'Should not return classes when searching for enums' {
            $file = New-TempFile 'ClassNotEnum.ps1' "class MyClass { [string] `$Name }"
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 0
        }
    }

    Context 'FindClassDefinitions' {

        It 'Should return an empty array when no classes are present' {
            $file = New-TempFile 'NoClass.ps1' '# no classes'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a single class definition' {
            $file = New-TempFile 'OneClass.ps1' "class MyClass { [string] `$Name }"
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'MyClass'
        }

        It 'Should find multiple class definitions' {
            $file = New-TempFile 'MultiClass.ps1' @'
class ClassA { [string] $Name }
class ClassB { [int] $Value }
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 2
        }

        It 'Should not return enums when searching for classes' {
            $file = New-TempFile 'EnumNotClass.ps1' "enum MyEnum { Val }"
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 0
        }
    }

    Context 'FindFunctionDefinitions' {

        It 'Should return an empty array when no functions are present' {
            $file = New-TempFile 'NoFuncs.ps1' '# no functions'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a standalone function' {
            $file = New-TempFile 'OneFunc.ps1' @'
Function Get-Value {
    [CmdletBinding()]
    param()
    return 'x'
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Get-Value'
        }

        It 'Should not return class methods as standalone functions' {
            $file = New-TempFile 'ClassMethod.ps1' @'
class MyClass {
    [string] GetName() {
        return "test"
    }
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find standalone functions but not class methods in a mixed file' {
            $file = New-TempFile 'Mixed.ps1' @'
Function Get-Standalone {
    [CmdletBinding()]
    param()
}

class MyClass {
    [string] ClassMethod() {
        return "x"
    }
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Get-Standalone'
        }
    }

    Context 'ExtractSourceCode' {

        It 'Should return the exact source text of a class definition' {
            $file = New-TempFile 'SourceClass.ps1' "class SomeClass { [string] `$Name }"
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classDef = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $source = [PSScriptBuilderAstEngine]::ExtractSourceCode($classDef)

            $source | Should -Match 'SomeClass'
        }

        It 'Should return the exact source text of an enum definition' {
            $file = New-TempFile 'SourceEnum.ps1' "enum SomeEnum { Val1; Val2 }"
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)
            $enumDef = ([PSScriptBuilderAstEngine]::FindEnumDefinitions($ast))[0]

            $source = [PSScriptBuilderAstEngine]::ExtractSourceCode($enumDef)

            $source | Should -Match 'SomeEnum'
        }

        It 'Should return the exact source text of a function definition' {
            $file = New-TempFile 'SourceFunc.ps1' @'
Function Get-Sample {
    [CmdletBinding()]
    param([string] $Name)
    Write-Output $Name
}
'@
            $ast     = [PSScriptBuilderAstEngine]::ParseFile($file)
            $funcDef = ([PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast))[0]

            $source = [PSScriptBuilderAstEngine]::ExtractSourceCode($funcDef)

            $source | Should -Match 'Function Get-Sample'
            $source | Should -Match 'Write-Output'
        }
    }

    Context 'IsBuiltInType' {

        It 'Should return true for primitive types' {
            [PSScriptBuilderAstEngine]::IsBuiltInType('string')  | Should -BeTrue
            [PSScriptBuilderAstEngine]::IsBuiltInType('int')     | Should -BeTrue
            [PSScriptBuilderAstEngine]::IsBuiltInType('bool')    | Should -BeTrue
        }

        It 'Should return true for types with System. prefix' {
            [PSScriptBuilderAstEngine]::IsBuiltInType('System.IO.Path') | Should -BeTrue
        }

        It 'Should return true for types with Microsoft. prefix' {
            [PSScriptBuilderAstEngine]::IsBuiltInType('Microsoft.Win32.Registry') | Should -BeTrue
        }

        It 'Should return false for a custom type name' {
            [PSScriptBuilderAstEngine]::IsBuiltInType('MyCustomClass') | Should -BeFalse
        }

        It 'Should return false for a custom type with PSScriptBuilder prefix' {
            [PSScriptBuilderAstEngine]::IsBuiltInType('PSScriptBuilderClassData') | Should -BeFalse
        }

        It 'Should return true for null or empty input' {
            [PSScriptBuilderAstEngine]::IsBuiltInType($null)  | Should -BeTrue
            [PSScriptBuilderAstEngine]::IsBuiltInType('')     | Should -BeTrue
            [PSScriptBuilderAstEngine]::IsBuiltInType('   ')  | Should -BeTrue
        }

        It 'Should be case-insensitive' {
            [PSScriptBuilderAstEngine]::IsBuiltInType('STRING')  | Should -BeTrue
            [PSScriptBuilderAstEngine]::IsBuiltInType('Boolean') | Should -BeTrue
        }
    }

    Context 'GetTypeReferences' {

        It 'Should return an empty array for a file with no type references' {
            $file = New-TempFile 'NoTypes.ps1' '# no types'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            # Filter out builtins to get only custom types
            $custom = @($result | Where-Object { -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) })
            $custom.Count | Should -Be 0
        }

        It 'Should detect a custom type used as a parameter type' {
            $file = New-TempFile 'ParamType.ps1' @'
Function Use-Custom {
    [CmdletBinding()]
    param([MyCustomType] $Input)
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'MyCustomType'
        }

        It 'Should not return duplicate type references' {
            $file = New-TempFile 'DupTypes.ps1' @'
Function Use-Custom {
    [CmdletBinding()]
    param([MyType] $A, [MyType] $B)
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)
            $myTypeCount = @($result | Where-Object { $_ -eq 'MyType' }).Count

            $myTypeCount | Should -Be 1
        }

        It 'Should extract a custom type from a generic type parameter' {
            $file = New-TempFile 'GenericType.ps1' @'
class GenericUser {
    [System.Collections.Generic.Dictionary[string, MyCustomType]] $Items
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'MyCustomType'
        }

        It 'Should extract the exception type from a catch clause' {
            $file = New-TempFile 'CatchType.ps1' @'
Function Invoke-Safe {
    [CmdletBinding()]
    param()
    try {
        Get-Item -Path "C:\temp"
    } catch ([MyCustomException]) {
        Write-Error $_
    }
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'MyCustomException'
        }

        It 'Should not include types used exclusively in a static property initializer expression' {
            $file = New-TempFile 'StaticInitExcluded.ps1' @'
class HasStaticInit {
    static [StaticOnlyType] $Instance = [StaticOnlyType]::new()
}
'@
            $ast      = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($classAst)

            $result | Should -Not -Contain 'StaticOnlyType'
        }

        It 'Should include types used in both a static initializer and a method body' {
            $file = New-TempFile 'SharedType.ps1' @'
class SharedUsage {
    static [SharedType] $Default = [SharedType]::new()

    [string] GetValue([SharedType] $input) {
        return $input.ToString()
    }
}
'@
            $ast      = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($classAst)

            $result | Should -Contain 'SharedType'
        }

        It 'Should not include types from a non-class-member static init (standalone function is unaffected)' {
            $file = New-TempFile 'StandaloneFunc.ps1' @'
Function Invoke-Work {
    [CmdletBinding()]
    param([StandaloneType] $Input)
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'StandaloneType'
        }
    }

    Context 'GetStaticInitializerTypeReferences' {

        It 'Should return an empty array when class has no static properties' {
            $file = New-TempFile 'NoStaticProps.ps1' @'
class NoStatics {
    [string] $Name
}
'@
            $ast      = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $custom = @($result | Where-Object { -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) })
            $custom.Count | Should -Be 0
        }

        It 'Should return an empty array when static properties have no initializer expressions' {
            $file = New-TempFile 'NoInitializer.ps1' @'
class HasStaticNoInit {
    static [string] $Label
}
'@
            $ast      = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $custom = @($result | Where-Object { -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) })
            $custom.Count | Should -Be 0
        }

        It 'Should return the type referenced in a static property initializer expression' {
            $file = New-TempFile 'StaticInitType.ps1' @'
class UsesStaticInit {
    static [InitType] $Default = [InitType]::new()
}
'@
            $ast      = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $result | Should -Contain 'InitType'
        }

        It 'Should return types from multiple static initializers without duplicates' {
            $file = New-TempFile 'MultiStaticInit.ps1' @'
class MultipleInits {
    static [TypeA] $A = [TypeA]::new()
    static [TypeB] $B = [TypeB]::new()
    static [TypeA] $A2 = [TypeA]::new()
}
'@
            $ast      = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $typeACount = @($result | Where-Object { $_ -eq 'TypeA' }).Count
            $result | Should -Contain 'TypeA'
            $result | Should -Contain 'TypeB'
            $typeACount | Should -Be 1
        }
    }

    Context 'GetDefinedClassNames' {

        It 'Should return an empty array when no classes exist' {
            $file = New-TempFile 'NoClassNames.ps1' '# empty'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetDefinedClassNames($ast)

            $result.Count | Should -Be 0
        }

        It 'Should return the names of all defined classes' {
            $file = New-TempFile 'ClassNames.ps1' @'
class Alpha { }
class Beta  { }
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetDefinedClassNames($ast)

            $result | Should -Contain 'Alpha'
            $result | Should -Contain 'Beta'
        }
    }

    Context 'GetDefinedEnumNames' {

        It 'Should return an empty array when no enums exist' {
            $file = New-TempFile 'NoEnumNames.ps1' '# empty'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetDefinedEnumNames($ast)

            $result.Count | Should -Be 0
        }

        It 'Should return the names of all defined enums' {
            $file = New-TempFile 'EnumNames.ps1' @'
enum StatusEnum { Active; Inactive }
enum ColorEnum  { Red; Blue }
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetDefinedEnumNames($ast)

            $result | Should -Contain 'StatusEnum'
            $result | Should -Contain 'ColorEnum'
        }
    }

    Context 'GetBaseClasses' {

        It 'Should return an empty array when class has no base class' {
            $file = New-TempFile 'NoBase.ps1' 'class MyClass { }'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetBaseClasses($classAst)

            $result.Count | Should -Be 0
        }

        It 'Should return the base class name when class inherits' {
            $file = New-TempFile 'WithBase.ps1' 'class Child : ParentClass { }'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetBaseClasses($classAst)

            $result.Count | Should -Be 1
            $result[0] | Should -Be 'ParentClass'
        }

        It 'Should return only the base class name, not the derived class name' {
            $file = New-TempFile 'BaseNotSelf.ps1' 'class Child : Base { }'
            $ast  = [PSScriptBuilderAstEngine]::ParseFile($file)
            $classAst = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetBaseClasses($classAst)

            $result | Should -Not -Contain 'Child'
            $result | Should -Contain 'Base'
        }
    }

    Context 'GetFunctionCalls' {

        It 'Should return an empty array for an empty function body' {
            $file = New-TempFile 'EmptyFunc.ps1' @'
Function Do-Nothing {
    [CmdletBinding()]
    param()
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)

            $result.Count | Should -Be 0
        }

        It 'Should return the names of called functions' {
            $file = New-TempFile 'FuncCalls.ps1' @'
Function Do-Work {
    [CmdletBinding()]
    param()
    Get-Item -Path 'C:\temp'
    Write-Verbose 'done'
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)

            $result | Should -Contain 'Get-Item'
            $result | Should -Contain 'Write-Verbose'
        }

        It 'Should return each function name only once when called multiple times' {
            $file = New-TempFile 'DupCalls.ps1' @'
Function Do-Work {
    [CmdletBinding()]
    param()
    Write-Verbose 'first'
    Write-Verbose 'second'
    Write-Verbose 'third'
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)
            $count  = @($result | Where-Object { $_ -eq 'Write-Verbose' }).Count

            $count | Should -Be 1
        }

        It 'Should find calls inside a class method body' {
            $file = New-TempFile 'ClassCalls.ps1' @'
class MyClass {
    [void] Run() {
        Get-Date
    }
}
'@
            $ast = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)

            $result | Should -Contain 'Get-Date'
        }
    }
}
