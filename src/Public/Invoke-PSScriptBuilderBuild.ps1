#region Cmdlet Invoke-PSScriptBuilderBuild
function Invoke-PSScriptBuilderBuild {
    <#
    .SYNOPSIS
        Executes the complete PowerShell script build process.
    .DESCRIPTION
        The Invoke-PSScriptBuilderBuild cmdlet orchestrates the entire build workflow, including:
        - Loading the template file
        - Collecting components from all registered collectors
        - Building and analyzing dependency graphs
        - Detecting circular dependencies (causes the build to fail with a detailed error message)
        - Performing topological sorting
        - Processing the template with collected components
        - Creating backups of existing output files (if enabled via -EnableBackup)
        - Writing the final output script

        The cmdlet returns a detailed BuildResult object containing metrics, timings, component counts,
        and file information. All paths are resolved relative to the project root
        ($Global:PSScriptBuilderProjectRoot) unless absolute paths are provided.

        By default, no backup is created before overwriting the output file. Use -EnableBackup to
        enable backup creation. This follows modern development practices where Git is used for
        version control instead of file-based backups.
    .PARAMETER ContentCollector
        The ContentCollector instance containing all registered component collectors. Accepts pipeline
        input to enable fluent chaining from Add-PSScriptBuilderCollector.
    .PARAMETER TemplatePath
        The path to the template file. Can be relative (to project root) or absolute.
        The template must contain placeholders for the sorted components and other collector keys.
        Relative paths are resolved using $Global:PSScriptBuilderProjectRoot.

        Example: "build\templates\module.psm1.template"
    .PARAMETER OutputPath
        The path where the final built script will be written. Can be relative (to project root) or absolute.
        Relative paths are resolved using $Global:PSScriptBuilderProjectRoot.

        Example: "build\output\MyModule.psm1"
    .PARAMETER BackupPath
        The directory where backup files are stored before overwriting existing output files.
        Can be relative (to project root) or absolute. Relative paths are resolved using
        $Global:PSScriptBuilderProjectRoot. If not specified, backups are created in the
        same directory as the output file.

        Backup files are named with a timestamp: MyModule.psm1.20260304_153045.bak
    .PARAMETER OrderedComponentsKey
        The placeholder key in the template that will be replaced with the dependency-ordered
        components. Defaults to "ORDERED_COMPONENTS".

        In the template: {{ORDERED_COMPONENTS}}
    .PARAMETER EnableBackup
        Enables backup creation of the existing output file before overwriting it. By default, no
        backup is created. When enabled, backup files are stored in the BackupPath directory with a
        timestamped filename (e.g., MyModule.psm1.20260309_153045.bak).

        This parameter can be used in combination with configuration files: load the configuration,
        check the Build.BackupEnabled option, and pass the switch accordingly.
    .PARAMETER SkipSyntaxValidation
        Skips the syntax validation step after writing the output file. By default, the output file
        is parsed to verify its syntactic correctness. TypeNotFound errors caused by external
        assemblies not loaded at build time are automatically filtered and do not fail validation.
        Use this switch only when the output contains syntax that cannot be parsed at all by the
        PowerShell parser.
    .OUTPUTS
        PSScriptBuilderBuildResult
    .EXAMPLE
        $result = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
            Invoke-PSScriptBuilderBuild -TemplatePath "template.psm1" -OutputPath "output.psm1"

        Fluent pipeline build using chained collector registration.
    .EXAMPLE
        $config = Get-PSScriptBuilderConfiguration
        $result = Invoke-PSScriptBuilderBuild -ContentCollector $cc `
            -TemplatePath $config.Build.TemplatePath `
            -OutputPath $config.Build.OutputPath `
            -BackupPath $config.Build.BackupPath `
            -EnableBackup:$config.Build.BackupEnabled

        Uses a configuration file for path resolution and backup control.
    .NOTES
        The cmdlet is a thin wrapper around PSScriptBuilderBuildOrchestrator, focusing on:
        - Project root path resolution (relative to $Global:PSScriptBuilderProjectRoot)
        - Exception propagation with context

        All validation logic (template existence, collector count, path validation, etc.) is
        handled by the Orchestrator and its dependencies. This keeps the cmdlet lightweight.
        Backups are disabled by default. Use -EnableBackup to enable backup creation. This follows
        modern development practices where version control (Git) is preferred over file-based backups.
        The Build.BackupEnabled configuration option can be used to set a project-wide default, which
        can then be passed to the cmdlet based on user preference.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderBuildResult])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter(Mandatory)]
        [string] $TemplatePath,

        [Parameter(Mandatory)]
        [string] $OutputPath,

        [Parameter()]
        [string] $BackupPath,

        [Parameter()]
        [string] $OrderedComponentsKey = "ORDERED_COMPONENTS",

        [Parameter()]
        [switch] $EnableBackup,

        [Parameter()]
        [switch] $SkipSyntaxValidation
    )

    process {
        try {
            # Resolve paths relative to project root (using PSScriptBuilderFileSystemHelper)
            $resolvedTemplatePath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($TemplatePath)
            $resolvedOutputPath   = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($OutputPath)

            $resolvedBackupPath = ""

            if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
                $resolvedBackupPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($BackupPath)
            }

            # Create orchestrator (all validation happens in constructor/Execute)
            $orchestrator = [PSScriptBuilderBuildOrchestrator]::new(
                $ContentCollector,
                $resolvedTemplatePath,
                $resolvedOutputPath,
                $resolvedBackupPath,
                $OrderedComponentsKey,
                $EnableBackup.IsPresent,
                (-not $SkipSyntaxValidation.IsPresent)
            )

            # Execute build
            $result = $orchestrator.ExecuteBuild()

            return $result
        }
        catch {
            $message = "Build failed. Error: $($_.Exception.Message)"
            throw [Exception]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Invoke-PSScriptBuilderBuild
