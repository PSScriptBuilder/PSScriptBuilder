Function Set-EmployeeStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Employee] $Employee,

        [Parameter(Mandatory = $true)]
        [EmploymentStatus] $Status
    )

    $Employee.Status = $Status
}
