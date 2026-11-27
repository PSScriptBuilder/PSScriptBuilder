using namespace System
using namespace System.IO

Describe 'Compress-PSScriptBuilderScript' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestScript {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            [File]::WriteAllText($path, $Content, [System.Text.Encoding]::UTF8)
            return $path
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Guard Clauses - Input
    Context 'Guard Clauses - Input' {

        It 'Should throw FileNotFoundException when Path does not exist' {
            { Compress-PSScriptBuilderScript -Path 'C:\nonexistent\file.ps1' -RemoveComments } | Should -Throw
        }
    }
    #endregion Guard Clauses - Input

    #region Guard Clauses - OutputPath
    Context 'Guard Clauses - OutputPath' {

        It 'Should throw IOException when OutputPath already exists and -Force is not set' {
            $inputPath  = New-TestScript -FileName 'input.ps1'  -Content '$x = 1'
            $outputPath = New-TestScript -FileName 'output.ps1' -Content 'existing content'

            { Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments -DestinationPath $outputPath } | Should -Throw
        }

        It 'Should not throw when OutputPath already exists and -Force is set' {
            $inputPath  = New-TestScript -FileName 'input2.ps1'  -Content '$x = 1'
            $outputPath = New-TestScript -FileName 'output2.ps1' -Content 'existing content'

            { Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments -DestinationPath $outputPath -Force } | Should -Not -Throw
        }
    }
    #endregion Guard Clauses - OutputPath

    #region RemoveComments
    Context 'RemoveComments' {

        It 'Should remove comments and return result to pipeline when no OutputPath is given' {
            $inputPath = New-TestScript -FileName 'comments.ps1' -Content "# comment`n`$x = 1"

            $result = Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments

            $result | Should -Not -Match '# comment'
            $result | Should -Match '\$x = 1'
        }

        It 'Should write result to OutputPath when specified' {
            $inputPath  = New-TestScript -FileName 'comments2.ps1'  -Content "# comment`n`$x = 1"
            $outputPath = Join-Path $TestDrive 'comments2.out.ps1'

            Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments -DestinationPath $outputPath

            [File]::Exists($outputPath) | Should -BeTrue
            $written = [File]::ReadAllText($outputPath)
            $written | Should -Not -Match '# comment'
            $written | Should -Match '\$x = 1'
        }
    }
    #endregion RemoveComments

    #region RemoveBlankLines
    Context 'RemoveBlankLines' {

        It 'Should remove blank lines and return result to pipeline' {
            $inputPath = New-TestScript -FileName 'blanks.ps1' -Content "`$x = 1`n`n`$y = 2"

            $result = Compress-PSScriptBuilderScript -Path $inputPath -RemoveBlankLines

            $result | Should -Not -Match '\n\n'
            $result | Should -Match '\$x = 1'
            $result | Should -Match '\$y = 2'
        }
    }
    #endregion RemoveBlankLines

    #region RemoveOutputStatements
    Context 'RemoveOutputStatements' {

        It 'Should remove isolated Write-Verbose calls and return result to pipeline' {
            $inputPath = New-TestScript -FileName 'verbose.ps1' -Content "`$x = 1`nWrite-Verbose `"test`"`n`$y = 2"

            $result = Compress-PSScriptBuilderScript -Path $inputPath -RemoveOutputStatements 'Write-Verbose'

            $result | Should -Not -Match 'Write-Verbose'
            $result | Should -Match '\$x = 1'
            $result | Should -Match '\$y = 2'
        }
    }
    #endregion RemoveOutputStatements

    #region Pipeline Input
    Context 'Pipeline Input' {

        It 'Should accept Path via ValueFromPipelineByPropertyName' {
            $inputPath = New-TestScript -FileName 'pipeline.ps1' -Content "# comment`n`$x = 1"

            $pipelineInput = [PSCustomObject]@{ Path = $inputPath }
            $result        = $pipelineInput | Compress-PSScriptBuilderScript -RemoveComments

            $result | Should -Not -Match '# comment'
            $result | Should -Match '\$x = 1'
        }
    }
    #endregion Pipeline Input

    #region Combined Operations
    Context 'Combined Operations' {

        It 'Should apply RemoveComments and RemoveBlankLines in correct order' {
            $inputPath = New-TestScript -FileName 'combined.ps1' -Content "# comment`n`n`$x = 1"

            $result = Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments -RemoveBlankLines

            $result | Should -Not -Match '# comment'
            ($result -split '\r?\n') | Where-Object { [string]::IsNullOrWhiteSpace($_) } | Should -BeNullOrEmpty
            $result | Should -Match '\$x = 1'
        }
    }
    #endregion Combined Operations

    #region Verbose Output - Size Reduction
    Context 'Verbose Output - Size Reduction' {

        It 'Should emit a Size verbose message when DestinationPath is specified' {
            $inputPath  = New-TestScript -FileName 'size-verbose.ps1' -Content "# comment`n`$x = 1"
            $outputPath = Join-Path $TestDrive 'size-verbose.out.ps1'

            $verboseMessages = Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments -DestinationPath $outputPath -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
                ForEach-Object { $_.Message }

            $verboseMessages | Where-Object { $_ -match '^  Size:.*->.*\(saved .*,\s*\d+(\.\d+)?%\)$' } | Should -Not -BeNullOrEmpty
        }

        It 'Should format size in B when both files are smaller than 1 KB' {
            $inputPath  = New-TestScript -FileName 'size-b.ps1' -Content "# comment`n`$x = 1"
            $outputPath = Join-Path $TestDrive 'size-b.out.ps1'

            $verboseMessages = Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments -DestinationPath $outputPath -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
                ForEach-Object { $_.Message }

            $sizeMessage = $verboseMessages | Where-Object { $_ -match '^  Size:' }
            $sizeMessage | Should -Match '\d+ B'
        }

        It 'Should format size in KB when input file is 1 KB or larger' {
            $largeContent = ('$x = 1' + "`n") * 200
            $inputPath    = New-TestScript -FileName 'size-kb.ps1' -Content $largeContent
            $outputPath   = Join-Path $TestDrive 'size-kb.out.ps1'

            $verboseMessages = Compress-PSScriptBuilderScript -Path $inputPath -RemoveBlankLines -DestinationPath $outputPath -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
                ForEach-Object { $_.Message }

            $sizeMessage = $verboseMessages | Where-Object { $_ -match '^  Size:' }
            $sizeMessage | Should -Match '\d+\.\d+ KB'
        }

        It 'Should not emit a Size verbose message when no DestinationPath is specified' {
            $inputPath = New-TestScript -FileName 'size-no-dest.ps1' -Content "# comment`n`$x = 1"

            $verboseMessages = Compress-PSScriptBuilderScript -Path $inputPath -RemoveComments -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
                ForEach-Object { $_.Message }

            $verboseMessages | Where-Object { $_ -match '^  Size:' } | Should -BeNullOrEmpty
        }
    }
    #endregion Verbose Output - Size Reduction
}
