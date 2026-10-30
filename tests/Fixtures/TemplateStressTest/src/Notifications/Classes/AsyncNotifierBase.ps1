class AsyncNotifierBase : NotifierBase {
    [void] SendAsync([string] $message) {
        throw [System.NotImplementedException]::new("SendAsync() must be implemented by subclass")
    }
}
