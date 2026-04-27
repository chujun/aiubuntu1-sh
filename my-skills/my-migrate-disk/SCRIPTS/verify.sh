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

TARGET_DIR="/data/migrate-root"
all_ok=true

echo "=== 2. 软链接检查 ==="

# 检查所有从 /root 指向 /data/migrate-root 的软链接
for link in /root/*/; do
  link=$(basename "$link")

  # 跳过非软链接
  if [ ! -L "/root/$link" ]; then
    continue
  fi

  target=$(readlink "/root/$link")

  # 只检查指向 TARGET_DIR 的
  if [[ "$target" == "$TARGET_DIR"* ]]; then
    if [ -e "/root/$link" ]; then
      check_ok "/root/$link -> $target"
    else
      check_fail "/root/$link -> $target (BROKEN)"
      all_ok=false
    fi
  fi
done

echo ""

echo "=== 3. 目标目录检查 ==="
if [ -d "$TARGET_DIR" ]; then
  check_ok "目标目录存在: $TARGET_DIR"
  echo ""
  du -sh "$TARGET_DIR"/* 2>/dev/null | sort -hr
else
  check_warn "目标目录不存在: $TARGET_DIR"
fi

echo ""

echo "=== 4. 命令测试 ==="

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
  check_warn "npm: 未找到"
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

echo "=== 5. Git 仓库检查 ==="
if [ -d "/root/sh/.git" ]; then
  check_ok "sh 仓库存在"
  cd /root/sh && git status --short 2>/dev/null | head -5
else
  check_warn "sh 仓库未找到"
fi

echo ""

echo "=========================================="
if [ "$all_ok" = true ]; then
  echo -e "${GREEN}验证通过！${NC}"
else
  echo -e "${RED}验证失败，请检查上述问题${NC}"
fi
echo "=========================================="
