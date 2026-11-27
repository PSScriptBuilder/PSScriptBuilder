using namespace System.Collections.Generic

#region Cmdlet Format-PSScriptBuilderDependencyAnalysis
function Format-PSScriptBuilderDependencyAnalysis {
    <#
    .SYNOPSIS
        Formats and displays the result of a dependency analysis operation.
    .DESCRIPTION
        The Format-PSScriptBuilderDependencyAnalysis cmdlet takes a PSScriptBuilderDependencyAnalysisResult
        object and displays its information in a clear, structured format. The output includes an analysis
        summary, component counts, and cycle information if applicable.

        By default, displays a compact summary. Use -Detailed for additional information including
        the full ordered component list (or a note if cycles prevent sorting).
    .PARAMETER AnalysisResult
        The PSScriptBuilderDependencyAnalysisResult object returned from Get-PSScriptBuilderDependencyAnalysis.
    .PARAMETER Detailed
        When specified, displays the full ordered component list in dependency order.
        If cycles were detected, a note is shown instead of the list.
        Without this switch, only the analysis summary, component counts, and cycle path (if any) are shown.
    .OUTPUTS
        None
    .EXAMPLE
        $analysis = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath "src" |
            Get-PSScriptBuilderDependencyAnalysis
        $analysis | Format-PSScriptBuilderDependencyAnalysis

        Displays a compact dependency analysis summary.
    .EXAMPLE
        $analysis | Format-PSScriptBuilderDependencyAnalysis -Detailed

        Displays the full analysis including the ordered component list.
    .NOTES
        This cmdlet displays results using Write-Host. It does not return any values.
        Cycle path is always shown when cycles are detected, regardless of -Detailed.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderDependencyAnalysisResult] $AnalysisResult,

        [Parameter()]
        [switch] $Detailed
    )

    process {
        Write-Host ""
        Write-Host "Analysis Summary"
        Write-Host "  Components : $($AnalysisResult.TotalComponents)"
        Write-Host "  Nodes      : $($AnalysisResult.TotalNodes)"
        Write-Host "  Edges      : $($AnalysisResult.TotalEdges)"
        Write-Host "  Cycles     : $(if ($AnalysisResult.HasCycles) { 'Detected' } else { 'None' })"
        Write-Host "  Cross-Deps : $(if ($AnalysisResult.HasCrossDependencies) { 'Detected' } else { 'None' })"

        Write-Host ""
        Write-Host "Components"

        $counts = $AnalysisResult.ComponentCounts
        $items  = [List[PSCustomObject]]::new()

        if ($null -ne $counts) {
            if ($counts.UsingStatements     -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Using';     Value = $counts.UsingStatements })     }
            if ($counts.EnumDefinitions     -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Enums';     Value = $counts.EnumDefinitions })     }
            if ($counts.ClassDefinitions    -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Classes';   Value = $counts.ClassDefinitions })    }
            if ($counts.FunctionDefinitions -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Functions'; Value = $counts.FunctionDefinitions }) }
            if ($counts.FileContents        -gt 0) { [void] $items.Add([PSCustomObject] @{ Label = 'Files';     Value = $counts.FileContents })        }
        }

        if ($items.Count -ne 0) {
            $maxLabelLength = ($items | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum
            $maxValueLength = "$($AnalysisResult.TotalComponents)".Length

            foreach ($item in $items) {
                Write-Host "  $($item.Label.PadRight($maxLabelLength)) : $("$($item.Value)".PadLeft($maxValueLength))"
            }

            Write-Host "  $('Total'.PadRight($maxLabelLength)) : $("$($AnalysisResult.TotalComponents)".PadLeft($maxValueLength))"
        }
        else {
            Write-Host "  None"
        }

        if ($AnalysisResult.HasCycles) {
            Write-Host ""
            Write-Host "Cycle Path"

            if ($null -ne $AnalysisResult.CyclePath -and $AnalysisResult.CyclePath.Count -gt 0) {
                Write-Host "  $($AnalysisResult.CyclePath[0])"

                for ($i = 1; $i -lt $AnalysisResult.CyclePath.Count; $i++) {
                    Write-Host "  -> $($AnalysisResult.CyclePath[$i])"
                }
            }
            else {
                Write-Host "  (cycle path unavailable)"
            }
        }

        if ($Detailed) {
            Write-Host ""

            if ($AnalysisResult.HasCycles) {
                Write-Host "Ordered Components"
                Write-Host "  No ordered component list available (cycle prevents topological sort)"
            }
            elseif ($null -ne $AnalysisResult.OrderedComponents -and $AnalysisResult.OrderedComponents.Count -gt 0) {
                Write-Host "Ordered Components ($($AnalysisResult.OrderedComponents.Count))"

                foreach ($component in $AnalysisResult.OrderedComponents) {
                    Write-Host "  $component"
                }
            }
            else {
                Write-Host "Ordered Components"
                Write-Host "  (no components)"
            }
        }

        Write-Host ""
    }
}
#endregion Cmdlet Format-PSScriptBuilderDependencyAnalysis
