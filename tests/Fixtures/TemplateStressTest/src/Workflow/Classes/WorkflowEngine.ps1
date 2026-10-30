using namespace System.Collections.Generic

class WorkflowEngine {
    [Ticket] $Ticket
    [WorkflowState] $State
    [List[WorkflowRule]] $Rules
    [List[WorkflowTransition]] $History

    WorkflowEngine([Ticket] $ticket) {
        $this.Ticket  = $ticket
        $this.State   = [WorkflowState]::Pending
        $this.Rules   = [List[WorkflowRule]]::new()
        $this.History = [List[WorkflowTransition]]::new()
    }

    [void] TransitionTo([WorkflowState] $newState) {
        $this.History.Add([WorkflowTransition]::new($this.State, $newState))
        $this.State = $newState
    }
}
