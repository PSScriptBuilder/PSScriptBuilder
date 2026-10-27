using namespace System

#region Cmdlet Get-PSScriptBuilderSourceCoverage
function Get-PSScriptBuilderSourceCoverage {
    <#
    .SYNOPSIS
        Translates Pester code coverage data back to the original source files.
    .DESCRIPTION
        The Get-PSScriptBuilderSourceCoverage cmdlet reads the .sourcemap.json sidecar file
        produced by Invoke-PSScriptBuilderBuild -WriteSourceMap and translates a Pester
        CodeCoverage result - reported in terms of the built output script - back to
        per-source-file coverage aggregates.

        This translation is necessary whenever tests load the built output as a single unit
        (e.g. via 'using module' for class-based projects) rather than the original per-file
        sources: Pester's CodeCoverage.Path must then point at the build output, since that is
        the only file whose execution PowerShell has any record of, and the resulting line
        numbers are otherwise meaningless relative to a multi-file source tree.

        The cmdlet supports two parameter sets:
        - ByBuildResult: Accepts a PSScriptBuilderBuildResult from the pipeline. The sidecar
          path is taken directly from BuildResult.SourceMapPath.
        - ByOutputPath: Accepts a path to the output script. The sidecar path is derived from
          that path. Relative paths are resolved using $Global:PSScriptBuilderProjectRoot.

        A warning is emitted if the output script has changed since the source map was
        created, as resolved line numbers may no longer be accurate. Coverage entries that
        reference a file other than the build output, or that fall outside any tracked
        component, are skipped and reported as a single consolidated warning each.
    .PARAMETER BuildResult
        The build result returned by Invoke-PSScriptBuilderBuild. The sidecar path is taken
        from BuildResult.SourceMapPath. Accepts pipeline input.
    .PARAMETER OutputPath
        The path to the output script. Can be relative (to project root) or absolute. The
        sidecar path is derived by appending ".sourcemap.json" to this path.
    .PARAMETER CodeCoverage
        The CodeCoverage property of a Pester result object (e.g. $pesterResult.CodeCoverage),
        exposing CommandsExecuted and CommandsMissed collections.
    .OUTPUTS
        Returns an array of PSScriptBuilderSourceCoverageResult, one per distinct source file
        referenced by the resolved coverage entries.
    .EXAMPLE
        $buildResult = $contentCollector |
            Invoke-PSScriptBuilderBuild -TemplatePath 'template.psm1' -OutputPath 'output.psm1' -WriteSourceMap

        $config = [PesterConfiguration]::Default
        $config.Run.Path             = 'tests'
        $config.Run.PassThru         = $true
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path    = $buildResult.OutputPath

        $pesterResult = Invoke-Pester -Configuration $config

        $buildResult | Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
            Format-PSScriptBuilderSourceCoverage

        Builds with a source map, runs Pester coverage against the built output, and displays
        coverage per original source file.
    .NOTES
        A .sourcemap.json sidecar file must exist alongside the output script. Run
        Invoke-PSScriptBuilderBuild with -WriteSourceMap to generate one.

        CodeCoverage.Path must point at the build output script, not at the original source
        files - otherwise Pester has no record of any executed code and reports 0% coverage
        for every source file.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderSourceCoverageResult[]])]
    param(
        [Parameter(ParameterSetName = 'ByBuildResult', Mandatory, ValueFromPipeline)]
        [PSScriptBuilderBuildResult] $BuildResult,

        [Parameter(ParameterSetName = 'ByOutputPath', Mandatory)]
        [string] $OutputPath,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $CodeCoverage
    )

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'ByBuildResult') {
                if ([string]::IsNullOrWhiteSpace($BuildResult.SourceMapPath)) {
                    $message = "No source map was written for this build. Re-run Invoke-PSScriptBuilderBuild with -WriteSourceMap."
                    throw [InvalidOperationException]::new($message)
                }
                $resolvedOutputPath = $BuildResult.OutputPath
                $sidecarPath        = $BuildResult.SourceMapPath
            }
            else {
                $resolvedOutputPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($OutputPath)
                $sidecarPath        = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($resolvedOutputPath)
            }

            $sourceMapData = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)
            $currentHash   = (Get-FileHash -LiteralPath $resolvedOutputPath -Algorithm SHA256).Hash

            if ($currentHash -ne $sourceMapData.OutputHash) {
                Write-Warning "Source map may be stale - output script has changed since the source map was created."
            }

            $resolver   = [PSScriptBuilderSourceLocationResolver]::new($sourceMapData)
            $translator = [PSScriptBuilderCodeCoverageTranslator]::new($resolver)

            return $translator.Translate($resolvedOutputPath, $CodeCoverage.CommandsExecuted, $CodeCoverage.CommandsMissed)
        }
        catch {
            $format  = "Failed to compute source coverage. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderSourceCoverage
