using namespace System
using namespace System.IO
using namespace System.Management.Automation.Language

Describe 'PSScriptBuilderAstEngine' {

    Context 'ParseFile' {

        It 'Should return a PSScriptBuilderParseResult for a valid file' {
            $file   = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\ClassA.ps1'

            $result = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result.GetType().Name    | Should -Be 'PSScriptBuilderParseResult'
            $result.Ast               | Should -Not -BeNullOrEmpty
            $result.ParseErrors.Count | Should -Be 0
        }

        It 'Should throw FileNotFoundException for a non-existent file' {
            $missing = Join-Path $TestDrive 'DoesNotExist.ps1'

            { [PSScriptBuilderAstEngine]::ParseFile($missing) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }

        It 'Should report parse errors for a file with a genuine parse error' {
            $file   = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\ClassWithParseError.ps1'

            $result = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result.ParseErrors.Count | Should -BeGreaterThan 0
            $result.Ast               | Should -Not -BeNullOrEmpty
        }

        It 'Should report parse errors for a PS5.1 reserved method name but produce no class definitions' -Skip:($PSVersionTable.PSVersion.Major -ne 5) {
            $file   = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\ClassWithReservedMethodName.ps1'

            $result = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result.ParseErrors.Count                                             | Should -BeGreaterThan 0
            ([PSScriptBuilderAstEngine]::FindClassDefinitions($result.Ast)).Count | Should -Be 0
        }

        It 'Should return parse errors for TypeNotFound but still find the definition in the AST' {
            $file   = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\ClassWithTypeRefToB.ps1'

            $result = [PSScriptBuilderAstEngine]::ParseFile($file)

            $result.ParseErrors.Count                                             | Should -BeGreaterThan 0
            $result.Ast                                                           | Should -Not -BeNullOrEmpty
            ([PSScriptBuilderAstEngine]::FindClassDefinitions($result.Ast)).Count | Should -BeGreaterThan 0
        }
    }

    Context 'FindUsingStatements' {

        It 'Should return an empty array when no using statements are present' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindUsingStatements($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a single using statement' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Using\OneUsing.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindUsingStatements($ast)

            $result.Count | Should -Be 1
        }

        It 'Should find multiple using statements' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Using\MultiUsing.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindUsingStatements($ast)

            $result.Count | Should -Be 3
        }
    }

    Context 'FindEnumDefinitions' {

        It 'Should return an empty array when no enums are present' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a single enum definition' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Enums\EnumA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'EnumA'
        }

        It 'Should find multiple enum definitions' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Enums\TwoEnums.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 2
        }

        It 'Should not return classes when searching for enums' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

            $result.Count | Should -Be 0
        }
    }

    Context 'FindClassDefinitions' {

        It 'Should return an empty array when no classes are present' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Enums\EnumA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a single class definition' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'ClassA'
        }

        It 'Should find multiple class definitions' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassAlphaBeta.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 2
        }

        It 'Should not return enums when searching for classes' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Enums\EnumA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

            $result.Count | Should -Be 0
        }
    }

    Context 'FindFunctionDefinitions' {

        It 'Should return an empty array when no functions are present' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find a standalone function' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Get-FuncA'
        }

        It 'Should not return class methods as standalone functions' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassCallsFuncA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 0
        }

        It 'Should find standalone functions but not class methods in a mixed file' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassAndFunction.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Get-Standalone'
        }
    }

    Context 'ExtractSourceCode' {

        It 'Should return the exact source text of a class definition' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classDef    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $source = [PSScriptBuilderAstEngine]::ExtractSourceCode($classDef)

            $source | Should -Match 'ClassA'
        }

        It 'Should return the exact source text of an enum definition' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Enums\EnumA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $enumDef     = ([PSScriptBuilderAstEngine]::FindEnumDefinitions($ast))[0]

            $source = [PSScriptBuilderAstEngine]::ExtractSourceCode($enumDef)

            $source | Should -Match 'EnumA'
        }

        It 'Should return the exact source text of a function definition' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncGetSample.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $funcDef     = ([PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast))[0]

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
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            # Filter out builtins to get only custom types
            $custom = @($result | Where-Object { -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) })
            $custom.Count | Should -Be 0
        }

        It 'Should detect a custom type used as a parameter type' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncWithCustomTypeParam.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'MyCustomType'
        }

        It 'Should not return duplicate type references' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncWithDuplicateTypeParam.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)
            $myTypeCount = @($result | Where-Object { $_ -eq 'MyType' }).Count

            $myTypeCount | Should -Be 1
        }

        It 'Should extract a custom type from a generic type parameter' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassGenericUser.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'MyCustomType'
        }

        It 'Should extract the exception type from a catch clause' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncWithCatchClause.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'MyCustomException'
        }

        It 'Should not include types used exclusively in a static property initializer expression' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassWithStaticInitOfB.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($classAst)

            $result | Should -Not -Contain 'ClassB'
        }

        It 'Should include types used in both a static initializer and a method body' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassSharedType.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($classAst)

            $result | Should -Contain 'SharedType'
        }

        It 'Should not include types from a non-class-member static init (standalone function is unaffected)' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncWithStandaloneType.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetTypeReferences($ast)

            $result | Should -Contain 'StandaloneType'
        }
    }

    Context 'GetStaticInitializerTypeReferences' {

        It 'Should return an empty array when class has no static properties' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $custom = @($result | Where-Object { -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) })
            $custom.Count | Should -Be 0
        }

        It 'Should return an empty array when static properties have no initializer expressions' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassNoStaticInit.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $custom = @($result | Where-Object { -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) })
            $custom.Count | Should -Be 0
        }

        It 'Should return the type referenced in a static property initializer expression' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassWithStaticInitOfB.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $result | Should -Contain 'ClassB'
        }

        It 'Should return types from multiple static initializers without duplicates' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassMultipleStaticInits.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classAst)

            $typeACount = @($result | Where-Object { $_ -eq 'TypeA' }).Count
            $result | Should -Contain 'TypeA'
            $result | Should -Contain 'TypeB'
            $typeACount | Should -Be 1
        }
    }

    Context 'GetDefinedClassNames' {

        It 'Should return an empty array when no classes exist' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Enums\EnumA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetDefinedClassNames($ast)

            $result.Count | Should -Be 0
        }

        It 'Should return the names of all defined classes' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassAlphaBeta.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetDefinedClassNames($ast)

            $result | Should -Contain 'Alpha'
            $result | Should -Contain 'Beta'
        }
    }

    Context 'GetDefinedEnumNames' {

        It 'Should return an empty array when no enums exist' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetDefinedEnumNames($ast)

            $result.Count | Should -Be 0
        }

        It 'Should return the names of all defined enums' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Enums\TwoEnums.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetDefinedEnumNames($ast)

            $result | Should -Contain 'StatusEnum'
            $result | Should -Contain 'ColorEnum'
        }
    }

    Context 'GetBaseClasses' {

        It 'Should return an empty array when class has no base class' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetBaseClasses($classAst)

            $result.Count | Should -Be 0
        }

        It 'Should return the base class name when class inherits' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassDerivedFromA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetBaseClasses($classAst)

            $result.Count | Should -Be 1
            $result[0] | Should -Be 'ClassA'
        }

        It 'Should return only the base class name, not the derived class name' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassDerivedFromA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast
            $classAst    = ([PSScriptBuilderAstEngine]::FindClassDefinitions($ast))[0]

            $result = [PSScriptBuilderAstEngine]::GetBaseClasses($classAst)

            $result | Should -Not -Contain 'ClassDerivedFromA'
            $result | Should -Contain 'ClassA'
        }
    }

    Context 'GetFunctionCalls' {

        It 'Should return an empty array for an empty function body' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)

            $result.Count | Should -Be 0
        }

        It 'Should return the names of called functions' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncWithGetItemAndVerbose.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)

            $result | Should -Contain 'Get-Item'
            $result | Should -Contain 'Write-Verbose'
        }

        It 'Should return each function name only once when called multiple times' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Functions\FuncWithDuplicateVerbose.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)
            $count  = @($result | Where-Object { $_ -eq 'Write-Verbose' }).Count

            $count | Should -Be 1
        }

        It 'Should find calls inside a class method body' {
            $file        = Join-Path $PSScriptRoot '..\..\..\.\TestData\Classes\ClassCallsFuncA.ps1'
            $parseResult = [PSScriptBuilderAstEngine]::ParseFile($file)
            $ast         = $parseResult.Ast

            $result = [PSScriptBuilderAstEngine]::GetFunctionCalls($ast)

            $result | Should -Contain 'Get-FuncA'
        }
    }
}

