Function Do-Work {
    [CmdletBinding()]
    param()
    Get-Item -Path 'C:\temp'
    Write-Verbose 'done'
}
