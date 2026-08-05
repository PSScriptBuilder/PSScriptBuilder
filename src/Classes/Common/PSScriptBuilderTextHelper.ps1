#region Class PSScriptBuilderTextHelper
<#
.SYNOPSIS
    Helper class for text formatting operations.
.DESCRIPTION
    The PSScriptBuilderTextHelper class provides static methods to assist with common text formatting tasks,
    such as handling singular and plural forms of nouns based on count values.

    This helper ensures consistent text formatting across the project and eliminates code duplication
    for common text manipulation patterns.
#>
class PSScriptBuilderTextHelper {
    #region Static Methods
    <#
    .SYNOPSIS
        Returns the appropriate singular or plural form of a noun based on the count.
    .DESCRIPTION
        The GetPluralForm method evaluates the provided count and returns either the singular or plural form
        of the noun. This is useful for generating grammatically correct messages in verbose output and logs.

        The method follows standard English grammar rules: count of 1 uses singular, all other counts use plural.
    .PARAMETER count
        The numeric count that determines whether to use singular or plural form.
    .PARAMETER singular
        The singular form of the noun (e.g., "file", "item", "match").
    .PARAMETER plural
        The plural form of the noun (e.g., "files", "items", "matches").
    .OUTPUTS
        Returns either the singular or plural string based on the count value.
    .EXAMPLE
        $text = [PSScriptBuilderTextHelper]::GetPluralForm(1, "file", "files")
        # Returns: "file"
    .EXAMPLE
        $text = [PSScriptBuilderTextHelper]::GetPluralForm(5, "match", "matches")
        # Returns: "matches"
    .EXAMPLE
        $processedText = [PSScriptBuilderTextHelper]::GetPluralForm($count, "item", "items")
        Write-Verbose "$count $processedText processed successfully"
    #>
    static [string] GetPluralForm([int] $count, [string] $singular, [string] $plural) {
        if ($count -eq 1) {
            return $singular
        }
        else {
            return $plural
        }
    }

    <#
    .SYNOPSIS
        Formats a count with the appropriate singular or plural form of a noun.
    .DESCRIPTION
        The FormatCountedNoun method combines a numeric count with the grammatically correct form of a noun,
        returning a formatted string like "5 files" or "1 file".

        This method internally uses GetPluralForm to determine the correct noun form and combines it with
        the count value in a single formatted output.
    .PARAMETER count
        The numeric count to include in the formatted output.
    .PARAMETER singular
        The singular form of the noun (e.g., "file", "item", "match").
    .PARAMETER plural
        The plural form of the noun (e.g., "files", "items", "matches").
    .OUTPUTS
        Returns a formatted string containing the count and the appropriate noun form.
    .EXAMPLE
        $message = [PSScriptBuilderTextHelper]::FormatCountedNoun(1, "file", "files")
        # Returns: "1 file"
    .EXAMPLE
        $message = [PSScriptBuilderTextHelper]::FormatCountedNoun(42, "match", "matches")
        # Returns: "42 matches"
    .EXAMPLE
        $processed = [PSScriptBuilderTextHelper]::FormatCountedNoun($processedCount, "item", "items")
        $modified = [PSScriptBuilderTextHelper]::FormatCountedNoun($modifiedCount, "file", "files")
        Write-Verbose "Processing completed: $processed processed, $modified modified"
    #>
    static [string] FormatCountedNoun([int] $count, [string] $singular, [string] $plural) {
        $noun = [PSScriptBuilderTextHelper]::GetPluralForm($count, $singular, $plural)
        return "$count $noun"
    }

    <#
    .SYNOPSIS
        Converts a value to its string representation or returns an empty string if the value is null.
    .DESCRIPTION
        The GetStringOrEmpty method provides null-safe string conversion for any object type. If the provided 
        value is null, an empty string is returned. If the value is already a string, it is returned unchanged. 
        For all other types, the ToString() method is called to obtain the string representation.

        This method is particularly useful when working with optional or nullable values that need to be 
        converted to strings for output, logging, or token substitution.
    .PARAMETER value
        The value to convert to a string. Can be of any type including null.
    .OUTPUTS
        Returns a string representation of the value, or an empty string if the value is null.
    .EXAMPLE
        $result = [PSScriptBuilderTextHelper]::GetStringOrEmpty($nullableValue)
        # Returns: '' if $nullableValue is $null, otherwise the string representation
    .EXAMPLE
        $commit = [PSScriptBuilderTextHelper]::GetStringOrEmpty($git.commit)
        # Returns: '' if commit is null, or the commit hash as string
    .EXAMPLE
        $tokenMap = @{
            'GIT_COMMIT' = [PSScriptBuilderTextHelper]::GetStringOrEmpty($g.commit)
            'GIT_BRANCH' = [PSScriptBuilderTextHelper]::GetStringOrEmpty($g.branch)
        }
    #>
    static [string] GetStringOrEmpty([object] $value) {
        if ($null -eq $value) {
            return ''
        }

        if ($value -is [string]) {
            return $value
        }

        return $value.ToString()
    }

    <#
    .SYNOPSIS
        Formats a file size in bytes to a human-readable string.
    .DESCRIPTION
        The FormatFileSize method converts a file size in bytes to a human-readable format using
        appropriate units (bytes, KB, or MB). The method automatically selects the most appropriate
        unit based on the size:
        - Less than 1 KB: displays in bytes
        - Between 1 KB and 1 MB: displays in KB with 2 decimal places
        - 1 MB or greater: displays in MB with 2 decimal places

        This provides consistent file size formatting across the project for display in verbose output,
        logs, and user-facing messages.
    .PARAMETER bytes
        The file size in bytes to format.
    .OUTPUTS
        Returns a formatted string with the file size and appropriate unit (e.g., "150 bytes", "2.34 KB", "5.67 MB").
    .EXAMPLE
        $size = [PSScriptBuilderTextHelper]::FormatFileSize(1024)
        # Returns: "1.00 KB"
    .EXAMPLE
        $size = [PSScriptBuilderTextHelper]::FormatFileSize(1548576)
        # Returns: "1.48 MB"
    .EXAMPLE
        Write-Host "Output file size: $([PSScriptBuilderTextHelper]::FormatFileSize($fileInfo.Length))"
    #>
    static [string] FormatFileSize([long] $bytes) {
        if ($bytes -lt 1KB) {
            return "$bytes bytes"
        }
        elseif ($bytes -lt 1MB) {
            return "{0:N2} KB" -f ($bytes / 1KB)
        }
        else {
            return "{0:N2} MB" -f ($bytes / 1MB)
        }
    }

    <#
    .SYNOPSIS
        Formats a TimeSpan duration to a human-readable string with appropriate precision.
    .DESCRIPTION
        The FormatDuration method converts a TimeSpan object to a human-readable format by selecting
        the most appropriate unit:
        - Less than 1 second: displays in milliseconds with 2 decimal places
        - 1 second or greater: displays in seconds with 2 decimal places

        This method is particularly useful for formatting execution times, elapsed times, and other
        duration measurements in verbose output, logs, and build results.
    .PARAMETER timespan
        The TimeSpan object representing the duration to format.
    .OUTPUTS
        Returns a formatted string with the duration and appropriate unit (e.g., "123.45 ms", "5.67 s").
    .EXAMPLE
        $elapsed = Measure-Command { Start-Sleep -Milliseconds 500 }
        $formatted = [PSScriptBuilderTextHelper]::FormatDuration($elapsed)
        # Returns: "500.xx ms"
    .EXAMPLE
        $duration = [TimeSpan]::FromSeconds(2.5)
        $formatted = [PSScriptBuilderTextHelper]::FormatDuration($duration)
        # Returns: "2.50 s"
    .EXAMPLE
        Write-Host "Execution time: $([PSScriptBuilderTextHelper]::FormatDuration($buildResult.ExecutionTime))"
    #>
    static [string] FormatDuration([TimeSpan] $timespan) {
        if ($timespan.TotalMilliseconds -lt 1000) {
            return "{0:N2} ms" -f $timespan.TotalMilliseconds
        }
        else {
            return "{0:N2} s" -f $timespan.TotalSeconds
        }
    }

    <#
    .SYNOPSIS
        Formats a PSScriptBuilderCollectorType value as a human-readable label.
    .DESCRIPTION
        The FormatCollectorType method converts a PSScriptBuilderCollectorType enum value to a
        short, readable string label suitable for use in verbose output, log messages, and
        JSON serialization (e.g., build result export artifacts).
    .PARAMETER collectorType
        The PSScriptBuilderCollectorType value to format.
    .OUTPUTS
        Returns a string label for the collector type (e.g., "Enum", "Class", "Function").
    .EXAMPLE
        $label = [PSScriptBuilderTextHelper]::FormatCollectorType([PSScriptBuilderCollectorType]::ClassCollector)
        # Returns: "Class"
    #>
    static [string] FormatCollectorType([PSScriptBuilderCollectorType] $collectorType) {
        switch ($collectorType) {
            ([PSScriptBuilderCollectorType]::UsingCollector)    { return "Using"    }
            ([PSScriptBuilderCollectorType]::EnumCollector)     { return "Enum"     }
            ([PSScriptBuilderCollectorType]::ClassCollector)    { return "Class"    }
            ([PSScriptBuilderCollectorType]::FunctionCollector) { return "Function" }
            ([PSScriptBuilderCollectorType]::FileCollector)     { return "File"     }
        }

        return $collectorType.ToString()
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderTextHelper
