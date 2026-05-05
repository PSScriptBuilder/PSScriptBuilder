using namespace System
using namespace System.Text

#region Class PSScriptBuilderDependencyGraphRenderer
<#
.SYNOPSIS
    Renders a dependency graph to a string representation.
.DESCRIPTION
    The PSScriptBuilderDependencyGraphRenderer class converts a PSScriptBuilderDependencyGraph
    to human-readable formats for documentation and visualization purposes.

    Supported output formats:
    - Mermaid: flowchart diagram syntax (TD direction), embeddable in Markdown
    - Dot: Graphviz DOT language, compatible with graphviz and online viewers

    All methods are static — no instance is required.
#>
class PSScriptBuilderDependencyGraphRenderer {
    #region Methods
    <#
    .SYNOPSIS
        Renders the dependency graph as a Mermaid flowchart diagram.
    .DESCRIPTION
        The RenderMermaid method converts the dependency graph to Mermaid flowchart syntax.
        Nodes with no edges are rendered as standalone entries. Directed edges are rendered
        as arrows from dependent to dependency.

        When includeEdgeTypes is true, each arrow is annotated with the edge type label
        (Inheritance, TypeReference, FunctionCall, StaticInitializer).
    .PARAMETER graph
        The dependency graph to render. Cannot be null.
    .PARAMETER includeEdgeTypes
        When true, edge type labels are included on each arrow.
    .OUTPUTS
        Returns the Mermaid diagram as a string.
    #>
    static [string] RenderMermaid([PSScriptBuilderDependencyGraph] $graph, [bool] $includeEdgeTypes) {
        if ($null -eq $graph) {
            $message = "Parameter 'graph' cannot be null."
            throw [ArgumentNullException]::new("graph", $message)
        }

        $stringBuilder = [StringBuilder]::new()
        [void] $stringBuilder.AppendLine("graph TD")

        $hasEdges = $false

        foreach ($entry in $graph.Dependencies.GetEnumerator()) {
            $from = $entry.Key

            if ($entry.Value.Count -eq 0) {
                # Isolated node — no edges
                [void] $stringBuilder.AppendLine("    $from")
            }
            else {
                foreach ($edge in $entry.Value) {
                    $hasEdges = $true
                    $to       = $edge.Target

                    if ($includeEdgeTypes) {
                        $label = $edge.EdgeType.ToString()
                        [void] $stringBuilder.AppendLine("    $from -->|$label| $to")
                    }
                    else {
                        [void] $stringBuilder.AppendLine("    $from --> $to")
                    }
                }
            }
        }

        # If the graph has edges but some targets are not keys (no outgoing edges of their own),
        # they appear implicitly as targets — no extra lines needed for Mermaid.
        if (-not $hasEdges -and $graph.Dependencies.Count -eq 0) {
            [void] $stringBuilder.AppendLine("    %% No components found")
        }

        return $stringBuilder.ToString().TrimEnd()
    }

    <#
    .SYNOPSIS
        Renders the dependency graph as a Mermaid diagram wrapped in a Markdown fenced code block.
    .DESCRIPTION
        The RenderMermaidMarkdown method produces a complete, immediately renderable Markdown snippet
        by wrapping the Mermaid diagram in a fenced code block (```mermaid ... ```).
        This is suitable for writing directly to .md or .markdown files.
    .PARAMETER graph
        The dependency graph to render. Cannot be null.
    .PARAMETER includeEdgeTypes
        When true, edge type labels are included on each arrow.
    .OUTPUTS
        Returns the fenced Mermaid code block as a string.
    #>
    static [string] RenderMermaidMarkdown([PSScriptBuilderDependencyGraph] $graph, [bool] $includeEdgeTypes) {
        $diagram       = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($graph, $includeEdgeTypes)
        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine("``````mermaid")
        [void] $stringBuilder.AppendLine($diagram)
        [void] $stringBuilder.AppendLine("``````")

        return $stringBuilder.ToString()
    }

    <#
    .SYNOPSIS
        Renders the dependency graph as a Graphviz DOT diagram.
    .DESCRIPTION
        The RenderDot method converts the dependency graph to Graphviz DOT language syntax.
        The output is compatible with Graphviz tools and online viewers such as viz-js.com.

        Isolated nodes (no edges) are rendered as standalone node declarations.
        When includeEdgeTypes is true, each edge is annotated with a label attribute.
    .PARAMETER graph
        The dependency graph to render. Cannot be null.
    .PARAMETER includeEdgeTypes
        When true, edge type labels are included as DOT label attributes.
    .OUTPUTS
        Returns the DOT diagram as a string.
    #>
    static [string] RenderDot([PSScriptBuilderDependencyGraph] $graph, [bool] $includeEdgeTypes) {
        if ($null -eq $graph) {
            $message = "Parameter 'graph' cannot be null."
            throw [ArgumentNullException]::new("graph", $message)
        }

        $stringBuilder = [StringBuilder]::new()
        [void] $stringBuilder.AppendLine("digraph PSScriptBuilder {")

        foreach ($entry in $graph.Dependencies.GetEnumerator()) {
            $from = $entry.Key

            if ($entry.Value.Count -eq 0) {
                # Isolated node — no edges
                [void] $stringBuilder.AppendLine("    `"$from`"")
            }
            else {
                foreach ($edge in $entry.Value) {
                    $to = $edge.Target

                    if ($includeEdgeTypes) {
                        $label = $edge.EdgeType.ToString()
                        [void] $stringBuilder.AppendLine("    `"$from`" -> `"$to`" [label=`"$label`"]")
                    }
                    else {
                        [void] $stringBuilder.AppendLine("    `"$from`" -> `"$to`"")
                    }
                }
            }
        }

        if ($graph.Dependencies.Count -eq 0) {
            [void] $stringBuilder.AppendLine("    // No components found")
        }

        [void] $stringBuilder.Append("}")

        return $stringBuilder.ToString()
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderDependencyGraphRenderer
