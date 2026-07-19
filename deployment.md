# 部署总手册

> 目标：记录新服务器部署时的基础 Docker 环境、全局约定、通用验证和排查入口。按需选择服务部署；具体服务步骤在 `services/` 下对应文件里。

文档中的域名、端口、路径、token、密码都用占位符表示，部署时按实际情况替换。不要把真实密钥、真实订阅地址、Reality private key 写进仓库。

## 1. 文档入口

按任务进入对应文档：

| 任务                                      | 文档                                                      |
| ----------------------------------------- | --------------------------------------------------------- |
| 基础 Docker、目录、域名、端口、防火墙约定 | 本文件                                                    |
| Caddy 公网 HTTPS 入口                     | [services/caddy.md](./services/caddy.md)                   |
| s-ui 面板、订阅、VLESS/Reality 入站       | [services/s-ui.md](./services/s-ui.md)                     |
| Marzban 面板、管理员、Xray 入站           | [services/marzban.md](./services/marzban.md)               |
| Remnawave Panel、数据库、节点接入入口     | [services/remnawave.md](./services/remnawave.md)           |
| Sub-Store 订阅聚合和`/mihomo` 文件      | [services/sub-store.md](./services/sub-store.md)           |
| SillyTavern 反代、白名单、API 设置        | [services/sillytavern.md](./services/sillytavern.md)       |
| Tailscale DERP 自管 relay                 | [services/tailscale-derp.md](./services/tailscale-derp.md) |
| 通用链路排查、基础状态采集                | 本文件                                                    |

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
/opt/tailscale-derp
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

| 服务                |          内部端口 |                         宿主机监听 | 说明                                     |
| ------------------- | ----------------: | ---------------------------------: | ---------------------------------------- |
| Caddy               |            80/443 |                             80/443 | 公网 HTTPS 入口                          |
| s-ui 面板           |              2095 |                               2095 | 建议限制来源 IP 或只在需要时开放         |
| s-ui 订阅           |              2096 |                               2096 | 给 Sub-Store 读取                        |
| s-ui 入站           |             32676 |                              32676 | 示例 VLESS/Reality 入站端口              |
| Marzban 面板        |              8000 |                     127.0.0.1:8000 | 只给 Caddy 反代                          |
| Marzban 入站        |        按面板配置 |                         按面板配置 | 例如 VLESS/Reality 节点端口              |
| Remnawave Panel     |              3000 |                     127.0.0.1:3010 | 只给 Caddy 反代                          |
| Remnawave Metrics   |              3001 |                     127.0.0.1:3011 | 只给本机健康检查或监控                   |
| Remnawave Node API  |              2222 | 只允许 Panel IP 或 Docker 网络访问 | Node 控制 API，不是用户代理端口          |
| Remnawave Node 入站 | 按 Config Profile |                             按配置 | 例如 VLESS/Reality 节点端口              |
| Sub-Store 前端      |              3001 |                     127.0.0.1:3001 | 只给 Caddy 反代                          |
| Sub-Store 后端      |              3002 |                     127.0.0.1:3002 | 文件/API 下载                            |
| SillyTavern         |              8000 |                     127.0.0.1:7123 | 只给 Caddy 反代                          |
| Tailscale DERP      |             33443 |              只允许本机 Caddy 访问 | DERP HTTPS 上游；公网走 Caddy`443/tcp` |
| Tailscale DERP STUN |          3478/udp |                           3478/udp | 需要云安全组和系统防火墙放行             |

如果把 s-ui Reality 入站放到 `443/tcp`，同一台机器同一个公网 IP 上 Caddy 就不能同时监听 `443/tcp`。除非有独立 IP 或明确的流量分流方案，否则按上表把 Caddy 和 s-ui 入站分开。

同机同时运行 Marzban Master 和 Marzban Node 会启动两个 Xray 实例，容易出现入站端口冲突。单机部署优先直接使用 Marzban Master 入站；多地区服务器再单独部署 Marzban Node。

Remnawave Panel 本身不跑 Xray-core；节点代理流量需要单独部署 Remnawave Node，并在面板里通过 Config Profile、Host、Internal Squad 关联。

Remnawave Node 的 `NODE_PORT` 是 Panel 调用 Node 的控制 API，不是给用户连接的代理端口。这个端口不要直接开放公网；这是 Node 的入口限制，不是 Panel 容器的出口限制。Node 使用 host 网络时在 `INPUT` 控制来源，Node 通过 Docker 发布端口时在 `DOCKER-USER` 或云安全组控制来源；用户代理端口按 Config Profile 的入站单独开放。

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

### Docker 转发基线

本仓库管理的服务器默认不对 Docker bridge 出口设置服务级、网段级或目的地址级白名单。Docker 继续自动维护 bridge、NAT、端口映射和网络隔离，宿主机 IPv4 `FORWARD` 基线使用 `ACCEPT`，入口访问控制放在云安全组、服务监听地址或统一的入口防火墙。

这套基线的硬前置条件是 Docker Engine `>= 28.0.0`。Docker 28 加强了 localhost 发布端口和未发布容器端口的 direct-routing 防护；旧版本先升级并完成回归验证，不要直接把全局 `FORWARD` 改成 `ACCEPT`。版本差异见 [Docker 端口发布文档](https://docs.docker.com/engine/network/port-publishing/) 和 [Docker Engine 28 release notes](https://docs.docker.com/engine/release-notes/28/)。

不要把 Docker 的 `iptables` 功能设置为 `false`。这会关闭 Docker 自动生成的网络规则，导致默认 bridge 的 NAT、端口映射或网络隔离失效。

Docker 28 及以上在 `/etc/docker/daemon.json` 使用：

```json
{
  "ip-forward-no-drop": true
}
```

如果 `daemon.json` 已存在，必须把字段合并进现有 JSON，不要覆盖原有配置。修改前备份当前规则和配置：

```bash
BACKUP_DIR="/root/firewall-backup/$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$BACKUP_DIR"
iptables-save > "$BACKUP_DIR/iptables-before-docker-forward.rules"
cp -a /etc/docker/daemon.json "$BACKUP_DIR/daemon.json.before" 2>/dev/null || true
systemctl list-unit-files --type=service > "$BACKUP_DIR/systemd-units.before"
```

先校验 Docker 配置和现有规则，不要一上来只改 policy：

```bash
docker version --format '{{.Server.Version}}'
dockerd --validate --config-file=/etc/docker/daemon.json
iptables -S FORWARD
iptables -S DOCKER-USER
systemctl list-unit-files --type=service | grep -Ei 'docker|forward|firewall|iptables|netfilter'
```

先停用并归档确认属于旧 Docker 出口白名单的 systemd 单元，再精确删除 `FORWARD` 或 `DOCKER-USER` 中的旧出口 `DROP`。不要使用 `iptables -F`，不要清空或手工改写 Docker 自动维护的 `DOCKER*` 链。完成审计和清理后再执行：

```bash
iptables -P FORWARD ACCEPT
```

`iptables -P FORWARD ACCEPT` 立即修改运行时 policy，但不能覆盖链里更早匹配的 `DROP`；`ip-forward-no-drop` 在 Docker daemon 下次启动时阻止 Docker 再把 policy 改为 `DROP`。生产服务器写入配置后可以先保持现有 daemon 运行，在计划维护窗口再重启 Docker；重启前先记录所有容器的 restart policy，避免 `restart: no` 的容器停机后未自动恢复。

Debian/Ubuntu 如果启用了 `netfilter-persistent`，确认 `/etc/iptables/rules.v4` 中的基线为：

```text
:FORWARD ACCEPT [0:0]
```

不要在 Docker 运行期间直接把包含 `DOCKER`、`DOCKER-FORWARD`、`DOCKER-CT` 等动态链的完整规则集固化到 `rules.v4`。静态配置只保存宿主机基线，让 Docker 在 daemon 启动时重建自己的链。确认 `netfilter-persistent.service` 在 `docker.service` 之前加载；Docker 运行期间禁止执行 `netfilter-persistent reload` 或手工 `iptables-restore`，否则可能清掉 Docker 的动态 filter/NAT 链。确需 reload 时必须安排维护窗口，reload 后受控重启 Docker，并完整验证容器、端口映射和出网。

```bash
systemctl show netfilter-persistent.service docker.service -p Id -p Before -p After
```

不要为单个 `br-*`、Docker 子网、容器服务或远端目的地址创建出口放行规则，也不要为此创建 systemd oneshot。如果容器出网失败而宿主机正常，先检查并恢复全局基线：

```bash
docker version --format '{{.Server.Version}}'
dockerd --help | grep ip-forward-no-drop
sysctl net.ipv4.ip_forward
iptables -S FORWARD
iptables -S DOCKER-USER
grep '^:FORWARD ' /etc/iptables/rules.v4 2>/dev/null
dockerd --validate --config-file=/etc/docker/daemon.json
docker exec <CONTAINER> curl -I --max-time 10 https://example.com/
```

如果启用了 Docker IPv6，还必须单独检查 IPv6 转发、`ip6tables` 和外层 IPv6 防火墙；不能因为 IPv4 已放通就默认 IPv6 策略正确。

## 6. 防火墙

防火墙策略统一放在最外层：云服务器优先使用云安全组控制公网端口；宿主机或 `network_mode: host` 服务使用 `INPUT`；Docker 发布端口需要依赖云安全组、监听地址，或在确有需要时使用一套统一的 `DOCKER-USER` 入口规则。

Docker 发布到 `0.0.0.0` 的端口经过 DNAT 后不一定进入宿主机 `INPUT` 链，因此不能只配置 `INPUT` 就认为容器端口已受保护。面板、数据库、metrics 和内部 API 优先绑定 `127.0.0.1`，由 Caddy 反代；不要用容器出口限制弥补错误的公网端口映射。

至少放行：

```text
80/tcp
443/tcp
s-ui 入站端口，例如 32676/tcp
Marzban 或其他节点入站端口，按面板配置开放
Tailscale DERP STUN 端口，例如 3478/udp
```

不建议直接公网暴露：

```text
Marzban 面板端口 8000
Remnawave Panel 3010
Remnawave Metrics 3011
Sub-Store 3001/3002
SillyTavern 7123
Tailscale DERP 上游端口 33443
```

这些服务推荐只监听 `127.0.0.1`，由 Caddy 反代对外提供 HTTPS。

## 通用排查

先判断问题在哪一层

```text
DNS / 安全组 / 防火墙
  -> Caddy / 公网 HTTPS
  -> 本机端口监听
  -> Docker 或 systemd 服务
  -> 应用配置
  -> 客户端配置
```

不要同时改 Caddy、容器、面板和客户端，否则很难知道是哪一步修好的。

### 服务排查入口

| 问题                                                | 文档                                                           |
| --------------------------------------------------- | -------------------------------------------------------------- |
| 502、证书申请失败、Caddy reload 不生效              | [services/caddy.md](./services/caddy.md#排查)                   |
| s-ui 面板、订阅、节点、VLESS/Reality                | [services/s-ui.md](./services/s-ui.md#排查)                     |
| Marzban 面板、入站、订阅                            | [services/marzban.md](./services/marzban.md#排查)               |
| Remnawave Panel、健康检查、Node 连接                | [services/remnawave.md](./services/remnawave.md#排查)           |
| Sub-Store`/mihomo`、下载为空、格式错误            | [services/sub-store.md](./services/sub-store.md#排查)           |
| SillyTavern 502、unauthorized、API、容器出站        | [services/sillytavern.md](./services/sillytavern.md#排查)       |
| Tailscale DERP`/derp/probe`、协议升级或 STUN 不通 | [services/tailscale-derp.md](./services/tailscale-derp.md#排查) |
