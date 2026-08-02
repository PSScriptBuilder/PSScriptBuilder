using namespace System.IO

#region Cmdlet Export-PSScriptBuilderDependencyGraph
function Export-PSScriptBuilderDependencyGraph {
    <#
    .SYNOPSIS
        Exports the dependency graph to a visual diagram format.
    .DESCRIPTION
        The Export-PSScriptBuilderDependencyGraph cmdlet converts a PSScriptBuilderDependencyGraph
        to a human-readable diagram for documentation and visualization purposes.

        Supported output formats:
        - Mermaid (default): flowchart syntax embeddable in Markdown files
        - Dot: Graphviz DOT language, compatible with graphviz tools and online viewers

        When -OutputPath is specified, the diagram is written to that file. Otherwise, the
        diagram string is returned to the pipeline.

        The cmdlet accepts ValueFromPipelineByPropertyName, enabling direct piping from
        Get-PSScriptBuilderDependencyAnalysis, which returns an object with a DependencyGraph property.
    .PARAMETER DependencyGraph
        The dependency graph to export. Accepts pipeline input by property name, enabling
        direct piping from Get-PSScriptBuilderDependencyAnalysis.
    .PARAMETER Format
        The output format for the diagram. Valid values are 'Mermaid' (default) and 'Dot'.
    .PARAMETER OutputPath
        The file path to write the diagram to. If omitted, the diagram string is returned
        to the pipeline instead.
    .PARAMETER IncludeEdgeTypes
        When specified, each edge in the diagram is annotated with its dependency type
        (Inheritance, TypeReference, FunctionCall, StaticInitializer).
    .PARAMETER Force
        When specified, overwrites an existing output file without prompting.
        When omitted and the target file already exists, the cmdlet throws an IOException.
    .OUTPUTS
        System.String
    .EXAMPLE
        $analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
        $analysis | Export-PSScriptBuilderDependencyGraph

        Exports the dependency graph as a Mermaid diagram to the pipeline.
    .EXAMPLE
        Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc |
            Export-PSScriptBuilderDependencyGraph -Format Dot -IncludeEdgeTypes -OutputPath ".\graph.dot"

        Exports the dependency graph as a Graphviz DOT diagram with edge type labels to a file.
    .EXAMPLE
        $analysis = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath ".\src\Classes" |
            Get-PSScriptBuilderDependencyAnalysis
        $analysis | Export-PSScriptBuilderDependencyGraph -OutputPath ".\docs\dependency-graph.md"

        Fluent pipeline: builds collector, analyzes dependencies, and exports Mermaid diagram.
    .EXAMPLE
        $cc | Get-PSScriptBuilderDependencyAnalysis |
            Export-PSScriptBuilderDependencyGraph -Format Dot -IncludeEdgeTypes -OutputPath '.\graph.dot'
        # Render with: dot -Tsvg graph.dot -o graph.svg

        Exports to Graphviz DOT format for large projects where Mermaid becomes hard to read.
        Requires Graphviz (https://graphviz.org) or an online viewer such as https://viz-js.com.
    .EXAMPLE
        # In a CI/CD build script:
        $cc | Get-PSScriptBuilderDependencyAnalysis |
            Export-PSScriptBuilderDependencyGraph -OutputPath '.\docs\dependency-graph.md' -Force

        Automatically updates the architecture diagram on every build.
        Use -Force to overwrite the existing file on each run.
        The Mermaid diagram is immediately renderable on GitHub, GitLab, and MkDocs.
    .NOTES
        The Mermaid format can be embedded in Markdown files and rendered by GitHub, GitLab,
        MkDocs, and many other documentation tools.

        When writing Mermaid output to a file with a .md or .markdown extension, the diagram is
        automatically wrapped in a fenced code block (```mermaid ... ```) so the file is
        immediately renderable. This wrapping is handled by the renderer. Pipeline output
        (no -OutputPath) always returns the raw diagram string without the fenced block.

        The Dot format requires Graphviz to render. It can also be visualized online at
        https://viz-js.com or https://dreampuf.github.io/GraphvizOnline.

        Components with no dependencies are rendered as isolated nodes.

        When -OutputPath is specified and the target file already exists, the cmdlet throws an
        IOException unless -Force is present. Use -Force in CI/CD scripts where the file is
        intentionally overwritten on every run.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [PSScriptBuilderDependencyGraph] $DependencyGraph,

        [Parameter()]
        [ValidateSet('Mermaid', 'Dot')]
        [string] $Format = 'Mermaid',

        [Parameter()]
        [string] $OutputPath,

        [Parameter()]
        [switch] $IncludeEdgeTypes,

        [Parameter()]
        [switch] $Force
    )

    process {
        try {
            $resolvedOutputPath = $null

            if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
                $resolvedOutputPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($OutputPath)
            }

            if ($null -ne $resolvedOutputPath -and [File]::Exists($resolvedOutputPath) -and -not $Force.IsPresent) {
                $format  = "Output file already exists: '{0}'. Use -Force to overwrite."
                $message = $format -f $resolvedOutputPath
                throw [IOException]::new($message)
            }

            $isMarkdown = $false

            if ($null -ne $resolvedOutputPath) {
                $extension  = [Path]::GetExtension($resolvedOutputPath)
                $isMarkdown = $extension -eq '.md' -or $extension -eq '.markdown'
            }

            $diagram = $null

            switch ($Format) {
                'Dot' {
                    $diagram = [PSScriptBuilderDependencyGraphRenderer]::RenderDot($DependencyGraph, $IncludeEdgeTypes.IsPresent)
                }
                default {
                    if ($isMarkdown) {
                        $diagram = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaidMarkdown($DependencyGraph, $IncludeEdgeTypes.IsPresent)
                    }
                    else {
                        $diagram = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($DependencyGraph, $IncludeEdgeTypes.IsPresent)
                    }
                }
            }

            if ($null -ne $resolvedOutputPath) {
                [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($resolvedOutputPath, $diagram)
                Write-Verbose "Dependency graph exported to: $resolvedOutputPath"
            }
            else {
                return $diagram
            }
        }
        catch {
            $format  = "Failed to export dependency graph. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Export-PSScriptBuilderDependencyGraph
