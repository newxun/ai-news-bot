. $PSScriptRoot\config.local.ps1

$headers = @{
    "Authorization" = "token $($Global:AiNewsConfig.GithubToken)"
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "ai-news-scheduler"
}

$response = Invoke-RestMethod -Uri "https://api.github.com/repos/$($Global:AiNewsConfig.Repo)/actions/runs?per_page=1" -Headers $headers
$run = $response.workflow_runs[0]

Write-Output "=== GitHub Actions Debug Info ==="
Write-Output "Workflow: $($run.name)"
Write-Output "Run Number: $($run.run_number)"
Write-Output "Status: $($run.status)"
Write-Output "Conclusion: $($run.conclusion)"
Write-Output ""
Write-Output "=== Timestamps (Raw from API) ==="
Write-Output "created_at: $($run.created_at)"
Write-Output "updated_at: $($run.updated_at)"
Write-Output "run_started_at: $($run.run_started_at)"
Write-Output ""
Write-Output "=== Timestamps (Parsed as UTC) ==="
$createdUtc = [DateTime]::Parse($run.created_at, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
$updatedUtc = [DateTime]::Parse($run.updated_at, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
Write-Output "created_at (UTC): $createdUtc"
Write-Output "updated_at (UTC): $updatedUtc"
Write-Output ""
Write-Output "=== Timestamps (Converted to Beijing) ==="
$beijingTz = [System.TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
$createdBeijing = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::SpecifyKind($createdUtc, [DateTimeKind]::Utc), $beijingTz)
$updatedBeijing = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::SpecifyKind($updatedUtc, [DateTimeKind]::Utc), $beijingTz)
Write-Output "created_at (Beijing): $createdBeijing"
Write-Output "updated_at (Beijing): $updatedBeijing"
