Describe 'PSScriptBuilderWellKnownFileNames' {

    Context 'Configuration' {

        It 'Should return the expected configuration file name' {
            [PSScriptBuilderWellKnownFileNames]::Configuration | Should -Be 'psscriptbuilder.config.json'
        }
    }

    Context 'ReleaseData' {

        It 'Should return the expected release data file name' {
            [PSScriptBuilderWellKnownFileNames]::ReleaseData | Should -Be 'psscriptbuilder.releasedata.json'
        }
    }

    Context 'BumpConfig' {

        It 'Should return the expected bump configuration file name' {
            [PSScriptBuilderWellKnownFileNames]::BumpConfig | Should -Be 'psscriptbuilder.bumpconfig.json'
        }
    }
}
