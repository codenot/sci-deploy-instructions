# 服务器部署清单

> 更新时间：2026-07-20T03:05:00Z
> 来源：对 `kr`、`tw`、`hk`、`hk2`、`vn`、`us` 六个 SSH alias 做状态采集，并补充 `gz` 的 Tailscale DERP 部署结果、`hk2` 的 Headscale/Tailscale 部署结果、`kr`/`gz` 切换到自建 Headscale 的结果、`hk2` Headscale 发布 `gz` 自建 DERP 的结果，以及 `kr` 的 Miaomiaowu、grok2api 和 Docker 转发策略调整结果；记录包括 `hostname`、`/etc/os-release`、`docker ps`、`ss -lntup`、`systemctl is-active`、`/opt` 目录和 compose 文件路径。
> 记录原则：本文只记录服务器 alias、服务、目录、容器名和端口用途；不要记录真实 IP、真实域名、token、密码、API key、订阅地址或 Remnawave Node `SECRET_KEY`。

## 总览

| 服务器 | Hostname | OS | 角色 | 当前主要服务 |
|---|---|---|---|---|
| `kr` | `VM-0-10-ubuntu` | Ubuntu 24.04 | 主控/多服务服务器 | Caddy、Komari Server、Remnawave Panel、Remnawave Node、Marzban、s-ui、Sub-Store、SillyTavern、Miaomiaowu、grok2api、Tailscale、sub2api、new-api/cli-proxy-api 等 |
| `tw` | `taiwan` | Ubuntu 24.04 | 台湾节点/辅助服务 | Remnawave Node、Hiddify Manager、sub2api、Caddy、cloudflared、Tailscale |
| `hk` | `serqdqtb8vzj60u` | Ubuntu 20.04 | 香港节点 | Remnawave Node、Komari Agent |
| `hk2` | `hongkong-annual` | Ubuntu 24.04 | 香港节点/Headscale 控制面 | Remnawave Node、Headscale、Caddy、Tailscale |
| `vn` | `C20260320147399` | Ubuntu 24.04 | 越南节点 | Remnawave Node、nginx |
| `us` | `racknerd-48395a9` | Ubuntu 24.04 | 美国节点 | Remnawave Node、Komari Agent |
| `gz` | `guangzhou` | Ubuntu 24.04 | 广州辅助服务/Tailscale relay | Caddy、Tailscale、Tailscale DERP、RustDesk、Komari Agent |

## `kr`

### 基础状态

- Docker：`active`
- Tailscale：`active`
- `s-ui` systemd：`active`
- Caddy systemd：已卸载，`caddy.service` 为 `not-found`；Docker 容器 `caddy` 正在运行，运维时以容器状态和 `/opt/caddy` 配置为准。

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Caddy | `/opt/caddy` | Docker 容器 `caddy` | `*:80`、`*:443`、`127.0.0.1:2019` |
| Komari Server | `/opt/komari` | Docker 容器 `komari`；Caddy HTTPS 反代 | `127.0.0.1:25774->25774` |
| Komari Agent | `/opt/komari-agent` | systemd 服务 `komari-agent` | 主动连接本机 Komari HTTPS 入口；Web SSH 已禁用 |
| Remnawave Panel | `/opt/remnawave` | Docker 容器 `remnawave`、`remnawave-db`、`remnawave-redis` | `127.0.0.1:3010->3000`、`127.0.0.1:3011->3001` |
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| Marzban | `/opt/marzban` | Docker 容器 `marzban` | `127.0.0.1:8000` 面板上游；另有 Xray 本地端口如 `127.0.0.1:26513`、`127.0.0.1:61080` |
| Marzban Node | `/opt/marzban-node.uninstalled-20260630-144713` | Docker 容器 `nifty_clarke`，镜像 `gozargah/marzban-node:latest` | 当前仍在运行，需确认是否保留 |
| s-ui | `/usr/local/s-ui` | systemd 服务 `s-ui` | `*:2095` 面板、`*:2096` 订阅、`*:32676` 节点入站 |
| Sub-Store | `/opt/substore` | Docker 容器 `sub-store` | `127.0.0.1:3001`、`127.0.0.1:3002` |
| SillyTavern | `/opt/SillyTavern` | Docker 容器 `sillytavern` | `127.0.0.1:7123->8000` |
| Miaomiaowu | `/opt/miaomiaowu` | Docker 容器 `miaomiaowu` | `127.0.0.1:8083->8080`，公网入口由 Caddy HTTPS 反代 |
| grok2api | `/opt/grok2api` | Docker 容器 `grok2api` | `127.0.0.1:8005->8000`，公网入口由 Caddy HTTPS 反代 |
| conviction-trade | `/opt/conviction-trade` | Docker 容器 `conviction-trade` | `127.0.0.1:3000` |
| sub2api | `/opt/sub2api` | compose 文件存在；进程 `sub2api` 正在监听 | `*:8080` |
| cli-proxy-api | `/opt/cli-proxy-api` | 进程 `cli-proxy-api` | `*:8317` |
| new-api | `/opt/new-api` | Docker 容器 `new-api`，`network_mode: host` | 应用端口 `*:4001`；iptables 限制非 loopback 访问；Caddy 反代 `newapi.codermb.com` |
| Tailscale | 系统包 | systemd 服务 `tailscaled` | `41641/udp`，已作为 `hk2` 自建 Headscale 的客户端接入 |

### 注意事项

- `kr` 是当前 Remnawave Panel 所在机器，也是一个 Remnawave Node。Panel 访问同机 Node 时不要在面板里填 `127.0.0.1`，应使用 Docker 网关或宿主机可达地址。
- `kr` 的 Tailscale 已从官方控制面切换到 `hk2` 自建 Headscale；客户端登录入口使用 `<HEADSCALE_DOMAIN>:<HEADSCALE_HTTPS_PORT>`，不要把真实域名或 preauth key 写入仓库。
- 当前 `kr` 到 `hk2` 的 Tailscale 数据面可经 DERP 中继连通，直连仍需继续检查两端 `41641/udp`、云安全组和 NAT 映射。
- `*:2222` 是 Remnawave Node 控制 API，不是用户代理端口。需要确认 iptables、云防火墙或安全组只允许 Panel 控制链路访问。
- Remnawave Panel 不再依靠 Docker FORWARD 目的地址白名单访问远程 Node；容器出口不按 Docker 网段或目的地址做限制。Node 控制 API 的公网入站仍需由宿主机入口防火墙和云安全组限制。
- 同机同时存在 s-ui、Marzban、Remnawave Node 和历史 Marzban Node，新增代理入站前必须先查 `ss -lntup`，避免端口冲突。
- `new-api` 原默认端口 `3000` 与 `conviction-trade` 冲突，当前通过 `--port 4001` 启动；公网访问走 Caddy `newapi.codermb.com` 反代到 `127.0.0.1:4001`，不要直接开放 `4001/tcp`。
- Miaomiaowu 的 compose、SQLite、订阅、规则模板和备份均在 `/opt/miaomiaowu`；应用端口只监听本机，Caddy 额外阻断未认证的初始化写接口。
- `kr` 当前运行 Docker Engine `28.2.2`；IPv4 `FORWARD` 运行策略和 `/etc/iptables/rules.v4` 固化策略均为 `ACCEPT`，Docker 通过 `/etc/docker/daemon.json` 的 `ip-forward-no-drop: true` 保持该策略，同时继续自动维护 NAT 和端口映射。原 `docker-forward-open.service`、Miaomiaowu 和 Remnawave 的 Docker 出口放行服务已停用并归档，不再配置容器出口白名单。
- Docker 发布端口经过 DNAT 后不一定进入宿主机 `INPUT` 链；需要公网访问控制时，应使用云安全组或统一的 `DOCKER-USER` 入口规则。面板和内部服务仍应绑定 `127.0.0.1`，不要依赖 `INPUT` 规则弥补错误的公网端口映射。
- grok2api 的 compose、配置、SQLite 数据和备份均在 `/opt/grok2api`；宿主机 `8005/tcp` 只监听 `127.0.0.1`，由 Caddy 反代，不要直接暴露公网。
- grok2api 首次启动时 `bootstrapAdmin.password` 至少需要 8 个字符；管理员创建成功后应从配置删除整个 `bootstrapAdmin` 段。`/healthz` 用于进程健康检查；尚未添加可用上游账号时 `/readyz` 返回 `503` 属于预期状态。
- grok2api 直连 Grok Console 时可能被上游 Cloudflare WAF 按数据中心出口拦截；此时应在管理端“运行设置 -> 出口代理”配置同一浏览器会话对应的代理、User-Agent 和 Cloudflare Cookie，不要继续修改 Caddy 或 Docker FORWARD。
- Komari Server 使用全新 SQLite 数据库，管理凭据和自动发现密钥只保存在 `/opt/komari` 且权限为 `0600`；当前启用 `Komari Next 1.4.18` 主题，主题文件位于 `/opt/komari/data/theme/next`，切换前备份位于 `/opt/komari/backup/20260719-171041-before-komari-next`；已为全部现有及未来节点启用北京、上海、广州三地电信/联通/移动共 9 个 ICMP 延迟任务，周期为 60 秒。

## `tw`

### 基础状态

- Docker：`active`
- Tailscale：`active`
- cloudflared：`active`
- Caddy systemd：`inactive`，但 Docker 容器 `caddy` 正在运行。

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Caddy | `/opt/caddy` | Docker 容器 `caddy` | `*:80`、`*:443`、`127.0.0.1:2019` |
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| Hiddify Manager | `/opt/hiddify-manager` | Docker 容器 `hiddify-manager`、`hiddify-mariadb`、`hiddify-redis` | `127.0.0.1:8088->80`、`127.0.0.1:8443->443` |
| sub2api | `/opt/sub2api` | Docker 容器 `sub2api_1`、`sub2api_2`、`sub2api-postgres`、`sub2api-redis` | `0.0.0.0:8081->8080`、`0.0.0.0:8082->8080` |
| cloudflared | systemd 服务 | 进程 `cloudflared` | `127.0.0.1:20241` 及若干 UDP 出站/隧道端口 |
| Komari Agent | `/opt/komari-agent` | systemd 服务 `komari-agent` | 主动连接 `kr` Komari HTTPS 入口；Web SSH 已禁用 |

### 注意事项

- `*:2222` 是 Remnawave Node 控制 API，需要确认只允许 Remnawave Panel 控制链路访问。
- `sub2api` 的 `8081`、`8082` 当前绑定 `0.0.0.0`，如果不是刻意公网提供，需要收紧到本机或反代入口。
- `/opt/hiddify`、`/opt/s-ui-backup`、`/opt/komari` 目录存在，但本次采集未见对应运行容器；变更前先确认用途。

## `hk`

### 基础状态

- Docker：`active`
- Caddy：`inactive`
- Tailscale：`inactive`
- cloudflared：`inactive`

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| Komari Agent | `/opt/komari-agent` | systemd 服务 `komari-agent` | 主动连接 `kr` Komari HTTPS 入口；Web SSH 已禁用 |
| Ookla Speedtest CLI | `/usr/local/bin/speedtest` | 官方静态 CLI `1.2.0.84` | 按需执行网络测速，不常驻监听端口 |

### 注意事项

- 当前看起来是纯 Remnawave Node 服务器，没有 Caddy 公网入口。
- `*:2222` 是 Remnawave Node 控制 API，需要确认只允许 Remnawave Panel 控制链路访问。
- `/opt/komari`、`/opt/s-ui-backup` 目录存在，但本次采集未见对应运行容器。

## `hk2`

### 基础状态

- Docker：`active`
- Tailscale：`active`
- Caddy systemd：`inactive`；Docker 容器 `caddy` 正在运行，运维时以容器状态和 `/opt/caddy` 配置为准。
- cloudflared：`inactive`

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`*:443` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| Headscale | `/opt/headscale` | Docker 容器 `headscale` | `127.0.0.1:8080->8080` 控制面上游、`127.0.0.1:9090->9090` metrics/debug |
| Caddy | `/opt/caddy` | Docker 容器 `caddy`，`network_mode: host` | `*:80`、`*:8443`、`127.0.0.1:2019`；反代 Headscale，上游 `127.0.0.1:8080` |
| Tailscale | 系统包 | systemd 服务 `tailscaled` | `41641/udp`，已作为 Headscale 节点接入 |
| Headscale DERP map | `/opt/headscale/config/derp-gz.yaml` | Headscale 本地 DERP map 文件 | 发布 `gz` 自建 DERP region，公网 DERP `443/tcp`、STUN `3478/udp` |
| Komari Agent | `/opt/komari-agent` | systemd 服务 `komari-agent` | 主动连接 `kr` Komari HTTPS 入口；Web SSH 已禁用 |

### 注意事项

- `443/tcp` 当前由 Remnawave Node 的 `rw-core` 监听；Caddy 没有占用 `443/tcp`，Headscale 公网 HTTPS 入口使用独立端口 `<HEADSCALE_HTTPS_PORT>`。
- Headscale 的真实域名、auth key、preauth key 和 tailnet 私有信息不要写入仓库；这里只记录占位符和端口用途。
- `hk2` 自身已作为 Headscale/Tailscale 节点接入，客户端接入时使用 `<HEADSCALE_DOMAIN>:<HEADSCALE_HTTPS_PORT>`。
- Headscale 已通过 `derp.paths` 加载 `gz` 自建 DERP map；真实 `<GZ_DERP_DOMAIN>` 不写入仓库，客户端应能在 `tailscale netcheck` 中看到 `gz`/`Guangzhou DERP` region。
- `*:2222` 是 Remnawave Node 控制 API，需要确认只允许 Remnawave Panel 控制链路访问。

## `vn`

### 基础状态

- Docker：`active`
- nginx：`active`
- `s-ui`：已于 2026-07-14 卸载

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| nginx | 系统包/默认路径 | systemd 服务 `nginx` | `*:80` |
| SSH | systemd/socket | `sshd` | `*:22958` |
| Komari Agent | `/opt/komari-agent` | systemd 服务 `komari-agent` | 主动连接 `kr` Komari HTTPS 入口；Web SSH 已禁用 |

### 注意事项

- `vn` 的 Remnawave Node 已接入 `kr` 的 Remnawave Panel，面板 Host 使用 `VLESS-Reality-25080` 入站，端口为 `25080`，SNI 为占位伪装域名。
- `2222/tcp` 是 Remnawave Node 控制 API；当前系统 iptables 只允许本机回环和 `kr` Panel 出口访问，并对其他来源 drop。规则是否重启后仍存在取决于服务器防火墙持久化方式，云安全组也要保持一致。
- s-ui 卸载前的完整安装目录、数据库和 systemd 单元已备份到 `/opt/s-ui-backup/s-ui-uninstall-20260714-124732.tgz`，对应 SHA-256 文件保存在同目录。
- s-ui 原使用的 `2095/tcp`、`2096/tcp` 和 `18841/tcp` 已停止监听；后续新增代理入站前仍需先查 `ss -lntup`，避免与 nginx `80/tcp` 和 Remnawave Node `25080/tcp` 冲突。

## `us`

### 基础状态

- Docker：`active`，Engine `29.6.2`。
- Tailscale：未部署。
- TCP 拥塞控制：`bbr`；默认 qdisc：`fq`。
- IPv4 `OUTPUT` 和 `FORWARD` 均为 `ACCEPT`；Docker 使用 `ip-forward-no-drop: true`，不设置服务级或目的地址级出口限制。

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| Komari Agent | `/opt/komari-agent` | systemd 服务 `komari-agent` | 主动连接 `kr` Komari HTTPS 入口；Web SSH 已禁用 |

### 注意事项

- Remnawave Panel 中节点名称为 `us-node`，关联 `Default-Profile` 的 `Shadowsocks` 和 `VLESS-Reality-25080` 入站；订阅 Host 为 `美国 - RackNerd`，绑定 `VLESS-Reality-25080`；Komari 中节点名称为 `us`。
- `2222/tcp` 由 `remnawave-node-firewall.service` 在宿主机 `INPUT` 限制为只允许 `kr` Panel 固定出口访问；IPv6 对该端口直接拒绝。云安全组也应保持相同入口策略。
- `25080/tcp` 是正式 VLESS/Reality 代理入站，需要在云安全组中开放；`61081` 仅监听 `127.0.0.1`。
- 防火墙只管理入口；不要给 `us` 添加 `OUTPUT`、容器网段、Docker 网桥或远端目的地址出口白名单。

## `gz`

### 基础状态

- Docker：`active`
- Tailscale：`active`
- Caddy systemd：`inactive`；Docker 容器 `caddy` 正在运行，运维时以容器状态和 `/opt/caddy` 配置为准。
- Tailscale DERP systemd：`active`

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Caddy | `/opt/caddy` | Docker 容器 `caddy`，`network_mode: host` | 绑定服务器内网地址的 `80/tcp`、`443/tcp`，`127.0.0.1:2019` |
| Tailscale DERP | `/opt/tailscale-derp` | systemd 服务 `tailscale-derp`，二进制 `/opt/tailscale-derp/bin/derper` | 公网入口由 Caddy `443/tcp` TLS 反代；上游 `33443/tcp` 仅允许本机访问；STUN `3478/udp` |
| Tailscale | 系统包 | systemd 服务 `tailscaled` | `41641/udp`，已作为 `hk2` 自建 Headscale 的客户端接入 |
| RustDesk Server | `/opt/rustdesk-server` | Docker 容器 `hbbs`、`hbbr` | `21115`、`21116`、`21117`、`21118`、`21119` 等 RustDesk 端口 |
| Komari Agent | `/opt/komari-agent` | systemd 服务 `komari-agent` | 主动连接 `kr` Komari HTTPS 入口；Web SSH 已禁用 |

### 注意事项

- DERP 域名、tailnet policy、节点私钥和上游自签私钥不要写入仓库；配置方法见 [services/tailscale-derp.md](./services/tailscale-derp.md)。
- `gz` 的 Tailscale 已从官方控制面切换到 `hk2` 自建 Headscale；客户端登录入口使用 `<HEADSCALE_DOMAIN>:<HEADSCALE_HTTPS_PORT>`，不要把真实域名或 preauth key 写入仓库。
- `gz` 自建 DERP 已发布到 `hk2` Headscale 的 DERP map；客户端优先通过 `gz` DERP relay 中继时，继续保持上游 `33443/tcp` 不直接暴露公网。
- Caddy 到 derper 的上游是 TLS：`https://127.0.0.1:33443`，并强制 `transport http { versions 1.1 }` 保留 `Upgrade: DERP`。
- `router.codenot.cc` 由 `gz` Caddy 反代到 Tailscale 节点 `100.64.0.2:3000`；`gz` 到上游路由走 `tailscale0`。
- `33443/tcp` 由 derper 监听全接口以便同时提供公网 STUN，但系统 iptables 在 `INPUT` 顶部 drop 非本机访问，防止公网绕过 Caddy 直连上游。
- `3478/udp` 服务端已监听并且本机 Tailscale 风格 STUN 请求可用；如公网 STUN 不通，优先检查云安全组或外层防火墙是否放行 `3478/udp`。
- Caddy 现有站点使用 `bind <PRIVATE_IP>` 风格；新增站点时不要随意改成全接口监听，避免影响既有入口。
- 原 Komari Server 容器、镜像、`/opt/komari` SQLite 数据和 `25774/tcp` 公网监听已于 2026-07-18 完整删除；当前只保留 Agent。

## 通用运维规则

- `kr`、`tw`、`hk`、`hk2`、`vn`、`us`、`gz` 已启用 TCP BBR，运行基线为 `net.ipv4.tcp_congestion_control=bbr` 和 `net.core.default_qdisc=fq`；除已有配置的 `kr` 外，其余节点使用 `/etc/sysctl.d/99-bbr.conf` 和 `/etc/modules-load.d/bbr.conf` 持久化。
- 修改任何线上配置前，先按服务文档备份对应目录、数据库或防火墙规则。
- Remnawave Node 的 `NODE_PORT` 默认是 `2222`，它是 Panel 控制 Node 的 API 端口，不是用户代理端口；不要把它当作订阅里的节点端口。
- 新增 Remnawave Node 或调整入站时，先看 [services/remnawave.md](./services/remnawave.md) 的「部署 Remnawave Node」章节。
- 新增 Caddy 站点或变更反代时，先看 [services/caddy.md](./services/caddy.md)，并在 reload 前执行 Caddyfile 校验。
- 新增或排查 Tailscale DERP relay 时，先看 [services/tailscale-derp.md](./services/tailscale-derp.md)。
- 排障按链路逐层检查：DNS/防火墙 -> Caddy/入口 -> 本机端口 -> Docker 或 systemd 服务 -> 应用配置。

## 只读刷新命令

```bash
for host in kr tw hk hk2 vn us gz; do
  printf "\n### %s\n" "$host"
  ssh "$host" '
    hostname
    . /etc/os-release 2>/dev/null && printf "%s %s\n" "$NAME" "$VERSION_ID"
    docker ps --format "{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}" 2>/dev/null || true
    ss -lntup 2>/dev/null | sed -n "1,160p"
    find /opt -maxdepth 3 \( -name docker-compose.yml -o -name compose.yml -o -name compose.yaml \) -print 2>/dev/null | sort
  '
done
```
