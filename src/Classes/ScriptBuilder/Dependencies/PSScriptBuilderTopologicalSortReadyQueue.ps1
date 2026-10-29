using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderTopologicalSortReadyQueue
<#
.SYNOPSIS
    A tie-break-aware priority queue for nodes that are ready to be processed by Kahn's algorithm.
.DESCRIPTION
    The PSScriptBuilderTopologicalSortReadyQueue groups the structures needed to break ties
    deterministically among simultaneously-ready nodes with no dependency path between them
    (RFC 0017), so the routing/priority decision lives in one place instead of being duplicated
    between where a node is added and where it is dequeued.

    A Function is preferred over a Class when both are ready, and ties within the same type are
    broken by alphabetically-later name first. Both preferences are the OPPOSITE of the desired
    final order, because PSScriptBuilderTopologicalSorter reverses the dependents-first list this
    queue helps produce - see PSScriptBuilderTopologicalSorter.RunKahnsAlgorithm for the full
    reasoning. Nodes with no entry in the supplied node-type map (e.g. enums, or when the map
    itself is $null) fall back to plain arrival order.
#>
class PSScriptBuilderTopologicalSortReadyQueue {
    #region Properties
    <#
    .SYNOPSIS
        Ready Function-typed nodes, sorted alphabetically for deterministic tie-breaking.
    #>
    hidden [SortedSet[string]] $Functions

    <#
    .SYNOPSIS
        Ready Class-typed nodes, sorted alphabetically for deterministic tie-breaking.
    #>
    hidden [SortedSet[string]] $Classes

    <#
    .SYNOPSIS
        Ready nodes with no entry in NodeTypes (e.g. enums), in plain FIFO arrival order.
    #>
    hidden [Queue[string]] $Other

    <#
    .SYNOPSIS
        Optional node name -> collector type map, used to route a node to the right structure.
    #>
    hidden [Dictionary[string, PSScriptBuilderCollectorType]] $NodeTypes
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderTopologicalSortReadyQueue.
    .PARAMETER nodeTypes
        Maps component names to their PSScriptBuilderCollectorType. May be $null, in which case
        every node falls back to plain arrival order.
    #>
    PSScriptBuilderTopologicalSortReadyQueue([Dictionary[string, PSScriptBuilderCollectorType]] $nodeTypes) {
        $this.Functions = [SortedSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $this.Classes   = [SortedSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $this.Other     = [Queue[string]]::new()
        $this.NodeTypes = $nodeTypes
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Returns the total number of nodes currently waiting in this queue.
    #>
    [int] Count() {
        return $this.Functions.Count + $this.Classes.Count + $this.Other.Count
    }

    <#
    .SYNOPSIS
        Adds a newly-ready node, routed to the structure matching its component type.
    .DESCRIPTION
        Looks up the node's type in NodeTypes and routes it to the matching structure: Functions
        and Classes go to their respective SortedSet (broken by alphabetical order on dequeue),
        everything else (no NodeTypes entry, or NodeTypes itself $null) goes to the FIFO fallback
        queue, preserving plain arrival-order behavior for those.
    .PARAMETER node
        The node name that just became ready (in-degree reached 0).
    #>
    [void] Add([string] $node) {
        $nodeType = $null

        if ($null -ne $this.NodeTypes -and $this.NodeTypes.ContainsKey($node)) {
            $nodeType = $this.NodeTypes[$node]
        }

        if ($nodeType -eq [PSScriptBuilderCollectorType]::FunctionCollector) {
            [void] $this.Functions.Add($node)
        }
        elseif ($nodeType -eq [PSScriptBuilderCollectorType]::ClassCollector) {
            [void] $this.Classes.Add($node)
        }
        else {
            $this.Other.Enqueue($node)
        }
    }

    <#
    .SYNOPSIS
        Removes and returns the next node to process, per the tie-break priority.
    .DESCRIPTION
        Prefers a ready Function (alphabetically latest first) over a ready Class (alphabetically
        latest first) over the FIFO fallback queue. Callers must check Count() first - Dequeue()
        throws if every structure is empty.
    #>
    [string] Dequeue() {
        if ($this.Functions.Count -gt 0) {
            $node = $this.Functions.Max
            [void] $this.Functions.Remove($node)
            return $node
        }

        if ($this.Classes.Count -gt 0) {
            $node = $this.Classes.Max
            [void] $this.Classes.Remove($node)
            return $node
        }

        return $this.Other.Dequeue()
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderTopologicalSortReadyQueue
