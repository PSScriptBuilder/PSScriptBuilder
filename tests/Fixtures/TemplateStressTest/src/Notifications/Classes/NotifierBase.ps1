class NotifierBase {
    [NotificationChannel] $Channel

    [void] Send([string] $message) {
        throw [System.NotImplementedException]::new("Send() must be implemented by subclass")
    }
}
