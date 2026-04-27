#!/bin/bash
# 磁盘诊断脚本

echo "=========================================="
echo "磁盘空间诊断报告"
echo "=========================================="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "=== 1. 根分区空间使用情况 ==="
df -h / | tail -1
echo ""

echo "=== 2. /data 目录使用情况 ==="
df -h /data 2>/dev/null || echo "/data 未单独挂载"
echo ""

echo "=== 3. 根目录各文件夹大小 (TOP 10) ==="
du -sh /* 2>/dev/null | sort -hr | head -10
echo ""

echo "=== 4. /root 目录详细占用 ==="
du -sh /root/* /root/.* 2>/dev/null | grep -v "/root/\.$" | sort -hr
echo ""

echo "=== 5. /root 软链接列表 ==="
ls -la /root/ | grep "^l" | awk '{print $NF, "->", $9}'
echo ""

echo "=== 6. /data 目录结构 ==="
du -sh /data/* 2>/dev/null | sort -hr
echo ""

echo "=== 7. 可清理的缓存目录 ==="
for cache_dir in /data/cache /data/.cache-root 2>/dev/null; do
  if [ -d "$cache_dir" ]; then
    size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    echo "  $cache_dir: $size"
  fi
done
echo ""

echo "=========================================="
echo "诊断完成"
echo "=========================================="
