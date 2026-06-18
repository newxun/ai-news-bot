# Register the daily AINewsScheduler task in Windows Task Scheduler
# Runs daily at 10:00 AM Beijing time. No admin required.

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$schedulerPath = Join-Path $scriptDir "scheduler.ps1"
$taskName = "AINewsScheduler"

if (-not (Test-Path $schedulerPath)) {
    Write-Error "scheduler.ps1 not found at $schedulerPath"
    exit 1
}

Write-Output "=== Registering AINewsScheduler task ==="
Write-Output "Scheduler script: $schedulerPath"
Write-Output ""

# Remove existing task if any
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "Removed existing task."
} catch {}

# Build action / trigger / settings
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$schedulerPath`""

# Daily trigger at 10:00 AM
$trigger = New-ScheduledTaskTrigger -Daily -At "10:00"

# -StartWhenAvailable: if 10 AM was missed (computer off), run ASAP after wake
# -DontStopOnIdleEnd: don't kill task when computer goes idle
# -ExecutionTimeLimit: max 2 hours
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -MultipleInstances IgnoreNew

# Register for current user (no admin needed)
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Daily scheduler: queries GitHub Actions completion, registers one-shot task for completion+5h to run AI news search via Claude Code" `
    -Force | Out-Null

Write-Output ""
Write-Output "=== Task registered successfully ==="
Write-Output ""

# Show registered task details
Get-ScheduledTask -TaskName $taskName | Format-List TaskName, TaskPath, State, Description
Write-Output "Trigger:"
(Get-ScheduledTask -TaskName $taskName).Triggers | Format-List
Write-Output "Action:"
(Get-ScheduledTask -TaskName $taskName).Actions | Format-List
