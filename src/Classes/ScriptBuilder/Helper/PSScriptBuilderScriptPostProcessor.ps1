using namespace System
using namespace System.Collections.Generic
using namespace System.Management.Automation.Language

#region Class PSScriptBuilderScriptPostProcessor
<#
.SYNOPSIS
    Static utility class for post-processing built PowerShell scripts.
.DESCRIPTION
    The PSScriptBuilderScriptPostProcessor class provides static methods for transforming
    a PowerShell script string after it has been built. Each method performs a single,
    independent transformation and returns the modified script string.

    Supported transformations:
    - RemoveComments:          removes all comment tokens; #Requires statements are preserved
    - RemoveBlankLines:        removes all blank lines
    - RemoveOutputStatements:  removes isolated calls to specified output cmdlets (e.g. Write-Verbose)

    Transformations are safe by design: only constructs that can be unambiguously identified
    and removed without corrupting the script are processed. Non-isolated output statement
    calls (e.g. inside pipelines or control flow expressions) are skipped silently.

    This class is the backing implementation for Compress-PSScriptBuilderScript.
#>
class PSScriptBuilderScriptPostProcessor {
    #region Methods
    <#
    .SYNOPSIS
        Removes all comments from a PowerShell script string.
    .DESCRIPTION
        The RemoveComments() method parses the script using the PowerShell tokenizer and removes
        all tokens of type Comment. This includes single-line comments, block comments,
        and region markers (#region / #endregion).

        #Requires statements are preserved because they are required by the PowerShell runtime
        and must remain at the top of the script.

        Tokens are removed in reverse order to preserve correct character offsets during removal.
    .PARAMETER script
        The PowerShell script string to process.
    .OUTPUTS
        Returns the script string with all comments removed.
    #>
    static [string] RemoveComments([string] $script) {
        $count = 0
        return [PSScriptBuilderScriptPostProcessor]::RemoveComments($script, [ref] $count)
    }

    <#
    .SYNOPSIS
        Removes all comments from a PowerShell script string and reports the number removed.
    .DESCRIPTION
        Behaves identically to RemoveComments([string]), but also sets the removedCount reference
        to the number of comment tokens removed.
    .PARAMETER script
        The PowerShell script string to process.
    .PARAMETER removedCount
        A reference variable that will be set to the number of comment tokens removed.
    .OUTPUTS
        Returns the script string with all comments removed.
    #>
    static [string] RemoveComments([string] $script, [ref] $removedCount) {
        $removedCount.Value = 0

        if ([string]::IsNullOrEmpty($script)) {
            return $script
        }

        $tokens      = $null
        $parseErrors = $null

        [Parser]::ParseInput($script, [ref] $tokens, [ref] $parseErrors) | Out-Null

        if ($parseErrors.Length -gt 0) {
            $format  = "Failed to tokenize script: {0} parse error(s). First error: {1}"
            $message = $format -f $parseErrors.Length, $parseErrors[0].Message
            throw [InvalidOperationException]::new($message)
        }

        $commentTokens = [List[Token]]::new()

        foreach ($token in $tokens) {
            if ($token.Kind -ne [TokenKind]::Comment) {
                continue
            }

            if ($token.Text -match '^#Requires') {
                continue
            }

            $commentTokens.Add($token)
        }

        # Remove in reverse order to preserve offsets
        $commentTokens.Sort({ param($a, $b) $b.Extent.StartOffset - $a.Extent.StartOffset })

        $result = $script

        foreach ($token in $commentTokens) {
            $start  = $token.Extent.StartOffset
            $length = $token.Extent.EndOffset - $token.Extent.StartOffset
            $result = $result.Remove($start, $length)
        }

        $removedCount.Value = $commentTokens.Count
        return $result
    }

    <#
    .SYNOPSIS
        Removes all blank lines from a PowerShell script string.
    .DESCRIPTION
        The RemoveBlankLines() method splits the script into lines and filters out all lines
        that contain only whitespace. The remaining lines are joined with the system line separator.
    .PARAMETER script
        The PowerShell script string to process.
    .OUTPUTS
        Returns the script string with all blank lines removed.
    #>
    static [string] RemoveBlankLines([string] $script) {
        $count = 0
        return [PSScriptBuilderScriptPostProcessor]::RemoveBlankLines($script, [ref] $count)
    }

    <#
    .SYNOPSIS
        Removes all blank lines from a PowerShell script string and reports the number removed.
    .DESCRIPTION
        Behaves identically to RemoveBlankLines([string]), but also sets the removedCount reference
        to the number of blank lines removed.
    .PARAMETER script
        The PowerShell script string to process.
    .PARAMETER removedCount
        A reference variable that will be set to the number of blank lines removed.
    .OUTPUTS
        Returns the script string with all blank lines removed.
    #>
    static [string] RemoveBlankLines([string] $script, [ref] $removedCount) {
        $removedCount.Value = 0

        if ([string]::IsNullOrEmpty($script)) {
            return $script
        }

        $lines         = $script -split '\r?\n'
        $nonBlankLines = [List[string]]::new()

        foreach ($line in $lines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $nonBlankLines.Add($line)
            }
        }

        $removedCount.Value = $lines.Count - $nonBlankLines.Count
        return $nonBlankLines -join [Environment]::NewLine
    }

    <#
    .SYNOPSIS
        Removes isolated calls to the specified output cmdlets from a PowerShell script string.
    .DESCRIPTION
        The RemoveOutputStatements() method parses the script using the PowerShell AST and removes
        all isolated calls to the specified cmdlets (e.g. Write-Verbose, Write-Debug).

        A call is considered isolated when:
        - The CommandAst is the sole element in its PipelineAst (no pipeline before the call)
        - The PipelineAst's parent is a ScriptBlockAst or NamedBlockAst (not inside if/foreach/etc.)

        Non-isolated calls are silently skipped and reported via Write-Verbose. The entire line
        including its line ending is removed to avoid leaving behind blank lines.

        Tokens are removed in reverse order to preserve correct character offsets during removal.
    .PARAMETER script
        The PowerShell script string to process.
    .PARAMETER cmdletNames
        An array of cmdlet names to remove. Comparison is case-insensitive.
    .OUTPUTS
        Returns the script string with all matching isolated output statements removed.
    #>
    static [string] RemoveOutputStatements([string] $script, [string[]] $cmdletNames) {
        $count = 0
        return [PSScriptBuilderScriptPostProcessor]::RemoveOutputStatements($script, $cmdletNames, [ref] $count)
    }

    <#
    .SYNOPSIS
        Removes isolated calls to the specified output cmdlets from a PowerShell script string and reports the number removed.
    .DESCRIPTION
        Behaves identically to RemoveOutputStatements([string], [string[]]), but also sets the
        removedCount reference to the number of output statement lines removed.
    .PARAMETER script
        The PowerShell script string to process.
    .PARAMETER cmdletNames
        An array of cmdlet names to remove. Comparison is case-insensitive.
    .PARAMETER removedCount
        A reference variable that will be set to the number of output statement lines removed.
    .OUTPUTS
        Returns the script string with all matching isolated output statements removed.
    #>
    static [string] RemoveOutputStatements([string] $script, [string[]] $cmdletNames, [ref] $removedCount) {
        $removedCount.Value = 0

        if ([string]::IsNullOrEmpty($script)) {
            return $script
        }

        if ($null -eq $cmdletNames -or $cmdletNames.Length -eq 0) {
            return $script
        }

        $tokens      = $null
        $parseErrors = $null
        $ast         = [Parser]::ParseInput($script, [ref] $tokens, [ref] $parseErrors)

        if ($parseErrors.Length -gt 0) {
            $format  = "Failed to parse script: {0} parse error(s). First error: {1}"
            $message = $format -f $parseErrors.Length, $parseErrors[0].Message
            throw [InvalidOperationException]::new($message)
        }

        $cmdletSet = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($name in $cmdletNames) {
            [void] $cmdletSet.Add($name)
        }

        $commandAsts = $ast.FindAll({
            param($node)
            $node -is [CommandAst]
        }, $true)

        $commandAstParent  = $null
        $pipelineAstParent = $null
        $linesToRemove     = [HashSet[int]]::new()

        foreach ($commandAst in $commandAsts) {
            $commandName = $commandAst.GetCommandName()

            if (-not $cmdletSet.Contains($commandName)) {
                continue
            }

            # Check: CommandAst must be the sole element in its PipelineAst
            $commandAstParent = $commandAst.Parent

            if ($commandAstParent -isnot [PipelineAst] -or $commandAstParent.PipelineElements.Count -ne 1) {
                Write-Verbose "Skipped non-isolated '$commandName' call at line $($commandAst.Extent.StartLineNumber): statement is part of a pipeline."
                continue
            }

            # Check: PipelineAst parent must be ScriptBlockAst or NamedBlockAst
            $pipelineAstParent = $commandAstParent.Parent

            if ($pipelineAstParent -isnot [ScriptBlockAst] -and $pipelineAstParent -isnot [NamedBlockAst]) {
                Write-Verbose "Skipped non-isolated '$commandName' call at line $($commandAst.Extent.StartLineNumber): statement is part of a larger expression."
                continue
            }

            [void] $linesToRemove.Add($commandAst.Extent.StartLineNumber)
        }

        $removedCount.Value = $linesToRemove.Count

        if ($linesToRemove.Count -eq 0) {
            return $script
        }

        $lines  = $script -split '\r?\n'
        $result = [List[string]]::new()

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if (-not $linesToRemove.Contains($i + 1)) {
                $result.Add($lines[$i])
            }
        }

        return $result -join [Environment]::NewLine
    }

    #endregion Methods
}
#endregion Class PSScriptBuilderScriptPostProcessor
