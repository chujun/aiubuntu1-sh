#!/bin/bash
# Ansible 控制节点安装脚本
# 用途：在 Ubuntu 24.04 控制节点上安装 Ansible

set -e

echo "=== 开始安装 Ansible 控制节点 ==="

# 更新包索引
echo "[1/4] 更新系统包索引..."
sudo apt update -qq

# 安装基础依赖
echo "[2/4] 安装基础依赖（pip3, git, sshpass, rsync）..."
sudo apt install -y -qq python3-pip git sshpass rsync > /dev/null

# 使用 pip3 安装 Ansible
echo "[3/4] 安装 Ansible（pip3 install）..."
pip3 install ansible ansible-core --break-system-packages -q

# 安装 ansible-galaxy community.general collection
echo "[4/4] 安装 ansible-galaxy community.general collection..."
ansible-galaxy collection install community.general

echo ""
echo "=== 安装完成 ==="
echo ""
echo "验证安装："
ansible --version
echo ""
ansible-galaxy collection list | grep community.general
