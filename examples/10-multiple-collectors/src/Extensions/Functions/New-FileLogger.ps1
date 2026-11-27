Function New-FileLogger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    return [FileLogger]::new($FilePath)
}
