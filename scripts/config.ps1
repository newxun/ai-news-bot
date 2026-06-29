# AI News Scheduler Configuration
# Copy this file to config.local.ps1 and set your own values
# Never commit config.local.ps1 to version control

$Global:AiNewsConfig = @{
    # GitHub Personal Access Token (classic)
    # Needs: repo -> public_repo scope for reading Actions
    # Create at: https://github.com/settings/tokens
    GithubToken = $null

    # GitHub repository to monitor (owner/repo format)
    Repo = "newxun/ai-news-bot"

    # Output directory for AI news files
    OutputDir = "D:\存档\AI新闻"

    # Timezone for display and scheduling
    # Use Windows timezone ID (e.g., "China Standard Time", "Pacific Standard Time")
    TimezoneId = "China Standard Time"

    # Hours to wait after GitHub Actions completion before running news search
    DelayHours = 5
}
