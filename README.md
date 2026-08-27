# AI News Projects

这个仓库包含两个 AI 新闻自动化项目。

---

## AI News Scheduler (Windows)

自动化 AI 新闻抓取系统，基于 Windows 任务计划程序和 GitHub Actions。

### 功能特点

- 每日自动监控 GitHub Actions 工作流完成状态
- 工作流完成后延迟指定小时数触发 AI 新闻搜索
- 使用 Claude Code CLI 搜索过去 24 小时内最重要的 AI 新闻
- 自动保存到指定目录，文件名格式：`AI新闻_YYYY-MM-DD.md`
- 完整的日志记录，支持幂等性和重复执行保护

### 文件说明

- **scripts/scheduler.ps1** - 核心调度器，查询 GitHub Actions 并注册一次性任务
- **scripts/runner.ps1** - 执行器，调用 Claude Code 进行新闻搜索
- **scripts/register-task.ps1** - 在 Windows 任务计划程序中注册每日任务
- **scripts/view-logs.ps1** - 日志查看工具，显示执行状态摘要
- **scripts/config.ps1** - 配置文件模板
- **scripts/config.local.ps1** - 本地配置文件（需要自行创建，不要提交到版本控制）

### 安装步骤

1. 创建配置文件：`cp scripts/config.ps1 scripts/config.local.ps1`
2. 创建 GitHub Token：访问 https://github.com/settings/tokens
3. 编辑 `scripts/config.local.ps1`，设置你的 GitHub token
4. 以管理员身份运行：`.\scripts\register-task.ps1`

### 时间计算说明

**重要**：系统使用任务完成时间（而非开始时间）来计算日期。这意味着：

- 文件名中的日期基于 Claude Code 执行完成时的北京时间
- 如果任务在跨午夜时完成，文件名会反映实际的完成日期
- 日志文件同样使用完成时间命名

### 日志文件

日志保存在 `~\.ai-news-scheduler\` 目录：
- `scheduler-YYYY-MM-DD.log` - 调度器日志
- `runner-YYYY-MM-DD.log` - 执行器日志（使用完成时间命名）
- `scheduled-YYYY-MM-DD.txt` - 调度标记文件

---

## AI News Bot (GitHub Actions)

每天早上 6:37 自动收集 AI 新闻，通过 Claude Code (GLM Coding Plan) 汇总后归档到仓库 `digests/` 目录。

### 快速部署

1. 在 GitHub 上创建一个 PRIVATE 仓库
2. 配置 GitHub Secrets（GLM_API_KEY）
3. 测试运行：在 Actions 页面手动触发 workflow
4. 确认定时触发：cron `37 22 * * *` (UTC)，对应北京时间 06:37

### 自定义

- 修改新闻来源：编辑 `prompt.md`
- 修改推送时间：编辑 `.github/workflows/daily-news.yml`
- 修改摘要格式：编辑 `prompt.md` 中的模板部分