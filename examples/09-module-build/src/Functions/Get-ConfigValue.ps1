Function Get-ConfigValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AppConfig] $Config,

        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter()]
        [string] $Default = ''
    )

    if ($Config.Contains($Key)) {
        return $Config.Get($Key).Value
    }

    return $Default
}
