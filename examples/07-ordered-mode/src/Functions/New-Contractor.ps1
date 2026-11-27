Function New-Contractor {
    [CmdletBinding()]
    param(
        [string]   $FirstName,
        [string]   $LastName,
        [string]   $Company,
        [DateTime] $ContractStart,
        [DateTime] $ContractEnd
    )

    $person = New-Person -FirstName $FirstName -LastName $LastName
    return [Contractor]::new($person.FirstName, $person.LastName, $Company, $ContractStart, $ContractEnd)
}
