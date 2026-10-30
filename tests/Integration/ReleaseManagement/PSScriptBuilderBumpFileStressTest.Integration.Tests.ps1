Describe 'Bump File Stress Test Integration - Multi-Run Staleness (RFC 0019)' -Tag 'Integration' {

    BeforeAll {
        $script:ExampleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\Fixtures\BumpFileStressTest')).Path

        # -WarningVariable does not reliably capture warnings raised from deep inside a class
        # method call chain (verified empirically); '*>&1' does - it merges every stream into
        # the output pipeline, so a WarningRecord shows up as a regular object next to the
        # PSScriptBuilderBumpFilesResult. Filter by type to separate them.
        Function Invoke-BumpAndCaptureWarnings {
            $output   = Update-PSScriptBuilderBumpFiles *>&1
            $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $result   = $output | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }
            return [PSCustomObject] @{ Result = $result; Warnings = $warnings }
        }
    }

    Context 'Simple-mode-only target (Manifest.psd1) warns from the second run onward' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-01'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
            $script:FirstRun = Update-PSScriptBuilderBumpFiles

            Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
            $script:SecondRun = Invoke-BumpAndCaptureWarnings
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should modify Manifest.psd1 on the first run' {
            $script:FirstRun.TotalFilesModified | Should -BeGreaterThan 0
        }

        It 'Should not modify Manifest.psd1 on the second run' {
            ($script:SecondRun.Result.BumpDetails | Where-Object { $_.Path -match 'Manifest\.psd1$' }) | Should -BeNullOrEmpty
        }

        It 'Should warn about Manifest.psd1 on the second run' {
            ($script:SecondRun.Warnings | Where-Object { $_.Message -match 'Manifest\.psd1' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Placeholder-mode-only target (CHANGELOG.md) warns from the second run onward' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-02'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
            Update-PSScriptBuilderBumpFiles | Out-Null

            Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
            $script:SecondRun = Invoke-BumpAndCaptureWarnings
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should warn about CHANGELOG.md on the second run' {
            ($script:SecondRun.Warnings | Where-Object { $_.Message -match 'CHANGELOG\.md' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Regex-mode target (config/app.json) is self-sustaining across three runs' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-03'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:AllWarnings = [System.Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt 3; $i++) {
                Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
                $run = Invoke-BumpAndCaptureWarnings
                $script:AllWarnings.AddRange(@($run.Warnings))
            }
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should never warn about config/app.json across three consecutive runs' {
            ($script:AllWarnings | Where-Object { $_.Message -match 'app\.json' }) | Should -BeNullOrEmpty
        }
    }

    Context 'Mixed Bump Mode target (Manifest2.psd1) never warns across three consecutive runs' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-04'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:AllWarnings = [System.Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt 3; $i++) {
                Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
                $run = Invoke-BumpAndCaptureWarnings
                $script:AllWarnings.AddRange(@($run.Warnings))
            }
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should never warn about Manifest2.psd1 across three consecutive runs' {
            ($script:AllWarnings | Where-Object { $_.Message -match 'Manifest2\.psd1' }) | Should -BeNullOrEmpty
        }
    }

    Context 'Partial Regex fallback target (Template.ps1.template) masks other stale tokens without warning' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-05'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
            Update-PSScriptBuilderBumpFiles | Out-Null

            Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails | Out-Null
            $script:SecondRun = Invoke-BumpAndCaptureWarnings

            $script:TemplateContent = Get-Content (Join-Path $script:Root 'build\Templates\Template.ps1.template') -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should not warn about Template.ps1.template on the second run' {
            ($script:SecondRun.Warnings | Where-Object { $_.Message -match 'Template\.ps1\.template' }) | Should -BeNullOrEmpty
        }

        It 'Should have left VERSION stale (no Regex fallback) since the first run' {
            $script:TemplateContent | Should -Match '# Version: 1\.0\.1'
        }
    }
}
