#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量，管道失败视为整体失败

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

# 检查是否为 root/sudo 权限
check_permission() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
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

log "====================================="
log "开始在 Ubuntu 系统安装 Docker..."
log "====================================="

# 1. 更新系统软件包
log "步骤 1/7：更新系统软件包列表..."
apt update || error "系统更新失败！"

log "步骤 2/7：升级系统已安装软件..."
apt upgrade -y || error "系统升级失败！"

# 2. 安装 Docker 依赖包
log "步骤 3/7：安装 Docker 必要依赖..."
apt install -y ca-certificates curl gnupg lsb-release || error "依赖包安装失败！"

# 3. 添加 Docker 官方 GPG 密钥
log "步骤 4/7：添加 Docker 官方 GPG 密钥..."
install -m 0755 -d /etc/apt/keyrings || error "创建密钥目录失败！"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error "GPG 密钥下载失败！"

# 4. 配置 Docker 软件源
log "步骤 5/7：配置 Docker 官方软件源..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || error "软件源配置失败！"

# 5. 安装 Docker Engine 及相关组件
log "步骤 6/7：安装 Docker Engine 套件..."
apt update >/dev/null 2>&1 || error "更新 Docker 软件源失败！"
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error "Docker 安装失败！"

# 6. 启动 Docker 并设置开机自启
log "步骤 7/7：启动 Docker 服务并配置开机自启..."
systemctl start docker || error "Docker 服务启动失败！"
systemctl enable docker || error "Docker 开机自启配置失败！"

# ==================== 测试验证 ====================
log "====================================="
log "开始测试 Docker 安装是否成功..."
log "====================================="

# 运行 hello-world 容器测试
if docker run --rm hello-world; then
    log "✅ Docker 安装成功！已正常运行测试容器。"
else
    # 捕获测试失败，检查是否为 AppArmor 错误
    log "❌ Docker 测试容器运行失败，检查是否为 AppArmor 问题..."
    if ! apparmor_status >/dev/null 2>&1; then
        fix_apparmor  # 修复 AppArmor 问题后重新测试
        # 重新测试 Docker
        if docker run --rm hello-world; then
            log "✅ AppArmor 修复后，Docker 测试成功！"
        else
            error "❌ AppArmor 修复后 Docker 仍无法运行，请手动排查问题！"
        fi
    else
        error "❌ Docker 测试失败，非 AppArmor 问题，请手动排查！"
    fi
fi

# ==================== 完成提示 ====================
log "====================================="
log "Docker 安装配置全部完成！"
log "当前 Docker 版本：$(docker --version)"
log "当前 Docker Compose 版本：$(docker compose version | awk '{print $4}')"
log "====================================="
log "使用说明："
log "1. 运行 Docker 命令：sudo docker [命令]（如 sudo docker ps）"
log "2. 若需免 sudo 使用 Docker：sudo usermod -aG docker 用户名（需注销重新登录）"
log "3. 查看 Docker 状态：sudo systemctl status docker"
log "4. 停止 Docker 服务：sudo systemctl stop docker"
log "====================================="
