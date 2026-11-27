class ReportGenerator {
    [ReportFormat] $Format
    hidden [LegacyReportFormatter] $Legacy
    hidden [CsvReportFormatter] $Csv

    ReportGenerator([ReportFormat] $format) {
        $this.Format = $format
        $this.Legacy = [LegacyReportFormatter]::new()
        $this.Csv    = [CsvReportFormatter]::new()
    }

    [string] Generate([TicketList] $list) {
        if ($this.Format -eq [ReportFormat]::Csv) {
            return $this.Csv.Format($list)
        }
        return $this.Legacy.Format($list)
    }
}
