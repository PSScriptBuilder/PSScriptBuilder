using namespace System.Collections.Generic

#region Cmdlet ConvertTo-PSScriptBuilderComponentDependencyTree
function ConvertTo-PSScriptBuilderComponentDependencyTree {
    <#
    .SYNOPSIS
        Converts component dependency entries to a hierarchical tree string.
    .DESCRIPTION
        The ConvertTo-PSScriptBuilderComponentDependencyTree cmdlet converts an array of
        PSScriptBuilderComponentDependencyEntry objects (as returned by
        Get-PSScriptBuilderComponentDependency) to a hierarchical tree diagram using
        Unicode box-drawing characters.

        The result is returned as a string to the pipeline, making it suitable for display,
        file output, or further processing.
    .PARAMETER InputObject
        One or more PSScriptBuilderComponentDependencyEntry objects to convert. Accepts pipeline input.
    .OUTPUTS
        System.String
    .EXAMPLE
        $analysis = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath '.\src\Classes' |
            Get-PSScriptBuilderDependencyAnalysis
        $analysis | Get-PSScriptBuilderComponentDependency -Name 'ClassA' |
            ConvertTo-PSScriptBuilderComponentDependencyTree

        Returns the dependencies of ClassA as a hierarchical tree string.
    .EXAMPLE
        $analysis | Get-PSScriptBuilderComponentDependency -Name 'BaseClass' -Direction Dependents |
            ConvertTo-PSScriptBuilderComponentDependencyTree |
            Set-Content -Path '.\dependents.txt'

        Converts dependents of BaseClass to a tree and writes it to a file.
    .EXAMPLE
        $tree = $analysis | Get-PSScriptBuilderComponentDependency -Name 'CheckoutOrchestrator' |
            ConvertTo-PSScriptBuilderComponentDependencyTree
        $lines = '## Dependencies', '```text', $tree, '```'
        Set-Content -Path '.\docs\dependencies.md' -Value ($lines -join [System.Environment]::NewLine)

        Embeds the dependency tree in a Markdown documentation file.
    .NOTES
        Rendering is delegated to PSScriptBuilderComponentDependencyRenderer.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderComponentDependencyEntry] $InputObject
    )

    begin {
        $entries = [List[PSScriptBuilderComponentDependencyEntry]]::new()
    }

    process {
        $entries.Add($InputObject)
    }

    end {
        return [PSScriptBuilderComponentDependencyRenderer]::RenderTree($entries.ToArray())
    }
}
#endregion Cmdlet ConvertTo-PSScriptBuilderComponentDependencyTree
