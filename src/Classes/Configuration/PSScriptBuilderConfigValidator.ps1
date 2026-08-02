using namespace System

#region Class PSScriptBuilderConfigValidator
<#
.SYNOPSIS
    Validates the PSScriptBuilder configuration structure.
.DESCRIPTION
    The PSScriptBuilderConfigValidator class provides centralized validation of the entire configuration 
    structure, including unknown options, required fields, and nested configurations. This ensures that 
    the configuration is valid before option classes are instantiated.
#>
class PSScriptBuilderConfigValidator {
    #region Private Properties
    <#
    .SYNOPSIS
        The configuration schema that defines the expected structure.
    .DESCRIPTION
        The Schema property holds a PSCustomObject that defines the expected configuration structure,
        including which fields are required and their types.
    #>
    hidden [PSCustomObject] $Schema
    #endregion Private Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderConfigValidator class.
    .DESCRIPTION
        The constructor initializes the configuration schema.
    #>
    PSScriptBuilderConfigValidator() {
        $this.InitializeSchema()
    }
    #endregion Constructors

    #region Methods
    #region Validation Methods
    <#
    .SYNOPSIS
        Validates the entire configuration.
    .DESCRIPTION
        The Validate method performs a recursive validation of the provided configuration against
        the defined schema, checking for unknown options and required fields.
    .PARAMETER config
        The PSCustomObject containing the configuration to validate.
    #>
    [void] Validate([PSCustomObject] $config) {
        if ($null -eq $config) {
            throw [ArgumentNullException]::new('config', 'Configuration object cannot be null.')
        }

        $this.ValidateRecursive($config, $this.Schema, "")
    }
    #endregion Validation Methods

    #region Private Helper Methods
    <#
    .SYNOPSIS
        Initializes the configuration schema.
    .DESCRIPTION
        The InitializeSchema method defines the expected structure of the PSScriptBuilder configuration,
        including all required fields and nested objects.
    #>
    hidden [void] InitializeSchema() {
        $this.Schema = [PSCustomObject] @{
            # Define release part of the configuration schema
            release = [PSCustomObject] @{
                dataFile       = @{ required = $true; type = "string" }
                bumpConfigFile = @{ required = $true; type = "string" }
            }

            # Define build part of the configuration schema
            build = [PSCustomObject] @{
                outputPath              = @{ required = $true; type = "string"  }
                backupPath              = @{ required = $true; type = "string"  }
                templatePath            = @{ required = $true; type = "string"  }
                orderedComponentsKey    = @{ required = $true; type = "string"  }
                backupEnabled           = @{ required = $true; type = "boolean" }
                syntaxValidationEnabled = @{ required = $true; type = "boolean" }
            }
        }
    }

    <#
    .SYNOPSIS
        Recursively validates configuration objects against the schema.
    .DESCRIPTION
        The ValidateRecursive method performs recursive validation of the configuration structure,
        checking for unknown options and verifying that all required fields are present.
    .PARAMETER obj
        The current PSCustomObject to validate.
    .PARAMETER schema
        The schema PSCustomObject that defines the expected structure.
    .PARAMETER path
        The current path in the configuration hierarchy.
    #>
    hidden [void] ValidateRecursive([PSCustomObject] $obj, [PSCustomObject] $schema, [string] $path) {
        if ($null -eq $obj) {
            throw [ArgumentNullException]::new('obj', 'Configuration object cannot be null.')
        }

        if ($null -eq $schema) {
            throw [ArgumentNullException]::new('schema', 'Schema object cannot be null.')
        }

        # Validate all properties in the object against the schema
        $objectProperties = $obj.PSObject.Properties

        foreach ($property in $objectProperties) {
            $propertyName = $property.Name.ToLower()
            $schemaValue  = $this.GetPropertyValue($schema, $propertyName)

            if ($null -eq $schemaValue) {
                $message = "Unknown configuration option: '$($this.BuildPath($path, $property.Name))'"
                throw [InvalidOperationException]::new($message)
            }

            # Recursive validation for nested objects
            if ($schemaValue -is [PSCustomObject] -and $property.Value -is [PSCustomObject]) {
                $this.ValidateRecursive($property.Value, $schemaValue, $this.BuildPath($path, $property.Name))
            }
        }

        # Validate that all required fields from the schema are present in the object
        $schemaProperties = $schema.PSObject.Properties

        foreach ($schemaProperty in $schemaProperties) {
            $schemaItem = $schemaProperty.Value

            # If this is a required field (Hashtable with required = $true)
            if ($schemaItem -is [Hashtable] -and $schemaItem["required"] -eq $true) {
                $configValue = $this.GetPropertyValue($obj, $schemaProperty.Name)

                if ($null -eq $configValue) {
                    $message = "Required configuration option missing: '$($this.BuildPath($path, $schemaProperty.Name))'"
                    throw [InvalidOperationException]::new($message)
                }

                # Validate type if specified in schema
                $expectedType = $schemaItem["type"]

                if (-not [string]::IsNullOrWhiteSpace($expectedType)) {
                    $fullPath = $this.BuildPath($path, $schemaProperty.Name)

                    $isTypeMismatch = switch ($expectedType) {
                        "boolean" { $configValue -isnot [bool]   }
                        "string"  { $configValue -isnot [string] }
                        default   { $false }
                    }

                    if ($isTypeMismatch) {
                        $format  = "Configuration option '{0}' must be of type '{1}'."
                        $message = $format -f $fullPath, $expectedType
                        throw [InvalidOperationException]::new($message)
                    }
                }
            }
            # If this is a required nested section (PSCustomObject in schema)
            elseif ($schemaItem -is [PSCustomObject]) {
                $configValue = $this.GetPropertyValue($obj, $schemaProperty.Name)

                if ($null -eq $configValue) {
                    $message = "Required configuration section missing: '$($this.BuildPath($path, $schemaProperty.Name))'"
                    throw [InvalidOperationException]::new($message)
                }
            }
        }
    }

    <#
    .SYNOPSIS
        Builds a dot-separated configuration path from a parent path and a property name.
    .DESCRIPTION
        The BuildPath method combines a parent path and a property name into a dot-separated
        path string. If the parent path is empty or whitespace, the property name is returned
        as-is. Used to construct human-readable paths for validation error messages.
    .PARAMETER path
        The current parent path. May be empty or whitespace for top-level properties.
    .PARAMETER name
        The property name to append to the path.
    .OUTPUTS
        Returns the combined path string.
    #>
    hidden [string] BuildPath([string] $path, [string] $name) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            return $name
        }

        return "$path.$name"
    }

    <#
    .SYNOPSIS
        Retrieves a property value from a PSCustomObject with case-insensitive lookup.
    .DESCRIPTION
        The GetPropertyValue method performs a case-insensitive lookup of a property in a PSCustomObject
        and returns its value, or $null if the property is not found.
    .PARAMETER obj
        The PSCustomObject to search.
    .PARAMETER propertyName
        The name of the property to retrieve (case-insensitive).
    .OUTPUTS
        Returns the property value or $null if not found.
    #>
    hidden [object] GetPropertyValue([PSCustomObject] $obj, [string] $propertyName) {
        if ($null -eq $obj) {
            return $null
        }

        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            return $null
        }

        $objectProperties = $obj.PSObject.Properties

        foreach ($property in $objectProperties) {
            if ($property.Name.ToLower() -eq $propertyName.ToLower()) {
                return $property.Value
            }
        }

        return $null
    }
    #endregion Private Helper Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderConfigValidator
