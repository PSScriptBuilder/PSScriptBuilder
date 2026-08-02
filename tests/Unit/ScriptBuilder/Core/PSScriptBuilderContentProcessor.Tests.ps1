using namespace System
using namespace System.IO

Describe 'PSScriptBuilderContentProcessor' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        # Builds a ContentCollector with the specified collector added and Execute() already called
        Function New-ExecutedCC {
            param([PSScriptBuilderCollectorBase] $Collector)
            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($Collector)
            $cc.Execute()
            return $cc
        }

        Function New-Processor {
            param([PSScriptBuilderContentCollector] $ContentCollector)
            return [PSScriptBuilderContentProcessor]::new($ContentCollector)
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Constructor' {

        It 'Should throw ArgumentNullException when ContentCollector is null' {
            { [PSScriptBuilderContentProcessor]::new($null) } | Should -Throw
        }

        It 'Should store the provided ContentCollector' {
            $cc        = [PSScriptBuilderContentCollector]::new()
            $processor = New-Processor -ContentCollector $cc

            $processor.ContentCollector | Should -Not -BeNullOrEmpty
        }
    }

    Context 'GetConsolidatedUsingStatements' {

        It 'Should return empty string when no UsingCollectors are registered' {
            $cc        = [PSScriptBuilderContentCollector]::new()
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.GetConsolidatedUsingStatements()

            $result | Should -BeNullOrEmpty
        }

        It 'Should return a single Using statement' {
            $file      = New-TestFile 'Using.ps1' 'using namespace System'
            $collector = [PSScriptBuilderUsingCollector]::new('Usings')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.GetConsolidatedUsingStatements()

            $result.Trim() | Should -Be 'using namespace System'
        }

        It 'Should deduplicate identical Using statements across collectors' {
            $file1 = New-TestFile 'Using1.ps1' 'using namespace System'
            $file2 = New-TestFile 'Using2.ps1' 'using namespace System'

            $c1 = [PSScriptBuilderUsingCollector]::new('Usings1')
            $c1.IncludeFiles = @($file1)
            $c2 = [PSScriptBuilderUsingCollector]::new('Usings2')
            $c2.IncludeFiles = @($file2)

            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($c1)
            $cc.AddCollector($c2)
            $cc.Execute()

            $processor = New-Processor -ContentCollector $cc

            $result = $processor.GetConsolidatedUsingStatements()
            $lines  = ($result -split [Environment]::NewLine) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $lines.Count | Should -Be 1
        }

        It 'Should sort multiple Using statements alphabetically' {
            $content = @"
using namespace System.IO
using namespace System
using namespace System.Collections.Generic
"@
            $file      = New-TestFile 'MultiUsing.ps1' $content
            $collector = [PSScriptBuilderUsingCollector]::new('Usings')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.GetConsolidatedUsingStatements()
            $lines  = ($result -split [Environment]::NewLine) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $lines[0] | Should -Be 'using namespace System'
            $lines[1] | Should -Be 'using namespace System.Collections.Generic'
            $lines[2] | Should -Be 'using namespace System.IO'
        }
    }

    Context 'BuildCollectorContent - null guard' {

        It 'Should throw ArgumentNullException when collector is null' {
            $cc        = [PSScriptBuilderContentCollector]::new()
            $processor = New-Processor -ContentCollector $cc

            { $processor.BuildCollectorContent($null, @()) } | Should -Throw
        }
    }

    Context 'BuildCollectorContent - Enum collector' {

        It 'Should return comment string when enum collector is empty' {
            $file      = New-TestFile 'EmptyEnum.ps1' '# no enums here'
            $collector = [PSScriptBuilderEnumCollector]::new('Enums')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @())

            $result | Should -Match '# No enums'
        }

        It 'Should return enum source code when enums are collected' {
            $file      = New-TestFile 'WithEnum.ps1' "enum BuildEnum { Alpha; Beta }"
            $collector = [PSScriptBuilderEnumCollector]::new('Enums')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @())

            $result | Should -Match 'enum BuildEnum'
        }

        It 'Should use orderedComponents order when provided' {
            $content = @"
enum ZEnum { Z }
enum AEnum { A }
"@
            $file      = New-TestFile 'OrderedEnums.ps1' $content
            $collector = [PSScriptBuilderEnumCollector]::new('Enums')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @('AEnum', 'ZEnum'))

            $result.IndexOf('AEnum') | Should -BeLessThan ($result.IndexOf('ZEnum'))
        }
    }

    Context 'BuildCollectorContent - Class collector' {

        It 'Should return comment string when class collector is empty' {
            $file      = New-TestFile 'EmptyClass.ps1' '# no classes here'
            $collector = [PSScriptBuilderClassCollector]::new('Classes')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @())

            $result | Should -Match '# No classes'
        }

        It 'Should return class source code when classes are collected' {
            $file      = New-TestFile 'WithClass.ps1' "class BuildClass {`n    [string] `$Name`n}"
            $collector = [PSScriptBuilderClassCollector]::new('Classes')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @())

            $result | Should -Match 'class BuildClass'
        }
    }

    Context 'BuildCollectorContent - Function collector' {

        It 'Should return comment string when function collector is empty' {
            $file      = New-TestFile 'EmptyFn.ps1' '# no functions here'
            $collector = [PSScriptBuilderFunctionCollector]::new('Functions')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @())

            $result | Should -Match '# No functions'
        }

        It 'Should return function source code when functions are collected' {
            $file      = New-TestFile 'WithFn.ps1' "Function Get-BuildThing {`n    param()`n}"
            $collector = [PSScriptBuilderFunctionCollector]::new('Functions')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @())

            $result | Should -Match 'Function Get-BuildThing'
        }
    }

    Context 'BuildCollectorContent - File collector' {

        It 'Should return comment string when file collector is empty' {
            $file      = New-TestFile 'EmptyFileColl.ps1' ''
            $collector = [PSScriptBuilderFileCollector]::new('Files')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            # FileCollector collects file content; empty file content -> Files have data but content is empty
            # If FileData is empty the early-return comment is returned
            $emptyCollector = [PSScriptBuilderFileCollector]::new('FilesEmpty')
            $result = $processor.BuildCollectorContent($emptyCollector, @())

            $result | Should -Match '# No files'
        }

        It 'Should return file content when files are collected' {
            $file      = New-TestFile 'FileColl.ps1' '# script content here'
            $collector = [PSScriptBuilderFileCollector]::new('Files')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.BuildCollectorContent($collector, @())

            $result | Should -Match '# script content here'
        }
    }

    Context 'GetFileContent' {

        It 'Should throw ArgumentNullException when collector is null' {
            $cc        = [PSScriptBuilderContentCollector]::new()
            $processor = New-Processor -ContentCollector $cc

            { $processor.GetFileContent($null) } | Should -Throw
        }

        It 'Should return concatenated file content' {
            $file      = New-TestFile 'GetFileColl.ps1' '# file content'
            $collector = [PSScriptBuilderFileCollector]::new('Files')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.GetFileContent($collector)

            $result | Should -Match '# file content'
        }
    }

    Context 'GetComponentSourceCode' {

        It 'Should delegate to ContentCollector and return source code' {
            $file      = New-TestFile 'ProcSrc.ps1' "class ProcSrcClass {`n    [string] `$Name`n}"
            $collector = [PSScriptBuilderClassCollector]::new('Classes')
            $collector.IncludeFiles = @($file)

            $cc        = New-ExecutedCC -Collector $collector
            $processor = New-Processor -ContentCollector $cc

            $result = $processor.GetComponentSourceCode('ProcSrcClass')

            $result | Should -Match 'class ProcSrcClass'
        }

        It 'Should throw when component is not found' {
            $cc        = [PSScriptBuilderContentCollector]::new()
            $processor = New-Processor -ContentCollector $cc

            { $processor.GetComponentSourceCode('NoSuch') } | Should -Throw
        }
    }
}
