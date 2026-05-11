## Context

Claude Code 的配置数据存储在 `~/.claude/` 目录，包括：
- 配置文件：`settings.json`、`AGENTS.md`
- 规则和技能：`rules/`、`skills/`
- 个人数据：`memory/`、`hooks/`、`mcp-configs/`
- 项目数据：`projects/`（包含会话历史）

当前无持久化机制，本地磁盘损坏或切换系统时需手动重建。

## Goals / Non-Goals

**Goals:**
- 实现 Claude Code 配置的自动备份到 GitHub 私有仓库
- 支持一键在新系统上恢复配置
- 备份过程不阻塞 Claude Code 正常使用
- 确保敏感配置（API token）不会泄露到公开仓库

**Non-Goals:**
- 不实现实时同步（仅在退出时触发）
- 不支持多设备冲突自动合并（假设单设备使用）
- 不备份源码（只备份 Claude Code 自身配置）

## Decisions

### 1. 备份仓库与源目录关系

**决策**: 直接在 `~/.claude/` 目录初始化 git 仓库

不使用独立的备份目录，直接将 `~/.claude/` 作为 git 仓库管理。

```bash
cd ~/.claude
git init
git remote add origin git@github.com:user/repo.git
```

**替代方案**:
- 独立备份目录（~/.claude-config-backup/）：需要 rsync 同步两份目录，增加复杂度和存储空间

### 2. 同步触发机制

**决策**: 使用 SessionEnd 钩子触发同步

Claude Code 的 SessionEnd 钩子在会话结束时触发，专门用于生命周期管理。

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "type": "command",
        "command": "~/.claude/scripts/backup.sh"
      }
    ]
  }
}
```

**替代方案**:
- PreToolUse/PostToolUse：触发太频繁，不适合耗时操作
- Stop 钩子：每次响应都触发，过于频繁
- 定时同步（cron）：无法确保在退出时立即备份

### 3. 增量同步策略

**决策**: 直接使用 git 管理增量同步

```bash
cd ~/.claude
git add -A
git status --short  # 快速检查是否有变化
git commit -m "Backup: $(date)"
git pull --rebase origin main  # 尝试自动合并
git push origin main
```

git 自动处理新增、修改、删除文件的差异。

**替代方案**:
- rsync 增量复制：需额外跟踪已同步文件列表，增加复杂度

### 4. 冲突处理策略

**决策**: 先 pull 再 push，冲突无法解决时提示用户手动处理

```bash
git pull --rebase origin main
if [ $? -ne 0 ]; then
    # 冲突无法自动解决
    echo "[$(date)] Sync FAILED: unresolved conflicts - manual intervention required" >> ~/.claude/backups/sync.log
    exit 1
fi
git push origin main
```

**场景处理**:
- 自动合并成功：直接 push
- 冲突可自动解决（同一文件不同部分）：rebase 自动处理
- 冲突无法自动解决：记录日志，提示用户手动解决后再同步

### 5. 仓库可见性校验

**决策**: 通过 `gh api` 查询仓库可见性，拒绝同步到公开仓库

```bash
is_private=$(gh api repos/{owner}/{repo} --jq '.private')
if [ "$is_private" = "false" ]; then
    echo "ERROR: Refusing to sync to PUBLIC repository"
    exit 1
fi
```

### 6. 异步执行

**决策**: SessionEnd 钩子中直接执行脚本，脚本内部处理失败情况

SessionEnd 本身不阻塞，但不等待脚本完成。脚本内部：
- 成功：记录 OK 日志
- 失败：记录 FAIL 日志，下次再试
- 冲突无法解决：记录警告，提示用户

### 7. 敏感信息处理

**决策**: 明文存储到私有仓库

settings.json 中的 `ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_BASE_URL` 直接同步，不做脱敏处理。

**理由**: 私有仓库具有访问控制，暴露风险可控。脱敏会增加迁移复杂度。

## Risks / Trade-offs

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 网络故障导致同步失败 | 备份不完整 | 失败写日志，下次成功时补发 |
| GitHub API 限流 | 校验失败 | 添加重试机制 |
| 仓库名称冲突 | 初始化失败 | 引导用户选择其他名称 |
| 首次初始化需认证 | 用户操作复杂 | 提供清晰的引导流程 |
| 多设备同时同步 | 冲突 | 先 pull 再 push，无法解决时提示用户 |

## Migration Plan

### 首次安装

1. 用户运行初始化脚本 `init-backup.sh`
2. 脚本检查 `gh` CLI 是否安装并登录
3. 提示用户输入仓库名称（默认 `claude-config-backup`）
4. 创建 GitHub 私有仓库
5. 在 `~/.claude/` 初始化 git 仓库
6. 添加远程仓库并执行首次推送
7. 配置 SessionEnd 钩子

### 恢复（迁移到新系统）

1. 用户在新系统上运行恢复脚本 `restore-backup.sh`
2. 脚本检查 `gh` CLI 并确认仓库访问权限
3. 克隆仓库到临时目录
4. 复制配置到 `~/.claude/` 覆盖现有文件
5. 配置 SessionEnd 钩子
6. 保留 .git 目录以便后续同步

## Open Questions

1. **备份频率**: 对于 `projects/` 中的大文件，是否需要限制同步频率或压缩？
2. **清理策略**: 会话历史无限增长，是否需要归档策略？
