using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderDependencyGraphBuilder
<#
.SYNOPSIS
    Builds a dependency graph from collected components.
.DESCRIPTION
    The PSScriptBuilderDependencyGraphBuilder analyzes all collectors (enums, classes, functions) and constructs 
    a complete dependency graph by extracting dependencies from ClassInfo and FunctionInfo objects.
#>
class PSScriptBuilderDependencyGraphBuilder {
    #region Properties
    <#
    .SYNOPSIS
        The content collector containing all component collectors.
    .DESCRIPTION
        Provides access to all registered collectors for dependency analysis.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The current dependency graph being built (build-time context).
    .DESCRIPTION
        The CurrentGraph property holds the dependency graph that is being constructed during the Build() method 
        execution.
        It is used by helper methods to add edges as dependencies are discovered.
    #>
    hidden [PSScriptBuilderDependencyGraph] $CurrentGraph

    <#
    .SYNOPSIS
        The set of defined component names (build-time context).
    .DESCRIPTION
        The CurrentDefinedComponents property holds a set of all component names defined in the project. 
        It is used to validate dependencies and ensure that edges are only added for components that exist in the 
        project. 
    #>
    hidden [HashSet[string]] $CurrentDefinedComponents

    <#
    .SYNOPSIS
        Counter for skipped external dependencies (build-time context).
    .DESCRIPTION
        The ExternalDependenciesSkipped property tracks the number of external dependencies that were encountered 
        but not added to the graph. External dependencies are references to types not defined in the project.
    #>
    hidden [int] $ExternalDependenciesSkipped
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderDependencyGraphBuilder.
    .DESCRIPTION
        Creates a new graph builder with the specified content collector.
    .PARAMETER contentCollector
        The content collector containing all component collectors.
    #>
    PSScriptBuilderDependencyGraphBuilder([PSScriptBuilderContentCollector] $contentCollector) {
        if ($null -eq $contentCollector) {
            $message = "ContentCollector cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        $this.ContentCollector = $contentCollector
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Builds a complete dependency graph from all collectors.
    .DESCRIPTION
        The Build() method orchestrates the graph construction by iterating through all registered collectors, 
        extracting dependencies from class and function definitions, and adding edges to the graph for valid 
        dependencies.
        It uses helper methods to handle different dependency types and maintains build-time context to ensure 
        that only valid edges are added.
    .OUTPUTS
        Returns a PSScriptBuilderDependencyGraph with all dependencies.
    #>
    [PSScriptBuilderDependencyGraph] Build() {
        Write-Verbose "Building dependency graph..."

        # Initialize build-time context
        $this.CurrentGraph = [PSScriptBuilderDependencyGraph]::new()
        $this.CurrentDefinedComponents = $this.ContentCollector.GetDefinedComponentNames()
        $this.ExternalDependenciesSkipped = 0

        Write-Verbose "  Validating against $($this.CurrentDefinedComponents.Count) defined component(s)"

        $collectors = $this.ContentCollector.GetCollectors()

        foreach ($collector in $collectors) {
            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::ClassCollector)    { $this.ProcessClassDependencies($collector)    }
                ([PSScriptBuilderCollectorType]::FunctionCollector) { $this.ProcessFunctionDependencies($collector) }
            }
        }

        # Ensure all defined components are registered as nodes, including isolated ones with no edges
        foreach ($componentName in $this.CurrentDefinedComponents) {
            $this.CurrentGraph.AddNode($componentName)
        }

        # Query graph statistics after all processing complete
        $totalNodes      = $this.CurrentGraph.GetAllNodes().Count
        $totalEdges      = $this.CurrentGraph.GetEdgeCount()
        $externalSkipped = $this.ExternalDependenciesSkipped

        $format  = "Dependency graph complete: {0} node(s), {1} edge(s), {2} external dependencies skipped"
        $message = [string]::Format($format, $totalNodes, $totalEdges, $externalSkipped)
        Write-Verbose $message

        return $this.CurrentGraph
    }

    #region Helper Methods
    <#
    .SYNOPSIS
        Attempts to add an edge to the graph if the target component is defined.
    .DESCRIPTION
        The TryAddEdge() method validates and adds a dependency edge to the graph. It performs several checks:
        1. Validates that $to is not null or empty
        2. Skips self-loops (component referencing itself)
        3. Skips external dependencies (components not defined in this project)
        4. Skips duplicate edges (edge already exists in graph)
        
        If all checks pass, it adds an edge in natural dependency direction: from $from to $to. This means
        the dependent ($from) points to its prerequisite ($to), matching standard graph convention.
        
        Example: If ClassA depends on ClassB, the method adds edge: ClassA -> ClassB
    .PARAMETER from
        The dependent component name (depends on $to).
    .PARAMETER to
        The prerequisite component name (required by $from).
    .PARAMETER edgeType
        The type of dependency relationship.
    .OUTPUTS
        Returns $true if edge was added, $false if skipped (null, self-loop, external, or duplicate).
    #>
    hidden [bool] TryAddEdge([string] $from, [string] $to, [PSScriptBuilderDependencyEdgeType] $edgeType) {
        if ([string]::IsNullOrWhiteSpace($to)) {
            return $false
        }

        # Skip self-loops (component referencing itself)
        # This is common for static method calls within the same class
        if ($from.ToLower() -eq $to.ToLower()) {
            return $false
        }

        if (-not $this.CurrentDefinedComponents.Contains($to)) {
            $this.ExternalDependenciesSkipped++
            return $false
        }

        # Check if edge already exists (avoid duplicate verbose output)
        if ($this.CurrentGraph.Dependencies.ContainsKey($from)) {
            $exists = $false

            foreach ($edge in $this.CurrentGraph.Dependencies[$from]) {
                if ($edge.Target -eq $to -and $edge.EdgeType -eq $edgeType) {
                    $exists = $true
                    break
                }
            }

            if ($exists) { return $false }
        }

        # Skip weaker edges if a stronger inheritance edge to the same target already exists
        $isWeakerEdge = 
            $edgeType -eq [PSScriptBuilderDependencyEdgeType]::TypeReference -or
            $edgeType -eq [PSScriptBuilderDependencyEdgeType]::StaticInitializer

        if ($isWeakerEdge -and $this.HasInheritanceEdge($from, $to)) { return $false }

        # Resolve human-readable label for verbose output
        $label = switch ($edgeType) {
            ([PSScriptBuilderDependencyEdgeType]::Inheritance)       { 'base class'         }
            ([PSScriptBuilderDependencyEdgeType]::TypeReference)     { 'type reference'     }
            ([PSScriptBuilderDependencyEdgeType]::FunctionCall)      { 'function call'      }
            ([PSScriptBuilderDependencyEdgeType]::StaticInitializer) { 'static initializer' }
        }

        # Add typed edge in natural direction: dependent -> prerequisite
        $this.CurrentGraph.AddEdge($from, $to, $edgeType)
        Write-Verbose "      $from --[$label]--> $to"
        return $true
    }

    <#
    .SYNOPSIS
        Determines whether an inheritance edge from $from to $to already exists in the graph.
    .DESCRIPTION
        The HasInheritanceEdge() method checks whether a direct Inheritance edge from the specified
        source component to the target component exists in the current dependency graph. It is used
        by TryAddEdge() to suppress weaker edges (TypeReference, StaticInitializer) when an
        Inheritance edge to the same target already exists.
    .PARAMETER from
        The dependent component name.
    .PARAMETER to
        The prerequisite component name.
    .OUTPUTS
        Returns $true if an Inheritance edge from $from to $to exists, $false otherwise.
    #>
    hidden [bool] HasInheritanceEdge([string] $from, [string] $to) {
        if (-not $this.CurrentGraph.Dependencies.ContainsKey($from)) {
            return $false
        }

        foreach ($edge in $this.CurrentGraph.Dependencies[$from]) {
            if ($edge.Target -eq $to -and $edge.EdgeType -eq [PSScriptBuilderDependencyEdgeType]::Inheritance) {
                return $true
            }
        }

        return $false
    }

    <#
    .SYNOPSIS
        Adds edges for type references.
    .DESCRIPTION
        The AddTypeReferenceEdges() method takes a component name and an array of type reference names. 
        It iterates through the type references and uses TryAddEdge() to add an edge for each one that is 
        defined in the project. 
        This method is used by both class and function dependency processing to handle dependencies on types 
        referenced in definitions and bodies.
    .PARAMETER componentName
        The name of the component that has the type references.
    .PARAMETER typeReferences
        Array of type reference names.
    #>
    hidden [void] AddTypeReferenceEdges([string] $componentName, [string[]] $typeReferences) {
        foreach ($typeReference in $typeReferences) {
            $this.TryAddEdge($componentName, $typeReference, [PSScriptBuilderDependencyEdgeType]::TypeReference) | Out-Null
        }
    }

    <#
    .SYNOPSIS
        Adds edges for static property initializer type references.
    .DESCRIPTION
        The AddStaticInitializerEdges() method takes a component name and an array of type names referenced
        in static property initializer expressions. It adds a StaticInitializer edge for each type that is
        defined in the project. StaticInitializer edges carry the same ordering weight as Inheritance edges:
        the referenced type must be emitted before this class in the output script.
    .PARAMETER componentName
        The name of the class that contains the static property initializers.
    .PARAMETER staticInitReferences
        Array of type names referenced in static property initializer expressions.
    #>
    hidden [void] AddStaticInitializerEdges([string] $componentName, [string[]] $staticInitReferences) {
        foreach ($typeReference in $staticInitReferences) {
            $this.TryAddEdge($componentName, $typeReference, [PSScriptBuilderDependencyEdgeType]::StaticInitializer) | Out-Null
        }
    }

    <#
    .SYNOPSIS
        Processes dependencies from a class collector.
    .DESCRIPTION
        The ProcessClassDependencies() method takes a class collector and iterates through all class definitions. 
        For each class, it attempts to add an edge for the base class (if defined) and then adds edges for any 
        type references found in the class definition.
        This method focuses on extracting dependencies related to class inheritance and type usage within class 
        definitions.
    .PARAMETER collector
        The class collector to process.
    #>
    hidden [void] ProcessClassDependencies([PSScriptBuilderClassCollector] $collector) {
        $classCount = $collector.ClassData.Count
        Write-Verbose "    Analyzing $classCount class(es) from collector with key '$($collector.CollectionKey)'..."

        foreach ($classData in $collector.ClassData.Values) {
            $className = $classData.Name

            # Add edge for base class (only if defined in project)
            if (-not [string]::IsNullOrWhiteSpace($classData.BaseClass)) {
                if (-not $this.TryAddEdge($className, $classData.BaseClass, [PSScriptBuilderDependencyEdgeType]::Inheritance)) {
                    Write-Verbose "      $className -> $($classData.BaseClass) (external, skipped)"
                }
            }

            # Add edges for type references
            $this.AddTypeReferenceEdges($className, $classData.TypeReferences)

            # Add edges for static property initializer references (load-time ordering constraint)
            $this.AddStaticInitializerEdges($className, $classData.StaticInitializerReferences)

            # Add edges for called functions (e.g. static property initializers)
            foreach ($calledFunction in $classData.CalledFunctions) {
                $this.TryAddEdge($className, $calledFunction, [PSScriptBuilderDependencyEdgeType]::FunctionCall) | Out-Null
            }
        }
    }

    <#
    .SYNOPSIS
        Processes dependencies from a function collector.
    .DESCRIPTION
        The ProcessFunctionDependencies() method takes a function collector and iterates through all function 
        definitions. For each function, it adds edges for any called functions and type references found in the 
        function definition.
    .PARAMETER collector
        The function collector to process.
    #>
    hidden [void] ProcessFunctionDependencies([PSScriptBuilderFunctionCollector] $collector) {
        $functionCount = $collector.FunctionData.Count

        Write-Verbose "    Analyzing $functionCount function(s) from collector with key '$($collector.CollectionKey)'..."

        foreach ($functionData in $collector.FunctionData.Values) {
            $functionName = $functionData.Name

            # Add edges for called functions
            foreach ($calledFunction in $functionData.CalledFunctions) {
                $this.TryAddEdge($functionName, $calledFunction, [PSScriptBuilderDependencyEdgeType]::FunctionCall) | Out-Null
            }

            # Add edges for type references
            $this.AddTypeReferenceEdges($functionName, $functionData.TypeReferences)
        }
    }

    #endregion Helper Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderDependencyGraphBuilder
