Function New-ConfigEntry {
    [CmdletBinding()]
    [OutputType([ConfigEntry])]
    param(
        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter(Mandatory)]
        [string] $Value,

        [Parameter()]
        [string] $Description = ''
    )

    return [ConfigEntry]::new($Key, $Value, $Description)
}
