#!/bin/bash
set -euo pipefail

info() { echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"; }
success() { echo -e "\033[1;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1\033[0m"; }
error() { echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2; exit 1; }

# 必须 root 权限
if [ "$(id -u)" -ne 0 ]; then
    error "请用 root 或 sudo 运行！"
fi

# 修改 SSH 配置，启用密码登录
config_path="/etc/ssh/sshd_config"
info "修改 SSH 配置，临时启用密码登录..."

# 启用密码登录
if grep -qE "^PasswordAuthentication" "$config_path"; then
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$config_path"
else
    echo "PasswordAuthentication yes" >> "$config_path"
fi

# 验证配置语法
info "验证配置语法..."
sshd -t || error "SSH 配置语法错误！"

# 重启 SSH 服务
info "重启 SSH 服务..."
if systemctl is-active --quiet ssh; then
    systemctl restart ssh
elif systemctl is-active --quiet sshd; then
    systemctl restart sshd
fi

success "✅ 密码登录已启用！现在可以用 vv 用户密码登录服务器"
echo -e "\n下一步："
echo "1. 本地终端执行：ssh vv@服务器IP（输入 vv 用户密码登录）"
echo "2. 登录后配置 SSH 公钥（推荐），配置完成后可再次禁用密码登录"
