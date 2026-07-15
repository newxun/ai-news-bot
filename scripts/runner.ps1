# AI News Runner - One-shot execution
$ErrorActionPreference = "Continue"

# Force UTF-8 for capturing Claude CLI output — otherwise Chinese text from stderr comes out as mojibake
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONUTF8 = "1"

# Load configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$configPath = Join-Path $scriptDir "config.local.ps1"
$templatePath = Join-Path $scriptDir "config.ps1"

if (Test-Path $configPath) {
    . $configPath
    $config = $Global:AiNewsConfig
} elseif (Test-Path $templatePath) {
    . $templatePath
    $config = $Global:AiNewsConfig
} else {
    Write-Error "Configuration file not found"
    exit 1
}

# Resolve output directory: relative paths are anchored to the project root
$outputDir = if ([System.IO.Path]::IsPathRooted($config.OutputDir)) {
    $config.OutputDir
} else {
    Join-Path $projectRoot $config.OutputDir
}

$beijingTz = [System.TimeZoneInfo]::FindSystemTimeZoneById($config.TimezoneId)
$nowBeijing = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $beijingTz)
$today = $nowBeijing.ToString("yyyy-MM-dd")
$nowTime = $nowBeijing.ToString("HH:mm")

$logDir = Join-Path $projectRoot "logs"
$logFile = Join-Path $logDir "runner-$today.log"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Write-Log "=== Runner started ===" "INFO"
Write-Log "Today: $today  Time: $nowTime" "INFO"

# Create output directory if not exists
if (-not (Test-Path $outputDir)) {
    try {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Log "Created output directory" "INFO"
    } catch {
        Write-Log "Failed to create output directory: $_" "ERROR"
        exit 1
    }
}

$outputFile = Join-Path $outputDir "AI小知识_$today.md"

# Idempotency check
if (Test-Path $outputFile) {
    Write-Log "Output file already exists, skipping" "INFO"
    Write-Log "=== Runner completed (SKIPPED) ===" "INFO"
    exit 0
}

# Locate Claude Code CLI
$claudePath = $null
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    $claudePath = $claudeCmd.Source
} else {
    $candidates = @(
        "$env:LOCALAPPDATA\pnpm\claude.ps1",
        "$env:LOCALAPPDATA\pnpm\claude.cmd",
        "$env:LOCALAPPDATA\pnpm\claude.exe",
        "$env:USERPROFILE\.claude\local\claude.exe",
        "$env:APPDATA\npm\claude.cmd",
        "$env:APPDATA\npm\claude.ps1",
        "$env:LOCALAPPDATA\Programs\claude\claude.exe",
        "$env:USERPROFILE\AppData\Roaming\npm\claude.cmd",
        "$env:USERPROFILE\scoop\shims\claude.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { $claudePath = $p; break }
    }
}

if (-not $claudePath) {
    Write-Log "Claude Code CLI not found" "ERROR"
    Write-Log "=== Runner failed (CLI not found) ===" "ERROR"
    exit 1
}

Write-Log "Using claude: $claudePath" "INFO"

# Build prompt
$outputPath = $outputDir.Replace('\', '/')
$basePrompt = @"
今日是 $today。请随机挑选一个有趣、准确、不太为人知的 AI（人工智能 / 机器学习 / 深度学习 / 大语言模型）小知识，用中英双语讲解。

要求：
- 只写一条知识
- 先写中文部分（100~200 字），通俗易懂，最好配一个具体例子或有趣的冷知识
- 再写对应的英文部分（English version），内容一致、简洁地道
- 标题用「## Daily AI Knowledge / 每日 AI 小知识」
- 结构：标题 → 中文段 → 英文段

保存到：$outputPath/AI小知识_$today.md
"@
$prompt = $basePrompt

$promptLength = $prompt.Length
Write-Log "Prompt length: $promptLength chars" "INFO"

# Invoke Claude Code with retry
Write-Log "Invoking Claude Code..." "INFO"

$retryDelays = @(1, 2, 3, 5)  # minutes: 1, 2, 3, 5
$attempt = 0
$success = $false
$output = $null
$exitCode = -1

foreach ($delayMinutes in $retryDelays) {
    $attempt++
    Write-Log "Attempt $attempt of $($retryDelays.Count)..." "INFO"

    try {
        # Pass prompt directly as argument — piping to claude.ps1 does NOT forward stdin to claude.exe
        # --dangerously-skip-permissions: -p mode cannot prompt for WebSearch/Write approval, so bypass is required for automation
        # --model: specify which model to use (glm-4.7 in this case)
        $output = & $claudePath --model glm-4.7 --dangerously-skip-permissions -p $prompt 2>&1
        $exitCode = $LASTEXITCODE

        Write-Log "Claude exit code: $exitCode" "INFO"

        if ($exitCode -eq 0) {
            Write-Log "Claude executed successfully" "INFO"
            $success = $true
            break
        } else {
            Write-Log "Claude exited with code: $exitCode" "WARN"
        }

        $outputLines = $output -split "`n"
        if ($outputLines.Count -gt 50) {
            $output = ($outputLines | Select-Object -Last 50) -join "`n"
        }
        Add-Content -Path $logFile -Value "--- Claude Output (last 50 lines) ---" -Encoding UTF8
        $output | Out-File -FilePath $logFile -Append -Encoding UTF8
    } catch {
        Write-Log "Claude invocation failed: $_" "ERROR"
    }

    if (-not $success -and $attempt -lt $retryDelays.Count) {
        $nextDelay = $retryDelays[$attempt]
        Write-Log "Retrying in $nextDelay minute(s)..." "INFO"
        Start-Sleep -Seconds ($nextDelay * 60)
    }
}

if (-not $success) {
    Write-Log "=== Runner failed after $attempt attempts ===" "ERROR"
    exit 1
}

# Verify output
if (Test-Path $outputFile) {
    $size = (Get-Item $outputFile).Length
    $content = Get-Content $outputFile -Raw -Encoding UTF8
    Write-Log "SUCCESS: Output file created" "INFO"
    Write-Log "Path: $outputFile" "INFO"
    Write-Log "Size: $size bytes" "INFO"

    if ($content -match "AI 小知识") {
        Write-Log "Content validation: PASSED" "INFO"
        Write-Log "=== Runner completed (SUCCESS) ===" "INFO"
        exit 0
    } else {
        Write-Log "Content validation: FAILED" "WARN"
        Write-Log "=== Runner completed with warnings ===" "WARN"
        exit 0
    }
} else {
    Write-Log "Output file not found" "ERROR"
    Write-Log "=== Runner failed ===" "ERROR"
    exit 1
}
