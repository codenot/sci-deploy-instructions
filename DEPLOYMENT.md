# 部署手册

> 目标：新服务器到手后，按这份流程部署 Caddy、s-ui、Sub-Store、SillyTavern，并完成基础验证。排查问题时看 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)。

文档中的域名、端口、路径、token、密码都用占位符表示，部署时按实际情况替换。不要把真实密钥、真实订阅地址、Reality private key 写进仓库。

## 1. 架构和约定

### 推荐目录

```bash
/opt/caddy
/opt/s-ui-backup
/opt/substore
/opt/SillyTavern
```

### 推荐域名

```text
silly.example.com     -> SillyTavern
sub.example.com       -> Sub-Store
api.example.com       -> 其他 API 服务，可选
```

### 端口约定

| 服务 | 内部端口 | 宿主机监听 | 说明 |
|---|---:|---:|---|
| Caddy | 80/443 | 80/443 | 公网 HTTPS 入口 |
| s-ui 面板 | 2095 | 2095 | 建议限制来源 IP 或只在需要时开放 |
| s-ui 订阅 | 2096 | 2096 | 给 Sub-Store 读取 |
| s-ui 入站 | 32676 | 32676 | 示例 VLESS/Reality 入站端口 |
| Sub-Store 前端 | 3001 | 127.0.0.1:3001 | 只给 Caddy 反代 |
| Sub-Store 后端 | 3002 | 127.0.0.1:3002 | 文件/API 下载 |
| SillyTavern | 8000 | 127.0.0.1:7123 | 只给 Caddy 反代 |

如果把 s-ui Reality 入站放到 `443/tcp`，同一台机器同一个公网 IP 上 Caddy 就不能同时监听 `443/tcp`。除非有独立 IP 或明确的流量分流方案，否则按上表把 Caddy 和 s-ui 入站分开。

## 2. 基础环境

### 安装 Docker

Ubuntu/Debian 推荐：

```bash
apt update
apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker version
docker compose version
```

### 防火墙

至少放行：

```text
80/tcp
443/tcp
s-ui 入站端口，例如 32676/tcp
```

如果 s-ui 面板不走 Caddy，也要放行面板端口。更稳妥的做法是限制来源 IP，或只在维护窗口临时开放。

## 3. Caddy 部署

### 创建目录

```bash
mkdir -p /opt/caddy/{etc,data,config,logs}
cd /opt/caddy
```

### docker-compose.yaml

```yaml
services:
  caddy:
    image: caddy:alpine
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./etc:/etc/caddy
      - ./data:/data
      - ./config:/config
      - /opt/share:/opt/share:ro
```

如果没有 `/opt/share` 静态文件目录，可以删掉最后一行 volume。

### Caddyfile 模板

```bash
cat > /opt/caddy/etc/Caddyfile <<'EOF'
silly.example.com {
    reverse_proxy 127.0.0.1:7123
}

sub.example.com {
    handle /mihomo {
        rewrite * /api/file/mihomo-auto
        reverse_proxy 127.0.0.1:3002
    }

    handle {
        reverse_proxy 127.0.0.1:3001
    }
}
EOF
```

### 启动与验证

```bash
cd /opt/caddy
docker compose up -d
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker logs --tail 100 caddy
```

### 新增或修改站点

```bash
cd /opt/caddy
cp etc/Caddyfile etc/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)
vim etc/Caddyfile
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

## 4. s-ui 部署

### 安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/main/install.sh)
```

安装完成后确认：

```bash
systemctl status s-ui --no-pager -l
/usr/local/s-ui/sui -v
```

### 设置面板和订阅端口

```bash
/usr/local/s-ui/sui setting -show
/usr/local/s-ui/s-ui.sh
```

推荐设置：

```text
Panel port: 2095
Panel path: <RANDOM_PANEL_PATH>
Sub port: 2096
Sub path: <RANDOM_SUB_PATH>
```

查看访问地址：

```bash
/usr/local/s-ui/sui uri
```

管理员账号：

```bash
# 会显示凭据，只在安全终端执行
/usr/local/s-ui/sui admin -show

# 修改管理员账号密码
/usr/local/s-ui/sui admin -username <USER> -password <PASSWORD>
```

### 创建 VLESS/Reality 入站

在 s-ui 面板中创建 sing-box 入站。推荐起点：

```text
协议：VLESS
端口：32676
安全：Reality
server_name / SNI：www.cloudflare.com
handshake server：www.cloudflare.com
fingerprint：chrome
flow：xtls-rprx-vision
用户：创建一个或多个客户端用户
```

保存前重新生成 Reality keypair 和 short id。不要使用 `www.microsoft.com` 作为 Reality 的 SNI 或 handshake 目标；已知会导致 `processed invalid connection` 类失败。细节看 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md#s-ui-vless-reality-真实案例)。

保存后确认端口：

```bash
systemctl restart s-ui
ss -lntup | grep sui
journalctl -u s-ui -n 100 --no-pager
```

### 提供给 Sub-Store 的订阅地址

订阅地址形态：

```text
http://127.0.0.1:2096/sub/<SUB_PATH>
```

如果 Sub-Store 和 s-ui 在同一台机器，推荐让 Sub-Store 使用这个本机地址，不要绕公网域名。

### 备份与恢复

核心数据：

```bash
/usr/local/s-ui/db/s-ui.db
/etc/systemd/system/s-ui.service
```

备份：

```bash
mkdir -p /opt/s-ui-backup
tar czf /opt/s-ui-backup/s-ui-$(date +%Y%m%d).tgz \
  /usr/local/s-ui/db \
  /etc/systemd/system/s-ui.service
```

恢复后：

```bash
systemctl daemon-reload
systemctl enable --now s-ui
systemctl restart s-ui
```

## 5. Sub-Store 部署

### 创建目录

```bash
mkdir -p /opt/substore/data
cd /opt/substore
```

### docker-compose.yaml

```yaml
services:
  sub-store:
    image: xream/sub-store:http-meta
    container_name: sub-store
    restart: always
    network_mode: host
    environment:
      SUB_STORE_BACKEND_API_HOST: 127.0.0.1
      SUB_STORE_BACKEND_API_PORT: 3002
      SUB_STORE_FRONTEND_BACKEND_PATH: /api
      SUB_STORE_FRONTEND_PORT: 3001
      SUB_STORE_FRONTEND_HOST: 127.0.0.1
      PORT: 9876
      HOST: 127.0.0.1
    volumes:
      - ./data:/opt/app/data
```

说明：

- `network_mode: host` 是为了直接访问本机 s-ui 订阅地址 `127.0.0.1:2096`。
- 前端和后端都绑定 `127.0.0.1`，只允许 Caddy 对外暴露。

### 启动与验证

```bash
cd /opt/substore
docker compose up -d
docker compose ps

curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' http://127.0.0.1:3001/
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' http://127.0.0.1:3002/
curl -ksS -o /dev/null -w '%{http_code} %{content_type}\n' https://sub.example.com/
```

### 配置订阅

进入：

```text
https://sub.example.com/
```

推荐结构：

1. 创建机场原始订阅：

```text
name: airport-main
source: remote
url: <机场原始订阅 URL>
```

2. 创建自建节点订阅：

```text
name: self-hosted
source: remote
url: http://127.0.0.1:2096/sub/<SUB_PATH>
```

3. 创建 collection：

```text
name: all-airports
subscriptions:
  - airport-main
  - self-hosted
```

4. 创建 file：

```text
name: mihomo-auto
sourceType: collection
source: all-airports
platform: ClashMeta / Mihomo
download: true
```

Caddy 会把：

```text
https://sub.example.com/mihomo
```

重写到：

```text
/api/file/mihomo-auto
```

客户端订阅：

```text
https://sub.example.com/mihomo
```

### 备份

```bash
cp /opt/substore/data/sub-store.json \
  /opt/substore/data/sub-store.json.bak-$(date +%Y%m%d-%H%M%S)

tar czf /opt/substore-backup-$(date +%Y%m%d).tgz /opt/substore/data /opt/substore/docker-compose.yaml
```

## 6. SillyTavern 部署

### 创建目录

```bash
mkdir -p /opt/SillyTavern/{config,data,plugins,extensions}
cd /opt/SillyTavern
```

### docker-compose.yml

```yaml
services:
  sillytavern:
    container_name: sillytavern
    hostname: sillytavern
    image: ghcr.io/sillytavern/sillytavern:latest
    environment:
      - NODE_ENV=production
      - FORCE_COLOR=1
      - SILLYTAVERN_HEARTBEATINTERVAL=30
    ports:
      - "127.0.0.1:7123:8000"
    volumes:
      - "./config:/home/node/app/config"
      - "./data:/home/node/app/data"
      - "./plugins:/home/node/app/plugins"
      - "./extensions:/home/node/app/public/scripts/extensions/third-party"
    healthcheck:
      test: ["CMD", "node", "src/healthcheck.js"]
      interval: 30s
      timeout: 10s
      start_period: 20s
      retries: 3
    restart: unless-stopped
```

### 初始化配置

首次启动：

```bash
docker compose up -d
docker compose logs -f
```

如果 `/opt/SillyTavern/config/config.yaml` 尚未生成，可先启动一次让容器生成，再停下来修改：

```bash
docker compose down
vim /opt/SillyTavern/config/config.yaml
```

推荐关键配置：

```yaml
dataRoot: ./data
listen: false
port: 8000
whitelistMode: true
enableForwardedWhitelist: false
whitelist:
  - ::1
  - 127.0.0.1
  - <DOCKER_BRIDGE_GATEWAY_IP>
whitelistDockerHosts: true
basicAuthMode: false
enableUserAccounts: false
forwardedHeaders:
  xRealIp: true
  xForwardedFor: true
  cfConnectingIp: false
```

获取 Docker bridge gateway：

```bash
docker inspect sillytavern \
  --format '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}'
```

常见是：

```text
172.18.0.1
172.19.0.1
```

改完后：

```bash
docker compose up -d
```

### Caddy 反代

```caddy
silly.example.com {
    reverse_proxy 127.0.0.1:7123
}
```

注意：Caddy 反代宿主机端口 `7123`，不是容器内部端口 `8000`。

### API 设置

如果使用 OpenAI-compatible 的 Chat Completions 服务，SillyTavern UI 中推荐：

```text
API: Chat Completion
Source: Custom / OpenAI-compatible
Endpoint: https://api.example.com/v1
Model: <MODEL_NAME>
API key: <API_KEY>
```

不要把 OpenAI-compatible chat API 配到 `Text Completion / Generic`。这个模式通常会请求：

```text
/v1/completions
```

而 Chat Completions 应该请求：

```text
/v1/chat/completions
```

### 验证

```bash
cd /opt/SillyTavern
docker compose ps
docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' sillytavern

curl -ksS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7123/
curl -ksS -o /dev/null -w '%{http_code}\n' https://silly.example.com/
docker logs --tail 200 sillytavern
```

验证上游 API：

```bash
docker exec sillytavern node - <<'NODE'
const url = 'https://api.example.com/v1/chat/completions';
const key = process.env.API_KEY || '<API_KEY>';
fetch(url, {
  method: 'POST',
  headers: {
    authorization: `Bearer ${key}`,
    'content-type': 'application/json',
  },
  body: JSON.stringify({
    model: '<MODEL_NAME>',
    messages: [{ role: 'user', content: 'ping' }],
    max_tokens: 8,
  }),
}).then(async r => {
  console.log(r.status, (await r.text()).slice(0, 300));
}).catch(console.error);
NODE
```

### 备份

```bash
tar czf /opt/sillytavern-backup-$(date +%Y%m%d).tgz \
  /opt/SillyTavern/config \
  /opt/SillyTavern/data \
  /opt/SillyTavern/plugins \
  /opt/SillyTavern/extensions \
  /opt/SillyTavern/docker-compose.yml
```

## 7. 全链路验证

部署完成后建议跑：

```bash
docker ps
ss -lntup | grep -E ':80|:443|:2095|:2096|:3001|:3002|:7123'

curl -ksS -o /dev/null -w 'silly %{http_code} %{time_total}\n' https://silly.example.com/
curl -ksS -o /dev/null -w 'sub %{http_code} %{time_total}\n' https://sub.example.com/
curl -ksS -o /dev/null -w 'mihomo %{http_code} %{content_type} %{time_total}\n' https://sub.example.com/mihomo

systemctl status s-ui --no-pager -l
docker logs --tail 100 caddy
docker logs --tail 100 sub-store
docker logs --tail 100 sillytavern
```

如果验证失败，不要在部署手册里继续猜。按 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) 从链路入口逐层排查。

## 8. 修改前备份习惯

Caddy：

```bash
cp /opt/caddy/etc/Caddyfile /opt/caddy/etc/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)
```

Sub-Store：

```bash
cp /opt/substore/data/sub-store.json /opt/substore/data/sub-store.json.bak-$(date +%Y%m%d-%H%M%S)
```

SillyTavern：

```bash
cp /opt/SillyTavern/config/config.yaml /opt/SillyTavern/config/config.yaml.bak-$(date +%Y%m%d-%H%M%S)
cp /opt/SillyTavern/docker-compose.yml /opt/SillyTavern/docker-compose.yml.bak-$(date +%Y%m%d-%H%M%S)
```

s-ui：

```bash
mkdir -p /opt/s-ui-backup
tar czf /opt/s-ui-backup/s-ui-before-change-$(date +%Y%m%d-%H%M%S).tgz /usr/local/s-ui/db
```
