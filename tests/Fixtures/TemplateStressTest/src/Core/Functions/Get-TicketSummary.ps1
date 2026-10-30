function Get-TicketSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TicketList] $List
    )

    return [PSCustomObject] @{
        Total      = $List.Items.Count
        Open       = $List.GetByStatus([TicketStatus]::Open).Count
        InProgress = $List.GetByStatus([TicketStatus]::InProgress).Count
        Resolved   = $List.GetByStatus([TicketStatus]::Resolved).Count
        Closed     = $List.GetByStatus([TicketStatus]::Closed).Count
    }
}
