#!/bin/bash
# 极简 Git 初始化 (一行命令版)
echo "请输入用户名和邮箱 (格式: 用户名 邮箱):"
read git_user git_email
git config --global user.name "$git_user" && \
git config --global user.email "$git_email" && \
git config --global init.defaultBranch main && \
git config --global credential.helper store && \
mkdir -p ~/.ssh && \
ssh-keygen -t ed25519 -C "$git_email" -f ~/.ssh/id_ed25519 -N "" && \
eval "$(ssh-agent -s)" && \
ssh-add ~/.ssh/id_ed25519 && \
echo "✅ 配置完成！公钥:" && \
cat ~/.ssh/id_ed25519.pub

