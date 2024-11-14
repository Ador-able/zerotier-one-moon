#!/bin/sh

# 引用自 https://github.com/rwv/docker-zerotier-moon
# 使用示例：./start-moon.sh -4 1.2.3.4 -6 2001:abcd:abcd::1 -p 9993

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin

/check_ip_and_restart.sh  &

moon_port=9993 # 默认的 ZeroTier moon 端口

# 通过 API 请求获取当前的公网 IPv4 地址
ipv4_address=$(curl -s https://ipinfo.io/json | jq -r '.ip')

sleep 5

# 处理命令行参数
while getopts "6:p:" arg
do
        case $arg in
             6)
                ipv6_address="$OPTARG"
                echo "IPv6 地址: $ipv6_address"
                ;;
             p)
                moon_port="$OPTARG"
                echo "Moon 端口: $moon_port"
                ;;
             ?)
                echo "未知参数"
                exit 1
                ;;
        esac
done

# 配置稳定的端点（stableEndpointsForSed）用于 ZeroTier
stableEndpointsForSed=""
if [ -z ${ipv4_address+x} ]; then   # 如果未设置 IPv4 地址
  if [ -z ${ipv6_address+x} ]; then # 并且未设置 IPv6 地址
    echo "请设置 IPv4 或 IPv6 地址。"
    exit 0
  else # 仅设置了 IPv6 地址
    stableEndpointsForSed="\"$ipv6_address\/$moon_port\""
  fi
else                                # 设置了 IPv4 地址
  if [ -z ${ipv6_address+x} ]; then # 且未设置 IPv6 地址
    stableEndpointsForSed="\"$ipv4_address\/$moon_port\""
  else # IPv4 和 IPv6 地址都已设置
    stableEndpointsForSed="\"$ipv4_address\/$moon_port\",\"$ipv6_address\/$moon_port\""
  fi
fi

# 去除多余的空格
stableEndpointsForSed="$(echo "${stableEndpointsForSed}" | tr -d '[:space:]')"
echo -e "稳定端点: ${stableEndpointsForSed}"

# 检查 ZeroTier 配置文件是否已生成
if [ -d "/var/lib/zerotier-one/moons.d" ]; then
  echo "已检测到 ZeroTier 配置文件"
  stableEndpointsForSed_clean="$ipv4_address/$moon_port"
  stableEndpointsForSed_clean="$(echo "${stableEndpointsForSed_clean}" | tr -d '[:space:]')"
  jq --arg endpoint "$stableEndpointsForSed_clean"  '.roots[].stableEndpoints = [$endpoint]' /var/lib/zerotier-one/moon.json > /var/lib/zerotier-one/temp.json && mv /var/lib/zerotier-one/temp.json /moon.json

  moon_id=$(cat /var/lib/zerotier-one/identity.public | cut -d ':' -f1)
  
  echo "删除旧的moons.d"
  rm -rf /var/lib/zerotier-one/moons.d

  mv /moon.json /var/lib/zerotier-one/moon.json

  echo -e "你的 ZeroTier moon ID 是 \033[0;31m$moon_id\033[0m，可通过以下命令连接此 moon: \033[0;31m\"zerotier-cli orbit $moon_id $moon_id\"\033[0m"
else
  echo "生成全新 ZeroTier 配置文件"
  nohup /usr/sbin/zerotier-one >/dev/null 2>&1 & # 后台启动 ZeroTier 服务以生成身份
  while [ ! -f /var/lib/zerotier-one/identity.secret ]; do # 等待身份文件生成
    sleep 1
  done
  # 初始化 moon 配置文件
  /usr/sbin/zerotier-idtool initmoon /var/lib/zerotier-one/identity.public >>/var/lib/zerotier-one/moon.json
  sed -i 's/"stableEndpoints": \[\]/"stableEndpoints": ['$stableEndpointsForSed']/g' /var/lib/zerotier-one/moon.json
fi

/usr/sbin/zerotier-idtool genmoon /var/lib/zerotier-one/moon.json >/dev/null # 生成最终配置文件
mkdir /var/lib/zerotier-one/moons.d
mv *.moon /var/lib/zerotier-one/moons.d/
pkill zerotier-one
moon_id=$(cat /var/lib/zerotier-one/moon.json | grep \"id\" | cut -d '"' -f4)
echo -e "你的 ZeroTier moon ID 是 \033[0;31m$moon_id\033[0m，可通过以下命令连接此 moon: \033[0;31m\"zerotier-cli orbit $moon_id $moon_id\"\033[0m"
exec /usr/sbin/zerotier-one