# Ansible 控制项目

本目录保存 VMware 批量服务器配置管理的 Ansible 项目文件。

## 控制节点依赖

在 Ansible 控制节点 VM（Ubuntu Server 24.04）中执行：

```bash
sudo apt update
sudo apt install -y python3 python3-pip git sshpass rsync
pip3 install ansible ansible-core
ansible-galaxy collection install -r requirements.yml
ansible --version
```

## 目录说明

- `ansible.cfg`：Ansible 默认配置，使用 `inventory/hosts.yml` 作为默认 inventory。
- `inventory/`：目标 VM 清单和变量文件，后续任务 4.x 完善。
- `playbooks/`：主 playbook 与分层 playbook，后续任务 5.x-8.x 完善。
- `roles/common/`：所有机器通用配置，如 SSH、NTP、防火墙。
- `roles/runtime/`：运行时环境配置，如 Docker、Java、Node、Python。
- `roles/workload/`：具体工作负载配置，如 AI 工作站。

## 验证命令

```bash
ansible-config dump --only-changed
ansible-inventory -i inventory/hosts.yml --graph
```
