using namespace System
using namespace System.IO

Describe 'PSScriptBuilderSourceMapFileManager' {

    BeforeAll {
        Function New-OutputFile {
            param([string] $FileName = 'output.ps1', [string] $Content = '# output script')
            $path = Join-Path $TestDrive $FileName
            [File]::WriteAllText($path, $Content, [Text.Encoding]::UTF8)
            return $path
        }

        Function New-Location {
            param(
                [string] $ComponentName       = 'MyClass',
                [string] $ComponentType       = 'Class',
                [string] $SourceFile          = 'C:\src\MyClass.ps1',
                [int]    $SourceLineNumber    = 1,
                [int]    $ComponentLineNumber = 1,
                [int]    $OutputLineNumber    = 1,
                [int]    $Offset              = 0,
                [int]    $ComponentLineCount  = 0
            )
            return [PSScriptBuilderSourceLocation]::new(
                $ComponentName, $ComponentType, $SourceFile,
                $SourceLineNumber, $ComponentLineNumber, $OutputLineNumber, $Offset, $ComponentLineCount)
        }

        # A valid format version 1 sidecar as object; schema tests change single fields before writing it
        Function New-SidecarData {
            $component = [PSCustomObject] @{
                ComponentName       = 'MyClass'
                ComponentType       = 'Class'
                SourceFile          = 'C:\src\MyClass.ps1'
                OutputLineNumber    = 5
                ComponentLineNumber = 1
                SourceLineNumber    = 1
                Offset              = 0
                ComponentLineCount  = 3
            }
            $data = [PSCustomObject] @{
                FormatVersion   = 1
                OutputPath      = 'C:\build\x.ps1'
                OutputHash      = 'A' * 64
                OutputLineCount = 10
                Components      = @($component)
            }
            return $data
        }

        Function Write-SidecarData {
            param([string] $FileName, [object] $Data)
            $path = Join-Path $TestDrive $FileName
            [File]::WriteAllText($path, (ConvertTo-Json -InputObject $Data -Depth 5))
            return $path
        }
    }

    #region GetSidecarPath

    Context 'GetSidecarPath' {

        It 'Should append .sourcemap.json to the output path' {
            $result = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('C:\build\output.ps1')

            $result | Should -Be 'C:\build\output.ps1.sourcemap.json'
        }

        It 'Should work with paths that already have an extension' {
            $result = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('C:\build\MyModule.psm1')

            $result | Should -Be 'C:\build\MyModule.psm1.sourcemap.json'
        }

        It 'Should throw ArgumentException when outputPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when outputPath is empty' {
            { [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when outputPath is whitespace' {
            { [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('   ') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    #endregion

    #region SourceMapExists

    Context 'SourceMapExists' {

        It 'Should return true when the sidecar file exists' {
            $sidecarPath = Join-Path $TestDrive 'exists.ps1.sourcemap.json'
            [File]::WriteAllText($sidecarPath, '{}', [Text.Encoding]::UTF8)

            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists($sidecarPath)

            $result | Should -BeTrue
        }

        It 'Should return false when the sidecar file does not exist' {
            $sidecarPath = Join-Path $TestDrive 'missing.ps1.sourcemap.json'

            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists($sidecarPath)

            $result | Should -BeFalse
        }

        It 'Should return false when sidecarPath is null' {
            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists($null)

            $result | Should -BeFalse
        }

        It 'Should return false when sidecarPath is empty' {
            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists('')

            $result | Should -BeFalse
        }
    }

    #endregion

    #region WriteSourceMapData / ReadSourceMapData roundtrip

    Context 'WriteSourceMapData' {

        It 'Should create the sidecar file alongside the output file' {
            $outputPath  = New-OutputFile 'write-test.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())

            Test-Path $sidecarPath | Should -BeTrue
        }

        It 'Should throw ArgumentException when outputPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($null, @()) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when sourceMap is null' {
            $outputPath = New-OutputFile 'null-map.ps1'

            { [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should write a sidecar with zero components for an empty source map' {
            $outputPath  = New-OutputFile 'empty-map.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components.Count | Should -Be 0
        }
    }

    Context 'WriteSourceMapData / ReadSourceMapData - roundtrip' {

        It 'Should round-trip a single source location correctly' {
            $outputPath  = New-OutputFile 'roundtrip-single.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $entry       = New-Location -ComponentName 'MyClass' -ComponentType 'Class' `
                -SourceFile 'C:\src\MyClass.ps1' -SourceLineNumber 14 -ComponentLineNumber 14 `
                -OutputLineNumber 100 -Offset 0

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @($entry))
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components.Count                | Should -Be 1
            $result.Components[0].ComponentName     | Should -Be 'MyClass'
            $result.Components[0].ComponentType     | Should -Be 'Class'
            $result.Components[0].SourceFile        | Should -Be 'C:\src\MyClass.ps1'
            $result.Components[0].SourceLineNumber  | Should -Be 14
            $result.Components[0].ComponentLineNumber | Should -Be 14
            $result.Components[0].OutputLineNumber  | Should -Be 100
            $result.Components[0].Offset            | Should -Be 0
        }

        It 'Should round-trip multiple source locations preserving order' {
            $outputPath  = New-OutputFile 'roundtrip-multi.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $entries = @(
                (New-Location -ComponentName 'EnumA' -ComponentType 'Enum' -OutputLineNumber 10),
                (New-Location -ComponentName 'ClassB' -ComponentType 'Class' -OutputLineNumber 20),
                (New-Location -ComponentName 'Get-Func' -ComponentType 'Function' -OutputLineNumber 30)
            )

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components.Count | Should -Be 3
            $result.Components[0].ComponentName | Should -Be 'EnumA'
            $result.Components[1].ComponentName | Should -Be 'ClassB'
            $result.Components[2].ComponentName | Should -Be 'Get-Func'
        }

        It 'Should store the OutputHash of the output file in the sidecar' {
            $outputPath  = New-OutputFile 'hash-test.ps1' '# known content'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $expectedHash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $storedHash = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath).OutputHash

            $storedHash | Should -Be $expectedHash
        }

        It 'Should store the line count of the output file in the sidecar' {
            $outputPath  = New-OutputFile 'linecount-test.ps1' "line1`nline2`nline3"
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $storedCount = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath).OutputLineCount

            $storedCount | Should -Be 3
        }

        It 'Should write the current format version to the sidecar' {
            $outputPath  = New-OutputFile 'format-version.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $raw = [File]::ReadAllText($sidecarPath) | ConvertFrom-Json

            $raw.FormatVersion | Should -Be 1
        }

        It 'Should round-trip ComponentLineCount' {
            $outputPath  = New-OutputFile 'roundtrip-linecount.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $entry       = New-Location -OutputLineNumber 100 -ComponentLineCount 25

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @($entry))
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components[0].ComponentLineCount | Should -Be 25
        }

        It 'Should write an unknown ComponentLineCount (0) as an absent field and read it back as 0' {
            $outputPath  = New-OutputFile 'roundtrip-unknown-linecount.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $entry       = New-Location -OutputLineNumber 1

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @($entry))
            $raw    = [File]::ReadAllText($sidecarPath) | ConvertFrom-Json
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $raw.Components[0].PSObject.Properties['ComponentLineCount'] | Should -BeNullOrEmpty
            $result.Components[0].ComponentLineCount                     | Should -Be 0
        }

        It 'Should read ComponentLineCount as 0 from a sidecar written by an earlier version' {
            $sidecarPath = Join-Path $TestDrive 'legacy.ps1.sourcemap.json'
            $json = '{"OutputPath":"C:\\build\\legacy.ps1","OutputHash":"' + ('A' * 64) + '","OutputLineCount":10,"Components":[' +
                    '{"ComponentName":"MyClass","ComponentType":"Class","OutputLineNumber":5,"Offset":0,' +
                    '"SourceFile":"C:\\src\\MyClass.ps1","ComponentLineNumber":1,"SourceLineNumber":1}]}'
            [File]::WriteAllText($sidecarPath, $json)

            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components[0].ComponentLineCount | Should -Be 0
            $result.Components[0].OutputLineNumber   | Should -Be 5
        }
    }

    #endregion

    #region ReadSourceMapData - error cases

    Context 'ReadSourceMapData - error cases' {

        It 'Should throw FileNotFoundException when sidecar does not exist' {
            $sidecarPath = Join-Path $TestDrive 'missing.ps1.sourcemap.json'

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }

        It 'Should throw ArgumentException when sidecarPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when sidecarPath is empty' {
            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData('') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw InvalidDataException when the sidecar is empty' {
            $sidecarPath = Join-Path $TestDrive 'empty.ps1.sourcemap.json'
            [File]::WriteAllText($sidecarPath, '')

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage '*is empty*'
        }

        It 'Should throw InvalidDataException when the sidecar uses a newer format version' {
            $sidecarPath = Join-Path $TestDrive 'newer-format.ps1.sourcemap.json'
            [File]::WriteAllText($sidecarPath, '{"FormatVersion":2,"OutputPath":"C:\\build\\x.ps1","OutputHash":"' + ('A' * 64) + '","OutputLineCount":1,"Components":[]}')

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage '*format version 2*-WriteSourceMap*'
        }

        It 'Should throw InvalidDataException, not a generic IOException, when the sidecar has an invalid format version' {
            $sidecarPath = Join-Path $TestDrive 'invalid-format.ps1.sourcemap.json'
            [File]::WriteAllText($sidecarPath, '{"FormatVersion":0,"OutputPath":"C:\\build\\x.ps1","OutputHash":"' + ('A' * 64) + '","OutputLineCount":1,"Components":[]}')

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException])
        }

        It 'Should throw InvalidDataException when the sidecar does not contain a JSON object (<Json>)' -ForEach @(
            @{ Json = '5' }
            @{ Json = '"text"' }
            @{ Json = '[1]' }
        ) {
            $sidecarPath = Join-Path $TestDrive 'not-an-object.ps1.sourcemap.json'
            [File]::WriteAllText($sidecarPath, $Json)

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage '*does not contain a JSON object*'
        }

        # e.g. left behind by an interrupted write
        It 'Should throw InvalidDataException, not a generic IOException, when the sidecar is truncated' {
            $sidecarPath = Join-Path $TestDrive 'truncated.ps1.sourcemap.json'
            [File]::WriteAllText($sidecarPath, '{"FormatVersion":1,"OutputPath":"C:\\build\\x.ps1","Outp')

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage '*could not be parsed as JSON*-WriteSourceMap*'
        }
    }

    #endregion

    #region ReadSourceMapData - schema validation

    Context 'ReadSourceMapData - schema validation' {

        It 'Should read a valid sidecar' {
            $sidecarPath = Write-SidecarData 'schema-valid.ps1.sourcemap.json' (New-SidecarData)

            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components.Count                 | Should -Be 1
            $result.Components[0].ComponentLineCount | Should -Be 3
        }

        It 'Should accept an OutputHash in lowercase hexadecimal characters' {
            $data = New-SidecarData
            $data.OutputHash = 'a' * 64
            $sidecarPath = Write-SidecarData 'schema-lowercase-hash.ps1.sourcemap.json' $data

            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.OutputHash | Should -Be ('a' * 64)
        }

        It 'Should ignore unknown fields at the top level and in component entries (Tolerant Reader)' {
            $data = New-SidecarData
            $data | Add-Member -NotePropertyName FutureField -NotePropertyValue 'x'
            $data.Components[0] | Add-Member -NotePropertyName FutureComponentField -NotePropertyValue 42
            $sidecarPath = Write-SidecarData 'schema-unknown-fields.ps1.sourcemap.json' $data

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } | Should -Not -Throw
        }

        It 'Should throw InvalidDataException naming the missing required field <Field>' -ForEach @(
            @{ Field = 'OutputPath';          Path = 'OutputPath' }
            @{ Field = 'OutputHash';          Path = 'OutputHash' }
            @{ Field = 'OutputLineCount';     Path = 'OutputLineCount' }
            @{ Field = 'Components';          Path = 'Components' }
            @{ Field = 'ComponentName';       Path = 'Components[0].ComponentName' }
            @{ Field = 'ComponentType';       Path = 'Components[0].ComponentType' }
            @{ Field = 'SourceFile';          Path = 'Components[0].SourceFile' }
            @{ Field = 'OutputLineNumber';    Path = 'Components[0].OutputLineNumber' }
            @{ Field = 'ComponentLineNumber'; Path = 'Components[0].ComponentLineNumber' }
            @{ Field = 'SourceLineNumber';    Path = 'Components[0].SourceLineNumber' }
            @{ Field = 'Offset';              Path = 'Components[0].Offset' }
        ) {
            $data = New-SidecarData
            if ($Path -like 'Components`[0`].*') {
                $data.Components[0].PSObject.Properties.Remove($Field)
            }
            else {
                $data.PSObject.Properties.Remove($Field)
            }
            $sidecarPath     = Write-SidecarData 'schema-missing.ps1.sourcemap.json' $data
            $expectedMessage = "*missing the required field '" + [WildcardPattern]::Escape($Path) + "'*"

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }

        # PowerShell would silently convert several of these (true -> 1, 1.5 -> 2, "1" -> 1, 5 -> "5")
        It 'Should throw InvalidDataException for <Path> = <Json>' -ForEach @(
            @{ Path = 'OutputPath';                         Json = '5' }
            @{ Path = 'OutputPath';                         Json = '""' }
            @{ Path = 'OutputHash';                         Json = '"xyz"' }
            @{ Path = 'OutputHash';                         Json = '""' }
            @{ Path = 'OutputLineCount';                    Json = '-1' }
            @{ Path = 'OutputLineCount';                    Json = '"abc"' }
            @{ Path = 'Components';                         Json = '{}' }
            @{ Path = 'Components[0].ComponentName';        Json = '""' }
            @{ Path = 'Components[0].ComponentType';        Json = '5' }
            @{ Path = 'Components[0].SourceFile';           Json = 'null' }
            @{ Path = 'Components[0].OutputLineNumber';     Json = '0' }
            @{ Path = 'Components[0].OutputLineNumber';     Json = 'true' }
            @{ Path = 'Components[0].ComponentLineNumber';  Json = '1.5' }
            @{ Path = 'Components[0].SourceLineNumber';     Json = '"1"' }
            @{ Path = 'Components[0].Offset';               Json = '-1' }
            @{ Path = 'Components[0].ComponentLineCount';   Json = '0' }
        ) {
            $data  = New-SidecarData
            $value = ConvertFrom-Json -InputObject ('{"v":' + $Json + '}')
            if ($Path -like 'Components`[0`].*') {
                $data.Components[0].($Path.Substring('Components[0].'.Length)) = $value.v
            }
            else {
                $data.$Path = $value.v
            }
            $sidecarPath     = Write-SidecarData 'schema-invalid.ps1.sourcemap.json' $data
            $expectedMessage = "*invalid value for '" + [WildcardPattern]::Escape($Path) + "'*"

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }

        It 'Should throw InvalidDataException naming the entry for a Components entry that is not an object (<Json>)' -ForEach @(
            @{ Json = '[null]' }
            @{ Json = '[1]' }
            @{ Json = '["text"]' }
        ) {
            $data            = New-SidecarData
            $data.Components = (ConvertFrom-Json -InputObject ('{"v":' + $Json + '}')).v
            $sidecarPath     = Write-SidecarData 'schema-entry-not-object.ps1.sourcemap.json' $data
            $expectedMessage = "*invalid value for '" + [WildcardPattern]::Escape('Components[0]') + "'*expected an object*"

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }

        It 'Should name the position of the invalid entry in the Components array' {
            $data   = New-SidecarData
            $second = $data.Components[0].PSObject.Copy()
            $second.OutputLineNumber = 0
            $data.Components = @($data.Components[0], $second)
            $sidecarPath     = Write-SidecarData 'schema-second-entry.ps1.sourcemap.json' $data
            $expectedMessage = "*invalid value for '" + [WildcardPattern]::Escape('Components[1].OutputLineNumber') + "'*"

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }
    }

    #endregion

    #region GetStaleWarnings

    Context 'GetStaleWarnings' {

        BeforeAll {
            # Calls GetStaleWarnings and returns its result together with anything written to the
            # warning and error streams, which must stay empty: the cmdlet writes the warnings itself
            Function Invoke-GetStaleWarnings {
                param([string] $StoredHash, [string] $OutputPath)
                $sourceMapData = [PSScriptBuilderSourceMapData]::new($OutputPath, $StoredHash, 0, @())
                $holder        = @{}
                $streamed      = @(& { $holder.Result = [PSScriptBuilderSourceMapFileManager]::GetStaleWarnings($sourceMapData, $OutputPath) } 2>&1 3>&1)
                $records = [PSCustomObject] @{
                    Warnings = $holder.Result
                    Streamed = $streamed
                }
                return $records
            }
        }

        It 'Should return an empty array when the output script is unchanged' {
            $outputPath = New-OutputFile 'stale-unchanged.ps1'
            $storedHash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash

            $records = Invoke-GetStaleWarnings -StoredHash $storedHash -OutputPath $outputPath

            # An empty array, not $null (Framework Design Guidelines for collections)
            $null -eq $records.Warnings | Should -BeFalse
            $records.Warnings.Count     | Should -Be 0
            $records.Streamed.Count     | Should -Be 0
        }

        It 'Should return no warning when the stored hash differs only in letter case' {
            $outputPath = New-OutputFile 'stale-lowercase.ps1'
            $storedHash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()

            $records = Invoke-GetStaleWarnings -StoredHash $storedHash -OutputPath $outputPath

            $records.Warnings.Count | Should -Be 0
        }

        It 'Should return the stale warning when the output script has changed' {
            $outputPath = New-OutputFile 'stale-changed.ps1'

            $records = Invoke-GetStaleWarnings -StoredHash ('0' * 64) -OutputPath $outputPath

            $records.Warnings.Count | Should -Be 1
            $records.Warnings[0]    | Should -BeLike '*may be stale*'
            $records.Streamed.Count | Should -Be 0
        }

        It 'Should return exactly one warning, without writing an error, when the output script cannot be read (<Case>)' -ForEach @(
            @{ Case = 'missing file' }
            @{ Case = 'missing directory' }
            @{ Case = 'path is a directory' }
        ) {
            $outputPath = switch ($Case) {
                'missing file'        { Join-Path $TestDrive 'stale-no-such-file.ps1' }
                'missing directory'   { [Path]::Combine($TestDrive, 'no-such-dir', 'out.ps1') }
                'path is a directory' { $TestDrive }
            }

            $records = Invoke-GetStaleWarnings -StoredHash ('0' * 64) -OutputPath $outputPath

            $records.Warnings.Count | Should -Be 1
            $records.Warnings[0]    | Should -BeLike '*could not be read*cannot be checked whether the source map is stale*'
            $records.Streamed.Count | Should -Be 0
        }

        It 'Should return exactly one warning, without writing an error, when the output script is locked' -Skip:($env:OS -ne 'Windows_NT') {
            # Exclusive file locks are only enforced on Windows
            $outputPath = New-OutputFile 'stale-locked.ps1'
            $storedHash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash

            $lockHandle = [File]::Open($outputPath, [FileMode]::Open, [FileAccess]::Read, [FileShare]::None)
            try {
                $records = Invoke-GetStaleWarnings -StoredHash $storedHash -OutputPath $outputPath
            }
            finally {
                $lockHandle.Dispose()
            }

            $records.Warnings.Count | Should -Be 1
            $records.Warnings[0]    | Should -BeLike '*could not be read*'
            $records.Streamed.Count | Should -Be 0
        }
    }

    #endregion GetStaleWarnings
}
