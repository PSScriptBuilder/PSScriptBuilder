Function New-Employee {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $Id,

        [Parameter(Mandatory)]
        [string] $FirstName,

        [Parameter(Mandatory)]
        [string] $LastName,

        [Parameter(Mandatory)]
        [string] $Department
    )
    return [Employee]::new($Id, $FirstName, $LastName, $Department)
}
