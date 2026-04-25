---
name: my-share-doc-record
description: 根据当前会话内容，生成「XXXX研究报告」风格的共享文档，原始 Markdown 存放到统一文档项目 doc/ai-share/，当前项目放跳转 HTML，并自动 git push 到远端。支持版本管理（备份、对比、回滚）和自学习更新机制。
origin: local
version: "1.1.0"
updated: "2026-04-25"
---

# My Share Doc Record

将本次会话整理成结构化的**研究报告**，适合知识沉淀和共享传播。原始 Markdown 存放到用户统一文档项目的 `doc/ai-share/` 目录，当前项目 `doc/ai-share/` 放跳转 HTML 页面，并自动提交到 GitHub 远端。

## 定位差异

| 技能 | 目标 | 文档风格 | 存放目录 |
|------|------|---------|---------|
| my-explore-doc-record | AI 协作学习 | 强调 AI 角色、工具使用、提示词过程 | doc/ai-explore/ |
| my-share-doc-record | 知识研究报告 | 强调主题本身、工作原理、应用场景 | doc/ai-share/ |

---

## 使用场景

- 会话内容涉及某个工具、技术、概念的系统性研究
- 想生成结构清晰的研究报告，便于知识沉淀和分享
- 想输出一份"关于 XXXX 的完整研究报告"

## 调用方式

```
/my-share-doc-record [可选：研究报告主题或版本管理命令]
```

### 文档生成模式

- `/my-share-doc-record` — 自动推断研究主题
- `/my-share-doc-record Git Worktree` — 指定研究主题关键词

### 版本管理模式

- `/my-share-doc-record --versions` — 列出所有版本
- `/my-share-doc-record --changelog` — 查看变更日志
- `/my-share-doc-record --diff v1.0.0 v1.1.0` — 对比两个版本
- `/my-share-doc-record --info v1.1.0` — 查看指定版本详情
- `/my-share-doc-record --restore v1.0.0` — 回滚到指定版本
- `/my-share-doc-record --set-doc-dir <path>` — 设置统一文档项目路径

---

## 执行流程

### Phase 0：收集上下文元数据

运行以下命令收集项目信息，所有命令均做好错误降级处理：

```bash
# 1. 当前日期
date +%Y-%m-%d

# 2. 项目路径
pwd

# 3. GitHub 地址（非 git 项目优雅降级）
git remote get-url origin || echo "暂无"

# 4. 当前分支与最近提交
git branch --show-current || echo "非 git 项目"
git log --oneline -5 || echo "暂无"
```

从会话 system-reminder 中提取：
- **会话 ID**：从 session summary 或文件路径提取 UUID 部分
- **AI 模型**：从 system-reminder 中的模型信息读取

#### 会话耗时估算

1. **起止时间**：从会话开始到当前时刻
2. **空闲扣除规则**：如果用户两条消息之间的间隔**超过 2 小时**，则将该段等待时间扣除
3. **精度**：保留 1 位小数，单位为小时

```
> **预计耗时：** X.X 小时（HH:MM ~ HH:MM，空闲说明）
```

---

### Phase 1：获取统一文档项目路径

**全局记忆机制（跨项目生效）：**

```bash
# 尝试从全局 memory 读取
cat ~/.claude/memory/user_doc_dir.md 2>/dev/null || echo "暂无"
```

- 首次执行时询问用户统一文档项目路径
- 保存到全局 memory：`~/.claude/memory/user_doc_dir.md`
- 后续在**任何项目**中执行技能时，直接读取使用
- 用户可通过 `--set-doc-dir <path>` 重新设置

---

### Phase 2：统计工具使用情况

#### 2.1 AI 大模型

**配置模型：**

| 模型 ID | 名称 | 用途 |
|---------|------|------|
| （从 system-reminder 读取） | — | 主对话 |

**实际调用模型：**

| 模型 ID | 模型名称 | 调用场景 | 说明 |
|--------|---------|---------|------|
| （实际使用） | — | — | 如有子代理调用需记录 |

#### 2.2 Claude Code 工具调用统计

统计 Bash / Read / Edit / Write / Grep / Glob / Agent / Skill 各自调用次数，用于生成 pie chart。

> ⚠️ 估算值，非精确统计

#### 2.3 技能（Skill）

记录本次会话中调用的 Skill：

| 技能名称 | 触发命令 | 调用次数 |
|---------|---------|---------|
| my-share-doc-record | /my-share-doc-record | 1 次 |

---

### Phase 3：整理用户提示词清单

从当前会话完整回溯用户的每一条输入，**原样保留，一字不改**，按时间顺序编号。

**提示词范围：**
- ✅ 普通文字输入、带截图的输入
- ❌ Claude 的回复、工具调用结果、system-reminder

---

### Phase 4：推断研究主题与文件名

**主题推断规则：**

1. 用户调用时提供参数 → 使用该参数
2. 分析会话主要内容自动推断
3. 多主题时选择最核心的那个

**文件名格式：**
```
doc/ai-share/{YYYY-MM-DD}-{研究主题}研究报告.md
```

**同名文件处理策略（三选一）：**

检测是否已有同名文档，**必须询问用户**：

| 选项 | 说明 | 适用场景 |
|------|------|---------|
| **新建版本** | 追加 `-v2`、`-v3` | 内容差异大 |
| **增量追加** | 追加到末尾 + 分隔线 | 持续迭代 |
| **合并文档**（推荐） | 合并为一个 + 归档旧版 | 多碎片整合 |

---

### Phase 4.5：版本管理与变更追踪

#### 4.5.1 版本管理命令

```
/my-share-doc-record --versions        # 列出所有版本
/my-share-doc-record --changelog       # 查看变更日志
/my-share-doc-record --diff v1.0.0 v1.1.0
/my-share-doc-record --info v1.1.0
/my-share-doc-record --restore v1.0.0
```

#### 4.5.2 版本元数据

```json
{
  "current": "1.1.0",
  "versions": [
    {
      "version": "1.1.0",
      "date": "2026-04-25",
      "changelog": "新增版本管理、路径记忆、自学习机制",
      "phases": ["Phase 0-7"]
    }
  ]
}
```

#### 4.5.3 自动备份规则

每次执行技能时：

```bash
SKILL_DIR="/root/.claude/skills/my-share-doc-record"
SKILL_FILE="${SKILL_DIR}/SKILL.md"
VERSION_DIR="${SKILL_DIR}/versions"
CURRENT_VERSION=$(grep '^version:' "$SKILL_FILE" | sed 's/version: *"\(.*\)"/\1/')

if [ ! -f "${VERSION_DIR}/SKILL-v${CURRENT_VERSION}.md" ]; then
    mkdir -p "$VERSION_DIR"
    cp "$SKILL_FILE" "${VERSION_DIR}/SKILL-v${CURRENT_VERSION}.md"
    echo "✅ 已备份版本 v${CURRENT_VERSION}"
fi
```

#### 4.5.4 版本回滚

```bash
cp versions/SKILL-v${TARGET_VERSION}.md SKILL.md
```

---

### Phase 5：生成研究报告

#### 文档存放策略（双目录机制）

**1. 原始 Markdown** → 统一文档项目 `doc/ai-share/`

**2. 跳转 HTML** → 当前项目 `doc/ai-share/`

**跳转 HTML 模板：**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; url={链接地址}">
    <title>{研究主题}研究报告 - 跳转中</title>
</head>
<body>
    <p>正在跳转到研究报告...</p>
    <p>如果没有自动跳转，请点击：<a href="{链接地址}">{研究主题}研究报告</a></p>
    <hr>
    <p><small>原始文档：{统一文档项目路径}/doc/ai-share/{文件名}.md</small></p>
    <p><small>生成时间：{YYYY-MM-DD}</small></p>
</body>
</html>
```

**GitHub 链接必须 URL 编码：**

```bash
python3 -c "import urllib.parse; print(urllib.parse.quote('文件名.md'))"
```

#### Mermaid 图表语法规范

**语法规则：**
1. `graph TD`/`flowchart TD` 等关键字必须**独立一行**
2. 节点定义每行一个，缩进 4 空格
3. 多行节点文本用 `<br/>`
4. 禁止在关键字行后直接跟节点定义
5. 禁止 `\n` 做节点内换行

---

#### 文档结构模板

```markdown
# {研究主题}研究报告

> **研究主题：** {主题名称}
> **日期：** {YYYY-MM-DD}
> **预计耗时：** {X.X} 小时（{HH:MM} ~ {HH:MM}，{空闲说明}）
> **项目路径：** {abs_path}
> **GitHub 地址：** {url 或 暂无}
> **本文档链接：** {GitHub 链接（URL 编码版）}

---

## 目录

- [一、研究概述](#一研究概述)
- [二、工作原理](#二工作原理)
- [三、核心概念](#三核心概念)
- [四、应用场景](#四应用场景)
- [五、命令参考](#五命令参考)
- [六、注意事项](#六注意事项)
- [七、实战案例](#七实战案例)
- [八、相关工具对比](#八相关工具对比)
- [九、用户提示词清单](#九用户提示词清单)
- [十、难点与挑战](#十难点与挑战)
- [十一、经验总结](#十一经验总结)

---

## 一、研究概述

（简要介绍研究主题是什么，解决什么问题）

---

## 二、工作原理

### 2.1 架构图

```mermaid
graph TD
    A["主体"] --> B["组件1"]
    A --> C["组件2"]
    B --> D["结果1"]
    C --> E["结果2"]
```

### 2.2 核心流程

```mermaid
flowchart LR
    A["输入"] --> B["处理"]
    B --> C["输出"]
```

---

## 三、核心概念

| 概念 | 说明 |
|------|------|
| 概念1 | 解释1 |
| 概念2 | 解释2 |

---

## 四、应用场景

### 场景矩阵

| 场景 | 适用性 | 用法 |
|------|--------|------|
| 场景1 | ✅ 适合 | 具体用法 |
| 场景2 | ⚠️ 注意 | 注意事项 |

### 典型案例

```mermaid
sequenceDiagram
    participant 用户
    participant 工具
    participant 系统

    用户->>工具: 操作1
    工具->>系统: 调用
    系统-->>工具: 结果
    工具-->>用户: 输出
```

---

## 五、命令参考

### 核心命令

| 命令 | 说明 | 示例 |
|------|------|------|
| 命令1 | 说明1 | `示例1` |

### 选项速查

| 选项 | 说明 |
|------|------|
| -a | 选项a说明 |

---

## 六、注意事项

| 注意点 | 说明 | 建议 |
|--------|------|------|
| 注意点1 | 说明1 | 建议1 |

---

## 七、实战案例

### 案例：{案例名称}

**问题：** {描述}

**解决：** {方案}

**步骤：**

```bash
# 步骤1
command1
```

**结果：** {结果}

---

## 八、相关工具对比

| 工具 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| 工具A | 优点A | 缺点A | 场景A |

---

## 九、用户提示词清单（原文）

**提示词 1：**
\`\`\`
（原文）
\`\`\`

---

## 十、难点与挑战

| 难点 | 初始判断 | 实际根因 | 解决方法 |
|------|---------|---------|---------|
| 难点1 | 判断1 | 根因1 | 解决1 |

---

## 十一、经验总结

| 经验 | 核心教训 |
|------|---------|
| 经验1 | 教训1 |

---

*文档生成时间：{YYYY-MM-DD} | 由 {模型名称} 辅助生成*
```

---

### Phase 6：质量自检

#### 第一步：Mermaid 语法检查

```bash
python3 -c "
import re, sys

fpath = sys.argv[1]
with open(fpath) as f:
    content = f.read()

blocks = re.findall(r'\`\`\`mermaid\n(.*?)\n\`\`\`', content, re.DOTALL)
if not blocks:
    print('未找到 Mermaid 图表')
    sys.exit(1)

errors = []
for idx, block in enumerate(blocks, 1):
    lines = block.strip().split('\n')
    first = lines[0]

    # 错误1: <br/> 在语法关键字行
    if '<br/>' in first:
        errors.append(f'图表 #{idx}: <br/> 在关键字行')
        continue

    # 错误2: 关键字行无后续内容
    if len(lines) == 1:
        errors.append(f'图表 #{idx}: 关键字行无后续内容')
        continue

print(f'检查了 {len(blocks)} 个 Mermaid 图表')
if errors:
    for e in errors:
        print(f'❌ {e}')
    sys.exit(1)
else:
    print('✅ 全部图表语法正确')
" <文件路径>
```

#### 第二步：逐项确认

- [ ] 研究主题已填写
- [ ] 核心章节完整（概述、原理、场景、命令）
- [ ] 至少 2 张 Mermaid 图表
- [ ] Mermaid 语法验证通过
- [ ] 文档无乱码

---

### Phase 7：自动提交到远端

**⚠️ 安全约束：**
- 仅提交 `doc/ai-share/` 目录
- 绝不使用 `git add .` 或 `git add -A`

```bash
# 切换到统一文档项目目录
cd {统一文档项目路径}

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
git commit -m "docs: 新增 {研究主题}研究报告"
git push origin $(git branch --show-current)

echo "✅ 已提交并推送到 GitHub"
```

---

### Phase 8：自学习更新机制

#### 8.1 改进发现时机

在执行过程中关注：
- 新场景未覆盖
- 重复手动操作
- 用户反馈修正
- 异常降级
- 缺失能力

#### 8.2 建议提出格式

```
🧠 技能自学习建议（本次执行中发现）

发现 N 个可改进之处：

┌─ 建议 1：{标题}
│  类型：新增能力 / 优化流程 / 修复问题
│  触发原因：{具体发生了什么}
│  改进方案：{怎么改}
│  影响范围：{影响哪些 Phase}
└─ 优先级：高 / 中 / 低

是否应用这些改进？
```

#### 8.3 用户决策

| 选项 | 说明 |
|------|------|
| **全部应用** | 批量修改 |
| **逐条选择** | 逐个确认 |
| **暂不改动** | 记录到 IMPROVEMENTS.md |
| **自定义** | 用户补充 |

#### 8.4 应用流程

```
1. 备份当前版本
2. 修改 SKILL.md
3. 升版号（patch/minor）
4. 备份新版本
5. 展示 diff
```

#### 8.5 建议记录

若用户选择「暂不改动」，记录到：

```markdown
# 技能改进建议池

## 待处理建议

### [{日期}] {标题}
- **类型：** 新增能力
- **触发场景：** {描述}
- **建议方案：** {描述}
- **状态：** 待处理
```
---

## 输出示例

```
✅ 研究报告已生成：
  📄 原始文档：/root/sh/doc/ai-share/2026-04-25-GitWorktree研究报告.md
  🔗 跳转页面：doc/ai-share/2026-04-25-GitWorktree研究报告.html
  🌐 GitHub 链接：https://github.com/chujun/aiubuntu1-sh/blob/main/doc/ai-share/2026-04-25-GitWorktree%E7%A0%94%E7%A9%B6%E6%8A%A5%E5%91%8A.md

📊 报告统计：
  - 总行数：XXX 行
  - Mermaid 图表：X 张
  - 章节数：11 章

🚀 Git 提交状态：
  - ✅ 已提交并推送到 GitHub (commit: abc1234)
```
