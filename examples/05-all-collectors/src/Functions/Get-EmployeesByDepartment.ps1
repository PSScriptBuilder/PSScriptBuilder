using namespace System.Collections.Generic

Function Get-EmployeesByDepartment {
    [CmdletBinding()]
    [OutputType([List[Employee]])]
    param(
        [Parameter(Mandatory = $true)]
        [Employee[]] $Employees,

        [Parameter(Mandatory = $true)]
        [Department] $Department
    )

    $result = [List[Employee]]::new()
    foreach ($employee in $Employees) {
        if ($employee.Department -eq $Department) {
            $result.Add($employee)
        }
    }

    return $result
}
