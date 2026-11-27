Function New-AppConfig {
    [CmdletBinding()]
    [OutputType([AppConfig])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    return [AppConfig]::new($Name)
}
