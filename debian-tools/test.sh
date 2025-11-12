#!/bin/bash
set -euo pipefail

# ==================== 核心函数：VLESS URI 转 Base64 客户端配置 ====================
# 用法：vless_uri_to_base64 "你的VLESS URI"
# 示例：vless_uri_to_base64 "vless://f55fef7e-b251-4cff-b717-6c8e1448a557@cdn.vcmario.dpdns.org:443?encryption=none&security=tls&type=ws&host=cdn.vcmario.dpdns.org&path=%2Fvless#V2Ray-VLESS-WS-TLS"
vless_uri_to_base64() {
    local vless_uri="$1"

    # 检查输入是否为空
    if [ -z "$vless_uri" ]; then
        echo "错误：请传入VLESS URI作为参数" >&2
        return 1
    fi

    # 1. 解析VLESS URI核心字段（基于RFC 3986格式解析）
    # 提取协议和主体（vless://xxx）
    local scheme="${vless_uri%%://*}"
    local main_part="${vless_uri#*://}"

    # 提取备注（#后面的内容）
    local ps="${main_part#*#}"
    # 移除备注，保留主体（@前面是UUID，后面是地址+端口+参数）
    local main_no_ps="${main_part%%#*}"
    # 提取UUID（@前面的部分）
    local id="${main_no_ps%%@*}"
    # 提取地址+端口+参数（@后面的部分）
    local addr_port_params="${main_no_ps#*@}"

    # 提取端口（:后面、?前面的数字）
    local port="${addr_port_params%%\?*}"
    port="${port##*:}"
    # 提取地址（:前面的部分）
    local add="${addr_port_params%%:*}"
    # 提取查询参数（?后面的部分）
    local query="${addr_port_params#*\?}"

    # 2. 解析查询参数（key=value格式）
    # 初始化默认参数
    local encryption="none"
    local security="none"
    local net="tcp"
    local host=""
    local path=""

    # 循环解析每个参数
    IFS='&' read -ra params <<< "$query"
    for param in "${params[@]}"; do
        local key="${param%%=*}"
        local value="${param#*=}"
        # URL解码value（处理%2F等编码字符）
        value=$(echo "$value" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))")
        
        case "$key" in
            encryption) encryption="$value" ;;
            security) security="$value" ;;
            type) net="$value" ;;  # type对应net字段（ws/tcp等）
            host) host="$value" ;;
            path) path="$value" ;;
        esac
    done

    # 3. 构建标准客户端JSON配置（兼容主流客户端）
    local json_config=$(cat <<EOF
{"v":"2","ps":"$ps","add":"$add","port":"$port","id":"$id","aid":"0","net":"$net","type":"none","host":"$host","path":"$path","tls":"$security","encryption":"$encryption"}
EOF
    )

    # 4. JSON压缩（移除所有空格，确保单行）+ Base64编码（标准URL安全编码）
    local minified_json=$(echo "$json_config" | tr -d '[:space:]')
    local base64_result=$(echo -n "$minified_json" | base64 -w 0)  # -w 0 禁用换行

    # 输出结果（可直接用于订阅或客户端导入）
    echo "vless://$base64_result"
}

# ==================== 测试用例（可选，删除不影响函数使用）====================
test_vless_convert() {
    echo "=== 测试开始：转换示例VLESS URI ==="
    local test_uri="vless://f55fef7e-b251-4cff-b717-6c8e1448a557@cdn.vcmario.dpdns.org:443?encryption=none&security=tls&type=ws&host=cdn.vcmario.dpdns.org&path=%2Fvless#V2Ray-VLESS-WS-TLS"
    echo "输入URI：$test_uri"
    echo -e "\n输出Base64配置："
    vless_uri_to_base64 "$test_uri"
    echo -e "\n=== 测试结束 ==="
}

# 执行测试（注释此行可禁用测试）
 test_vless_convert
#

# 调用如下：
#local my_vless_uri="vless://f55fef7e-b251-4cff-b717-6c8e1448a557@cdn.vcmario.dpdns.org:443?encryption=none&security=tls&type=ws&host=cdn.vcmario.dpdns.org&path=%2Fvless#V2Ray-VLESS-WS-TLS"
#local base64_config=$(vless_uri_to_base64 "$my_vless_uri")
#echo "生成的Base64配置：$base64_config"
