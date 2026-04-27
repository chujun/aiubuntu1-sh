#!/bin/bash
# 验证脚本 - 检查迁移结果

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

log_silent "=== verify.sh 启动 ==="

echo "=========================================="
echo "迁移验证报告"
echo "=========================================="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "=== 1. 磁盘空间检查 ==="
df -h / | tail -1
echo ""

all_ok=true

echo "=== 2. 软链接检查 ==="

# 检查所有指向 /data/migrate-root 的软链接
link_found=false
for link in /root/* /root/.*; do
  [ ! -L "$link" ] && continue

  link_name=$(basename "$link")
  [[ "$link_name" == "." || "$link_name" == ".." ]] && continue

  target=$(readlink "$link")

  # 只检查指向 TARGET_DIR 的
  if [[ "$target" == "$TARGET_DIR"* ]]; then
    link_found=true
    if [ -e "$link" ]; then
      check_ok "/root/$link_name -> $target"
    else
      check_fail "/root/$link_name -> $target (BROKEN)"
      all_ok=false
    fi
  fi
done

if [ "$link_found" = false ]; then
  check_warn "没有找到指向 $TARGET_DIR 的软链接"
fi

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

echo "=== 4. 其他软链接检查 ==="
for link in /root/* /root/.*; do
  [ ! -L "$link" ] && continue

  link_name=$(basename "$link")
  [[ "$link_name" == "." || "$link_name" == ".." ]] && continue

  target=$(readlink "$link")

  # 跳过已在第2步检查过的
  [[ "$target" == "$TARGET_DIR"* ]] && continue

  if [ -e "$link" ]; then
    echo -e "  ${GREEN}✓${NC} /root/$link_name -> $target"
  else
    echo -e "  ${RED}✗${NC} /root/$link_name -> $target (BROKEN)"
  fi
done

echo ""
echo "=========================================="
if [ "$all_ok" = true ]; then
  echo -e "${GREEN}验证通过！${NC}"
  log_silent "验证通过"
else
  echo -e "${RED}验证失败，请检查上述问题${NC}"
  log_silent "验证失败"
fi
echo "=========================================="
