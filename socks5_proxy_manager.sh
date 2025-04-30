#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：请以 root 权限运行此脚本！${NC}"
    echo -e "${YELLOW}使用命令：sudo bash $0${NC}"
    exit 1
fi

# 检查 redsocks 是否安装
if ! command -v redsocks &> /dev/null; then
    echo -e "${YELLOW}redsocks 未安装，正在安装...${NC}"
    apt update
    apt install -y redsocks
    if [ $? -ne 0 ]; then
        echo -e "${RED}安装 redsocks 失败，请手动安装后再运行脚本！${NC}"
        exit 1
    fi
    echo -e "${GREEN}redsocks 安装成功！${NC}"
fi

# redsocks 配置文件路径
REDSOCKS_CONF="/etc/redsocks.conf"

# 备份原始配置文件
if [ -f "$REDSOCKS_CONF" ] && [ ! -f "$REDSOCKS_CONF.bak" ]; then
    cp "$REDSOCKS_CONF" "$REDSOCKS_CONF.bak"
    echo -e "${GREEN}已备份原始配置文件到 $REDSOCKS_CONF.bak${NC}"
fi

# 函数：配置 redsocks
configure_redsocks() {
    local ip=$1
    local port=$2
    cat > "$REDSOCKS_CONF" << EOF
base {
    log_debug = off;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
}
redsocks {
    local_ip = 127.0.0.1;
    local_port = 12345;
    ip = $ip;
    port = $port;
    type = socks5;
}
EOF
    echo -e "${GREEN}redsocks 配置文件已更新！${NC}"
}

# 函数：设置 iptables 规则
setup_iptables() {
    echo -e "${YELLOW}正在设置 iptables 规则...${NC}"
    iptables -t nat -N REDSOCKS 2>/dev/null
    iptables -t nat -F REDSOCKS 2>/dev/null
    iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
    iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
    echo -e "${GREEN}iptables 规则设置完成！${NC}"
}

# 函数：清除 iptables 规则
clear_iptables() {
    echo -e "${YELLOW}正在清除 iptables 规则...${NC}"
    iptables -t nat -F REDSOCKS 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp -j REDSOCKS 2>/dev/null
    iptables -t nat -X REDSOCKS 2>/dev/null
    echo -e "${GREEN}iptables 规则已清除！${NC}"
}

# 函数：启动代理
start_proxy() {
    echo -e "${YELLOW}正在启动 SOCKS5 代理...${NC}"
    systemctl restart redsocks
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SOCKS5 代理启动成功！${NC}"
    else
        echo -e "${RED}SOCKS5 代理启动失败，请检查配置！${NC}"
    fi
}

# 函数：关闭代理
stop_proxy() {
    echo -e "${YELLOW}正在关闭 SOCKS5 代理...${NC}"
    systemctl stop redsocks
    clear_iptables
    echo -e "${GREEN}SOCKS5 代理已关闭！${NC}"
}

# 主菜单
while true; do
    echo -e "\n${YELLOW}===== SOCKS5 代理管理工具 =====${NC}"
    echo -e "1. 配置并启动 SOCKS5 代理"
    echo -e "2. 关闭 SOCKS5 代理"
    echo -e "3. 退出"
    echo -e "${YELLOW}=============================${NC}"
    read -p "请选择操作（1-3）： " choice

    case $choice in
        1)
            # 输入 SOCKS5 代理信息
            read -p "请输入 SOCKS5 代理 IP 地址： " proxy_ip
            read -p "请输入 SOCKS5 代理端口号： " proxy_port

            # 验证输入
            if [ -z "$proxy_ip" ] || [ -z "$proxy_port" ]; then
                echo -e "${RED}错误：IP 地址或端口号不能为空！${NC}"
                continue
            fi

            # 配置 redsocks
            configure_redsocks "$proxy_ip" "$proxy_port"

            # 设置 iptables 规则
            setup_iptables

            # 启动代理
            start_proxy
            ;;
        2)
            # 关闭代理
            stop_proxy
            ;;
        3)
            echo -e "${GREEN}退出程序，再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新选择！${NC}"
            ;;
    esac
done
