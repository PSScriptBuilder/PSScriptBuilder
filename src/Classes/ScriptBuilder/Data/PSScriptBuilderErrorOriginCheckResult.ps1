#region Class PSScriptBuilderErrorOriginCheckResult
<#
.SYNOPSIS
    Represents the result of checking whether an error originated in the mapped output script.
.DESCRIPTION
    The PSScriptBuilderErrorOriginCheckResult class is returned by
    PSScriptBuilderSourceLocationResolver.CheckErrorOrigin(). It states whether an ErrorRecord's
    script file counts as the output script the source map belongs to and, if not, why.

    A negative result is not a failed check: the check succeeded and determined that the error
    came from somewhere else. Instances are created through the static FromMappedOutput() and
    NotFromMappedOutput() methods, which state the outcome at the call site.
#>
class PSScriptBuilderErrorOriginCheckResult {
    #region Properties
    <#
    .SYNOPSIS
        Whether the error originated in the mapped output script.
    .DESCRIPTION
        True if the error's script file is the output script or an unmodified copy of it, false
        otherwise.
    #>
    [bool] $IsFromMappedOutput

    <#
    .SYNOPSIS
        The warning message explaining why the error did not originate in the output script.
    .DESCRIPTION
        Set only when IsFromMappedOutput is false; $null otherwise.
    #>
    [string] $MismatchMessage
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new PSScriptBuilderErrorOriginCheckResult.
    .DESCRIPTION
        Prefer the static FromMappedOutput() and NotFromMappedOutput() methods, which state the
        outcome at the call site. Throws ArgumentException if the message does not match the
        outcome: a negative result requires a message, a positive one must not have one.
    .PARAMETER isFromMappedOutput
        Whether the error originated in the mapped output script.
    .PARAMETER mismatchMessage
        The reason why the error did not originate in the output script, or $null.
    #>
    PSScriptBuilderErrorOriginCheckResult([bool] $isFromMappedOutput, [string] $mismatchMessage) {
        $hasMessage = -not [string]::IsNullOrWhiteSpace($mismatchMessage)

        if (-not $isFromMappedOutput -and -not $hasMessage) {
            $message = "Parameter 'mismatchMessage' is required " +
                       "when the error did not originate in the mapped output script."
            throw [ArgumentException]::new($message, "mismatchMessage")
        }

        if ($isFromMappedOutput -and $hasMessage) {
            $message = "Parameter 'mismatchMessage' must be empty " +
                       "when the error originated in the mapped output script."
            throw [ArgumentException]::new($message, "mismatchMessage")
        }

        $this.IsFromMappedOutput = $isFromMappedOutput

        # Assigned only when present: assigning $null to a [string] property stores an empty
        # string, while a property that is never assigned stays $null
        if ($hasMessage) {
            $this.MismatchMessage = $mismatchMessage
        }
    }
    #endregion Constructors

    #region Static Methods
    <#
    .SYNOPSIS
        Creates a result stating that the error originated in the mapped output script.
    .DESCRIPTION
        A method rather than a static property: PowerShell class properties cannot be read-only,
        so a shared instance could be modified by any caller.
    .OUTPUTS
        Returns a new PSScriptBuilderErrorOriginCheckResult with IsFromMappedOutput set to true.
    #>
    static [PSScriptBuilderErrorOriginCheckResult] FromMappedOutput() {
        $result = [PSScriptBuilderErrorOriginCheckResult]::new($true, $null)
        return $result
    }

    <#
    .SYNOPSIS
        Creates a result stating that the error did not originate in the mapped output script.
    .PARAMETER mismatchMessage
        The warning message explaining why. Cannot be null or empty.
    .OUTPUTS
        Returns a new PSScriptBuilderErrorOriginCheckResult with IsFromMappedOutput set to false.
    #>
    static [PSScriptBuilderErrorOriginCheckResult] NotFromMappedOutput([string] $mismatchMessage) {
        $result = [PSScriptBuilderErrorOriginCheckResult]::new($false, $mismatchMessage)
        return $result
    }
    #endregion Static Methods
}
#endregion Class PSScriptBuilderErrorOriginCheckResult
