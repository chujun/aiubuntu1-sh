# /root 目录软链接迁移清单

## 概述

本清单记录 `/root` 目录下所有软链接的迁移信息，将原本占用根分区空间的目录迁移至 `/data/migrate-root/` 目录。

**迁移时间**: 2026-04-27

- **软链接总数**: 13
- **总迁移大小**: 约 13.5G

## 软链接迁移清单

| 序号 | 原始路径 (/root) | 目标路径 (/data/migrate-root) | 大小 | 说明 |
|------|------------------|------------------------------|------|------|
| 1 | `/root/.npm` | `/data/migrate-root/user-config/.npm` | 2.1G | npm 包管理配置及缓存 |
| 2 | `/root/.nvm` | `/data/migrate-root/user-config/.nvm` | 1.1G | Node 版本管理器 |
| 3 | `/root/ai` | `/data/migrate-root/ai` | 3.0G | AI 相关配置和数据 |
| 4 | `/root/.cache` | `/data/migrate-root/user-config/root-cache` | 351M | 用户缓存目录 |
| 5 | `/root/stock-quant-strategy-venv` | `/data/migrate-root/venvs/stock-quant-strategy-venv` | 560M | 量化交易策略虚拟环境 |
| 6 | `/root/.paddlex` | `/data/migrate-root/cache/.paddlex` | 2.6G | PaddleX 机器学习模型 |
| 7 | `/root/venv` | `/data/migrate-root/venvs/root-venv` | 450M | Python 虚拟环境 |
| 8 | `/root/playwright-venv` | `/data/migrate-root/venvs/playwright-venv` | 309M | Playwright 测试虚拟环境 |
| 9 | `/root/.local` | `/data/migrate-root/user-config/.local` | 496M | 用户本地应用配置 |
| 10 | `/root/.opencode` | `/data/migrate-root/user-config/.opencode` | 160M | OpenCode 编辑器配置 |
| 11 | `/root/claude` | `/data/migrate-root/claude/claude_root` | 376M | Claude Code 配置 |
| 12 | `/root/.wdm` | `/data/migrate-root/user-config/.wdm` | 51M | WebDriver Manager 配置 |
| 13 | `/root/.bun` | `/data/migrate-root/user-config/.bun` | 34M | Bun runtime 配置 |

## 目标目录结构

```
/data/migrate-root/
├── user-config/           # 用户配置目录 (约 4.2G)
│   ├── .npm/             # npm 缓存
│   ├── .nvm/             # Node 版本管理
│   ├── .local/           # 本地应用配置
│   ├── .opencode/        # OpenCode 配置
│   ├── .wdm/             # WebDriver Manager
│   ├── .bun/             # Bun runtime
│   └── root-cache/       # 通用缓存
├── ai/                   # AI 相关 (3.0G)
├── venvs/                # Python 虚拟环境 (约 1.3G)
│   ├── root-venv/
│   ├── playwright-venv/
│   └── stock-quant-strategy-venv/
├── cache/                # 缓存目录 (约 2.6G)
│   └── .paddlex/
└── claude/
    └── claude_root/      # Claude Code 配置 (376M)
```

## 注意事项

1. **user-config/** 目录包含重要用户配置，不建议随意清理
2. **venv** 目录包含 Python 虚拟环境，清理前请确认不再使用
3. **cache/** 目录包含可重新下载的缓存（如模型、缓存包），可按需清理
4. 软链接损坏时可使用 `readlink -f /root/<path>` 检查目标是否存在
5. 所有软链接均已验证正常工作
