using namespace System.Collections.Generic

class TicketList {
    [List[Ticket]] $Items

    TicketList() {
        $this.Items = [List[Ticket]]::new()
    }

    [void] Add([Ticket] $ticket) {
        $this.Items.Add($ticket)
    }

    [Ticket[]] GetByStatus([TicketStatus] $status) {
        return $this.Items | Where-Object { $_.Status -eq $status }
    }
}
