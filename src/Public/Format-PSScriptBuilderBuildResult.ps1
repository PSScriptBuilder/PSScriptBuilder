using namespace System.Collections.Generic

#region Cmdlet Format-PSScriptBuilderBuildResult
function Format-PSScriptBuilderBuildResult {
    <#
    .SYNOPSIS
        Formats and displays the result of a build operation.
    .DESCRIPTION
        The Format-PSScriptBuilderBuildResult cmdlet takes a PSScriptBuilderBuildResult object and displays
        its information in a clear, structured format. The output includes build summary, component counts,
        and dependency information.

        By default, displays a compact summary. Use -Detailed for comprehensive information including
        all processed files and component details.
    .PARAMETER BuildResult
        The PSScriptBuilderBuildResult object returned from Invoke-PSScriptBuilderBuild.
    .PARAMETER Detailed
        When specified, displays additional information including:
        - Complete list of all processed source files
        - Full backup file path (if backup was created)
        - Component details with dependencies

        Without this switch, only the build summary, component counts, and total execution time are shown.
    .EXAMPLE
        $result = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath "template.psm1" -OutputPath "output.psm1"
        Format-PSScriptBuilderBuildResult -BuildResult $result

        Displays a compact build summary with component counts and execution time.
    .EXAMPLE
        $result | Format-PSScriptBuilderBuildResult -Detailed

        Pipes an existing build result and displays detailed information including all processed
        source files and component dependencies.
    .OUTPUTS
        None
    .NOTES
        This cmdlet displays build results using Write-Host. It does not return any values.
        File sizes are displayed in human-readable format (KB/MB).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderBuildResult] $BuildResult,

        [Parameter()]
        [switch] $Detailed
    )

    process {
        # Validate input
        if ($null -eq $BuildResult) {
            Write-Host "BuildResult is null. Nothing to display."
            return
        }

        Write-Host ""
        Write-Host "Build Summary"
        Write-Host "  Output : $($BuildResult.OutputPath)"
        Write-Host "  Size   : $([PSScriptBuilderTextHelper]::FormatFileSize($BuildResult.OutputFileSize))"
        Write-Host "  Time   : $([PSScriptBuilderTextHelper]::FormatDuration($BuildResult.ExecutionTime))"

        if (-not [string]::IsNullOrWhiteSpace($BuildResult.BackupPath)) {
            Write-Host "  Backup : $($BuildResult.BackupPath)"
        }

        Write-Host ""
        Write-Host "Components"

        $counts = $BuildResult.ComponentCounts
        $items  = [List[PSCustomObject]]::new()

        if ($counts.UsingStatements     -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Using';     Value = $counts.UsingStatements })     }
        if ($counts.EnumDefinitions     -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Enums';     Value = $counts.EnumDefinitions })     }
        if ($counts.ClassDefinitions    -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Classes';   Value = $counts.ClassDefinitions })    }
        if ($counts.FunctionDefinitions -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Functions'; Value = $counts.FunctionDefinitions }) }
        if ($counts.FileContents        -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Files';     Value = $counts.FileContents })        }

        if ($items.Count -ne 0) {
            $maxLabelLength = ($items | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum
            $maxValueLength = "$($BuildResult.TotalComponents)".Length

            foreach ($item in $items) {
                Write-Host "  $($item.Label.PadRight($maxLabelLength)) : $("$($item.Value)".PadLeft($maxValueLength))"
            }

            Write-Host "  $('Total'.PadRight($maxLabelLength)) : $("$($BuildResult.TotalComponents)".PadLeft($maxValueLength))"
        }
        else {
            Write-Host "  None"
        }

        Write-Host ""

        # Detailed Information
        if ($Detailed) {
            # Processed Files
            if ($null -ne $BuildResult.ProcessedFiles -and $BuildResult.ProcessedFiles.Count -gt 0) {
                Write-Host "Processed Files ($($BuildResult.ProcessedFiles.Count))"

                foreach ($file in $BuildResult.ProcessedFiles) {
                    Write-Host "  $file"
                }

                Write-Host ""
            }

            # Component Details
            if ($null -ne $BuildResult.ComponentDetails -and $BuildResult.ComponentDetails.Count -gt 0) {
                Write-Host "Component Details"

                # Group by type
                $grouped = $BuildResult.ComponentDetails | Group-Object -Property Type

                foreach ($group in $grouped) {
                    $typeLabel = [PSScriptBuilderTextHelper]::FormatCollectorType($group.Group[0].Type)
                    Write-Host "  $($typeLabel):"

                    foreach ($component in $group.Group) {
                        Write-Host "    $($component.Name)"
                        Write-Host "      File : $($component.SourceFile)"

                        if ($null -ne $component.Dependencies -and $component.Dependencies.Count -gt 0) {
                            Write-Host "      Deps : $($component.Dependencies -join ', ')"
                        }
                    }
                    Write-Host ""
                }
            }
        }
    }
}
#endregion Cmdlet Format-PSScriptBuilderBuildResult
