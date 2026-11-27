using namespace System
using namespace System.IO

Describe 'PSScriptBuilderSourceMapSerializer' {

    BeforeAll {
        $script:SidecarPath = 'C:\build\x.ps1.sourcemap.json'

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

        Function New-SourceMapData {
            param([PSScriptBuilderSourceLocation[]] $Components = @())
            return [PSScriptBuilderSourceMapData]::new('C:\build\x.ps1', ('A' * 64), 10, $Components)
        }

        # Runs the script block with verbose output enabled and returns its result together with
        # everything written to any stream, which must stay empty: the serializer is a pure
        # conversion, progress and diagnostics are written by the file manager
        Function Invoke-WithAllStreams {
            param([scriptblock] $ScriptBlock)
            $savedPreference          = $Global:VerbosePreference
            $Global:VerbosePreference = 'Continue'
            try {
                $holder   = @{}
                $streamed = @(& { $holder.Result = & $ScriptBlock } *>&1)
            }
            finally {
                $Global:VerbosePreference = $savedPreference
            }
            $records = [PSCustomObject] @{
                Result   = $holder.Result
                Streamed = $streamed
            }
            return $records
        }
    }

    #region Serialize

    Context 'Serialize' {

        It 'Should throw ArgumentException when sourceMapData is null' {
            { [PSScriptBuilderSourceMapSerializer]::Serialize($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should write FormatVersion as the first field with the current format version' {
            $json = [PSScriptBuilderSourceMapSerializer]::Serialize((New-SourceMapData))
            $raw  = $json | ConvertFrom-Json

            $raw.PSObject.Properties.Name[0] | Should -Be 'FormatVersion'
            $raw.FormatVersion               | Should -Be ([PSScriptBuilderSourceMapSerializer]::SourceMapFormatVersion)
        }

        It 'Should write the output path, hash and line count' {
            $raw = [PSScriptBuilderSourceMapSerializer]::Serialize((New-SourceMapData)) | ConvertFrom-Json

            $raw.OutputPath      | Should -Be 'C:\build\x.ps1'
            $raw.OutputHash      | Should -Be ('A' * 64)
            $raw.OutputLineCount | Should -Be 10
        }

        It 'Should write an empty Components array for an empty source map' {
            $raw = [PSScriptBuilderSourceMapSerializer]::Serialize((New-SourceMapData)) | ConvertFrom-Json

            $raw.PSObject.Properties.Name -contains 'Components' | Should -BeTrue
            @($raw.Components).Count                            | Should -Be 0
        }

        It 'Should write a known ComponentLineCount and omit an unknown one (0)' {
            $components = @(
                New-Location -ComponentName 'Known'   -ComponentLineCount 5
                New-Location -ComponentName 'Unknown' -ComponentLineCount 0
            )

            $raw = [PSScriptBuilderSourceMapSerializer]::Serialize((New-SourceMapData -Components $components)) | ConvertFrom-Json

            $raw.Components[0].ComponentLineCount                                      | Should -Be 5
            $raw.Components[1].PSObject.Properties.Name -contains 'ComponentLineCount' | Should -BeFalse
        }

        It 'Should round-trip through Deserialize' {
            $components = @(
                New-Location -ComponentName 'MyClass' -SourceFile 'C:\src\My "Quoted" Class.ps1' -OutputLineNumber 5 -ComponentLineCount 3
                New-Location -ComponentName 'Get-Func' -ComponentType 'Function' -SourceLineNumber 4 -ComponentLineNumber 4 -OutputLineNumber 9
            )

            $json   = [PSScriptBuilderSourceMapSerializer]::Serialize((New-SourceMapData -Components $components))
            $result = [PSScriptBuilderSourceMapSerializer]::Deserialize($json, $script:SidecarPath)

            $result.OutputPath                       | Should -Be 'C:\build\x.ps1'
            $result.OutputHash                       | Should -Be ('A' * 64)
            $result.OutputLineCount                  | Should -Be 10
            $result.Components.Count                 | Should -Be 2
            $result.Components[0].SourceFile         | Should -Be 'C:\src\My "Quoted" Class.ps1'
            $result.Components[0].ComponentLineCount | Should -Be 3
            $result.Components[1].ComponentName      | Should -Be 'Get-Func'
            $result.Components[1].ComponentType      | Should -Be 'Function'
            $result.Components[1].SourceLineNumber   | Should -Be 4
            $result.Components[1].OutputLineNumber   | Should -Be 9
            $result.Components[1].ComponentLineCount | Should -Be 0
        }

        It 'Should write nothing to the verbose, warning or error stream' {
            $records = Invoke-WithAllStreams { [PSScriptBuilderSourceMapSerializer]::Serialize((New-SourceMapData -Components @(New-Location))) }

            $records.Result         | Should -Not -BeNullOrEmpty
            $records.Streamed.Count | Should -Be 0
        }
    }

    #endregion Serialize

    #region Deserialize

    Context 'Deserialize' {

        It 'Should read a valid sidecar' {
            $json = '{"FormatVersion":1,"OutputPath":"C:\\build\\x.ps1","OutputHash":"' + ('A' * 64) + '","OutputLineCount":10,' +
                    '"Components":[{"ComponentName":"MyClass","ComponentType":"Class","OutputLineNumber":5,"Offset":0,' +
                    '"SourceFile":"C:\\src\\MyClass.ps1","ComponentLineNumber":1,"SourceLineNumber":1,"ComponentLineCount":3}]}'

            $result = [PSScriptBuilderSourceMapSerializer]::Deserialize($json, $script:SidecarPath)

            $result                                  | Should -BeOfType ([PSScriptBuilderSourceMapData])
            $result.Components.Count                 | Should -Be 1
            $result.Components[0].ComponentName      | Should -Be 'MyClass'
            $result.Components[0].ComponentLineCount | Should -Be 3
        }

        # A [string] parameter receives $null as an empty string, so both are an empty sidecar
        It 'Should throw InvalidDataException naming the sidecar for empty content (<Case>)' -ForEach @(
            @{ Case = 'null';       Json = $null }
            @{ Case = 'empty';      Json = '' }
            @{ Case = 'whitespace'; Json = "  `r`n " }
        ) {
            $expectedMessage = '*' + [WildcardPattern]::Escape($script:SidecarPath) + ' is empty*-WriteSourceMap*'

            { [PSScriptBuilderSourceMapSerializer]::Deserialize($Json, $script:SidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }

        # null is valid JSON, but not an object - it must not be reported as an empty sidecar
        It 'Should throw InvalidDataException when the content is not a JSON object (<Json>)' -ForEach @(
            @{ Json = '42' }
            @{ Json = '"text"' }
            @{ Json = '[1,2]' }
            @{ Json = 'null' }
        ) {
            { [PSScriptBuilderSourceMapSerializer]::Deserialize($Json, $script:SidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage '*does not contain a JSON object*'
        }

        It 'Should throw InvalidDataException wrapping the parser exception for malformed JSON (<Case>)' -ForEach @(
            @{ Case = 'truncated';         Json = '{"FormatVersion":1,"Outp' }
            @{ Case = 'not JSON';          Json = 'hello' }
            @{ Case = 'text after object'; Json = '{"a":1}}' }
        ) {
            $expectedMessage = '*' + [WildcardPattern]::Escape($script:SidecarPath) + ' could not be parsed as JSON*-WriteSourceMap*'

            $thrown = $null
            try {
                $null = [PSScriptBuilderSourceMapSerializer]::Deserialize($Json, $script:SidecarPath)
            }
            catch {
                $thrown = $_.Exception
            }

            $thrown                | Should -BeOfType ([InvalidDataException])
            $thrown.Message        | Should -BeLike $expectedMessage
            $thrown.InnerException | Should -BeOfType ([ArgumentException])
        }

        # Valid JSON that ConvertFrom-Json cannot represent as an object, in both PowerShell versions
        It 'Should throw InvalidDataException wrapping the parser exception for keys differing only in letter case' {
            $thrown = $null
            try {
                $null = [PSScriptBuilderSourceMapSerializer]::Deserialize('{"a":1,"A":2}', $script:SidecarPath)
            }
            catch {
                $thrown = $_.Exception
            }

            $thrown                | Should -BeOfType ([InvalidDataException])
            $thrown.Message        | Should -BeLike '*could not be parsed as JSON*'
            $thrown.InnerException | Should -BeOfType ([InvalidOperationException])
        }

        # Windows PowerShell 5.1 appends the complete JSON text to its parser message
        It 'Should limit the parser message in the error for a large malformed sidecar' {
            $entries = (1..2000 | ForEach-Object { '{"ComponentName":"C' + $_ + '","OutputLineNumber":' + $_ + '}' }) -join ','
            $json    = '{"FormatVersion":1,"Components":[' + $entries + '],"Outp'

            $thrown = $null
            try {
                $null = [PSScriptBuilderSourceMapSerializer]::Deserialize($json, $script:SidecarPath)
            }
            catch {
                $thrown = $_.Exception
            }

            $json.Length           | Should -BeGreaterThan 90000
            $thrown                | Should -BeOfType ([InvalidDataException])
            $thrown.Message.Length | Should -BeLessThan 600
        }

        It 'Should throw InvalidDataException for a newer format version before validating other fields' {
            # Only FormatVersion is present: a schema violation must not hide the version problem
            { [PSScriptBuilderSourceMapSerializer]::Deserialize('{"FormatVersion":2}', $script:SidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage '*format version 2*'
        }

        It 'Should throw InvalidDataException naming the missing required field' {
            { [PSScriptBuilderSourceMapSerializer]::Deserialize('{"FormatVersion":1}', $script:SidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage "*missing the required field 'OutputPath'*"
        }

        It 'Should write nothing to the verbose, warning or error stream' {
            $json    = [PSScriptBuilderSourceMapSerializer]::Serialize((New-SourceMapData -Components @(New-Location)))
            $records = Invoke-WithAllStreams { [PSScriptBuilderSourceMapSerializer]::Deserialize($json, $script:SidecarPath) }

            $records.Result.Components.Count | Should -Be 1
            $records.Streamed.Count          | Should -Be 0
        }
    }

    #endregion Deserialize

    #region ReadFields

    Context 'ReadFields' {

        BeforeAll {
            $script:SidecarPath = 'C:\build\x.ps1.sourcemap.json'

            # Reads the JSON value under a one-field schema with the given rule
            Function Invoke-ReadFields {
                param([string] $Json, [hashtable] $Rule)
                $container = ConvertFrom-Json -InputObject ('{"v":' + $Json + '}')
                $schema    = [ordered] @{ v = $Rule }
                $fields    = [PSScriptBuilderSourceMapSerializer]::ReadFields($container, $schema, '', $script:SidecarPath)
                return $fields.v
            }
        }

        It 'Should return the default of an absent optional field (FormatVersion of a sidecar written by an earlier version)' {
            $data = '{"OutputPath":"C:\\build\\x.ps1"}' | ConvertFrom-Json

            $fields = [PSScriptBuilderSourceMapSerializer]::ReadFields($data, [PSScriptBuilderSourceMapSerializer]::VersionSchema, '', $script:SidecarPath)

            $fields.FormatVersion | Should -Be 1
        }

        It 'Should return one entry per schema field' {
            $data = '{"a":"x","b":2}' | ConvertFrom-Json
            $schema = [ordered] @{
                a = @{ Required = $true;  Type = 'String' }
                b = @{ Required = $true;  Type = 'WholeNumber'; Minimum = 0 }
                c = @{ Required = $false; Type = 'WholeNumber'; Minimum = 1; Default = 0 }
            }

            $fields = [PSScriptBuilderSourceMapSerializer]::ReadFields($data, $schema, '', $script:SidecarPath)

            $fields.Keys.Count | Should -Be 3
            $fields.a          | Should -Be 'x'
            $fields.b          | Should -Be 2
            $fields.c          | Should -Be 0
        }

        It 'Should throw InvalidDataException naming the field path for an absent required field' {
            $data            = '{}' | ConvertFrom-Json
            $schema          = [ordered] @{ OutputPath = @{ Required = $true; Type = 'String' } }
            $expectedMessage = "*missing the required field '" + [WildcardPattern]::Escape('Components[2].OutputPath') + "'*"

            { [PSScriptBuilderSourceMapSerializer]::ReadFields($data, $schema, 'Components[2].', $script:SidecarPath) } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }

        # One case per kind of invalid value: boolean, null and string
        It 'Should throw InvalidDataException showing the invalid value <Json> in JSON notation' -ForEach @(
            @{ Json = 'true' }
            @{ Json = 'null' }
            @{ Json = '"2"' }
        ) {
            $rule            = @{ Required = $true; Type = 'WholeNumber'; Minimum = 1 }
            $expectedMessage = '*(' + [WildcardPattern]::Escape($Json) + ')*expected a whole number of at least 1*'

            { Invoke-ReadFields -Json $Json -Rule $rule } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }

        It 'Should throw ArgumentException for an unknown rule type' {
            $rule = @{ Required = $true; Type = 'NoSuchType' }

            { Invoke-ReadFields -Json '"x"' -Rule $rule } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should accept <Json> as <Type>' -ForEach @(
            @{ Type = 'String';     Json = '"MyClass"' }
            @{ Type = 'Sha256Hash'; Json = '"' + ('0123456789abcdef' * 4) + '"' }
            @{ Type = 'Array';      Json = '[]' }
            @{ Type = 'Array';      Json = '[{"X":1}]' }
        ) {
            $rule = @{ Required = $true; Type = $Type }

            { Invoke-ReadFields -Json $Json -Rule $rule } | Should -Not -Throw
        }

        # No conversion between types: a number is not a string, a string of digits is not a hash
        It 'Should reject <Json> as <Type>' -ForEach @(
            @{ Type = 'String';     Json = '5' }
            @{ Type = 'String';     Json = '""' }
            @{ Type = 'String';     Json = '"   "' }
            @{ Type = 'String';     Json = 'null' }
            @{ Type = 'Sha256Hash'; Json = '"ABC"' }
            @{ Type = 'Sha256Hash'; Json = '"' + ('G' * 64) + '"' }
            @{ Type = 'Sha256Hash'; Json = '1' }
            @{ Type = 'Array';      Json = '{}' }
            @{ Type = 'Array';      Json = '"text"' }
            @{ Type = 'Array';      Json = 'null' }
        ) {
            $rule = @{ Required = $true; Type = $Type }

            { Invoke-ReadFields -Json $Json -Rule $rule } | Should -Throw -ExceptionType ([InvalidDataException])
        }

        # JSON has a single number type: every notation of a whole number in range is accepted
        It 'Should accept the whole number <Json> as <Expected> with minimum <Minimum>' -ForEach @(
            @{ Json = '1';          Minimum = 1; Expected = 1 }
            @{ Json = '1.0';        Minimum = 1; Expected = 1 }
            @{ Json = '1e0';        Minimum = 1; Expected = 1 }
            @{ Json = '2.0';        Minimum = 1; Expected = 2 }
            @{ Json = '2147483647'; Minimum = 1; Expected = 2147483647 }
            @{ Json = '0';          Minimum = 0; Expected = 0 }
        ) {
            $rule = @{ Required = $true; Type = 'WholeNumber'; Minimum = $Minimum }

            $result = Invoke-ReadFields -Json $Json -Rule $rule

            $result | Should -BeOfType ([int])
            $result | Should -Be $Expected
        }

        # PowerShell itself would convert several of these (true -> 1, 1.5 -> 2, "2" -> 2)
        It 'Should reject <Json> as whole number with minimum <Minimum>' -ForEach @(
            @{ Json = 'null';       Minimum = 1 }
            @{ Json = 'true';       Minimum = 1 }
            @{ Json = 'false';      Minimum = 0 }
            @{ Json = '0';          Minimum = 1 }
            @{ Json = '-1';         Minimum = 0 }
            @{ Json = '1.5';        Minimum = 1 }
            @{ Json = '1e20';       Minimum = 1 }
            @{ Json = '3000000000'; Minimum = 1 }
            @{ Json = '"2"';        Minimum = 1 }
            @{ Json = '"abc"';      Minimum = 1 }
            @{ Json = '[1]';        Minimum = 1 }
            @{ Json = '{}';         Minimum = 1 }
        ) {
            $rule = @{ Required = $true; Type = 'WholeNumber'; Minimum = $Minimum }

            { Invoke-ReadFields -Json $Json -Rule $rule } | Should -Throw -ExceptionType ([InvalidDataException])
        }
    }

    #endregion ReadFields

    #region ThrowIfUnsupportedFormatVersion

    Context 'ThrowIfUnsupportedFormatVersion' {

        It 'Should not throw for the supported format version' {
            $supportedVersion = [PSScriptBuilderSourceMapSerializer]::SourceMapFormatVersion

            { [PSScriptBuilderSourceMapSerializer]::ThrowIfUnsupportedFormatVersion($supportedVersion, 'C:\build\x.ps1.sourcemap.json') } |
                Should -Not -Throw
        }

        It 'Should throw InvalidDataException naming both versions for a newer format version' {
            $supportedVersion = [PSScriptBuilderSourceMapSerializer]::SourceMapFormatVersion
            $newerVersion     = $supportedVersion + 1
            $expectedMessage  = "*format version $newerVersion*up to format version $supportedVersion*"

            { [PSScriptBuilderSourceMapSerializer]::ThrowIfUnsupportedFormatVersion($newerVersion, 'C:\build\x.ps1.sourcemap.json') } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }
    }

    #endregion ThrowIfUnsupportedFormatVersion

    #region ConvertToSourceLocation

    Context 'ConvertToSourceLocation' {

        It 'Should map every field of a component entry' {
            $component = '{"ComponentName":"MyClass","ComponentType":"Class","OutputLineNumber":100,"Offset":0,' +
                         '"SourceFile":"C:\\src\\MyClass.ps1","ComponentLineNumber":14,"SourceLineNumber":14,"ComponentLineCount":25}' |
                         ConvertFrom-Json

            $result = [PSScriptBuilderSourceMapSerializer]::ConvertToSourceLocation($component, 0, 'C:\build\x.ps1.sourcemap.json')

            $result.ComponentName       | Should -Be 'MyClass'
            $result.ComponentType       | Should -Be 'Class'
            $result.SourceFile          | Should -Be 'C:\src\MyClass.ps1'
            $result.SourceLineNumber    | Should -Be 14
            $result.ComponentLineNumber | Should -Be 14
            $result.OutputLineNumber    | Should -Be 100
            $result.Offset              | Should -Be 0
            $result.ComponentLineCount  | Should -Be 25
        }

        It 'Should set ComponentLineCount to 0 for an entry written by an earlier version' {
            $component = '{"ComponentName":"MyClass","ComponentType":"Class","OutputLineNumber":100,"Offset":0,' +
                         '"SourceFile":"C:\\src\\MyClass.ps1","ComponentLineNumber":14,"SourceLineNumber":14}' |
                         ConvertFrom-Json

            $result = [PSScriptBuilderSourceMapSerializer]::ConvertToSourceLocation($component, 0, 'C:\build\x.ps1.sourcemap.json')

            $result.ComponentLineCount | Should -Be 0
        }

        It 'Should name the entry by its index when a field is invalid' {
            $component = '{"ComponentName":"MyClass","ComponentType":"Class","OutputLineNumber":0,"Offset":0,' +
                         '"SourceFile":"C:\\src\\MyClass.ps1","ComponentLineNumber":14,"SourceLineNumber":14}' |
                         ConvertFrom-Json
            $expectedMessage = "*invalid value for '" + [WildcardPattern]::Escape('Components[7].OutputLineNumber') + "'*"

            { [PSScriptBuilderSourceMapSerializer]::ConvertToSourceLocation($component, 7, 'C:\build\x.ps1.sourcemap.json') } |
                Should -Throw -ExceptionType ([InvalidDataException]) -ExpectedMessage $expectedMessage
        }
    }

    #endregion ConvertToSourceLocation
}
