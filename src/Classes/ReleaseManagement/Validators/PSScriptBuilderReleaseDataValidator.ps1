using namespace System
using namespace System.Collections.Generic
using namespace System.Globalization

#region Class PSScriptBuilderReleaseDataValidator
<#
.SYNOPSIS
    Validates release data against defined rules.
.DESCRIPTION
    The PSScriptBuilderReleaseValidator class provides functionality to validate release data structures 
    against a set of predefined rules. It checks for required fields, data types, value constraints, and 
    custom validation logic.
#>
class PSScriptBuilderReleaseDataValidator {
    #region Properties
    <#
    .SYNOPSIS
        Collection of validation error messages.
    .DESCRIPTION
        The ValidationErrors property holds a list of error messages generated during the validation process.
    #>
    hidden [List[string]] $ValidationErrors

    <#
    .SYNOPSIS
        The release data schema that defines the expected structure.
    .DESCRIPTION
        The Schema property holds a PSCustomObject that defines the expected structure of release data,
        including which fields are required and their expected types at each level.
    #>
    hidden [PSCustomObject] $Schema
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderReleaseDataValidator class.
    .DESCRIPTION
        The constructor initializes the ValidationErrors property as an empty list and initializes the schema.
    #>
    PSScriptBuilderReleaseDataValidator() {
        $this.ValidationErrors = [List[string]]::new()
        $this.InitializeSchema()
    }
    #endregion Constructors

    #region Methods
    #region Public Methods
    <#
    .SYNOPSIS
        Validates the release data against defined rules.
    .DESCRIPTION
        The Validate method iterates through a set of predefined validation rules and checks the release data 
        against each rule. It records any validation errors encountered during the process.
    .PARAMETER releaseData
        The release data to validate as a PSCustomObject.
    .OUTPUTS
        Returns $true if all validation checks pass, otherwise $false.
    #>
    [bool] Validate([PSCustomObject] $releaseData) {
        $this.ValidationErrors.Clear()

        if (-not $releaseData) {
            $this.ValidationErrors.Add('Release data is null or not initialized')
            return $false
        }

        # Step 1: Validate schema (structure)
        if (-not $this.ValidateSchema($releaseData)) {
            # Continue with Step 2 to collect all errors
        }

        # Step 2: Validate rules (values)
        $rules = $this.GetValidationRules()
        $isValid = $true

        foreach ($rule in $rules) {
            if (-not $this.ValidateRule($releaseData, $rule)) {
                $isValid = $false
                # Continue validating other rules to collect all errors
            }
        }

        # Return false if either validation step failed
        return ($this.ValidationErrors.Count -eq 0) -and $isValid
    }

    <#
    .SYNOPSIS
        Gets the list of validation errors.
    .DESCRIPTION
        The GetErrors method returns an array of error messages recorded during the validation process.
    .OUTPUTS
        Returns a List[string] of validation error messages.
    #>
    [string[]] GetErrors() {
        return $this.ValidationErrors.ToArray()
    }

    <#
    .SYNOPSIS
        Throws an exception if there are any validation errors.
    .DESCRIPTION
        The ThrowIfInvalid method checks if there are any validation errors recorded. If so, it constructs a 
        detailed error message and throws an exception containing all validation errors.
    #>
    [void] ThrowIfInvalid() {
        if ($this.ValidationErrors.Count -gt 0) {
            $allErrors = $this.ValidationErrors -join [Environment]::NewLine
            $message = "Release data validation failed with the following errors:$([Environment]::NewLine)$allErrors"
            throw [InvalidOperationException]::new($message)
        }
    }
    #endregion Public Methods

    #region Schema Initialization and Validation
    <#
    .SYNOPSIS
        Initializes the release data schema.
    .DESCRIPTION
        The InitializeSchema method defines the expected structure of the release data, including
        the allowed fields at the top level and within each section (version, build, git).
    #>
    hidden [void] InitializeSchema() {
        $this.Schema = [PSCustomObject] @{
            version = [PSCustomObject] @{
                major         = @{ required = $true;  type = "int"    }
                minor         = @{ required = $true;  type = "int"    }
                patch         = @{ required = $true;  type = "int"    }
                prerelease    = @{ required = $false; type = "string" }
                buildmetadata = @{ required = $false; type = "string" }
                full          = @{ required = $false; type = "string" }
            }
            build = [PSCustomObject] @{
                number        = @{ required = $false; type = "int"    }
                date          = @{ required = $false; type = "string" }
                time          = @{ required = $false; type = "string" }
                timestamp     = @{ required = $false; type = "string" }
                year          = @{ required = $false; type = "int"    }
                month         = @{ required = $false; type = "int"    }
                day           = @{ required = $false; type = "int"    }
                hour          = @{ required = $false; type = "int"    }
                minute        = @{ required = $false; type = "int"    }
                second        = @{ required = $false; type = "int"    }
            }
            git = [PSCustomObject] @{
                commit        = @{ required = $false; type = "string" }
                commitShort   = @{ required = $false; type = "string" }
                branch        = @{ required = $false; type = "string" }
                tag           = @{ required = $false; type = "string" }
            }
        }
    }

    <#
    .SYNOPSIS
        Validates the release data structure against the schema.
    .DESCRIPTION
        The ValidateSchema method recursively validates that the release data contains only expected fields
        at all levels. Unknown fields are reported as errors. This method supports arbitrary nesting depth.
    .PARAMETER releaseData
        The release data object to validate.
    .OUTPUTS
        Returns $true if the structure is valid, otherwise $false.
    #>
    hidden [bool] ValidateSchema([PSCustomObject] $releaseData) {
        return $this.ValidateSchemaRecursive($releaseData, $this.Schema, "")
    }

    <#
    .SYNOPSIS
        Recursively validates a release data object against its schema definition.
    .DESCRIPTION
        The ValidateSchemaRecursive method checks for unknown fields at the current level and recursively
        validates nested objects. Supports arbitrary nesting depth.
    .PARAMETER obj
        The object to validate.
    .PARAMETER schema
        The schema definition for this level.
    .PARAMETER path
        The current path in the object hierarchy (for error messages).
    .OUTPUTS
        Returns $true if all levels are valid, otherwise $false.
    #>
    hidden [bool] ValidateSchemaRecursive([PSCustomObject] $obj, [PSCustomObject] $schema, [string] $path) {
        if ($null -eq $obj) {
            return $true
        }

        $isValid = $true
        $schemaProperties = $schema.PSObject.Properties.Name

        # Check for unknown fields in the current object
        $actualProperties = $obj.PSObject.Properties.Name

        foreach ($objProperty in $actualProperties) {
            if ($objProperty -notin $schemaProperties) {
                if (-not [string]::IsNullOrWhiteSpace($path)) {
                    $displayPath = "$path.$objProperty"
                }
                else {
                    $displayPath = $objProperty
                }

                $this.ValidationErrors.Add("Unknown field '$displayPath' in release data. Expected fields at this level: $($schemaProperties -join ', ')")
                $isValid = $false
            }
        }

        # Recursively validate nested objects
        foreach ($schemaProperty in $schemaProperties) {
            $schemaValue = $schema.$schemaProperty
            $objValue    = $obj.$schemaProperty

            # If schema value is a PSCustomObject (not a hashtable), it's a nested object to validate recursively
            if ($null -ne $schemaValue -and $schemaValue -is [PSCustomObject]) {
                if (-not [string]::IsNullOrWhiteSpace($path)) {
                    $displayPath = "$path.$schemaProperty"
                }
                else {
                    $displayPath = $schemaProperty
                }
               
                if ($null -ne $objValue) {
                    if (-not $this.ValidateSchemaRecursive($objValue, $schemaValue, $displayPath)) {
                        $isValid = $false
                    }
                }
            }
        }

        return $isValid
    }
    #endregion Schema Initialization and Validation

    #region Validation Implementation
    <#
    .SYNOPSIS
        Validates the release data against a single rule.
    .DESCRIPTION
        The ValidateRule method checks the release data against a specific validation rule, including required 
        fields, data types, value constraints, and custom validation logic.
    .PARAMETER releaseData
        The release data to validate as a PSCustomObject.
    .PARAMETER rule
        A hashtable defining the validation rule.
    .OUTPUTS
        Returns $true if the release data passes the validation rule, otherwise $false.
    #>
    [bool] ValidateRule([PSCustomObject] $releaseData, [hashtable] $rule) {
        $path   = $rule.Path
        $exists = $this.PathExists($releaseData, $path)

        if (-not $this.ValidateRequired($rule, $exists)) {
            return $false
        }

        if (-not $exists) {
            return $true
        }

        $value = $this.GetValueByPath($releaseData, $path)

        if (-not $this.ValidateType($rule, $value, $path)) {
            return $false
        }

        if (-not $this.ValidateConstraints($rule, $value, $path)) {
            return $false
        }

        if (-not $this.ValidateCustom($rule, $value, $path)) {
            return $false
        }

        return $true
    }

    <#
    .SYNOPSIS
        Validates if a required field exists.
    .DESCRIPTION
        The ValidateRequired method checks if a required field is present in the release data. If the field is 
        required but missing, it records an error message.
    .PARAMETER rule
        A hashtable defining the validation rule.
    .PARAMETER exists
        A boolean indicating whether the field exists in the release data.
    #>
    [bool] ValidateRequired([hashtable] $rule, [bool] $exists) {
        if ($rule.Required -and -not $exists) {
            $this.ValidationErrors.Add($rule.ErrorMessage)
            return $false
        }

        return $true
    }

    <#
    .SYNOPSIS
        Validates the data type of a field.
    .DESCRIPTION
        The ValidateType method checks if the value of a field matches the expected data type defined in the 
        validation rule. If there is a type mismatch, it records an error message.
    .PARAMETER rule
        A hashtable defining the validation rule, including the expected type.
    .PARAMETER value
        The value of the field to validate.
    .PARAMETER path
        The dot-separated path of the field being validated as a string (used for error messages).
    .OUTPUTS
        Returns $true if the value matches the expected type, otherwise $false.
    #>
    [bool] ValidateType([hashtable] $rule, [object] $value, [string] $path) {
        if ($null -eq $value) {
            return $true
        }

        if (-not $rule.ContainsKey('Type')) {
            return $true
        }

        switch ($rule.Type) {
            'int' {
                if ($value -isnot [int] -and $value -isnot [long]) {
                    $this.AddTypeError($path, 'Integer', $value)
                    return $false
                }
            }
            'string' {
                if ($value -isnot [string]) {
                    $this.AddTypeError($path, 'String', $value)
                    return $false
                }
            }
            'PSCustomObject' {
                if ($value -isnot [PSCustomObject]) {
                    $this.ValidationErrors.Add("'$path' is expected to be an object")
                    return $false
                }
            }
            default {
                $this.ValidationErrors.Add("Unknown type '$($rule.Type)' specified in validation rule for path '$path'")
                return $false
            }
        }

        return $true
    }

    <#
    .SYNOPSIS
        Validates value constraints of a field.
    .DESCRIPTION
        The ValidateConstraints method checks if the value of a field adheres to constraints defined in the 
        validation rule, such as minimum/maximum values, patterns, and length restrictions. If any constraint is 
        violated, it records an error message.
    .PARAMETER rule
        A hashtable defining the validation rule.
    .PARAMETER value
        The value of the field to validate.
    .PARAMETER path
        The dot-separated path of the field being validated as a string.
    #>
    [bool] ValidateConstraints([hashtable] $rule, [object] $value, [string] $path) {
        if ($null -eq $value) {
            return $true
        }

        if ($rule.ContainsKey('MinValue') -and $value -lt $rule.MinValue) {
            $this.ValidationErrors.Add("Value at path '$path' is less than the minimum allowed value of $($rule.MinValue)")
            return $false
        }

        if ($rule.ContainsKey('MaxValue') -and $value -gt $rule.MaxValue) {
            $this.ValidationErrors.Add("Value at path '$path' is greater than the maximum allowed value of $($rule.MaxValue)")
            return $false
        }

        if ($rule.ContainsKey('Pattern') -and -not [string]::IsNullOrEmpty($value) -and -not ($value -match $rule.Pattern)) {
            $this.ValidationErrors.Add("Value at path '$path' does not match the required pattern '$($rule.Pattern)'")
            return $false
        }

        if ($rule.ContainsKey('MinLength') -and $value.Length -lt $rule.MinLength) {
            $this.ValidationErrors.Add("Value at path '$path' is shorter than the minimum allowed length of $($rule.MinLength)")
            return $false
        }

        if ($rule.ContainsKey('MaxLength') -and $value.Length -gt $rule.MaxLength) {
            $this.ValidationErrors.Add("Value at path '$path' is longer than the maximum allowed length of $($rule.MaxLength)")
            return $false
        }

        return $true
    }

    <#
    .SYNOPSIS
        Validates a field using custom logic.
    .DESCRIPTION
        The ValidateCustom method executes a custom validation function defined in the validation rule. If the 
        custom validation fails or throws an exception, it records an error message.
    .PARAMETER rule
        A hashtable defining the validation rule.
    .PARAMETER value
        The value of the field to validate.
    .PARAMETER path
        The dot-separated path of the field being validated as a string.
    #>
    [bool] ValidateCustom([hashtable] $rule, [object] $value, [string] $path) {
        if (-not $value) {
            return $true
        }

        if (-not $rule.ContainsKey('CustomValidator')) {
            return $true
        }

        try {
            $result = & $rule.CustomValidator $value

            if ($result -isnot [bool]) {
                $this.ValidationErrors.Add("Custom validator for path '$path' did not return a boolean value")
                return $false
            }
            elseif (-not $result) {
                $this.ValidationErrors.Add($rule.ErrorMessage)
                return $false
            }
        }
        catch {
            $this.ValidationErrors.Add("Custom validator for path '$path' threw an exception: $($_.Exception.Message)")
            return $false
        }

        return $true
    }

    <#
    .SYNOPSIS
        Checks if a field exists at the specified path.
    .DESCRIPTION
        The PathExists method traverses the version data structure to determine if a field exists at the given 
        dot-separated path.
    .PARAMETER releaseData
        The version data as a PSCustomObject.
    .PARAMETER path
        The dot-separated path to check as a string.
    .OUTPUTS
        Returns $true if the field exists, otherwise $false.
    #>
    [bool] PathExists([PSCustomObject] $releaseData, [string] $path) {
        $segments = $path -split '\.'
        $current  = $releaseData

        foreach ($segment in $segments) {
            if (-not $current.PSObject.Properties[$segment]) {
                return $false
            }

            $current = $current.$segment
        }

        return $true
    }

    <#
    .SYNOPSIS
        Retrieves the value at the specified path.
    .DESCRIPTION
        The GetValueByPath method traverses the version data structure to retrieve the value located at the given 
        dot-separated path.
    .PARAMETER releaseData
        The version data as a PSCustomObject.
    .PARAMETER path
        The dot-separated path to retrieve the value from as a string.
    .OUTPUTS
        Returns the value located at the specified path, or $null if the path does not exist.
    #>
    [object] GetValueByPath([PSCustomObject] $releaseData, [string] $path) {
        $segments = $path -split '\.'
        $current  = $releaseData

        foreach ($segment in $segments) {
            if ($current.PSObject.Properties[$segment]) {
                $current = $current.$segment
            }
            else {
                return $null
            }
        }

        return $current
    }

    <#
    .SYNOPSIS
        Records a type error in the validation errors.
    .DESCRIPTION
        The AddTypeError method constructs a detailed type error message and adds it to the ValidationErrors 
        collection.
    .PARAMETER path
        The dot-separated path where the type error occurred as a string.
    .PARAMETER expectedType
        The expected data type as a string.
    .PARAMETER value
        The actual value that caused the type error.
    #>
    [void] AddTypeError([string] $path, [string] $expectedType, [object] $value) {
        $actualType  = if ($null  -eq $value  ) { 'null' } else { $value.GetType().Name }
        $valueString = if ($value -is [string]) { $value } else { $value.ToString()     }

        $format  = "Type error at '{0}': Expected type '{1}', but got type '{2}' with value '{3}'"
        $message = $format -f $path, $expectedType, $actualType, $valueString

        $this.ValidationErrors.Add($message)
    }

    <#
    .SYNOPSIS
        Gets the predefined validation rules for version data.
    .DESCRIPTION
        The GetValidationRules method returns an array of hashtables, each defining a validation rule for the 
        version data structure.
    .OUTPUTS
        Returns an array of hashtables representing validation rules.
    #>
    [hashtable[]] GetValidationRules() {
        return @(
            @{
                Path         = 'version'
                Required     = $true
                Type         = 'PSCustomObject'
                ErrorMessage = 'The required "version" section is missing or invalid'
            }
            @{
                Path         = 'version.major'
                Required     = $true
                Type         = 'int'
                MinValue     = 0
                ErrorMessage = 'The required "major" field in the version section is missing or invalid'
            }
            @{
                Path         = 'version.minor'
                Required     = $true
                Type         = 'int'
                MinValue     = 0
                ErrorMessage = 'The required "minor" field in the version section is missing or invalid'
            }
            @{
                Path         = 'version.patch'
                Required     = $true
                Type         = 'int'
                MinValue     = 0
                ErrorMessage = 'The required "patch" field in the version section is missing or invalid'
            }
            @{
                Path         = 'version.prerelease'
                Required     = $false
                Type         = 'string'
                Pattern      = '^[0-9A-Za-z\-\.]+$'
                ErrorMessage = 'The optional "prerelease" field in the version section is invalid. It must contain alphanumeric characters, hyphens, and dots.'
            }
            @{
                Path         = 'version.buildmetadata'
                Required     = $false
                Type         = 'string'
                Pattern      = '^[0-9A-Za-z\-\.]+$'
                ErrorMessage = 'The optional "buildmetadata" field in the version section is invalid. It must contain alphanumeric characters, hyphens, and dots.'
            }
            @{
                Path         = 'version.full'
                Required     = $false
                Type         = 'string'
                Pattern      = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z\-\.]+)?(\+[0-9A-Za-z\-\.]+)?$'
                ErrorMessage = 'The optional "full" field in the version section is invalid. It must follow semantic versioning format.'
            }
            @{
                Path         = 'build'
                Required     = $false
                Type         = 'PSCustomObject'
                ErrorMessage = 'The optional "build" section is invalid'
            }
            @{
                Path         = 'build.number'
                Required     = $false
                Type         = 'int'
                MinValue     = 0
                ErrorMessage = 'The optional "number" field in the build section is invalid'
            }
            @{
                Path         = 'build.date'
                Required     = $false
                Type         = 'string'
                Pattern      = '^\d{4}-\d{2}-\d{2}$'
                ErrorMessage = 'The optional "date" field in the build section is invalid. It must be in yyyy-MM-dd format.'
            }
            @{
                Path         = 'build.time'
                Required     = $false
                Type         = 'string'
                Pattern      = '^\d{2}:\d{2}:\d{2}$'
                ErrorMessage = 'The optional "time" field in the build section is invalid. It must be in HH:mm:ss format.'
            }
            @{
                Path         = 'build.timestamp'
                Required     = $false
                Type         = 'string'
                ErrorMessage = 'The optional "timestamp" field in the build section is invalid. It must be in ISO 8601 format.'
                CustomValidator = {
                    param($value)
                    try {
                        $format   = 'yyyy-MM-ddTHH:mm:ssZ'
                        $provider = [CultureInfo]::InvariantCulture
                        [DateTime]::ParseExact($value, $format, $provider) | Out-Null
                        return $true
                    }
                    catch { return $false }
                }
            }
            @{
                Path         = 'build.year'
                Required     = $false
                Type         = 'int'
                MinValue     = 2000
                MaxValue     = 2100
                ErrorMessage = 'The optional "year" field in the build section is invalid'
            }
            @{
                Path         = 'build.month'
                Required     = $false
                Type         = 'int'
                MinValue     = 1
                MaxValue     = 12
                ErrorMessage = 'The optional "month" field in the build section is invalid. It must be between 1 and 12.'
            }
            @{
                Path         = 'build.day'
                Required     = $false
                Type         = 'int'
                MinValue     = 1
                MaxValue     = 31
                ErrorMessage = 'The optional "day" field in the build section is invalid. It must be between 1 and 31.'
            }
            @{
                Path         = 'build.hour'
                Required     = $false
                Type         = 'int'
                MinValue     = 0
                MaxValue     = 23
                ErrorMessage = 'The optional "hour" field in the build section is invalid. It must be between 0 and 23.'
            }
            @{
                Path         = 'build.minute'
                Required     = $false
                Type         = 'int'
                MinValue     = 0
                MaxValue     = 59
                ErrorMessage = 'The optional "minute" field in the build section is invalid. It must be between 0 and 59.'
            }
            @{
                Path         = 'build.second'
                Required     = $false
                Type         = 'int'
                MinValue     = 0
                MaxValue     = 59
                ErrorMessage = 'The optional "second" field in the build section is invalid. It must be between 0 and 59.'
            }
            @{
                Path         = 'git'
                Required     = $false
                Type         = 'PSCustomObject'
                ErrorMessage = 'The optional "git" section is invalid'
            }
            @{
                Path         = 'git.commit'
                Required     = $false
                Type         = 'string'
                Pattern      = '^[0-9a-fA-F]{40}$'
                ErrorMessage = 'The optional "commit" field in the git section is invalid. It must be a valid 40-character SHA-1 hash.'
            }
            @{
                Path         = 'git.commitShort'
                Required     = $false
                Type         = 'string'
                Pattern      = '^[0-9a-fA-F]{7}$'
                ErrorMessage = 'The optional "commitShort" field in the git section is invalid. It must be a valid 7-character short SHA-1 hash.'
            }
            @{
                Path         = 'git.branch'
                Required     = $false
                Type         = 'string'
                MinLength    = 1
                MaxLength    = 100
                ErrorMessage = 'The optional "branch" field in the git section is invalid. It must be between 1 and 100 characters.'
            }
            @{
                Path         = 'git.tag'
                Required     = $false
                Type         = 'string'
                MinLength    = 1
                MaxLength    = 100
                ErrorMessage = 'The optional "tag" field in the git section is invalid. It must be between 1 and 100 characters.'
            }
        )
    }
    #endregion Validation Implementation
    #endregion Methods
}
#endregion Class PSScriptBuilderReleaseDataValidator
