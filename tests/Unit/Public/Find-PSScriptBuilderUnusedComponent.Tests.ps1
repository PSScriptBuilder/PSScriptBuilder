using namespace System

Describe 'Find-PSScriptBuilderUnusedComponent' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-SimpleCC {
            param([string] $ClassFile)
            $collector = [PSScriptBuilderClassCollector]::new('CLASSES')
            $collector.IncludeFiles = @($ClassFile)
            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($collector)
            $cc.Execute()
            return $cc
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Return type
    Context 'Return type' {

        It 'Should return PSScriptBuilderUnusedComponentEntry objects' {
            $classFile = New-TestFile 'RT-Class.ps1' 'class RTClass { }'
            $cc        = New-SimpleCC -ClassFile $classFile

            $result = $cc | Find-PSScriptBuilderUnusedComponent -WarningAction SilentlyContinue

            $result | ForEach-Object { $_.GetType().Name | Should -Be 'PSScriptBuilderUnusedComponentEntry' }
        }
    }
    #endregion Return type

    #region Parameter - ContentCollector
    Context 'Parameter - ContentCollector (pipeline)' {

        It 'Should accept ContentCollector via pipeline' {
            $classFile = New-TestFile 'Pipe-Class.ps1' 'class PipeClass { }'
            $cc        = New-SimpleCC -ClassFile $classFile

            { $cc | Find-PSScriptBuilderUnusedComponent -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
    #endregion Parameter - ContentCollector

    #region Parameter - EntryPoint
    Context 'Parameter - EntryPoint' {

        It 'Should return only unreachable components when EntryPoint is specified' {
            $baseFile   = New-TestFile 'EP-Base.ps1'   'class EPBase { }'
            $orphanFile = New-TestFile 'EP-Orphan.ps1' 'class EPOrphan { }'
            $funcFile   = New-TestFile 'EP-Func.ps1'   'Function Get-EPFunc { [EPBase] $x = $null }'

            $classCollector    = [PSScriptBuilderClassCollector]::new('CLASSES')
            $orphanCollector   = [PSScriptBuilderClassCollector]::new('ORPHAN')
            $functionCollector = [PSScriptBuilderFunctionCollector]::new('FUNCTIONS')
            $classCollector.IncludeFiles    = @($baseFile)
            $orphanCollector.IncludeFiles   = @($orphanFile)
            $functionCollector.IncludeFiles = @($funcFile)

            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($classCollector)
            $cc.AddCollector($orphanCollector)
            $cc.AddCollector($functionCollector)

            $result = $cc | Find-PSScriptBuilderUnusedComponent -EntryPoint 'Get-EPFunc'

            $result | Where-Object { $_.Name -eq 'EPOrphan' } | Should -Not -BeNullOrEmpty
            $result | Where-Object { $_.Name -eq 'EPBase' }   | Should -BeNullOrEmpty
        }

        It 'Should emit warnings when EntryPoint is not specified' {
            $classFile = New-TestFile 'Warn-Class.ps1' 'class WarnClass { }'
            $cc        = New-SimpleCC -ClassFile $classFile

            $warnings = @()
            $cc | Find-PSScriptBuilderUnusedComponent -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings.Count | Should -BeGreaterThan 0
        }

        It 'Should not emit entry point warnings when EntryPoint is specified' {
            $classFile = New-TestFile 'NoWarn-Class.ps1' 'class NoWarnClass { }'
            $funcFile  = New-TestFile 'NoWarn-Func.ps1'  'Function Get-NoWarn { [NoWarnClass] $x = $null }'

            $classCollector    = [PSScriptBuilderClassCollector]::new('CLASSES')
            $functionCollector = [PSScriptBuilderFunctionCollector]::new('FUNCTIONS')
            $classCollector.IncludeFiles    = @($classFile)
            $functionCollector.IncludeFiles = @($funcFile)

            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($classCollector)
            $cc.AddCollector($functionCollector)

            $warnings = @()
            $cc | Find-PSScriptBuilderUnusedComponent -EntryPoint 'Get-NoWarn' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            # The entry-point-missing warnings should not be present
            $entryPointWarning = $warnings | Where-Object { $_ -like '*-EntryPoint*' }
            $entryPointWarning | Should -BeNullOrEmpty
        }
    }
    #endregion Parameter - EntryPoint

    #region No results
    Context 'No unused components' {

        It 'Should return empty result when all components are reachable from entry point' {
            $classFile = New-TestFile 'AllUsed-Class.ps1' 'class AllUsedClass { }'
            $funcFile  = New-TestFile 'AllUsed-Func.ps1'  'Function Get-AllUsed { [AllUsedClass] $x = $null }'

            $classCollector    = [PSScriptBuilderClassCollector]::new('CLASSES')
            $functionCollector = [PSScriptBuilderFunctionCollector]::new('FUNCTIONS')
            $classCollector.IncludeFiles    = @($classFile)
            $functionCollector.IncludeFiles = @($funcFile)

            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($classCollector)
            $cc.AddCollector($functionCollector)

            $result = $cc | Find-PSScriptBuilderUnusedComponent -EntryPoint 'Get-AllUsed'

            $result | Should -BeNullOrEmpty
        }
    }
    #endregion No results
}
