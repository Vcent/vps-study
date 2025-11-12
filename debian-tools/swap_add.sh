#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 核心配置 ====================
SWAP_SIZE="512M"          # Swap 大小（512MB）
SWAP_FILE="/swapfile"     # Swap 文件路径
FSTAB_ENTRY="$SWAP_FILE none swap sw 0 0"  # fstab 配置项

# ==================== 工具函数 ====================
# 日志输出（带颜色和时间戳）
info() { echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"; }
success() { echo -e "\033[1;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1\033[0m"; }
error() { echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2; exit 1; }

# 检查是否为 root 权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# 检查系统是否已有 Swap
check_existing_swap() {
    info "检查系统是否已存在 Swap 分区..."
    if swapon --show >/dev/null 2>&1; then
        info "当前系统已存在 Swap 分区："
        swapon --show
        read -p $'\033[1;33m是否继续创建新的 512MB Swap？（y/N）\033[0m' confirm
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
        # 转换 SWAP_SIZE 为 MB（512M → 512）
        local mb_size=$(echo "$SWAP_SIZE" | sed 's/[Mm]$//')
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
        success "512MB Swap 分区创建并启用成功！"
    else
        error "Swap 分区创建失败，请检查日志排查问题！"
    fi
}

# ==================== 核心流程 ====================
main() {
    clear
    echo -e "\033[1;34m====================================="
    echo -e "Linux 一键创建 512MB Swap 分区脚本"
    echo -e "=====================================\033[0m"

    check_root               # 检查 root 权限
    check_existing_swap      # 检查已有 Swap
    check_swap_file          # 检查 Swap 文件是否存在
    create_swap_file         # 创建 Swap 文件
    set_swap_permissions     # 设置权限
    format_swap              # 格式化
    enable_swap              # 启用
    persist_swap             # 永久生效
    verify_swap              # 验证

    echo -e "\n\033[1;32m====================================="
    echo -e "操作完成！后续说明："
    echo -e "1. 临时关闭 Swap：sudo swapoff $SWAP_FILE"
    echo -e "2. 永久删除 Swap：sudo swapoff $SWAP_FILE && sudo rm -f $SWAP_FILE && sudo sed -i '/$SWAP_FILE/d' /etc/fstab"
    echo -e "3. 查看 Swap 使用率：htop 或 free -h"
    echo -e "=====================================\033[0m"
}

# 启动主流程
main
