# AI News Bot

本项目使用 Claude Code + GLM Coding Plan 在 GitHub Actions 上定时运行，每天早上 6:37 (CST) 自动收集并汇总过去 24 小时的 AI 新闻，推送到 Telegram。

## 时间计算方式

**重要**：系统使用任务完成时间（而非开始时间）来计算日期和文件命名。这意味着：

- 所有日期计算基于 Claude Code 执行完成时的北京时间
- 如果任务在跨午夜时完成，文件名会反映实际的完成日期
- GitHub Actions 的触发时间与文件日期可能不同

## 环境变量

- `ANTHROPIC_BASE_URL` - GLM Anthropic 兼容端点
- `ANTHROPIC_AUTH_TOKEN` - GLM API Key
- `ANTHROPIC_MODEL` - 主模型 (glm-4.7)
- `TELEGRAM_BOT_TOKEN` - Telegram Bot Token（仅发送步骤使用）
- `TELEGRAM_CHAT_ID` - 目标 Chat ID（仅发送步骤使用）

## 运行方式

GitHub Actions 定时触发，或通过 workflow_dispatch 手动触发。