Function Get-EmployeeById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Employee[]] $Employees,

        [Parameter(Mandatory)]
        [int] $Id
    )
    $found = $Employees | Where-Object { $_.Id -eq $Id }
    if ($null -eq $found) {
        $message = "Employee with Id {0} was not found." -f $Id
        throw [System.Collections.Generic.KeyNotFoundException]::new($message)
    }
    return $found
}
