# AI News Scheduler

自动化 AI 新闻抓取系统，基于 Windows 任务计划程序和 GitHub Actions。

## 功能特点

- 每日自动监控 GitHub Actions 工作流完成状态
- 工作流完成后延迟指定小时数触发 AI 新闻搜索
- 使用 Claude Code CLI 搜索过去 24 小时内最重要的 AI 新闻
- 自动保存到指定目录，文件名格式：`AI新闻_YYYY-MM-DD.md`
- 完整的日志记录，支持幂等性和重复执行保护

## 文件说明

- **scheduler.ps1** - 核心调度器，查询 GitHub Actions 并注册一次性任务
- **runner.ps1** - 执行器，调用 Claude Code 进行新闻搜索
- **register-task.ps1** - 在 Windows 任务计划程序中注册每日任务
- **view-logs.ps1** - 日志查看工具，显示执行状态摘要
- **config.ps1** - 配置文件模板
- **config.local.ps1** - 本地配置文件（需要自行创建，不要提交到版本控制）

## 安装步骤

### 1. 创建配置文件

复制 `config.ps1` 为 `config.local.ps1` 并填写你的设置：

```powershell
cp config.ps1 config.local.ps1
```

编辑 `config.local.ps1`，设置你的 GitHub token：

```powershell
@{
    GithubToken = "ghp_xxxxxxxxxxxxxxxxxxxx"  # 你的 GitHub token
    Repo = "newxun/ai-news-bot"              # 监控的仓库
    OutputDir = "D:\存档\AI新闻"              # 输出目录
    TimezoneId = "China Standard Time"        # 时区
    DelayHours = 5                           # 延迟小时数
}
```

### 2. 创建 GitHub Token

访问 https://github.com/settings/tokens 创建新的 Personal Access Token (classic)：
- 勾选 `repo` -> `public_repo` 权限
- 复制 token 到 `config.local.ps1`

### 3. 注册 Windows 任务

以管理员身份运行 PowerShell：

```powershell
.\register-task.ps1
```

这会注册一个每日任务，每天上午 10:00 运行调度器。

### 4. 手动测试

可以直接运行调度器测试：

```powershell
.\scheduler.ps1
```

或运行执行器测试：

```powershell
.\runner.ps1
```

## 查看执行状态

使用日志查看工具：

```powershell
.\view-logs.ps1
```

这会显示：
- 今天的调度器和执行器状态
- 输出文件状态
- 最近 7 天的执行历史

## 日志文件

日志保存在 `~\.ai-news-scheduler\` 目录：

- `scheduler-YYYY-MM-DD.log` - 调度器日志
- `runner-YYYY-MM-DD.log` - 执行器日志
- `scheduled-YYYY-MM-DD.txt` - 调度标记文件

## 工作流程

1. 每天上午 10:00，Windows 任务计划程序运行 `scheduler.ps1`
2. 调度器查询 GitHub Actions API，获取最新工作流完成时间
3. 计算目标时间 = 完成时间 + 延迟小时数
4. 如果目标时间已过，立即运行执行器
5. 否则，注册一次性任务在目标时间运行执行器
6. 执行器调用 Claude Code 搜索 AI 新闻并保存文件

## 状态标记

日志中的状态标记：

- **[SUCCESS]** - 执行成功
- **[SKIPPED]** - 已完成，跳过重复执行
- **[WAITING]** - 等待条件满足
- **[WARNING]** - 执行有警告
- **[ERROR]** - 执行失败
- **[INFO]** - 信息性消息

## 故障排除

### GitHub API 错误

检查：
- Token 是否正确设置
- Token 是否有 `public_repo` 权限
- 网络连接是否正常

### Claude Code 未找到

确保：
- Claude Code CLI 已安装并在 PATH 中
- 或使用已知的安装路径

### 输出文件未创建

检查：
- 执行器日志中的 Claude 输出
- Claude Code 是否正常运行
- 输出目录是否有写权限

## 卸载

删除 Windows 任务：

```powershell
Unregister-ScheduledTask -TaskName "AINewsScheduler" -Confirm:$false
```

删除所有一次性任务：

```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like "AINewsRunner_*" } | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false
}
```

## 注意事项

- `config.local.ps1` 包含敏感信息，不要提交到版本控制
- 确保输出目录存在且有写权限
- 时区设置使用 Windows 时区 ID
