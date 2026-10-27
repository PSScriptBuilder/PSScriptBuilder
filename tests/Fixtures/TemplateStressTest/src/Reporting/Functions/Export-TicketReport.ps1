function Export-TicketReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [TicketList] $List,

        [Parameter(Mandatory)]
        [ReportGenerator] $Generator
    )

    return $Generator.Generate($List)
}
