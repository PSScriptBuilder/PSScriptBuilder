using namespace System

#region Class PSScriptBuilderBuildResult
<#
.SYNOPSIS
    Represents the complete result of a build operation.
.DESCRIPTION
    The PSScriptBuilderBuildResult class encapsulates comprehensive information about a build operation
    including output details, component counts, timing metrics, dependency information, processed files, and
    component details. This class provides a complete audit trail for logging and reporting purposes.
#>
class PSScriptBuilderBuildResult {
    #region Properties
    <#
    .SYNOPSIS
        The path to the generated output file.
    .DESCRIPTION
        The OutputPath property holds the absolute path to the generated script file.
    #>
    [string] $OutputPath

    <#
    .SYNOPSIS
        The size of the output file in bytes.
    .DESCRIPTION
        The OutputFileSize property contains the file size of the generated script in bytes.
    #>
    [long] $OutputFileSize

    <#
    .SYNOPSIS
        The path to the backup file, if created.
    .DESCRIPTION
        The BackupPath property holds the absolute path to the backup file created before overwriting
        an existing output file. Is null if no backup was created.
    #>
    [string] $BackupPath

    <#
    .SYNOPSIS
        Component counts for all collector types.
    .DESCRIPTION
        The ComponentCounts property contains the number of components collected by each collector type
        (using statements, enums, classes, functions, files).
    #>
    [PSScriptBuilderBuildComponentCounts] $ComponentCounts

    <#
    .SYNOPSIS
        Array of all processed source files.
    .DESCRIPTION
        The ProcessedFiles property contains the absolute paths of all source files that were
        processed during collection.
    #>
    [string[]] $ProcessedFiles

    <#
    .SYNOPSIS
        Detailed information for all collected components.
    .DESCRIPTION
        The ComponentDetails property contains detailed information (type, name, source file, dependencies)
        for all enums, classes, and functions collected during the build.
    #>
    [PSScriptBuilderBuildComponentDetail[]] $ComponentDetails

    <#
    .SYNOPSIS
        Total number of components collected.
    .DESCRIPTION
        The TotalComponents property contains the sum of all component counts (usings, enums, classes,
        functions, files). This is a calculated property set during construction.
    #>
    [int] $TotalComponents

    <#
    .SYNOPSIS
        Total execution time of the build operation.
    .DESCRIPTION
        The ExecutionTime property contains the total time taken by the build operation.
    #>
    [TimeSpan] $ExecutionTime

    <#
    .SYNOPSIS
        Indicates whether the output file passed syntax validation.
    .DESCRIPTION
        The SyntaxValid property is true if the generated output file was successfully parsed
        as a valid PowerShell script. Note that this is a parse check only — runtime type
        availability and semantic correctness are not verified.
    #>
    [bool] $SyntaxValid
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderBuildResult.
    .DESCRIPTION
        Creates a new PSScriptBuilderBuildResult with the specified build operation information.
        The TotalComponents property is calculated by summing all component counts.
    .PARAMETER outputPath
        The absolute path to the generated output file.
    .PARAMETER outputFileSize
        The size of the output file in bytes.
    .PARAMETER backupPath
        The absolute path to the backup file, or null if no backup was created.
    .PARAMETER componentCounts
        Component counts for all collector types.
    .PARAMETER executionTime
        Total execution time of the build operation.
    .PARAMETER processedFiles
        Array of all processed source file paths.
    .PARAMETER componentDetails
        Detailed information for all collected components.
    .PARAMETER syntaxValid
        Indicates whether the output file passed syntax validation (parse check).
    #>
    PSScriptBuilderBuildResult(
        [string]                                $outputPath,
        [long]                                  $outputFileSize,
        [string]                                $backupPath,
        [PSScriptBuilderBuildComponentCounts]   $componentCounts,
        [TimeSpan]                              $executionTime,
        [string[]]                              $processedFiles,
        [PSScriptBuilderBuildComponentDetail[]] $componentDetails,
        [bool]                                  $syntaxValid
    ) {
        $this.OutputPath       = $outputPath
        $this.OutputFileSize   = $outputFileSize
        $this.BackupPath       = $backupPath
        $this.ComponentCounts  = $componentCounts
        $this.ExecutionTime    = $executionTime
        $this.ProcessedFiles   = $processedFiles
        $this.ComponentDetails = $componentDetails
        $this.SyntaxValid      = $syntaxValid

        # Calculate TotalComponents
        $this.TotalComponents = 
            $componentCounts.UsingStatements     + 
            $componentCounts.EnumDefinitions     + 
            $componentCounts.ClassDefinitions    + 
            $componentCounts.FunctionDefinitions + 
            $componentCounts.FileContents
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderBuildResult
