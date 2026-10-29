#region Cmdlet Export-PSScriptBuilderBuildResult
function Export-PSScriptBuilderBuildResult {
    <#
    .SYNOPSIS
        Exports a build result to a JSON file.
    .DESCRIPTION
        The Export-PSScriptBuilderBuildResult cmdlet serializes a PSScriptBuilderBuildResult to a
        structured JSON file suitable for use as a CI artifact for debugging, auditing, and
        tracking changes between builds.

        The output always includes build summary data: output path, file size, syntax validation
        status, execution time, total component count, and component counts by type. A UTC
        generation timestamp is added automatically.

        Use -Detailed to include the full list of processed source files and per-component details
        (type, name, source file, and dependencies) in the output.

        Relative paths are resolved using the project root ($Global:PSScriptBuilderProjectRoot).
        If the project root has not been set explicitly, it is auto-discovered from the current
        working directory. The output directory is created automatically if it does not exist.
    .PARAMETER BuildResult
        The build result to export. Accepts pipeline input.
    .PARAMETER Path
        The file path to write the JSON report to. Relative paths are resolved using the project
        root. The output directory is created automatically if it does not exist.
    .PARAMETER Detailed
        When specified, includes the full list of processed source files and per-component details
        (type, name, source file, dependencies) in the JSON output.

        Without this switch, only the build summary and component counts are included.
    .PARAMETER Force
        When specified, overwrites an existing file without error.
        When omitted and the target file already exists, the cmdlet throws an IOException.
    .OUTPUTS
        System.String
    .EXAMPLE
        $result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json"

        Exports a compact build summary to a JSON file.
    .EXAMPLE
        $result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json" -Detailed -Force

        Exports a detailed report including all processed files and component details.
        Overwrites the file if it already exists.
    .EXAMPLE
        $result = Invoke-PSScriptBuilderBuild @buildParams
        $result | Format-PSScriptBuilderBuildResult
        $result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json" -Force

        Builds the script, displays the result to the console, and exports the report as a CI artifact.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSScriptBuilderBuildResult] $BuildResult,

        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $false)]
        [switch] $Detailed,

        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    process {
        try {
            $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($Path)

            Write-Verbose "Exporting build result to: $resolvedPath"

            $exporter = [PSScriptBuilderBuildResultExporter]::new(
                $BuildResult,
                $resolvedPath,
                $Detailed.IsPresent,
                $Force.IsPresent
            )

            $outputPath = $exporter.Export()

            return $outputPath
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Export-PSScriptBuilderBuildResult
