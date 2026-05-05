using namespace System
using namespace System.IO

Describe 'PSScriptBuilderTemplateProcessor' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        # Builds a ContentCollector, adds the given collectors, executes it and returns it
        Function New-ExecutedCC {
            param([PSScriptBuilderCollectorBase[]] $Collectors)
            $cc = [PSScriptBuilderContentCollector]::new()
            foreach ($c in $Collectors) { $cc.AddCollector($c) }
            $cc.Execute()
            return $cc
        }

        Function New-ClassCollectorWithFile {
            param([string] $Key = 'CLASS_DEFINITIONS', [string] $FilePath)
            $c = [PSScriptBuilderClassCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-EnumCollectorWithFile {
            param([string] $Key = 'ENUM_DEFINITIONS', [string] $FilePath)
            $c = [PSScriptBuilderEnumCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-FunctionCollectorWithFile {
            param([string] $Key = 'FUNCTION_DEFINITIONS', [string] $FilePath)
            $c = [PSScriptBuilderFunctionCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-UsingCollectorWithFile {
            param([string] $Key = 'USING_STATEMENTS', [string] $FilePath)
            $c = [PSScriptBuilderUsingCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Constructor - parameter guards' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderTemplateProcessor]::new($null, '{{CLASS_DEFINITIONS}}', 'ORDERED_COMPONENTS', $false) } | Should -Throw
        }

        It 'Should throw ArgumentException when templateContent is empty' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderTemplateProcessor]::new($cc, '', 'ORDERED_COMPONENTS', $false) } | Should -Throw
        }

        It 'Should throw ArgumentException when orderedComponentsKey is empty' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderTemplateProcessor]::new($cc, '{{CLASS_DEFINITIONS}}', '', $false) } | Should -Throw
        }

        It 'Should throw when template is invalid (missing collector placeholder in Free mode)' {
            $classFile = New-TestFile 'GuardClass.ps1' 'class GuardClass { }'
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            # Template missing {{CLASS_DEFINITIONS}} -> validator should throw
            { [PSScriptBuilderTemplateProcessor]::new($cc, '# no placeholders', 'ORDERED_COMPONENTS', $false) } | Should -Throw
        }
    }

    Context 'Render - Free mode' {

        It 'Should replace a single Class placeholder with collected source code' {
            $classFile = New-TestFile 'RenderClass.ps1' "class RenderClass {`n    [string] `$Name`n}"
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = "{{CLASS_DEFINITIONS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $false)

            $result = $processor.Render(@())

            $result | Should -Match 'class RenderClass'
            $result | Should -Not -Match '\{\{CLASS_DEFINITIONS\}\}'
        }

        It 'Should replace Enum and Class placeholders maintaining template structure' {
            $enumFile  = New-TestFile 'FreeEnum.ps1'  'enum FreeEnum { A; B }'
            $classFile = New-TestFile 'FreeClass.ps1' 'class FreeClass { }'

            $enumC  = New-EnumCollectorWithFile  -FilePath $enumFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($enumC, $classC)

            $template  = "{{ENUM_DEFINITIONS}}`n---`n{{CLASS_DEFINITIONS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $false)

            $result = $processor.Render(@())

            $result | Should -Match 'enum FreeEnum'
            $result | Should -Match 'class FreeClass'
            $result | Should -Match '\-\-\-'
        }

        It 'Should respect orderedComponents for dependency-ordered output in Free mode' {
            $content   = "class ZClass { }`nclass AClass { }"
            $classFile = New-TestFile 'OrderedFreeClass.ps1' $content
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = "{{CLASS_DEFINITIONS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $false)

            # Pass ordered list: AClass before ZClass
            $result = $processor.Render(@('AClass', 'ZClass'))

            $result.IndexOf('AClass') | Should -BeLessThan ($result.IndexOf('ZClass'))
        }

        It 'Should replace Using placeholder with consolidated Using statements' {
            $usingFile = New-TestFile 'FreeUsing.ps1' "using namespace System`nusing namespace System.IO"
            $classFile = New-TestFile 'FreeUsingClass.ps1' 'class FreeUsingClass { }'

            $usingC = New-UsingCollectorWithFile -FilePath $usingFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($usingC, $classC)

            $template  = "{{USING_STATEMENTS}}`n{{CLASS_DEFINITIONS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $false)

            $result = $processor.Render(@())

            $result | Should -Match 'using namespace System'
            $result | Should -Not -Match '\{\{USING_STATEMENTS\}\}'
        }
    }

    Context 'Render - Ordered mode' {

        It 'Should replace ORDERED_COMPONENTS placeholder with dependency-sorted source code' {
            $classFile = New-TestFile 'CrossClass.ps1' 'class CrossClass { }'
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = "{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            $result = $processor.Render(@('CrossClass'))

            $result | Should -Match 'class CrossClass'
            $result | Should -Not -Match '\{\{ORDERED_COMPONENTS\}\}'
        }

        It 'Should replace Using placeholder before ORDERED_COMPONENTS in Ordered mode' {
            $usingFile = New-TestFile 'CrossUsing.ps1' 'using namespace System'
            $classFile = New-TestFile 'CrossClassU.ps1' 'class CrossUClass { }'

            $usingC = New-UsingCollectorWithFile -FilePath $usingFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($usingC, $classC)

            $template  = "{{USING_STATEMENTS}}`n{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            $result = $processor.Render(@('CrossUClass'))

            $result | Should -Match 'using namespace System'
            $result | Should -Match 'class CrossUClass'
        }

        It 'Should output components in orderedComponents sequence' {
            $content   = "class ZCross { }`nclass ACross { }"
            $classFile = New-TestFile 'CrossOrder.ps1' $content
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = "{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            $result = $processor.Render(@('ACross', 'ZCross'))

            $result.IndexOf('ACross') | Should -BeLessThan ($result.IndexOf('ZCross'))
        }

        It 'Should produce comment when orderedComponents is empty' {
            $cc       = [PSScriptBuilderContentCollector]::new()
            $template = "{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            $result = $processor.Render(@())

            $result | Should -Match '# No components'
        }

        It 'Should throw InvalidOperationException when orderedComponents contains an unknown component name' {
            $classFile = New-TestFile 'KnownClass.ps1' 'class KnownClass { }'
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = "{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            { $processor.Render(@('NonExistentComponent')) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'Render - Hybrid Free+Ordered mode ($UseOrderedMode = $true, HasCrossDependencies = $false)' {

        It 'Should replace ORDERED_COMPONENTS with class source code in Hybrid mode' {
            $classFile = New-TestFile 'HybridClass.ps1' 'class HybridClass { }'
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = '{{ORDERED_COMPONENTS}}'
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            $result = $processor.Render(@('HybridClass'))

            $result | Should -Match 'class HybridClass'
            $result | Should -Not -Match '\{\{ORDERED_COMPONENTS\}\}'
        }

        It 'Should output two classes in dependency order in Hybrid mode' {
            $content   = "class ZHybrid { }`nclass AHybrid { }"
            $classFile = New-TestFile 'HybridOrder.ps1' $content
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = '{{ORDERED_COMPONENTS}}'
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            $result = $processor.Render(@('AHybrid', 'ZHybrid'))

            $result.IndexOf('AHybrid') | Should -BeLessThan ($result.IndexOf('ZHybrid'))
        }

        It 'Should replace Using and ORDERED_COMPONENTS in Hybrid mode' {
            $usingFile = New-TestFile 'HybridUsing.ps1' 'using namespace System'
            $classFile = New-TestFile 'HybridUsingClass.ps1' 'class HybridUsingClass { }'

            $usingC = New-UsingCollectorWithFile -FilePath $usingFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($usingC, $classC)

            $template  = "{{USING_STATEMENTS}}`n{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)

            $result = $processor.Render(@('HybridUsingClass'))

            $result | Should -Match 'using namespace System'
            $result | Should -Match 'class HybridUsingClass'
        }
    }
}
