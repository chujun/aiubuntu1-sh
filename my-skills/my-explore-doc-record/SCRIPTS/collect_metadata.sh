#!/bin/bash
# Phase 0：收集上下文元数据
# 用法：bash SCRIPTS/collect_metadata.sh

# 1. 当前日期
date +%Y-%m-%d

# 2. 项目路径
pwd

# 3. GitHub 地址（非 git 项目优雅降级）
git remote get-url origin || echo "暂无"

# 4. 当前分支与最近提交
git branch --show-current || echo "非 git 项目"
git log --oneline -5 || echo "暂无"

# 5. 技术栈自动检测（并行检测所有标记文件，输出完整技术栈列表）
echo "=== 技术栈检测 ==="
FOUND=0
[ -f package.json ] && {
  python3 -c "import json; d=json.load(open('package.json')); deps=list({**d.get('dependencies',{}),**d.get('devDependencies',{})}.keys()); print('Node.js/TypeScript:', deps[:12])" 2>/dev/null
  FOUND=1
}
[ -f go.mod ] && { echo "Go: $(head -1 go.mod)"; FOUND=1; }
[ -f pyproject.toml ] && { echo "Python (pyproject.toml)"; FOUND=1; }
[ -f requirements.txt ] && { echo "Python (requirements.txt)"; FOUND=1; }
[ -f Cargo.toml ] && { echo "Rust (Cargo.toml)"; FOUND=1; }
[ -f pom.xml ] && { echo "Java/Kotlin (Maven)"; FOUND=1; }
[ -f build.gradle ] || [ -f build.gradle.kts ] && { echo "Java/Kotlin (Gradle)"; FOUND=1; }
[ -f Gemfile ] && { echo "Ruby (Gemfile)"; FOUND=1; }
[ -f composer.json ] && { echo "PHP (Composer)"; FOUND=1; }
[ -f Package.swift ] && { echo "Swift (SPM)"; FOUND=1; }
[ -f CMakeLists.txt ] || [ -f Makefile ] && { echo "C/C++ (CMake/Make)"; FOUND=1; }
[ -f Dockerfile ] || [ -f docker-compose.yml ] && { echo "Docker 容器化"; FOUND=1; }
[ "$FOUND" -eq 0 ] && echo "技术栈未知，请手动填写"

# 6. 动态读取已配置的 MCP 服务
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
