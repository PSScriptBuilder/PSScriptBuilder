Function New-Employee {
    [CmdletBinding()]
    [OutputType([Employee])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FirstName,

        [Parameter(Mandatory = $true)]
        [string] $LastName,

        [Parameter(Mandatory = $true)]
        [Address] $Address,

        [Parameter(Mandatory = $true)]
        [Department] $Department,

        [Parameter(Mandatory = $true)]
        [DateTime] $HireDate,

        [Parameter(Mandatory = $true)]
        [decimal] $Salary
    )

    return [Employee]::new($FirstName, $LastName, $Address, $Department, $HireDate, $Salary)
}

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
