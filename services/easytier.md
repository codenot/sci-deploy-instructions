# EasyTier

> 目标：部署 EasyTier 私有网络的种子/中转节点或自建 config-server，并让其他服务器加入同一网络。基础目录、防火墙和修改前备份约定见 [deployment.md](../deployment.md)。

网络名称、共享密钥、私有模式、种子节点、Relay、config-server、DHCP 和 QUIC 代理之间的关系见 [EasyTier 核心概念与权限模型](./easytier-concepts.md)。

真实网络密码、服务器公网地址和节点身份不要提交到仓库。运行目录统一使用 `/opt/easytier`。

## 本机 GUI 配置归档

2026-08-13 从本机 EasyTier GUI v2.6.4 导出的配置已脱敏保存为：

- [gui-export.redacted.conf.example](../examples/easytier/gui-export.redacted.conf.example)

导出配置包含以下设置：

- 网络名称为 `easytier`。
- DHCP 自动分配虚拟 IPv4。
- 监听 `11010/tcp`、`11010/udp` 和 WireGuard `11011/udp`。
- 启用 QUIC 代理、延迟优先和私有模式。

原始导出中的网络密码为空。部署服务器前必须生成强密码，并在本机 GUI 和所有服务器上设置相同的网络名称与密码。实例 UUID 属于单个节点，已从模板删除，不能复制到其他节点。

## 模板选择

| 机器角色 | 模板 | 说明 |
|---|---|---|
| 公网种子节点 | [seed.conf.example](../examples/easytier/seed.conf.example) | 监听公网 `11010/tcp` 和 `11010/udp`，不依赖其他节点 |
| 普通服务器 | [peer.conf.example](../examples/easytier/peer.conf.example) | 通过 `ET_SEED_HOST` 连接种子节点 |
| 每台服务器的变量 | [server.env.example](../examples/easytier/server.env.example) | 网络密码只放在服务器，节点名称和虚拟 IP 每台不同 |

模板保留了 GUI 的主要网络行为，但服务器默认不开放 WireGuard `11011/udp`。只有确实需要让原生 WireGuard 客户端接入时才单独配置并放行该端口。

## 安装

Ubuntu/Debian 服务器执行：

```bash
apt update
apt install -y ca-certificates curl unzip openssl

curl -fsSL \
  https://raw.githubusercontent.com/EasyTier/EasyTier/main/script/install.sh \
  | bash -s install /opt --no-gh-proxy

systemctl stop easytier@default
/opt/easytier/easytier-core --version
```

安装脚本会把程序放到 `/opt/easytier`，并创建 `easytier@.service`。如果服务器不能直接访问 GitHub，先按网络环境下载官方 release，再把 `easytier-core` 和 `easytier-cli` 放到 `/opt/easytier`。

## 配置种子节点

在本机仓库根目录将模板传到服务器，目标路径示例：

```bash
scp examples/easytier/seed.conf.example \
  root@<SEED_SERVER>:/opt/easytier/config/server.conf
scp examples/easytier/server.env.example \
  root@<SEED_SERVER>:/opt/easytier/config/server.env
```

登录种子服务器后编辑 `/opt/easytier/config/server.env`：

```dotenv
ET_NETWORK_NAME=easytier
ET_NETWORK_SECRET=<STRONG_SHARED_SECRET>
ET_INSTANCE_NAME=seed-1
ET_IPV4=10.144.144.1
ET_SEED_HOST=<SEED_PUBLIC_IP_OR_DOMAIN>
```

首次部署可以用以下命令生成密码，然后手动填入环境文件；同一个值也要填入本机 GUI 和其他服务器：

```bash
openssl rand -hex 32
chmod 600 /opt/easytier/config/server.env
chmod 600 /opt/easytier/config/server.conf
```

不要把命令生成的真实值写回本仓库。

## 配置其他服务器

普通服务器使用 `peer.conf.example`：

```bash
scp examples/easytier/peer.conf.example \
  root@<PEER_SERVER>:/opt/easytier/config/server.conf
scp examples/easytier/server.env.example \
  root@<PEER_SERVER>:/opt/easytier/config/server.env
```

每台普通服务器都使用相同的 `ET_NETWORK_NAME`、`ET_NETWORK_SECRET` 和 `ET_SEED_HOST`，但必须使用不同的节点名称和虚拟 IP：

```dotenv
ET_NETWORK_NAME=easytier
ET_NETWORK_SECRET=<SAME_STRONG_SHARED_SECRET>
ET_INSTANCE_NAME=peer-1
ET_IPV4=10.144.144.2
ET_SEED_HOST=<SEED_PUBLIC_IP_OR_DOMAIN>
```

下一台可以使用 `peer-2` 和 `10.144.144.3`。不要复制实例 UUID，也不要让两个节点使用相同虚拟 IP。

## systemd

官方 `easytier@.service` 通过实例名读取 `/opt/easytier/config/%i.conf`。为 `server` 实例增加环境文件：

```bash
install -d -m 0755 /etc/systemd/system/easytier@server.service.d
cat > /etc/systemd/system/easytier@server.service.d/environment.conf <<'EOF'
[Service]
EnvironmentFile=/opt/easytier/config/server.env
EOF
```

修改前先校验环境变量和 TOML：

```bash
set -a
. /opt/easytier/config/server.env
set +a

/opt/easytier/easytier-core --check-config \
  -c /opt/easytier/config/server.conf
```

校验通过后启动：

```bash
systemd-analyze verify /etc/systemd/system/easytier@.service
systemctl daemon-reload
systemctl disable --now easytier@default 2>/dev/null || true
systemctl enable --now easytier@server
systemctl status easytier@server --no-pager -l
```

## 防火墙

种子节点需要在云安全组和宿主机入口防火墙放行：

```text
11010/tcp
11010/udp
```

如果所有普通服务器都有固定公网 IP，优先只允许这些来源。`15888/tcp` 是本机 RPC，仅监听 `127.0.0.1`，不要开放公网。普通服务器不要求公网开放 `11010`；需要其他节点直接连接它时再按实际拓扑放行。

私有模式和网络密码负责 EasyTier 网络准入，但不能代替云安全组或系统防火墙。

## 本机 GUI 加入

本机 GUI 中保持网络名称 `easytier`，设置与服务器相同的强网络密码，并在对等节点中添加：

```text
udp://<SEED_PUBLIC_IP_OR_DOMAIN>:11010
tcp://<SEED_PUBLIC_IP_OR_DOMAIN>:11010
```

本机使用 DHCP 即可；如果改为静态虚拟 IP，不能与服务器的 `10.144.144.1`、`10.144.144.2` 等地址重复。

## 验证

服务器执行：

```bash
ss -lntup | grep 11010
/opt/easytier/easytier-cli peer
/opt/easytier/easytier-cli route
journalctl -u easytier@server -n 100 --no-pager
```

从任意已加入节点测试：

```bash
ping 10.144.144.1
ping 10.144.144.2
```

预期能看到不同的节点名称、不同的虚拟 IP，并且节点之间可以互相 ping 通。

## 自建 config-server

config-server 是节点配置、状态和日志的管理控制面，不是 peer，也不参与 P2P 发现或业务流量中转。需要 Web 集中管理时才部署；只用配置文件和 seed peer 组网时不需要它。

推荐把两类进程分开部署：config-server 是 Web/SQLite 应用，适合用 Docker；真正创建 TUN、修改宿主机路由的 `easytier-core` 节点优先使用原生二进制加 systemd。原生节点不需要额外处理 `network_mode: host`、`NET_ADMIN`、`NET_RAW` 和 `/dev/net/tun` 容器映射，路由及 `easytier-cli` 排查也更直接。

推荐使用官方 `easytier-web-embed` 的固定版本 Docker 镜像：

- Web/API 上游只发布到 `127.0.0.1:11211`。
- 配置下发端使用 WebSocket，只发布到 `127.0.0.1:22020`。
- Caddy 用独立域名统一提供 HTTPS/WSS，公网不直接开放 `11211` 和 `22020`。
- 禁用注册，立即替换默认 `admin/admin`、`user/user`。
- 节点用户名使用随机长字符串；它出现在 config-server URL 中，等同 bearer token。
- SQLite、凭据、日志和备份统一放在 `/opt/easytier-config-server`。

模板：

- [config-server.compose.yml.example](../examples/easytier/config-server.compose.yml.example)
- [config-server.caddy.example](../examples/easytier/config-server.caddy.example)
- [config-server-backup.sh.example](../examples/easytier/config-server-backup.sh.example)
- [easytier-config-server-backup.service.example](../examples/easytier/easytier-config-server-backup.service.example)
- [easytier-config-server-backup.timer.example](../examples/easytier/easytier-config-server-backup.timer.example)

部署前生成管理员账号、密码和节点用户名，真实值只保存在服务器：

```bash
install -d -m 0750 /opt/easytier-config-server/{config,data,logs,backup,bin}
openssl rand -hex 12 > /opt/easytier-config-server/config/admin.username
openssl rand -hex 24 > /opt/easytier-config-server/config/admin.password
openssl rand -hex 24 > /opt/easytier-config-server/config/node.username
openssl rand -hex 24 > /opt/easytier-config-server/config/node.password
chmod 600 /opt/easytier-config-server/config/*
```

Compose 中将 `<ET_CONFIG_SERVER_DOMAIN>` 替换为真实域名，Caddy 中再将域名及 `<ET_CONFIG_SERVER_USERNAME>` 替换为节点用户名。必须先执行 `docker compose config` 和 `caddy validate`，再启动容器、reload Caddy。首次启动会创建 SQLite 及默认账号；要在开放公网访问前通过 Web API 或离线数据库操作替换默认用户名和密码，并确认默认账号登录返回 `401`。

节点接入地址：

```text
wss://<ET_CONFIG_SERVER_DOMAIN>/<ET_CONFIG_SERVER_USERNAME>
```

CLI 示例：

```bash
easytier-core \
  --config-server 'wss://<ET_CONFIG_SERVER_DOMAIN>/<ET_CONFIG_SERVER_USERNAME>'
```

`<ET_CONFIG_SERVER_USERNAME>` 是控制面访问凭据，不是 EasyTier 虚拟网络的 `network_name`。节点连上 config-server 后，再由 Web 控制台为节点下发各自网络配置。每个节点的 machine ID 必须固定且唯一；容器运行节点时可只读挂载宿主机 `/etc/machine-id`。

### 原生节点接入 config-server

模板：

- [easytier-node.env.example](../examples/easytier/easytier-node.env.example)
- [easytier-node.service.example](../examples/easytier/easytier-node.service.example)

从官方 release 下载与 config-server 相同版本的 Linux 压缩包，先使用 release API 提供的 SHA-256 校验，再将 `easytier-core` 和 `easytier-cli` 安装到：

```text
/opt/easytier/bin/easytier-core
/opt/easytier/bin/easytier-cli
```

目录布局：

```text
/opt/easytier/config     # config-server 下发的网络配置
/opt/easytier/etc        # node.env，权限 0700
/opt/easytier/logs
/opt/easytier/backup
```

将环境文件放到 `/opt/easytier/etc/node.env` 并设为 `0600`。`ET_MACHINE_ID` 可使用本机 `/etc/machine-id` 的内容，但不能复制到另一台服务器；`ET_HOSTNAME` 每台节点必须唯一。然后安装并启动 systemd unit：

```bash
install -m 0644 examples/easytier/easytier-node.service.example \
  /etc/systemd/system/easytier-node.service
systemd-analyze verify /etc/systemd/system/easytier-node.service
systemctl daemon-reload
systemctl enable --now easytier-node.service
```

只连接 config-server 而尚未下发网络配置时，节点会出现在 Web 控制台，但不会创建 EasyTier TUN 或加入虚拟网络。应在控制台确认设备 hostname 和 machine ID 后，再为它保存并运行网络配置。

### 通过 config-server 下发多节点私有网络

config-server 只负责保存和下发配置。仍需选择一个有稳定公网地址的 EasyTier 节点作为初始节点，其他节点通过它首次进入网络；建链后 EasyTier 会继续尝试节点间直连。

建议先规划不与局域网、云 VPC 和 Tailscale `100.64.0.0/10` 重叠的虚拟网段。例如：

| 节点 | 虚拟 IPv4 | 初始 peer |
|---|---|---|
| `<SEED_NODE>` | `10.144.144.1/24` | 留空 |
| `<PEER_1>` | `10.144.144.2/24` | 种子节点 `11010/tcp`、`11010/udp` |
| `<PEER_2>` | `10.144.144.3/24` | 种子节点 `11010/tcp`、`11010/udp` |
| `<PEER_3>` | `10.144.144.4/24` | 种子节点 `11010/tcp`、`11010/udp` |
| `<PEER_4>` | `10.144.144.5/24` | 种子节点 `11010/tcp`、`11010/udp` |

所有节点使用相同的网络名称和强网络密码，并统一配置：

- 开启私有模式、加密、QUIC 代理和 QUIC 入站。
- 每台使用不同的实例 UUID、hostname 和虚拟 IP。
- 监听 `tcp://0.0.0.0:11010`、`udp://0.0.0.0:11010`；普通节点不要求在云安全组开放该端口。
- 开启中继网络白名单时，只加入当前私有网络名称，避免为其他网络转发。
- 初始节点不配置 peer；其他节点配置 `tcp://<SEED_HOST>:11010` 和 `udp://<SEED_HOST>:11010`。

集中下发按以下顺序进行：

1. 使用 SQLite online backup 备份 config-server 数据库。
2. 确认所有节点的 hostname 和 machine ID 唯一，且目标虚拟 IP 没有重复。
3. 对每份配置分别执行远程校验，全部通过后才开始运行。
4. 先保存并运行初始节点，确认 TUN、`11010/tcp`、`11010/udp` 和公网 TCP 可达。
5. 再保存并运行其他节点，检查每台都为 `running`。
6. 从初始节点查看 peer 和 route，并对其他虚拟 IP 做双向 ping。
7. 重新读取已保存配置，核对私有模式、QUIC、网络名称、虚拟 IP 和初始 peer。

config-server 保存的节点配置包含网络密码，数据库备份和节点侧生成的 TOML 都必须按密钥保护。QUIC 代理是虚拟网络内 TCP 流量的传输优化，不代表 peer 表的底层隧道一定显示 `quic`；实际建链仍可能显示 `tcp` 或 `udp`。

验证：

```bash
systemctl status easytier-node.service --no-pager -l
journalctl -u easytier-node.service -n 100 --no-pager
ss -lntp | grep 15888
/opt/easytier/bin/easytier-cli peer
/opt/easytier/bin/easytier-cli route
```

Web 控制台地址为：

```text
https://<ET_CONFIG_SERVER_DOMAIN>
```

验证：

```bash
docker compose -f /opt/easytier-config-server/compose.yml ps
docker inspect easytier-config-server \
  --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}'
ss -lnt | grep -E '127.0.0.1:(11211|22020)'
curl -I https://<ET_CONFIG_SERVER_DOMAIN>/
docker exec caddy caddy validate \
  --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl status easytier-config-server-backup.timer --no-pager
```

升级前先用 SQLite online backup 备份数据库，并备份 `config/`、Compose 和 Caddyfile。不要在容器运行时直接复制 `et.db`，否则 WAL 中的数据可能遗漏。恢复时同时恢复数据库和 `config/` 中的凭据文件，然后校验文件属主、启动容器并检查数据库完整性。

## 排查

按链路逐层检查：

```text
云安全组 / 系统防火墙
  -> 种子节点 11010/tcp、11010/udp
  -> EasyTier systemd 服务和日志
  -> 网络名称与密码是否完全相同
  -> ET_SEED_HOST 是否可达
  -> 虚拟 IP 是否重复或与现有 Tailscale/局域网路由重叠
```

config-server 另按以下链路排查：

```text
DNS / 80、443 防火墙
  -> Caddy HTTPS/WSS
  -> 127.0.0.1:11211、127.0.0.1:22020
  -> easytier-config-server 容器健康和日志
  -> URL 中的节点用户名是否完全一致
  -> machine ID 是否固定且唯一
```

本仓库模板使用 `10.144.144.0/24`，不要改成 Tailscale 使用的 `100.64.0.0/10`。如果 Tailscale 和 EasyTier 同时存在，还要避免两者同时代理相同子网或同时接管默认路由。
