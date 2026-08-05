using namespace System.IO

Describe 'PSScriptBuilderScaffolder' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Scaffold - directories (no release management)' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('DirProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $script:projectPath = [Path]::Combine($TestDrive, 'DirProject')
        }

        It 'Should create the project root directory' {
            Test-Path $script:projectPath | Should -BeTrue
        }

        It 'Should create src\Enums directory' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Enums')) | Should -BeTrue
        }

        It 'Should create src\Classes directory' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Classes')) | Should -BeTrue
        }

        It 'Should create src\Public directory' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Public')) | Should -BeTrue
        }

        It 'Should create build\Templates directory' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Templates')) | Should -BeTrue
        }

        It 'Should create build\Output directory' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Output')) | Should -BeTrue
        }

        It 'Should not create build\Release directory when IncludeReleaseManagement is false' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Release')) | Should -BeFalse
        }
    }

    Context 'Scaffold - files (no release management)' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('FileProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $script:projectPath = [Path]::Combine($TestDrive, 'FileProject')
        }

        It 'Should create psscriptbuilder.config.json' {
            Test-Path ([Path]::Combine($script:projectPath, 'psscriptbuilder.config.json')) | Should -BeTrue
        }

        It 'Should create Build-<Name>.ps1' {
            Test-Path ([Path]::Combine($script:projectPath, 'Build-FileProject.ps1')) | Should -BeTrue
        }

        It 'Should create <Name>.ps1.template in build\Templates' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Templates', 'FileProject.ps1.template')) | Should -BeTrue
        }

        It 'Should not create release files when IncludeReleaseManagement is false' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.releasedata.json')) | Should -BeFalse
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.bumpconfig.json')) | Should -BeFalse
            Test-Path ([Path]::Combine($script:projectPath, 'Release-FileProject.ps1')) | Should -BeFalse
        }
    }

    Context 'Scaffold - build script content' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('ContentProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $buildScriptPath          = [Path]::Combine($TestDrive, 'ContentProject', 'Build-ContentProject.ps1')
            $script:buildScriptContent = Get-Content $buildScriptPath -Raw
        }

        It 'Should contain "using module PSScriptBuilder"' {
            $script:buildScriptContent | Should -Match 'using module PSScriptBuilder'
        }

        It 'Should contain Set-PSScriptBuilderProjectRoot' {
            $script:buildScriptContent | Should -Match 'Set-PSScriptBuilderProjectRoot'
        }

        It 'Should contain Invoke-PSScriptBuilderBuild' {
            $script:buildScriptContent | Should -Match 'Invoke-PSScriptBuilderBuild'
        }

        It 'Should reference the correct template file name' {
            $script:buildScriptContent | Should -Match 'ContentProject\.ps1\.template'
        }

        It 'Should reference the correct output file name' {
            $script:buildScriptContent | Should -Match 'ContentProject\.ps1'
        }

    }

    Context 'Scaffold - release script content' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('ReleaseContentProject', $TestDrive, $true, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $releaseScriptPath            = [Path]::Combine($TestDrive, 'ReleaseContentProject', 'Release-ReleaseContentProject.ps1')
            $script:releaseScriptContent  = Get-Content $releaseScriptPath -Raw
        }

        It 'Should contain "using module PSScriptBuilder"' {
            $script:releaseScriptContent | Should -Match 'using module PSScriptBuilder'
        }

        It 'Should contain Set-PSScriptBuilderProjectRoot' {
            $script:releaseScriptContent | Should -Match 'Set-PSScriptBuilderProjectRoot'
        }

        It 'Should contain Update-PSScriptBuilderReleaseData' {
            $script:releaseScriptContent | Should -Match 'Update-PSScriptBuilderReleaseData'
        }

        It 'Should contain Update-PSScriptBuilderBumpFiles' {
            $script:releaseScriptContent | Should -Match 'Update-PSScriptBuilderBumpFiles'
        }

        It 'Should reference the correct build script name' {
            $script:releaseScriptContent | Should -Match 'Build-ReleaseContentProject\.ps1'
        }

        It 'Should contain a literal $PSScriptRoot reference, not an expanded path' {
            $script:releaseScriptContent | Should -Match '\$PSScriptRoot'
        }

        It 'Should not contain hardcoded $Major/$Minor/$Patch in releaseParams' {
            $script:releaseScriptContent | Should -Not -Match 'Major\s*=\s*\$Major'
            $script:releaseScriptContent | Should -Not -Match 'Minor\s*=\s*\$Minor'
            $script:releaseScriptContent | Should -Not -Match 'Patch\s*=\s*\$Patch'
        }

        It 'Should contain switch on ParameterSetName' {
            $script:releaseScriptContent | Should -Match '\$PSCmdlet\.ParameterSetName'
        }

        It 'Should not contain the test drive path as a hardcoded value in the dot-source line' {
            $escaped = [regex]::Escape($TestDrive)
            $script:releaseScriptContent | Should -Not -Match ". `"$escaped"
        }
    }

    Context 'Scaffold - template content (no release management)' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('TemplateProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $templatePath          = [Path]::Combine($TestDrive, 'TemplateProject', 'build', 'Templates', 'TemplateProject.ps1.template')
            $script:templateContent = Get-Content $templatePath -Raw
        }

        It 'Should contain the auto-generated header comment' {
            $script:templateContent | Should -Match 'Auto-generated by PSScriptBuilder'
        }

        It 'Should contain {{ENUM_DEFINITIONS}} placeholder' {
            $script:templateContent | Should -Match '\{\{ENUM_DEFINITIONS\}\}'
        }

        It 'Should contain {{CLASS_DEFINITIONS}} placeholder' {
            $script:templateContent | Should -Match '\{\{CLASS_DEFINITIONS\}\}'
        }

        It 'Should contain {{FUNCTION_DEFINITIONS}} placeholder' {
            $script:templateContent | Should -Match '\{\{FUNCTION_DEFINITIONS\}\}'
        }

        It 'Should not contain {{VERSION}} placeholder when IncludeReleaseManagement is false' {
            $script:templateContent | Should -Not -Match '\{\{VERSION\}\}'
        }

        It 'Should not contain {{BUILD_TIMESTAMP}} placeholder when IncludeReleaseManagement is false' {
            $script:templateContent | Should -Not -Match '\{\{BUILD_TIMESTAMP\}\}'
        }
    }

    Context 'Scaffold - return value' {

        BeforeAll {
            $request        = [PSScriptBuilderScaffoldingRequest]::new('ResultProject', $TestDrive, $false, $false, $false)
            $scaffolder     = [PSScriptBuilderScaffolder]::new($request)
            $script:result  = $scaffolder.Scaffold()
        }

        It 'Should return a PSScriptBuilderScaffoldingResult' {
            $script:result.GetType().Name | Should -Be 'PSScriptBuilderScaffoldingResult'
        }

        It 'Should return the correct ProjectName' {
            $script:result.ProjectName | Should -Be 'ResultProject'
        }

        It 'Should return the correct ProjectPath' {
            $script:result.ProjectPath | Should -Be ([Path]::Combine($TestDrive, 'ResultProject'))
        }

        It 'Should return the correct BuildScriptPath' {
            $script:result.BuildScriptPath | Should -Be ([Path]::Combine($TestDrive, 'ResultProject', 'Build-ResultProject.ps1'))
        }

        It 'Should list created files in the result' {
            $script:result.CreatedFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should list created directories in the result' {
            $script:result.CreatedDirectories.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Scaffold - with IncludeReleaseManagement' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('RmProject', $TestDrive, $true, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $script:projectPath = [Path]::Combine($TestDrive, 'RmProject')
        }

        It 'Should create build\Release directory' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Release')) | Should -BeTrue
        }

        It 'Should create psscriptbuilder.releasedata.json' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.releasedata.json')) | Should -BeTrue
        }

        It 'Should create psscriptbuilder.bumpconfig.json' {
            Test-Path ([Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.bumpconfig.json')) | Should -BeTrue
        }

        It 'psscriptbuilder.bumpconfig.json should use bumpFiles key' {
            $bumpConfigPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.bumpconfig.json')
            $bumpConfigContent = Get-Content $bumpConfigPath -Raw | ConvertFrom-Json
            $bumpConfigContent.bumpFiles | Should -Not -BeNullOrEmpty
        }

        It 'psscriptbuilder.bumpconfig.json should have 1 bumpFiles entry' {
            $bumpConfigPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.bumpconfig.json')
            $bumpConfigContent = Get-Content $bumpConfigPath -Raw | ConvertFrom-Json
            $bumpConfigContent.bumpFiles.Count | Should -Be 1
        }

        It 'psscriptbuilder.bumpconfig.json entry should use items mode' {
            $bumpConfigPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.bumpconfig.json')
            $bumpConfigContent = Get-Content $bumpConfigPath -Raw | ConvertFrom-Json
            $bumpConfigContent.bumpFiles[0].items | Should -Not -BeNullOrEmpty
            $bumpConfigContent.bumpFiles[0].items.Count | Should -Be 2
        }

        It 'psscriptbuilder.bumpconfig.json VERSION item should have correct pattern' {
            $bumpConfigPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.bumpconfig.json')
            $bumpConfigContent = Get-Content $bumpConfigPath -Raw | ConvertFrom-Json
            $bumpConfigContent.bumpFiles[0].items[0].pattern | Should -Be '# Version:\s+({REGEX_VERSION})'
        }

        It 'psscriptbuilder.bumpconfig.json BUILD_TIMESTAMP item should have correct pattern' {
            $bumpConfigPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.bumpconfig.json')
            $bumpConfigContent = Get-Content $bumpConfigPath -Raw | ConvertFrom-Json
            $bumpConfigContent.bumpFiles[0].items[1].pattern | Should -Be '# Timestamp:\s+({REGEX_BUILD_TIMESTAMP})'
        }

        It 'Should create Release-<Name>.ps1' {
            Test-Path ([Path]::Combine($script:projectPath, 'Release-RmProject.ps1')) | Should -BeTrue
        }

        It 'psscriptbuilder.releasedata.json should contain version 0.1.0' {
            $releaseDataPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.releasedata.json')
            $releaseDataContent = Get-Content $releaseDataPath -Raw | ConvertFrom-Json
            $releaseDataContent.version.full | Should -Be '0.1.0'
        }

        It 'psscriptbuilder.releasedata.json should contain build number 0' {
            $releaseDataPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.releasedata.json')
            $releaseDataContent = Get-Content $releaseDataPath -Raw | ConvertFrom-Json
            $releaseDataContent.build.number | Should -Be 0
        }

        It 'psscriptbuilder.releasedata.json should have null git fields' {
            $releaseDataPath    = [Path]::Combine($script:projectPath, 'build', 'Release', 'psscriptbuilder.releasedata.json')
            $releaseDataContent = Get-Content $releaseDataPath -Raw | ConvertFrom-Json
            $releaseDataContent.git.commit | Should -BeNullOrEmpty
            $releaseDataContent.git.branch | Should -BeNullOrEmpty
        }

        It 'Template should contain version default value 0.1.0' {
            $templatePath    = [Path]::Combine($script:projectPath, 'build', 'Templates', 'RmProject.ps1.template')
            $templateContent = Get-Content $templatePath -Raw
            $templateContent | Should -Match '# Version:\s+0\.1\.0'
        }

        It 'Template should contain timestamp default value 1970-01-01T00:00:00Z' {
            $templatePath    = [Path]::Combine($script:projectPath, 'build', 'Templates', 'RmProject.ps1.template')
            $templateContent = Get-Content $templatePath -Raw
            $templateContent | Should -Match '# Timestamp:\s+1970-01-01T00:00:00Z'
        }
    }

    Context 'Scaffold - validation (existing non-empty directory)' {

        It 'Should throw when directory exists and is not empty and Force is false' {
            $existingPath = [Path]::Combine($TestDrive, 'ExistingProject')
            New-Item -ItemType Directory -Path $existingPath -Force | Out-Null
            Set-Content -Path ([Path]::Combine($existingPath, 'existing.txt')) -Value 'content'

            $request    = [PSScriptBuilderScaffoldingRequest]::new('ExistingProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)

            { $scaffolder.Scaffold() } | Should -Throw
        }

        It 'Should not throw when directory does not exist' {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('BrandNewProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)

            { $scaffolder.Scaffold() } | Should -Not -Throw
        }

        It 'Should not throw when directory exists but is empty' {
            $emptyPath = [Path]::Combine($TestDrive, 'EmptyProject')
            New-Item -ItemType Directory -Path $emptyPath -Force | Out-Null

            $request    = [PSScriptBuilderScaffoldingRequest]::new('EmptyProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)

            { $scaffolder.Scaffold() } | Should -Not -Throw
        }

        It 'Should not throw when directory exists and is not empty but Force is true' {
            $forcedPath = [Path]::Combine($TestDrive, 'ForcedProject')
            New-Item -ItemType Directory -Path $forcedPath -Force | Out-Null
            Set-Content -Path ([Path]::Combine($forcedPath, 'existing.txt')) -Value 'content'

            $request    = [PSScriptBuilderScaffoldingRequest]::new('ForcedProject', $TestDrive, $false, $false, $true)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)

            { $scaffolder.Scaffold() } | Should -Not -Throw
        }
    }

    Context 'Rollback - no files created' {

        It 'Should not throw when validation fails and no files were created' {
            $existingPath = [Path]::Combine($TestDrive, 'RollbackNoOpProject')
            New-Item -ItemType Directory -Path $existingPath -Force | Out-Null
            Set-Content -Path ([Path]::Combine($existingPath, 'existing.txt')) -Value 'content'

            $request    = [PSScriptBuilderScaffoldingRequest]::new('RollbackNoOpProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)

            { $scaffolder.Scaffold() } | Should -Throw

            # No files should have been created under the project path
            $existingFiles = Get-ChildItem $existingPath -File
            $existingFiles.Count | Should -Be 1  # only the pre-existing file
        }
    }

    Context 'Scaffold - sample files (IncludeSampleFiles = $true)' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('SampleProject', $TestDrive, $false, $true, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $script:projectPath = [Path]::Combine($TestDrive, 'SampleProject')
        }

        It 'Should create WorkStatus.ps1 in src\Enums' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Enums', 'WorkStatus.ps1')) | Should -BeTrue
        }

        It 'Should create Employee.ps1 in src\Classes' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Classes', 'Employee.ps1')) | Should -BeTrue
        }

        It 'Should create Get-EmployeeInfo.ps1 in src\Public' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Public', 'Get-EmployeeInfo.ps1')) | Should -BeTrue
        }

        It 'WorkStatus.ps1 should define the WorkStatus enum' {
            $content = Get-Content ([Path]::Combine($script:projectPath, 'src', 'Enums', 'WorkStatus.ps1')) -Raw
            $content | Should -Match 'enum WorkStatus'
        }

        It 'Employee.ps1 should reference WorkStatus' {
            $content = Get-Content ([Path]::Combine($script:projectPath, 'src', 'Classes', 'Employee.ps1')) -Raw
            $content | Should -Match 'WorkStatus'
        }

        It 'Get-EmployeeInfo.ps1 should reference Employee' {
            $content = Get-Content ([Path]::Combine($script:projectPath, 'src', 'Public', 'Get-EmployeeInfo.ps1')) -Raw
            $content | Should -Match 'Employee'
        }
    }

    Context 'Scaffold - sample files (IncludeSampleFiles = $false)' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('NoSampleProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $script:projectPath = [Path]::Combine($TestDrive, 'NoSampleProject')
        }

        It 'Should not create WorkStatus.ps1' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Enums', 'WorkStatus.ps1')) | Should -BeFalse
        }

        It 'Should not create Employee.ps1' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Classes', 'Employee.ps1')) | Should -BeFalse
        }

        It 'Should not create Get-EmployeeInfo.ps1' {
            Test-Path ([Path]::Combine($script:projectPath, 'src', 'Public', 'Get-EmployeeInfo.ps1')) | Should -BeFalse
        }
    }

    Context 'Scaffold - config file content' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('ConfigContentProject', $TestDrive, $false, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $configPath          = [Path]::Combine($TestDrive, 'ConfigContentProject', 'psscriptbuilder.config.json')
            $script:configContent = Get-Content $configPath -Raw | ConvertFrom-Json
        }

        It 'Should have a build section' {
            $script:configContent.build | Should -Not -BeNullOrEmpty
        }

        It 'build.outputPath should point to build\Output' {
            $script:configContent.build.outputPath | Should -Be '.\build\Output'
        }

        It 'build.templatePath should point to build\Templates' {
            $script:configContent.build.templatePath | Should -Be '.\build\Templates'
        }

        It 'build.backupPath should point to build\Output\Backup' {
            $script:configContent.build.backupPath | Should -Be '.\build\Output\Backup'
        }

        It 'build.orderedComponentsKey should be ORDERED_COMPONENTS' {
            $script:configContent.build.orderedComponentsKey | Should -Be 'ORDERED_COMPONENTS'
        }

        It 'build.backupEnabled should be false' {
            $script:configContent.build.backupEnabled | Should -BeFalse
        }

        It 'build.syntaxValidationEnabled should be true' {
            $script:configContent.build.syntaxValidationEnabled | Should -BeTrue
        }

        It 'Should have a release section' {
            $script:configContent.release | Should -Not -BeNullOrEmpty
        }

        It 'release.dataFile should point to psscriptbuilder.releasedata.json' {
            $script:configContent.release.dataFile | Should -Match 'psscriptbuilder\.releasedata\.json'
        }

        It 'release.bumpConfigFile should point to psscriptbuilder.bumpconfig.json' {
            $script:configContent.release.bumpConfigFile | Should -Match 'psscriptbuilder\.bumpconfig\.json'
        }
    }

    Context 'Scaffold - template content (with release management)' {

        BeforeAll {
            $request    = [PSScriptBuilderScaffoldingRequest]::new('RmTemplateProject', $TestDrive, $true, $false, $false)
            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $scaffolder.Scaffold() | Out-Null
            $templatePath          = [Path]::Combine($TestDrive, 'RmTemplateProject', 'build', 'Templates', 'RmTemplateProject.ps1.template')
            $script:templateContent = Get-Content $templatePath -Raw
        }

        It 'Should contain the auto-generated header comment' {
            $script:templateContent | Should -Match 'Auto-generated by PSScriptBuilder'
        }

        It 'Should contain version default value 0.1.0 as a comment' {
            $script:templateContent | Should -Match '# Version:\s+0\.1\.0'
        }

        It 'Should contain timestamp default value 1970-01-01T00:00:00Z as a comment' {
            $script:templateContent | Should -Match '# Timestamp:\s+1970-01-01T00:00:00Z'
        }

        It 'Should contain {{ENUM_DEFINITIONS}} placeholder' {
            $script:templateContent | Should -Match '\{\{ENUM_DEFINITIONS\}\}'
        }

        It 'Should contain {{CLASS_DEFINITIONS}} placeholder' {
            $script:templateContent | Should -Match '\{\{CLASS_DEFINITIONS\}\}'
        }

        It 'Should contain {{FUNCTION_DEFINITIONS}} placeholder' {
            $script:templateContent | Should -Match '\{\{FUNCTION_DEFINITIONS\}\}'
        }
    }
}
