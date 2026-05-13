---
name: my-fix-claude-code-viewer
description: 诊断并修复 claude-code-viewer 服务无法启动的问题——JSONL 文件损坏、权限错误、依赖缺失、网络绑定问题。
origin: open-spec-first
---

# Claude Code Viewer 服务修复指南

诊断并修复 `claude-code-viewer` systemd 服务无法启动或陷入循环重启的问题。

## 触发条件

满足以下任一条件时使用本技能：

- `systemctl --user start claude-code-viewer.service` 启动失败
- 服务状态为 `activating (auto-restart)` 且有 exit-code
- 错误信息包含 `SyntaxError: Expected ',' or '}' after property value in JSON`
- HTTP `http://localhost:3400/` 无响应

---

## Step 1: 检查服务状态

```bash
systemctl --user status claude-code-viewer.service
journalctl --user -u claude-code-viewer.service -n 50
```

在输出中查找以下特征模式：

| 特征 | 原因 | 解决方案 |
|------|------|----------|
| `SyntaxError` in `parseJsonl` | JSONL 文件损坏 | Step 2 |
| `aggregateTokenUsageAndCost` | Session 缓存损坏 | Step 2 |
| `Permission denied` | 文件权限问题 | Step 3 |
| `EADDRINUSE` | 端口 3400 被占用 | Step 4 |
| `ENOENT` / `MODULE_NOT_FOUND` | 依赖缺失 | Step 5 |

---

## Step 2: 查找并修复损坏的 JSONL 文件

### 2a: 查找所有 JSON/JSONL 文件

```bash
find ~/.claude -name "*.jsonl" -o -name "*.json" 2>/dev/null | head -50
```

### 2b: 验证每个 JSONL 文件

```bash
node -e "
const fs = require('fs');
const path = require('path');

function findJsonFiles(dir, files = []) {
    if (!fs.existsSync(dir)) return files;
    const items = fs.readdirSync(dir, { withFileTypes: true });
    for (const item of items) {
        const fullPath = path.join(dir, item.name);
        if (item.isDirectory() && !item.name.startsWith('.')) {
            findJsonFiles(fullPath, files);
        } else if (item.isFile() && (item.name.endsWith('.json') || item.name.endsWith('.jsonl'))) {
            files.push(fullPath);
        }
    }
    return files;
}

const jsonFiles = findJsonFiles(process.env.HOME + '/.claude');
console.log('Found', jsonFiles.length, 'JSON/JSONL files');

for (const f of jsonFiles) {
    try {
        const content = fs.readFileSync(f, 'utf8');
        if (f.endsWith('.jsonl')) {
            content.split('\n').forEach((line, i) => {
                if (line.trim()) {
                    try { JSON.parse(line); }
                    catch(e) {
                        console.log('ERROR in', f, 'line', i+1, ':', e.message);
                        console.log('Context:', JSON.stringify(line.slice(0, 200)));
                    }
                }
            });
        } else {
            JSON.parse(content);
        }
    } catch(e) {
        console.log('FILE ERROR:', f, '-', e.message);
    }
}
"
```

### 2c: 修复损坏的文件

如果发现 `.jsonl` 文件有错误：

1. **备份文件**
   ```bash
   cp "/path/to/corrupted/file.jsonl" "/path/to/corrupted/file.jsonl.bak"
   ```

2. **分析错误类型**
   ```bash
   node -e "
   const fs = require('fs');
   const file = '/path/to/corrupted/file.jsonl';
   const content = fs.readFileSync(file, 'utf8');
   const lines = content.split('\n');
   // 打印损坏的行（将 N 替换为报告中的行号）
   console.log('Line N:', JSON.stringify(lines[N-1]?.slice(0, 300)));
   console.log('Line N+1:', JSON.stringify(lines[N]?.slice(0, 300)));
   "
   ```

3. **常见损坏模式及修复方法**

   **模式 A: 行内容合并（最常见）**
   ```
   Line 727: "...\"isSidechain\":false,\"message\":{\"id\":\"061b...<突然终止>
   Line 728: "\",\"version\":\"2.1.87\",\"gitBranch\":\"claude/...<下一条记录的内容>"
   ```
   → 两条相邻的 JSONL 记录被合并成一条。解决方案：删除这两行。

   ```bash
   node -e "
   const fs = require('fs');
   const file = '/path/to/corrupted/file.jsonl';
   const lines = fs.readFileSync(file, 'utf8').split('\n');
   const cleanLines = lines.filter((_, i) => i !== N-1 && i !== N); // N = 损坏的行号
   fs.writeFileSync(file, cleanLines.join('\n') + '\n');
   console.log('Original:', lines.length, 'lines');
   console.log('Cleaned:', cleanLines.length, 'lines');
   "
   ```

   **模式 B: JSON 内容被截断**
   ```
   Line 727: {"id":"abc","content":"
   (文件突然结束)
   ```
   → 最后一行内容不完整。解决方案：删除不完整的行。

   ```bash
   node -e "
   const fs = require('fs');
   const file = '/path/to/file.jsonl';
   const lines = fs.readFileSync(file, 'utf8').split('\n');
   // 验证最后一行是否不完整
   const lastLine = lines[lines.length - 1];
   try { JSON.parse(lastLine); console.log('Last line is valid'); }
   catch(e) {
     console.log('Last line is corrupt, removing it');
     lines.pop();
     fs.writeFileSync(file, lines.join('\n') + '\n');
   }
   "
   ```

   **模式 C: 文件包含非 UTF-8 字符**
   → 文件包含无效的字节序列。

   ```bash
   # 用 hexdump 检查
   xxd /path/to/file.jsonl | grep -A2 " Position of corruption"
   # 解决方案：过滤无效字符后重建文件
   node -e "
   const fs = require('fs');
   const file = '/path/to/file.jsonl';
   let content = fs.readFileSync(file);
   // 移除非 UTF-8 字节
   content = content.toString('utf8').replace(/\ufffd/g, '');
   fs.writeFileSync(file, content);
   "
   ```

### 2d: 验证修复结果

```bash
node -e "
const fs = require('fs');
const file = '/path/to/repaired/file.jsonl';
const content = fs.readFileSync(file, 'utf8');
const lines = content.split('\n');
let error = null;
lines.forEach((line, i) => {
    if (line.trim()) {
        try { JSON.parse(line); }
        catch(e) { error = 'Line ' + (i+1) + ': ' + e.message; }
    }
});
if (error) console.log('Still has error:', error);
else console.log('File is valid! Lines:', lines.length);
"
```

---

## Step 3: 检查文件权限

```bash
ls -la ~/.config/systemd/user/claude-code-viewer.service
ls -la ~/.nvm/versions/node/*/bin/claude-code-viewer 2>/dev/null
```

如果服务或二进制文件不可读：

```bash
chmod 644 ~/.config/systemd/user/claude-code-viewer.service
chmod 755 ~/.nvm/versions/node/*/bin/claude-code-viewer
```

---

## Step 4: 检查端口 3400

```bash
ss -tlnp | grep 3400
lsof -i :3400 2>/dev/null
```

如果端口被占用：

```bash
# 查找并停止占用进程
fuser -k 3400/tcp
# 或者如果服务已经在运行
systemctl --user stop claude-code-viewer.service
sleep 2
```

---

## Step 5: 检查 Node.js 依赖

```bash
node --version
npm list -g @kimuson/claude-code-viewer 2>/dev/null
/root/.nvm/versions/node/*/bin/claude-code-viewer --version 2>/dev/null
```

如果 Node.js 版本过旧或包未安装：

```bash
# 重新安装 viewer
npm install -g @kimuson/claude-code-viewer
```

---

## Step 6: 重启服务

```bash
systemctl --user daemon-reload
systemctl --user enable claude-code-viewer.service
systemctl --user start claude-code-viewer.service
sleep 3
systemctl --user status claude-code-viewer.service
```

---

## Step 7: 验证 HTTP 响应

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3400/
```

应返回 `200`。

---

## 一键自动修复脚本

执行所有诊断和修复步骤：

```bash
#!/bin/bash
set -e

echo "=== Claude Code Viewer 修复脚本 ==="

# 停止服务
systemctl --user stop claude-code-viewer.service 2>/dev/null || true

# 查找损坏的 JSONL 文件
echo "正在搜索损坏的 JSONL 文件..."
CORRUPTED=$(find ~/.claude -name "*.jsonl" 2>/dev/null | while read f; do
  node -e "
    const fs = require('fs');
    const content = fs.readFileSync('$f', 'utf8');
    const lines = content.split('\n');
    lines.forEach((line, i) => {
      if (line.trim()) {
        try { JSON.parse(line); }
        catch(e) { console.log('$f:' + (i+1)); process.exit(1); }
      }
    });
  " 2>/dev/null || echo "$f"
done)

if [ -n "$CORRUPTED" ]; then
  echo "发现损坏文件: $CORRUPTED"
  echo "需要手动干预。请使用 --verbose 参数查看详情。"
else
  echo "未发现损坏的 JSONL 文件。"
fi

# 重启服务
echo "正在启动服务..."
systemctl --user start claude-code-viewer.service
sleep 3

# 验证
STATUS=$(systemctl --user is-active claude-code-viewer.service)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3400/ 2>/dev/null || echo "000")

echo "服务状态: $STATUS"
echo "HTTP 状态: $HTTP_CODE"

if [ "$STATUS" = "active" ] && [ "$HTTP_CODE" = "200" ]; then
  echo "=== 修复成功 ==="
else
  echo "=== 修复失败 ==="
  systemctl --user status claude-code-viewer.service --no-pager
fi
```

---

## 常见问题速查表

| 错误信息 | 原因 | 修复方法 |
|----------|------|----------|
| `SyntaxError: Expected ',' or '}' after property value in JSON at position 899` | Session JSONL 文件行内容合并 | 从 `51c1d5e9-*.jsonl` 文件中删除损坏的两行 |
| 服务循环重启，显示 `Result: exit-code` | projects 缓存中 JSONL 文件损坏 | 按 Step 2 方法修复文件 |
| `11 projects cache initialized` 但随后在 `Initializing sessions cache` 时崩溃 | Session 缓存损坏，而非 projects 缓存 | 检查 projects 目录下的 `.jsonl` 文件 |
