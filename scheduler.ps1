# AI News Scheduler - Daily trigger
# Runs at 10:00 AM (or whenever missed) via Windows Task Scheduler
# Mirrors the Claude Code cron logic:
#   1. Query GitHub Actions for latest workflow run completion time
#   2. Compute target = completion + 5h (Beijing time)
#   3. If target already passed -> run runner immediately
#   4. Otherwise -> register one-shot Windows task for target time
#   5. One-shot task invokes Claude Code CLI with the search prompt

$ErrorActionPreference = "Stop"

# ===== Configuration =====
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "config.local.ps1"
$templatePath = Join-Path $scriptDir "config.ps1"

# Load configuration
if (Test-Path $configPath) {
    . $configPath
    $config = $Global:AiNewsConfig
} elseif (Test-Path $templatePath) {
    Write-Warning "config.local.ps1 not found. Using template with defaults."
    . $templatePath
    $config = $Global:AiNewsConfig
} else {
    Write-Error "Configuration file not found: $configPath or $templatePath"
    exit 1
}

if ($null -eq $config.GithubToken -or $config.GithubToken -eq "") {
    Write-Error "GithubToken not configured. Please edit config.local.ps1 and set your token."
    Write-Error "Create token at: https://github.com/settings/tokens"
    exit 1
}

$token = $config.GithubToken
$repo = $config.Repo
$delayHours = $config.DelayHours
$outputDir = $config.OutputDir
$runnerPath = Join-Path $scriptDir "runner.ps1"
$logDir = Join-Path $env:USERPROFILE ".ai-news-scheduler"
$beijingTz = [System.TimeZoneInfo]::FindSystemTimeZoneById($config.TimezoneId)

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$nowBeijing = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $beijingTz)
$today = $nowBeijing.ToString("yyyy-MM-dd")
$logFile = Join-Path $logDir "scheduler-$today.log"
$markerFile = Join-Path $logDir "scheduled-$today.txt"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Write-Log "=== Scheduler started ===" "INFO"
Write-Log "Beijing now: $nowBeijing" "INFO"
Write-Log "Monitoring repo: $repo" "INFO"
Write-Log "Delay hours: $delayHours" "INFO"

# Idempotency: skip if already scheduled today
if (Test-Path $markerFile) {
    Write-Log "Marker file exists for $today. Already scheduled." "INFO"
    Write-Log "=== Scheduler completed (ALREADY SCHEDULED) ===" "INFO"
    exit 0
}

# ===== Query GitHub API =====
$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "ai-news-scheduler"
}

try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/actions/runs?per_page=1" -Headers $headers -TimeoutSec 30
    Write-Log "GitHub API query successful" "INFO"
} catch {
    Write-Log "GitHub API error: $_" "ERROR"
    Write-Log "=== Scheduler failed (GitHub API error) ===" "ERROR"
    exit 1
}

$run = $response.workflow_runs[0]
if (-not $run) {
    Write-Log "No workflow runs found" "WARN"
    Write-Log "=== Scheduler completed (No workflows) ===" "INFO"
    exit 0
}

Write-Log "Latest workflow: $($run.name) #$($run.run_number)" "INFO"
Write-Log "Workflow status: $($run.status)" "INFO"

if ($run.status -ne "completed") {
    Write-Log "Workflow not completed yet. Exiting." "INFO"
    Write-Log "=== Scheduler completed (Workflow not complete) ===" "INFO"
    exit 0
}

# Parse completion time (UTC ISO 8601 -> Beijing)
# Use DateTimeOffset to properly handle timezone conversion
$completedOffset = [DateTimeOffset]::Parse($run.updated_at, [System.Globalization.CultureInfo]::InvariantCulture)
$completedUtc = $completedOffset.UtcDateTime
$completedBeijing = [System.TimeZoneInfo]::ConvertTimeFromUtc($completedUtc, $beijingTz)
$completedDate = $completedBeijing.ToString("yyyy-MM-dd")

Write-Log "Workflow conclusion: $($run.conclusion)" "INFO"
Write-Log "Completed at (Beijing): $completedBeijing" "INFO"

# Only schedule for today's completion
if ($completedDate -ne $today) {
    Write-Log "Completion is from $completedDate, not today ($today)" "INFO"
    Write-Log "=== Scheduler completed (Old completion date) ===" "INFO"
    exit 0
}

Write-Log "Completion is from today, proceeding to schedule" "INFO"

# ===== Compute target = completion + delay hours =====
$target = $completedBeijing.AddHours($delayHours)
Write-Log "Target time (Beijing): $target" "INFO"

# If target already passed, run runner immediately
if ($nowBeijing -ge $target) {
    Write-Log "Target already passed. Invoking runner immediately." "INFO"
    Write-Log "=== Scheduler completed (Invoking runner) ===" "INFO"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runnerPath
    exit 0
}

# ===== Register one-shot Windows task for target time =====
$taskName = "AINewsRunner_$today"
$cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

# Delete existing one-shot with same name if any
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

try {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At $target
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

    Write-Log "Registered one-shot task '$taskName' for $target" "INFO"
    Set-Content -Path $markerFile -Value "Scheduled at $nowBeijing`nTarget: $target`nTask: $taskName" -Encoding UTF8
    Write-Log "=== Scheduler completed (SUCCESS) ===" "INFO"
} catch {
    Write-Log "Register-ScheduledTask failed: $_" "ERROR"
    Write-Log "Falling back to schtasks.exe" "WARN"

    $targetTime = $target.ToString("HH:mm:ss")
    $targetDate = $target.ToString("MM/dd/yyyy")
    $result = schtasks /create /tn $taskName /tr $cmd /sc once /st $targetTime /sd $targetDate /f 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Log "schtasks created one-shot for $targetDate $targetTime" "INFO"
        Set-Content -Path $markerFile -Value "Scheduled at $nowBeijing`nTarget: $target" -Encoding UTF8
        Write-Log "=== Scheduler completed (SUCCESS with fallback) ===" "INFO"
    } else {
        Write-Log "schtasks FAILED. Exit: $LASTEXITCODE. Output: $result" "ERROR"
        Write-Log "=== Scheduler failed (Task registration failed) ===" "ERROR"
        exit 1
    }
}
