using namespace System.IO
using namespace System.Text

Describe 'PSScriptBuilderFileIOHelper' {

    BeforeAll {
        # PowerShell wraps an exception of a .NET call in MethodInvocationException, which
        # Should -Throw -ExceptionType does not unwrap
        Function Get-ThrownException {
            param([scriptblock] $ScriptBlock)
            try {
                & $ScriptBlock
            }
            catch {
                $exception = $_.Exception
                while ($exception -is [System.Management.Automation.MethodInvocationException] -and $null -ne $exception.InnerException) {
                    $exception = $exception.InnerException
                }
                return $exception
            }
            return $null
        }
    }

    #region Static Properties
    Context 'utf8EncodingWithBOM - static property' {

        It 'Should expose a UTF8Encoding instance' {
            [PSScriptBuilderFileIOHelper]::utf8EncodingWithBOM |
                Should -BeOfType ([UTF8Encoding])
        }

        It 'Should have BOM enabled' {
            [PSScriptBuilderFileIOHelper]::utf8EncodingWithBOM.GetPreamble().Length |
                Should -Be 3
        }
    }
    #endregion Static Properties

    #region ReadAllTextUTF8WithBOM
    Context 'ReadAllTextUTF8WithBOM' {

        It 'Should read the content of an existing file' {
            $filePath = Join-Path $TestDrive 'read-test.txt'
            $expected = 'Hello UTF8'
            [File]::WriteAllText($filePath, $expected, [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be $expected
        }

        It 'Should read multi-line content correctly' {
            $filePath = Join-Path $TestDrive 'read-multiline.txt'
            $expected = "line1`r`nline2`r`nline3"
            [File]::WriteAllText($filePath, $expected, [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be $expected
        }

        It 'Should read an empty file as empty string' {
            $filePath = Join-Path $TestDrive 'read-empty.txt'
            [File]::WriteAllText($filePath, '', [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be ''
        }
    }
    #endregion ReadAllTextUTF8WithBOM

    #region ReadAllBytes
    Context 'ReadAllBytes' {

        It 'Should return the exact bytes of the file, byte order mark included' {
            $filePath = Join-Path $TestDrive 'read-bytes.txt'
            [File]::WriteAllText($filePath, 'abc', [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllBytes($filePath)

            ($result | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' | Should -Be 'EF BB BF 61 62 63'
        }

        It 'Should return an empty array for an empty file' {
            $filePath = Join-Path $TestDrive 'read-bytes-empty.txt'
            [File]::WriteAllBytes($filePath, [byte[]]::new(0))

            $result = [PSScriptBuilderFileIOHelper]::ReadAllBytes($filePath)

            $result.Length | Should -Be 0
        }

        It 'Should throw when the file does not exist' {
            $filePath = Join-Path $TestDrive 'read-bytes-missing.txt'

            { [PSScriptBuilderFileIOHelper]::ReadAllBytes($filePath) } | Should -Throw
        }
    }
    #endregion ReadAllBytes

    #region DecodeUTF8WithBOM
    Context 'DecodeUTF8WithBOM' {

        BeforeAll {
            $script:Umlauts = 'Gr' + [char] 0xFC + [char] 0xDF + 'e'
        }

        # The text must be exactly what ReadAllTextUTF8WithBOM returns for the same file
        It 'Should decode <Case> exactly as ReadAllTextUTF8WithBOM reads it' -ForEach @(
            @{ Case = 'UTF-8 with BOM';    Encoding = [UTF8Encoding]::new($true) }
            @{ Case = 'UTF-8 without BOM'; Encoding = [UTF8Encoding]::new($false) }
            @{ Case = 'UTF-16 LE';         Encoding = [UnicodeEncoding]::new($false, $true) }
            @{ Case = 'UTF-16 BE';         Encoding = [UnicodeEncoding]::new($true, $true) }
        ) {
            $filePath = Join-Path $TestDrive ('decode-' + ($Case -replace '\W', '') + '.txt')
            [File]::WriteAllText($filePath, "line1`r`nVersion $script:Umlauts", $Encoding)

            $expected = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)
            $result   = [PSScriptBuilderFileIOHelper]::DecodeUTF8WithBOM([File]::ReadAllBytes($filePath))

            $result | Should -BeExactly $expected
        }

        It 'Should decode empty bytes as an empty string' {
            [PSScriptBuilderFileIOHelper]::DecodeUTF8WithBOM([byte[]]::new(0)) | Should -Be ''
        }

        It 'Should throw a DecoderFallbackException for invalid UTF-8' {
            $invalid = [byte[]] (0x41, 0xFC, 0x42)

            $thrown = Get-ThrownException { [PSScriptBuilderFileIOHelper]::DecodeUTF8WithBOM($invalid) }

            $thrown | Should -BeOfType ([DecoderFallbackException])
        }

        It 'Should throw ArgumentNullException for $null' {
            { [PSScriptBuilderFileIOHelper]::DecodeUTF8WithBOM($null) } |
                Should -Throw -ExceptionType ([System.ArgumentNullException])
        }
    }
    #endregion DecodeUTF8WithBOM

    #region EncodeUTF8WithBOM
    Context 'EncodeUTF8WithBOM' {

        # The bytes must be exactly what WriteAllTextUTF8WithBOM writes for the same text
        It 'Should encode <Case> exactly as WriteAllTextUTF8WithBOM writes it' -ForEach @(
            @{ Case = 'text';  Text = "{`r`n  `"a`": 1`r`n} " + [char] 0xFC }
            @{ Case = 'empty'; Text = '' }
            @{ Case = 'null';  Text = $null }
        ) {
            $filePath = Join-Path $TestDrive "encode-$Case.txt"
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, $Text)
            $expected = [File]::ReadAllBytes($filePath)

            $result = [PSScriptBuilderFileIOHelper]::EncodeUTF8WithBOM($Text)

            [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($result, $expected) | Should -BeTrue
        }

        It 'Should throw an EncoderFallbackException for a lone surrogate' {
            $lone = 'a' + [char] 0xD800 + 'b'

            $thrown = Get-ThrownException { [PSScriptBuilderFileIOHelper]::EncodeUTF8WithBOM($lone) }

            $thrown | Should -BeOfType ([EncoderFallbackException])
        }
    }
    #endregion EncodeUTF8WithBOM

    #region WriteAllTextUTF8WithBOM
    Context 'WriteAllTextUTF8WithBOM' {

        It 'Should write content to a new file' {
            $filePath = Join-Path $TestDrive 'write-test.txt'
            $content  = 'Written content'

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, $content)

            Test-Path $filePath | Should -BeTrue
        }

        It 'Should write content that can be read back correctly' {
            $filePath = Join-Path $TestDrive 'write-read-back.txt'
            $content  = 'round-trip content'

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, $content)
            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be $content
        }

        It 'Should overwrite existing file content' {
            $filePath = Join-Path $TestDrive 'write-overwrite.txt'
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'original')

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'overwritten')
            $result = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

            $result | Should -Be 'overwritten'
        }

        It 'Should write a BOM to the file' {
            $filePath = Join-Path $TestDrive 'write-bom.txt'

            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'bom check')
            $rawBytes = [File]::ReadAllBytes($filePath)

            # UTF-8 BOM: EF BB BF
            $rawBytes[0] | Should -Be 0xEF
            $rawBytes[1] | Should -Be 0xBB
            $rawBytes[2] | Should -Be 0xBF
        }
    }
    #endregion WriteAllTextUTF8WithBOM

    #region AppendAllTextUTF8WithBOM
    Context 'AppendAllTextUTF8WithBOM' {

        It 'Should create a new file if it does not exist' {
            $filePath = Join-Path $TestDrive 'append-new.txt'

            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'first')

            Test-Path $filePath | Should -BeTrue
        }

        It 'Should append content to an existing file' {
            $filePath = Join-Path $TestDrive 'append-existing.txt'
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'first')

            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'second')
            $result = [File]::ReadAllText($filePath, [UTF8Encoding]::new($true, $true))

            $result | Should -Be 'firstsecond'
        }

        It 'Should append multiple times' {
            $filePath = Join-Path $TestDrive 'append-multiple.txt'
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($filePath, 'A')
            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'B')
            [PSScriptBuilderFileIOHelper]::AppendAllTextUTF8WithBOM($filePath, 'C')

            $result = [File]::ReadAllText($filePath, [UTF8Encoding]::new($true, $true))

            $result | Should -Be 'ABC'
        }
    }
    #endregion AppendAllTextUTF8WithBOM

    #region FindNonAsciiFilesWithoutBom
    Context 'FindNonAsciiFilesWithoutBom' {

        It 'Should return empty array when filePaths is null' {
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom($null)
            $result | Should -BeNullOrEmpty
        }

        It 'Should return empty array when filePaths is empty' {
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@())
            $result | Should -BeNullOrEmpty
        }

        It 'Should return empty array for ASCII-only file without BOM' {
            $path = Join-Path $TestDrive 'ascii-no-bom.ps1'
            [File]::WriteAllBytes($path, [byte[]] @(0x63, 0x6C, 0x61, 0x73, 0x73))  # "class"
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@($path))
            $result | Should -BeNullOrEmpty
        }

        It 'Should return empty array for ASCII-only file with BOM' {
            $path = Join-Path $TestDrive 'ascii-with-bom.ps1'
            [File]::WriteAllBytes($path, [byte[]] @(0xEF, 0xBB, 0xBF, 0x63, 0x6C, 0x61, 0x73, 0x73))
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@($path))
            $result | Should -BeNullOrEmpty
        }

        It 'Should return empty array for non-ASCII file with BOM' {
            $path = Join-Path $TestDrive 'nonascii-with-bom.ps1'
            [File]::WriteAllBytes($path, [byte[]] @(0xEF, 0xBB, 0xBF, 0xC3, 0xA4))  # BOM + ä (UTF-8)
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@($path))
            $result | Should -BeNullOrEmpty
        }

        It 'Should return the path for non-ASCII file without BOM' {
            $path = Join-Path $TestDrive 'nonascii-no-bom.ps1'
            [File]::WriteAllBytes($path, [byte[]] @(0xC3, 0xA4))  # ä in UTF-8 without BOM
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@($path))
            $result | Should -Contain $path
        }

        It 'Should return only problematic files from a mixed list' {
            $cleanPath = Join-Path $TestDrive 'clean.ps1'
            $dirtyPath = Join-Path $TestDrive 'dirty.ps1'
            [File]::WriteAllBytes($cleanPath, [byte[]] @(0xEF, 0xBB, 0xBF, 0xC3, 0xA4))  # BOM + ä
            [File]::WriteAllBytes($dirtyPath, [byte[]] @(0xC3, 0xA4))                    # ä without BOM
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@($cleanPath, $dirtyPath))
            $result    | Should -HaveCount 1
            $result[0] | Should -Be $dirtyPath
        }

        It 'Should skip non-existent files silently' {
            $missing = Join-Path $TestDrive 'does-not-exist.ps1'
            $result  = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@($missing))
            $result | Should -BeNullOrEmpty
        }

        It 'Should skip empty files silently' {
            $path = Join-Path $TestDrive 'empty.ps1'
            [File]::WriteAllBytes($path, [byte[]] @())
            $result = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(@($path))
            $result | Should -BeNullOrEmpty
        }
    }
    #endregion FindNonAsciiFilesWithoutBom

    #region ComputeSHA256Hash
    Context 'ComputeSHA256Hash' {

        It 'Should return the same hash as Get-FileHash' {
            $filePath = Join-Path $TestDrive 'hash-content.txt'
            [File]::WriteAllText($filePath, "line1`r`nline2", [UTF8Encoding]::new($true, $true))

            $result = [PSScriptBuilderFileIOHelper]::ComputeSHA256Hash($filePath)

            $result | Should -BeExactly (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
        }

        It 'Should return the well-known hash of an empty file' {
            $filePath = Join-Path $TestDrive 'hash-empty.txt'
            [File]::WriteAllBytes($filePath, [byte[]] @())

            $result = [PSScriptBuilderFileIOHelper]::ComputeSHA256Hash($filePath)

            $result | Should -BeExactly 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
        }

        It 'Should release the file after hashing' {
            $filePath = Join-Path $TestDrive 'hash-release.txt'
            [File]::WriteAllText($filePath, 'content')

            [PSScriptBuilderFileIOHelper]::ComputeSHA256Hash($filePath) | Out-Null

            { Remove-Item -LiteralPath $filePath -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should throw FileNotFoundException when the file does not exist' {
            $filePath = Join-Path $TestDrive 'hash-missing.txt'
            $thrown   = $null

            try { [PSScriptBuilderFileIOHelper]::ComputeSHA256Hash($filePath) } catch { $thrown = $_.Exception }

            # A script caller receives .NET exceptions from a class method wrapped in a MethodInvocationException
            $thrown.GetBaseException() | Should -BeOfType ([FileNotFoundException])
        }

        It 'Should throw IOException when the file is locked' -Skip:($env:OS -ne 'Windows_NT') {
            # Exclusive file locks are only enforced on Windows
            $filePath = Join-Path $TestDrive 'hash-locked.txt'
            [File]::WriteAllText($filePath, 'content')
            $thrown   = $null

            $lockHandle = [File]::Open($filePath, [FileMode]::Open, [FileAccess]::Read, [FileShare]::None)
            try {
                try { [PSScriptBuilderFileIOHelper]::ComputeSHA256Hash($filePath) } catch { $thrown = $_.Exception }
            }
            finally {
                $lockHandle.Dispose()
            }

            $thrown.GetBaseException() | Should -BeOfType ([IOException])
        }
    }
    #endregion ComputeSHA256Hash
}
