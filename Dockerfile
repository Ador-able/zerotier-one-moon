FROM debian:bookworm-slim

LABEL version="1.14.0"
LABEL description="ZeroTier One moon as Docker Image"

ARG VERSION=1.14.0

RUN apt-get update -qq && apt-get install curl jq gpg ca-certificates -y \
    &&  mkdir -p /usr/share/zerotier && \
    curl -o /usr/share/zerotier/tmp.asc "https://download.zerotier.com/contact%40zerotier.com.gpg" \
    && gpg --no-default-keyring --keyring /usr/share/zerotier/zerotier.gpg --import /usr/share/zerotier/tmp.asc && \
    rm -f /usr/share/zerotier/tmp.asc \
    && echo "deb [signed-by=/usr/share/zerotier/zerotier.gpg] https://download.zerotier.com/debian/bookworm bookworm main" >/etc/apt/sources.list.d/zerotier.list \
    && apt-get update -qq && apt-get install zerotier-one=${VERSION} iproute2 net-tools iputils-ping openssl procps -y \
    && rm -rf /var/lib/apt/lists/*

COPY start-moon.sh /start-moon.sh
COPY check_ip_and_restart.sh /check_ip_and_restart.sh

# 设置执行权限
RUN chmod +x /start-moon.sh /check_ip_and_restart.sh

ENTRYPOINT ["/start-moon.sh"]
