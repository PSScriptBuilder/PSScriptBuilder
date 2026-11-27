Function New-Person {
    [CmdletBinding()]
    param(
        [string] $FirstName,
        [string] $LastName
    )

    return [Person]::new($FirstName, $LastName)
}
