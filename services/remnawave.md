# Remnawave 部署

> Remnawave Panel 是用户、节点、订阅和配置的管理面板。Panel 本身不包含 Xray-core；实际代理流量需要单独部署 Remnawave Node，并在面板里通过 Config Profile、Host、Internal Squad 关联。基础约定见 [DEPLOYMENT.md](../DEPLOYMENT.md)。

官方要求 Remnawave 服务不要直接暴露公网，面板必须通过反向代理和 HTTPS 访问。建议让 Panel 只监听 `127.0.0.1:3010`，Metrics 只监听 `127.0.0.1:3011`，由 Caddy 对外提供 `https://remnawave.example.com/`。

## 创建目录

```bash
mkdir -p /opt/remnawave/{data/postgres,run/valkey,config,etc,logs,backup}
chmod 711 /opt/remnawave /opt/remnawave/data /opt/remnawave/run
chmod 700 /opt/remnawave/config /opt/remnawave/etc /opt/remnawave/logs /opt/remnawave/backup
cd /opt/remnawave
```

PostgreSQL 和 Valkey 容器会用非 root 用户写入挂载目录。首次启动前给写入目录设置权限：

```bash
chown -R 999:999 /opt/remnawave/data/postgres
chmod 700 /opt/remnawave/data/postgres
chown -R 999:1000 /opt/remnawave/run/valkey
chmod 1777 /opt/remnawave/run/valkey
```

## docker-compose.yml

```yaml
x-common: &common
  ulimits:
    nofile:
      soft: 1048576
      hard: 1048576
  restart: always
  networks:
    - remnawave-network

x-logging: &logging
  logging:
    driver: json-file
    options:
      max-size: 100m
      max-file: 5

x-env: &env
  env_file: .env

services:
  remnawave:
    image: remnawave/backend:2
    container_name: remnawave
    hostname: remnawave
    <<: [*common, *logging, *env]
    volumes:
      - ./run/valkey:/var/run/valkey
    ports:
      - 127.0.0.1:3010:${APP_PORT:-3000}
      - 127.0.0.1:3011:${METRICS_PORT:-3001}
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:${METRICS_PORT:-3001}/health']
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      remnawave-db:
        condition: service_healthy
      remnawave-redis:
        condition: service_healthy

  remnawave-db:
    image: postgres:18.4
    container_name: remnawave-db
    hostname: remnawave-db
    shm_size: 512mb
    <<: [*common, *logging, *env]
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - TZ=UTC
    volumes:
      - ./data/postgres:/var/lib/postgresql
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}']
      interval: 3s
      timeout: 10s
      retries: 3

  remnawave-redis:
    image: valkey/valkey:9-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    <<: [*common, *logging]
    volumes:
      - ./run/valkey:/var/run/valkey
    command: >
      valkey-server
      --save ""
      --appendonly no
      --maxmemory-policy noeviction
      --loglevel warning
      --unixsocket /var/run/valkey/valkey.sock
      --unixsocketperm 777
      --port 0
    healthcheck:
      test: ['CMD', 'valkey-cli', '-s', '/var/run/valkey/valkey.sock', 'ping']
      interval: 3s
      timeout: 3s
      retries: 3

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    external: false
```

## .env

生成强随机值：

```bash
POSTGRES_PASSWORD="$(openssl rand -hex 24)"
JWT_AUTH_SECRET="$(openssl rand -hex 64)"
JWT_API_TOKENS_SECRET="$(openssl rand -hex 64)"
METRICS_PASS="$(openssl rand -hex 32)"
WEBHOOK_SECRET_HEADER="$(openssl rand -hex 32)"
```

写入 `.env`，真实 secret 只放在服务器：

```bash
cat > /opt/remnawave/.env <<EOF
APP_PORT=3000
METRICS_PORT=3001
API_INSTANCES=1

DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@remnawave-db:5432/postgres"
REDIS_SOCKET=/var/run/valkey/valkey.sock

JWT_AUTH_SECRET=${JWT_AUTH_SECRET}
JWT_API_TOKENS_SECRET=${JWT_API_TOKENS_SECRET}

IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
TELEGRAM_BOT_TOKEN=change_me
TELEGRAM_NOTIFY_USERS=change_me
TELEGRAM_NOTIFY_NODES=change_me
TELEGRAM_NOTIFY_CRM=change_me
TELEGRAM_NOTIFY_SERVICE=change_me
TELEGRAM_NOTIFY_TBLOCKER=change_me

PANEL_DOMAIN=remnawave.example.com
FRONT_END_DOMAIN=remnawave.example.com
SUB_PUBLIC_DOMAIN=remnawave.example.com/api/sub

SWAGGER_PATH=/docs
SCALAR_PATH=/scalar
IS_DOCS_ENABLED=false

METRICS_USER=admin
METRICS_PASS=${METRICS_PASS}

WEBHOOK_ENABLED=false
WEBHOOK_URL=https://your-webhook-url.example/endpoint
WEBHOOK_SECRET_HEADER=${WEBHOOK_SECRET_HEADER}

BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED=false
BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD=[60,80]
NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED=false
NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS=[6,24,48]
EXPIRATION_NOTIFICATIONS_ENABLED=false
EXPIRATION_NOTIFICATIONS=[-72,-48,-24,24]

POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postgres
EOF

chmod 600 /opt/remnawave/.env
chmod 600 /opt/remnawave/docker-compose.yml
```

`PANEL_DOMAIN`、`FRONT_END_DOMAIN`、`SUB_PUBLIC_DOMAIN` 都不要带 `http://` 或 `https://`。`SUB_PUBLIC_DOMAIN` 默认用 `remnawave.example.com/api/sub`。

## 启动

```bash
cd /opt/remnawave
docker compose config >/dev/null
docker compose pull
docker compose up -d
docker compose ps
docker logs --tail 100 remnawave
```

第一次启动会初始化数据库和默认数据。日志里出现 `Remnawave Backend`、`Nest application successfully started` 后再继续。

## Caddy 反代

修改前先备份：

```bash
cp /opt/caddy/etc/Caddyfile \
  /opt/caddy/etc/Caddyfile.bak-remnawave-$(date +%Y%m%d-%H%M%S)
```

追加站点。Remnawave Panel 需要域名根路径，不要挂到子路径：

```caddy
remnawave.example.com {
    reverse_proxy 127.0.0.1:3010
}
```

校验并 reload：

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

## 验证

```bash
cd /opt/remnawave
docker compose ps

ss -lntup | grep -E ':3010|:3011'
curl -sS -D- http://127.0.0.1:3011/health
curl -ksS -o /dev/null -w '%{http_code} %{content_type}\n' \
  https://remnawave.example.com/

docker logs --tail 200 remnawave
```

预期：

- `remnawave`、`remnawave-db`、`remnawave-redis` 都是 healthy。
- `3010` 和 `3011` 都只监听 `127.0.0.1`。
- `/health` 返回 `200` 且数据库状态为 `up`。
- 面板域名返回 `200 text/html`。

直接访问 `http://127.0.0.1:3010/` 可能被 Remnawave 拒绝，这是正常的；它要求走 HTTPS 反代。

## 首次登录和节点

打开：

```text
https://remnawave.example.com/
```

首次部署时按页面提示创建管理员账号。后续添加代理节点的基本路径：

```text
Nodes -> Management -> Create Node
Config Profiles -> 创建或选择入站配置
Hosts -> 给订阅配置公开域名、SNI、端口等参数
Internal Squads -> 关联用户、Host、Config Profile
```

Remnawave 的节点配置方式和 Marzban 不完全一样。Marzban 更像在 Core Settings/Host Settings 里直接配置 Xray 入站；Remnawave 是先在 Config Profile 定义 inbounds，再把 Profile 绑定到 Node，并通过 Host 和 Squad 决定订阅里展示什么。

## 部署 Remnawave Node

Remnawave Node 承载 Xray-core。`NODE_PORT` 是 Panel 调 Node 的控制 API，不是用户代理端口；用户连接的端口来自 Config Profile 里的 Xray inbounds。

同机 Docker 部署时注意：Panel 在容器网络里，`127.0.0.1` 指的是 Panel 容器自身，不是宿主机。Node 使用 `network_mode: host` 后，Panel 应该通过 Docker 网关或宿主机内网 IP 访问 Node。

远程 Node 推荐让控制链路走内网、Tailscale、WireGuard 或云 VPC 私网地址。不要为了让 Panel 连接 Node 就把 `NODE_PORT` 对全公网开放；如果必须经过公网，也只允许 Panel 出口 IP 访问。

### 修改前备份

```bash
mkdir -p /opt/remnawave/backup /opt/remnawave-node/backup

cd /opt/remnawave
docker compose exec -T remnawave-db pg_dump -U postgres -d postgres -Fc \
  > /opt/remnawave/backup/remnawave-before-node-$(date +%Y%m%d-%H%M%S).dump

iptables-save > /opt/remnawave-node/backup/iptables-before-node-$(date +%Y%m%d-%H%M%S).rules
ip6tables-save > /opt/remnawave-node/backup/ip6tables-before-node-$(date +%Y%m%d-%H%M%S).rules
```

### 生成 Node SECRET_KEY

在 Panel 容器里运行官方 CLI，并选择生成 Node `SECRET_KEY` 的菜单项：

```bash
docker exec -it remnawave remnawave
```

把输出的 `SECRET_KEY` 只保存到服务器，不要写进仓库。

### 创建 Node 目录和 compose

```bash
mkdir -p /opt/remnawave-node/{data,config,etc,logs,backup}
chmod 700 /opt/remnawave-node /opt/remnawave-node/config /opt/remnawave-node/etc /opt/remnawave-node/backup
cd /opt/remnawave-node
```

写入 `.env`：

```bash
cat > /opt/remnawave-node/.env <<'EOF'
NODE_PORT=2222
SECRET_KEY=<SECRET_KEY_FROM_PANEL>
EOF

chmod 600 /opt/remnawave-node/.env
```

写入 `docker-compose.yml`：

```yaml
services:
  remnawave-node:
    image: remnawave/node:latest
    container_name: remnawave-node
    hostname: remnawave-node
    restart: always
    network_mode: host
    env_file:
      - ./.env
    volumes:
      - ./logs:/var/log/remnawave-node
```

启动：

```bash
cd /opt/remnawave-node
chmod 600 docker-compose.yml
docker compose config >/dev/null
docker compose pull
docker compose up -d
docker compose ps
docker logs --tail 100 remnawave-node
```

### 限制 Node 控制端口

`2222/tcp` 只允许 Panel 所在 Docker 网络、Panel 私网 IP、Tailscale IP 或指定公网出口 IP 访问。同机部署先确认 Remnawave Docker 网络：

```bash
docker network inspect remnawave-network \
  --format '{{range .IPAM.Config}}{{.Subnet}} {{.Gateway}}{{end}}'
```

同机示例规则，按实际 Docker 网段替换 `<REMNAWAVE_DOCKER_SUBNET>`：

```bash
iptables -I INPUT 1 -p tcp --dport 2222 -s 127.0.0.1/32 \
  -m comment --comment remnawave-node-control-loopback -j ACCEPT
iptables -I INPUT 2 -p tcp --dport 2222 -s <REMNAWAVE_DOCKER_SUBNET> \
  -m comment --comment remnawave-node-control-docker -j ACCEPT
iptables -I INPUT 3 -p tcp --dport 2222 \
  -m comment --comment remnawave-node-control-drop -j DROP

ip6tables -I INPUT 1 -p tcp --dport 2222 -s ::1/128 \
  -m comment --comment remnawave-node-control-loopback -j ACCEPT
ip6tables -I INPUT 2 -p tcp --dport 2222 \
  -m comment --comment remnawave-node-control-drop -j DROP
```

远程 Node 示例规则，按实际 Panel 控制链路地址替换 `<PANEL_CONTROL_IP>`。它可以是 Tailscale IP、VPC 私网 IP 或固定公网出口 IP：

```bash
iptables -I INPUT 1 -p tcp --dport 2222 -s <PANEL_CONTROL_IP>/32 \
  -m comment --comment remnawave-node-control-panel -j ACCEPT
iptables -I INPUT 2 -p tcp --dport 2222 \
  -m comment --comment remnawave-node-control-drop -j DROP
```

iptables 规则是否重启后仍然存在，取决于服务器使用的防火墙管理方式；云安全组也要同步限制 `NODE_PORT`。

### 在 Panel 中添加 Node

获取 Panel 容器访问宿主机的 Docker 网关：

```bash
docker network inspect remnawave-network \
  --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'
```

在面板里添加，同机 Node 的 Address 用 Docker 网关或宿主机内网 IP，远程 Node 的 Address 用 Panel 能访问到的私网、Tailscale、WireGuard 或固定公网地址：

```text
Nodes -> Management -> Create Node

Name: <NODE_NAME>
Address: <DOCKER_GATEWAY_OR_NODE_CONTROL_IP>
Port: 2222
Country Code: <COUNTRY_CODE>
Config Profile: <PROFILE_NAME>
Active Inbounds: <INBOUND_TAGS>
```

同机 Docker 场景不要把 Address 填成 `127.0.0.1`，否则 Panel 容器会连到自己。

### 避免默认入站意外公网监听

Remnawave 初始化的默认 Profile 可能带一个示例 Shadowsocks 入站，例如 `0.0.0.0:1234`。如果只是为了先接入 Node，不想立刻开放代理端口，先在 Config Profiles 里把默认入站改成只监听本机的占位端口：

```json
{
  "tag": "Shadowsocks",
  "listen": "127.0.0.1",
  "port": 61081,
  "protocol": "shadowsocks",
  "settings": {
    "method": "chacha20-ietf-poly1305",
    "clients": [],
    "network": "tcp,udp"
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls", "quic"]
  }
}
```

真正提供服务时，再创建 VLESS/Reality、Trojan、Shadowsocks 等正式入站，选择明确的公网端口，并在防火墙或安全组中只开放这些代理入站端口。

### Node 验证

```bash
cd /opt/remnawave-node
docker compose ps

ss -lntup | grep -E ':2222|:<PROXY_PORT>|:61081'
ss -lnuup | grep -E ':<PROXY_PORT>|:61081'

docker logs --tail 100 remnawave-node
docker logs --tail 150 remnawave | grep -E 'Started all nodes|Generated config|Node .*health|error|warn'

docker exec remnawave-db psql -U postgres -d postgres -P pager=off \
  -c "select name,address,port,is_connected,is_connecting,is_disabled,last_status_message,last_status_change from nodes order by created_at;"
```

预期：

- Node 容器为 `Up`。
- `nodes.is_connected = true`，`is_connecting = false`，`is_disabled = false`。
- Panel 日志出现 `Started all nodes` 或 `Started node`。
- `NODE_PORT` 从公网不可连接；正式代理入站端口只有在明确配置后才对公网监听。

## 备份与恢复

备份：

```bash
tar czf /opt/remnawave/backup/remnawave-$(date +%Y%m%d-%H%M%S).tgz \
  -C /opt/remnawave \
  docker-compose.yml .env data config etc
```

恢复后：

```bash
cd /opt/remnawave
docker compose up -d
docker compose ps
docker logs --tail 100 remnawave
```

Node 也要单独备份，尤其是 `.env` 和 `SECRET_KEY`：

```bash
tar czf /opt/remnawave-node/backup/remnawave-node-$(date +%Y%m%d-%H%M%S).tgz \
  -C /opt/remnawave-node \
  docker-compose.yml .env secret-key.txt config etc
```

## 排查

### 基础命令

Panel：

```bash
cd /opt/remnawave
docker compose ps
docker logs --tail 200 remnawave
docker logs --tail 100 remnawave-db
docker logs --tail 100 remnawave-redis
ss -lntup | grep -E ':3010|:3011'
curl -sS -D- http://127.0.0.1:3011/health
```

Node：

```bash
cd /opt/remnawave-node
docker compose ps
docker logs --tail 200 remnawave-node
ss -lntup | grep -E ':2222|:<PROXY_PORT>|:61081'
```

### Panel 打不开或 Caddy 502

检查：

```bash
curl -sS -D- http://127.0.0.1:3011/health
curl -ksS -o /dev/null -w '%{http_code} %{content_type}\n' \
  https://remnawave.example.com/
docker logs --tail 100 caddy
docker logs --tail 200 remnawave
```

修复方向：

- Caddy 上游应指向 `127.0.0.1:3010`。
- Panel 需要通过 HTTPS 反代访问，直接访问 `http://127.0.0.1:3010/` 可能被拒绝。
- `PANEL_DOMAIN`、`FRONT_END_DOMAIN`、`SUB_PUBLIC_DOMAIN` 不要带 `http://` 或 `https://`。
- `remnawave-db` 和 `remnawave-redis` 必须 healthy。

### `/health` 不健康

检查：

```bash
cd /opt/remnawave
docker compose ps
docker logs --tail 100 remnawave-db
docker logs --tail 100 remnawave-redis
docker logs --tail 200 remnawave
```

修复方向：

- 检查 `/opt/remnawave/data/postgres` 和 `/opt/remnawave/run/valkey` 权限。
- 检查 `.env` 里的 `DATABASE_URL`、`POSTGRES_USER`、`POSTGRES_PASSWORD`、`POSTGRES_DB` 是否一致。
- 首次启动后等待数据库初始化完成再访问面板。

### Node 连接不上 Panel

检查：

```bash
docker network inspect remnawave-network \
  --format '{{range .IPAM.Config}}{{.Subnet}} {{.Gateway}}{{end}}'
docker logs --tail 200 remnawave-node
docker logs --tail 200 remnawave | grep -E 'Started all nodes|Started node|Node .*health|error|warn'
docker exec remnawave-db psql -U postgres -d postgres -P pager=off \
  -c "select name,address,port,is_connected,is_connecting,is_disabled,last_status_message,last_status_change from nodes order by created_at;"
```

修复方向：

- 同机 Docker 场景里，Panel 添加 Node 的 Address 不要填 `127.0.0.1`。
- Address 应填 Docker 网关或宿主机内网 IP。
- `NODE_PORT` 是控制 API，只允许 Panel 所在 Docker 网段或指定 Panel IP 访问。
- Node `.env` 里的 `SECRET_KEY` 必须来自 Panel 生成的 Node key。

### 默认入站意外监听公网

检查：

```bash
ss -lntup | grep -E ':1234|:61081|:<PROXY_PORT>'
ss -lnuup | grep -E ':1234|:61081|:<PROXY_PORT>'
```

修复方向：

- 如果只是接入 Node，不想立即开放代理端口，把默认 Profile 入站改成 `127.0.0.1:61081`。
- 真正提供服务时，再创建明确的 VLESS/Reality、Trojan、Shadowsocks 等正式入站。
- 云安全组和系统防火墙只开放明确的代理入站端口，不开放 `NODE_PORT`。
