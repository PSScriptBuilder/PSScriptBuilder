using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.IO

#region Class PSScriptBuilderSourceMapSerializer
<#
.SYNOPSIS
    Converts source map data to and from the JSON format of a sidecar file.
.DESCRIPTION
    The PSScriptBuilderSourceMapSerializer provides static methods that convert a
    PSScriptBuilderSourceMapData instance into the JSON text of a .sourcemap.json sidecar and back.
    It owns the sidecar format: the format version, the schema every field is validated against,
    and the mapping between stored component entries and PSScriptBuilderSourceLocation. Reading
    and writing the file itself is done by PSScriptBuilderSourceMapFileManager.
#>
class PSScriptBuilderSourceMapSerializer {
    #region Static Fields
    <#
    .SYNOPSIS
        The source map format version written by, and the highest version readable by, this module version.
    .DESCRIPTION
        Written to every sidecar as FormatVersion. Incremented only for changes that an older reader
        would misinterpret (e.g. a changed meaning of an existing field) - not for additive fields
        such as ComponentLineCount, which older readers safely ignore. Sidecars without the field
        were written before it existed and are read as version 1.
    #>
    hidden static [int] $SourceMapFormatVersion = 1

    <#
    .SYNOPSIS
        The maximum length of the parser message included in a "could not be parsed" error.
    .DESCRIPTION
        Windows PowerShell 5.1 appends the complete JSON text to its parser messages, which would
        put an entire sidecar into the error message. The cause is stated at the beginning in both
        PowerShell versions; the complete parser exception stays available as InnerException.
    #>
    hidden static [int] $MaxParseErrorDetailLength = 200

    <#
    .SYNOPSIS
        The schema of the FormatVersion field, read before any other field.
    .DESCRIPTION
        Kept separate from SidecarSchema because the format version decides whether SidecarSchema
        applies at all: an unsupported version must be reported as such, not as a schema
        violation of fields a newer format may define differently. Sidecars without the field
        were written before it existed and are read as version 1.
    #>
    hidden static [OrderedDictionary] $VersionSchema = [ordered] @{
        FormatVersion = @{ Required = $false; Type = 'WholeNumber'; Minimum = 1; Default = 1 }
    }

    <#
    .SYNOPSIS
        The schema of the top-level sidecar fields in format version 1.
    .DESCRIPTION
        Declarative rules applied by ReadFields(). Each rule has Required and Type, plus Minimum for
        WholeNumber and Default for optional fields. Types: String (a non-empty string),
        Sha256Hash (64 hexadecimal characters), WholeNumber (a JSON whole number of at least
        Minimum, in any notation) and Array. Fields not listed are ignored (Tolerant Reader), so a
        newer module version can add fields without breaking older readers.
    #>
    hidden static [OrderedDictionary] $SidecarSchema = [ordered] @{
        OutputPath      = @{ Required = $true;  Type = 'String' }
        OutputHash      = @{ Required = $true;  Type = 'Sha256Hash' }
        OutputLineCount = @{ Required = $true;  Type = 'WholeNumber'; Minimum = 0 }
        Components      = @{ Required = $true;  Type = 'Array' }
    }

    <#
    .SYNOPSIS
        The schema of one entry of the sidecar's Components array in format version 1.
    .DESCRIPTION
        Rules as in SidecarSchema. ComponentType is deliberately a free string, not a fixed list:
        the known values (Enum, Class, Function, File) are not exhaustive, and a newer module
        version may add a collector type. ComponentLineCount is optional: an absent field means
        unknown (sidecars written before it existed), read as 0; a present value is a real line
        count of at least 1.
    #>
    hidden static [OrderedDictionary] $ComponentSchema = [ordered] @{
        ComponentName       = @{ Required = $true;  Type = 'String' }
        ComponentType       = @{ Required = $true;  Type = 'String' }
        SourceFile          = @{ Required = $true;  Type = 'String' }
        OutputLineNumber    = @{ Required = $true;  Type = 'WholeNumber'; Minimum = 1 }
        ComponentLineNumber = @{ Required = $true;  Type = 'WholeNumber'; Minimum = 1 }
        SourceLineNumber    = @{ Required = $true;  Type = 'WholeNumber'; Minimum = 1 }
        Offset              = @{ Required = $true;  Type = 'WholeNumber'; Minimum = 0 }
        ComponentLineCount  = @{ Required = $false; Type = 'WholeNumber'; Minimum = 1; Default = 0 }
    }
    #endregion Static Fields

    #region Static Methods
    <#
    .SYNOPSIS
        Converts source map data into the JSON text of a sidecar file.
    .DESCRIPTION
        The Serialize method wraps the source map data in a PSCustomObject with PascalCase keys,
        writing FormatVersion first, and serializes it as JSON. A component's ComponentLineCount
        of 0 (unknown) is written as an absent field, which is how the format expresses "unknown"
        (see ComponentSchema).
    .PARAMETER sourceMapData
        The source map data to serialize.
    .OUTPUTS
        Returns the JSON text of the sidecar as string.
    #>
    static [string] Serialize([PSScriptBuilderSourceMapData] $sourceMapData) {
        if ($null -eq $sourceMapData) {
            $message = "Parameter 'sourceMapData' cannot be null."
            throw [ArgumentException]::new($message, "sourceMapData")
        }

        $components = [List[PSCustomObject]]::new()
        foreach ($entry in $sourceMapData.Components) {
            $fields = [ordered] @{
                ComponentName       = $entry.ComponentName
                ComponentType       = $entry.ComponentType
                OutputLineNumber    = $entry.OutputLineNumber
                Offset              = $entry.Offset
                SourceFile          = $entry.SourceFile
                ComponentLineNumber = $entry.ComponentLineNumber
                SourceLineNumber    = $entry.SourceLineNumber
            }

            if ($entry.ComponentLineCount -gt 0) {
                $fields.ComponentLineCount = $entry.ComponentLineCount
            }

            $components.Add([PSCustomObject] $fields)
        }

        $data = [PSCustomObject] @{
            FormatVersion   = [PSScriptBuilderSourceMapSerializer]::SourceMapFormatVersion
            OutputPath      = $sourceMapData.OutputPath
            OutputHash      = $sourceMapData.OutputHash
            OutputLineCount = $sourceMapData.OutputLineCount
            Components      = $components.ToArray()
        }

        $json = $data | ConvertTo-Json -Depth 5
        return $json
    }

    <#
    .SYNOPSIS
        Converts the JSON text of a sidecar file into source map data.
    .DESCRIPTION
        The Deserialize method parses the JSON text, validates it against VersionSchema,
        SidecarSchema and ComponentSchema, and returns a PSScriptBuilderSourceMapData instance
        containing the output path, SHA-256 hash, total line count, and the reconstructed source
        location entries.
        Throws InvalidDataException if the text is empty, cannot be parsed as JSON, is not a JSON
        object, has an unsupported format version, or lacks a required field or has an invalid
        value for one. Empty includes $null, which a [string] parameter receives as an empty
        string, and whitespace; it is checked before parsing, so a text containing only the JSON
        literal null is reported as not being a JSON object. ConvertFrom-Json throws
        ArgumentException for malformed JSON and InvalidOperationException for valid JSON it cannot
        represent (e.g. keys differing only in letter case); only these two are caught, and only
        around the parsing itself. Of duplicate keys, ConvertFrom-Json keeps the last value, as
        common JSON parsers do; the module never writes duplicate keys.
    .PARAMETER json
        The JSON text of the sidecar file.
    .PARAMETER sidecarPath
        The path to the sidecar file, used in error messages.
    .OUTPUTS
        Returns the deserialized sidecar content as PSScriptBuilderSourceMapData.
    #>
    static [PSScriptBuilderSourceMapData] Deserialize([string] $json, [string] $sidecarPath) {
        if ([string]::IsNullOrWhiteSpace($json)) {
            $format  = "Source map {0} is empty. Rebuild the output script with -WriteSourceMap to recreate the source map."
            $message = $format -f $sidecarPath
            throw [InvalidDataException]::new($message)
        }

        $data = $null
        try {
            $data = $json | ConvertFrom-Json
        }
        catch [ArgumentException], [InvalidOperationException] {
            $maxDetailLength = [PSScriptBuilderSourceMapSerializer]::MaxParseErrorDetailLength
            $detail          = $_.Exception.Message
            if ($detail.Length -gt $maxDetailLength) {
                $detail = $detail.Substring(0, $maxDetailLength) + '...'
            }

            $format  = "Source map {0} could not be parsed as JSON ({1}). Rebuild the output script with -WriteSourceMap to recreate the source map."
            $message = $format -f $sidecarPath, $detail
            throw [InvalidDataException]::new($message, $_.Exception)
        }

        # The full type name is required: [PSCustomObject] is an accelerator for PSObject and
        # matches any value, e.g. a plain number; it also rejects a text containing only null
        if ($data -isnot [System.Management.Automation.PSCustomObject]) {
            $format  = "Source map {0} does not contain a JSON object. Rebuild the output script with -WriteSourceMap to recreate the source map."
            $message = $format -f $sidecarPath
            throw [InvalidDataException]::new($message)
        }

        $versionFields = [PSScriptBuilderSourceMapSerializer]::ReadFields($data, [PSScriptBuilderSourceMapSerializer]::VersionSchema, '', $sidecarPath)
        $formatVersion = $versionFields.FormatVersion
        [PSScriptBuilderSourceMapSerializer]::ThrowIfUnsupportedFormatVersion($formatVersion, $sidecarPath)

        $fields           = [PSScriptBuilderSourceMapSerializer]::ReadFields($data, [PSScriptBuilderSourceMapSerializer]::SidecarSchema, '', $sidecarPath)
        $componentEntries = $fields.Components

        $components = [List[PSScriptBuilderSourceLocation]]::new()
        for ($index = 0; $index -lt $componentEntries.Count; $index++) {
            $components.Add([PSScriptBuilderSourceMapSerializer]::ConvertToSourceLocation($componentEntries[$index], $index, $sidecarPath))
        }

        $sourceMapData = [PSScriptBuilderSourceMapData]::new(
            $fields.OutputPath,
            $fields.OutputHash,
            $fields.OutputLineCount,
            $components.ToArray()
        )
        return $sourceMapData
    }

    <#
    .SYNOPSIS
        Reads all fields of deserialized sidecar data defined in a schema and validates them.
    .DESCRIPTION
        The ReadFields method runs once over the schema's rules and returns the converted value of
        every field, or the rule's Default if an optional field is absent. Properties are looked up
        via PSObject.Properties, because a bare access to a missing property throws when the caller
        runs under StrictMode.

        Values are validated, not converted between types: String and Sha256Hash require an
        actual string, Array a JSON array (its entries are validated by the caller), and
        WholeNumber a JSON whole number of at least Minimum that fits into an int. Whole numbers
        are checked by value, not by notation: JSON has a single number type, so 1, 1.0 and 1e0
        are the same number (as in JSON Schema's "integer"); ConvertFrom-Json yields Int32 or
        Int64 for 1, and Double or Decimal for 1.0, depending on the PowerShell version. Booleans
        and strings are never accepted as numbers, although PowerShell would convert them (true to
        1, "2" to 2). A missing required field or an invalid value throws InvalidDataException
        naming the field path and showing the value in JSON notation.

        All checks run inline in this one loop rather than in a method per field: a PowerShell
        class method call costs about 10 microseconds, and about 20 with a [ref] parameter, which
        made a chain of per-field methods the dominant cost of reading a large sidecar.
    .PARAMETER container
        The deserialized object that holds the fields (the sidecar or one component entry).
    .PARAMETER schema
        The schema that defines the fields (VersionSchema, SidecarSchema or ComponentSchema).
    .PARAMETER pathPrefix
        The path of the container used in error messages, e.g. "Components[3]." or "" for the top
        level.
    .PARAMETER sidecarPath
        The path to the sidecar file, used in error messages.
    .OUTPUTS
        Returns a hashtable with one entry per schema field: int for WholeNumber, string for String
        and Sha256Hash, the array for Array.
    #>
    hidden static [hashtable] ReadFields([object] $container, [OrderedDictionary] $schema, [string] $pathPrefix, [string] $sidecarPath) {
        $fields     = @{}
        $properties = $container.PSObject.Properties

        foreach ($fieldName in $schema.Keys) {
            $rule     = $schema[$fieldName]
            $property = $properties[$fieldName]

            if ($null -eq $property) {
                if ($rule.Required) {
                    $format  = "Source map {0} is missing the required field '{1}'. Rebuild the output script with -WriteSourceMap to recreate the source map."
                    $message = $format -f $sidecarPath, ($pathPrefix + $fieldName)
                    throw [InvalidDataException]::new($message)
                }

                $fields[$fieldName] = $rule.Default
                continue
            }

            $value   = $property.Value
            $isValid = $false
            switch ($rule.Type) {
                'String' {
                    $isValid = ($value -is [string]) -and -not [string]::IsNullOrWhiteSpace($value)
                }
                'Sha256Hash' {
                    $isValid = ($value -is [string]) -and ($value -match '^[0-9A-Fa-f]{64}$')
                }
                'Array' {
                    $isValid = ($value -is [array])
                }
                'WholeNumber' {
                    $isNumber = ($value -is [int]) -or ($value -is [long]) -or ($value -is [double]) -or ($value -is [decimal])
                    $isValid  = $isNumber -and ([Math]::Truncate($value) -eq $value) -and
                                ($value -ge $rule.Minimum) -and ($value -le [int]::MaxValue)
                }
                default {
                    $format  = "Unknown source map schema type '{0}'."
                    $message = $format -f $rule.Type
                    throw [ArgumentException]::new($message, "schema")
                }
            }

            if (-not $isValid) {
                $displayValue = [PSScriptBuilderSourceMapSerializer]::FormatJsonValue($value)
                $expectation  = [PSScriptBuilderSourceMapSerializer]::DescribeRule($rule)
                $format       = "Source map {0} has an invalid value for '{1}' ({2}); expected {3}. " +
                                "Rebuild the output script with -WriteSourceMap to recreate the source map."
                $message      = $format -f $sidecarPath, ($pathPrefix + $fieldName), $displayValue, $expectation
                throw [InvalidDataException]::new($message)
            }

            $fields[$fieldName] = $value
            if ($rule.Type -eq 'WholeNumber') {
                $fields[$fieldName] = [int] $value
            }
        }

        return $fields
    }

    <#
    .SYNOPSIS
        Describes what a schema rule expects, for use in error messages.
    .PARAMETER rule
        The schema rule.
    .OUTPUTS
        Returns the description, e.g. "a whole number of at least 1", as string.
    #>
    hidden static [string] DescribeRule([hashtable] $rule) {
        $description = switch ($rule.Type) {
            'String'      { 'a non-empty string' }
            'Sha256Hash'  { 'a SHA-256 hash of 64 hexadecimal characters' }
            'WholeNumber' { 'a whole number of at least {0}' -f $rule.Minimum }
            'Array'       { 'an array' }
            default       { "a value of type '{0}'" -f $rule.Type }
        }
        return $description
    }

    <#
    .SYNOPSIS
        Renders a deserialized value in JSON notation, for use in error messages.
    .DESCRIPTION
        ConvertTo-Json renders $null as an empty string in PS 5.1, hence the explicit default.
    .PARAMETER value
        The value as returned by ConvertFrom-Json.
    .OUTPUTS
        Returns the value in compact JSON notation, e.g. true, "2", null or [1], as string.
    #>
    hidden static [string] FormatJsonValue([object] $value) {
        $jsonValue = 'null'
        if ($null -ne $value) {
            $jsonValue = ConvertTo-Json -InputObject $value -Compress -Depth 3 -WarningAction SilentlyContinue
        }
        return $jsonValue
    }

    <#
    .SYNOPSIS
        Throws if a sidecar uses a format version newer than this module version supports.
    .DESCRIPTION
        The ThrowIfUnsupportedFormatVersion method compares the format version with
        SourceMapFormatVersion and throws InvalidDataException with both versions and how to
        recover if it is newer. Named after the .NET ThrowIf pattern (e.g.
        ArgumentOutOfRangeException.ThrowIfGreaterThan).
    .PARAMETER formatVersion
        The validated format version read from the sidecar.
    .PARAMETER sidecarPath
        The path to the sidecar file, used in the error message.
    #>
    hidden static [void] ThrowIfUnsupportedFormatVersion([int] $formatVersion, [string] $sidecarPath) {
        $supportedVersion = [PSScriptBuilderSourceMapSerializer]::SourceMapFormatVersion
        if ($formatVersion -le $supportedVersion) {
            return
        }

        $format  = "Source map {0} uses format version {1}, but this version of PSScriptBuilder supports up to format version {2}. " +
                   "Update PSScriptBuilder, or rebuild the output script with -WriteSourceMap to recreate the source map."
        $message = $format -f $sidecarPath, $formatVersion, $supportedVersion
        throw [InvalidDataException]::new($message)
    }

    <#
    .SYNOPSIS
        Converts one deserialized sidecar component entry into a PSScriptBuilderSourceLocation.
    .DESCRIPTION
        The ConvertToSourceLocation method validates a stored component entry against
        ComponentSchema and translates it into the current data model. An entry that is not a JSON
        object, lacks a required field or has an invalid value throws InvalidDataException naming
        the entry, e.g. "Components[3].OutputLineNumber".
    .PARAMETER component
        One element of the sidecar's Components array, as returned by ConvertFrom-Json.
    .PARAMETER index
        The position of the entry in the Components array, used in error messages.
    .PARAMETER sidecarPath
        The path to the sidecar file, used in error messages.
    .OUTPUTS
        Returns the source location as PSScriptBuilderSourceLocation.
    #>
    hidden static [PSScriptBuilderSourceLocation] ConvertToSourceLocation([object] $component, [int] $index, [string] $sidecarPath) {
        $entryPath = "Components[$index]"

        # The full type name is required: [PSCustomObject] is an accelerator for PSObject and
        # matches any value, e.g. a plain number
        if ($component -isnot [System.Management.Automation.PSCustomObject]) {
            $displayValue = [PSScriptBuilderSourceMapSerializer]::FormatJsonValue($component)
            $format       = "Source map {0} has an invalid value for '{1}' ({2}); expected an object. " +
                            "Rebuild the output script with -WriteSourceMap to recreate the source map."
            $message      = $format -f $sidecarPath, $entryPath, $displayValue
            throw [InvalidDataException]::new($message)
        }

        $fields = [PSScriptBuilderSourceMapSerializer]::ReadFields($component, [PSScriptBuilderSourceMapSerializer]::ComponentSchema, "$entryPath.", $sidecarPath)

        $location = [PSScriptBuilderSourceLocation]::new(
            $fields.ComponentName,
            $fields.ComponentType,
            $fields.SourceFile,
            $fields.SourceLineNumber,
            $fields.ComponentLineNumber,
            $fields.OutputLineNumber,
            $fields.Offset,
            $fields.ComponentLineCount
        )
        return $location
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderSourceMapSerializer
