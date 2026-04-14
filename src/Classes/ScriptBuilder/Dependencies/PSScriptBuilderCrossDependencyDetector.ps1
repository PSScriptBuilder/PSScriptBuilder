using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderCrossDependencyDetector
<#
.SYNOPSIS
    Detects cross-dependencies between component types in a sorted component list.
.DESCRIPTION
    The PSScriptBuilderCrossDependencyDetector analyzes a topologically sorted list of components to determine
    if classes and functions are intermixed in the dependency order. This indicates that some classes depend
    on functions or vice versa, which requires special handling during template processing.

    The detector examines the sequence of components and identifies transitions between component types
    (Class->Function or Function->Class), which signal the presence of cross-dependencies.
#>
class PSScriptBuilderCrossDependencyDetector {
    #region Properties
    <#
    .SYNOPSIS
        The content collector containing all component collectors.
    .DESCRIPTION
        The ContentCollector property provides access to all registered collectors, which is needed to
        determine which components are classes and which are functions.
    #>
    [PSScriptBuilderContentCollector] $ContentCollector
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderCrossDependencyDetector.
    .DESCRIPTION
        Creates a new cross-dependency detector for the specified content collector.
    .PARAMETER contentCollector
        The content collector containing all component collectors.
    #>
    PSScriptBuilderCrossDependencyDetector([PSScriptBuilderContentCollector] $contentCollector) {
        if ($null -eq $contentCollector) {
            $message = "The parameter 'contentCollector' cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        $this.ContentCollector = $contentCollector
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Determines if cross-dependencies exist between component types.
    .DESCRIPTION
        The HasCrossDependencies method analyzes a topologically sorted list of components to detect if
        classes and functions are intermixed in the dependency order. This indicates cross-dependencies
        between component types.
        
        Algorithm:
        1. Get all class names from ClassCollector
        2. Get all function names from FunctionCollector
        3. Track the last seen component type (None, Class, Function)
        4. Iterate through sorted components:
           - If component is a class and last type was Function -> cross-dependency detected
        5. Emit a single conclusion message (detected / not detected)
        6. Return true if cross-dependencies found, false otherwise
        
        Note: Enums are ignored as they never have dependencies.
        Note: Class -> Function is never a real dependency at load time; only Function -> Class
              transitions indicate genuine cross-dependencies.
    .PARAMETER orderedComponents
        The topologically sorted component names to analyze.
    .OUTPUTS
        Returns $true if cross-dependencies exist between classes and functions, $false otherwise.
    #>
    [bool] HasCrossDependencies([string[]] $orderedComponents) {
        Write-Verbose "Analyzing cross-dependencies..."

        if ($null -eq $orderedComponents -or $orderedComponents.Count -eq 0) {
            Write-Verbose "  No components to analyze"
            return $false
        }

        # Get all class and function names
        $classNames    = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $functionNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        $collectors = $this.ContentCollector.GetCollectors()

        foreach ($collector in $collectors) {
            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::ClassCollector) {
                    foreach ($className in $collector.ClassData.Keys) {
                        [void] $classNames.Add($className)
                    }
                }

                ([PSScriptBuilderCollectorType]::FunctionCollector) {
                    foreach ($functionName in $collector.FunctionData.Keys) {
                        [void] $functionNames.Add($functionName)
                    }
                }
            }
        }

        # Track last seen component type
        # 0 = None, 1 = Class, 2 = Function
        $lastType             = 0
        $hasCrossDependencies = $false

        foreach ($componentName in $orderedComponents) {
            if ($classNames.Contains($componentName)) {
                # Current component is a class
                if ($lastType -eq 2) {
                    # Last was a function, now a class -> cross-dependency
                    $hasCrossDependencies = $true
                }

                $lastType = 1
            }
            elseif ($functionNames.Contains($componentName)) {
                # Current component is a function
                # Note: Class -> Function is never a real dependency (classes cannot depend on functions
                # at load time via the type system). Only Function -> Class is a genuine cross-dependency.
                $lastType = 2
            }
            # Enums are ignored (no dependencies)
        }

        if ($hasCrossDependencies) {
            Write-Verbose "  Cross-dependencies detected -- all components must share a single template placeholder, in dependency order"
        } 
        else {
            Write-Verbose "  No cross-dependencies detected"
        }

        return $hasCrossDependencies
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderCrossDependencyDetector
