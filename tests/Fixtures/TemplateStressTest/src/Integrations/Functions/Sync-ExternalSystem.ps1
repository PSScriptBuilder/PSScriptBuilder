function Sync-ExternalSystem {
    [CmdletBinding()]
    [OutputType([Ticket])]
    param(
        [Parameter(Mandatory)]
        [IntegrationType] $Type,

        [Parameter(Mandatory)]
        [string] $ExternalId
    )

    switch ($Type) {
        ([IntegrationType]::Jira)   { return [JiraSync]::new().Import($ExternalId) }
        ([IntegrationType]::GitHub) { return [GitHubSync]::new().Import($ExternalId) }
    }

    throw [System.ArgumentException]::new("Unsupported integration type: $Type")
}
