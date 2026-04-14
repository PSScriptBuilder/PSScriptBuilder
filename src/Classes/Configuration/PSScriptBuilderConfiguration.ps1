using namespace System.Collections.Specialized
using namespace System.IO

#region Class PSScriptBuilderConfiguration
<#
.SYNOPSIS
    Configuration for the PSScriptBuilder.
.DESCRIPTION
    The PSScriptBuilderConfiguration class provides properties to configure the behavior of the PSScriptBuilder.
#>
class PSScriptBuilderConfiguration {
    #region Static Properties
    <#
    .SYNOPSIS
        Cached instance of the PSScriptBuilderConfiguration (Lazy-loaded Singleton).
    .DESCRIPTION
        The Current static property holds the cached configuration instance. It is loaded on first access 
        and reused throughout the application lifecycle.
    #>
    static [PSScriptBuilderConfiguration] $Current = $null

    <#
    .SYNOPSIS
        Flag indicating whether the configuration has been loaded.
    .DESCRIPTION
        The IsLoaded static property tracks whether Load() has already been called to avoid unnecessary reloads.
    #>
    static [bool] $IsLoaded = $false
    #endregion Static Properties

    #region Properties
    <#
    .SYNOPSIS
        Configuration file name for the PSScriptBuilder.
    .DESCRIPTION
        The ConfigFileName property holds the file name of the configuration file used by the PSScriptBuilder. 
    #>
    [string] $ConfigFileName = "psscriptbuilder.config.json"

    <#
    .SYNOPSIS
        Release options for the PSScriptBuilder.
    .DESCRIPTION
        The Release property is an instance of the PSScriptBuilderReleaseOptions class, which contains various 
        settings related to release management, such as version numbers and release metadata.
    #>
    [PSScriptBuilderReleaseOptions] $Release

    <#
    .SYNOPSIS
        Build options for the PSScriptBuilder.
    .DESCRIPTION
        The Build property is an instance of the PSScriptBuilderBuildOptions class, which contains various 
        settings related to the build process, such as output paths and flags for creating missing directories.
    #>
    [PSScriptBuilderBuildOptions] $Build
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderConfiguration class.
    .DESCRIPTION
        The default constructor initializes the PSScriptBuilderConfiguration instance and loads the configuration 
        from the default configuration file path.
    #>
    PSScriptBuilderConfiguration() {
        $this.Initialize()
    }

    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderConfiguration class with a specified configuration file.
    .DESCRIPTION
        This constructor initializes the PSScriptBuilderConfiguration instance and loads the configuration from 
        the specified configuration file path.
    .PARAMETER configFile
        The path to the configuration file to load as a string.
    #>
    PSScriptBuilderConfiguration([string] $ConfigFileName) {
        $this.ConfigFileName = $ConfigFileName
        $this.Initialize()
    }
    #endregion Constructors

    #region Methods
    #region Static Methods (Configuration Lifecycle)
    <#
    .SYNOPSIS
        Loads the configuration (Lazy Load Pattern).
    .DESCRIPTION
        The Load() static method initializes and caches the configuration on first call. Subsequent calls 
        return the cached instance. Uses Lazy Loading - configuration is only loaded when first accessed.
    .OUTPUTS
        Returns the cached instance of PSScriptBuilderConfiguration.
    #>
    static [PSScriptBuilderConfiguration] Load() {
        if (-not [PSScriptBuilderConfiguration]::IsLoaded) {
            [PSScriptBuilderConfiguration]::Current = [PSScriptBuilderConfiguration]::new()
            [PSScriptBuilderConfiguration]::IsLoaded = $true
        }
        
        return [PSScriptBuilderConfiguration]::Current
    }

    <#
    .SYNOPSIS
        Sets the configuration instance (for testing or overrides).
    .DESCRIPTION
        The Set() static method allows replacing the cached configuration instance. Useful for testing 
        or when you need to use an alternate configuration. Automatically marks configuration as loaded.
    .PARAMETER configuration
        The PSScriptBuilderConfiguration instance to cache.
    .EXAMPLE
        $customConfig = [PSScriptBuilderConfiguration]::new("custom.config.json")
        [PSScriptBuilderConfiguration]::Set($customConfig)
    #>
    static [void] Set([PSScriptBuilderConfiguration] $configuration) {
        [PSScriptBuilderConfiguration]::Current = $configuration
        [PSScriptBuilderConfiguration]::IsLoaded = $true
    }

    <#
    .SYNOPSIS
        Resets the configuration (for testing cleanup).
    .DESCRIPTION
        The Reset() static method clears the cached configuration and marks it as unloaded. Should be called 
        in test cleanup to ensure a fresh configuration is loaded in the next test.
    .EXAMPLE
        # In test cleanup
        [PSScriptBuilderConfiguration]::Reset()
    #>
    static [void] Reset() {
        [PSScriptBuilderConfiguration]::Current = $null
        [PSScriptBuilderConfiguration]::IsLoaded = $false
    }

    <#
    .SYNOPSIS
        Creates a default configuration file in the specified project root.
    .DESCRIPTION
        The CreateDefault() static method writes a new psscriptbuilder.config.json file with default
        values to the specified project root directory. If the file already exists, an
        InvalidOperationException is thrown unless force is set to $true.
    .PARAMETER projectRoot
        The path to the project root directory where the configuration file will be created.
    .PARAMETER force
        If set to $true, overwrites an existing configuration file.
    #>
    static [void] CreateDefault([string] $projectRoot, [bool] $force) {
        $configPath = [Path]::Combine($projectRoot, "psscriptbuilder.config.json")

        if ([File]::Exists($configPath) -and -not $force) {
            $message = "Configuration file already exists: '{0}'. Use -Force to overwrite." -f $configPath
            throw [InvalidOperationException]::new($message)
        }

        $defaultConfig = [ordered] @{
            release = [ordered] @{
                dataFile       = ".\build\Release\psscriptbuilder.releasedata.json"
                bumpConfigFile = ".\build\Release\psscriptbuilder.bumpconfig.json"
            }
            build = [ordered] @{
                outputPath              = ".\build\Output"
                backupPath              = ".\build\Output\Backup"
                templatePath            = ".\build\Templates"
                orderedComponentsKey    = "ORDERED_COMPONENTS"
                backupEnabled           = $false
                syntaxValidationEnabled = $true
            }
        }

        $defaultContent = $defaultConfig | ConvertTo-Json -Depth 3

        [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($configPath, $defaultContent)
        Write-Verbose "Configuration file created: $configPath"
    }

    <#
    .SYNOPSIS
        Gets the current configuration instance.
    .DESCRIPTION
        The GetCurrent() static method returns the cached configuration. If not yet loaded, it triggers 
        Load() automatically.
    .OUTPUTS
        Returns the cached instance of PSScriptBuilderConfiguration.
    #>
    static [PSScriptBuilderConfiguration] GetCurrent() {
        if (-not [PSScriptBuilderConfiguration]::IsLoaded) {
            [PSScriptBuilderConfiguration]::Load() | Out-Null
        }

        return [PSScriptBuilderConfiguration]::Current
    }
    #endregion Static Methods (Configuration Lifecycle)

    #region Helper Methods
    <#
    .SYNOPSIS
        Initializes the configuration by loading settings from the configuration file.
    .DESCRIPTION
        The Initialize method reads the configuration file specified in the ConfigFileName property,
        validates its structure against the expected schema, and populates the class properties with 
        the corresponding settings.
    #>
    [void] Initialize() {
        $config = [PSScriptBuilderConfigLoader]::LoadFromFile($this.ConfigFileName)
        
        # Validate the configuration structure before processing
        $validator = [PSScriptBuilderConfigValidator]::new()
        $validator.Validate($config)
        
        # Load options from validated configuration
        $this.Release = [PSScriptBuilderConfigLoader]::LoadReleaseOptions($config)
        $this.Build   = [PSScriptBuilderConfigLoader]::LoadBuildOptions($config)
    }
    #endregion Helper Methods

    #region Data Formatting
    <#
    .SYNOPSIS
        Returns a flattened representation of the configuration as an OrderedDictionary.
    .DESCRIPTION
        The GetConfigurationFlattened method converts the hierarchical configuration structure into a 
        single-level OrderedDictionary. 
        This is useful for tabular display or when a flat structure is needed.
    .OUTPUTS
        Returns a System.Collections.Specialized.OrderedDictionary with flattened configuration properties.
    #>
    [OrderedDictionary] GetConfigurationFlattened() {
        return [ordered] @{
            ReleaseDataFile              = $this.Release.DataFile
            ReleaseBumpConfigFile        = $this.Release.BumpConfigFile
            BuildTemplatePath            = $this.Build.TemplatePath
            BuildOutputPath              = $this.Build.OutputPath
            BuildBackupPath              = $this.Build.BackupPath
            BuildOrderedComponentsKey    = $this.Build.OrderedComponentsKey
            BuildBackupEnabled           = $this.Build.BackupEnabled
            BuildSyntaxValidationEnabled = $this.Build.SyntaxValidationEnabled
        }
    }
    #endregion Data Formatting
    #endregion Methods
}
#endregion Class PSScriptBuilderConfiguration
