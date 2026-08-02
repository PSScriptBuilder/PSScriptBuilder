Function Format-Salary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [decimal] $Amount
    )

    return $Amount.ToString('C', [System.Globalization.CultureInfo]::GetCultureInfo('en-US'))
}
