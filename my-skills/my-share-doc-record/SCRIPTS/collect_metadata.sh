#!/usr/bin/env bash
# Phase 0 元数据收集脚本
# 收集项目信息供技能生成文档使用

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
git log --oneline -5 2>/dev/null || echo "暂无"

# 5. 技术栈自动检测（并行检测所有标记文件）
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
