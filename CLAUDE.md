# AI News Bot

本项目使用 Claude Code + GLM Coding Plan 在 GitHub Actions 上定时运行，每天早上 6:00 (CST) 自动收集并汇总过去 24 小时的 AI 新闻，推送到 Telegram。

模型生成 `digests/YYYY-MM-DD.md`（并复制到 `output/digest.txt`）；workflow 负责提交到仓库，并独立完成 Telegram 推送。

## 环境变量

- `ANTHROPIC_BASE_URL` - GLM Anthropic 兼容端点
- `ANTHROPIC_AUTH_TOKEN` - GLM API Key
- `ANTHROPIC_MODEL` - 主模型 (glm-4.7)
- `TELEGRAM_BOT_TOKEN` - Telegram Bot Token（仅发送步骤使用）
- `TELEGRAM_CHAT_ID` - 目标 Chat ID（仅发送步骤使用）

## 运行方式

GitHub Actions 定时触发，或通过 workflow_dispatch 手动触发。
