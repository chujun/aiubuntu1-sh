#!/usr/bin/env bash
# 自动提交到 GitHub 脚本
# 仅提交 doc/ai-share/ 目录，绝不使用 git add .
# 用法：bash SCRIPTS/auto_commit.sh <统一文档项目路径> <文档标题>

set -e

DOC_PROJECT_PATH="$1"
DOC_TITLE="$2"

if [ -z "$DOC_PROJECT_PATH" ] || [ -z "$DOC_TITLE" ]; then
    echo "用法：bash SCRIPTS/auto_commit.sh <统一文档项目路径> <文档标题>"
    exit 1
fi

cd "$DOC_PROJECT_PATH"

# 0. 更新版本元数据
SKILL_DIR="/root/.claude/skills/my-share-doc-record"
SKILL_FILE="${SKILL_DIR}/SKILL.md"
VERSION_DIR="${SKILL_DIR}/versions"
CURRENT_VERSION=$(grep '^version:' "$SKILL_FILE" | sed 's/version: *"\(.*\)"/\1/')
TODAY=$(date +%Y-%m-%d)

if ! git diff --quiet "$SKILL_FILE" 2>/dev/null; then
    python3 -c "
import json
vfile = '$VERSION_DIR/VERSIONS.json'
try:
    with open(vfile) as f:
        data = json.load(f)
except:
    data = {'current': '0.0.0', 'versions': []}

existing = [i for i, v in enumerate(data['versions']) if v['version'] == '$CURRENT_VERSION']
if not existing:
    data['versions'].insert(0, {
        'version': '$CURRENT_VERSION',
        'date': '$TODAY',
        'changelog': '自动更新',
    })
    data['current'] = '$CURRENT_VERSION'
    with open(vfile, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print('✅ 已更新 VERSIONS.json')
"

    if ! grep -q "^## v$CURRENT_VERSION " "$VERSION_DIR/CHANGELOG.md" 2>/dev/null; then
        sed -i "1i\\
## v$CURRENT_VERSION ($TODAY)\\
### 自动更新\\
- 版本元数据自动更新\\
" "$VERSION_DIR/CHANGELOG.md"
    fi
fi

# 1. 检查远端
if ! git remote get-url origin >/dev/null 2>&1; then
    echo "⚠️ 非 git 仓库或无远端，跳过"
    exit 0
fi

# 2. 仅添加 doc/ai-share/
git add doc/ai-share/

# 3. 检查是否有更改
if git diff --cached --quiet; then
    echo "ℹ️ doc/ai-share/ 无新增更改"
    exit 0
fi

# 4. 提交并推送
git commit -m "docs: 新增 ${DOC_TITLE}研究报告"
git push origin $(git branch --show-current)

echo "✅ 已提交并推送到 GitHub"
