using namespace System
using namespace System.IO

Describe 'PSScriptBuilderBuildDataAggregator' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-ExecutedCC {
            param([PSScriptBuilderCollectorBase[]] $Collectors)
            $cc = [PSScriptBuilderContentCollector]::new()
            foreach ($c in $Collectors) {
                $cc.AddCollector($c)
            }
            $cc.Execute()
            return $cc
        }

        Function New-Aggregator {
            param([PSScriptBuilderContentCollector] $CC)
            return [PSScriptBuilderBuildDataAggregator]::new($CC)
        }

        # Creates a ClassCollector that has collected one class from a temp file
        Function New-ClassCollector {
            param([string] $Key = 'Classes', [string] $ClassName = 'MyClass')
            $file = New-TestFile "$Key-$ClassName.ps1" "class $ClassName { }"
            $c = [PSScriptBuilderClassCollector]::new($Key)
            $c.IncludeFiles = @($file)
            return $c
        }

        # Creates an EnumCollector that has collected one enum from a temp file
        Function New-EnumCollector {
            param([string] $Key = 'Enums', [string] $EnumName = 'MyEnum')
            $file = New-TestFile "$Key-$EnumName.ps1" "enum $EnumName { Value1 }"
            $c = [PSScriptBuilderEnumCollector]::new($Key)
            $c.IncludeFiles = @($file)
            return $c
        }

        # Creates a FunctionCollector that has collected one function from a temp file
        Function New-FunctionCollector {
            param([string] $Key = 'Functions', [string] $FunctionName = 'Get-Something')
            $file = New-TestFile "$Key-$FunctionName.ps1" "Function $FunctionName { }"
            $c = [PSScriptBuilderFunctionCollector]::new($Key)
            $c.IncludeFiles = @($file)
            return $c
        }

        # Creates a UsingCollector that has collected one using statement from a temp file
        Function New-UsingCollector {
            param([string] $Key = 'Usings')
            $file = New-TestFile "$Key.ps1" 'using namespace System'
            $c = [PSScriptBuilderUsingCollector]::new($Key)
            $c.IncludeFiles = @($file)
            return $c
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Constructor
    Context 'Constructor' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderBuildDataAggregator]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should accept a valid ContentCollector' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderBuildDataAggregator]::new($cc) } |
                Should -Not -Throw
        }
    }
    #endregion Constructor

    #region GetComponentCounts
    Context 'GetComponentCounts - empty collector' {

        It 'Should return a BuildComponentCounts object with all zeros when no collectors are registered' {
            $cc         = [PSScriptBuilderContentCollector]::new()
            $aggregator = New-Aggregator -CC $cc

            $counts = $aggregator.GetComponentCounts()

            $counts                   | Should -Not -BeNullOrEmpty
            $counts.UsingStatements   | Should -Be 0
            $counts.EnumDefinitions   | Should -Be 0
            $counts.ClassDefinitions  | Should -Be 0
            $counts.FunctionDefinitions | Should -Be 0
            $counts.FileContents      | Should -Be 0
        }
    }

    Context 'GetComponentCounts - with collectors' {

        It 'Should count class definitions correctly' {
            $cc         = New-ExecutedCC -Collectors @(New-ClassCollector -Key 'CC-ClassCount' -ClassName 'CountClass')
            $aggregator = New-Aggregator -CC $cc

            $counts = $aggregator.GetComponentCounts()

            $counts.ClassDefinitions | Should -Be 1
        }

        It 'Should count enum definitions correctly' {
            $cc         = New-ExecutedCC -Collectors @(New-EnumCollector -Key 'CC-EnumCount' -EnumName 'CountEnum')
            $aggregator = New-Aggregator -CC $cc

            $counts = $aggregator.GetComponentCounts()

            $counts.EnumDefinitions | Should -Be 1
        }

        It 'Should count function definitions correctly' {
            $cc         = New-ExecutedCC -Collectors @(New-FunctionCollector -Key 'CC-FuncCount' -FunctionName 'Get-CountFunc')
            $aggregator = New-Aggregator -CC $cc

            $counts = $aggregator.GetComponentCounts()

            $counts.FunctionDefinitions | Should -Be 1
        }

        It 'Should count using statements correctly' {
            $cc         = New-ExecutedCC -Collectors @(New-UsingCollector -Key 'CC-UsingCount')
            $aggregator = New-Aggregator -CC $cc

            $counts = $aggregator.GetComponentCounts()

            $counts.UsingStatements | Should -Be 1
        }

        It 'Should count file contents correctly' {
            $file = New-TestFile 'CC-FileCount.ps1' '# some file content'
            $c = [PSScriptBuilderFileCollector]::new('CC-FileCount')
            $c.IncludeFiles = @($file)
            $cc         = New-ExecutedCC -Collectors @($c)
            $aggregator = New-Aggregator -CC $cc

            $counts = $aggregator.GetComponentCounts()

            $counts.FileContents | Should -Be 1
        }

        It 'Should aggregate counts across multiple collector types' {
            $collectors = @(
                (New-ClassCollector    -Key 'CC-Multi-Class'    -ClassName    'MultiClass'),
                (New-EnumCollector     -Key 'CC-Multi-Enum'     -EnumName     'MultiEnum'),
                (New-FunctionCollector -Key 'CC-Multi-Function' -FunctionName 'Get-MultiFunc')
            )
            $cc         = New-ExecutedCC -Collectors $collectors
            $aggregator = New-Aggregator -CC $cc

            $counts = $aggregator.GetComponentCounts()

            $counts.ClassDefinitions    | Should -Be 1
            $counts.EnumDefinitions     | Should -Be 1
            $counts.FunctionDefinitions | Should -Be 1
        }
    }
    #endregion GetComponentCounts

    #region GetComponentDetails (no-arg)
    Context 'GetComponentDetails - no-arg' {

        It 'Should return an empty array when no Enum/Class/Function collectors are registered' {
            $cc         = [PSScriptBuilderContentCollector]::new()
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails()

            $details.Count | Should -Be 0
        }

        It 'Should return one detail for a single collected class' {
            $cc         = New-ExecutedCC -Collectors @(New-ClassCollector -Key 'CC-Det-Class' -ClassName 'DetailClass')
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails()

            $details.Count | Should -Be 1
            $details[0].Name | Should -Be 'DetailClass'
        }

        It 'Should return one detail for a single collected enum' {
            $cc         = New-ExecutedCC -Collectors @(New-EnumCollector -Key 'CC-Det-Enum' -EnumName 'DetailEnum')
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails()

            $details.Count | Should -Be 1
            $details[0].Name | Should -Be 'DetailEnum'
        }

        It 'Should return one detail for a single collected function' {
            $cc         = New-ExecutedCC -Collectors @(New-FunctionCollector -Key 'CC-Det-Func' -FunctionName 'Get-DetailFunc')
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails()

            $details.Count | Should -Be 1
            $details[0].Name | Should -Be 'Get-DetailFunc'
        }

        It 'Should not include Using or File collector entries in details' {
            $collectors = @(
                (New-UsingCollector -Key 'CC-Det-Using'),
                (New-ClassCollector -Key 'CC-Det-Class2' -ClassName 'OnlyClass')
            )
            $cc         = New-ExecutedCC -Collectors $collectors
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails()

            $details.Count           | Should -Be 1
            $details[0].Name         | Should -Be 'OnlyClass'
        }

        It 'Should return correct component type for each detail' {
            $collectors = @(
                (New-ClassCollector    -Key 'CC-Type-Class'    -ClassName    'TypedClass'),
                (New-EnumCollector     -Key 'CC-Type-Enum'     -EnumName     'TypedEnum'),
                (New-FunctionCollector -Key 'CC-Type-Function' -FunctionName 'Get-TypedFunc')
            )
            $cc         = New-ExecutedCC -Collectors $collectors
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails()

            $types = $details | ForEach-Object { $_.Type.ToString() }
            $types | Should -Contain 'ClassCollector'
            $types | Should -Contain 'EnumCollector'
            $types | Should -Contain 'FunctionCollector'
        }
    }
    #endregion GetComponentDetails (no-arg)

    #region GetComponentDetails (with names)
    Context 'GetComponentDetails - with names array' {

        It 'Should return only the requested component when given a specific name' {
            $collectors = @(
                (New-ClassCollector -Key 'CC-Named-A' -ClassName 'ClassA'),
                (New-ClassCollector -Key 'CC-Named-B' -ClassName 'ClassB')
            )
            $cc         = New-ExecutedCC -Collectors $collectors
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails(@('ClassA'))

            $details.Count   | Should -Be 1
            $details[0].Name | Should -Be 'ClassA'
        }

        It 'Should return an empty array when an unknown name is requested' {
            $cc         = New-ExecutedCC -Collectors @(New-ClassCollector -Key 'CC-Unknown' -ClassName 'KnownClass')
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails(@('UnknownClass'))

            $details.Count | Should -Be 0
        }

        It 'Should return an empty array when an empty names array is provided' {
            $cc         = New-ExecutedCC -Collectors @(New-ClassCollector -Key 'CC-EmptyArr' -ClassName 'AnyClass')
            $aggregator = New-Aggregator -CC $cc

            $details = $aggregator.GetComponentDetails(@())

            $details.Count | Should -Be 0
        }
    }
    #endregion GetComponentDetails (with names)

    #region GetProcessedFiles
    Context 'GetProcessedFiles' {

        It 'Should return an empty array when no collectors are registered' {
            $cc         = [PSScriptBuilderContentCollector]::new()
            $aggregator = New-Aggregator -CC $cc

            $files = $aggregator.GetProcessedFiles()

            $files.Count | Should -Be 0
        }

        It 'Should return the source file path for a collected class' {
            $file = New-TestFile 'GPF-Class.ps1' 'class GpfClass { }'
            $c    = [PSScriptBuilderClassCollector]::new('GPF-Class')
            $c.IncludeFiles = @($file)

            $cc         = New-ExecutedCC -Collectors @($c)
            $aggregator = New-Aggregator -CC $cc

            $files = $aggregator.GetProcessedFiles()

            $files.Count | Should -BeGreaterOrEqual 1
            $files        | Should -Contain $file
        }

        It 'Should return the source file path for a collected enum' {
            $file = New-TestFile 'GPF-Enum.ps1' 'enum GpfEnum { Val }'
            $c    = [PSScriptBuilderEnumCollector]::new('GPF-Enum')
            $c.IncludeFiles = @($file)

            $cc         = New-ExecutedCC -Collectors @($c)
            $aggregator = New-Aggregator -CC $cc

            $files = $aggregator.GetProcessedFiles()

            $files | Should -Contain $file
        }

        It 'Should return the source file path for a collected function' {
            $file = New-TestFile 'GPF-Func.ps1' 'Function Get-GpfFunc { }'
            $c    = [PSScriptBuilderFunctionCollector]::new('GPF-Func')
            $c.IncludeFiles = @($file)

            $cc         = New-ExecutedCC -Collectors @($c)
            $aggregator = New-Aggregator -CC $cc

            $files = $aggregator.GetProcessedFiles()

            $files | Should -Contain $file
        }

        It 'Should deduplicate files appearing in multiple collectors' {
            $sharedFile = New-TestFile 'GPF-Shared.ps1' @'
class SharedClass { }
enum SharedEnum { A }
'@
            $c1 = [PSScriptBuilderClassCollector]::new('GPF-Dedup-Class')
            $c1.IncludeFiles = @($sharedFile)
            $c2 = [PSScriptBuilderEnumCollector]::new('GPF-Dedup-Enum')
            $c2.IncludeFiles = @($sharedFile)

            $cc         = New-ExecutedCC -Collectors @($c1, $c2)
            $aggregator = New-Aggregator -CC $cc

            $files = $aggregator.GetProcessedFiles()

            ($files | Where-Object { $_ -eq $sharedFile }).Count | Should -Be 1
        }
    }
    #endregion GetProcessedFiles
}
