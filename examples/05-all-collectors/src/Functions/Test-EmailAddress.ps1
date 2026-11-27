using namespace System.Text.RegularExpressions

Function Test-EmailAddress {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $EmailAddress
    )

    return [Regex]::IsMatch($EmailAddress, $Script:EmailPattern)
}
