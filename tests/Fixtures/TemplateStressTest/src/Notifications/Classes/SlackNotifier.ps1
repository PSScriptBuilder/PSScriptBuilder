using namespace System.Net.Http

class SlackNotifier : AsyncNotifierBase {
    SlackNotifier() {
        $this.Channel = [NotificationChannel]::Slack
    }

    [void] SendAsync([string] $message) {
        Write-Verbose "Slack (async): $message"
    }
}
