#!/bin/bash

# SOCKS5 代理管理工具
# 用于配置和控制 redsocks 进行 SOCKS5 代理设置

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以 root 权限运行此脚本！${NC}"
    exit 1
fi

# 配置 redsocks
configure_redsocks() {
    echo -e "${YELLOW}开始配置 SOCKS5 代理...${NC}"
    
    # 安装 redsocks
    if ! command -v redsocks &> /dev/null; then
        echo -e "${YELLOW}安装 redsocks...${NC}"
        apt update
        apt install -y redsocks
        if [ $? -ne 0 ]; then
            echo -e "${RED}安装 redsocks 失败，请检查网络或包管理器！${NC}"
            exit 1
        fi
    fi
    
    # 获取 SOCKS5 服务器信息
    read -p "请输入 SOCKS5 服务器地址（例如 127.0.0.1）：" socks5_server
    read -p "请输入 SOCKS5 服务器端口（例如 1080）：" socks5_port
    
    # 配置 redsocks
    echo -e "${YELLOW}正在配置 /etc/redsocks.conf...${NC}"
    cat > /etc/redsocks.conf << EOF
base {
    log_debug = off;
    log_info = off;
    log = stderr;
    daemon = off;
    redirector = iptables;
}
redsocks {
    local_ip = 127.0.0.1;
    local_port = 12345;
    ip = $socks5_server;
    port = $socks5_port;
    type = socks5;
}
EOF

    # 配置 iptables 规则
    echo -e "${YELLOW}配置 iptables 规则...${NC}"
    iptables -t nat -N REDSOCKS
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
    
    # 启动 redsocks
    echo -e "${YELLOW}启动 redsocks 服务...${NC}"
    systemctl restart redsocks
    systemctl enable redsocks
    
    echo -e "${GREEN}SOCKS5 代理配置完成并已启动！${NC}"
}

# 停止 redsocks 和清理规则
stop_redsocks() {
    echo -e "${YELLOW}正在关闭 SOCKS5 代理...${NC}"
    
    # 停止 redsocks 服务
    if systemctl is-active --quiet redsocks; then
        systemctl stop redsocks
        echo -e "${GREEN}redsocks 服务已停止！${NC}"
    else
        echo -e "${YELLOW}redsocks 服务未运行！${NC}"
    fi
    
    # 清理 iptables 规则
    if iptables -t nat -L REDSOCKS &> /dev/null; then
        iptables -t nat -F REDSOCKS
        iptables -t nat -X REDSOCKS
        iptables -t nat -D OUTPUT -p tcp -j REDSOCKS 2>/dev/null
        echo -e "${GREEN}iptables 规则已清理！${NC}"
    else
        echo -e "${YELLOW}未找到 REDSOCKS 相关的 iptables 规则！${NC}"
    fi
    
    echo -e "${GREEN}SOCKS5 代理已关闭！${NC}"
}

# 主菜单
main_menu() {
    local max_attempts=5
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        clear
        echo -e "${GREEN}===== SOCKS5 代理管理工具 =====${NC}"
        echo "1. 配置并启动 SOCKS5 代理"
        echo "2. 关闭 SOCKS5 代理"
        echo "3. 退出"
        echo -e "${GREEN}=============================${NC}"
        echo "尝试次数：$((attempt+1))/$max_attempts"
        read -p "请选择操作（1-3）：" choice
        echo "调试信息 - 你输入的值为：'$choice'"
        
        # 清理输入中的不可见字符（如 \r）
        choice=$(echo "$choice" | tr -d '\r')
        echo "调试信息 - 清理后的值为：'$choice'"
        
        case $choice in
            1)
                configure_redsocks
                read -p "按 Enter 键返回菜单..."
                attempt=0
                ;;
            2)
                stop_redsocks
                read -p "按 Enter 键返回菜单..."
                attempt=0
                ;;
            3)
                echo -e "${GREEN}退出程序！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择！${NC}"
                sleep 1
                attempt=$((attempt+1))
                ;;
        esac
    done
    echo -e "${RED}达到最大尝试次数，退出程序。${NC}"
    exit 1
}

# 启动主菜单
main_menu
