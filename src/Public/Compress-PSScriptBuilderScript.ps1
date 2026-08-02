using namespace System.IO

#region Cmdlet Compress-PSScriptBuilderScript
function Compress-PSScriptBuilderScript {
    <#
    .SYNOPSIS
        Post-processes a built PowerShell script by removing comments, blank lines, or output statements.
    .DESCRIPTION
        The Compress-PSScriptBuilderScript cmdlet transforms a PowerShell script file by applying one
        or more post-processing operations. Each operation is independent and can be combined freely.

        Supported operations:
        - RemoveComments:          removes all comment tokens; #Requires statements are preserved
        - RemoveBlankLines:        removes all blank lines
        - RemoveOutputStatements:  removes isolated calls to specified output cmdlets

        The cmdlet accepts pipeline input from Invoke-PSScriptBuilderBuild via the OutputPath property,
        enabling direct chaining of build and post-processing in a single pipeline.

        When -DestinationPath is specified, the result is written to that file. Otherwise, the processed
        script string is returned to the pipeline.
    .PARAMETER Path
        The path to the PowerShell script file to process. Accepts pipeline input by property name
        via the OutputPath property, enabling direct piping from Invoke-PSScriptBuilderBuild.
    .PARAMETER RemoveComments
        When specified, removes all comments from the script including single-line comments,
        block comments, and region markers (#region / #endregion).
        #Requires statements are preserved.
    .PARAMETER RemoveBlankLines
        When specified, removes all blank lines from the script.
    .PARAMETER RemoveOutputStatements
        When specified, removes isolated calls to the specified output cmdlets. Valid values are:
        Write-Verbose, Write-Debug, Write-Host, Write-Warning, Write-Information.

        A call is considered isolated when it stands alone on its line and is not part of a pipeline
        or a control flow expression (if, foreach, etc.). Non-isolated calls are skipped silently
        and reported via Write-Verbose.
    .PARAMETER DestinationPath
        The file path to write the processed script to. If omitted, the processed script string
        is returned to the pipeline instead.
    .PARAMETER Force
        When specified, overwrites an existing output file without prompting.
        When omitted and the target file already exists, the cmdlet throws an IOException.
    .OUTPUTS
        System.String
    .EXAMPLE
        Compress-PSScriptBuilderScript -Path '.\build\Output\MyScript.ps1' -RemoveComments -RemoveBlankLines -DestinationPath '.\deploy\MyScript.ps1' -Force

        Removes all comments and blank lines from the built script and writes the result to a
        deploy folder, overwriting any existing file.
    .EXAMPLE
        Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath '.\template.ps1' -OutputPath '.\output\MyScript.ps1' |
            Compress-PSScriptBuilderScript -RemoveComments -RemoveBlankLines -DestinationPath '.\deploy\MyScript.ps1' -Force

        Chains build and post-processing in a single pipeline. The OutputPath from the build result
        is passed automatically to the -Path parameter via its OutputPath alias.
    .EXAMPLE
        Compress-PSScriptBuilderScript -Path '.\output\MyScript.ps1' -RemoveOutputStatements 'Write-Verbose', 'Write-Debug' -DestinationPath '.\deploy\MyScript.ps1' -Force

        Removes all isolated Write-Verbose and Write-Debug calls from the script before deployment.
    .EXAMPLE
        $compressed = Compress-PSScriptBuilderScript -Path '.\output\MyScript.ps1' -RemoveComments

        Returns the processed script as a string without writing to a file.
        Useful for inspecting the result or piping into further processing.
    .NOTES
        Operations are applied in the following order regardless of parameter order:
        1. RemoveComments
        2. RemoveOutputStatements
        3. RemoveBlankLines

        This order ensures that removing comments or output statements does not leave behind
        unexpected blank lines that RemoveBlankLines then cleans up.

        When -DestinationPath is specified and the file already exists, the cmdlet throws an
        IOException unless -Force is present.

        Non-isolated output statement calls are silently skipped. Use -Verbose to see which
        calls were skipped and why.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('OutputPath')]
        [string] $Path,

        [Parameter()]
        [switch] $RemoveComments,

        [Parameter()]
        [switch] $RemoveBlankLines,

        [Parameter()]
        [ValidateSet('Write-Verbose', 'Write-Debug', 'Write-Host', 'Write-Warning', 'Write-Information')]
        [string[]] $RemoveOutputStatements,

        [Parameter()]
        [string] $DestinationPath,

        [Parameter()]
        [switch] $Force
    )

    process {
        try {
            $resolvedInputPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($Path)

            if (-not [File]::Exists($resolvedInputPath)) {
                $format  = "Input file not found: '{0}'."
                $message = $format -f $resolvedInputPath
                throw [FileNotFoundException]::new($message, $resolvedInputPath)
            }

            $resolvedOutputPath = $null

            if (-not [string]::IsNullOrWhiteSpace($DestinationPath)) {
                $resolvedOutputPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($DestinationPath)
            }

            if ($null -ne $resolvedOutputPath -and [File]::Exists($resolvedOutputPath) -and -not $Force.IsPresent) {
                $format  = "Output file already exists: '{0}'. Use -Force to overwrite."
                $message = $format -f $resolvedOutputPath
                throw [IOException]::new($message)
            }

            $inputSize = [System.IO.FileInfo]::new($resolvedInputPath).Length
            $script = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($resolvedInputPath)

            Write-Verbose "Compressing: $resolvedInputPath"

            if ($RemoveComments.IsPresent) {
                $removedCount = 0
                $script = [PSScriptBuilderScriptPostProcessor]::RemoveComments($script, [ref] $removedCount)
                Write-Verbose "  Removed $removedCount comment(s)"
            }

            if ($null -ne $RemoveOutputStatements -and $RemoveOutputStatements.Length -gt 0) {
                $removedCount = 0
                $script = [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, $RemoveOutputStatements, [ref] $removedCount)
                Write-Verbose "  Removed $removedCount output statement(s): $($RemoveOutputStatements -join ', ')"
            }

            if ($RemoveBlankLines.IsPresent) {
                $removedCount = 0
                $script = [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script, [ref] $removedCount)
                Write-Verbose "  Removed $removedCount blank line(s)"
            }

            Write-Verbose "Compression complete."

            if ($null -ne $resolvedOutputPath) {
                [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($resolvedOutputPath, $script)
                Write-Verbose "Result written to: $resolvedOutputPath"

                $outputSize   = [FileInfo]::new($resolvedOutputPath).Length
                $savedBytes   = $inputSize - $outputSize
                $savedPercent = [Math]::Round(($savedBytes / $inputSize) * 100, 1)

                $inputLabel  = if ($inputSize  -ge 1MB) { '{0:F2} MB' -f ($inputSize  / 1MB) } elseif ($inputSize  -ge 1KB) { '{0:F1} KB' -f ($inputSize  / 1KB) } else { "$inputSize B"  }
                $outputLabel = if ($outputSize -ge 1MB) { '{0:F2} MB' -f ($outputSize / 1MB) } elseif ($outputSize -ge 1KB) { '{0:F1} KB' -f ($outputSize / 1KB) } else { "$outputSize B" }
                $savedLabel  = if ($savedBytes -ge 1MB) { '{0:F2} MB' -f ($savedBytes / 1MB) } elseif ($savedBytes -ge 1KB) { '{0:F1} KB' -f ($savedBytes / 1KB) } else { "$savedBytes B" }

                Write-Verbose "  Size: $inputLabel -> $outputLabel (saved $savedLabel, $savedPercent%)"
            }
            else {
                return $script
            }
        }
        catch {
            $format  = "Failed to compress script '{0}'. Error: {1}"
            $message = $format -f $Path, $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Compress-PSScriptBuilderScript
