using namespace System
using namespace System.IO
using namespace System.Text.RegularExpressions

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

        Function New-FileCollectorWithFile {
            param([string] $Key = 'FILE_CONTENTS', [string] $FilePath)
            $c = [PSScriptBuilderFileCollector]::new($Key)
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

        It 'Should consolidate overlapping Using collectors without duplicating any statement' {
            $usingFileA = New-TestFile 'OverlapUsingA.ps1' "using namespace System.Collections.Generic`nusing namespace System.Text"
            $usingFileB = New-TestFile 'OverlapUsingB.ps1' "using namespace System.Collections.Generic`nusing namespace System.Net"

            $usingA = New-UsingCollectorWithFile -Key 'UsingA' -FilePath $usingFileA
            $usingB = New-UsingCollectorWithFile -Key 'UsingB' -FilePath $usingFileB
            $cc     = New-ExecutedCC -Collectors @($usingA, $usingB)

            $template  = "{{UsingA}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $false)

            $result = $processor.Render(@())

            ([regex]::Matches($result, [regex]::Escape('using namespace System.Collections.Generic'))).Count | Should -Be 1
            $result | Should -Match ([regex]::Escape('using namespace System.Text'))
            $result | Should -Match ([regex]::Escape('using namespace System.Net'))
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

    Context 'RFC 0002 - ordered-components-key collision' {

        It 'Should throw a collision-specific error when a Class collector uses the reserved ordered-components key' {
            $classFile = New-TestFile 'RFC0002Class.ps1' 'class RFC0002Class { }'
            $collector = New-ClassCollectorWithFile -Key 'ORDERED_COMPONENTS' -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)
            $template  = '{{ORDERED_COMPONENTS}}'

            { [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true) } |
                Should -Throw -ExpectedMessage '*collides with the reserved ordered-components*'
        }

        It 'Should reject a File collector using the reserved ordered-components key at validation, not silently corrupt output' {
            $fileFile  = New-TestFile 'RFC0002File.ps1' '# Documentation note: this project uses {{ORDERED_COMPONENTS}} in its template.'
            $collector = New-FileCollectorWithFile -Key 'ORDERED_COMPONENTS' -FilePath $fileFile
            $cc        = New-ExecutedCC -Collectors @($collector)
            $template  = '{{ORDERED_COMPONENTS}}'

            { [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true) } | Should -Throw
        }

        It 'Should not silently discard the ordered-components block when a Using collector uses the reserved key' {
            $usingFile = New-TestFile 'RFC0002Using.ps1' 'using namespace System.Collections.Generic'
            $classFile = New-TestFile 'RFC0002UsingClass.ps1' 'class RFC0002UsingClass { }'

            $usingC = New-UsingCollectorWithFile -Key 'ORDERED_COMPONENTS' -FilePath $usingFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($usingC, $classC)

            $template = '{{ORDERED_COMPONENTS}}'

            { [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true) } | Should -Throw
        }

        It 'Should throw a collision-specific error when the colliding CollectionKey differs only in case' {
            $classFile = New-TestFile 'RFC0002CaseClass.ps1' 'class RFC0002CaseClass { }'
            $collector = New-ClassCollectorWithFile -Key 'ordered_components' -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)
            $template  = '{{ordered_components}}'

            { [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true) } |
                Should -Throw -ExpectedMessage '*collides with the reserved ordered-components*'
        }

        It 'Should still fail with the missing-placeholder error in Free Mode when a colliding collectors own placeholder is absent' {
            $classFile = New-TestFile 'RFC0002FreeModeClass.ps1' 'class RFC0002FreeModeClass { }'
            $collector = New-ClassCollectorWithFile -Key 'ORDERED_COMPONENTS' -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)
            $template  = 'no placeholder here at all'

            { [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $false) } |
                Should -Throw -ExpectedMessage '*does not contain placeholders*'
        }
    }

    Context 'RFC 0003 - Ordered/Hybrid Mode template injection' {

        It 'Should not duplicate a class into File content that happens to mention ORDERED_COMPONENTS' {
            $headerFile = New-TestFile 'RFC0003Header.ps1' '# Documentation note: this project uses {{ORDERED_COMPONENTS}} in its template.'
            $classFile  = New-TestFile 'RFC0003Widget.ps1' 'class RFC0003Widget { [string] $Name }'

            $fileC  = New-FileCollectorWithFile -FilePath $headerFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($fileC, $classC)

            $template  = "{{FILE_CONTENTS}}`n{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)
            $result    = $processor.Render(@('RFC0003Widget'))

            ([Regex]::Matches($result, 'class RFC0003Widget')).Count | Should -Be 1
        }

        It 'Should not duplicate or corrupt content when one File collector mentions another File placeholder' {
            $file1 = New-TestFile 'RFC0003File1.ps1' '# Note: this project also has {{FILE_CONTENT2}} elsewhere.'
            $file2 = New-TestFile 'RFC0003File2.ps1' '# This is the real second files content.'

            $fileC1 = New-FileCollectorWithFile -Key 'FILE_CONTENT1' -FilePath $file1
            $fileC2 = New-FileCollectorWithFile -Key 'FILE_CONTENT2' -FilePath $file2
            $cc     = New-ExecutedCC -Collectors @($fileC1, $fileC2)

            $template  = "{{FILE_CONTENT1}}`n{{FILE_CONTENT2}}`n{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)
            $result    = $processor.Render(@())

            ([Regex]::Matches($result, 'real second files content')).Count | Should -Be 1
            $result | Should -Match ([Regex]::Escape('# Note: this project also has {{FILE_CONTENT2}} elsewhere.'))
        }
    }

    Context 'RFC 0004 - placeholder case-sensitivity mismatch' {

        It 'Should replace a differently-cased placeholder in Free Mode' {
            $classFile = New-TestFile 'RFC0004Class.ps1' 'class RFC0004Class { }'
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = '{{class_definitions}}'
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $false)
            $result    = $processor.Render(@())

            $result | Should -Match 'class RFC0004Class'
            $result | Should -Not -Match '\{\{class_definitions\}\}'
        }

        It 'Should replace a differently-cased Using placeholder in Ordered/Hybrid Mode' {
            $usingFile = New-TestFile 'RFC0004Using.ps1' 'using namespace System'
            $classFile = New-TestFile 'RFC0004UsingClass.ps1' 'class RFC0004UsingClass { }'

            $usingC = New-UsingCollectorWithFile -FilePath $usingFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($usingC, $classC)

            $template  = "{{using_statements}}`n{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)
            $result    = $processor.Render(@('RFC0004UsingClass'))

            $result | Should -Match 'using namespace System'
            $result | Should -Not -Match '\{\{using_statements\}\}'
        }

        It 'Should replace a differently-cased File placeholder in Ordered/Hybrid Mode' {
            $fileFile  = New-TestFile 'RFC0004File.ps1' 'file content for RFC0004'
            $classFile = New-TestFile 'RFC0004FileClass.ps1' 'class RFC0004FileClass { }'

            $fileC  = New-FileCollectorWithFile -Key 'DOC_FILE' -FilePath $fileFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ExecutedCC -Collectors @($fileC, $classC)

            $template  = "{{doc_file}}`n{{ORDERED_COMPONENTS}}"
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'ORDERED_COMPONENTS', $true)
            $result    = $processor.Render(@('RFC0004FileClass'))

            $result | Should -Match 'file content for RFC0004'
            $result | Should -Not -Match '\{\{doc_file\}\}'
        }

        It 'Should replace a differently-cased placeholder for a custom OrderedComponentsKey' {
            $classFile = New-TestFile 'RFC0004CustomKey.ps1' 'class RFC0004CustomKey { }'
            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ExecutedCC -Collectors @($collector)

            $template  = '{{my_components}}'
            $processor = [PSScriptBuilderTemplateProcessor]::new($cc, $template, 'MY_COMPONENTS', $true)
            $result    = $processor.Render(@('RFC0004CustomKey'))

            $result | Should -Match 'class RFC0004CustomKey'
            $result | Should -Not -Match '\{\{my_components\}\}'
        }
    }
}
