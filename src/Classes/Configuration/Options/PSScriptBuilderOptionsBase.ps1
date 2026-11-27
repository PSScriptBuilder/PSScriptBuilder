using namespace System

#region Class PSScriptBuilderOptionsBase
<#
.SYNOPSIS
    Base class for script builder configuration options.
.DESCRIPTION
    The PSScriptBuilderOptionsBase class provides a foundation for configuration option classes used in the 
    PSScriptBuilder. Configuration validation is handled centrally by PSScriptBuilderConfigValidator before
    option classes are instantiated, keeping option classes focused on data management.
#>
class PSScriptBuilderOptionsBase {
    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderOptionsBase class.
    .DESCRIPTION
        The constructor for the PSScriptBuilderOptionsBase class initializes the option object by calling 
        SetOptions and ValidateOptions. 
        Configuration-level validation is performed by PSScriptBuilderConfigValidator before option objects 
        are created.
    .PARAMETER config
        A PSCustomObject containing the configuration data.
    #>
    PSScriptBuilderOptionsBase([PSCustomObject] $config) {
        $this.ValidateInstance()
        $this.SetOptions($config)
        $this.ValidateOptions()
    }
    #endregion Constructors

    #region Methods
    #region Validation Methods
    <#
    .SYNOPSIS
        Validates that the current instance is not the abstract base class.
    .DESCRIPTION
        The ValidateInstance method checks if the current instance is of the PSScriptBuilderOptionsBase class.
        If it is, an exception is thrown since this class is intended to be abstract and should not be 
        instantiated directly.
    #>
    hidden [void] ValidateInstance() {
        if ($this.GetType().Name -eq "PSScriptBuilderOptionsBase") {
            $message = "PSScriptBuilderOptionsBase is an abstract class and cannot be instantiated directly"
            throw [InvalidOperationException]::new($message)
        }
    }
    #endregion Validation Methods

    #region Private Helper Methods
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

    #region Abstract Methods
    <#
    .SYNOPSIS
        Sets options based on the provided configuration.
    .DESCRIPTION
        The SetOptions method iterates through the properties of the provided configuration object and sets 
        the corresponding properties in the derived class instance.
    .PARAMETER config
        A PSCustomObject containing the configuration data.
    .NOTES
        This method is intended to be overridden in derived classes to implement specific option setting logic.
    #>
    [void] SetOptions([PSCustomObject] $config) {
        throw [NotImplementedException]::new("SetOptions method must be implemented in derived classes")
    }

    <#
    .SYNOPSIS
        Validates the configuration options.
    .DESCRIPTION
        The ValidateOptions method checks if the options set in the derived class instance are valid.
        This includes option-specific validation (e.g., conditional requirements, value range checks).
    .NOTES
        This method is intended to be overridden in derived classes to implement specific validation logic.
    #>
    [void] ValidateOptions() {
        throw [NotImplementedException]::new("ValidateOptions method must be implemented in derived classes")
    }
    #endregion Abstract Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderOptionsBase
