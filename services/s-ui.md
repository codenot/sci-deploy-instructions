# s-ui 部署

> s-ui 提供面板、订阅和节点入站。基础约定见 [deployment.md](../deployment.md)。

## 安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/main/install.sh)
```

安装完成后确认：

```bash
systemctl status s-ui --no-pager -l
/usr/local/s-ui/sui -v
```

## 设置面板和订阅端口

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

## 创建 VLESS/Reality 入站

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

保存前重新生成 Reality keypair 和 short id。不要使用 `www.microsoft.com` 作为 Reality 的 SNI 或 handshake 目标；已知会导致 `processed invalid connection` 类失败。

保存后确认端口：

```bash
systemctl restart s-ui
ss -lntup | grep sui
journalctl -u s-ui -n 100 --no-pager
```

## 提供给 Sub-Store 的订阅地址

订阅地址形态：

```text
http://127.0.0.1:2096/sub/<SUB_PATH>
```

如果 Sub-Store 和 s-ui 在同一台机器，推荐让 Sub-Store 使用这个本机地址，不要绕公网域名。

## 备份与恢复

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

## 排查

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

## s-ui VLESS Reality 真实案例

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
