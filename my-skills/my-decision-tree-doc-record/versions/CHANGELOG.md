# my-decision-tree-doc-record 变更日志

## v1.3.0 (2026-05-13)
### 优化
- 统一文档项目机制：使用 `user_doc_dir.md` 与其他技能保持一致
- Phase 1 改为"获取统一文档项目路径"
- Phase 10 明确提交目标为统一文档项目

## v1.2.0 (2026-05-13)
### 新增
- 双目录机制：原文存统一文档项目，跳转 HTML 存当前项目
- 会话耗时估算（Phase 0）
- 自学习更新机制（Phase 11）
- 输出示例章节
- 修复重复的"版本管理"章节

## v1.1.2 (2026-05-13)
### 优化
- Phase 9 质量自检改为调用 validate_mermaid.sh

## v1.1.1 (2026-05-13)
### 优化
- SKILL.md 模板内容抽取到 TEMPLATE.md

## v1.1.0 (2026-05-13)
### 新增
- 版本管理机制（VERSIONS.json、CHANGELOG.md）
- SCRIPTS/collect_metadata.sh 元数据收集脚本
- SCRIPTS/auto_commit.sh 自动提交脚本
- 输出文档版本控制
- 用户偏好记忆

## v1.0.0 (2026-05-12)
### 新增
- 初始版本
- 支持从方案选型对话提取决策节点
- 支持生成 Mermaid 决策树
- 支持决策记录表和约束条件追踪
