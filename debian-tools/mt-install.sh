#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 核心配置（可按需修改）====================
CONTAINER_NAME="metatube"       # 容器名称
HOST_PORT="12345"               # 宿主机端口（对外暴露）
CONTAINER_PORT="8080"           # 容器内部端口
CONFIG_DIR="/opt/src/metatube"  # 配置文件/数据库挂载目录
IMAGE_NAME="ghcr.io/metatube-community/metatube-server:latest"  # 镜像名称
DSN_PATH="/config/metatube.db"  # 数据库路径（容器内）

# ==================== 工具函数 ====================
info() { echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"; }
success() { echo -e "\033[1;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1\033[0m"; }
error() { echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2; exit 1; }

# 检查是否为 root/sudo 权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# 检查 Docker 是否已安装并运行
check_docker() {
    info "检查 Docker 环境..."
    if ! command -v docker &> /dev/null; then
        error "未安装 Docker！请先安装 Docker 后再运行此脚本（可使用之前的 install_docker.sh 脚本）"
    fi
    if ! systemctl is-active --quiet docker; then
        info "Docker 服务未启动，正在启动..."
        systemctl start docker || error "Docker 服务启动失败！"
    fi
    if ! systemctl is-enabled --quiet docker; then
        info "Docker 未设置开机自启，正在配置..."
        systemctl enable docker || error "Docker 开机自启配置失败！"
    fi
    success "Docker 环境正常（已启动+开机自启）"
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if lsof -i:"$port" >/dev/null 2>&1; then
        error "宿主机端口 $port 已被占用！请释放端口或修改脚本中的 HOST_PORT 配置"
    fi
}

# 检查容器是否已存在
check_container() {
    if docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        info "容器 $CONTAINER_NAME 已存在，正在停止并删除旧容器..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || error "停止旧容器失败！"
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || error "删除旧容器失败！"
        success "旧容器已删除"
    fi
}

# 创建配置目录并设置权限
create_config_dir() {
    info "创建配置目录：$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR" || error "创建配置目录失败！"
    # 设置目录权限（确保容器可读写）
    chmod 755 "$CONFIG_DIR" || error "设置配置目录权限失败！"
    success "配置目录创建并授权成功"
}

# 拉取镜像并启动容器
run_container() {
    info "开始部署 Metatube 容器..."
    info "镜像名称：$IMAGE_NAME"
    info "端口映射：$HOST_PORT:$CONTAINER_PORT"
    info "数据挂载：$CONFIG_DIR → /config"
    info "数据库路径：$DSN_PATH"

    # 执行 Docker 运行命令
    docker run -d \
      --name "$CONTAINER_NAME" \
      -p "$HOST_PORT:$CONTAINER_PORT" \
      -v "$CONFIG_DIR:/config" \
      -e MT_MOVIE_PROVIDER_TOKYO_HOT_PRIORITY=1020 \
      --restart=always \
      "$IMAGE_NAME" \
      -dsn "$DSN_PATH" || error "容器启动失败！请查看日志：docker logs $CONTAINER_NAME"

    # 检查容器状态（等待3秒确保启动完成）
    sleep 3
    if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then
        success "Metatube 容器启动成功！"
    else
        error "容器启动后异常退出，日志：$(docker logs "$CONTAINER_NAME")"
    fi
}

# 验证部署结果
verify_deployment() {
    info "验证部署结果..."
    echo -e "\n=== 部署信息汇总 ==="
    echo -e "容器名称：$CONTAINER_NAME"
    echo -e "访问地址：http://服务器IP:$HOST_PORT"
    echo -e "配置/数据库目录：$CONFIG_DIR"
    echo -e "容器状态：$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")"
    echo -e "镜像版本：$IMAGE_NAME"
    echo -e "====================\n"

    # 检查端口是否监听
    if netstat -tuln | grep -q ":$HOST_PORT"; then
        success "端口 $HOST_PORT 已正常监听，部署完成！"
    else
        info "端口 $HOST_PORT 暂未监听，可能容器正在初始化，请等待10秒后重试访问"
    fi
}

# ==================== 核心流程 ====================
main() {
    clear
    echo -e "\033[1;34m====================================="
    echo -e "        Metatube 一键部署脚本"
    echo -e "=====================================\033[0m"

    check_root          # 检查权限
    check_docker        # 检查 Docker 环境
    check_port "$HOST_PORT"  # 检查端口是否占用
    check_container     # 检查并删除旧容器
    create_config_dir   # 创建配置目录
    run_container       # 启动容器
    verify_deployment   # 验证部署

    echo -e "\033[1;32m====================================="
    echo -e "🎉 部署完成！请访问：http://服务器IP:$HOST_PORT"
    echo -e "=====================================\033[0m"
    echo -e "常用命令："
    echo -e "  查看日志：sudo docker logs -f $CONTAINER_NAME"
    echo -e "  重启容器：sudo docker restart $CONTAINER_NAME"
    echo -e "  停止容器：sudo docker stop $CONTAINER_NAME"
    echo -e "  删除容器：sudo docker rm -f $CONTAINER_NAME"
    echo -e "  备份数据：cp -a $CONFIG_DIR/metatube.db 备份路径"
}

# 启动主流程
main
