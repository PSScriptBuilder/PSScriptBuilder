using namespace System

Describe 'New-PSScriptBuilderTemplate' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-ClassCC {
            param([string] $Key, [string] $FilePath)
            $collector = New-PSScriptBuilderCollector -Type Class -CollectionKey $Key
            $collector.IncludeFiles = @($FilePath)
            return New-PSScriptBuilderContentCollector -Collector $collector
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Return type
    Context 'Return type' {

        It 'Should return a PSScriptBuilderTemplateGenerationResult' {
            $classFile = New-TestFile 'RT-Class.ps1' 'class RTClass { }'
            $output    = Join-Path $TestDrive 'RT-output.template'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            $result = $cc | New-PSScriptBuilderTemplate -OutputPath $output

            $result.GetType().Name | Should -Be 'PSScriptBuilderTemplateGenerationResult'
        }
    }
    #endregion Return type

    #region Parameter - ContentCollector
    Context 'Parameter - ContentCollector (pipeline)' {

        It 'Should accept ContentCollector via pipeline' {
            $classFile = New-TestFile 'Pipe-Class.ps1' 'class PipeClass { }'
            $output    = Join-Path $TestDrive 'Pipe-output.template'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            { $cc | New-PSScriptBuilderTemplate -OutputPath $output } | Should -Not -Throw
        }
    }
    #endregion Parameter - ContentCollector

    #region Parameter - OrderedComponentsKey
    Context 'Parameter - OrderedComponentsKey' {

        It 'Should use ORDERED_COMPONENTS as default key when cross-dependencies are detected' {
            # Cross-dependency: class calls a function
            $classFile    = New-TestFile 'Key-Class.ps1'    'class KeyClass { [void] Run() { Get-KeyFunc } }'
            $functionFile = New-TestFile 'Key-Function.ps1' 'Function Get-KeyFunc { }'
            $output       = Join-Path $TestDrive 'Key-output.template'

            $classCollector    = [PSScriptBuilderClassCollector]::new('CLASSES')
            $functionCollector = [PSScriptBuilderFunctionCollector]::new('FUNCTIONS')
            $classCollector.IncludeFiles    = @($classFile)
            $functionCollector.IncludeFiles = @($functionFile)
            $cc = New-PSScriptBuilderContentCollector -Collector @($classCollector, $functionCollector)

            $result = $cc | New-PSScriptBuilderTemplate -OutputPath $output

            $result.Placeholders | Should -Contain '{{ORDERED_COMPONENTS}}'
        }

        It 'Should use a custom OrderedComponentsKey when specified' {
            $classFile    = New-TestFile 'CustomKey-Class.ps1'    'class CustomKeyClass { [void] Run() { Get-CustomKeyFunc } }'
            $functionFile = New-TestFile 'CustomKey-Function.ps1' 'Function Get-CustomKeyFunc { }'
            $output       = Join-Path $TestDrive 'CustomKey-output.template'

            $classCollector    = [PSScriptBuilderClassCollector]::new('CLASSES')
            $functionCollector = [PSScriptBuilderFunctionCollector]::new('FUNCTIONS')
            $classCollector.IncludeFiles    = @($classFile)
            $functionCollector.IncludeFiles = @($functionFile)
            $cc = New-PSScriptBuilderContentCollector -Collector @($classCollector, $functionCollector)

            $result = $cc | New-PSScriptBuilderTemplate -OutputPath $output -OrderedComponentsKey 'MY_ORDERED'

            $result.Placeholders | Should -Contain '{{MY_ORDERED}}'
            $result.Placeholders | Should -Not -Contain '{{ORDERED_COMPONENTS}}'
        }
    }
    #endregion Parameter - OrderedComponentsKey

    #region Parameter - OrderedMode
    Context 'Parameter - OrderedMode' {

        It 'Should return Hybrid mode when -OrderedMode is specified and no cross-dependencies exist' {
            $classFile = New-TestFile 'OrdMode-Class.ps1' 'class OrdModeClass { }'
            $output    = Join-Path $TestDrive 'OrdMode-output.template'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            $result = $cc | New-PSScriptBuilderTemplate -OutputPath $output -OrderedMode

            $result.Mode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Hybrid)
        }

        It 'Should set OrderedMode to true in result when -OrderedMode switch is used' {
            $classFile = New-TestFile 'OrdFlag-Class.ps1' 'class OrdFlagClass { }'
            $output    = Join-Path $TestDrive 'OrdFlag-output.template'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            $result = $cc | New-PSScriptBuilderTemplate -OutputPath $output -OrderedMode

            $result.OrderedMode | Should -BeTrue
        }

        It 'Should return Free mode when -OrderedMode is not specified and no cross-dependencies exist' {
            $classFile = New-TestFile 'NoOrdMode-Class.ps1' 'class NoOrdModeClass { }'
            $output    = Join-Path $TestDrive 'NoOrdMode-output.template'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            $result = $cc | New-PSScriptBuilderTemplate -OutputPath $output

            $result.Mode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Free)
        }
    }
    #endregion Parameter - OrderedMode

    #region Parameter - Force
    Context 'Parameter - Force' {

        It 'Should throw when output file exists and -Force is not specified' {
            $classFile = New-TestFile 'NoForce-Class.ps1'        'class NoForceClass { }'
            $output    = New-TestFile 'NoForce-existing.template' '# existing'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            { $cc | New-PSScriptBuilderTemplate -OutputPath $output } | Should -Throw
        }

        It 'Should not throw when output file exists and -Force is specified' {
            $classFile = New-TestFile 'Force-Class.ps1'        'class ForceClass { }'
            $output    = New-TestFile 'Force-existing.template' '# existing'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            { $cc | New-PSScriptBuilderTemplate -OutputPath $output -Force } | Should -Not -Throw
        }
    }
    #endregion Parameter - Force

    #region WhatIf
    Context 'WhatIf' {

        It 'Should not write the template file when -WhatIf is specified' {
            $classFile = New-TestFile 'WhatIf-Class.ps1' 'class WhatIfClass { }'
            $output    = Join-Path $TestDrive 'WhatIf-output.template'
            $cc        = New-ClassCC -Key 'CLASSES' -FilePath $classFile

            $cc | New-PSScriptBuilderTemplate -OutputPath $output -WhatIf

            Test-Path $output | Should -BeFalse
        }
    }
    #endregion WhatIf
}
