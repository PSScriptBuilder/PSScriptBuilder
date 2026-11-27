using namespace System
using namespace System.Collections.Generic
using namespace System.Text

#region Class PSScriptBuilderComponentDependencyRenderer
<#
.SYNOPSIS
    Renders PSScriptBuilderComponentDependencyEntry results as a hierarchical tree.
.DESCRIPTION
    The PSScriptBuilderComponentDependencyRenderer class converts an array of
    PSScriptBuilderComponentDependencyEntry objects (as returned by
    PSScriptBuilderDependencyGraphTraverser) to a hierarchical tree diagram using
    Unicode box-drawing characters.

    All methods are static - no instance is required.
    This class is the backing implementation for Format-PSScriptBuilderComponentDependencies.
#>
class PSScriptBuilderComponentDependencyRenderer {
    #region Methods
    <#
    .SYNOPSIS
        Renders the entries as a hierarchical tree.
    .DESCRIPTION
        The RenderTree() method produces a tree diagram using Unicode box-drawing characters.
        The traversal root is shown as the top-level node. Children are indented and connected
        with corner, branch, and vertical bar characters. Children at each level are sorted alphabetically.

        The root name is derived from the first element of DependencyPath in the first entry.

        Returns a placeholder message when the entries array is empty or null.
    .PARAMETER entries
        The dependency entries to render.
    .OUTPUTS
        Returns the formatted tree as a string.
    #>
    static [string] RenderTree([PSScriptBuilderComponentDependencyEntry[]] $entries) {
        if ($null -eq $entries -or $entries.Length -eq 0) {
            return "  (no components found)"
        }

        $rootName    = $entries[0].DependencyPath[0]
        $childrenMap = [Dictionary[string, List[string]]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($entry in $entries) {
            $parent = $entry.DependencyPath[$entry.DependencyPath.Length - 2]

            if (-not $childrenMap.ContainsKey($parent)) {
                $childrenMap[$parent] = [List[string]]::new()
            }

            $childrenMap[$parent].Add($entry.Name)
        }

        $stringBuilder = [StringBuilder]::new()
        [void] $stringBuilder.AppendLine($rootName)

        if ($childrenMap.ContainsKey($rootName)) {
            $children = @($childrenMap[$rootName] | Sort-Object)

            for ($i = 0; $i -lt $children.Count; $i++) {
                $isLast = $i -eq ($children.Count - 1)
                [PSScriptBuilderComponentDependencyRenderer]::RenderTreeNode(
                    $children[$i], '', $isLast, $childrenMap, $stringBuilder
                )
            }
        }

        return $stringBuilder.ToString().TrimEnd()
    }

    <#
    .SYNOPSIS
        Recursively renders a single tree node and its children.
    .DESCRIPTION
        The RenderTreeNode() method appends one node to the StringBuilder with the correct
        prefix and connector character (corner or branch). It then recurses into child nodes,
        extending the prefix with a vertical bar (for non-last nodes) or spaces (for last nodes).
    .PARAMETER node
        The component name to render.
    .PARAMETER prefix
        The accumulated indentation prefix from parent levels.
    .PARAMETER isLast
        True if this node is the last child of its parent.
    .PARAMETER childrenMap
        Map of parent name to sorted list of child names.
    .PARAMETER stringBuilder
        The StringBuilder to append output to.
    #>
    hidden static [void] RenderTreeNode(
        [string]                           $node,
        [string]                           $prefix,
        [bool]                             $isLast,
        [Dictionary[string, List[string]]] $childrenMap,
        [StringBuilder]                    $stringBuilder
    ) {
        $treeCorner   = [string]([char] 9492) + [string]([char] 9472) + [string]([char] 9472) + ' '
        $treeBranch   = [string]([char] 9500) + [string]([char] 9472) + [string]([char] 9472) + ' '
        $treeVertical = [string]([char] 9474) + '   '

        $connector   = if ($isLast) { $treeCorner }      else { $treeBranch }
        $childPrefix = if ($isLast) { $prefix + '    ' } else { $prefix + $treeVertical }

        [void] $stringBuilder.AppendLine("$prefix$connector$node")

        if ($childrenMap.ContainsKey($node)) {
            $children = @($childrenMap[$node] | Sort-Object)

            for ($i = 0; $i -lt $children.Count; $i++) {
                $isChildLast = $i -eq ($children.Count - 1)
                [PSScriptBuilderComponentDependencyRenderer]::RenderTreeNode(
                    $children[$i], $childPrefix, $isChildLast, $childrenMap, $stringBuilder
                )
            }
        }
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderComponentDependencyRenderer
