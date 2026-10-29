class WebhookNotifier : AsyncNotifierBase {
    [string] $Url

    WebhookNotifier([string] $url) {
        $this.Channel = [NotificationChannel]::Webhook
        $this.Url     = $url
    }

    [void] SendAsync([string] $message) {
        Write-Verbose "Webhook ($($this.Url), async): $message"
    }
}
