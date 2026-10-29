using namespace System.Collections.Generic

class Ticket {
    [int] $Id
    [string] $Title
    [TicketPriority] $Priority
    [TicketCategory] $Category
    [TicketStatus] $Status
    [List[Comment]] $Comments
    [User] $Assignee

    Ticket([int] $id, [string] $title, [TicketPriority] $priority, [TicketCategory] $category) {
        $this.Id       = $id
        $this.Title    = $title
        $this.Priority = $priority
        $this.Category = $category
        $this.Status   = [TicketStatus]::Open
        $this.Comments = [List[Comment]]::new()
    }

    [void] AddComment([Comment] $comment) {
        $this.Comments.Add($comment)
    }
}
