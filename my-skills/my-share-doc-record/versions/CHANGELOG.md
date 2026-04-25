# my-share-doc-record 变更日志

## v1.3.0 (2026-04-25)
### 优化
- SKILL.md 代码模块化：将 3 个长脚本抽取到 `SCRIPTS/` 目录
  - `collect_metadata.sh`（~50行）→ Phase 0 元数据收集脚本
  - `validate_mermaid.sh`（~95行）→ Mermaid 语法验证脚本（与 explore 技能共用）
  - `auto_commit.sh`（~65行）→ 自动提交到 GitHub 脚本
- SKILL.md 从 572 行减至 396 行（减少 176 行，31%）

## v1.2.0 (2026-04-25)
### 优化
- 抽取文档结构模板到独立文件 `TEMPLATE.md`，SKILL.md 改为引用指针
- 共享 `MERMAID_RULES.md`（与 my-explore-doc-record 保持一致）
- Mermaid 语法验证升级：mermaid-cli 优先 + Python 静态检查回退（含未闭合括号检查）
- Phase 0 技术栈检测改为并行检测 12 种标记文件（Node.js/Go/Python/Rust/Java/Kotlin/Ruby/PHP/Swift/C/C++/Docker）
- Phase 0 新增 MCP 服务动态读取
- 质量自检清单从 5 项扩充至 12 项（新增：文档头部字段完整性、乱码检测、Mermaid 最低数量、模型署名、pie chart 估算说明等）

## v1.1.0 (2026-04-25)
### 新增
- 版本管理机制（备份、对比、回滚）
- 统一文档项目路径全局记忆
- 自学习更新机制（Phase 8）
- 用户提示词清单章节
- 难点与挑战章节
- 会话耗时估算
- 对齐 my-explore-doc-record 全部功能

## v1.0.0 (2026-04-25)
### 新增
- 初始版本
- 支持生成研究报告
- 支持 Mermaid 图表
- 支持自动提交到 GitHub
