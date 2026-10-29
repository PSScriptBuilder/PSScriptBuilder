Describe 'Template Stress Test Integration - Multiple Using Collectors' -Tag 'Integration' {

    BeforeAll {
        [PSScriptBuilderConfiguration]::Reset()
        $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\Fixtures\TemplateStressTest')).Path
        $Global:PSScriptBuilderProjectRoot = $script:Root

        $script:CC = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'CoreEnums'          -IncludePath 'src\Core\Enums' |
            Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CoreClasses'        -IncludePath 'src\Core\Classes' |
            Add-PSScriptBuilderCollector -Type Function -CollectionKey 'CoreFunctions'      -IncludePath 'src\Core\Functions' |
            Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'WorkflowEnums'      -IncludePath 'src\Workflow\Enums' |
            Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'WorkflowClasses'    -IncludePath 'src\Workflow\Classes' |
            Add-PSScriptBuilderCollector -Type Function -CollectionKey 'WorkflowFunctions'  -IncludePath 'src\Workflow\Functions' |
            Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'NotificationEnums'     -IncludePath 'src\Notifications\Enums' |
            Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'NotificationClasses'   -IncludePath 'src\Notifications\Classes' |
            Add-PSScriptBuilderCollector -Type Function -CollectionKey 'NotificationFunctions' -IncludePath 'src\Notifications\Functions' |
            Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'ReportingEnums'     -IncludePath 'src\Reporting\Enums' |
            Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'ReportingClasses'   -IncludePath 'src\Reporting\Classes' |
            Add-PSScriptBuilderCollector -Type Function -CollectionKey 'ReportingFunctions' -IncludePath 'src\Reporting\Functions' |
            Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CliClasses'         -IncludePath 'src\CLI\Classes' |
            Add-PSScriptBuilderCollector -Type Function -CollectionKey 'CliFunctions'       -IncludePath 'src\CLI\Functions' |
            Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'IntegrationEnums'     -IncludePath 'src\Integrations\Enums' |
            Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'IntegrationClasses'   -IncludePath 'src\Integrations\Classes' |
            Add-PSScriptBuilderCollector -Type Function -CollectionKey 'IntegrationFunctions' -IncludePath 'src\Integrations\Functions' |
            Add-PSScriptBuilderCollector -Type Using -CollectionKey 'CoreUsings'         -IncludePath 'src\Core' |
            Add-PSScriptBuilderCollector -Type Using -CollectionKey 'WorkflowUsings'     -IncludePath 'src\Workflow' |
            Add-PSScriptBuilderCollector -Type Using -CollectionKey 'NotificationUsings' -IncludePath 'src\Notifications' |
            Add-PSScriptBuilderCollector -Type Using -CollectionKey 'IntegrationUsings'  -IncludePath 'src\Integrations'

        $script:ValidTemplatePath  = Join-Path $script:Root 'build\Templates\StressTest.ps1.template'
        $script:BrokenTemplatePath = Join-Path $script:Root 'build\Templates\StressTest.Broken.ps1.template'
    }

    AfterAll {
        [PSScriptBuilderConfiguration]::Reset()
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Valid template - single consolidated Using placeholder for 4 registered Using collectors' {

        It 'Should return true for Test-PSScriptBuilderTemplate' {
            $result = Test-PSScriptBuilderTemplate -ContentCollector $script:CC -TemplatePath $script:ValidTemplatePath
            $result | Should -BeTrue
        }

        It 'Should build successfully and merge all 4 Using collectors'' statements into the output' {
            $outPath = Join-Path $TestDrive 'StressTest.ps1'
            Invoke-PSScriptBuilderBuild -ContentCollector $script:CC -TemplatePath $script:ValidTemplatePath -OutputPath $outPath | Out-Null
            $content = Get-Content -Path $outPath -Raw

            $content | Should -Match 'using namespace System\.Collections\.Generic'
            $content | Should -Match 'using namespace System\.Linq'
            $content | Should -Match 'using namespace System\.Text\.Json'
            $content | Should -Match 'using namespace System\.Net\.Http'
            $content | Should -Match 'using namespace System\.Text\.RegularExpressions'
        }
    }

    Context 'Broken template - a second, independent Using placeholder is rejected' {

        It 'Should return false for Test-PSScriptBuilderTemplate' {
            $result = Test-PSScriptBuilderTemplate -ContentCollector $script:CC -TemplatePath $script:BrokenTemplatePath
            $result | Should -BeFalse
        }

        It 'Should throw a message naming the consolidated Using collector placeholders when building' {
            $outPath = Join-Path $TestDrive 'StressTest.Broken.ps1'
            {
                Invoke-PSScriptBuilderBuild -ContentCollector $script:CC -TemplatePath $script:BrokenTemplatePath -OutputPath $outPath
            } | Should -Throw '*Using collector placeholders*'
        }
    }

    Context 'Get-PSScriptBuilderDependencyAnalysis - real, multi-path cross-dependencies' {

        BeforeAll {
            $script:Analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $script:CC
        }

        It 'Should report cross-dependencies' {
            $script:Analysis.HasCrossDependencies | Should -BeTrue
        }

        It 'Should report no cycles' {
            $script:Analysis.HasCycles | Should -BeFalse
        }

        It 'Should report 37 total component nodes' {
            $script:Analysis.TotalNodes | Should -Be 37
        }
    }
}
