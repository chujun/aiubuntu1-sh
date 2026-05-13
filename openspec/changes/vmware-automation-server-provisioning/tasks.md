# Tasks: VMware 自动化批量服务器搭建系统

> **⚠️ 执行约束（必读）**：
> 1. **严格按序号顺序执行**：必须先完成 1.1，才能做 1.2，依此类推
> 2. **宿主机任务阻塞规则**：宿主机任务（🖥️）没有完成，不得标记序号更大的任何任务为已完成
> 3. **状态更新方式**：告诉 AI 宿主机任务的完成情况，AI 更新 tasks.md 并同步到 git

---

## 1. 环境准备

> 🔒 阻塞：1.1-1.5 必须全部完成才能解锁后续任务

- [x] 1.1 在 VMware Workstation Pro 中创建 Ansible 控制节点 VM（Ubuntu Server 24.04，2C/4GB/40GB）
- [x] 1.2 配置控制节点 VM 网络（与目标 VM 同网段）
- [x] 1.3 在控制节点 VM 中安装 Python3、pip、Git、sshpass、rsync
- [ ] 1.4 在 Windows 11 上下载并安装 Packer（解压到指定目录）
- [ ] 1.5 验证 Packer 安装：`packer --version`

## 2. Packer 镜像构建配置

> 🔒 阻塞：1.5 完成后才能执行 2.6-2.9；2.1-2.5 可提前编写

- [ ] 2.1 创建 `packer/ubuntu-24-server/` 目录结构
- [ ] 2.2 编写 `ubuntu-24-server.pkr.hcl` Packer 配置文件
- [ ] 2.3 创建 Cloud-Init `http/user-data` 配置文件（主机名、用户、SSH 密钥）
- [ ] 2.4 创建 Cloud-Init `http/meta-data` 配置文件
- [ ] 2.5 编写 `variables.pkr.hcl` 共享变量文件（ISO 路径、VM 配置等）
- [ ] 2.6 运行 `packer validate` 验证配置
- [ ] 2.7 准备 Ubuntu 24.04 Server ISO 文件
- [ ] 2.8 执行 `packer build` 构建 Ubuntu Server 基础镜像
- [ ] 2.9 验证镜像可正常启动并通过 Cloud-Init 完成初始化
- [ ] 2.10 创建 `packer/ubuntu-24-desktop/` 目录和配置（Desktop 版本）

## 3. Ansible 控制节点配置

> 🔒 阻塞：2.8 完成后才能执行 3.1-3.2；3.3-3.5 可提前编写

- [ ] 3.1 在控制节点 VM 中安装 Ansible（pip3 install ansible ansible-core）
- [ ] 3.2 安装 ansible-galaxy collections：`community.general`
- [ ] 3.3 创建 `ansible/` 项目目录结构
- [ ] 3.4 编写 `ansible.cfg` 配置文件
- [ ] 3.5 创建 Git 仓库并初始化（用于配置版本化）
- [ ] 3.6 验证 Ansible 安装：`ansible --version`

## 4. Ansible Inventory 配置

> 🔒 阻塞：3.6 完成后才能执行 4.4-4.5；4.1-4.3 可提前编写

- [ ] 4.1 创建 `inventory/hosts.yml` 主机清单文件
- [ ] 4.2 创建 `inventory/group_vars/all.yml` 全局变量
- [ ] 4.3 创建 `inventory/host_vars/` 目录（单机变量）
- [ ] 4.4 验证 Inventory：`ansible-inventory -i inventory/hosts.yml --graph`
- [ ] 4.5 配置 SSH 密钥对（用于无密码连接目标 VM）

## 5. Ansible Common 层 Role

> 🔒 阻塞：4.5 完成后才能解锁 5.1-5.9

- [ ] 5.1 创建 `roles/common/ssh/` Role（SSH 服务配置）
- [ ] 5.2 创建 `roles/common/ssh/tasks/main.yml` 主任务文件
- [ ] 5.3 创建 `roles/common/ssh/tasks/debian.yml`（Ubuntu/Debian 专用）
- [ ] 5.4 创建 `roles/common/ssh/vars/debian.yml` 变量文件
- [ ] 5.5 创建 `roles/common/ntp/` Role（NTP 时间同步）
- [ ] 5.6 创建 `roles/common/firewall/` Role（防火墙配置）
- [ ] 5.7 创建 `roles/common/firewall/tasks/debian.yml`（ufw）
- [ ] 5.8 创建 `roles/common/firewall/tasks/redhat.yml`（firewalld）
- [ ] 5.9 创建 `playbooks/base.yml` 基础配置 playbook

## 6. Ansible Runtime 层 Role

> 🔒 阻塞：5.9 完成后才能解锁

- [ ] 6.1 创建 `roles/runtime/docker/` Role
- [ ] 6.2 创建 `roles/runtime/docker/tasks/main.yml`
- [ ] 6.3 创建 `roles/runtime/docker/handlers/main.yml`
- [ ] 6.4 创建 `roles/runtime/docker/vars/main.yml`
- [ ] 6.5 创建 `roles/runtime/java/` Role（OpenJDK）
- [ ] 6.6 创建 `roles/runtime/node/` Role（Node.js）
- [ ] 6.7 创建 `roles/runtime/python/` Role
- [ ] 6.8 创建 `playbooks/runtime.yml` 运行时环境 playbook

## 7. Ansible Workload 层 Role

> 🔒 阻塞：6.8 完成后才能解锁

- [ ] 7.1 创建 `roles/workload/ai-workstation/` Role
- [ ] 7.2 创建 `roles/workload/ai-workstation/tasks/main.yml`
- [ ] 7.3 创建 `playbooks/ai-workstation.yml` AI 工作站 playbook

## 8. Ansible 主 Playbook

> 🔒 阻塞：7.3 完成后才能解锁 8.3

- [ ] 8.1 创建 `playbooks/site.yml` 主入口 playbook
- [ ] 8.2 创建 `playbooks/site.yml` 引入 base/runtime/ai-workstation plays
- [ ] 8.3 测试完整 playbook 执行：`ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check`

## 9. 端到端测试

> 🔒 阻塞：8.3 完成后才能解锁

- [ ] 9.1 从 Packer 构建镜像开始完整流程测试
- [ ] 9.2 克隆 VM 并修改主机名/IP
- [ ] 9.3 执行 `ansible-playbook -i inventory/hosts.yml playbooks/site.yml`
- [ ] 9.4 验证 SSH 连接：`ansible -i inventory/hosts.yml all -m ping`
- [ ] 9.5 验证 Docker 安装：`docker --version`
- [ ] 9.6 验证 Java 安装：`java -version`
- [ ] 9.7 验证 Node 安装：`node -v`

## 10. 多 OS 支持扩展（可选，后续阶段）

> 🔒 阻塞：9.7 完成后才能开始

- [ ] 10.1 添加 Debian 12 支持（创建目标 VM）
- [ ] 10.2 在各 Role 内添加 `tasks/debian.yml` 文件
- [ ] 10.3 在各 Role 内添加 `vars/debian.yml` 文件
- [ ] 10.4 测试 Debian VM 的 Ansible 执行
- [ ] 10.5 更新文档中的多 OS 支持说明

## 11. 文档与维护

> 🔒 阻塞：10.5 完成后才能开始

- [ ] 11.1 编写 `docs/runbooks/packer-build.md` 操作手册
- [ ] 11.2 编写 `docs/runbooks/ansible-execution.md` 操作手册
- [ ] 11.3 编写 `docs/design.md` 设计文档
- [ ] 11.4 提交所有配置到 Git 仓库
- [ ] 11.5 创建 Git tag 或 release 标记初始版本
