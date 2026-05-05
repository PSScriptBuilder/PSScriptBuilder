---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Export-PSScriptBuilderDependencyGraph

## SYNOPSIS
Exports the dependency graph to a visual diagram format.

## SYNTAX

```
Export-PSScriptBuilderDependencyGraph [-DependencyGraph] <PSScriptBuilderDependencyGraph> [[-Format] <String>]
 [[-OutputPath] <String>] [-IncludeEdgeTypes] [-Force]
 [<CommonParameters>]
```

## DESCRIPTION
The Export-PSScriptBuilderDependencyGraph cmdlet converts a PSScriptBuilderDependencyGraph
to a human-readable diagram for documentation and visualization purposes.

Supported output formats:

- Mermaid (default): flowchart syntax embeddable in Markdown files
- Dot: Graphviz DOT language, compatible with graphviz tools and online viewers

When -OutputPath is specified, the diagram is written to that file.
Otherwise, the
diagram string is returned to the pipeline.

The cmdlet accepts ValueFromPipelineByPropertyName, enabling direct piping from
Get-PSScriptBuilderDependencyAnalysis, which returns an object with a DependencyGraph property.

## EXAMPLES

### EXAMPLE 1
```
$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
$analysis | Export-PSScriptBuilderDependencyGraph
```

Exports the dependency graph as a Mermaid diagram to the pipeline.

### EXAMPLE 2
```
Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc |
    Export-PSScriptBuilderDependencyGraph -Format Dot -IncludeEdgeTypes -OutputPath ".\graph.dot"
```

Exports the dependency graph as a Graphviz DOT diagram with edge type labels to a file.

### EXAMPLE 3
```
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath ".\src\Classes" |
    Get-PSScriptBuilderDependencyAnalysis
```

$analysis | Export-PSScriptBuilderDependencyGraph -OutputPath ".\docs\dependency-graph.md"

Fluent pipeline: builds collector, analyzes dependencies, and exports Mermaid diagram.

### EXAMPLE 4
```
$cc | Get-PSScriptBuilderDependencyAnalysis |
    Export-PSScriptBuilderDependencyGraph -Format Dot -IncludeEdgeTypes -OutputPath '.\graph.dot'
# Render with: dot -Tsvg graph.dot -o graph.svg
```

Exports to Graphviz DOT format for large projects where Mermaid becomes hard to read.
Requires Graphviz (https://graphviz.org) or an online viewer such as https://viz-js.com.

### EXAMPLE 5
```
# In a CI/CD build script:
$cc | Get-PSScriptBuilderDependencyAnalysis |
    Export-PSScriptBuilderDependencyGraph -OutputPath '.\docs\dependency-graph.md' -Force
```

Automatically updates the architecture diagram on every build.
Use -Force to overwrite the existing file on each run.
The Mermaid diagram is immediately renderable on GitHub, GitLab, and MkDocs.

## PARAMETERS

### -DependencyGraph
The dependency graph to export.
Accepts pipeline input by property name, enabling
direct piping from Get-PSScriptBuilderDependencyAnalysis.

```yaml
Type: PSScriptBuilderDependencyGraph
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Format
The output format for the diagram.
Valid values are 'Mermaid' (default) and 'Dot'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Mermaid
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
The file path to write the diagram to.
If omitted, the diagram string is returned
to the pipeline instead.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeEdgeTypes
When specified, each edge in the diagram is annotated with its dependency type
(Inheritance, TypeReference, FunctionCall, StaticInitializer).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
When specified, overwrites an existing output file without prompting.
When omitted and the target file already exists, the cmdlet throws an IOException.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.String
## NOTES
The Mermaid format can be embedded in Markdown files and rendered by GitHub, GitLab,
MkDocs, and many other documentation tools.

When writing Mermaid output to a file with a .md or .markdown extension, the diagram is
automatically wrapped in a fenced code block (\`\`\`mermaid ...
\`\`\`) so the file is
immediately renderable.
This wrapping is handled by the renderer.
Pipeline output
(no -OutputPath) always returns the raw diagram string without the fenced block.

The Dot format requires Graphviz to render.
It can also be visualized online at
https://viz-js.com or https://dreampuf.github.io/GraphvizOnline.

Components with no dependencies are rendered as isolated nodes.

When -OutputPath is specified and the target file already exists, the cmdlet throws an
IOException unless -Force is present.
Use -Force in CI/CD scripts where the file is
intentionally overwritten on every run.

## RELATED LINKS
