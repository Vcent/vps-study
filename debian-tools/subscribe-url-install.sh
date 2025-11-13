#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 配置参数（可按需修改）====================
NGINX_DIR="/opt/src/nginx-shadowrocket"  # Nginx 配置和订阅文件目录
SUBSCRIBE_FILE="ssr_subscribe.txt"      # 订阅文件名
LISTEN_ADDR="127.0.0.1"                 # 监听地址（仅本地）
LISTEN_PORT="11111"                     # 监听端口
NGINX_CONF="nginx.conf"                 # Nginx 配置文件名
CONTAINER_NAME="nginx-shadowrocket"      # Docker 容器名
NGINX_IMAGE="nginx:alpine"              # Nginx 镜像（轻量版）
SUBSCRIBE_PATH="/ssr_subscribe"         # 订阅访问路径（客户端访问用）

# ==================== 工具函数 ====================
info() { echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"; }
success() { echo -e "\033[1;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1\033[0m"; }
error() { echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2; exit 1; }

# 检查是否为 root 权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# 检查 Docker 是否安装，未安装则自动安装
check_and_install_docker() {
    info "检查 Docker 是否已安装..."
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        success "Docker 已安装（版本：$(docker --version | awk '{print $3}' | sed 's/,//')）"
        # 确保 Docker 服务已启动
        if ! systemctl is-active --quiet docker; then
            info "Docker 服务未启动，正在启动..."
            systemctl enable --now docker || error "Docker 服务启动失败！"
            success "Docker 服务启动成功"
        fi
    else
        info "Docker 未安装，开始自动安装..."
        # 安装 Docker 依赖
        sudo apt update >/dev/null 2>&1 || error "系统更新失败！"
        sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https >/dev/null 2>&1 || error "Docker 依赖安装失败！"
        # 安装 Docker 官方脚本
        curl -fsSL get.docker.com | sudo bash >/dev/null 2>&1 || error "Docker 安装脚本执行失败！"
        # 启动并设置开机自启
        systemctl enable --now docker || error "Docker 服务启动失败！"
        success "Docker 安装并启动成功！"
    fi
}

# 准备目录和订阅文件
prepare_files() {
    info "准备目录和订阅文件..."
    # 创建工作目录
    if [ ! -d "$NGINX_DIR" ]; then
        mkdir -p "$NGINX_DIR" || error "创建目录 $NGINX_DIR 失败！"
        success "目录 $NGINX_DIR 创建成功"
    else
        info "目录 $NGINX_DIR 已存在，跳过创建"
    fi

    cp $SUBSCRIBE_FILE $NGINX_DIR/

    # 切换到工作目录
    cd "$NGINX_DIR" || error "进入目录 $NGINX_DIR 失败！"

    # 检查订阅文件是否存在，不存在则创建并提示用户编辑
    if [ ! -f "$SUBSCRIBE_FILE" ]; then
        touch "$SUBSCRIBE_FILE" || error "创建订阅文件 $SUBSCRIBE_FILE 失败！"
        info "订阅文件 $SUBSCRIBE_FILE 已创建（当前为空）"
        echo -e "\033[1;33m⚠️  请先编辑订阅文件，添加 VLESS 订阅链接（一行一个节点）：\033[0m"
        echo -e "   nano $NGINX_DIR/$SUBSCRIBE_FILE"
        echo -e "\033[1;33m编辑完成后，重新运行此脚本！\033[0m"
        exit 0
    else
        # 检查订阅文件是否为空
        if [ -z "$(cat "$SUBSCRIBE_FILE" | tr -d '[:space:]')" ]; then
            error "订阅文件 $SUBSCRIBE_FILE 为空，请先添加 VLESS 订阅链接！"
        fi
        success "订阅文件 $SUBSCRIBE_FILE 已存在且非空"
    fi

    # 创建 Nginx 配置文件
    info "创建 Nginx 配置文件 $NGINX_CONF..."
    cat > "$NGINX_CONF" <<EOF
events {}

http {
    server {
        listen 0.0.0.0:$LISTEN_PORT;
        server_name localhost;

        location $SUBSCRIBE_PATH {
            default_type text/plain;
            alias /etc/nginx/$SUBSCRIBE_FILE;
            try_files \$uri =404;
        }
    }
}
EOF
    if [ -f "$NGINX_CONF" ]; then
        success "Nginx 配置文件创建成功"
    else
        error "Nginx 配置文件创建失败！"
    fi
}

# 部署 Nginx Docker 容器
deploy_nginx_container() {
    info "部署 Nginx 容器 $CONTAINER_NAME..."
    # 停止并删除已存在的同名容器
    if docker ps -a --filter "name=^/$CONTAINER_NAME$" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        info "已存在同名容器，正在停止并删除..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || error "停止容器 $CONTAINER_NAME 失败！"
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || error "删除容器 $CONTAINER_NAME 失败！"
        success "旧容器删除成功"
    fi

    # 拉取 Nginx 镜像（如果本地没有）
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$NGINX_IMAGE"; then
        info "拉取 Nginx 镜像 $NGINX_IMAGE..."
        docker pull "$NGINX_IMAGE" >/dev/null 2>&1 || error "拉取镜像 $NGINX_IMAGE 失败！"
        success "镜像拉取成功"
    fi

    # 启动 Nginx 容器（挂载配置文件和订阅文件）
    docker run -d \
        --name "$CONTAINER_NAME" \
        -v "$NGINX_DIR/$NGINX_CONF:/etc/nginx/nginx.conf:ro" \
        -v "$NGINX_DIR/$SUBSCRIBE_FILE:/etc/nginx/$SUBSCRIBE_FILE:ro" \
        -p "$LISTEN_ADDR:$LISTEN_PORT:$LISTEN_PORT" \
        --restart always \
        "$NGINX_IMAGE" || error "容器启动失败！"

    success "Nginx 容器 $CONTAINER_NAME 启动成功"
}

# 测试订阅服务是否可用
test_subscribe_service() {
    info "测试订阅服务是否可用..."
    local test_url="http://$LISTEN_ADDR:$LISTEN_PORT$SUBSCRIBE_PATH"
    local test_result=$(curl -s --connect-timeout 5 "$test_url")

    if [ -n "$test_result" ]; then
        success "订阅服务测试成功！"
        echo -e "\033[1;33m=====================================\033[0m"
        echo -e "📌 订阅服务信息："
        echo -e "   访问地址：$test_url"
        echo -e "   容器名称：$CONTAINER_NAME"
        echo -e "   订阅文件：$NGINX_DIR/$SUBSCRIBE_FILE"
        echo -e "\n📋 订阅内容预览（前 50 字符）："
        echo -e "   $(echo "$test_result" | head -c 50)...\033[0m"
        echo -e "\033[1;33m=====================================\033[0m"
    else
        error "订阅服务测试失败！请检查容器日志：docker logs $CONTAINER_NAME"
    fi
}

# 显示后续操作说明
show_usage() {
    echo -e "\n\033[1;32m=====================================\033[0m"
    echo -e "🎉 所有步骤执行完成！"
    echo -e "=====================================\033[0m"
    echo -e "💡 后续操作说明："
    echo -e "   1. 更新订阅节点：编辑 $NGINX_DIR/$SUBSCRIBE_FILE（一行一个节点），然后执行："
    echo -e "      docker restart $CONTAINER_NAME"
    echo -e "   2. 查看容器状态：docker ps | grep $CONTAINER_NAME"
    echo -e "   3. 查看容器日志：docker logs $CONTAINER_NAME"
    echo -e "   4. 停止容器：docker stop $CONTAINER_NAME"
    echo -e "   5. 卸载容器：docker rm -f $CONTAINER_NAME && rm -rf $NGINX_DIR"
    echo -e "=====================================\033[0m"
}

# ==================== 核心流程 ====================
main() {
    clear
    echo -e "\033[1;34m====================================="
    echo -e "   自动化部署 Nginx 订阅服务（Shadowrocket）"
    echo -e "=====================================\033[0m"
    echo -e "📋 配置信息："
    echo -e "   监听地址：$LISTEN_ADDR:$LISTEN_PORT"
    echo -e "   订阅路径：$SUBSCRIBE_PATH"
    echo -e "   工作目录：$NGINX_DIR"
    echo -e "   容器名称：$CONTAINER_NAME"
    echo -e "\033[1;33m请确认配置无误，按回车继续...\033[0m"
    read -r

    check_root                          # 检查 root 权限
    check_and_install_docker            # 检查/安装 Docker
    prepare_files                       # 准备目录和文件
    deploy_nginx_container              # 部署 Nginx 容器
    test_subscribe_service              # 测试服务可用性
    show_usage                          # 显示后续操作说明
}

# 启动主流程
main

