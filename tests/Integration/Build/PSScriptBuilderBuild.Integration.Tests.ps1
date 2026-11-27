Describe 'Build Integration - Invoke-PSScriptBuilderBuild' -Tag 'Integration' {

    Context 'Example 01: Functions-only (Free Mode)' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\01-functions-only')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $script:Root 'build\Templates\HRUtils.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex01-HRUtils.ps1'

            $collector = New-PSScriptBuilderCollector -Type Function -IncludePath 'src'
            $cc = New-PSScriptBuilderContentCollector -Collector $collector
            $script:Result  = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output
            $script:Content = Get-Content -Path $script:Output -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should produce an output file at the specified path' {
            Test-Path $script:Output | Should -BeTrue
        }

        It 'Should contain the collected function definitions' {
            $script:Content | Should -Match 'Function Get-FormattedName'
        }

        It 'Should not contain any unreplaced placeholders' {
            $script:Content | Should -Not -Match '\{\{FUNCTION_DEFINITIONS\}\}'
        }

        It 'Should report correct function count in BuildResult' {
            $script:Result.ComponentCounts.FunctionDefinitions | Should -Be 3
        }

        It 'Should report a positive execution time in BuildResult' {
            $script:Result.ExecutionTime.TotalMilliseconds | Should -BeGreaterThan 0
        }
    }

    Context 'Example 02: Classes and Enums - enum appears before class in output' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\02-classes-and-enums')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $script:Root 'build\Templates\HRTools.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex02-HRTools.ps1'

            $enumC  = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'
            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $cc = New-PSScriptBuilderContentCollector -Collector @($enumC, $classC, $funcC)
            $script:Result  = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output
            $script:Content = Get-Content -Path $script:Output -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should contain class definitions' {
            $script:Content | Should -Match 'class Employee'
        }

        It 'Should contain enum definitions' {
            $script:Content | Should -Match 'enum Department'
        }

        It 'Should place enum definitions before class definitions' {
            $script:Content.IndexOf('enum Department') | Should -BeLessThan ($script:Content.IndexOf('class Employee'))
        }

        It 'Should not contain any unreplaced placeholders' {
            $script:Content | Should -Not -Match '\{\{.*?\}\}'
        }
    }

    Context 'Example 02: Classes and Enums - an escaped {{{{ORDERED_COMPONENTS}}}} comment renders as literal text (RFC 0001)' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\02-classes-and-enums')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $TestDrive 'EscapedComment.ps1.template'
            $templateContent = "# Example: you could switch to Hybrid mode by using {{{{ORDERED_COMPONENTS}}}} instead`n{{ENUM_DEFINITIONS}}`n`n{{CLASS_DEFINITIONS}}`n`n{{FUNCTION_DEFINITIONS}}"
            Set-Content -Path $templatePath -Value $templateContent
            $script:Output = Join-Path $TestDrive 'Ex02-EscapedComment.ps1'

            $enumC  = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'
            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $cc = New-PSScriptBuilderContentCollector -Collector @($enumC, $classC, $funcC)
            $null = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output
            $script:Content = Get-Content -Path $script:Output -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should contain the literal, un-escaped {{ORDERED_COMPONENTS}} text in the comment' {
            $script:Content | Should -Match ([regex]::Escape('{{ORDERED_COMPONENTS}}'))
        }

        It 'Should not contain any leftover four-brace escape sequence' {
            $script:Content | Should -Not -Match '\{\{\{\{'
        }

        It 'Should not contain any leftover NUL sentinel character' {
            ($script:Content.ToCharArray() | Where-Object { [int]$_ -eq 0 }).Count | Should -Be 0
        }

        It 'Should still contain the real class definitions' {
            $script:Content | Should -Match 'class Employee'
        }
    }

    Context 'Example 03: With Configuration - template and output paths resolved from config' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\03-with-configuration')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:Config = Get-PSScriptBuilderConfiguration
            $templatePath  = Join-Path $script:Config.Build.TemplatePath 'HRTools.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex03-HRTools.ps1'

            $enumC  = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'
            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $cc = New-PSScriptBuilderContentCollector -Collector @($enumC, $classC, $funcC)
            $script:Result  = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output
            $script:Content = Get-Content -Path $script:Output -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should load configuration successfully' {
            $script:Config | Should -Not -BeNullOrEmpty
        }

        It 'Should resolve a non-empty templates path from configuration' {
            $script:Config.Build.TemplatePath | Should -Not -BeNullOrEmpty
        }

        It 'Should produce an output file at the specified path' {
            Test-Path $script:Output | Should -BeTrue
        }

        It 'Should contain class definitions' {
            $script:Content | Should -Match 'class Employee'
        }

        It 'Should contain enum definitions' {
            $script:Content | Should -Match 'enum Department'
        }

        It 'Should not contain any unreplaced placeholders' {
            $script:Content | Should -Not -Match '\{\{.*?\}\}'
        }
    }

    Context 'Example 04: Flexible File Structure - multiple definition types extracted from flat src layout' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\04-flexible-file-structure')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $script:Root 'build\Templates\HRTools.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex04-HRTools.ps1'

            $enumC  = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src'
            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src'
            $cc = New-PSScriptBuilderContentCollector -Collector @($enumC, $classC, $funcC)
            $script:Result  = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output
            $script:Content = Get-Content -Path $script:Output -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should contain enum definitions extracted from mixed-type source files' {
            $script:Content | Should -Match 'enum Department'
        }

        It 'Should contain class definitions extracted from mixed-type source files' {
            $script:Content | Should -Match 'class Employee'
        }

        It 'Should not contain any unreplaced placeholders' {
            $script:Content | Should -Not -Match '\{\{.*?\}\}'
        }
    }

    Context 'Example 05: All Collectors - raw file content, using statements, and typed components' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\05-all-collectors')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $script:Root 'build\Templates\HRTools.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex05-HRTools.ps1'

            $usingC  = New-PSScriptBuilderCollector -Type Using -IncludePath 'src\Functions'
            $headerC = New-PSScriptBuilderCollector -Type File -CollectionKey 'Header'        -IncludeFile 'src\Files\Header.ps1'
            $configC = New-PSScriptBuilderCollector -Type File -CollectionKey 'Configuration' -IncludeFile 'src\Files\Configuration.ps1'
            $enumC   = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'
            $classC  = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC   = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $cc = New-PSScriptBuilderContentCollector -Collector @($usingC, $headerC, $configC, $enumC, $classC, $funcC)
            $script:Result  = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output
            $script:Content = Get-Content -Path $script:Output -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should inject the raw header file content' {
            $script:Content | Should -Match 'HR Tools'
        }

        It 'Should inject class definitions after the file content' {
            $script:Content | Should -Match 'class Employee'
        }

        It 'Should not contain any unreplaced placeholders' {
            $script:Content | Should -Not -Match '\{\{.*?\}\}'
        }
    }

    Context 'Example 07: Ordered Mode - dependency order respected in output' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\07-ordered-mode')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $script:Root 'build\Templates\HRWorkforce.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex07-HRWorkforce.ps1'

            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $cc = New-PSScriptBuilderContentCollector -Collector @($classC, $funcC)
            $script:Result  = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output
            $script:Content = Get-Content -Path $script:Output -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should contain the base class Person' {
            $script:Content | Should -Match 'class Person'
        }

        It 'Should contain the derived class Employee' {
            $script:Content | Should -Match 'class Employee'
        }

        It 'Should place the base class Person before the derived class Employee' {
            $script:Content.IndexOf('class Person') | Should -BeLessThan ($script:Content.IndexOf('class Employee'))
        }

        It 'Should not contain any unreplaced placeholders' {
            $script:Content | Should -Not -Match '\{\{.*?\}\}'
        }
    }

    Context 'CreateBackup - backup file is created when output already exists' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\01-functions-only')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath    = Join-Path $script:Root 'build\Templates\HRUtils.ps1.template'
            $script:BackupOutput = Join-Path $TestDrive 'HRUtils-Backup.ps1'

            # First build - creates the output file (no backup)
            $collector1 = New-PSScriptBuilderCollector -Type Function -IncludePath 'src'
            $cc1 = New-PSScriptBuilderContentCollector -Collector $collector1
            Invoke-PSScriptBuilderBuild -ContentCollector $cc1 -TemplatePath $templatePath -OutputPath $script:BackupOutput | Out-Null

            # Second build - output already exists, backup should be created
            $collector2 = New-PSScriptBuilderCollector -Type Function -IncludePath 'src'
            $cc2 = New-PSScriptBuilderContentCollector -Collector $collector2
            Invoke-PSScriptBuilderBuild -ContentCollector $cc2 -TemplatePath $templatePath -OutputPath $script:BackupOutput -EnableBackup | Out-Null
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should create a backup file alongside the output file' {
            $bakFiles = Get-ChildItem -Path $TestDrive -Filter '*.bak'
            $bakFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should keep the original output file intact' {
            Test-Path $script:BackupOutput | Should -BeTrue
        }
    }

    Context 'WriteSourceMap - sidecar file is written alongside the output' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\01-functions-only')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $script:Root 'build\Templates\HRUtils.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex01-WriteSourceMap-HRUtils.ps1'

            $collector = New-PSScriptBuilderCollector -Type Function -IncludePath 'src'
            $cc = New-PSScriptBuilderContentCollector -Collector $collector
            $script:Result      = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output -WriteSourceMap
            $script:SidecarPath = "$($script:Output).sourcemap.json"
            $script:SourceMap   = $script:Result | Resolve-PSScriptBuilderSourceLocation
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should write a .sourcemap.json sidecar file alongside the output' {
            Test-Path $script:SidecarPath | Should -BeTrue
        }

        It 'Should resolve at least one component from the source map' {
            $script:SourceMap.Count | Should -BeGreaterThan 0
        }

        It 'Should map each entry to an existing source file' {
            foreach ($entry in $script:SourceMap) {
                Test-Path $entry.SourceFile | Should -BeTrue
            }
        }

        It 'Should set a positive output line number for each entry' {
            foreach ($entry in $script:SourceMap) {
                $entry.OutputLineNumber | Should -BeGreaterThan 0
            }
        }
    }

    Context 'WriteSourceMap - sidecar is not written when WriteSourceMap is omitted' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\01-functions-only')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $templatePath  = Join-Path $script:Root 'build\Templates\HRUtils.ps1.template'
            $script:Output = Join-Path $TestDrive 'Ex01-NoSourceMap-HRUtils.ps1'

            $collector = New-PSScriptBuilderCollector -Type Function -IncludePath 'src'
            $cc = New-PSScriptBuilderContentCollector -Collector $collector
            Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath $templatePath -OutputPath $script:Output | Out-Null
            $script:SidecarPath = "$($script:Output).sourcemap.json"
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should not write a .sourcemap.json sidecar file' {
            Test-Path $script:SidecarPath | Should -BeFalse
        }
    }
}
