Function New-Employee {
    [CmdletBinding()]
    param(
        [string]   $FirstName,
        [string]   $LastName,
        [string]   $Department,
        [DateTime] $StartDate
    )

    $person = New-Person -FirstName $FirstName -LastName $LastName
    return [Employee]::new($person.FirstName, $person.LastName, $Department, $StartDate)
}
