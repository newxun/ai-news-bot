# AI News Bot - GitHub Actions + GLM Coding Plan

每天早上 6:25 自动收集 AI 新闻，通过 Claude Code (GLM Coding Plan) 汇总后推送到 Telegram。

电脑关机也能跑，完全免费。

## 快速部署

### 1. 创建 GitHub 私有仓库

```bash
# 在 GitHub 上创建一个 PRIVATE 仓库，比如 ai-news-bot
git init
git add .
git commit -m "Initial commit"
git remote add origin git@github.com:你的用户名/ai-news-bot.git
git push -u origin main
```

### 2. 配置 GitHub Secrets

在仓库 Settings → Secrets and variables → Actions 中添加 3 个 Secret：

| Secret 名称 | 值 | 说明 |
|---|---|---|
| `GLM_API_KEY` | 你的 GLM Coding Plan API Key | 智谱开放平台的 API Key |
| `TELEGRAM_BOT_TOKEN` | 你的 Telegram Bot Token | 形如 `123456:ABC-DEF...` |
| `TELEGRAM_CHAT_ID` | 你的 Chat ID | 数字，如 `123456789` |

### 3. 测试运行

在仓库的 Actions 页面：
1. 点击 "Daily AI News Digest" workflow
2. 点击 "Run workflow" 手动触发一次测试
3. 查看运行日志确认结果

### 4. 确认定时触发

workflow 已配置 cron `25 22 * * *` (UTC)，对应北京时间 06:25。

> ⚠️ GitHub Actions 定时任务可能有 5-30 分钟延迟（免费账户优先级较低），实际触发时间通常在 6:25-7:00 之间。

## 自定义

### 修改新闻来源
编辑 `prompt.md`，添加或修改 curl 命令的数据源。

### 修改推送时间
编辑 `.github/workflows/daily-news.yml` 中的 cron 表达式：
```
# 格式: 分 时 日 月 周 (UTC时间)
# 北京时间 = UTC + 8
# 示例: 每天 8:00 CST = 00:00 UTC
- cron: '00 00 * * *'
```

### 修改摘要格式
编辑 `prompt.md` 中的模板部分。
