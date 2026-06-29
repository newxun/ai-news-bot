# AI News Scheduler Log Viewer
# Shows a summary of recent scheduler and runner executions

$logDir = Join-Path $env:USERPROFILE ".ai-news-scheduler"
$configDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatePath = Join-Path $configDir "config.ps1"
$localConfigPath = Join-Path $configDir "config.local.ps1"

# Load config to get output directory
if (Test-Path $localConfigPath) {
    . $localConfigPath
    $config = $Global:AiNewsConfig
} elseif (Test-Path $templatePath) {
    . $templatePath
    $config = $Global:AiNewsConfig
} else {
    $config = @{ OutputDir = "D:\存档\AI新闻" }
}

Write-Output "=== AI News Scheduler Status ==="
Write-Output ""

if (-not (Test-Path $logDir)) {
    Write-Output "Log directory not found: $logDir"
    Write-Output "System has not run yet."
    exit 0
}

# Get today's date
$beijingTz = [System.TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
$nowBeijing = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $beijingTz)
$today = $nowBeijing.ToString("yyyy-MM-dd")

# Function to parse log status
function Get-LogStatus {
    param([string]$LogFile)

    if (-not (Test-Path $LogFile)) {
        return @{ Status = "NO_LOG"; Summary = "No log file" }
    }

    $content = Get-Content $LogFile -Raw -Encoding UTF8

    # Check for success indicators
    if ($content -match "\[INFO\].*Runner completed \(SUCCESS\)" -or $content -match "SUCCESS: Output file created") {
        return @{ Status = "SUCCESS"; Summary = "Execution successful" }
    }

    if ($content -match "\[INFO\].*Scheduler completed \(SUCCESS\)" -or $content -match "\[INFO\].*Scheduler completed \(Invoking runner\)") {
        return @{ Status = "SUCCESS"; Summary = "Scheduled successfully" }
    }

    if ($content -match "\[INFO\].*Runner completed \(SKIPPED\)") {
        return @{ Status = "SKIPPED"; Summary = "Already completed today" }
    }

    if ($content -match "\[INFO\].*Scheduler completed \(ALREADY SCHEDULED\)") {
        return @{ Status = "SKIPPED"; Summary = "Already scheduled today" }
    }

    if ($content -match "\[INFO\].*Scheduler completed \(Old completion date\)") {
        return @{ Status = "SKIPPED"; Summary = "Waiting for today's workflow" }
    }

    if ($content -match "\[INFO\].*Scheduler completed \(Workflow not complete\)") {
        return @{ Status = "WAITING"; Summary = "Waiting for workflow completion" }
    }

    if ($content -match "\[ERROR\]") {
        return @{ Status = "ERROR"; Summary = "Execution failed" }
    }

    if ($content -match "\[WARN\]") {
        return @{ Status = "WARNING"; Summary = "Execution with warnings" }
    }

    return @{ Status = "UNKNOWN"; Summary = "Status unclear" }
}

# Function to format status with color
function Show-Status {
    param([string]$Status, [string]$Summary)

    $color = switch ($Status) {
        "SUCCESS" { "Green" }
        "SKIPPED" { "Cyan" }
        "WAITING" { "Yellow" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "Gray" }
    }

    $statusText = "[$Status]"
    Write-Output "$statusText $Summary"
}

# Check today's files
$schedulerLog = Join-Path $logDir "scheduler-$today.log"
$runnerLog = Join-Path $logDir "runner-$today.log"
$markerFile = Join-Path $logDir "scheduled-$today.txt"
$outputFile = Join-Path $config.OutputDir "AI新闻_$today.md"

Write-Output "Today: $today (Beijing)"
Write-Output ""

# Scheduler status
Write-Output "Scheduler:"
$schedulerStatus = Get-LogStatus $schedulerLog
Show-Status @($schedulerStatus.Status, $schedulerStatus.Summary)

if (Test-Path $markerFile) {
    $markerContent = Get-Content $markerFile -Raw -Encoding UTF8
    Write-Output "  Scheduled for: $(($markerContent -split "\r?\n") | Select-Object -Index 1)"
}

# Runner status
Write-Output ""
Write-Output "Runner:"
$runnerStatus = Get-LogStatus $runnerLog
Show-Status @($runnerStatus.Status, $runnerStatus.Summary)

# Output file status
Write-Output ""
Write-Output "Output file:"
if (Test-Path $outputFile) {
    $size = (Get-Item $outputFile).Length
    $modified = (Get-Item $outputFile).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    Write-Output "  [EXISTS] $outputFile"
    Write-Output "  Size: $size bytes"
    Write-Output "  Modified: $modified"
} else {
    Write-Output "  [NOT_FOUND] File not created yet"
}

# Recent history (last 7 days)
Write-Output ""
Write-Output "=== Recent History (Last 7 Days) ==="
Write-Output ""

$history = @()
for ($i = 1; $i -le 7; $i++) {
    $date = $nowBeijing.AddDays(-$i).ToString("yyyy-MM-dd")
    $runnerLog = Join-Path $logDir "runner-$date.log"
    $outputFile = Join-Path $config.OutputDir "AI新闻_$date.md"

    if (Test-Path $runnerLog) {
        $status = Get-LogStatus $runnerLog
        $outputExists = Test-Path $outputFile
        $history += [PSCustomObject]@{
            Date = $date
            Status = $status.Status
            OutputExists = $outputExists
        }
    }
}

if ($history.Count -eq 0) {
    Write-Output "No recent history found."
} else {
    $history | Format-Table -AutoSize @{
        Label = "Date"
        Expression = { $_.Date }
        Width = 12
    }, @{
        Label = "Status"
        Expression = {
            $color = switch ($_.Status) {
                "SUCCESS" { "Green" }
                "ERROR" { "Red" }
                default { "Gray" }
            }
            "[$($_.Status)]"
        }
        Width = 12
    }, @{
        Label = "Output"
        Expression = { if ($_.OutputExists) { "Yes" } else { "No" } }
        Width = 8
    }
}

Write-Output ""
Write-Output "=== View Detailed Logs ==="
Write-Output "Scheduler: $schedulerLog"
Write-Output "Runner: $runnerLog"
Write-Output ""
Write-Output "Run 'view-logs.ps1 -detail' to view full log contents."
