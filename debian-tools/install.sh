#!/bin/bash
set -euo pipefail  # 严格模式：报错立即退出，禁止未定义变量

# ==================== 配置区（完全适配你的脚本名和目录结构）====================
# 1. 小脚本路径：当前主脚本所在目录下的 tools/ 子目录（自动识别主脚本位置）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# 2. 小脚本配置（严格对应你的 tools 目录下的脚本名）
# 格式：["脚本文件名" "功能描述"]（顺序=一键执行顺序）
SCRIPTS=(
  "user-add.sh"                         "1. 创建vv用户（含sudo免密、SSH同步）"
  "ban-root-ssh.sh"                     "2. 禁止 root 用 ssh 登录 && 禁止用 password 登录!!!!!"
  "ssh-enable-passwd-login.sh"          "3. 启用 ssh 的 passwd 登录"
  "docker-install.sh"                   "4. 安装Docker（含自动启动、测试）"
  "swap_add.sh"                         "5. 添加512MB Swap分区（永久生效）"
  "v2ray-install.sh"                    "6. 部署V2Ray（VLESS+WS+TLS）"
  "mt-install.sh"                       "7. 部署 mt 服务（Docker 版）"
  "subscribe-url-install.sh"            "8. 部署本地 subscribe url 服务"
  "xray-reality-install.sh"            "9. 部署Xray with vless + xtls + reality 服务"
  "fall-back-install.sh"               "10. 部署fall back 服务"
)

# ==================== 通用工具函数 ====================
info() { echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1\033[0m"; }
error() { echo -e "\033[1;31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1\033[0m" >&2; exit 1; }
check_root() { [ "$(id -u)" -eq 0 ] || error "请用root/sudo权限运行！"; }

# 检查 tools 目录是否存在，不存在则创建
check_scripts_dir() {
  if [ ! -d "$SCRIPT_DIR" ]; then
    info "小脚本目录 $SCRIPT_DIR 不存在，正在创建..."
    mkdir -p "$SCRIPT_DIR" || error "创建小脚本目录 $SCRIPT_DIR 失败！"
  fi
}

# 检查所有小脚本是否存在（严格匹配你的脚本名）
check_scripts_exist() {
  check_scripts_dir  # 先确保目录存在
  info "检查所有小脚本是否存在（目录：$SCRIPT_DIR）..."
  for ((i=0; i<${#SCRIPTS[@]}; i+=2)); do
    local script_name=${SCRIPTS[$i]}
    local script_path="$SCRIPT_DIR/$script_name"
    if [ ! -f "$script_path" ]; then
      error "小脚本不存在：$script_path，请确认脚本名是否正确（当前需：${SCRIPTS[$i]}）"
    fi
  done
  info "所有小脚本存在，准备执行..."
}

# ==================== 模式1：一键执行所有小脚本（按顺序）====================
run_all_scripts() {
  info "=== 开始一键执行所有脚本（顺序：创建用户→装Docker→加Swap→装V2Ray→部署Metatube）==="
  check_root
  check_scripts_exist

  for ((i=0; i<${#SCRIPTS[@]}; i+=2)); do
    local script_name=${SCRIPTS[$i]}
    local script_desc=${SCRIPTS[$i+1]}
    local script_path="$SCRIPT_DIR/$script_name"

    info "\n====================================="
    info "开始执行：$script_desc"
    info "脚本路径：$script_path"
    info "====================================="
    
    # 加载并执行小脚本（source=包含并执行）
    source "$script_path" || error "执行 $script_name 失败！"
    
    info "====================================="
    info "执行完成：$script_desc"
    info "=====================================\n"
  done

  echo -e "\033[1;32m====================================="
  echo -e "🎉 所有脚本执行完成！服务器初始化成功！"
  echo -e "=====================================\033[0m"
}

# ==================== 模式2：菜单选择执行指定小脚本 ====================
show_menu() {
  clear
  echo -e "\033[1;34m====================================="
  echo -e "          服务器初始化主脚本"
  echo -e "=====================================\033[0m"
  echo "0. 一键执行所有脚本"
  for ((i=0; i<${#SCRIPTS[@]}; i+=2)); do
    echo "${SCRIPTS[$i+1]}"  # 显示带序号的功能描述（与你的脚本名对应）
  done
  echo -e "\033[1;33m请输入要执行的序号（0-$(( ${#SCRIPTS[@]} / 2 ))）：\033[0m"
}

run_selected_script() {
  check_root
  check_scripts_exist

  while true; do
    show_menu
    read -p "输入序号：" choice

    # 选择0：一键执行所有
    if [ "$choice" -eq 0 ]; then
      run_all_scripts
      break
    fi

    # 选择指定脚本（序号对应SCRIPTS数组）
    local index=$(( (choice-1)*2 ))
    if [ $index -ge 0 ] && [ $index -lt ${#SCRIPTS[@]} ]; then
      local script_name=${SCRIPTS[$index]}
      local script_desc=${SCRIPTS[$index+1]}
      local script_path="$SCRIPT_DIR/$script_name"

      info "\n====================================="
      info "开始执行：$script_desc"
      info "脚本路径：$script_path"
      info "====================================="
      
      source "$script_path" || error "执行 $script_name 失败！"
      
      echo -e "\033[1;32m====================================="
      echo -e "🎉 $script_desc 执行完成！"
      echo -e "=====================================\033[0m"
      
      # 询问是否继续执行其他脚本
      read -p $'\033[1;33m是否继续执行其他脚本？（y/N）\033[0m' continue_choice
      [[ "$continue_choice" =~ ^[Yy]$ ]] || break
    else
      error "输入错误！请输入0-${#SCRIPTS[@]/2}之间的序号"
    fi
  done
}

# ==================== 主流程（默认启动菜单模式）====================
if [ $# -eq 1 ] && [ "$1" = "--all" ]; then
  # 命令行传--all参数：一键执行所有（适合自动化）
  run_all_scripts
else
  # 无参数：启动菜单模式（适合手动选择）
  run_selected_script
fi
