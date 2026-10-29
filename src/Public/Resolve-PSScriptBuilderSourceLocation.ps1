using namespace System
using namespace System.Management.Automation

#region Cmdlet Resolve-PSScriptBuilderSourceLocation
function Resolve-PSScriptBuilderSourceLocation {
    <#
    .SYNOPSIS
        Resolves an output script line number or ErrorRecord back to its source file location.
    .DESCRIPTION
        The Resolve-PSScriptBuilderSourceLocation cmdlet reads the .sourcemap.json sidecar file
        produced by Invoke-PSScriptBuilderBuild -WriteSourceMap and resolves a line number or
        ErrorRecord from the built output script back to the originating source file and line.

        The cmdlet supports two parameter sets:
        - ByBuildResult: Accepts a PSScriptBuilderBuildResult from the pipeline. The sidecar path
          is derived automatically from BuildResult.OutputPath.
        - ByOutputPath: Accepts a path to the output script. The sidecar path is derived from that
          path. Relative paths are resolved using $Global:PSScriptBuilderProjectRoot.

        When neither -LineNumber nor -ErrorRecord is provided, the full source map is returned
        as a PSScriptBuilderSourceLocation array (useful for verifying component order).

        A warning is emitted if the output script has changed since the source map was created,
        as resolved line numbers may no longer be accurate.
    .PARAMETER BuildResult
        The build result returned by Invoke-PSScriptBuilderBuild. The sidecar path is derived
        from BuildResult.OutputPath. Accepts pipeline input.
    .PARAMETER OutputPath
        The path to the output script. Can be relative (to project root) or absolute. The sidecar
        path is derived by appending ".sourcemap.json" to this path.
    .PARAMETER LineNumber
        The 1-based line number in the output script to resolve. Cannot be combined with
        -ErrorRecord.
    .PARAMETER ErrorRecord
        An ErrorRecord whose InvocationInfo.ScriptLineNumber is used as the line number to
        resolve. Cannot be combined with -LineNumber.
    .OUTPUTS
        Returns one or more PSScriptBuilderSourceLocation objects. When -LineNumber or
        -ErrorRecord is provided, returns a single PSScriptBuilderSourceLocation (or $null if
        no component covers that line). When neither is provided, returns all entries in the
        source map as PSScriptBuilderSourceLocation[].
    .EXAMPLE
        $result = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
            Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
            Invoke-PSScriptBuilderBuild -TemplatePath 'template.psm1' -OutputPath 'output.psm1' -WriteSourceMap

        try { . $result.OutputPath }
        catch { $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_ }

        Resolves an error thrown during dot-source back to the originating source file.
    .EXAMPLE
        Resolve-PSScriptBuilderSourceLocation -OutputPath 'build\Output\MyProject.ps1' -LineNumber 1000

        Resolves a line number obtained from the console error message back to the source file.
        Requires a prior build with -WriteSourceMap.
    .EXAMPLE
        $result | Resolve-PSScriptBuilderSourceLocation | Format-Table

        Returns the full source map as a formatted table for component order verification.
    .NOTES
        A .sourcemap.json sidecar file must exist alongside the output script. Run
        Invoke-PSScriptBuilderBuild with -WriteSourceMap to generate one.

        The sidecar is tied to a specific build output. If the output script is rebuilt without
        -WriteSourceMap, the sidecar becomes stale. A SHA-256 hash comparison is performed on
        each invocation to detect staleness; a warning is emitted but resolution still proceeds.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderSourceLocation[]])]
    param(
        [Parameter(ParameterSetName = 'ByBuildResult', Mandatory, ValueFromPipeline)]
        [PSScriptBuilderBuildResult] $BuildResult,

        [Parameter(ParameterSetName = 'ByOutputPath', Mandatory)]
        [string] $OutputPath,

        [Parameter()]
        [int] $LineNumber,

        [Parameter()]
        [ErrorRecord] $ErrorRecord
    )

    process {
        try {
            if ($PSBoundParameters.ContainsKey('LineNumber') -and $PSBoundParameters.ContainsKey('ErrorRecord')) {
                $message = "Parameters 'LineNumber' and 'ErrorRecord' cannot be used together."
                throw [ArgumentException]::new($message)
            }

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
            $storedHash    = $sourceMapData.OutputHash

            $currentHash = (Get-FileHash -LiteralPath $resolvedOutputPath -Algorithm SHA256).Hash

            if ($currentHash -ne $storedHash) {
                Write-Warning "Source map may be stale - output script has changed since the source map was created."
            }

            $resolver = [PSScriptBuilderSourceLocationResolver]::new($sourceMapData)

            if ($PSBoundParameters.ContainsKey('LineNumber')) {
                return $resolver.Resolve($LineNumber)
            }
            elseif ($PSBoundParameters.ContainsKey('ErrorRecord')) {
                return $resolver.Resolve($ErrorRecord)
            }
            else {
                return $resolver.GetSourceMap()
            }
        }
        catch {
            $format  = "Failed to resolve source location. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Resolve-PSScriptBuilderSourceLocation
