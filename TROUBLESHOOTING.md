# 故障排查手册

> 目标：部署后出现 502、404、timeout、unauthorized、节点不通、订阅异常、Reality 握手失败时，按这份手册定位问题。新机器从零部署看 [DEPLOYMENT.md](./DEPLOYMENT.md)。

不要把真实 token、密码、API key、订阅 URL、Reality private key 写进笔记或仓库。需要完整客户端链接时，从 s-ui 面板重新读取。

## 1. 排查顺序

先判断问题在哪一层：

```text
DNS / 安全组 / 防火墙
  -> Caddy / 公网 HTTPS
  -> 本机端口监听
  -> Docker 或 systemd 服务
  -> 应用配置
  -> 客户端配置
```

每次修改前先备份，每次修改后只验证一个假设。不要同时改 Caddy、容器、面板和客户端，否则很难知道是哪一步修好的。

## 2. 基础状态采集

先跑这一组，保存输出里的异常：

```bash
date -u
hostname -I
docker ps
ss -lntup | grep -E ':80|:443|:2095|:2096|:3001|:3002|:7123|:32676'

systemctl status s-ui --no-pager -l
docker logs --tail 100 caddy
docker logs --tail 100 sub-store
docker logs --tail 100 sillytavern
```

公网入口验证：

```bash
curl -vk https://silly.example.com/
curl -vk https://sub.example.com/
curl -vk https://sub.example.com/mihomo
```

本机上游验证：

```bash
curl -sS -o /dev/null -w 'sub frontend %{http_code} %{content_type}\n' http://127.0.0.1:3001/
curl -sS -o /dev/null -w 'sub backend %{http_code} %{content_type}\n' http://127.0.0.1:3002/
curl -sS -o /dev/null -w 'silly %{http_code}\n' http://127.0.0.1:7123/
curl -sS -o /dev/null -w 's-ui sub %{http_code}\n' http://127.0.0.1:2096/sub/<SUB_PATH>
```

## 3. Caddy 排查

### 公网 502

常见原因：Caddy 能收到请求，但反代的上游端口没有监听，或端口写错。

检查：

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker logs --since 5m caddy
ss -lntup | grep -E ':3001|:3002|:7123'
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7123/
```

修复方向：

- SillyTavern 反代应指向宿主机 `127.0.0.1:7123`，不是容器内部 `8000`。
- Sub-Store 前端应指向 `127.0.0.1:3001`。
- Sub-Store 文件/API 应指向 `127.0.0.1:3002`。
- 上游没监听时，先修应用容器或 systemd 服务，不要先改 Caddy。

### 证书申请失败

检查：

```bash
dig +short silly.example.com
dig +short sub.example.com
ss -lntup | grep -E ':80|:443'
docker logs --tail 200 caddy
```

修复方向：

- 域名 DNS 必须指向当前服务器。
- 安全组和系统防火墙必须放行 `80/tcp` 和 `443/tcp`。
- 如果经过 Cloudflare，确认代理和 SSL/TLS 模式没有挡住 ACME 验证。
- 同一 IP 上不要让其他服务占用 Caddy 的 `80/tcp` 或 `443/tcp`。

### 改配置不生效

按这个顺序确认：

```bash
cd /opt/caddy
cp etc/Caddyfile etc/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
docker logs --tail 100 caddy
```

如果 reload 成功但行为没变，确认改的是 `/opt/caddy/etc/Caddyfile`，不是其他路径的 Caddyfile。

## 4. s-ui 排查

### 基础命令

```bash
systemctl status s-ui --no-pager -l
journalctl -u s-ui -n 200 --no-pager
journalctl -u s-ui -f
ss -lntup | grep sui
/usr/local/s-ui/sui -v
/usr/local/s-ui/sui setting -show
/usr/local/s-ui/sui uri
```

s-ui 的核心数据在：

```text
/usr/local/s-ui/db/s-ui.db
/etc/systemd/system/s-ui.service
```

s-ui 生成的是 sing-box 配置，配置由 SQLite 数据库动态生成。登录面板后，可通过面板 API `<PANEL_BASE>/app/api/singbox-config` 查看当前生成配置。

### 面板打不开

检查：

```bash
systemctl status s-ui --no-pager -l
ss -lntup | grep -E ':2095'
/usr/local/s-ui/sui uri
```

修复方向：

- 确认面板端口是当前设置里的 `Panel port`。
- 确认 URL path 是当前设置里的 `Panel path`。
- 检查安全组和系统防火墙。
- 如果面板暴露到公网，建议限制来源 IP。

### 订阅 404

检查：

```bash
/usr/local/s-ui/sui setting -show
curl -v http://127.0.0.1:2096/sub/<SUB_PATH>
```

修复方向：

- 确认 `Sub port` 和 `Sub path`。
- Sub-Store 与 s-ui 在同机时，Sub-Store 里优先填 `http://127.0.0.1:2096/sub/<SUB_PATH>`。
- 不要让 Sub-Store 绕公网域名访问同机 s-ui 订阅。

### 节点不通

检查：

```bash
ss -lntup | grep -E ':32676|:443'
journalctl -u s-ui -n 200 --no-pager
```

修复方向：

- 确认入站端口正在监听。
- 确认安全组和防火墙放行入站端口。
- 确认客户端 UUID、flow、Reality public key、short id、SNI、fingerprint 与面板一致。
- 如果入站使用 `443/tcp`，确认 Caddy 或其他服务没有占用同一 IP 的 `443/tcp`。

<a id="s-ui-vless-reality-真实案例"></a>

## 5. s-ui VLESS Reality 真实案例

记录日期：2026-06-30。

### 结论

- `xg` 服务器上的 s-ui 已部署并运行正常，版本为 `s-ui 1.5.0`。
- 这次 VLESS + Reality 的失败点不是端口、防火墙、DNS、客户端、时间偏移、UUID、public/private key 不匹配，也不是 short id 长度本身。
- 失败配置使用了 `www.microsoft.com` 作为 Reality 的 `server_name` 和 handshake 目标。
- 服务端日志出现 `TLS handshake: REALITY: processed invalid connection`。
- 客户端表现为 EOF/reset。
- 改用 `www.cloudflare.com` 并重新生成 Reality keypair/short id 后，Xray 和 sing-box 客户端都验证成功。

### 当前可用配置特征

```text
入站协议：vless
入站端口：443
Reality SNI：www.cloudflare.com
Reality handshake server：www.cloudflare.com
Reality fingerprint：chrome
VLESS flow：xtls-rprx-vision
DNS：sing-box 配置中补 Cloudflare DoT，并保留 DNS hijack 规则
```

注意：这是 `xg` 当时的可用特征，不代表所有机器都必须用 `443/tcp`。如果同机还要跑 Caddy HTTPS，优先使用独立 s-ui 入站端口，或给 s-ui 准备独立 IP。

### 排查过程

1. 确认 s-ui 服务运行：

   ```bash
   systemctl status s-ui --no-pager -l
   ss -lntup | grep -E ':2095|:443'
   ```

2. 确认配置来源：

   ```text
   SQLite 数据库：/usr/local/s-ui/db/s-ui.db
   sing-box 配置接口：<PANEL_BASE>/app/api/singbox-config
   ```

3. 观察失败特征：

   ```text
   SNI/handshake：www.microsoft.com
   服务端日志：TLS handshake: REALITY: processed invalid connection
   客户端：Xray 和 sing-box 都出现 EOF/reset 类失败
   ```

4. 已排除项：

   ```text
   443 端口不可达
   DNS 未配置导致的入站握手失败
   客户端实现问题
   Reality public/private key 不匹配
   服务器和本地时间偏移
   short id 只需要缩短即可解决
   ```

5. 最终修复：

   ```text
   重新生成 Reality keypair 和 short id
   将 server_name 与 handshake 目标改为 www.cloudflare.com
   重启 s-ui
   用 Xray 与 sing-box 本地客户端复测
   ```

### 复测方法

可以用本地 Xray 或 sing-box 启一个临时 SOCKS/mixed 代理，然后请求 Cloudflare trace：

```bash
curl --socks5-hostname 127.0.0.1:18081 https://www.cloudflare.com/cdn-cgi/trace
```

成功时应能看到出口 IP 为服务器出口 IP，并出现类似：

```text
colo=HKG
loc=HK
tls=TLSv1.3
h=www.cloudflare.com
```

同时服务端日志应出现 VLESS 客户端连接记录，而不是 `processed invalid connection`。

### DNS 备注

- 服务端 DNS 已补到 sing-box 配置里，使用 Cloudflare DoT。
- 客户端是否把 DNS 请求发到服务器，取决于客户端模式：
  - 如果客户端本地解析域名，DNS 不会到服务器。
  - 如果客户端把域名目标交给代理，服务器会用 sing-box DNS 解析。
  - 如果客户端使用 TUN/透明代理并把 DNS 劫持进代理，DNS 请求才会被服务端 DNS 规则接管。

## 6. Sub-Store 排查

### 基础命令

```bash
cd /opt/substore
docker compose ps
docker compose logs -f
docker logs --tail 200 sub-store
curl -I https://sub.example.com/mihomo
curl -sS http://127.0.0.1:3002/api/file/mihomo-auto | head
```

### `/mihomo` 404

修复方向：

- Caddy 中 `/mihomo` 是否 rewrite 到 `/api/file/mihomo-auto`。
- Sub-Store file 名称是否正好叫 `mihomo-auto`。
- Caddy 是否把 `/mihomo` 反代到后端 `127.0.0.1:3002`，不是前端 `3001`。

### 下载为空

修复方向：

- collection 是否选中了订阅。
- 远程机场订阅是否能拉取。
- 自建 s-ui 订阅是否能从 Sub-Store 容器访问。
- file 的 `sourceType`、`source`、`platform` 是否正确。

### 自建节点没出现

检查：

```bash
curl -v http://127.0.0.1:2096/sub/<SUB_PATH>
docker inspect sub-store --format '{{.HostConfig.NetworkMode}}'
```

修复方向：

- Sub-Store 推荐使用 `network_mode: host`。
- s-ui 订阅地址推荐用 `127.0.0.1:2096`。
- 确认 s-ui 的 `Sub path` 没写错。

### 客户端提示格式错误

修复方向：

- file 的 platform/模板应选择 Mihomo/ClashMeta 对应格式。
- 用 `curl -sS https://sub.example.com/mihomo | head` 看输出是不是客户端期望格式。

## 7. SillyTavern 排查

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

## 8. 修改前备份

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

iptables：

```bash
iptables-save > /root/iptables-before-change-$(date +%Y%m%d-%H%M%S).rules
```
