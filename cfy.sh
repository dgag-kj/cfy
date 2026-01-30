cat > cfy.sh << 'EOF'
#!/bin/bash

INSTALL_PATH="/usr/local/bin/cfy"
WORK_DIR="/root/cfst"

# --- 1. 自我安装逻辑 ---
if [ "$0" != "$INSTALL_PATH" ]; then
    echo "正在安装 [cfy 节点优选生成器]..."
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误: 安装需要管理员权限。"
        exit 1
    fi
    
    # 写入文件到系统路径
    cat "$0" > "$INSTALL_PATH"

    if [ $? -eq 0 ]; then
        chmod +x "$INSTALL_PATH"
        echo "✅ 安装成功! 您现在可以在任何地方直接输入 'cfy' 来运行它。"
        echo "---"
        echo "正在首次启动..."
        exec "$INSTALL_PATH"
    else
        echo "❌ 安装失败，无法写入 /usr/local/bin。"
        exit 1
    fi
    exit 0
fi

# --- 主程序 ---

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

check_deps() {
    for cmd in jq curl base64 grep sed mktemp shuf awk; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}错误: 命令 '$cmd' 未找到. 请先安装它 (apt/yum install $cmd).${NC}"
            exit 1
        fi
    done
}

# --- 2. 爬虫逻辑 (保留为选项2: Wetest) ---
get_all_optimized_ips() {
    local url_v4="https://www.wetest.vip/page/cloudflare/address_v4.html"
    local url_v6="https://www.wetest.vip/page/cloudfront/address_v6.html"
    
    echo -e "${YELLOW}正在爬取 wetest.vip 获取公共优选 IP...${NC}"
    
    local paired_data_file
    paired_data_file=$(mktemp)
    trap 'rm -f "$paired_data_file"' EXIT

    parse_url() {
        local url="$1"; local type_desc="$2"
        echo -e "  -> 正在获取 ${type_desc} 列表..."
        local html_content=$(curl -s "$url")
        if [ -z "$html_content" ]; then echo -e "${RED}  -> 获取失败!${NC}"; return; fi
        local table_rows=$(echo "$html_content" | tr -d '\n\r' | sed 's/<tr>/\n&/g' | grep '^<tr>')
        local ips=$(echo "$table_rows" | sed -n 's/.*data-label="优选地址">\([^<]*\)<.*/\1/p')
        local isps=$(echo "$table_rows" | sed -n 's/.*data-label="线路名称">\([^<]*\)<.*/\1/p')
        paste -d' ' <(echo "$ips") <(echo "$isps") >> "$paired_data_file"
    }

    parse_url "$url_v4" "IPv4"; parse_url "$url_v6" "IPv6"

    if ! [ -s "$paired_data_file" ]; then echo -e "${RED}无法解析出任何 IP.${NC}"; return 1; fi

    declare -g -a ip_list isp_list
    local shuffled_pairs
    mapfile -t shuffled_pairs < <(shuf "$paired_data_file")
    for pair in "${shuffled_pairs[@]}"; do
        ip_list+=("$(echo "$pair" | cut -d' ' -f1)")
        isp_list+=("$(echo "$pair" | cut -d' ' -f2-)")
    done
    echo -e "${GREEN}成功获取 ${#ip_list[@]} 个公共优选 IP (已随机打乱).${NC}"; return 0
}

# --- 3. CSV 读取逻辑 (替换选项1: 本地测速) ---
get_local_csv_ips() {
    # 尝试进入目录
    if [ -d "$WORK_DIR" ]; then cd "$WORK_DIR"; fi
    
    if [ ! -f "result.csv" ]; then
        echo -e "${RED}❌ 错误: 在 $PWD 下没找到 result.csv${NC}"
        echo "请先运行 CloudflareST 测速，或者确保你在正确的目录下。"
        return 1
    fi
    
    echo -e "${YELLOW}正在读取 result.csv (CloudflareST结果)...${NC}"
    
    # 清空并读取
    declare -g -a ip_list latency_list
    ip_list=()
    latency_list=()
    
    # 跳过标题，读取 IP(第1列) 和 延迟(第6列)
    while IFS=, read -r ip port tls data region loss latency speed; do
        if [[ "$ip" != "IP地址" ]] && [[ -n "$ip" ]]; then
            ip_list+=("$ip")
            latency_list+=("$latency")
        fi
    done < result.csv
    
    if [ ${#ip_list[@]} -eq 0 ]; then echo -e "${RED}CSV 为空或格式错误.${NC}"; return 1; fi
    
    echo -e "${GREEN}成功加载 ${#ip_list[@]} 个本地测速 IP.${NC}"; return 0
}

main() {
    check_deps
    # 自动定位
    if [ -d "$WORK_DIR" ]; then cd "$WORK_DIR"; fi

    local url_file="/etc/sing-box/url.txt"
    declare -a valid_urls valid_ps_names
    
    echo -e "${GREEN}=================================================="
    echo -e " 节点优选生成器 (cfy - 混合版)"
    echo -e "==================================================${NC}"

    # --- 获取节点 ---
    if [ -f "$url_file" ]; then
        mapfile -t urls < "$url_file"
        for url in "${urls[@]}"; do
            if [[ "$url" == vmess://* ]]; then
                decoded_json=$(echo "${url#"vmess://"}" | base64 -d 2>/dev/null)
                ps=$(echo "$decoded_json" | jq -r .ps 2>/dev/null)
                if [ -n "$ps" ]; then valid_urls+=("$url"); valid_ps_names+=("$ps"); fi
            fi
        done
    fi

    local selected_url
    if [ ${#valid_urls[@]} -gt 0 ]; then
        if [ ${#valid_urls[@]} -eq 1 ]; then
            selected_url=${valid_urls[0]}
            echo -e "${YELLOW}自动选择节点: ${valid_ps_names[0]}${NC}"
        else
            echo -e "${YELLOW}请选择基准节点:${NC}"
            for i in "${!valid_ps_names[@]}"; do printf "%3d) %s\n" "$((i+1))" "${valid_ps_names[$i]}"; done
            local choice
            while true; do
                read -p "输入编号: " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#valid_urls[@]} ]; then
                    selected_url=${valid_urls[$((choice-1))]}; break
                fi
            done
        fi
    else
        while true; do
            read -p "请手动粘贴 vmess:// 链接: " selected_url
            if [[ "$selected_url" == vmess://* ]]; then break; fi
        done
    fi

    local base64_part=${selected_url#"vmess://"}
    local original_json=$(echo "$base64_part" | base64 -d)
    local original_ps=$(echo "$original_json" | jq -r .ps)
    echo -e "${GREEN}已选择: $original_ps${NC}"
    
    # --- 菜单选择 ---
    echo -e "${YELLOW}请选择优选来源:${NC}"
    echo "  1) 本地测速结果 (result.csv)  <-- 你的 CloudflareST 结果"
    echo "  2) 云优选 (wetest.vip)        <-- 公共爬虫 (无需测速)"
    
    local source_mode
    while true; do
        read -p "输入选项 (1-2): " choice
        if [[ "$choice" == "1" ]]; then source_mode="csv"; break;
        elif [[ "$choice" == "2" ]]; then source_mode="web"; break;
        fi
    done
    
    # --- 执行数据获取 ---
    declare -a ip_list isp_list latency_list
    if [[ "$source_mode" == "csv" ]]; then
        get_local_csv_ips || exit 1
    else
        get_all_optimized_ips || exit 1
    fi

    # --- 询问数量 ---
    local num_to_generate
    read -p "请输入要生成的节点数量 (默认 10): " num_to_generate
    num_to_generate=${num_to_generate:-10}
    
    # 数量校验
    if [ "$num_to_generate" -gt "${#ip_list[@]}" ]; then
        num_to_generate=${#ip_list[@]}
    fi

    echo "---"
    echo -e "${YELLOW}生成的节点链接:${NC}"
    
    # --- 生成循环 ---
    for ((i=0; i<$num_to_generate; i++)); do
        local new_ip=${ip_list[$i]}
        local new_ps_suffix=""
        
        if [[ "$source_mode" == "csv" ]]; then
            # CSV模式：名字带延迟
            local lat=${latency_list[$i]}
            new_ps_suffix="优选${new_ip}-${lat}ms"
        else
            # Web模式：名字带ISP
            local isp=${isp_list[$i]}
            new_ps_suffix="优选${isp}"
        fi
        
        local new_ps="${original_ps}-${new_ps_suffix}"
        
        # JSON 替换
        local new_json=$(echo "$original_json" | jq --arg ip "$new_ip" --arg ps "$new_ps" '.add = $ip | .ps = $ps')
        local new_base64=$(echo -n "$new_json" | base64 | tr -d '\n')
        
        echo "vmess://${new_base64}"
    done
    
    echo "---"
    echo -e "${GREEN}生成完毕!${NC}"
}

check_deps
main
EOF

chmod +x cfy.sh && ./cfy.sh
