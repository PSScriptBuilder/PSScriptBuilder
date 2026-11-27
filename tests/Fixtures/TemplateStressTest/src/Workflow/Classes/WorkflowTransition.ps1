class WorkflowTransition {
    [WorkflowState] $From
    [WorkflowState] $To

    WorkflowTransition([WorkflowState] $from, [WorkflowState] $to) {
        $this.From = $from
        $this.To   = $to
    }
}
