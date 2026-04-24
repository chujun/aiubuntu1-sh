---
name: my-skills-sync
description: 自动同步 Claude Code 自定义技能（my-* 打头的 skill）到本地目录，支持文件监听实时同步和 systemd 服务开机自启动。
origin: local
version: "1.1.0"
updated: "2026-04-24"
---

# My Skills Sync

自动同步 Claude Code 自定义技能（`my-*` 打头的 skill）到本地目录，支持文件监听实时同步和 systemd 服务开机自启动。

## 背景

当用户在多台设备使用 Claude Code 或需要统一管理自定义技能时，需要将 `~/.claude/skills/` 下的 `my-*` 技能同步到项目目录。本技能提供：

- **手动同步**：一键同步所有 my-* skills 到本地
- **实时监控**：inotifywait 监听文件变化，自动同步
- **开机自启**：systemd 服务，开机自动启动监控

## 使用场景

- 多设备同步自定义技能到统一目录
- 将自定义技能纳入 Git 版本管理
- 本地备份 Claude Code 自定义技能
- 开源自定义技能到 GitHub

## 目录结构

```
my-skills/
├── my-skills-sync/              # 技能主目录
│   ├── SKILL.md                 # 技能定义文档
│   ├── sync-skills.sh           # 同步脚本
│   ├── watch-skills.sh          # 监控脚本
│   ├── my-skills-sync.service   # systemd 服务文件
│   ├── sync.log                 # 同步日志
│   ├── watch.log                # 监控日志
│   └── watch.pid               # 监控进程 PID
├── my-explore-doc-record/       # 其他自定义技能
└── my-fix-claude-code-viewer/
```

## 快速开始

### 1. 安装依赖

```bash
# Ubuntu/Debian
sudo apt install inotify-tools rsync

# CentOS/RHEL
sudo yum install inotify-tools rsync
```

### 2. 手动同步

```bash
cd my-skills/my-skills-sync
bash sync-skills.sh
```

### 3. 启动监控

```bash
bash watch-skills.sh start
```

### 4. 配置开机自启（可选）

```bash
sudo cp my-skills-sync.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable my-skills-sync.service
sudo systemctl start my-skills-sync.service
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `bash sync-skills.sh` | 手动执行一次同步 |
| `bash watch-skills.sh start` | 启动后台监控 |
| `bash watch-skills.sh stop` | 停止后台监控 |
| `bash watch-skills.sh restart` | 重启监控 |
| `bash watch-skills.sh status` | 查看监控状态 |
| `bash watch-skills.sh sync` | 手动触发同步 |

## 核心脚本

### sync-skills.sh

同步脚本，将 `~/.claude/skills/my-*` 同步到本地目录。

**功能：**
- 自动发现所有 `my-*` 开头的 skill
- 使用 rsync 增量同步
- 生成同步日志到 `sync.log`

**核心逻辑：**
```bash
SOURCE_DIR="$HOME/.claude/skills"
TARGET_DIR="$(cd "$(dirname "$0")" && pwd)"

# 获取所有 my- 开头的 skill
my_skills=$(find "$SOURCE_DIR" -maxdepth 1 -type d -name "my-*" | xargs -r basename -a)

for skill in $my_skills; do
    rsync -avz --delete "$SOURCE_DIR/$skill/" "$TARGET_DIR/$skill/"
done
```

### watch-skills.sh

监控脚本，使用 inotifywait 监听文件变化并自动同步。

**功能：**
- 首次启动自动执行同步
- 监听 `~/.claude/skills/my-*` 目录下所有文件变化
- 后台运行，PID 文件管理
- 支持 start/stop/restart/status/sync 命令

**核心逻辑：**
```bash
inotifywait -m -r \
    --exclude '(\.git|swp|swo)' \
    -e modify,create,delete,move \
    "$SOURCE_DIR" | while read path action file; do

    if echo "$path" | grep -q "my-"; then
        bash "$(dirname "$0")/sync-skills.sh"
    fi
done
```

## systemd 服务配置

### 服务文件内容

```ini
[Unit]
Description=My Skills Sync Service - Sync my-* skills to local directory
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=/root/sh/my-skills/my-skills-sync
ExecStart=/root/sh/my-skills/my-skills-sync/watch-skills.sh start
ExecStop=/root/sh/my-skills/my-skills-sync/watch-skills.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 服务管理命令

```bash
# 查看状态
sudo systemctl status my-skills-sync

# 停止服务
sudo systemctl stop my-skills-sync

# 启动服务
sudo systemctl start my-skills-sync

# 重启服务
sudo systemctl restart my-skills-sync

# 禁用开机自启
sudo systemctl disable my-skills-sync
```

## 工作原理

```
┌─────────────────┐    监听变化     ┌─────────────────┐
│ ~/.claude/skills │ ──────────────► │  inotifywait    │
│     /my-*        │                │  (后台进程)      │
└─────────────────┘                └────────┬────────┘
                                            │
                                            │ 触发同步
                                            ▼
                                   ┌─────────────────┐
                                   │  sync-skills.sh │
                                   └────────┬────────┘
                                            │
                                            │ rsync 增量同步
                                            ▼
                                   ┌─────────────────┐
                                   │  ./my-skills/   │
                                   │   /my-*         │
                                   └─────────────────┘
```

1. `inotifywait` 监听 `~/.claude/skills/my-*` 目录下的所有文件变化
2. 检测到变化后，自动触发 `sync-skills.sh`
3. `sync-skills.sh` 使用 rsync 增量同步到本地 `my-skills/` 目录
4. 同步日志写入 `sync.log` 和 `watch.log`

## 日志文件

- `sync.log` - 同步操作日志
- `watch.log` - 监控进程日志

查看日志：
```bash
tail -f sync.log
tail -f watch.log
```

## 依赖要求

- **Linux 内核**：需要 inotify 支持（Ubuntu/Debian/CentOS 等）
- **软件包**：
  - `inotify-tools`（提供 inotifywait）
  - `rsync`（已预装）

## 开源发布

发布到 GitHub 前请确保：

1. **移除敏感信息**：检查 skill 目录是否包含 API keys、tokens 等
2. **添加 LICENSE**：选择合适的开源协议
3. **Git 提交**：
   ```bash
   git add my-skills/my-skills-sync/
   git commit -m "feat: 添加 my-skills-sync 技能"
   git push origin main
   ```

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.2.0 | 2026-04-24 | 简化结构，移除符号链接，使用完整路径运行脚本 |
| 1.1.0 | 2026-04-24 | 修复服务路径问题，通过符号链接解决脚本位置与 systemd WorkingDirectory 不一致的问题 |
| 1.0.0 | 2026-04-13 | 初始版本，包含同步、监控、systemd 服务 |

## 输出示例

```
✅ 同步完成
  已同步: my-explore-doc-record
  已同步: my-fix-claude-code-viewer
```
