#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量，管道失败视为整体失败

# ==================== 工具函数 ====================
# 日志输出（带颜色+时间戳，更直观）
log() {
    echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"
}

# 成功提示
success() {
    echo -e "\033[1;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1\033[0m"
}

# 错误输出并退出
error() {
    echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2
    exit 1
}

# 检查是否为 root/sudo 权限
check_permission() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# 检测系统发行版（Debian/Ubuntu 通用）
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"  # 输出 debian 或 ubuntu
        VERSION_CODENAME="$VERSION_CODENAME"  # 输出 bullseye、jammy 等
        log "检测到系统：$DISTRO $VERSION_CODENAME"
    else
        error "无法检测系统发行版，仅支持 Debian/Ubuntu 系统！"
    fi
}

# 清理旧的 Docker 源（避免冲突）
clean_old_repo() {
    log "清理旧的 Docker 软件源..."
    # 删除 Ubuntu 源（你的核心问题）
    sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker-ce.list
    # 删除旧密钥（若存在）
    sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg /etc/apt/keyrings/docker.gpg
    log "旧源清理完成"
}

# 修复 AppArmor 缺失问题
fix_apparmor() {
    log "检测到 AppArmor 相关错误，开始修复..."
    
    # 安装 AppArmor 及工具
    log "正在安装 AppArmor 组件..."
    apt update >/dev/null 2>&1
    apt install -y apparmor apparmor-utils || error "AppArmor 安装失败！"
    
    # 启用并启动 AppArmor 服务
    log "正在启动 AppArmor 服务..."
    systemctl enable apparmor || error "AppArmor 启用开机自启失败！"
    systemctl start apparmor || error "AppArmor 服务启动失败！"
    
    # 重启 Docker 应用配置
    log "重启 Docker 服务..."
    systemctl restart docker || error "Docker 重启失败！"
    
    log "AppArmor 修复完成！"
}

# ==================== 核心安装逻辑 ====================
check_permission  # 先检查权限
detect_distro     # 检测系统（Debian/Ubuntu 通用）
clean_old_repo    # 清理旧源（关键修复）

log "====================================="
log "开始安装 Docker（$DISTRO 系统适配版）..."
log "====================================="

# 1. 更新系统软件包（显示进度，避免卡顿误解）
log "步骤 1/7：更新系统软件包列表..."
apt update -y || error "系统更新失败！请检查网络连接"

log "步骤 2/7：升级系统已安装软件（耗时可能较长）..."
apt upgrade -y || error "系统升级失败！"

# 2. 安装 Docker 依赖包（兼容 Debian/Ubuntu）
log "步骤 3/7：安装 Docker 必要依赖..."
apt install -y ca-certificates curl gnupg lsb-release apt-transport-https || error "依赖包安装失败！"

# 3. 添加 Docker 官方 GPG 密钥（统一路径，避免权限问题）
log "步骤 4/7：添加 Docker 官方 GPG 密钥..."
install -m 0755 -d /etc/apt/keyrings || error "创建密钥目录失败！"
curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error "GPG 密钥下载失败！"
chmod a+r /etc/apt/keyrings/docker.gpg  # 给所有用户读权限，避免后续警告

# 4. 配置 Docker 软件源（关键：根据系统自动选择 Debian/Ubuntu 源）
log "步骤 5/7：配置 Docker 官方软件源..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO \
$VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || error "软件源配置失败！"

# 5. 安装 Docker Engine 及相关组件
log "步骤 6/7：安装 Docker Engine 套件..."
apt update -y >/dev/null 2>&1 || error "更新 Docker 软件源失败！"
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
    # 捕获安装失败，输出详细日志
    log "Docker 安装失败，查看 apt 详细日志..."
    apt install -y docker-ce docker-ce-cli containerd.io  # 重新执行并显示详细错误
    error "Docker 安装失败！"
}

# 6. 启动 Docker 并设置开机自启（增加状态检查）
log "步骤 7/7：启动 Docker 服务并配置开机自启..."
systemctl start docker || error "Docker 服务启动失败！"
systemctl enable docker || error "Docker 开机自启配置失败！"

# 验证 Docker 服务状态
if ! systemctl is-active --quiet docker; then
    error "Docker 服务启动后异常退出！"
fi

# ==================== 测试验证 ====================
log "====================================="
log "开始测试 Docker 安装是否成功..."
log "====================================="

# 运行 hello-world 容器测试（添加超时和详细输出）
log "运行 hello-world 测试容器..."
if docker run --rm hello-world; then
    success "Docker 安装成功！已正常运行测试容器"
else
    # 捕获测试失败，检查是否为 AppArmor 错误
    log "测试容器运行失败，检查是否为 AppArmor 问题..."
    if ! command -v apparmor_status &> /dev/null || ! apparmor_status >/dev/null 2>&1; then
        fix_apparmor  # 修复 AppArmor 问题后重新测试
        # 重新测试 Docker
        if docker run --rm hello-world; then
            success "AppArmor 修复后，Docker 测试成功！"
        else
            error "AppArmor 修复后 Docker 仍无法运行，请手动执行 'docker logs hello-world' 排查"
        fi
    else
        error "Docker 测试失败，非 AppArmor 问题！请执行 'docker logs hello-world' 查看详细错误"
    fi
fi

# ==================== 完成提示（增强实用性） ====================
log "====================================="
success "Docker 安装配置全部完成！"
log "====================================="
log "📌 当前版本信息："
log "   Docker：$(docker --version | awk '{print $3}' | sed 's/,//')"
log "   Docker Compose：$(docker compose version | awk '{print $4}')"
log "====================================="
log "💡 使用说明："
log "   1. 免 sudo 运行 Docker（需注销重新登录）："
log "      sudo usermod -aG docker \$USER"
log "   2. 常用命令："
log "      - 查看容器：sudo docker ps"
log "      - 查看镜像：sudo docker images"
log "      - 启动/停止 Docker 服务：sudo systemctl start/stop docker"
log "      - 查看 Docker 日志：sudo journalctl -u docker"
log "====================================="
