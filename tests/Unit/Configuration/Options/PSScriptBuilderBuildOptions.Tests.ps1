using namespace System
using namespace System.IO

Describe 'PSScriptBuilderBuildOptions' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-BuildConfig {
            param(
                [string] $OutputPath,
                [string] $BackupPath              = '',
                [string] $TemplatePath            = '',
                [string] $OrderedComponentsKey    = 'ORDERED_COMPONENTS',
                [bool]   $BackupEnabled           = $false,
                [bool]   $SyntaxValidationEnabled = $true,
                [bool]   $WriteSourceMap          = $false
            )
            return [PSCustomObject] @{
                outputPath              = $OutputPath
                backupPath              = $BackupPath
                templatePath            = $TemplatePath
                orderedComponentsKey    = $OrderedComponentsKey
                backupEnabled           = $BackupEnabled
                syntaxValidationEnabled = $SyntaxValidationEnabled
                writeSourceMap          = $WriteSourceMap
            }
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set OutputPath from config' {
            $outPath = Join-Path $TestDrive 'OutputMapping'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath))

            $options.OutputPath | Should -Be $outPath
        }

        It 'Should set OrderedComponentsKey from config' {
            $outPath = Join-Path $TestDrive 'OutputKey'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath -OrderedComponentsKey 'MY_KEY'))

            $options.OrderedComponentsKey | Should -Be 'MY_KEY'
        }

        It 'Default OrderedComponentsKey should be ORDERED_COMPONENTS when not overridden' {
            $outPath = Join-Path $TestDrive 'OutputDefault'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath))

            $options.OrderedComponentsKey | Should -Be 'ORDERED_COMPONENTS'
        }

        It 'Default BackupEnabled should be false' {
            $outPath = Join-Path $TestDrive 'OutputCB'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath))

            $options.BackupEnabled | Should -BeFalse
        }

        It 'Default SyntaxValidationEnabled should be true' {
            $outPath = Join-Path $TestDrive 'OutputSVE'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath))

            $options.SyntaxValidationEnabled | Should -BeTrue
        }

        It 'Should set SyntaxValidationEnabled to false when configured' {
            $outPath = Join-Path $TestDrive 'OutputSVEFalse'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath -SyntaxValidationEnabled $false))

            $options.SyntaxValidationEnabled | Should -BeFalse
        }

        It 'Should preserve default OrderedComponentsKey when absent from config' {
            $outPath = Join-Path $TestDrive 'OutputAbsentKey'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $config = [PSCustomObject] @{ outputPath = $outPath; templatePath = $outPath }
            $options = [PSScriptBuilderBuildOptions]::new($config)

            $options.OrderedComponentsKey | Should -Be 'ORDERED_COMPONENTS'
        }

        It 'Should preserve default SyntaxValidationEnabled when absent from config' {
            $outPath = Join-Path $TestDrive 'OutputAbsentSVE'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $config = [PSCustomObject] @{ outputPath = $outPath; templatePath = $outPath }
            $options = [PSScriptBuilderBuildOptions]::new($config)

            $options.SyntaxValidationEnabled | Should -BeTrue
        }

        It 'Default WriteSourceMap should be false' {
            $outPath = Join-Path $TestDrive 'OutputWSM'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath))

            $options.WriteSourceMap | Should -BeFalse
        }

        It 'Should set WriteSourceMap to true when configured' {
            $outPath = Join-Path $TestDrive 'OutputWSMTrue'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $options = [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath -WriteSourceMap $true))

            $options.WriteSourceMap | Should -BeTrue
        }
    }

    Context 'ValidateOptions - path errors' {

        It 'Should throw InvalidOperationException when BackupEnabled is true but BackupPath is empty' {
            $outPath = Join-Path $TestDrive 'OutputBackup'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            { [PSScriptBuilderBuildOptions]::new((New-BuildConfig $outPath -BackupEnabled $true -BackupPath '')) } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }
}
