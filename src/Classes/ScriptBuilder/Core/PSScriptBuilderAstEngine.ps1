using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation.Language

#region Class PSScriptBuilderAstEngine
<#
.SYNOPSIS
    Static utility class for PowerShell AST parsing and analysis.
.DESCRIPTION
    The PSScriptBuilderAstEngine class provides static methods for parsing PowerShell files, navigating 
    AST structures, analyzing dependencies, and extracting source code.
    Designed for PowerShell 5.1 compatibility.
#>
class PSScriptBuilderAstEngine {
    #region Properties
    <#
    .SYNOPSIS
        Parse error IDs that are never structural.
    .DESCRIPTION
        Parse errors with these IDs cannot cause definitions to disappear from the AST and are
        therefore excluded from structural error detection in GetStructuralParseErrors.

        Currently contains:
        - TypeNotFound: emitted when a referenced type is defined in a separate file and cannot
          be resolved during isolated file parsing. Expected in every multi-file project.

        To discover new IDs: when a false positive occurs, the exception message thrown by
        ThrowIfParseFailedSilently includes the ErrorId in brackets, e.g. [TypeNotFound].
        Before adding a new ID here, verify that the error cannot cause definitions to
        disappear from the AST - only add IDs that have been confirmed non-structural.
    #>
    static hidden [string[]] $NonStructuralParseErrorIds = @('TypeNotFound')

    <#
    .SYNOPSIS
        Set of built-in type names for O(1) lookup in IsBuiltInType().
    .DESCRIPTION
        Initialized once when the class is loaded. Uses OrdinalIgnoreCase because PowerShell
        type names are always ASCII, making ordinal and invariant-culture comparison identical.
    #>
    static hidden [HashSet[string]] $BuiltInTypeNames = [HashSet[string]]::new(
        [string[]] @(
            # Primitives
            'string', 'int', 'int32', 'int64', 'uint32', 'uint64',
            'long', 'ulong', 'short', 'ushort',
            'byte', 'sbyte', 'double', 'float', 'single', 'decimal',
            'bool', 'boolean', 'char',

            # Common Objects
            'object', 'array', 'hashtable',
            'psobject', 'pscustomobject',

            # Time/Date
            'datetime', 'timespan', 'datetimeoffset',

            # Other
            'void', 'guid', 'uri', 'version',
            'scriptblock', 'regex', 'switch',
            'mailaddress', 'ipaddress',
            'securestring', 'pscredential',
            'xml', 'xmldocument', 'xmlelement'
        ),
        [StringComparer]::OrdinalIgnoreCase
    )
    #endregion Properties

    #region Methods
    #region Parsing
    <#
    .SYNOPSIS
        Parses a PowerShell file and returns the parse result.
    .DESCRIPTION
        Parses the specified PowerShell file using the PowerShell parser and returns a
        PSScriptBuilderParseResult containing both the ScriptBlockAst and any parse errors.

        Parse errors are not evaluated here - callers are responsible for determining whether
        errors are significant. A common pattern is to check whether definitions were collected
        from the AST: if none were found but parse errors are present, the errors likely caused
        definitions to be silently dropped.
    .PARAMETER path
        The absolute path to the PowerShell file to parse.
    .OUTPUTS
        PSScriptBuilderParseResult containing the AST and any parse errors.
    #>
    static [PSScriptBuilderParseResult] ParseFile([string] $path) {
        if (-not (Test-Path $path -PathType Leaf)) {
            throw [FileNotFoundException]::new("File not found: $path")
        }

        $parseErrors = $null
        $tokens      = $null

        try {
            $ast = [Parser]::ParseFile($path, [ref] $tokens, [ref] $parseErrors)
        }
        catch {
            $message = "Failed to parse file: $path. Error: $($_.Exception.Message)"
            throw [InvalidOperationException]::new($message, $_.Exception)
        }

        # Fatal error: no AST created
        if ($null -eq $ast) {
            $message = "Failed to create AST from file: $path"
            throw [InvalidOperationException]::new($message)
        }

        # Wrap in @() to guarantee an array - a single parse error would otherwise be unwrapped to a scalar
        $errors = @(if ($null -ne $parseErrors) { $parseErrors })
        return [PSScriptBuilderParseResult]::new($ast, $errors)
    }

    <#
    .SYNOPSIS
        Filters parse errors to only structural errors.
    .DESCRIPTION
        Returns only the parse errors that indicate genuine structural problems, excluding errors
        that are always caused by unresolved cross-file type references.

        Cross-file reference errors (e.g. TypeNotFound) are expected when files are parsed in
        isolation - the referenced type is defined in a separate file and is only available at
        runtime. These errors cannot cause definitions to disappear from the AST and are therefore
        not structural.
    .PARAMETER parseErrors
        The parse errors returned by ParseFile.
    .OUTPUTS
        An array containing only the structural parse errors. Returns an empty array if there are
        none or if the input is null.
    #>
    static [ParseError[]] GetStructuralParseErrors([ParseError[]] $parseErrors) {
        if ($null -eq $parseErrors -or $parseErrors.Count -eq 0) {
            return @()
        }

        $nonStructuralIds = [PSScriptBuilderAstEngine]::NonStructuralParseErrorIds

        return @($parseErrors | Where-Object { $nonStructuralIds -notcontains $_.ErrorId })
    }
    #endregion Parsing

    #region AST Navigation
    <#
    .SYNOPSIS
        Finds all using statements in the AST.
    .DESCRIPTION
        Searches the AST for all UsingStatementAst nodes.
    .PARAMETER ast
        The ScriptBlockAst to search.
    .OUTPUTS
        An array of UsingStatementAst nodes representing the using statements found in the AST.
    #>
    static [UsingStatementAst[]] FindUsingStatements([ScriptBlockAst] $ast) {
        $predicate = {
            $args[0] -is [UsingStatementAst]
        }

        return $ast.FindAll($predicate, $true)
    }

    <#
    .SYNOPSIS
        Finds all top-level enum definitions in the AST.
    .DESCRIPTION
        Searches the AST for all TypeDefinitionAst nodes that represent enums, excluding nested enums 
        (only top-level enums are returned).
    .PARAMETER ast
        The ScriptBlockAst to search.
    .OUTPUTS
        An array of TypeDefinitionAst nodes representing the top-level enums found in the AST.
    #>
    static [TypeDefinitionAst[]] FindEnumDefinitions([ScriptBlockAst] $ast) {
        $predicate = {
            (      $args[0]        -is [TypeDefinitionAst]) -and 
                   $args[0].IsEnum                          -and
            (-not ($args[0].Parent -is [TypeDefinitionAst]))
        }

        return $ast.FindAll($predicate, $true)
    }

    <#
    .SYNOPSIS
        Finds all top-level class definitions in the AST.
    .DESCRIPTION
        Searches the AST for all TypeDefinitionAst nodes that represent classes, excluding nested classes 
        (only top-level classes are returned).
    .PARAMETER ast
        The ScriptBlockAst to search.
    .OUTPUTS
        An array of TypeDefinitionAst nodes representing the top-level classes found in the AST.
    #>
    static [TypeDefinitionAst[]] FindClassDefinitions([ScriptBlockAst] $ast) {
        $predicate = {
            (      $args[0]        -is [TypeDefinitionAst]) -and 
                   $args[0].IsClass                         -and 
            (-not ($args[0].Parent -is [TypeDefinitionAst]))
        }

        return $ast.FindAll($predicate, $true)
    }

    <#
    .SYNOPSIS
        Finds standalone function definitions in the AST.
    .DESCRIPTION
        Searches the AST for FunctionDefinitionAst nodes that are NOT methods within a class.
        This filters out class methods and returns only top-level functions and cmdlets.
    .PARAMETER ast
        The ScriptBlockAst to search.
    .OUTPUTS
        An array of FunctionDefinitionAst nodes representing standalone functions.
    #>
    static [FunctionDefinitionAst[]] FindFunctionDefinitions([ScriptBlockAst] $ast) {
        $predicate = { 
            param($node)

            if ($node -isnot [FunctionDefinitionAst]) {
                return $false
            }

            # Check if this function is inside a class (has TypeDefinitionAst as ancestor)
            $parent = $node.Parent

            while ($null -ne $parent) {
                if ($parent -is [TypeDefinitionAst]) {
                    # It's a class method, exclude it
                    return $false
                }

                $parent = $parent.Parent
            }

            # It's a standalone function
            return $true
        }

        return $ast.FindAll($predicate, $true)
    }
    #endregion AST Navigation

    #region Dependency Analysis
    <#
    .SYNOPSIS
        Extracts all type references from the AST, excluding static property initializer expressions.
    .DESCRIPTION
        Analyzes the AST and extracts all referenced types including:
        - Type constraints (properties, parameters, return types)
        - Type expressions (constructors, static calls)
        - Convert expressions (casts)
        - Binary expressions (-is, -as operators)
        - Catch clause exception types
        - Generic type parameters

        When the AST is a class definition, type references that originate exclusively from
        static property initializer expressions are excluded. Those references are captured
        separately by GetStaticInitializerTypeReferences().

        Note: the type annotation of a static property (e.g. [B] in 'static [B] $x = ...') is
        NOT inside the InitialValue extent and is therefore still included in the result.
    .PARAMETER ast
        The AST to analyze.
    .OUTPUTS
        An array of unique type names referenced in the AST.
    #>
    static [string[]] GetTypeReferences([Ast] $ast) {
        $types = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        # Build extent-exclusion list: collect extents of entire static property members
        # (including type annotations and initializer expressions).
        # Only TypeDefinitionAst nodes representing classes can have static property initializers.
        # For all other AST types the list stays empty and IsInsideAnyExtent always returns false.
        $initExtents = [List[IScriptExtent]]::new()

        if ($ast -is [TypeDefinitionAst] -and $ast.IsClass) {
            foreach ($member in $ast.Members) {
                if ($member -is [PropertyMemberAst] -and $member.IsStatic -and $null -ne $member.InitialValue) {
                    $initExtents.Add($member.Extent)
                }
            }
        }

        # 1. TypeConstraintAst (Properties, Parameters, Returns, Variables)
        $predicate = { 
            $args[0] -is [TypeConstraintAst] 
        }

        $typeConstraints = $ast.FindAll($predicate, $true)

        foreach ($typeConstraint in $typeConstraints) {
            if ([PSScriptBuilderAstEngine]::IsInsideAnyExtent($typeConstraint, $initExtents)) { continue }

            $extractedTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($typeConstraint.TypeName)

            foreach ($extractedType in $extractedTypes) {
                $types.Add($extractedType) | Out-Null
            }
        }

        # 2. TypeExpressionAst (Constructors, Static Calls, Type literals)
        $predicate = { 
            $args[0] -is [TypeExpressionAst] 
        }

        $typeExpressions = $ast.FindAll($predicate, $true)

        foreach ($typeExpression in $typeExpressions) {
            if ([PSScriptBuilderAstEngine]::IsInsideAnyExtent($typeExpression, $initExtents)) { continue }

            $extractedTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($typeExpression.TypeName)

            foreach ($extractedType in $extractedTypes) {
                $types.Add($extractedType) | Out-Null
            }
        }

        # 3. ConvertExpressionAst (Casts: [Type] $var)
        $predicate = { 
            $args[0] -is [ConvertExpressionAst] 
        }

        $converts = $ast.FindAll($predicate, $true)

        foreach ($convert in $converts) {
            if ([PSScriptBuilderAstEngine]::IsInsideAnyExtent($convert, $initExtents)) { continue }

            if ($convert.Type -and $convert.Type.TypeName) {
                $extractedTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($convert.Type.TypeName)

                foreach ($extractedType in $extractedTypes) {
                    $types.Add($extractedType) | Out-Null
                }
            }
        }

        # 4. BinaryExpressionAst (-is, -as operators)
        $predicate = { 
            ($args[0]          -is [BinaryExpressionAst]) -and 
            ($args[0].Operator -in ([TokenKind]::Is, [TokenKind]::As))
        }

        $binaryOps = $ast.FindAll($predicate, $true)

        foreach ($binaryOp in $binaryOps) {
            if ([PSScriptBuilderAstEngine]::IsInsideAnyExtent($binaryOp, $initExtents)) { continue }

            if ($binaryOp.Right -is [TypeExpressionAst] -and $binaryOp.Right.TypeName) {
                $extractedTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($binaryOp.Right.TypeName)

                foreach ($extractedType in $extractedTypes) {
                    $types.Add($extractedType) | Out-Null
                }
            }
        }

        # 5. CatchClauseAst (Exception types)
        $predicate = { 
            $args[0] -is [CatchClauseAst] 
        }

        $catchClauses = $ast.FindAll($predicate, $true)

        foreach ($catchClause in $catchClauses) {
            if ([PSScriptBuilderAstEngine]::IsInsideAnyExtent($catchClause, $initExtents)) { continue }

            if ($catchClause.CatchTypes) {
                foreach ($catchType in $catchClause.CatchTypes) {
                    if ($catchType.TypeName) {
                        $extractedTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($catchType.TypeName)

                        foreach ($extractedType in $extractedTypes) {
                            $types.Add($extractedType) | Out-Null
                        }
                    }
                }
            }
        }

        # 6. ParameterAst with TypeConstraint attributes (Method parameters, especially static methods)
        # Note: TypeConstraintAst from #1 should already cover most parameters, but we explicitly
        # check ParameterAst to ensure static method parameters are not missed
        $predicate = { 
            $args[0] -is [ParameterAst] 
        }

        $parameters = $ast.FindAll($predicate, $true)

        foreach ($parameter in $parameters) {
            if ([PSScriptBuilderAstEngine]::IsInsideAnyExtent($parameter, $initExtents)) { continue }

            foreach ($attribute in $parameter.Attributes) {
                if ($attribute -is [TypeConstraintAst] -and $attribute.TypeName) {
                    $extractedTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($attribute.TypeName)

                    foreach ($extractedType in $extractedTypes) {
                        $types.Add($extractedType) | Out-Null
                    }
                }
            }
        }

        return @($types)
    }

    <#
    .SYNOPSIS
        Extracts type references from static property initializer expressions.
    .DESCRIPTION
        Analyzes a class AST and extracts all type references that appear inside static property
        initializer expressions (the right-hand side of 'static [T] $x = <expression>').
        These type references represent load-time ordering constraints: the referenced type must
        be defined before the class that uses it in a static initializer, because static property
        initializers are executed when the .psm1 file is loaded.

        Only static properties with an initializer expression are processed. Static properties
        without an initializer and instance properties are ignored.

        Note: The type annotation of the property itself (e.g. [B] in 'static [B] $x = ...')
        is NOT included in this result, and is also excluded from GetTypeReferences() - the
        entire static property member (annotation + initializer) is treated as a single
        load-time constraint unit. The initializer expression ([B]::new()) IS included.
    .PARAMETER classAst
        The TypeDefinitionAst representing the class to analyze.
    .OUTPUTS
        An array of unique type names referenced in static property initializer expressions.
    #>
    static [string[]] GetStaticInitializerTypeReferences([TypeDefinitionAst] $classAst) {
        $types = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($member in $classAst.Members) {
            if ($member -isnot [PropertyMemberAst]) { continue }
            if (-not $member.IsStatic)              { continue }
            if ($null -eq $member.InitialValue)     { continue }

            # Reuse GetTypeReferences scoped to the InitialValue expression.
            # InitialValue is an ExpressionAst (not a TypeDefinitionAst), so the extent-exclusion
            # branch inside GetTypeReferences will not trigger - no recursion risk.
            $initTypes = [PSScriptBuilderAstEngine]::GetTypeReferences($member.InitialValue)

            foreach ($initType in $initTypes) {
                $types.Add($initType) | Out-Null
            }
        }

        return @($types)
    }

    <#
    .SYNOPSIS
        Gets the base class of a class definition.
    .DESCRIPTION
        Extracts the base class (if any) from a TypeDefinitionAst representing a class.
        PowerShell only supports single inheritance, so at most one base class is returned.
    .PARAMETER class
        The TypeDefinitionAst representing the class.
    .OUTPUTS
        An array containing the name of the base class, or an empty array if there is no base class.
    #>
    static [string[]] GetBaseClasses([TypeDefinitionAst] $class) {
        if ($class.BaseTypes -and $class.BaseTypes.Count -gt 0) {
            $baseTypeName = $class.BaseTypes[0].TypeName.Name
            return @($baseTypeName)
        }

        return @()
    }

    <#
    .SYNOPSIS
        Extracts all function/command calls from the AST.
    .DESCRIPTION
        Searches the AST for all CommandAst nodes and extracts their command names.
        This includes both user-defined functions and built-in cmdlets.
        Caller is responsible for filtering.
    .PARAMETER ast
        The AST to analyze.
    .OUTPUTS
        An array of unique command/function names called in the AST.
    #>
    static [string[]] GetFunctionCalls([Ast] $ast) {
        $functions = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        $commands = $ast.FindAll({ $args[0] -is [CommandAst] }, $true)

        foreach ($command in $commands) {
            $commandName = $command.GetCommandName()

            if ($commandName) {
                $functions.Add($commandName) | Out-Null
            }
        }

        return @($functions)
    }
    #endregion Dependency Analysis

    #region Type Introspection
    <#
    .SYNOPSIS
        Gets the names of all classes defined in the AST.
    .DESCRIPTION
        Extracts the names of all top-level class definitions in the AST.
        Useful for filtering out self-references in dependency analysis.
    .PARAMETER ast
        The ScriptBlockAst to analyze.
    .EXAMPLE
        $classNames = [PSScriptBuilderAstEngine]::GetDefinedClassNames($ast)
    #>
    static [string[]] GetDefinedClassNames([ScriptBlockAst] $ast) {
        $classes = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)
        $result  = @($classes | ForEach-Object { $_.Name })
        return $result
    }

    <#
    .SYNOPSIS
        Gets the names of all enums defined in the AST.
    .DESCRIPTION
        Extracts the names of all top-level enum definitions in the AST.
        Useful for filtering out self-references in dependency analysis.
    .PARAMETER ast
        The ScriptBlockAst to analyze.
    .OUTPUTS
        An array of enum names defined in the AST.
    #>
    static [string[]] GetDefinedEnumNames([ScriptBlockAst] $ast) {
        $enums  = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)
        $result = @($enums | ForEach-Object { $_.Name })
        return $result
    }
    #endregion Type Introspection

    #region Filtering
    <#
    .SYNOPSIS
        Checks if a type is a built-in .NET or PowerShell type.
    .DESCRIPTION
        Determines whether the specified type name represents a built-in type that should
        typically be excluded from dependency analysis. This includes .NET framework types,
        PowerShell types, and common primitive types.
    .PARAMETER typeName
        The type name to check.
    .OUTPUTS
        Returns $true if the type is considered built-in and should be filtered out; otherwise, $false.
    #>
    static [bool] IsBuiltInType([string] $typeName) {
        if ([string]::IsNullOrWhiteSpace($typeName)) {
            return $true
        }

        # Namespace prefixes (case-insensitive)
        $builtInPrefixes = @(
            'System.',
            'Microsoft.',
            'Management.Automation.'
        )

        foreach ($prefix in $builtInPrefixes) {
            if ($typeName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }

        return [PSScriptBuilderAstEngine]::BuiltInTypeNames.Contains($typeName)
    }
    #endregion Filtering

    #region Source Extraction
    <#
    .SYNOPSIS
        Extracts the source code text from an AST node.
    .DESCRIPTION
        Returns the original source code text represented by the specified AST node.
    .PARAMETER ast
        The AST node to extract source code from.
    .OUTPUTS
        A string containing the source code corresponding to the AST node.
    #>
    static [string] ExtractSourceCode([Ast] $ast) {
        return $ast.Extent.Text
    }
    #endregion Source Extraction

    #region Helper Methods
    <#
    .SYNOPSIS
        Checks whether an AST node falls entirely within any of the given extents.
    .DESCRIPTION
        Returns true if the given node's extent is contained within at least one extent in the
        provided list (StartOffset >= extent.StartOffset and EndOffset <= extent.EndOffset).
        Used by GetTypeReferences() to skip nodes that originate from static property
        initializer expressions.
        When the extents list is empty, this method always returns false.
    .PARAMETER node
        The AST node to check.
    .PARAMETER extents
        The list of extents to test containment against.
    .OUTPUTS
        Returns $true if the node is inside any of the extents; otherwise $false.
    #>
    hidden static [bool] IsInsideAnyExtent([Ast] $node, [List[IScriptExtent]] $extents) {
        foreach ($extent in $extents) {
            if ($node.Extent.StartOffset -ge $extent.StartOffset -and
                $node.Extent.EndOffset   -le $extent.EndOffset) {
                return $true
            }
        }

        return $false
    }

    <#
    .SYNOPSIS
        Extracts all type names from an ITypeName, including generic parameters.
    .DESCRIPTION
        Recursively analyzes an ITypeName and extracts all type names, including:
        - Simple types (User)
        - Generic types with parameters (List[User])
        - Nested generics (Dictionary[string, List[User]])
        - Array types (User[])
        This is a hidden helper method used by GetTypeReferences.
    .PARAMETER typeName
        The ITypeName to analyze.
    .OUTPUTS
        An array of type names extracted from the ITypeName.
    #>
    hidden static [string[]] ExtractTypeNamesFromTypeName([ITypeName] $typeName) {
        $types = [List[string]]::new()

        if ($null -eq $typeName) {
            return @()
        }

        if ($typeName -is [GenericTypeName]) {
            # Generic Type (e.g., List[User])
            # Add main type
            $types.Add($typeName.TypeName.Name)

            # Add generic arguments recursively
            foreach ($genericArgument in $typeName.GenericArguments) {
                $nestedTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($genericArgument)
                $types.AddRange($nestedTypes)
            }
        }
        elseif ($typeName -is [ArrayTypeName]) {
            # Array Type (e.g., User[])
            $elementTypes = [PSScriptBuilderAstEngine]::ExtractTypeNamesFromTypeName($typeName.ElementType)
            $types.AddRange($elementTypes)
        }
        else {
            # Simple TypeName
            $types.Add($typeName.Name)
        }

        return @($types)
    }
    #endregion Helper Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderAstEngine
