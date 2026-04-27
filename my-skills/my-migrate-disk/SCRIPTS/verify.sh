#!/bin/bash
# 验证脚本 - 检查迁移结果

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
check_fail() { echo -e "${RED}[✗]${NC} $1"; }
check_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "=========================================="
echo "迁移验证报告"
echo "=========================================="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "=== 1. 磁盘空间检查 ==="
df -h / | tail -1
echo ""

echo "=== 2. 软链接检查 ==="
all_ok=true

declare -A links=(
  ["/root/.npm"]="/data/user-config/.npm"
  ["/root/.nvm"]="/data/user-config/.nvm"
  ["/root/.local"]="/data/user-config/.local"
  ["/root/.cache"]="/data/user-config/root-cache"
  ["/root/.opencode"]="/data/user-config/.opencode"
  ["/root/.paddlex"]="/data/cache/.paddlex"
  ["/root/.wdm"]="/data/user-config/.wdm"
  ["/root/.bun"]="/data/user-config/.bun"
  ["/root/.claude"]="/data/claude/claude_root"
  ["/root/ai"]="/data/ai"
  ["/root/venv"]="/data/venvs/root-venv"
  ["/root/playwright-venv"]="/data/venvs/playwright-venv"
  ["/root/stock-quant-strategy-venv"]="/data/venvs/stock-quant-strategy-venv"
)

for link in "${!links[@]}"; do
  target="${links[$link]}"

  if [ -L "$link" ]; then
    actual=$(readlink "$link")
    if [ "$actual" = "$target" ]; then
      check_ok "$link -> $actual"
    else
      check_fail "$link -> $actual (期望: $target)"
      all_ok=false
    fi
  elif [ -e "$link" ]; then
    check_warn "$link 存在但不是软链接"
  else
    check_fail "$link 不存在 (BROKEN)"
    all_ok=false
  fi
done

echo ""

echo "=== 3. 命令测试 ==="

# Node/npm
if command -v node &> /dev/null; then
  check_ok "node: $(node --version)"
else
  check_fail "node: 未找到"
  all_ok=false
fi

if command -v npm &> /dev/null; then
  check_ok "npm: $(npm --version)"
else
  check_fail "npm: 未找到"
  all_ok=false
fi

# Python
if command -v python3 &> /dev/null; then
  check_ok "python3: $(python3 --version)"
else
  check_fail "python3: 未找到"
  all_ok=false
fi

# Git
if command -v git &> /dev/null; then
  check_ok "git: $(git --version)"
else
  check_fail "git: 未找到"
  all_ok=false
fi

echo ""

echo "=== 4. Git 仓库检查 ==="
if [ -d "/root/sh/.git" ]; then
  check_ok "sh 仓库存在"
  cd /root/sh && git status --short 2>/dev/null | head -5
else
  check_warn "sh 仓库未找到"
fi

echo ""

echo "=== 5. /data 目录检查 ==="
du -sh /data/* 2>/dev/null | sort -hr

echo ""
echo "=========================================="
if [ "$all_ok" = true ]; then
  echo -e "${GREEN}验证通过！${NC}"
else
  echo -e "${RED}验证失败，请检查上述问题${NC}"
fi
echo "=========================================="
