Function Get-EmployeesByDepartment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Employee[]] $Employees,

        [Parameter(Mandatory)]
        [string] $Department
    )
    return @($Employees | Where-Object { $_.Department -eq $Department })
}
