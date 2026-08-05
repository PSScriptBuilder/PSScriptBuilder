using namespace System.Management.Automation.Language

#region Class PSScriptBuilderParseResult
<#
.SYNOPSIS
    Represents the result of parsing a PowerShell file.
.DESCRIPTION
    The PSScriptBuilderParseResult class encapsulates the output of the PowerShell parser,
    combining the ScriptBlockAst and any parse errors produced during parsing.

    Parse errors do not necessarily indicate a problem - some errors (e.g. unresolved type
    references) are expected when files are parsed in isolation. Callers are responsible for
    determining whether the errors are significant based on context, such as whether any
    definitions were collected from the AST.
#>
class PSScriptBuilderParseResult {
    #region Properties
    <#
    .SYNOPSIS
        The AST produced by the parser.
    .DESCRIPTION
        The Ast property holds the ScriptBlockAst returned by the PowerShell parser.
        This is always present, even when parse errors occurred.
    #>
    [ScriptBlockAst] $Ast

    <#
    .SYNOPSIS
        Parse errors encountered during parsing.
    .DESCRIPTION
        The ParseErrors property holds all parse errors reported by the PowerShell parser.
        An empty array indicates a clean parse. Errors may be harmless (e.g. unresolved type
        references in isolated file parsing) or indicate genuine syntax problems.
    #>
    [ParseError[]] $ParseErrors
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderParseResult.
    .DESCRIPTION
        Creates a new PSScriptBuilderParseResult with the specified AST and parse errors.
    .PARAMETER ast
        The ScriptBlockAst produced by the parser. Cannot be null.
    .PARAMETER parseErrors
        The parse errors reported by the parser. Pass an empty array if there were none.
    #>
    PSScriptBuilderParseResult([ScriptBlockAst] $ast, [ParseError[]] $parseErrors) {
        if ($null -eq $ast) {
            $message = "The AST produced by the parser cannot be null."
            throw [ArgumentNullException]::new("ast", $message)
        }

        $this.Ast         = $ast
        $this.ParseErrors = if ($null -ne $parseErrors) { $parseErrors } else { @() }
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderParseResult
