# 服务器部署清单

> 更新时间：2026-07-02T13:09:10Z  
> 来源：对 `kr`、`tw`、`hk`、`hk2`、`vn` 五个 SSH alias 做状态采集，包括 `hostname`、`/etc/os-release`、`docker ps`、`ss -lntup`、`systemctl is-active`、`/opt` 目录和 compose 文件路径。  
> 记录原则：本文只记录服务器 alias、服务、目录、容器名和端口用途；不要记录真实 IP、真实域名、token、密码、API key、订阅地址或 Remnawave Node `SECRET_KEY`。

## 总览

| 服务器 | Hostname | OS | 角色 | 当前主要服务 |
|---|---|---|---|---|
| `kr` | `VM-0-10-ubuntu` | Ubuntu 24.04 | 主控/多服务服务器 | Caddy、Remnawave Panel、Remnawave Node、Marzban、s-ui、Sub-Store、SillyTavern、sub2api、new-api/cli-proxy-api 等 |
| `tw` | `taiwan` | Ubuntu 24.04 | 台湾节点/辅助服务 | Remnawave Node、Hiddify Manager、sub2api、Caddy、cloudflared、Tailscale |
| `hk` | `hongkong` | Ubuntu 20.04 | 香港节点 | Remnawave Node |
| `hk2` | `hongkong-annual` | Ubuntu 24.04 | 香港节点 | Remnawave Node |
| `vn` | `C20260320147399` | Ubuntu 24.04 | 越南节点/既有 s-ui 服务器 | Remnawave Node、s-ui、nginx |

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
| Remnawave Panel | `/opt/remnawave` | Docker 容器 `remnawave`、`remnawave-db`、`remnawave-redis` | `127.0.0.1:3010->3000`、`127.0.0.1:3011->3001` |
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| Marzban | `/opt/marzban` | Docker 容器 `marzban` | `127.0.0.1:8000` 面板上游；另有 Xray 本地端口如 `127.0.0.1:26513`、`127.0.0.1:61080` |
| Marzban Node | `/opt/marzban-node.uninstalled-20260630-144713` | Docker 容器 `nifty_clarke`，镜像 `gozargah/marzban-node:latest` | 当前仍在运行，需确认是否保留 |
| s-ui | `/usr/local/s-ui` | systemd 服务 `s-ui` | `*:2095` 面板、`*:2096` 订阅、`*:32676` 节点入站 |
| Sub-Store | `/opt/substore` | Docker 容器 `sub-store` | `127.0.0.1:3001`、`127.0.0.1:3002` |
| SillyTavern | `/opt/SillyTavern` | Docker 容器 `sillytavern` | `127.0.0.1:7123->8000` |
| conviction-trade | `/opt/conviction-trade` | Docker 容器 `conviction-trade` | `127.0.0.1:3000` |
| sub2api | `/opt/sub2api` | compose 文件存在；进程 `sub2api` 正在监听 | `*:8080` |
| cli-proxy-api | `/opt/cli-proxy-api` | 进程 `cli-proxy-api` | `*:8317` |
| new-api | `/opt/new-api` | compose 文件存在 | 本次采集未见运行容器，变更前先确认 |

### 注意事项

- `kr` 是当前 Remnawave Panel 所在机器，也是一个 Remnawave Node。Panel 访问同机 Node 时不要在面板里填 `127.0.0.1`，应使用 Docker 网关或宿主机可达地址。
- `*:2222` 是 Remnawave Node 控制 API，不是用户代理端口。需要确认 iptables、云防火墙或安全组只允许 Panel 控制链路访问。
- Remnawave Panel 容器网段到远程 Node 控制口走 Docker FORWARD 白名单；新增远程 Node 时需要同步增加对应出站和回包规则。
- 同机同时存在 s-ui、Marzban、Remnawave Node 和历史 Marzban Node，新增代理入站前必须先查 `ss -lntup`，避免端口冲突。

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

### 注意事项

- 当前看起来是纯 Remnawave Node 服务器，没有 Caddy 公网入口。
- `*:2222` 是 Remnawave Node 控制 API，需要确认只允许 Remnawave Panel 控制链路访问。
- `/opt/komari`、`/opt/s-ui-backup` 目录存在，但本次采集未见对应运行容器。

## `hk2`

### 基础状态

- Docker：`active`
- Caddy：`inactive`
- Tailscale：`inactive`
- cloudflared：`inactive`

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`*:443` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |

### 注意事项

- `443/tcp` 当前由 Remnawave Node 的 `rw-core` 监听；如果以后要在这台机器上部署 Caddy 或其他 HTTPS 入口，需要先调整入站端口或准备独立 IP/分流方案。
- `*:2222` 是 Remnawave Node 控制 API，需要确认只允许 Remnawave Panel 控制链路访问。

## `vn`

### 基础状态

- Docker：`active`
- nginx：`active`
- `s-ui` systemd：`active`

### 已部署服务

| 服务 | 部署目录 | 运行形态 | 监听/暴露 |
|---|---|---|---|
| Remnawave Node | `/opt/remnawave-node` | Docker 容器 `remnawave-node`，`network_mode: host` | `*:2222` 控制 API、`*:25080` 代理入站、`127.0.0.1:61081` 本地占位/内部端口 |
| s-ui | `/usr/local/s-ui` | systemd 服务 `s-ui` | `*:2095` 面板、`*:2096` 订阅、`*:18841` 节点入站 |
| nginx | 系统包/默认路径 | systemd 服务 `nginx` | `*:80` |
| SSH | systemd/socket | `sshd` | `*:22958` |

### 注意事项

- `vn` 的 Remnawave Node 已接入 `kr` 的 Remnawave Panel，面板 Host 使用 `VLESS-Reality-25080` 入站，端口为 `25080`，SNI 为占位伪装域名。
- `2222/tcp` 是 Remnawave Node 控制 API；当前系统 iptables 只允许本机回环和 `kr` Panel 出口访问，并对其他来源 drop。规则是否重启后仍存在取决于服务器防火墙持久化方式，云安全组也要保持一致。
- `vn` 原有 nginx 与 s-ui 仍在运行，后续新增代理入站前先查 `ss -lntup`，避免与 `80`、`2095`、`2096`、`18841`、`25080` 冲突。

## 通用运维规则

- 修改任何线上配置前，先按服务文档备份对应目录、数据库或防火墙规则。
- Remnawave Node 的 `NODE_PORT` 默认是 `2222`，它是 Panel 控制 Node 的 API 端口，不是用户代理端口；不要把它当作订阅里的节点端口。
- 新增 Remnawave Node 或调整入站时，先看 [services/remnawave.md](./services/remnawave.md) 的「部署 Remnawave Node」章节。
- 新增 Caddy 站点或变更反代时，先看 [services/caddy.md](./services/caddy.md)，并在 reload 前执行 Caddyfile 校验。
- 排障按链路逐层检查：DNS/防火墙 -> Caddy/入口 -> 本机端口 -> Docker 或 systemd 服务 -> 应用配置。

## 只读刷新命令

```bash
for host in kr tw hk hk2 vn; do
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
