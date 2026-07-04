# Marzban 部署

> Marzban 是基于 Xray-core 的多用户面板。推荐让面板只监听 `127.0.0.1:8000`，由 Caddy 反代提供 HTTPS；节点入站端口在面板里创建后再按需开放，不要默认暴露管理端口。基础约定见 [deployment.md](../deployment.md)。

Marzban Docker 部署按本仓库约定把 compose、配置、数据库和备份都放在 `/opt/marzban` 下，不使用会把数据放到 `/var/lib/marzban` 的默认安装路径。

同机同时运行 Marzban Master 和 Marzban Node 会启动两个 Xray 实例，容易出现入站端口冲突。单机部署优先直接使用 Marzban Master 入站；多地区服务器再单独部署 Marzban Node。

## 创建目录

```bash
mkdir -p /opt/marzban/{data,config,backup,logs}
chmod 700 /opt/marzban
cd /opt/marzban
```

## docker-compose.yml

```yaml
services:
  marzban:
    image: gozargah/marzban:latest
    container_name: marzban
    restart: unless-stopped
    network_mode: host
    env_file:
      - ./.env
    volumes:
      - ./data:/opt/marzban/data
      - ./config:/opt/marzban/config
```

说明：

- `network_mode: host` 方便 Xray 入站直接监听宿主机端口。
- 面板进程由 Marzban 自己绑定到 `127.0.0.1:8000`，不直接暴露公网。
- SQLite 数据库、Xray 配置都映射到 `/opt/marzban` 子目录。

## .env

```bash
cat > /opt/marzban/.env <<'EOF'
SQLALCHEMY_DATABASE_URL=sqlite:////opt/marzban/data/db.sqlite3
XRAY_JSON=/opt/marzban/config/xray_config.json
UVICORN_HOST=127.0.0.1
UVICORN_PORT=8000
DASHBOARD_PATH=/<RANDOM_DASHBOARD_PATH>/
DOCS=False
XRAY_SUBSCRIPTION_URL_PREFIX=https://marzban.example.com
XRAY_SUBSCRIPTION_PATH=<RANDOM_SUB_PATH>
SUB_PROFILE_TITLE=Marzban
SUB_SUPPORT_URL=https://t.me/
EOF

chmod 600 /opt/marzban/.env
```

`DASHBOARD_PATH` 和 `XRAY_SUBSCRIPTION_PATH` 使用随机路径。不要把真实路径、管理员密码或订阅路径提交到仓库。

## 初始 xray_config.json

首次启动时不要直接使用默认 `1080` 入站。先用一个只监听本机的占位入站启动面板，后续在 Marzban 面板里显式创建 VLESS/Reality、Trojan、Shadowsocks 等入站。

```bash
cat > /opt/marzban/config/xray_config.json <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "BLOCK",
        "type": "field"
      }
    ]
  },
  "inbounds": [
    {
      "tag": "PLACEHOLDER_LOOPBACK",
      "listen": "127.0.0.1",
      "port": 61080,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 9,
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "DIRECT"
    },
    {
      "protocol": "blackhole",
      "tag": "BLOCK"
    }
  ]
}
EOF

chmod 600 /opt/marzban/config/xray_config.json
```

## 启动

```bash
cd /opt/marzban
docker compose config >/dev/null
docker compose up -d
docker compose ps
docker logs --tail 100 marzban
```

## 创建管理员

```bash
ADMIN_USER='<ADMIN_USER>'
ADMIN_PASS='<ADMIN_PASSWORD>'

cd /opt/marzban
MARZBAN_ADMIN_PASSWORD="$ADMIN_PASS" \
  docker compose exec -T \
  -e MARZBAN_ADMIN_PASSWORD="$ADMIN_PASS" \
  marzban marzban-cli admin create \
  --username "$ADMIN_USER" \
  --sudo \
  --telegram-id 0 \
  --discord-webhook 0
```

如果需要在服务器本地保存凭据，只放在 `/opt/marzban/admin-credentials.txt`，并设置为 root 只读：

```bash
cat > /opt/marzban/admin-credentials.txt <<'EOF'
Marzban URL: https://marzban.example.com/<RANDOM_DASHBOARD_PATH>/
Username: <ADMIN_USER>
Password: <ADMIN_PASSWORD>
Notes: This file is root-readable only. Do not commit these values to git.
EOF

chmod 600 /opt/marzban/admin-credentials.txt
```

## Caddy 反代

修改前先备份：

```bash
cp /opt/caddy/etc/Caddyfile \
  /opt/caddy/etc/Caddyfile.bak-marzban-$(date +%Y%m%d-%H%M%S)
```

追加站点：

```caddy
marzban.example.com {
    reverse_proxy 127.0.0.1:8000
}
```

校验并 reload：

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

## 验证

```bash
cd /opt/marzban
docker compose ps
docker inspect -f '{{.State.Status}} {{.RestartCount}}' marzban

ss -lntup | grep -E ':8000|:61080'
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  http://127.0.0.1:8000/<RANDOM_DASHBOARD_PATH>/
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  http://127.0.0.1:8000/api/system
curl -ksS -o /dev/null -w '%{http_code} %{content_type}\n' \
  https://marzban.example.com/<RANDOM_DASHBOARD_PATH>/

docker logs --tail 200 marzban
```

预期：

- Dashboard 返回 `200 text/html`。
- 未登录访问 `/api/system` 返回 `401 application/json`，这是正常的鉴权行为。
- `ss` 中面板只应显示 `127.0.0.1:8000`。

## 创建节点入站

进入：

```text
https://marzban.example.com/<RANDOM_DASHBOARD_PATH>/
```

推荐起点：

```text
协议：VLESS
安全：Reality
server_name / SNI：www.cloudflare.com
handshake server：www.cloudflare.com
fingerprint：chrome
flow：xtls-rprx-vision
端口：选择未占用端口，例如 32677
```

创建入站后再开放对应端口，并验证：

```bash
ss -lntup | grep '<INBOUND_PORT>'
docker logs --tail 100 marzban
```

不要把 Marzban 面板端口、Xray API 端口或临时测试端口直接暴露到公网。

## 提供给 Sub-Store 的订阅地址

订阅地址形态：

```text
https://marzban.example.com/<RANDOM_SUB_PATH>/<USER_TOKEN>
```

如果 Sub-Store 和 Marzban 在同一台机器，也可以让 Sub-Store 读取 Caddy HTTPS 订阅地址。不要把真实用户 token 写进仓库。

## 备份与恢复

备份：

```bash
tar czf /opt/marzban/backup/marzban-$(date +%Y%m%d-%H%M%S).tgz \
  -C /opt/marzban \
  docker-compose.yml .env data config
```

恢复后：

```bash
cd /opt/marzban
docker compose up -d
docker compose ps
docker logs --tail 100 marzban
```

## 排查

### 基础命令

```bash
cd /opt/marzban
docker compose ps
docker inspect -f '{{.State.Status}} {{.RestartCount}}' marzban
docker logs --tail 200 marzban
ss -lntup | grep -E ':8000|:61080|:<INBOUND_PORT>'
```

### 面板打不开或 Caddy 502

检查：

```bash
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  http://127.0.0.1:8000/<RANDOM_DASHBOARD_PATH>/
curl -ksS -o /dev/null -w '%{http_code} %{content_type}\n' \
  https://marzban.example.com/<RANDOM_DASHBOARD_PATH>/
docker logs --tail 100 caddy
docker logs --tail 100 marzban
```

修复方向：

- Caddy 上游应指向 `127.0.0.1:8000`。
- `UVICORN_HOST` 应为 `127.0.0.1`，不要让面板直接公网监听。
- `DASHBOARD_PATH` 必须和访问路径一致，包含前后 `/` 时要保持一致。
- 容器没启动时先看 `.env`、`xray_config.json` 和 Marzban 日志。

### `/api/system` 返回 401

未登录访问 `/api/system` 返回 `401 application/json` 是正常鉴权行为。用它验证应用进程活着，不代表登录失败。

```bash
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  http://127.0.0.1:8000/api/system
```

### 节点入站不监听

检查：

```bash
ss -lntup | grep '<INBOUND_PORT>'
docker logs --tail 200 marzban
```

修复方向：

- 确认入站已经在 Marzban 面板里创建并启用。
- 确认端口没有被 s-ui、Caddy、Remnawave Node 或其他 Xray 实例占用。
- 单机部署优先使用 Marzban Master 入站，不要同时再跑同机 Marzban Node。
- 修改 Xray 配置后观察 Marzban 日志是否有 JSON 或端口绑定错误。

### 订阅无法被 Sub-Store 读取

检查：

```bash
curl -vk https://marzban.example.com/<RANDOM_SUB_PATH>/<USER_TOKEN>
docker logs --tail 100 marzban
```

修复方向：

- `XRAY_SUBSCRIPTION_URL_PREFIX` 应是 `https://marzban.example.com`。
- `XRAY_SUBSCRIPTION_PATH` 应和面板生成的订阅路径一致。
- 不要把真实 `<USER_TOKEN>` 写进仓库或聊天记录。
