class Comment {
    [string] $Author
    [string] $Text
    [datetime] $CreatedAt

    Comment([string] $author, [string] $text) {
        $this.Author    = $author
        $this.Text      = $text
        $this.CreatedAt = [datetime]::UtcNow
    }
}
