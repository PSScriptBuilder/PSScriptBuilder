using namespace System.Text.Json

class EmailNotifier : NotifierBase {
    EmailNotifier() {
        $this.Channel = [NotificationChannel]::Email
    }

    [void] Send([string] $message) {
        Write-Verbose "Email: $message"
    }
}
