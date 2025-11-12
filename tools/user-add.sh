#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 核心配置 ====================
USERNAME="vv"                # 要创建的用户名
SUDOERS_FILE="/etc/sudoers.d/90-cloud-init-users"  # sudo 权限配置文件
PASSWORD_LENGTH=12           # 自动生成密码长度
SPECIAL_CHARS="!@#$%^&*()_+-="  # 密码特殊字符集
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"  # 备份文件后缀（带时间戳）

# ==================== 工具函数 ====================
# 日志输出（带时间戳）
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

# 错误输出并退出
error() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
    exit 1
}

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# 检查用户名是否已存在
check_user_exist() {
    if id -u "$USERNAME" >/dev/null 2>&1; then
        error "用户名 '$USERNAME' 已存在，脚本退出！"
    fi
}

# 自动生成强密码（12位：大写3位+小写4位+数字3位+特殊字符2位）
generate_strong_password() {
    local upper=$(tr -dc 'A-Z' < /dev/urandom | head -c 3)
    local lower=$(tr -dc 'a-z' < /dev/urandom | head -c 4)
    local digit=$(tr -dc '0-9' < /dev/urandom | head -c 3)
    local special=$(tr -dc "$SPECIAL_CHARS" < /dev/urandom | head -c 2)
    
    # 打乱字符顺序（避免固定格式）
    echo -n "$upper$lower$digit$special" | shuf | tr -d '\n'
}

# 安全添加 sudo 配置（避免删除原有内容）
safe_add_sudo_config() {
    local config_line="$USERNAME ALL=(ALL) NOPASSWD:ALL"
    
    # 1. 先备份原有 sudoers 文件（如果存在）
    if [ -f "$SUDOERS_FILE" ]; then
        log "备份原有 sudoers 配置文件：$SUDOERS_FILE -> ${SUDOERS_FILE}${BACKUP_SUFFIX}"
        cp -a "$SUDOERS_FILE" "${SUDOERS_FILE}${BACKUP_SUFFIX}" || error "备份 sudoers 文件失败！"
    fi

    # 2. 检查配置是否已存在（避免重复添加）
    if [ -f "$SUDOERS_FILE" ] && grep -qxF "$config_line" "$SUDOERS_FILE"; then
        log "sudo 配置已存在，无需重复添加"
        return 0
    fi

    # 3. 追加新配置（原子操作：先写入临时文件，再覆盖，避免中途失败）
    local temp_file=$(mktemp)
    if [ -f "$SUDOERS_FILE" ]; then
        # 保留原有内容，追加新配置
        cat "$SUDOERS_FILE" > "$temp_file"
        echo "$config_line" >> "$temp_file"
    else
        # 文件不存在，直接写入新配置
        echo "$config_line" > "$temp_file"
    fi

    # 4. 验证临时文件语法（安全第一）
    log "验证 sudoers 配置语法..."
    if visudo -cf "$temp_file"; then
        # 语法正确，覆盖原文件（设置正确权限：root 只读，避免其他用户修改）
        mv -f "$temp_file" "$SUDOERS_FILE"
        chmod 0440 "$SUDOERS_FILE"  # sudoers 文件必须是 440 权限，否则 sudo 报错
        log "sudo 配置添加成功，文件权限已设置为 0440"
    else
        # 语法错误，删除临时文件，恢复备份（如果有）
        rm -f "$temp_file"
        if [ -f "${SUDOERS_FILE}${BACKUP_SUFFIX}" ]; then
            log "sudoers 配置语法错误，恢复原有配置文件"
            mv -f "${SUDOERS_FILE}${BACKUP_SUFFIX}" "$SUDOERS_FILE"
        fi
        error "sudoers 配置语法错误，已恢复原有配置，请检查脚本后重试！"
    fi
}

# ==================== 核心逻辑 ====================
check_root          # 检查 root 权限
check_user_exist    # 检查用户是否已存在

# 1. 生成自动密码
PASSWORD=$(generate_strong_password)
log "已生成自动密码：$PASSWORD（请妥善保存！）"

# 2. 创建用户并自动设置密码（无需交互）
log "正在创建用户 '$USERNAME'..."
# useradd 参数说明：-m 自动创建家目录，-s 指定登录 Shell
useradd -m -s /bin/bash "$USERNAME" || error "创建用户失败！"
# 用 chpasswd 自动设置密码（避免交互）
echo "$USERNAME:$PASSWORD" | chpasswd || error "设置用户密码失败！"

# 3. 将用户添加到 sudo 组
log "正在添加 '$USERNAME' 到 sudo 组..."
usermod -aG sudo "$USERNAME" || error "添加 sudo 组失败！"

# 4. 同步当前用户（运行脚本的用户）的 .ssh 目录到新用户家目录
log "正在同步 .ssh 密钥到 /home/$USERNAME..."
if [ -d "$HOME/.ssh" ]; then
    rsync --archive --chown="$USERNAME:$USERNAME" "$HOME/.ssh" "/home/$USERNAME" || error "同步 .ssh 目录失败！"
    # 确保 .ssh 目录权限安全（700）、authorized_keys 权限 600
    chmod 700 "/home/$USERNAME/.ssh"
    [ -f "/home/$USERNAME/.ssh/authorized_keys" ] && chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
else
    log "警告：当前用户家目录下无 .ssh 目录，跳过密钥同步"
fi

# 5. 安全配置免密码 sudo 权限（核心修复点）
log "正在配置 '$USERNAME' 免密码 sudo 权限..."
safe_add_sudo_config  # 调用安全添加函数，不再直接删除文件

# ==================== 完成提示 ====================
log "====================================="
log "用户 '$USERNAME' 创建配置完成！"
log "用户名：$USERNAME"
log "密码：$PASSWORD（请立即保存，首次登录可修改）"
log "权限：免密码 sudo + sudo 组成员"
log "SSH 密钥：已同步当前用户的 .ssh 目录（支持密钥登录）"
log "sudoers 备份：${SUDOERS_FILE}${BACKUP_SUFFIX}（如需恢复可手动操作）"
log "====================================="
