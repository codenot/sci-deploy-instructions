# 部署总手册

> 目标：记录新服务器部署时的基础 Docker 环境、全局约定、通用验证和排查入口。按需选择服务部署；具体服务步骤在 `services/` 下对应文件里。

文档中的域名、端口、路径、token、密码都用占位符表示，部署时按实际情况替换。不要把真实密钥、真实订阅地址、Reality private key 写进仓库。

## 1. 文档入口

按任务进入对应文档：

| 任务 | 文档 |
|---|---|
| 基础 Docker、目录、域名、端口、防火墙约定 | 本文件 |
| Caddy 公网 HTTPS 入口 | [services/caddy.md](./services/caddy.md) |
| s-ui 面板、订阅、VLESS/Reality 入站 | [services/s-ui.md](./services/s-ui.md) |
| Marzban 面板、管理员、Xray 入站 | [services/marzban.md](./services/marzban.md) |
| Remnawave Panel、数据库、节点接入入口 | [services/remnawave.md](./services/remnawave.md) |
| Sub-Store 订阅聚合和 `/mihomo` 文件 | [services/sub-store.md](./services/sub-store.md) |
| SillyTavern 反代、白名单、API 设置 | [services/sillytavern.md](./services/sillytavern.md) |
| 通用链路排查、基础状态采集 | 本文件 |

按实际机器角色选择需要部署的服务。一台服务器不需要部署全部服务。

## 2. 目录约定

推荐服务根目录：

```bash
/opt/caddy
/opt/s-ui-backup
/opt/marzban
/opt/remnawave
/opt/remnawave-node
/opt/substore
/opt/SillyTavern
```

Docker 服务统一以 `/opt/<service>` 作为部署根目录，compose、环境文件和服务数据都放在这个根目录下。宿主机挂载目录使用固定语义子目录：

```text
/opt/<service>/data
/opt/<service>/config
/opt/<service>/etc
/opt/<service>/logs
/opt/<service>/backup
```

按服务实际需要创建子目录；不要使用 `docker-data`、`app-data` 这类额外前缀目录。示例：

```text
/opt/caddy/etc      -> /etc/caddy
/opt/caddy/data     -> /data
/opt/caddy/config   -> /config
/opt/substore/data  -> /opt/app/data
```

Marzban Docker 部署也按本仓库约定把 compose、配置、数据库和备份都放在 `/opt/marzban` 下，不使用会把数据放到 `/var/lib/marzban` 的默认安装路径。

## 3. 域名约定

```text
silly.example.com     -> SillyTavern
marzban.example.com   -> Marzban
remnawave.example.com -> Remnawave Panel
sub.example.com       -> Sub-Store
api.example.com       -> 其他 API 服务，可选
```

面板类服务尽量使用随机路径或强密码。真实面板路径、订阅路径、token、密码不要提交到仓库。

## 4. 端口约定

| 服务 | 内部端口 | 宿主机监听 | 说明 |
|---|---:|---:|---|
| Caddy | 80/443 | 80/443 | 公网 HTTPS 入口 |
| s-ui 面板 | 2095 | 2095 | 建议限制来源 IP 或只在需要时开放 |
| s-ui 订阅 | 2096 | 2096 | 给 Sub-Store 读取 |
| s-ui 入站 | 32676 | 32676 | 示例 VLESS/Reality 入站端口 |
| Marzban 面板 | 8000 | 127.0.0.1:8000 | 只给 Caddy 反代 |
| Marzban 入站 | 按面板配置 | 按面板配置 | 例如 VLESS/Reality 节点端口 |
| Remnawave Panel | 3000 | 127.0.0.1:3010 | 只给 Caddy 反代 |
| Remnawave Metrics | 3001 | 127.0.0.1:3011 | 只给本机健康检查或监控 |
| Remnawave Node API | 2222 | 只允许 Panel IP 或 Docker 网络访问 | Node 控制 API，不是用户代理端口 |
| Remnawave Node 入站 | 按 Config Profile | 按配置 | 例如 VLESS/Reality 节点端口 |
| Sub-Store 前端 | 3001 | 127.0.0.1:3001 | 只给 Caddy 反代 |
| Sub-Store 后端 | 3002 | 127.0.0.1:3002 | 文件/API 下载 |
| SillyTavern | 8000 | 127.0.0.1:7123 | 只给 Caddy 反代 |

如果把 s-ui Reality 入站放到 `443/tcp`，同一台机器同一个公网 IP 上 Caddy 就不能同时监听 `443/tcp`。除非有独立 IP 或明确的流量分流方案，否则按上表把 Caddy 和 s-ui 入站分开。

同机同时运行 Marzban Master 和 Marzban Node 会启动两个 Xray 实例，容易出现入站端口冲突。单机部署优先直接使用 Marzban Master 入站；多地区服务器再单独部署 Marzban Node。

Remnawave Panel 本身不跑 Xray-core；节点代理流量需要单独部署 Remnawave Node，并在面板里通过 Config Profile、Host、Internal Squad 关联。

Remnawave Node 的 `NODE_PORT` 是 Panel 调用 Node 的控制 API，不是给用户连接的代理端口。这个端口不要直接开放公网；同机 Docker 部署时可以只允许 Remnawave Panel 所在 Docker 网段访问，用户代理端口则按 Config Profile 的入站单独开放。

## 5. 安装 Docker

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

## 6. 防火墙

至少放行：

```text
80/tcp
443/tcp
s-ui 入站端口，例如 32676/tcp
Marzban 或其他节点入站端口，按面板配置开放
```

不建议直接公网暴露：

```text
Marzban 面板端口 8000
Remnawave Panel 3010
Remnawave Metrics 3011
Sub-Store 3001/3002
SillyTavern 7123
```

这些服务推荐只监听 `127.0.0.1`，由 Caddy 反代对外提供 HTTPS。

## 7. 全链路验证

部署完成后建议跑：

```bash
docker ps
ss -lntup | grep -E ':80|:443|:2095|:2096|:3001|:3002|:7123|:8000|:3010|:3011'

curl -ksS -o /dev/null -w 'silly %{http_code} %{time_total}\n' https://silly.example.com/
curl -ksS -o /dev/null -w 'marzban %{http_code} %{time_total}\n' https://marzban.example.com/<RANDOM_DASHBOARD_PATH>/
curl -ksS -o /dev/null -w 'remnawave %{http_code} %{time_total}\n' https://remnawave.example.com/
curl -ksS -o /dev/null -w 'sub %{http_code} %{time_total}\n' https://sub.example.com/
curl -ksS -o /dev/null -w 'mihomo %{http_code} %{content_type} %{time_total}\n' https://sub.example.com/mihomo

systemctl status s-ui --no-pager -l
docker logs --tail 100 caddy
docker logs --tail 100 marzban
docker logs --tail 100 remnawave
docker logs --tail 100 sub-store
docker logs --tail 100 sillytavern
```

如果验证失败，不要同时改多个组件。先按下一节通用排查定位层级，再进入对应服务文档处理。

## 8. 通用排查

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

### 基础状态采集

先跑这一组，保存输出里的异常：

```bash
date -u
hostname -I
docker ps
ss -lntup | grep -E ':80|:443|:2095|:2096|:3001|:3002|:7123|:32676|:8000|:3010|:3011'

systemctl status s-ui --no-pager -l
docker logs --tail 100 caddy
docker logs --tail 100 marzban
docker logs --tail 100 remnawave
docker logs --tail 100 sub-store
docker logs --tail 100 sillytavern
```

公网入口验证：

```bash
curl -vk https://silly.example.com/
curl -vk https://marzban.example.com/<RANDOM_DASHBOARD_PATH>/
curl -vk https://remnawave.example.com/
curl -vk https://sub.example.com/
curl -vk https://sub.example.com/mihomo
```

本机上游验证：

```bash
curl -sS -o /dev/null -w 'marzban %{http_code} %{content_type}\n' http://127.0.0.1:8000/<RANDOM_DASHBOARD_PATH>/
curl -sS -D- http://127.0.0.1:3011/health
curl -sS -o /dev/null -w 'sub frontend %{http_code} %{content_type}\n' http://127.0.0.1:3001/
curl -sS -o /dev/null -w 'sub backend %{http_code} %{content_type}\n' http://127.0.0.1:3002/
curl -sS -o /dev/null -w 'silly %{http_code}\n' http://127.0.0.1:7123/
curl -sS -o /dev/null -w 's-ui sub %{http_code}\n' http://127.0.0.1:2096/sub/<SUB_PATH>
```

### 服务排查入口

| 问题 | 文档 |
|---|---|
| 502、证书申请失败、Caddy reload 不生效 | [services/caddy.md](./services/caddy.md#排查) |
| s-ui 面板、订阅、节点、VLESS/Reality | [services/s-ui.md](./services/s-ui.md#排查) |
| Marzban 面板、入站、订阅 | [services/marzban.md](./services/marzban.md#排查) |
| Remnawave Panel、健康检查、Node 连接 | [services/remnawave.md](./services/remnawave.md#排查) |
| Sub-Store `/mihomo`、下载为空、格式错误 | [services/sub-store.md](./services/sub-store.md#排查) |
| SillyTavern 502、unauthorized、API、容器出站 | [services/sillytavern.md](./services/sillytavern.md#排查) |

## 9. 修改前备份习惯

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

Marzban：

```bash
mkdir -p /opt/marzban/backup
tar czf /opt/marzban/backup/marzban-before-change-$(date +%Y%m%d-%H%M%S).tgz \
  -C /opt/marzban \
  docker-compose.yml .env data config
```

Remnawave：

```bash
mkdir -p /opt/remnawave/backup
tar czf /opt/remnawave/backup/remnawave-before-change-$(date +%Y%m%d-%H%M%S).tgz \
  -C /opt/remnawave \
  docker-compose.yml .env data config etc
```

iptables：

```bash
iptables-save > /root/iptables-before-change-$(date +%Y%m%d-%H%M%S).rules
```
