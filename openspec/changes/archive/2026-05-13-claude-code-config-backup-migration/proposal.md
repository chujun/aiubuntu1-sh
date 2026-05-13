## Why

Claude Code 的配置数据（settings.json、skills、rules、项目记忆、会话历史等）目前存储在本地 ~/.claude/ 目录，缺乏持久化和跨设备同步能力。一旦本地磁盘损坏或需要切换到新系统，这些数据将丢失或需要手动重建。通过将配置同步到 GitHub 私有仓库，可以实现永久存储和跨系统迁移。

## What Changes

1. **一键初始化脚本** - 在首次使用时创建 GitHub 私有仓库并配置本地同步
2. **自动化后台同步** - 每次退出 Claude Code 时自动将配置备份到 GitHub
3. **访问权限校验** - 同步前检查目标仓库是否为私有，公开仓库拒绝同步以防止敏感信息泄露
4. **异步执行机制** - 同步在后台执行，不阻塞 Claude Code 退出流程
5. **增量同步策略** - 使用 git 管理变更，只同步有变化的文件
6. **一键迁移脚本** - 在新系统上执行脚本，还原所有配置到新环境

## Capabilities

### New Capabilities

- `config-backup`: Claude Code 配置备份到 GitHub 私有仓库
  - 备份内容包括 settings.json、AGENTS.md、rules/、skills/、memory/、hooks/、mcp-configs/、projects/
  - 后台异步执行，不阻塞退出
  - 网络失败时记录日志并下次重试
- `config-restore`: 从 GitHub 恢复配置到新系统
  - 一键脚本拉取仓库并还原配置
  - 支持选择性恢复（部分目录或全部）
- `repo-access-control`: 仓库访问权限校验
  - 同步前通过 GitHub API 校验仓库可见性
  - 拒绝同步到公开仓库，防止敏感信息泄露

## Impact

- **新增文件**: 同步脚本 (~/.claude/scripts/)、初始化脚本、恢复脚本
- **修改配置**: Claude Code 退出钩子配置
- **依赖**: GitHub CLI (gh)、git、rsync
- **外部系统**: GitHub API（用于校验仓库可见性）
