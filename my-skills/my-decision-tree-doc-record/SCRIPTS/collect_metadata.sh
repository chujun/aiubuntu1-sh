#!/usr/bin/env bash
# Phase 0 元数据收集脚本
# 收集项目信息供技能生成决策树文档使用

echo "=== 元数据收集 ==="

# 1. 当前日期
echo "日期: $(date +%Y-%m-%d)"

# 2. 项目路径
echo "项目路径: $(pwd)"

# 3. GitHub 地址（非 git 项目优雅降级）
GITHUB_URL=$(git remote get-url origin 2>/dev/null || echo "暂无")
echo "GitHub: $GITHUB_URL"

# 4. 当前分支与最近提交
BRANCH=$(git branch --show-current 2>/dev/null || echo "非 git 项目")
echo "分支: $BRANCH"
echo "最近提交:"
git log --oneline -3 2>/dev/null || echo "暂无"

# 5. 动态读取已配置的 MCP 服务
echo "=== MCP 服务 ==="
python3 -c "
import json, os
cfg = os.path.expanduser('~/.claude/settings.json')
try:
    d = json.load(open(cfg))
    mcps = d.get('mcpServers', {})
    if mcps:
        for name, conf in mcps.items():
            print(f'  - {name}')
    else:
        print('  （未配置 MCP 服务）')
except:
    print('  （无法读取配置）')
" 2>/dev/null

echo "=== 收集完成 ==="
