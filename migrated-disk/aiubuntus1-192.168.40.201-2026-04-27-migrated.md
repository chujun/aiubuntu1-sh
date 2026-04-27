# /root 目录软链接迁移清单

## 概述

本清单记录 `/root` 目录下所有软链接的迁移信息，将原本占用根分区空间的目录迁移至 `/data` 目录。

**迁移时间**: 2026-04-27

- **软链接总数**: 13

## 软链接迁移清单

| 序号 | 原始路径 (/root) | 目标路径 (/data) | 大小 | 说明 |
|------|------------------|------------------|------|------|
| 1 | `/root/.cache` | `/data/user-config/root-cache` | 0 | 用户缓存目录 |
| 2 | `/root/.wdm` | `/data/user-config/.wdm` | 0 | WebDriver Manager 配置 |
| 3 | `/root/.claude` | `/data/claude/claude_root` | 0 | Claude Code 配置 |
| 4 | `/root/venv` | `/data/venvs/root-venv` | 0 | Python 虚拟环境 |
| 5 | `/root/.nvm` | `/data/user-config/.nvm` | 0 | Node 版本管理器 |
| 6 | `/root/.opencode` | `/data/user-config/.opencode` | 0 | OpenCode 编辑器配置 |
| 7 | `/root/.bun` | `/data/user-config/.bun` | 0 | Bun runtime 配置 |
| 8 | `/root/ai` | `/data/ai` | 0 | AI 相关配置和数据 |
| 9 | `/root/.local` | `/data/user-config/.local` | 0 | 用户本地应用配置 |
| 10 | `/root/playwright-venv` | `/data/venvs/playwright-venv` | 0 | Playwright 测试虚拟环境 |
| 11 | `/root/stock-quant-strategy-venv` | `/data/venvs/stock-quant-strategy-venv` | 0 | 量化交易策略虚拟环境 |
| 12 | `/root/.paddlex` | `/data/cache/.paddlex` | 0 | PaddleX 机器学习模型 |
| 13 | `/root/.npm` | `/data/user-config/.npm` | 0 | npm 包管理配置及缓存 |

## 注意事项

1. **user-config/** 目录包含重要用户配置，不建议随意清理
2. **venv** 目录包含 Python 虚拟环境，清理前请确认不再使用
3. **cache/** 目录包含可重新下载的缓存（如模型、缓存包），可按需清理
4. 软链接损坏时可使用 `readlink -f /root/<path>` 检查目标是否存在
