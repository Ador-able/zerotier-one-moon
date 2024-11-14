#!/bin/bash

# 获取当前容器的 ID
container_id=$(curl --unix-socket /var/run/docker.sock -X GET "http://localhost/containers/$(hostname)/json" | jq -r .Id)


# 存储 IP 地址的文件
ip_file="/current_ip.txt"

# 函数：获取当前容器的 IPv4 地址
get_current_ip() {
    ipv4_address=$(curl -s https://ipinfo.io/json | jq -r '.ip')
    echo "$ipv4_address"
}

# 初次运行时获取并存储当前 IP 地址
current_ip=$(get_current_ip)
echo "$current_ip" > "$ip_file"
echo "初始 IP 地址: $current_ip"

# 定时检查 IP 地址变化
while true; do
    sleep 60 # 每分钟检查一次

    new_ip=$(get_current_ip)
    old_ip=$(cat "$ip_file")

    # 检查 IP 是否更改
    if [ "$new_ip" != "$old_ip" ]; then
        echo "检测到 IP 地址变化: $old_ip -> $new_ip"

        # 调用 Docker API 重启容器
        curl -s --unix-socket /var/run/docker.sock -X POST "http://localhost/containers/$container_id/restart"

        # 更新 IP 文件
        echo "$new_ip" > "$ip_file"
    else
        echo "IP 地址未变化: $new_ip"
    fi
done
