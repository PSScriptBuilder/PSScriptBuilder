function Send-BulkNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TicketList] $List,

        [Parameter(Mandatory)]
        [NotifierBase] $Notifier
    )

    foreach ($ticket in $List.Items) {
        $Notifier.Send("Ticket #$($ticket.Id): $($ticket.Title)")
    }
}
