function Send-TicketNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Ticket] $Ticket,

        [Parameter(Mandatory)]
        [NotifierBase] $Notifier
    )

    $Notifier.Send("Ticket #$($Ticket.Id): $($Ticket.Title)")
}
