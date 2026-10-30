class SharedUsage {
    static [SharedType] $Default = [SharedType]::new()

    [string] GetValue([SharedType] $input) {
        return $input.ToString()
    }
}
