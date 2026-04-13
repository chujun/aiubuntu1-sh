# my-skills-sync

自动同步 Claude Code 自定义技能（`my-*` 打头的 skill）到本地目录，支持文件监听实时同步和 systemd 服务开机自启动。

## 功能特性

- **手动同步**：一键同步所有 `my-*` skills 到本地目录
- **实时监控**：inotifywait 监听文件变化，自动同步
- **后台运行**：后台进程管理，支持 PID 文件
- **开机自启**：systemd 服务配置，开机自动启动监控

## 系统要求

- Linux 内核（支持 inotify）
- `inotify-tools`
- `rsync`

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt install inotify-tools rsync

# CentOS/RHEL
sudo yum install inotify-tools rsync
```

## 快速开始

### 1. 进入技能目录

```bash
cd my-skills/my-skills-sync
```

### 2. 手动同步

```bash
./sync-skills.sh
```

### 3. 启动监控

```bash
./watch-skills.sh start
```

### 4. 验证状态

```bash
./watch-skills.sh status
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `./sync-skills.sh` | 手动执行一次同步 |
| `./watch-skills.sh start` | 启动后台监控 |
| `./watch-skills.sh stop` | 停止后台监控 |
| `./watch-skills.sh restart` | 重启监控 |
| `./watch-skills.sh status` | 查看监控状态 |
| `./watch-skills.sh sync` | 手动触发同步 |

## systemd 服务（可选）

### 安装

```bash
# 复制服务文件
sudo cp my-skills-sync.service /etc/systemd/system/

# 重新加载 systemd
sudo systemctl daemon-reload

# 启用开机自启动
sudo systemctl enable my-skills-sync.service

# 启动服务
sudo systemctl start my-skills-sync.service
```

### 管理命令

```bash
sudo systemctl status my-skills-sync   # 查看状态
sudo systemctl stop my-skills-sync     # 停止服务
sudo systemctl start my-skills-sync    # 启动服务
sudo systemctl restart my-skills-sync  # 重启服务
sudo systemctl disable my-skills-sync  # 禁用开机自启
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

## 目录结构

```
my-skills/
├── my-skills-sync/           # 本技能目录
│   ├── SKILL.md             # 技能定义文档
│   ├── README.md            # 本文档
│   ├── sync-skills.sh       # 同步脚本
│   ├── watch-skills.sh      # 监控脚本
│   └── my-skills-sync.service # systemd 服务文件
├── my-explore-doc-record/    # 其他自定义技能
└── my-fix-claude-code-viewer/
```

## 日志文件

- `sync.log` - 同步操作日志
- `watch.log` - 监控进程日志

查看日志：
```bash
tail -f sync.log
tail -f watch.log
```

## 开源发布

如需开源到 GitHub：

1. 确保不包含敏感信息（API keys、tokens 等）
2. 选择开源协议（推荐 AGPLv3 或 MIT）
3. 添加 LICENSE 文件
4. Git 提交并推送

```bash
git add my-skills/my-skills-sync/
git commit -m "feat: 添加 my-skills-sync 技能"
git push origin main
```

## License

MIT License
