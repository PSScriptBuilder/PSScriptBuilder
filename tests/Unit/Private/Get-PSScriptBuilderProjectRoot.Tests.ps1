using namespace System

Describe 'Get-PSScriptBuilderProjectRoot' {

    <#
    Get-PSScriptBuilderProjectRoot is a private function (src\Private\, not exported).
    InModuleScope is required to reach it - verified to work correctly with a module
    loaded via 'using module' (the mechanism Invoke-Tests.ps1 uses for this project),
    both for normal returns and for exception propagation.

    Every test that needs a specific directory to auto-discover from creates its own
    isolated subdirectory under $TestDrive, rather than writing to $TestDrive's root
    directly - $TestDrive is not recreated between It blocks, so a shared root would let
    one test's config file leak into another test's directory walk.
    #>

    AfterEach {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Cached value' {

        It 'Should return the cached value without touching the file system' {
            $Global:PSScriptBuilderProjectRoot = 'C:\Some\Cached\Root'

            $result = InModuleScope PSScriptBuilder {
                Get-PSScriptBuilderProjectRoot
            }

            $result | Should -Be 'C:\Some\Cached\Root'
        }
    }

    Context 'Auto-discovery - success' {

        It 'Should find the config file in the current directory' {
            $projectDir = Join-Path $TestDrive 'current-dir-test'
            New-Item -Path $projectDir -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $projectDir 'psscriptbuilder.config.json') -ItemType File | Out-Null

            Push-Location $projectDir
            try {
                $result = InModuleScope PSScriptBuilder {
                    Get-PSScriptBuilderProjectRoot
                }
            }
            finally {
                Pop-Location
            }

            $result | Should -Be $projectDir
        }

        It 'Should walk up to find the config file in a parent directory' {
            $projectDir = Join-Path $TestDrive 'parent-walk-test'
            $nestedDir  = Join-Path (Join-Path $projectDir 'a') 'b'
            New-Item -Path $nestedDir -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $projectDir 'psscriptbuilder.config.json') -ItemType File | Out-Null

            Push-Location $nestedDir
            try {
                $result = InModuleScope PSScriptBuilder {
                    Get-PSScriptBuilderProjectRoot
                }
            }
            finally {
                Pop-Location
            }

            $result | Should -Be $projectDir
        }

        It 'Should cache the discovered root in $Global:PSScriptBuilderProjectRoot' {
            $projectDir = Join-Path $TestDrive 'cache-test'
            New-Item -Path $projectDir -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $projectDir 'psscriptbuilder.config.json') -ItemType File | Out-Null

            Push-Location $projectDir
            try {
                InModuleScope PSScriptBuilder {
                    Get-PSScriptBuilderProjectRoot
                } | Out-Null
            }
            finally {
                Pop-Location
            }

            $Global:PSScriptBuilderProjectRoot | Should -Be $projectDir
        }
    }

    Context 'Auto-discovery - failure' {

        It 'Should throw InvalidOperationException when no config file is found up to the filesystem root' {
            $isolatedDir = Join-Path $TestDrive 'no-config-anywhere-test'
            New-Item -Path $isolatedDir -ItemType Directory -Force | Out-Null

            Push-Location $isolatedDir
            try {
                { InModuleScope PSScriptBuilder { Get-PSScriptBuilderProjectRoot } } |
                    Should -Throw -ExceptionType ([InvalidOperationException])
            }
            finally {
                Pop-Location
            }
        }
    }
}