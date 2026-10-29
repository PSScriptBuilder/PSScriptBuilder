using namespace System.Text

Function Format-EmployeeReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [Employee] $Employee
    )

    $sb = [StringBuilder]::new()
    [void]$sb.AppendLine("Employee Report")
    [void]$sb.AppendLine("  Name      : $($Employee.FirstName) $($Employee.LastName)")
    [void]$sb.AppendLine("  Department: $($Employee.Department)")
    [void]$sb.AppendLine("  Status    : $($Employee.Status)")
    [void]$sb.AppendLine("  Hire Date : $($Employee.HireDate.ToString('yyyy-MM-dd'))")
    [void]$sb.Append(    "  Salary    : $($Employee.Salary.ToString('C', [System.Globalization.CultureInfo]::GetCultureInfo('en-US')))")

    return $sb.ToString()
}
