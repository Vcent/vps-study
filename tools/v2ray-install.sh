#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 工具函数 ====================
# 日志输出（带颜色）
info() { echo -e "\033[1;34m[INFO] $1\033[0m"; }
success() { echo -e "\033[1;32m[SUCCESS] $1\033[0m"; }
error() { echo -e "\033[1;31m[ERROR] $1\033[0m" >&2; exit 1; }

# 检查是否为 root/sudo 权限
check_permission() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户或 sudo 权限运行此脚本！"
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -i:$port >/dev/null 2>&1; then
        error "端口 $port 已被占用，请释放端口后重新运行脚本！"
    fi
}

# 生成并保存 UUID
generate_uuid() {
    info "正在生成客户端认证 UUID..."
    if ! command -v uuidgen &> /dev/null; then
        info "未安装 uuid-runtime，正在安装..."
        apt update >/dev/null 2>&1
        apt install -y uuid-runtime || error "uuid-runtime 安装失败！"
    fi
    UUID=$(uuidgen)
    success "UUID 生成成功：$UUID"
    echo "$UUID" > ~/v2ray_uuid.txt
    success "UUID 已保存到 ~/v2ray_uuid.txt"
}

# 申请 Let's Encrypt 证书
apply_cert() {
    info "开始申请 Let's Encrypt TLS 证书（需域名已解析到服务器IP）"
    read -p "请输入你的域名（如 cdn.vcmario.dpdns.org）：" DOMAIN

    # 检查 certbot
    if ! command -v certbot &> /dev/null; then
        info "未安装 certbot，正在安装..."
        apt update >/dev/null 2>&1
        apt install -y certbot || error "certbot 安装失败！"
    fi

    # 检查 80 端口（standalone 模式需要）
    check_port 80
    info "正在申请证书，过程可能需要几十秒..."
    if ! certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email; then
        error "证书申请失败！请确认域名已正确解析到服务器IP，且 80 端口未被占用"
    fi

    # 证书路径
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
        error "证书文件不存在，请检查申请过程是否有误"
    fi
    success "证书申请成功！"
    success "证书路径：$CERT_PATH"
    success "私钥路径：$KEY_PATH"
}

# 配置证书自动续期
config_cert_renew() {
    info "正在配置证书自动续期..."
    # 检查定时任务是否已存在
    if ! crontab -l 2>/dev/null | grep -q "certbot -q renew"; then
        # 添加 cron 任务（每12小时随机时间执行续期）
        (crontab -l 2>/dev/null; echo "0 */12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && certbot -q renew") | crontab -
        success "已添加证书自动续期 cron 任务"
    else
        success "证书自动续期任务已存在，无需重复添加"
    fi

    # 测试续期
    info "测试证书续期功能..."
    if certbot renew --dry-run >/dev/null 2>&1; then
        success "证书续期测试通过！"
    else
        error "证书续期测试失败，请检查配置"
    fi

    # 显示证书有效期
    info "当前证书有效期："
    openssl s_client -connect localhost:443 -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -dates || info "暂时无法获取证书有效期，容器启动后可再次查看"
}

# 创建 V2Ray 配置文件
create_v2ray_config() {
    info "正在创建 V2Ray 配置文件（VLESS + WS + TLS）..."
    V2RAY_DIR="$HOME/v2ray"
    mkdir -p "$V2RAY_DIR" || error "创建 V2Ray 目录失败"

    # 配置内容（替换 UUID、证书路径、域名）
    cat > "$V2RAY_DIR/config.json" << EOF
{
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "level": 0,
        "email": "user@vless"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/vless"
      },
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "$CERT_PATH",
          "keyFile": "$KEY_PATH"
        }],
        "serverName": "$DOMAIN"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

    if [ ! -f "$V2RAY_DIR/config.json" ]; then
        error "配置文件创建失败"
    fi
    success "V2Ray 配置文件创建成功：$V2RAY_DIR/config.json"
}

# 运行 V2Ray Docker 容器
run_v2ray_container() {
    info "正在启动 V2Ray Docker 容器..."
    # 检查容器是否已存在
    if docker ps -a --filter "name=v2ray-vless-ws-tls" --format "{{.Names}}" | grep -q "v2ray-vless-ws-tls"; then
        info "容器已存在，正在停止并删除旧容器..."
        docker stop v2ray-vless-ws-tls >/dev/null 2>&1
        docker rm v2ray-vless-ws-tls >/dev/null 2>&1
    fi

    # 检查 443 端口
    check_port 443

    # 启动容器（挂载配置、证书，映射 443 端口）
    docker run -d \
      --name v2ray-vless-ws-tls \
      -v "$HOME/v2ray/config.json:/etc/v2ray/config.json" \
      -v /etc/letsencrypt:/etc/letsencrypt:ro \
      -p 443:443 \
      v2fly/v2fly-core:v4.27.0 || error "容器启动失败！"

    # 检查容器状态
    sleep 3
    if docker ps --filter "name=v2ray-vless-ws-tls" --format "{{.Status}}" | grep -q "Up"; then
        success "V2Ray 容器启动成功！容器名：v2ray-vless-ws-tls"
    else
        error "容器启动失败，日志：$(docker logs v2ray-vless-ws-tls)"
    fi
}

# 生成 V2Ray 客户端 URI 和二维码提示
generate_client_config() {
    info "正在生成客户端连接配置..."
    # 生成 URI（URL编码 path）
    URI="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=%2Fvless#V2Ray-VLESS-WS-TLS"
    
    echo -e "\n====================================="
    success "客户端配置信息（请复制保存）"
    echo -e "====================================="
    echo -e "协议：VLESS"
    echo -e "地址：$DOMAIN"
    echo -e "端口：443"
    echo -e "UUID：$UUID"
    echo -e "加密方式：none"
    echo -e "传输方式：WebSocket"
    echo -e "WebSocket 路径：/vless"
    echo -e "TLS：启用"
    echo -e "SNI/服务器名：$DOMAIN"
    echo -e "-------------------------------------"
    echo -e "客户端连接 URI："
    echo -e "\033[1;33m$URI\033[0m"
    echo -e "-------------------------------------"
    echo -e "生成二维码步骤："
    echo -e "1. 访问在线二维码生成工具（如 https://www.qr-code-generator.com/ 或 https://cli.im/text）"
    echo -e "2. 将上面的 URI 粘贴到工具中"
    echo -e "3. 生成二维码后，客户端APP（V2RayN、Shadowrocket等）扫描即可导入"
    echo -e "=====================================\n"
    
    success "安全提示：UUID 是访问凭证，请勿公开分享！证书将自动续期，无需手动操作"
}

# ==================== 主流程 ====================
main() {
    clear
    echo -e "\033[1;34m====================================="
    echo -e "开始部署 V2Ray (VLESS + WS + TLS)"
    echo -e "=====================================\033[0m"

    check_permission  # 检查权限
    check_port 443    # 检查 443 端口

    # 步骤1：安装 Docker（若未安装）
    info "步骤1/7：检查并安装 Docker..."
    if ! command -v docker &> /dev/null; then
        info "未安装 Docker，正在安装..."
        apt update >/dev/null 2>&1
        apt install -y docker.io || error "Docker 安装失败！"
        systemctl enable docker >/dev/null 2>&1
        systemctl start docker >/dev/null 2>&1
        success "Docker 安装并启动成功"
    else
        success "Docker 已安装，当前状态：$(systemctl is-active docker)"
    fi

    # 步骤2：生成 UUID
    info "步骤2/7：生成 UUID..."
    generate_uuid

    # 步骤3：申请 TLS 证书
    info "步骤3/7：申请 TLS 证书..."
    apply_cert

    # 步骤4：配置证书自动续期
    info "步骤4/7：配置证书自动续期..."
    config_cert_renew

    # 步骤5：创建 V2Ray 配置
    info "步骤5/7：创建 V2Ray 配置文件..."
    create_v2ray_config

    # 步骤6：运行 V2Ray 容器
    info "步骤6/7：启动 V2Ray Docker 容器..."
    run_v2ray_container

    # 步骤7：生成客户端配置
    info "步骤7/7：生成客户端连接信息..."
    generate_client_config

    echo -e "\033[1;32m====================================="
    echo -e "V2Ray (VLESS + WS + TLS) 部署完成！"
    echo -e "=====================================\033[0m"
}

# 启动主流程
main
