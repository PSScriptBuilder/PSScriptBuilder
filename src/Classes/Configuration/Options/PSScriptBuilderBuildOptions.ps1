using namespace System.IO

#region Class PSScriptBuilderBuildOptions
<#
.SYNOPSIS
    Configuration options for the build process.
.DESCRIPTION
    The PSScriptBuilderBuildOptions class provides properties to configure options of the build process,
    including output path, backup settings, and syntax validation.
#>
class PSScriptBuilderBuildOptions : PSScriptBuilderOptionsBase {
    #region Properties
    <#
    .SYNOPSIS
        Specifies the output path for the build artifacts.
    .DESCRIPTION
        The OutputPath property holds the file path where the build artifacts will be saved. This allows users 
        to define a custom location for build outputs.
    #>
    [string] $OutputPath

    <#
    .SYNOPSIS
        Specifies the path to the backup directory.
    .DESCRIPTION
        The BackupPath property holds the file path where backup files will be stored. Backups are created
        before overwriting existing build output files, allowing rollback if the build fails.
    #>
    [string] $BackupPath

    <#
    .SYNOPSIS
        Specifies the path to the build templates directory.
    .DESCRIPTION
        The TemplatePath property holds the file path where build templates are located. Templates are used
        during the build process to generate output files.
    #>
    [string] $TemplatePath

    <#
    .SYNOPSIS
        Specifies the placeholder name for dependency-ordered components.
    .DESCRIPTION
        The OrderedComponentsKey property holds the name of the template placeholder used for dependency-ordered
        components when cross-dependencies are detected between classes and functions. Default is "ORDERED_COMPONENTS".
    #>
    [string] $OrderedComponentsKey = "ORDERED_COMPONENTS"

    <#
    .SYNOPSIS
        Indicates whether to create a backup of the output file before overwriting.
    .DESCRIPTION
        The BackupEnabled property is a boolean that determines whether a backup of the existing output file
        should be created before it is overwritten during the build process. Default is false.
        When enabled, backups are stored in the BackupPath directory with timestamped filenames.
    #>
    [bool] $BackupEnabled = $false

    <#
    .SYNOPSIS
        Indicates whether output syntax validation is enabled.
    .DESCRIPTION
        The SyntaxValidationEnabled property is a boolean that determines whether the output file is
        validated for syntax correctness after the build. Default is true.
        TypeNotFound errors caused by external assemblies not loaded at build time are automatically
        filtered and do not fail the validation. Disable this only when the output contains syntax
        that cannot be parsed at all by the PowerShell parser.
    #>
    [bool] $SyntaxValidationEnabled = $true
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderBuildOptions class.
    .DESCRIPTION
        The constructor takes a PSCustomObject containing configuration data and initializes the class instance.
    .PARAMETER config
        A PSCustomObject containing the build configuration data.
    #>
    PSScriptBuilderBuildOptions([PSCustomObject] $config) : base($config) {
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Sets the build options based on the provided configuration.
    .DESCRIPTION
        The SetOptions method sets the corresponding properties of the BuildOptions instance from the 
        provided configuration object.
    .PARAMETER config
        A PSCustomObject containing the build configuration data.
    #>
    [void] SetOptions([PSCustomObject] $config) {
        $this.OutputPath              = [string] $this.GetPropertyValue($config, "outputPath")
        $this.BackupPath              = [string] $this.GetPropertyValue($config, "backupPath")
        $this.TemplatePath            = [string] $this.GetPropertyValue($config, "templatePath")
        $this.OrderedComponentsKey    = [string] $this.GetPropertyValue($config, "orderedComponentsKey")
        $this.BackupEnabled           = [bool]   $this.GetPropertyValue($config, "backupEnabled")
        $this.SyntaxValidationEnabled = [bool]   $this.GetPropertyValue($config, "syntaxValidationEnabled")
    }

    <#
    .SYNOPSIS
        Validates the build options.
    .DESCRIPTION
        The ValidateOptions method performs option-specific validation including path normalization
        and directory creation if required. Structural validation is handled by PSScriptBuilderConfigValidator.
    #>
    [void] ValidateOptions() {
        # Normalize path to absolute path rooted at the project root
        $this.OutputPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($this.OutputPath)

        # Validate backup path if backup is enabled
        if ($this.BackupEnabled) {
            if ([string]::IsNullOrWhiteSpace($this.BackupPath)) {
                $message = 
                    "Backup is enabled but backup path is not configured." + $([Environment]::NewLine) + 
                    "Set 'backupPath' in the configuration or disable backup by setting 'backupEnabled' to false"
                throw [InvalidOperationException]::new($message)
            }
        }

        # Normalize backup path to absolute path rooted at the project root
        # Note: Backup directory is created on-demand by BackupManager when needed
        $this.BackupPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($this.BackupPath)


        # Normalize template path to absolute path rooted at the project root
        $this.TemplatePath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($this.TemplatePath)
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderBuildOptions
