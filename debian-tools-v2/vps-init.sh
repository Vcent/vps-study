
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 核心配置 ====================
USERNAME="vv"                # 要创建的用户名
SUDOERS_FILE="/etc/sudoers.d/90-cloud-init-users"  # sudo 权限配置文件
PASSWORD_LENGTH=12           # 自动生成密码长度
SPECIAL_CHARS="!@#$%^&*()_+-="  # 密码特殊字符集
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"  # 备份文件后缀（带时间戳）
SWAP_FILE="/swapfile"     # Swap 文件路径
FSTAB_ENTRY="$SWAP_FILE none swap sw 0 0"  # fstab 配置项
SSH_KEY_DIR="/root/ssh_keys_${USERNAME}_$(date +%Y%m%d%H%M%S)"  # 临时保存SSH密钥的目录

# ==================== 工具函数 ====================
# 日志输出（带颜色和时间戳）
info() { echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"; }
success() { echo -e "\033[1;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1\033[0m"; }
error() { echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2; exit 1; }

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# ==================== 用户创建功能 ====================
# 检查用户名是否已存在
check_user_exist() {
    if id -u "$USERNAME" >/dev/null 2>&1; then
        error "用户名 '$USERNAME' 已存在，请删除后重试！"
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
        info "备份原有 sudoers 配置文件：$SUDOERS_FILE -> ${SUDOERS_FILE}${BACKUP_SUFFIX}"
        cp -a "$SUDOERS_FILE" "${SUDOERS_FILE}${BACKUP_SUFFIX}" || error "备份 sudoers 文件失败！"
    fi

    # 2. 检查配置是否已存在（避免重复添加）
    if [ -f "$SUDOERS_FILE" ] && grep -qxF "$config_line" "$SUDOERS_FILE"; then
        info "sudo 配置已存在，无需重复添加"
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
    info "验证 sudoers 配置语法..."
    if visudo -cf "$temp_file"; then
        # 语法正确，覆盖原文件（设置正确权限：root 只读，避免其他用户修改）
        mv -f "$temp_file" "$SUDOERS_FILE"
        chmod 0440 "$SUDOERS_FILE"  # sudoers 文件必须是 440 权限，否则 sudo 报错
        info "sudo 配置添加成功，文件权限已设置为 0440"
    else
        # 语法错误，删除临时文件，恢复备份（如果有）
        rm -f "$temp_file"
        if [ -f "${SUDOERS_FILE}${BACKUP_SUFFIX}" ]; then
            info "sudoers 配置语法错误，恢复原有配置文件"
            mv -f "${SUDOERS_FILE}${BACKUP_SUFFIX}" "$SUDOERS_FILE"
        fi
        error "sudoers 配置语法错误，已恢复原有配置，请检查脚本后重试！"
    fi
}

# 生成 SSH 密钥对并配置
setup_ssh_keys() {
    local user_home="/home/$USERNAME"
    local user_ssh_dir="$user_home/.ssh"
    local user_authorized_keys="$user_ssh_dir/authorized_keys"
    
    # 创建保存私钥的目录
    info "创建 SSH 密钥存储目录：$SSH_KEY_DIR"
    mkdir -p "$SSH_KEY_DIR"
    chmod 700 "$SSH_KEY_DIR"
    
    # 生成 SSH 密钥对
    info "为用户 '$USERNAME' 生成 SSH 密钥对..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_DIR/${USERNAME}_id_rsa" -N "" -C "${USERNAME}@vps-$(date +%Y%m%d)" || error "生成 SSH 密钥对失败！"
    
    # 确保用户的 .ssh 目录存在且权限正确
    if [ ! -d "$user_ssh_dir" ]; then
        info "创建用户 '$USERNAME' 的 .ssh 目录"
        mkdir -p "$user_ssh_dir"
        chown "$USERNAME:$USERNAME" "$user_ssh_dir"
        chmod 700 "$user_ssh_dir"
    fi
    
    # 添加公钥到 authorized_keys
    info "配置公钥到用户 '$USERNAME' 的 authorized_keys 文件"
    cat "$SSH_KEY_DIR/${USERNAME}_id_rsa.pub" >> "$user_authorized_keys"
    chown "$USERNAME:$USERNAME" "$user_authorized_keys"
    chmod 600 "$user_authorized_keys"
    
    success "SSH 密钥对生成成功！"
    success "公钥已添加到 $user_authorized_keys"
    success "私钥保存在：$SSH_KEY_DIR/${USERNAME}_id_rsa"
    
    # 显示私钥内容（以便用户可以复制）
    echo -e "\n\033[1;33m======================================\033[0m"
    echo -e "\033[1;33m请复制以下私钥内容并保存到您的本地机器：\033[0m"
    echo -e "\033[1;33m======================================\033[0m"
    cat "$SSH_KEY_DIR/${USERNAME}_id_rsa"
    echo -e "\033[1;33m======================================\033[0m"
    echo -e "\033[1;33m警告：请确保安全保存此私钥，切勿泄露给他人！\033[0m"
    echo -e "\033[1;33m======================================\033[0m\n"
    
    # 提供登录测试指南
    local server_ip=$(hostname -I | awk '{print $1}')
    success "====================================="
    success "SSH 登录测试指南："
    success "1. 在本地机器上保存私钥："
    success "   mkdir -p ~/.ssh"
    success "   复制私钥内容到 ~/.ssh/${USERNAME}_id_rsa"
    success "   chmod 600 ~/.ssh/${USERNAME}_id_rsa"
    success "2. 测试 SSH 登录："
    success "   ssh -i ~/.ssh/${USERNAME}_id_rsa ${USERNAME}@${server_ip}"
    success "3. 登录成功后建议修改密码："
    success "   passwd"
    success "====================================="
}

# 创建用户功能
create_user() {
    info "开始创建用户 '$USERNAME'..."
    
    check_user_exist    # 检查用户是否已存在

    # 1. 生成自动密码
    local PASSWORD=$(generate_strong_password)
    info "已生成自动密码：$PASSWORD（请妥善保存！）"

    # 2. 创建用户并自动设置密码（无需交互）
    info "正在创建用户 '$USERNAME'..."
    # useradd 参数说明：-m 自动创建家目录，-s 指定登录 Shell
    useradd -m -s /bin/bash "$USERNAME" || error "创建用户失败！"
    # 用 chpasswd 自动设置密码（避免交互）
    echo "$USERNAME:$PASSWORD" | chpasswd || error "设置用户密码失败！"

    # 3. 将用户添加到 sudo 组
    info "正在添加 '$USERNAME' 到 sudo 组..."
    usermod -aG sudo "$USERNAME" || error "添加 sudo 组失败！"

    # 4. 同步当前用户（运行脚本的用户）的 .ssh 目录到新用户家目录
    info "正在检查是否需要同步现有 .ssh 目录..."
    if [ -d "$HOME/.ssh" ]; then
        info "同步 .ssh 密钥到 /home/$USERNAME..."
        rsync --archive --chown="$USERNAME:$USERNAME" "$HOME/.ssh" "/home/$USERNAME" || error "同步 .ssh 目录失败！"
        # 确保 .ssh 目录权限安全（700）、authorized_keys 权限 600
        chmod 700 "/home/$USERNAME/.ssh"
        [ -f "/home/$USERNAME/.ssh/authorized_keys" ] && chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
    else
        info "当前用户家目录下无 .ssh 目录，将直接为新用户生成 SSH 密钥"
    fi

    # 5. 为用户生成 SSH 密钥对
    setup_ssh_keys

    # 6. 安全配置免密码 sudo 权限
    info "正在配置 '$USERNAME' 免密码 sudo 权限..."
    safe_add_sudo_config  # 调用安全添加函数

    # 完成提示
    success "====================================="
    success "用户 '$USERNAME' 创建配置完成！"
    success "用户名：$USERNAME"
    success "密码：$PASSWORD（请立即保存，首次登录请修改！）"
    success "权限：免密码 sudo + sudo 组成员"
    success "SSH 私钥：已生成并显示在屏幕上，请复制保存！"
    success "私钥文件路径：$SSH_KEY_DIR/${USERNAME}_id_rsa"
    success "====================================="
}

# ==================== Swap 创建功能 ====================
# 检查系统是否已有 Swap
check_existing_swap() {
    info "检查系统是否已存在 Swap 分区..."
    if swapon --show >/dev/null 2>&1; then
        info "当前系统已存在 Swap 分区："
        swapon --show
        read -p $'\033[1;33m是否继续创建新的 Swap？（y/N）\033[0m' confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            error "用户取消操作，脚本退出！"
        fi
    else
        info "系统暂无 Swap 分区，继续创建..."
    fi
}

# 检查 Swap 文件是否已存在
check_swap_file() {
    if [ -f "$SWAP_FILE" ]; then
        error "Swap 文件 $SWAP_FILE 已存在！请先删除（sudo rm -f $SWAP_FILE）或修改脚本中的 SWAP_FILE 路径"
    fi
}

# 创建 Swap 文件（优先使用 fallocate，失败则用 dd）
create_swap_file() {
    info "创建 $SWAP_SIZE 的 Swap 文件：$SWAP_FILE"
    if command -v fallocate &> /dev/null; then
        # fallocate 速度更快（推荐）
        sudo fallocate -l "$SWAP_SIZE" "$SWAP_FILE" || error "fallocate 创建 Swap 文件失败！"
    else
        # 兼容无 fallocate 的系统（如部分精简版 Linux）
        info "fallocate 未找到，使用 dd 命令创建（速度较慢，请耐心等待）..."
        # 转换 SWAP_SIZE 为 MB（例如 2G → 2048）
        local size_num=$(echo "$SWAP_SIZE" | sed 's/[^0-9]//g')
        local size_unit=$(echo "$SWAP_SIZE" | sed 's/[0-9]//g')
        
        if [[ "$size_unit" =~ ^[Gg]$ ]]; then
            local mb_size=$((size_num * 1024))
        else
            local mb_size=$size_num
        fi
        
        sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$mb_size" status=progress || error "dd 创建 Swap 文件失败！"
    fi
}

# 设置 Swap 文件权限（仅 root 可读写，避免安全风险）
set_swap_permissions() {
    info "设置 Swap 文件权限为 600（仅 root 可访问）..."
    sudo chmod 600 "$SWAP_FILE" || error "设置 Swap 文件权限失败！"
}

# 格式化 Swap 文件
format_swap() {
    info "格式化 Swap 文件..."
    sudo mkswap "$SWAP_FILE" || error "格式化 Swap 文件失败！"
}

# 启用 Swap 文件
enable_swap() {
    info "启用 Swap 文件..."
    sudo swapon "$SWAP_FILE" || error "启用 Swap 文件失败！"
}

# 设置永久生效（添加到 /etc/fstab）
persist_swap() {
    info "配置 Swap 永久生效（添加到 /etc/fstab）..."
    # 检查配置是否已存在，避免重复添加
    if grep -qxF "$FSTAB_ENTRY" /etc/fstab; then
        info "/etc/fstab 中已存在该 Swap 配置，无需重复添加"
    else
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab || error "写入 /etc/fstab 失败！"
    fi
}

# 验证 Swap 是否生效
verify_swap() {
    info "验证 Swap 配置是否生效..."
    echo -e "\n=== 当前 Swap 状态 ==="
    swapon --show
    echo -e "\n=== 系统内存/swap 使用情况 ==="
    free -h

    # 检查 Swap 是否正常加载
    if swapon --show | grep -q "$SWAP_FILE"; then
        success "$SWAP_SIZE Swap 分区创建并启用成功！"
    else
        error "Swap 分区创建失败，请检查日志排查问题！"
    fi
}

# 创建 Swap 功能
create_swap() {
    info "开始创建 Swap 分区..."
    
    # 获取系统内存并计算 Swap 大小（2倍）
    local MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    local SWAP_SIZE="${MEM_TOTAL}M"
    
    # 如果内存大于4GB，Swap 大小最大为8GB
    if [ "$MEM_TOTAL" -gt 4096 ]; then
        SWAP_SIZE="8G"
        info "系统内存大于4GB，设置 Swap 大小为 8GB（避免占用过多磁盘空间）"
    else
        info "根据系统内存计算，设置 Swap 大小为 $SWAP_SIZE（系统内存的2倍）"
    fi
    
    check_existing_swap      # 检查已有 Swap
    check_swap_file          # 检查 Swap 文件是否存在
    create_swap_file         # 创建 Swap 文件
    set_swap_permissions     # 设置权限
    format_swap              # 格式化
    enable_swap              # 启用
    persist_swap             # 永久生效
    verify_swap              # 验证

    success "====================================="
    success "Swap 分区创建完成！"
    success "Swap 大小：$SWAP_SIZE"
    success "Swap 文件路径：$SWAP_FILE"
    success "已设置开机自启"
    success "====================================="
}

# ==================== 帮助信息 ====================
show_help() {
    echo -e "\033[1;34m====================================="
    echo -e "VPS 初始化脚本"
    echo -e "=====================================\033[0m"
    echo -e "用法：sudo bash $0 [选项]"
    echo -e ""
    echo -e "选项："
    echo -e "  --user       创建新用户 vv 并配置 sudo 免密权限和 SSH 密钥"
    echo -e "  --swap       创建 Swap 分区（大小为系统内存的 2 倍）"
    echo -e "  --all        执行所有功能（创建用户和 Swap）"
    echo -e "  --help       显示此帮助信息"
    echo -e ""
    echo -e "示例："
    echo -e "  sudo bash $0 --user      # 仅创建用户"
    echo -e "  sudo bash $0 --swap      # 仅创建 Swap"
    echo -e "  sudo bash $0 --all       # 执行所有功能"
    echo -e ""
}

# ==================== 主流程 ====================
main() {
    # 检查参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    check_root  # 检查 root 权限
    
    # 处理参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --user)
                create_user
                shift
                ;;
            --swap)
                create_swap
                shift
                ;;
            --all)
                create_user
                create_swap
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "未知选项：$1，请使用 --help 查看可用选项"
                ;;
        esac
done
}

# 启动主流程
main "$@"
