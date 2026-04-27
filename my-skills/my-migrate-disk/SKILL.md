# My Migrate Disk

将根目录磁盘空间迁移到扩展数据磁盘的技能，通过软链接方式解决根分区空间不足的问题。

## 功能概述

1. **诊断分析** - 检查磁盘空间使用情况，找出占用空间大的目录
2. **智能分类** - 区分用户配置（重要）和缓存（可清理）
3. **安全迁移** - 迁移目录到 /data 并创建软链接
4. **验证测试** - 验证迁移后所有命令正常工作
5. **清单生成** - 生成迁移报告文档

## 目录分类

### 用户配置目录（重要，不清理）

| 目录 | 说明 |
|------|------|
| `.npm` | npm 包管理配置 |
| `.nvm` | Node 版本管理器 |
| `.local` | 用户本地配置 |
| `.opencode` | OpenCode 配置 |
| `.wdm` | WebDriverManager |
| `.bun` | Bun runtime 配置 |
| `ai` | AI 相关数据 |
| `venv` | Python 虚拟环境 |
| `.claude` | Claude Code 配置 |

### 缓存目录（可清理）

| 目录 | 说明 |
|------|------|
| `.paddlex` | PaddleX 模型（可重新下载） |
| `.huggingface_cache` | HuggingFace 缓存 |
| `.cache` | 通用缓存 |

### 虚拟环境目录

| 目录 | 说明 |
|------|------|
| `venv` | 主 Python 虚拟环境 |
| `playwright-venv` | Playwright 测试环境 |
| `stock-quant-strategy-venv` | 量化交易环境 |

## 目标目录结构

```
/data/
├── user-config/              # 用户配置数据（重要）
│   ├── .npm
│   ├── .nvm
│   ├── .local
│   ├── .opencode
│   ├── .wdm
│   ├── .bun
│   └── root-cache/
├── ai/                       # AI 数据
├── venvs/                    # Python 虚拟环境
│   ├── root-venv/
│   ├── playwright-venv/
│   └── stock-quant-strategy-venv/
├── claude/                   # Claude 配置
├── cache/                    # 缓存（可清理）
│   ├── .paddlex/
│   ├── .huggingface_cache/
│   └── ms-playwright/
└── logs/                     # 日志
```

## 使用方式

### 诊断磁盘空间

```bash
# 检查根分区空间
df -h /

# 检查各目录大小
du -sh /* 2>/dev/null | sort -hr

# 检查 /root 目录详细占用
du -sh /root/* 2>/dev/null | sort -hr

# 找出所有软链接
ls -la /root/ | grep "^l"
```

### 执行迁移

```bash
# 1. 创建目标目录结构
mkdir -p /data/user-config
mkdir -p /data/venvs
mkdir -p /data/cache

# 2. 迁移用户配置目录
mv /root/.npm /data/user-config/ && ln -s /data/user-config/.npm /root/.npm
mv /root/.nvm /data/user-config/ && ln -s /data/user-config/.nvm /root/.nvm
mv /root/.local /data/user-config/ && ln -s /data/user-config/.local /root/.local
mv /root/.opencode /data/user-config/ && ln -s /data/user-config/.opencode /root/.opencode
mv /root/.wdm /data/user-config/ && ln -s /data/user-config/.wdm /root/.wdm
mv /root/.bun /data/user-config/ && ln -s /data/user-config/.bun /root/.bun

# 3. 迁移虚拟环境
mv /root/venv /data/venvs/root-venv && ln -s /data/venvs/root-venv /root/venv
mv /root/playwright-venv /data/venvs/ && ln -s /data/venvs/playwright-venv /root/playwright-venv
mv /root/stock-quant-strategy-venv /data/venvs/ && ln -s /data/venvs/stock-quant-strategy-venv /root/stock-quant-strategy-venv

# 4. 迁移缓存目录
mv /root/.paddlex /data/cache/ && ln -s /data/cache/.paddlex /root/.paddlex

# 5. 迁移 AI 目录
mv /root/ai /data/ai && ln -s /data/ai /root/ai

# 6. 迁移 Claude 配置
mkdir -p /data/claude
mv /root/.claude /data/claude/claude_root && ln -s /data/claude/claude_root /root/.claude
```

### 验证迁移

```bash
# 检查所有软链接
for link in /root/.npm /root/.nvm /root/.local /root/.cache /root/.opencode /root/.paddlex /root/.wdm /root/.bun /root/.claude /root/ai /root/venv /root/playwright-venv /root/stock-quant-strategy-venv; do
  if [ -e "$link" ]; then
    echo "✓ $link -> $(readlink $link)"
  else
    echo "✗ $link (BROKEN)"
  fi
done

# 测试命令
node --version && npm --version
python3 --version
git --version
```

## 脚本工具

### diagnose.sh - 磁盘诊断

```bash
#!/bin/bash
echo "=== 根分区空间 ==="
df -h /

echo -e "\n=== /root 目录大小 ==="
du -sh /root/* 2>/dev/null | sort -hr

echo -e "\n=== /root 软链接 ==="
ls -la /root/ | grep "^l"

echo -e "\n=== /data 目录大小 ==="
du -sh /data/* 2>/dev/null | sort -hr
```

### migrate.sh - 批量迁移

```bash
#!/bin/bash
# 迁移用户配置
for item in .npm .nvm .local .opencode .wdm .bun; do
  if [ -L "/root/$item" ]; then
    echo "$item 已是软链接，跳过"
  elif [ -d "/root/$item" ]; then
    mv "/root/$item" "/data/user-config/$item"
    ln -s "/data/user-config/$item" "/root/$item"
    echo "迁移 $item"
  fi
done
```

## 注意事项

1. **迁移前备份** - 重要目录迁移前建议备份
2. **按序迁移** - 建议一个目录一个目录迁移，便于排查问题
3. **验证测试** - 每次迁移后验证命令是否正常
4. **软链接断裂** - 使用 `readlink -f /root/<path>` 检查目标是否存在
5. **权限问题** - 确保目标目录权限正确

## 故障排除

### 软链接断裂

```bash
# 检查软链接状态
ls -la /root/<link>

# 修复软链接
rm /root/<link>
ln -s /data/<target> /root/<link>
```

### 命令找不到

```bash
# 刷新 shell 环境
source ~/.bashrc

# 或重新登录 shell
exec $SHELL
```

### 权限不足

```bash
# 检查目录权限
ls -la /data/<dir>

# 修复权限
sudo chown -R $(whoami):$(whoami) /data/<dir>
```
