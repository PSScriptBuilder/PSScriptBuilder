Function Get-FormattedName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FirstName,

        [Parameter(Mandatory = $true)]
        [string] $LastName
    )

    return "$FirstName $LastName"
}
