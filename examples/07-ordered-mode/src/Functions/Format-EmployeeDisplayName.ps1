function Format-EmployeeDisplayName {
    param([Person] $Employee)
    return "$($Employee.FirstName) $($Employee.LastName)"
}
