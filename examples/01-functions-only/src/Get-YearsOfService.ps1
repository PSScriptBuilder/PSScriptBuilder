Function Get-YearsOfService {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [DateTime] $HireDate
    )

    $years = [Math]::Floor(([DateTime]::Today - $HireDate).TotalDays / 365.25)

    if ($years -eq 1) {
        return "1 year"
    }

    return "$years years"
}
