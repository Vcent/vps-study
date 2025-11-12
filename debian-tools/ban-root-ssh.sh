#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 工具函数 ====================
info() { echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"; }
success() { echo -e "\033[1;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1\033[0m"; }
error() { echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2; exit 1; }

# 检查是否为 root 权限（必须 root 才能修改 SSH 配置）
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# 检查是否存在非 root 管理员用户（避免禁止 root 后无账号登录）
check_non_root_user() {
    info "检查是否存在非 root 管理员用户（UID 1000+ 且在 sudo 组）..."
    # 查找 UID 1000+ 且属于 sudo 组的用户
    ADMIN_USER=$(getent passwd | awk -F: '$3 >= 1000 {print $1}' | xargs -I {} groups {} | grep -w "sudo" | head -n1 | awk '{print $1}')
    
    if [ -z "$ADMIN_USER" ]; then
        info "未找到可用的非 root 管理员用户！"
        read -p $'\033[1;33m是否现在创建一个（推荐）？（y/N）\033[0m' choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            create_admin_user
        else
            error "禁止 root 登录后无可用管理员账号，脚本退出！"
        fi
    else
        success "找到可用管理员用户：$ADMIN_USER（可用于登录和 sudo 操作）"
    fi
}

# 创建非 root 管理员用户（可选）
create_admin_user() {
    read -p $'\033[1;33m请输入新用户名：\033[0m' username
    if id -u "$username" >/dev/null 2>&1; then
        error "用户 $username 已存在！"
    fi
    info "创建管理员用户 $username 并添加到 sudo 组..."
    useradd -m -s /bin/bash "$username" || error "创建用户失败！"
    passwd "$username" || error "设置用户密码失败！"
    usermod -aG sudo "$username" || error "添加用户到 sudo 组失败！"
    success "管理员用户 $username 创建成功（可 sudo 切换 root）"
}

# 备份 SSH 配置文件（避免修改错误导致无法恢复）
backup_ssh_config() {
    local config_path="/etc/ssh/sshd_config"
    local backup_path="${config_path}.bak.$(date +'%Y%m%d%H%M%S')"
    info "备份 SSH 配置文件到：$backup_path"
    cp -a "$config_path" "$backup_path" || error "备份 SSH 配置失败！"
    success "SSH 配置备份完成"
}

# 禁止 root 密码登录 + 禁止 root 密钥登录（可选）
disable_root_login() {
    local config_path="/etc/ssh/sshd_config"
    info "开始修改 SSH 配置，禁止 root 登录..."

    # 1. 禁止 root 密码登录（PasswordAuthentication no）
    if grep -qE "^PasswordAuthentication" "$config_path"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$config_path"
    else
        echo "PasswordAuthentication no" >> "$config_path"
    fi

    # 2. 禁止 root 登录（PermitRootLogin no）
    if grep -qE "^PermitRootLogin" "$config_path"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$config_path"
    else
        echo "PermitRootLogin no" >> "$config_path"
    fi

    # 3. 可选：禁止空密码登录（增强安全）
    if grep -qE "^PermitEmptyPasswords" "$config_path"; then
        sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$config_path"
    else
        echo "PermitEmptyPasswords no" >> "$config_path"
    fi

    # 4. 可选：启用公钥登录（如果之前禁用了）
    if grep -qE "^PubkeyAuthentication" "$config_path"; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$config_path"
    else
        echo "PubkeyAuthentication yes" >> "$config_path"
    fi

    success "SSH 配置修改完成：已禁止 root 登录"
}

# 验证 SSH 配置是否合法（避免语法错误导致 SSH 服务启动失败）
validate_ssh_config() {
    info "验证 SSH 配置文件语法..."
    if sshd -t; then
        success "SSH 配置语法正确"
    else
        error "SSH 配置语法错误！请检查修改或恢复备份文件"
    fi
}

# 重启 SSH 服务（应用配置）
restart_ssh_service() {
    info "重启 SSH 服务应用配置..."
    # 兼容不同系统的 SSH 服务名（debian/ubuntu 是 ssh，centos/rhel 是 sshd）
    if systemctl is-active --quiet ssh; then
        systemctl restart ssh || error "重启 SSH 服务失败！"
    elif systemctl is-active --quiet sshd; then
        systemctl restart sshd || error "重启 SSH 服务失败！"
    else
        error "未找到 SSH 服务（可能是 ssh 或 sshd）"
    fi
    success "SSH 服务重启成功"
}

# 验证禁止 root 登录是否生效
verify_disable_root() {
    info "验证 root 登录是否已禁止..."
    local sshd_status=$(sshd -T | grep -E "permitrootlogin|passwordauthentication")
    echo -e "\n=== SSH 关键配置状态 ==="
    echo "$sshd_status" | awk '{print $1 ": " $2}'
    
    if echo "$sshd_status" | grep -q "permitrootlogin=no" && echo "$sshd_status" | grep -q "passwordauthentication=no"; then
        success "✅ 禁止 root 登录配置已生效！"
    else
        error "❌ 禁止 root 登录配置未生效，请检查！"
    fi
}

# ==================== 核心流程 ====================
main() {
    clear
    echo -e "\033[1;34m====================================="
    echo -e "          禁止 root 登录脚本"
    echo -e "=====================================\033[0m"
    echo "⚠️  警告：执行后 root 用户将无法直接登录，需通过非 root 管理员账号登录"
    echo "⚠️  请确保：1. 存在非 root 管理员账号 2. 账号已配置密码或 SSH 密钥"
    echo -e "\033[1;33m请仔细阅读以上警告，确认后按回车继续...\033[0m"
    read -r

    check_root               # 检查 root 权限
    check_non_root_user      # 检查/创建非 root 管理员用户
    backup_ssh_config        # 备份 SSH 配置
    disable_root_login       # 禁止 root 登录
    validate_ssh_config      # 验证配置语法
    restart_ssh_service      # 重启 SSH 服务
    verify_disable_root      # 验证生效

    echo -e "\n\033[1;32m====================================="
    echo -e "🎉 禁止 root 登录配置完成！"
    echo -e "=====================================\033[0m"
    echo -e "📌 后续登录说明："
    echo -e "   1. 用管理员用户登录：ssh $ADMIN_USER@服务器IP"
    echo -e "   2. 切换到 root 用户：sudo -i（输入用户密码）"
    echo -e "   3. 如需恢复 root 登录：编辑 /etc/ssh/sshd_config，将 PermitRootLogin 改为 yes，重启 SSH 服务"
    echo -e "====================================="
}

# 启动主流程
main
