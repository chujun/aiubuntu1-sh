# my-decision-tree-doc-builder 变更日志

## v1.1.0 (2026-05-13)
### 新增
- 版本管理机制（VERSIONS.json、CHANGELOG.md、SKILL.md 版本备份）
- 输出文档版本控制（检测同名文档，询问用户选择策略）
- 用户偏好记忆（~/.claude/memory/decision_tree_doc_dir.md）
- SCRIPTS/collect_metadata.sh（元数据收集脚本）
- SCRIPTS/auto_commit.sh（自动提交到 GitHub 脚本）
- 完整 10 个 Phase 执行流程

## v1.0.0 (2026-05-12)
### 新增
- 初始版本
- 支持从方案选型对话提取决策节点
- 支持生成 Mermaid 决策树
- 支持决策记录表和约束条件追踪
