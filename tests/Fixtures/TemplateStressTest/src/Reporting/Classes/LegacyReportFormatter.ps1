class LegacyReportFormatter {
    [string] Format([TicketList] $list) {
        $lines = $list.Items | ForEach-Object { "$($_.Id): $($_.Title) [$($_.Status)]" }
        return $lines -join "`n"
    }
}
