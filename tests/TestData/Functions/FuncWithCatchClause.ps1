Function Invoke-Safe {
    [CmdletBinding()]
    param()
    try {
        Get-Item -Path 'C:\temp'
    } catch ([MyCustomException]) {
        Write-Error $_
    }
}
