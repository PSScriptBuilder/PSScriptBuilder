# Export-PSScriptBuilderDependencyGraph

Exports the dependency graph to a visual diagram format.

## Description

Renders a `PSScriptBuilderDependencyGraph` as a diagram — every component as a node, every
dependency as an edge — in one of two formats:

- **Mermaid** (default): flowchart syntax that renders natively on GitHub, GitLab, and MkDocs,
  well suited to small and medium projects.
- **Dot**: Graphviz DOT language, rendered with the `dot` command-line tool or an online viewer.
  Handles hundreds of nodes far better than Mermaid, for larger projects.

When writing Mermaid output to a file with a `.md`/`.markdown` extension, the diagram is
automatically wrapped in a fenced `mermaid` code block, so the file renders immediately. Piped
output (no `-OutputPath`) always returns the raw diagram string, unwrapped.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-DependencyGraph` | `PSScriptBuilderDependencyGraph` | **Required.** The graph to export. Accepts pipeline input by property name, enabling direct piping from [`Get-PSScriptBuilderDependencyAnalysis`](Get-PSScriptBuilderDependencyAnalysis.md) (its `DependencyGraph` property). |
| `-Format` | string | `"Mermaid"` (default) or `"Dot"`. |
| `-OutputPath` | string | Path to write the diagram to. Omit to get the diagram string back on the pipeline instead. |
| `-IncludeEdgeTypes` | switch | Annotate each edge with its dependency type (`Inheritance`, `TypeReference`, `FunctionCall`, `StaticInitializer`). |
| `-Force` | switch | Overwrite `-OutputPath` if it already exists. Without it, an existing file causes an `IOException`. |

## Examples

### Generate an architecture diagram for code review

```powershell
$analysis | Export-PSScriptBuilderDependencyGraph -OutputPath '.\docs\architecture.md' -Force
```

The resulting file contains a fenced Mermaid code block that renders as an interactive diagram
on GitHub, GitLab, and MkDocs.

### Export to Graphviz for a large project

```powershell
$analysis | Export-PSScriptBuilderDependencyGraph -Format Dot -IncludeEdgeTypes -OutputPath '.\graph.dot'
```

```text title="Render with Graphviz"
dot -Tsvg graph.dot -o graph.svg
```

### Regenerate the diagram automatically on every build (CI)

```powershell
$analysis | Export-PSScriptBuilderDependencyGraph -OutputPath '.\docs\dependency-graph.md' -Force
```

Commit the generated file so pull request diffs show architecture changes alongside source
changes.

## Output

Returns the diagram as a `string` when `-OutputPath` is omitted; otherwise writes the file and
returns nothing.

## See Also

- [Dependency Analysis Guide: Architecture Overview for Code Review](../guides/dependency-analysis.md#architecture-overview-for-code-review)
- [Dependency Analysis Guide: Large Projects with Graphviz](../guides/dependency-analysis.md#large-projects-with-graphviz)
- [Cmdlet Reference: Get-PSScriptBuilderDependencyAnalysis](Get-PSScriptBuilderDependencyAnalysis.md)
