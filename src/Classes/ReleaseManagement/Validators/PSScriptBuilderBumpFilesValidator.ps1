using namespace System
using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderBumpFilesValidator
<#
.SYNOPSIS
    Validates bump files configuration against defined rules.
.DESCRIPTION
    The PSScriptBuilderBumpFilesValidator class provides functionality to validate bump configuration data 
    structures against a set of predefined rules. It checks for required fields, data types, file paths, 
    patterns, and token configurations.
#>
class PSScriptBuilderBumpFilesValidator {
    #region Properties
    <#
    .SYNOPSIS
        Collection of validation error messages.
    .DESCRIPTION
        The ValidationErrors property holds a list of error messages generated during the validation process.
    #>
    [List[string]] $ValidationErrors

    <#
    .SYNOPSIS
        The bump files configuration schema that defines the expected structure.
    .DESCRIPTION
        The Schema property holds a PSCustomObject that defines the expected structure of bump configuration,
        including allowed fields at each level.
    #>
    hidden [PSCustomObject] $Schema
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderBumpFilesValidator class.
    .DESCRIPTION
        The constructor initializes the ValidationErrors property as an empty list and initializes the schema.
    #>
    PSScriptBuilderBumpFilesValidator() {
        $this.ValidationErrors = [List[string]]::new()
        $this.InitializeSchema()
    }
    #endregion Constructors

    #region Methods
    #region Public Methods
    <#
    .SYNOPSIS
        Validates the bump files configuration against defined rules.
    .DESCRIPTION
        The Validate method checks the bump files configuration for structural integrity, required fields, 
        valid patterns, and token configurations.
    .PARAMETER bumpFilesConfig
        The bump files configuration to validate as a PSCustomObject.
    .OUTPUTS
        Returns $true if all validation checks pass, otherwise $false.
    #>
    [bool] Validate([PSCustomObject] $bumpFilesConfig) {
        $this.ValidationErrors.Clear()

        # Validate bumpFilesConfig is not null
        if (-not $bumpFilesConfig) {
            $this.ValidationErrors.Add("Bump files configuration is null or not initialized")
            return $false
        }

        # Step 1: Validate schema (structure)
        if (-not $this.ValidateSchema($bumpFilesConfig)) {
            # Continue with Step 2 to collect all errors
        }

        # Step 2: Validate rules (values) - existing logic
        $isValid = $true

        # Validate bumpFiles property exists
        if (-not $bumpFilesConfig.PSObject.Properties.Name -contains 'bumpFiles') {
            $this.ValidationErrors.Add("Bump files configuration does not contain a 'bumpFiles' property")
            return $false
        }

        # Validate bumpFiles is not null
        if ($null -eq $bumpFilesConfig.bumpFiles) {
            $this.ValidationErrors.Add("The 'bumpFiles' property is null")
            return $false
        }
        # Normalize single-element edge case: PSCustomObject -> Array
        if ($bumpFilesConfig.bumpFiles -is [PSCustomObject]) {
            $bumpFilesConfig.bumpFiles = @($bumpFilesConfig.bumpFiles)
        }
        # Validate bumpFiles is an array
        if ($bumpFilesConfig.bumpFiles -isnot [array]) {
            $this.ValidationErrors.Add("The 'bumpFiles' property must be an array")
            return $false
        }

        # Validate bumpFiles array is not empty
        if ($bumpFilesConfig.bumpFiles.Count -eq 0) {
            $this.ValidationErrors.Add("The 'bumpFiles' array is empty")
            return $false
        }

        # Validate each file configuration
        $fileIndex = 0

        foreach ($fileConfig in $bumpFilesConfig.bumpFiles) {
            if (-not $this.ValidateFileConfiguration($fileConfig, $fileIndex)) {
                $isValid = $false
            }

            $fileIndex++
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
        Returns a string array of validation error messages.
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
            $message = "Bump files configuration validation failed with the following errors:$([Environment]::NewLine)$allErrors"
            throw [InvalidOperationException]::new($message)
        }
    }
    #endregion Public Methods

    #region Schema Initialization and Validation
    <#
    .SYNOPSIS
        Initializes the bump files configuration schema.
    .DESCRIPTION
        The InitializeSchema method defines the expected structure of bump configuration, including
        allowed fields at the top level and within each file configuration.
    #>
    hidden [void] InitializeSchema() {
        $this.Schema = [PSCustomObject] @{
            bumpFiles = [PSCustomObject] @{
                path   = @{ required = $true;  type = "string" }
                tokens = @{ required = $false; type = "array"  }
                items  = [PSCustomObject] @{
                    pattern     = @{ required = $true;  type = "string" }
                    tokens      = @{ required = $true;  type = "array"  }
                    description = @{ required = $false; type = "string" }
                }
                description = @{ required = $false; type = "string" }
            }
        }
    }

    <#
    .SYNOPSIS
        Validates the bump files configuration structure against the schema.
    .DESCRIPTION
        The ValidateSchema method validates that the configuration contains only expected fields
        at all levels. Unknown fields are reported as errors. This method supports arbitrary nesting depth.
    .PARAMETER bumpFilesConfig
        The bump files configuration object to validate.
    .OUTPUTS
        Returns $true if the structure is valid, otherwise $false.
    #>
    hidden [bool] ValidateSchema([PSCustomObject] $bumpFilesConfig) {
        return $this.ValidateSchemaRecursive($bumpFilesConfig, $this.Schema, "")
    }

    <#
    .SYNOPSIS
        Recursively validates a bump configuration object against its schema definition.
    .DESCRIPTION
        The ValidateSchemaRecursive method checks for unknown fields at the current level and recursively
        validates nested objects and arrays. Supports arbitrary nesting depth.
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

        # Get schema properties at this level
        $schemaProperties = $schema.PSObject.Properties.Name
        
        # Get actual properties at this level
        $actualProperties = $obj.PSObject.Properties.Name

        $isValid = $true
        foreach ($objProperty in $actualProperties) {
            if ($objProperty -notin $schemaProperties) {
                # Construct display path for error message
                if ([string]::IsNullOrWhiteSpace($path)) {
                    $displayPath = $objProperty
                }
                else {
                    $displayPath = "$path.$objProperty"
                }

                $format  = "Unknown field '{0}' in bump configuration. Expected fields at this level: {1}"
                $message = [string]::Format($format, $displayPath, ($schemaProperties -join ', '))
                $this.ValidationErrors.Add($message)

                $isValid = $false
            }
        }

        # Recursively validate nested objects and arrays
        foreach ($schemaProperty in $schemaProperties) {
            $schemaValue = $schema.$schemaProperty
            $objValue    = $obj.$schemaProperty

            # If schema value is a PSCustomObject (not a hashtable), it's a nested structure to validate recursively
            if ($null -ne $schemaValue -and $schemaValue -is [PSCustomObject]) {
                if ([string]::IsNullOrWhiteSpace($path)) {
                    $displayPath = $schemaProperty
                }
                else {
                    $displayPath = "$path.$schemaProperty"
                }

                # Handle arrays
                if ($objValue -is [array]) {
                    $arrayIndex = 0

                    foreach ($arrayElement in $objValue) {
                        if ($null -ne $arrayElement -and $arrayElement -is [PSCustomObject]) {
                            $arrayDisplayPath = "$displayPath[$arrayIndex]"

                            if (-not $this.ValidateSchemaRecursive($arrayElement, $schemaValue, $arrayDisplayPath)) {
                                $isValid = $false
                            }
                        }

                        $arrayIndex++
                    }
                }
                elseif ($null -ne $objValue -and $objValue -is [PSCustomObject]) {
                    # Handle single objects
                    if (-not $this.ValidateSchemaRecursive($objValue, $schemaValue, $displayPath)) {
                        $isValid = $false
                    }
                }
            }
        }

        return $isValid
    }
    #endregion Schema Initialization and Validation

    #region Private Validation Methods
    <#
    .SYNOPSIS
        Validates a single file configuration entry.
    .DESCRIPTION
        Validates that a file configuration contains required properties (path, items) and that items 
        are properly configured with patterns and tokens.
    .PARAMETER fileConfig
        The file configuration object to validate.
    .PARAMETER fileIndex
        The index of the file in the array for error reporting.
    #>
    hidden [bool] ValidateFileConfiguration([PSCustomObject] $fileConfig, [int] $fileIndex) {
        $fileIndexPrefix = "bumpFiles[$fileIndex]"

        # Validate that fileConfig is not null
        if ($null -eq $fileConfig) {
            $this.ValidationErrors.Add("{$fileIndexPrefix}: File configuration is null")
            return $false
        }

        $isValid = $true

        # Validate required 'path' property
        if (-not $fileConfig.PSObject.Properties.Name -contains 'path') {
            $this.ValidationErrors.Add("{$fileIndexPrefix}: Missing required property 'path'")
            return $false
        }

        # Validate 'path' is not null or empty
        if ([string]::IsNullOrWhiteSpace($fileConfig.path)) {
            $this.ValidationErrors.Add("{$fileIndexPrefix}: Property 'path' cannot be null or empty")
            return $false
        }

        # Validate that EITHER 'tokens' OR 'items' exists (mutually exclusive)
        $hasTokens = $fileConfig.PSObject.Properties.Name -contains 'tokens' -and $null -ne $fileConfig.tokens -and @($fileConfig.tokens).Count -gt 0
        $hasItems  = $fileConfig.PSObject.Properties.Name -contains 'items'  -and $null -ne $fileConfig.items  -and @($fileConfig.items).Count  -gt 0

        # Check: exactly one must be present
        if ($hasTokens -and $hasItems) {
            $this.ValidationErrors.Add("{$fileIndexPrefix}: Cannot have both 'tokens' and 'items' - use one or the other")
            return $false
        }

        if (-not $hasTokens -and -not $hasItems) {
            $this.ValidationErrors.Add("{$fileIndexPrefix}: Must have either 'tokens' or 'items' property with valid content")
            return $false
        }

        # Validate 'tokens' structure if present
        if ($hasTokens) {
            # Normalize single-element edge case: PSCustomObject -> Array
            if ($fileConfig.tokens -is [PSCustomObject]) {
                $fileConfig.tokens = @($fileConfig.tokens)
            }

            # Validate all tokens are non-empty strings
            foreach ($token in $fileConfig.tokens) {
                if ([string]::IsNullOrWhiteSpace($token)) {
                    $this.ValidationErrors.Add("{$fileIndexPrefix}: Token array contains null or empty values")
                    $isValid = $false
                    break
                }
            }
        }

        # Validate 'items' structure if present
        if ($hasItems) {
            # Normalize single-element edge case: PSCustomObject -> Array
            if ($fileConfig.items -is [PSCustomObject]) {
                $fileConfig.items = @($fileConfig.items)
            }

            # Validate 'items' is an array
            if ($fileConfig.items -isnot [array]) {
                $this.ValidationErrors.Add("{$fileIndexPrefix}: Property 'items' must be an array")
                return $false
            }

            # Validate each item in the array
            $itemIndex = 0

            foreach ($item in $fileConfig.items) {
                if (-not $this.ValidateItemConfiguration($item, $fileIndex, $itemIndex)) {
                    $isValid = $false
                }

                $itemIndex++
            }
        }

        return $isValid
    }

    <#
    .SYNOPSIS
        Validates a single item configuration within a file.
    .DESCRIPTION
        Validates that an item contains required properties (pattern, tokens) and that tokens is an array.
    .PARAMETER item
        The item configuration object to validate.
    .PARAMETER fileIndex
        The index of the parent file in the array.
    .PARAMETER itemIndex
        The index of the item within the parent file's items array.
    #>
    hidden [bool] ValidateItemConfiguration([PSCustomObject] $item, [int] $fileIndex, [int] $itemIndex) {
        $itemPrefix = "bumpFiles[$fileIndex].items[$itemIndex]"

        # Validate that item is not null
        if ($null -eq $item) {
            $this.ValidationErrors.Add("{$itemPrefix}: Item configuration is null")
            return $false
        }

        $isValid = $true

        # Validate required 'pattern' property
        if (-not $item.PSObject.Properties.Name -contains 'pattern') {
            $this.ValidationErrors.Add("{$itemPrefix}: Missing required property 'pattern'")
            return $false
        }

        # Validate 'pattern' is not null or empty
        if ([string]::IsNullOrWhiteSpace($item.pattern)) {
            $this.ValidationErrors.Add("{$itemPrefix}: Property 'pattern' cannot be null or empty")
            return $false
        }

        # Validate required 'tokens' property
        if (-not $item.PSObject.Properties.Name -contains 'tokens') {
            $this.ValidationErrors.Add("{$itemPrefix}: Missing required property 'tokens'")
            return $false
        }

        # Validate 'tokens' is not null
        if ($null -eq $item.tokens) {
            $this.ValidationErrors.Add("{$itemPrefix}: Property 'tokens' is null")
            return $false
        }

        # Normalize single-element edge case: PSCustomObject -> Array
        if ($item.tokens -is [PSCustomObject]) {
            $item.tokens = @($item.tokens)
        }

        # Validate 'tokens' is an array
        if ($item.tokens -isnot [array]) {
            $this.ValidationErrors.Add("{$itemPrefix}: Property 'tokens' must be an array")
            return $false
        }

        # Validate 'tokens' array is not empty
        if ($item.tokens.Count -eq 0) {
            $this.ValidationErrors.Add("{$itemPrefix}: Property 'tokens' array is empty")
            return $false
        }

        # Validate each token is non-empty string with valid name
        $tokenIndex = 0

        foreach ($token in $item.tokens) {
            if ([string]::IsNullOrWhiteSpace($token)) {
                $this.ValidationErrors.Add("{$itemPrefix}: Token at index $tokenIndex is null or empty")

                $isValid = $false
            }
            elseif ($token -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                $message = 
                    "{$itemPrefix}: Token '$token' contains invalid characters. " + $([Environment]::NewLine) +
                    "Tokens must start with a letter or underscore and contain only alphanumeric characters and underscores"
                $this.ValidationErrors.Add($message)

                $isValid = $false
            }

            $tokenIndex++
        }

        return $isValid
    }
    #endregion Private Validation Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderBumpFilesValidator
