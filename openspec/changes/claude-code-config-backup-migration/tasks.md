## 1. 初始化脚本

- [ ] 1.1 创建 `~/.claude/scripts/` 目录结构
- [ ] 1.2 实现 `init-backup.sh` - 检查 gh CLI 依赖
- [ ] 1.3 实现 `init-backup.sh` - 检查 gh 认证状态
- [ ] 1.4 实现 `init-backup.sh` - 提示用户输入仓库名称
- [ ] 1.5 实现 `init-backup.sh` - 创建 GitHub 私有仓库
- [ ] 1.6 实现 `init-backup.sh` - 在 `~/.claude/` 初始化 git 仓库
- [ ] 1.7 实现 `init-backup.sh` - 添加远程仓库并执行首次推送
- [ ] 1.8 实现 `init-backup.sh` - 配置 SessionEnd 钩子

## 2. 备份脚本

- [ ] 2.1 创建 `~/.claude/backups/` 目录（存放日志）
- [ ] 2.2 实现 `backup.sh` - 仓库可见性校验（私有仓库检查）
- [ ] 2.3 实现 `backup.sh` - git add -A 暂存所有变更
- [ ] 2.4 实现 `backup.sh` - git status 检查是否有变更
- [ ] 2.5 实现 `backup.sh` - git commit 提交变更
- [ ] 2.6 实现 `backup.sh` - git pull --rebase 尝试自动合并
- [ ] 2.7 实现 `backup.sh` - 冲突检测与处理（无法解决时记录警告）
- [ ] 2.8 实现 `backup.sh` - git push 推送到远程
- [ ] 2.9 实现 `backup.sh` - 成功/失败/冲突日志记录

## 3. 恢复脚本

- [ ] 3.1 实现 `restore-backup.sh` - 检查 gh CLI 依赖
- [ ] 3.2 实现 `restore-backup.sh` - 检查 gh 认证状态
- [ ] 3.3 实现 `restore-backup.sh` - 克隆仓库到临时目录
- [ ] 3.4 实现 `restore-backup.sh` - 复制配置到 `~/.claude/` 覆盖现有文件
- [ ] 3.5 实现 `restore-backup.sh` - 保留 .git 目录
- [ ] 3.6 实现 `restore-backup.sh` - 验证恢复完整性

## 4. 钩子配置

- [ ] 4.1 在 `~/.claude/hooks/hooks.json` 中添加 SessionEnd 钩子配置
- [ ] 4.2 配置 backup.sh 为 SessionEnd 钩子的触发命令

## 5. 测试验证

- [ ] 5.1 测试初始化脚本 - 完整流程测试
- [ ] 5.2 测试备份脚本 - 无变更时的行为
- [ ] 5.3 测试备份脚本 - 有新文件时的增量同步
- [ ] 5.4 测试备份脚本 - 网络故障时的日志记录
- [ ] 5.5 测试恢复脚本 - 完整恢复流程
- [ ] 5.6 测试钩子配置 - SessionEnd 触发验证
