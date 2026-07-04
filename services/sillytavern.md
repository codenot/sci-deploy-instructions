# SillyTavern 部署

> SillyTavern 只监听本机端口，由 Caddy 反代提供公网 HTTPS。基础约定见 [deployment.md](../deployment.md)。

## 创建目录

```bash
mkdir -p /opt/SillyTavern/{config,data,plugins,extensions}
cd /opt/SillyTavern
```

## docker-compose.yml

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

## 初始化配置

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

## Caddy 反代

```caddy
silly.example.com {
    reverse_proxy 127.0.0.1:7123
}
```

注意：Caddy 反代宿主机端口 `7123`，不是容器内部端口 `8000`。

## API 设置

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

## 验证

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

## 备份

```bash
tar czf /opt/sillytavern-backup-$(date +%Y%m%d).tgz \
  /opt/SillyTavern/config \
  /opt/SillyTavern/data \
  /opt/SillyTavern/plugins \
  /opt/SillyTavern/extensions \
  /opt/SillyTavern/docker-compose.yml
```

## 排查

### 基础命令

```bash
cd /opt/SillyTavern
docker compose ps
docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' sillytavern
docker logs --tail 200 sillytavern
curl -ksS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7123/
curl -ksS -o /dev/null -w '%{http_code}\n' https://silly.example.com/
```

### 公网 502

修复方向：

- Caddy 上游应为 `127.0.0.1:7123`。
- Docker compose 端口映射应为 `127.0.0.1:7123:8000`。
- 容器内部端口 `8000` 不应该直接写进 Caddy 反代。

### 页面 forbidden / unauthorized

修复方向：

- SillyTavern whitelist 要包含 Docker bridge gateway。
- `enableForwardedWhitelist` 可以先设为 `false`。
- `whitelistDockerHosts` 推荐设为 `true`。

获取 gateway：

```bash
docker inspect sillytavern \
  --format '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}'
```

### 模型列表能拉到但生成失败

修复方向：

- OpenAI-compatible Chat Completions 服务应配置到 `Chat Completion`。
- Source 选 `Custom / OpenAI-compatible`。
- Endpoint 形态通常是 `https://api.example.com/v1`。
- 不要配到 `Text Completion / Generic`，它通常请求 `/v1/completions`。
- Chat Completions 应请求 `/v1/chat/completions`。

容器内验证：

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

### 生成 timeout 或容器出站失败

如果容器内访问外网 timeout，但宿主机正常：

```bash
docker exec sillytavern node -e 'fetch("https://1.1.1.1").then(r=>console.log(r.status)).catch(console.error)'
curl -I https://1.1.1.1
iptables -S FORWARD
docker network ls
docker network inspect <SILLYTAVERN_NETWORK>
```

修改 iptables 前先备份：

```bash
iptables-save > /root/iptables-before-docker-egress-$(date +%Y%m%d-%H%M%S).rules
```

临时放通某个 Docker bridge 示例：

```bash
BRIDGE=br-xxxxxxxxxxxx
iptables -I FORWARD 1 -o "$BRIDGE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD 2 -i "$BRIDGE" ! -o "$BRIDGE" -j ACCEPT
```

注意：这只是运行时规则。服务器重启后要重新确认，或用 systemd oneshot / netfilter-persistent 做持久化。
