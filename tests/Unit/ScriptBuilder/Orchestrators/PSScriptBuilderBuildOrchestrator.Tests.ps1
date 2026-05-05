using namespace System
using namespace System.IO

Describe 'PSScriptBuilderBuildOrchestrator' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-TemplateFile {
            param([string] $FileName, [string] $Content = '{{CLASSES}}')
            return New-TestFile -FileName $FileName -Content $Content
        }

        Function New-EmptyCC {
            return [PSScriptBuilderContentCollector]::new()
        }

        Function New-Orchestrator {
            param(
                [PSScriptBuilderContentCollector] $CC                     = $null,
                [string]                          $TemplatePath           = '',
                [string]                          $OutputPath             = '',
                [string]                          $BackupDir              = '',
                [string]                          $OrderedKey             = '',
                [bool]                            $BackupEnabled          = $false,
                [bool]                            $SyntaxValidationEnabled = $true
            )

            if ($null -eq $CC) {
                $CC = New-EmptyCC
            }

            return [PSScriptBuilderBuildOrchestrator]::new(
                $CC,
                $TemplatePath,
                $OutputPath,
                $BackupDir,
                $OrderedKey,
                $BackupEnabled,
                $SyntaxValidationEnabled
            )
        }

        # Builds a simple ContentCollector with one class, executed
        Function New-ClassCC {
            param([string] $Key, [string] $ClassName, [string] $FilePath)
            $c = [PSScriptBuilderClassCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($c)
            $cc.Execute()
            return $cc
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Constructor
    Context 'Constructor - parameter validation' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            $template = New-TemplateFile 'ctor-null-cc.template'
            $output   = Join-Path $TestDrive 'ctor-null-cc.ps1'

            { [PSScriptBuilderBuildOrchestrator]::new($null, $template, $output, '', '', $false, $true) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should throw ArgumentException when templatePath is null or empty' {
            $output = Join-Path $TestDrive 'ctor-no-template.ps1'

            { New-Orchestrator -CC (New-EmptyCC) -TemplatePath '' -OutputPath $output } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when templatePath is whitespace' {
            $output = Join-Path $TestDrive 'ctor-ws-template.ps1'

            { New-Orchestrator -CC (New-EmptyCC) -TemplatePath '   ' -OutputPath $output } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when outputPath is null or empty' {
            $template = New-TemplateFile 'ctor-no-output.template'

            { New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath '' } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when outputPath is whitespace' {
            $template = New-TemplateFile 'ctor-ws-output.template'

            { New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath '   ' } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should not throw when all required parameters are valid' {
            $template = New-TemplateFile 'ctor-valid.template'
            $output   = Join-Path $TestDrive 'ctor-valid.ps1'

            { New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath $output } |
                Should -Not -Throw
        }

        It 'Should default orderedComponentsKey to ORDERED_COMPONENTS when not provided' {
            $template = New-TemplateFile 'ctor-default-key.template'
            $output   = Join-Path $TestDrive 'ctor-default-key.ps1'

            # Use a template with {{ORDERED_COMPONENTS}} so the processor does not fail
            Set-Content -Path $template -Value '{{ORDERED_COMPONENTS}}' -Encoding UTF8

            { New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath $output -OrderedKey '' } |
                Should -Not -Throw
        }
    }
    #endregion Constructor

    #region LoadTemplate
    Context 'LoadTemplate' {

        It 'Should return the template content when the file exists' {
            $expectedContent = '# valid template content'
            $template        = New-TemplateFile 'lt-valid.template' -Content $expectedContent
            $output          = Join-Path $TestDrive 'lt-valid.ps1'
            $orch            = New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath $output

            $result = $orch.LoadTemplate()

            $result.TrimEnd() | Should -Be $expectedContent
        }

        It 'Should throw when the template file does not exist' {
            $missing = Join-Path $TestDrive 'lt-missing.template'
            $output  = Join-Path $TestDrive 'lt-missing.ps1'
            $orch    = New-Orchestrator -CC (New-EmptyCC) -TemplatePath $missing -OutputPath $output

            { $orch.LoadTemplate() } | Should -Throw
        }
    }
    #endregion LoadTemplate

    #region CreateBackup (phase method)
    Context 'CreateBackup - phase method' {

        It 'Should return null when the output file does not exist' {
            $template  = New-TemplateFile 'cb-no-output.template'
            $output    = Join-Path $TestDrive 'cb-no-output.ps1'
            $backupDir = Join-Path $TestDrive 'cb-no-output-backups'
            $orch      = New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath $output -BackupDir $backupDir

            $result = $orch.CreateBackup()

            $result | Should -BeNullOrEmpty
        }

        It 'Should return a backup path when the output file exists' {
            $template  = New-TemplateFile 'cb-exists.template'
            $output    = New-TestFile 'cb-exists-output.ps1' '# existing output'
            $backupDir = Join-Path $TestDrive 'cb-exists-backups'
            $orch      = New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath $output -BackupDir $backupDir

            $result = $orch.CreateBackup()

            $result           | Should -Not -BeNullOrEmpty
            Test-Path $result | Should -BeTrue
        }
    }
    #endregion CreateBackup

    #region WriteOutput
    Context 'WriteOutput' {

        It 'Should create the output file with the specified content' {
            $template = New-TemplateFile 'wo-test.template'
            $output   = Join-Path $TestDrive 'wo-written.ps1'
            $orch     = New-Orchestrator -CC (New-EmptyCC) -TemplatePath $template -OutputPath $output

            $orch.WriteOutput('# output content')

            Test-Path $output                 | Should -BeTrue
            (Get-Content $output -Raw).Trim() | Should -Be '# output content'
        }
    }
    #endregion WriteOutput

    #region ExecuteBuild
    Context 'ExecuteBuild - complete pipeline' {

        It 'Should return a BuildResult when the build succeeds' {
            $classFile = New-TestFile 'EB-Class.ps1' 'class EBClass { }'
            $template  = New-TemplateFile 'EB-success.template' -Content '{{CLASSES}}'
            $output    = Join-Path $TestDrive 'EB-success.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output

            $result = $orch.ExecuteBuild()

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should write the output file after a successful build' {
            $classFile = New-TestFile 'EB-Write-Class.ps1' 'class EBWriteClass { }'
            $template  = New-TemplateFile 'EB-write.template' -Content '{{CLASSES}}'
            $output    = Join-Path $TestDrive 'EB-write.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBWriteClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output

            $orch.ExecuteBuild() | Out-Null

            Test-Path $output | Should -BeTrue
        }

        It 'Should return a BuildResult with ProcessedFiles containing the source file' {
            $classFile = New-TestFile 'EB-PF-Class.ps1' 'class EBPfClass { }'
            $template  = New-TemplateFile 'EB-pf.template' -Content '{{CLASSES}}'
            $output    = Join-Path $TestDrive 'EB-pf.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBPfClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output

            $result = $orch.ExecuteBuild()

            $result.ProcessedFiles | Should -Contain $classFile
        }

        It 'Should include the class name in the component details' {
            $classFile = New-TestFile 'EB-CD-Class.ps1' 'class EBCdClass { }'
            $template  = New-TemplateFile 'EB-cd.template' -Content '{{CLASSES}}'
            $output    = Join-Path $TestDrive 'EB-cd.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBCdClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output

            $result = $orch.ExecuteBuild()

            $result.ComponentDetails.Name | Should -Contain 'EBCdClass'
        }

        It 'Should not create a backup when CreateBackup is false' {
            $classFile = New-TestFile 'EB-NoBak-Class.ps1' 'class EBNoBakClass { }'
            $template  = New-TemplateFile 'EB-nobak.template' -Content '{{CLASSES}}'
            $output    = Join-Path $TestDrive 'EB-nobak.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBNoBakClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output -BackupEnabled $false

            $result = $orch.ExecuteBuild()

            $result.BackupPath | Should -BeNullOrEmpty
        }

        It 'Should create a backup when CreateBackup is true and output file exists' {
            $classFile = New-TestFile 'EB-Bak-Class.ps1' 'class EBBakClass { }'
            $template  = New-TemplateFile 'EB-bak.template' -Content '{{CLASSES}}'
            $output    = New-TestFile 'EB-bak.ps1' '# old output'
            $backupDir = Join-Path $TestDrive 'EB-bak-dir'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBBakClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output -BackupDir $backupDir -BackupEnabled $true

            $result = $orch.ExecuteBuild()

            $result.BackupPath | Should -Not -BeNullOrEmpty
            Test-Path $result.BackupPath | Should -BeTrue
        }

        It 'Should throw when the template file does not exist' {
            $missing = Join-Path $TestDrive 'EB-missing.template'
            $output  = Join-Path $TestDrive 'EB-missing.ps1'

            $orch = New-Orchestrator -CC (New-EmptyCC) -TemplatePath $missing -OutputPath $output

            { $orch.ExecuteBuild() } | Should -Throw
        }

        It 'Should throw when a circular dependency is detected between classes' {
            # ClassA extends ClassB, ClassB extends ClassA -> cycle
            $fileA    = New-TestFile 'EB-CycleA.ps1' 'class CycleClassA : CycleClassB { }'
            $fileB    = New-TestFile 'EB-CycleB.ps1' 'class CycleClassB : CycleClassA { }'
            $template = New-TemplateFile 'EB-cycle.template' -Content '{{CLASSES}}'
            $output   = Join-Path $TestDrive 'EB-cycle.ps1'

            $c = [PSScriptBuilderClassCollector]::new('CLASSES')
            $c.IncludeFiles = @($fileA, $fileB)
            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($c)
            $cc.Execute()

            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output

            { $orch.ExecuteBuild() } | Should -Throw
        }

        It 'Should return a BuildResult with SyntaxValid set to true after a successful build' {
            $classFile = New-TestFile 'EB-Syntax-Class.ps1' 'class EBSyntaxClass { }'
            $template  = New-TemplateFile 'EB-syntax.template' -Content '{{CLASSES}}'
            $output    = Join-Path $TestDrive 'EB-syntax.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBSyntaxClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output

            $result = $orch.ExecuteBuild()

            $result.SyntaxValid | Should -BeTrue
        }

        It 'Should skip syntax validation and still succeed when SyntaxValidationEnabled is false' {
            $classFile = New-TestFile 'EB-SkipSyn-Class.ps1' 'class EBSkipSynClass { }'
            # Template produces invalid PowerShell output to prove validation is not executed
            $template  = New-TemplateFile 'EB-skipsyn.template' -Content '!invalid@syntax {{CLASSES}}'
            $output    = Join-Path $TestDrive 'EB-skipsyn.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBSkipSynClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output -SyntaxValidationEnabled $false

            $result = $orch.ExecuteBuild()

            $result.SyntaxValid | Should -BeTrue
        }

        It 'Should throw when SyntaxValidationEnabled is true and output contains a syntax error' {
            $classFile = New-TestFile 'EB-SynErr-Class.ps1' 'class EBSynErrClass { }'
            # Template produces invalid PowerShell output - 'function (' is a definite parse error
            $template  = New-TemplateFile 'EB-synerr.template' -Content "{{CLASSES}}`nfunction ("
            $output    = Join-Path $TestDrive 'EB-synerr.ps1'

            $cc   = New-ClassCC -Key 'CLASSES' -ClassName 'EBSynErrClass' -FilePath $classFile
            $orch = New-Orchestrator -CC $cc -TemplatePath $template -OutputPath $output -SyntaxValidationEnabled $true

            { $orch.ExecuteBuild() } | Should -Throw
        }
    }
    #endregion ExecuteBuild
}
