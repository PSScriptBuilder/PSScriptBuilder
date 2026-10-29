class CsvReportFormatter {
    [string] Format([TicketList] $list) {
        $lines = $list.Items | ForEach-Object { "$($_.Id),$($_.Title),$($_.Status)" }
        return ("Id,Title,Status`n" + ($lines -join "`n"))
    }
}
