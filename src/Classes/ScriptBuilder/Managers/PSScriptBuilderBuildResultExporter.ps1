using namespace System
using namespace System.Collections.Specialized
using namespace System.IO

#region Class PSScriptBuilderBuildResultExporter
<#
.SYNOPSIS
    Exports a PSScriptBuilderBuildResult to a JSON file.
.DESCRIPTION
    The PSScriptBuilderBuildResultExporter class serializes a PSScriptBuilderBuildResult to a
    structured JSON file suitable for use as a CI artifact for debugging, auditing, and
    tracking changes between builds.

    The output always includes the build summary (output path, file size, timing, component
    counts, syntax validation status, and a UTC generation timestamp). When detailed output
    is requested, the processed file list and full component details are also included.
#>
class PSScriptBuilderBuildResultExporter {
    #region Properties
    <#
    .SYNOPSIS
        The build result to export.
    .DESCRIPTION
        The BuildResult property holds the PSScriptBuilderBuildResult instance to serialize into
        the JSON output file.
    #>
    hidden [PSScriptBuilderBuildResult] $BuildResult

    <#
    .SYNOPSIS
        The absolute path to write the JSON file to.
    .DESCRIPTION
        The Path property holds the absolute path to the JSON file that will be written by the
        Export method.
    #>
    hidden [string] $Path

    <#
    .SYNOPSIS
        Whether to include processed files and component details in the output.
    .DESCRIPTION
        The Detailed property controls whether the processed file list and per-component details
        are included in the JSON output. When false, only the build summary and component counts
        are written.
    #>
    hidden [bool] $Detailed

    <#
    .SYNOPSIS
        Whether to overwrite an existing file.
    .DESCRIPTION
        The Force property controls whether an existing output file is overwritten without error.
        When false, the Export method throws an IOException if the target file already exists.
    #>
    hidden [bool] $Force
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderBuildResultExporter class.
    .DESCRIPTION
        Creates a new PSScriptBuilderBuildResultExporter with the specified build result, target
        path, detail level, and force flag.
    .PARAMETER buildResult
        The build result to export.
    .PARAMETER path
        The absolute path to write the JSON file to.
    .PARAMETER detailed
        If true, processed files and component details are included in the output.
    .PARAMETER force
        If true, an existing file is overwritten without error.
    #>
    PSScriptBuilderBuildResultExporter(
        [PSScriptBuilderBuildResult] $buildResult,
        [string]                     $path,
        [bool]                       $detailed,
        [bool]                       $force
    ) {
        $this.BuildResult = $buildResult
        $this.Path        = $path
        $this.Detailed    = $detailed
        $this.Force       = $force
    }
    #endregion Constructors

    #region Public Methods
    <#
    .SYNOPSIS
        Exports the build result to a JSON file.
    .DESCRIPTION
        Ensures the output directory exists, applies the force guard, serializes the build
        result to JSON, and writes the file using UTF-8 encoding without BOM.
    .OUTPUTS
        Returns the absolute path of the written file.
    #>
    [string] Export() {
        if ([File]::Exists($this.Path) -and -not $this.Force) {
            $format  = "Output file already exists: '{0}'. Use -Force to overwrite."
            $message = $format -f $this.Path
            throw [IOException]::new($message)
        }

        $directory = [Path]::GetDirectoryName($this.Path)

        if ($directory -and -not (Test-Path -Path $directory -PathType Container)) {
            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($directory)
            Write-Verbose "  Created directory: $directory"
        }

        $json = $this.BuildJson()

        [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithoutBOM($this.Path, $json)

        $fileInfo = [FileInfo]::new($this.Path)
        $fileSize = [PSScriptBuilderTextHelper]::FormatFileSize($fileInfo.Length)
        $mode     = if ($this.Detailed) { 'detailed' } else { 'compact' }
        Write-Verbose "Export complete: $fileSize ($mode)"

        return $this.Path
    }
    #endregion Public Methods

    #region Private Methods
    <#
    .SYNOPSIS
        Serializes the build data to a normalized JSON string.
    .DESCRIPTION
        Builds the data structure via BuildData, serializes it with ConvertTo-Json, and
        normalizes empty arrays to compact inline form to avoid the multi-line empty array
        formatting produced by ConvertTo-Json in PowerShell 5.1.
    .OUTPUTS
        Returns a JSON string ready to be written to the output file.
    #>
    hidden [string] BuildJson() {
        $data = $this.BuildData()
        $json = $data | ConvertTo-Json -Depth 10
        return $json -replace '\[\s*\r?\n\s*\]', '[]'
    }

    <#
    .SYNOPSIS
        Builds the OrderedDictionary representing the report data.
    .DESCRIPTION
        Maps build result properties to JSON-friendly types: TimeSpan to milliseconds,
        CollectorType enum to string, and adds a UTC generation timestamp.
        When Detailed is true, processed files and component details are appended.
    .OUTPUTS
        Returns an OrderedDictionary ready for ConvertTo-Json serialization.
    #>
    hidden [OrderedDictionary] BuildData() {
        $result = $this.BuildResult

        $data = [ordered] @{
            generatedAt         = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssK')
            outputPath          = $result.OutputPath
            outputFileSizeBytes = $result.OutputFileSize
            backupPath          = $result.BackupPath
            syntaxValid         = $result.SyntaxValid
            executionTimeMs     = [long] $result.ExecutionTime.TotalMilliseconds
            totalComponents     = $result.TotalComponents
            componentCounts     = [ordered] @{
                usingStatements     = $result.ComponentCounts.UsingStatements
                enumDefinitions     = $result.ComponentCounts.EnumDefinitions
                classDefinitions    = $result.ComponentCounts.ClassDefinitions
                functionDefinitions = $result.ComponentCounts.FunctionDefinitions
                fileContents        = $result.ComponentCounts.FileContents
            }
        }

        if ($this.Detailed) {
            $data['processedFiles'] = $result.ProcessedFiles

            $data['components'] = @(foreach ($detail in $result.ComponentDetails) {
                [ordered] @{
                    type         = [PSScriptBuilderTextHelper]::FormatCollectorType($detail.Type)
                    name         = $detail.Name
                    sourceFile   = $detail.SourceFile
                    dependencies = $detail.Dependencies
                }
            })
        }

        return $data
    }
    #endregion Private Methods
}
#endregion Class PSScriptBuilderBuildResultExporter
