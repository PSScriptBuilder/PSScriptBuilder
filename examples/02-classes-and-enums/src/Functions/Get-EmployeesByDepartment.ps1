Function Get-EmployeesByDepartment {
    [CmdletBinding()]
    [OutputType([Employee[]])]
    param(
        [Parameter(Mandatory = $true)]
        [Employee[]] $Employees,

        [Parameter(Mandatory = $true)]
        [Department] $Department
    )

    return $Employees | Where-Object { $_.Department -eq $Department }
}
