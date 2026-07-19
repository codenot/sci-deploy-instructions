# AGENTS.md

本仓库是新服务器部署与排障说明，主要服务包括 Caddy、s-ui、Marzban、Remnawave、Sub-Store、SillyTavern。AI 接手本仓库时，先读本文件，再按任务类型读取部署总手册或服务文档。

## 快速入口

- 部署总手册：[deployment.md](./deployment.md)
- 线路 ASN 速查：[asn-route.md](./asn-route.md)
- 仓库说明：[README.md](./README.md)
- 本文件只保存 AI 操作指导和速查信息；基础 Docker、全局约定和通用排查以部署总手册为准，单服务部署和服务专属排查以 `services/` 下对应文件为准。

## AI 操作原则

1. 部署或改配置任务先看 `deployment.md` 的基础约定，再进入 `services/` 下对应服务文件；排障任务先看 `deployment.md` 的通用排查，再进入对应服务文件的排查章节。
2. 涉及真实服务器、真实域名、token、密码、API key、订阅地址时，不要写入仓库；文档中只保留占位符。
3. 修改线上配置前先备份，尤其是 Caddyfile、Sub-Store 数据、SillyTavern 配置、s-ui 数据库、Marzban 数据库和 Xray 配置、Remnawave PostgreSQL 数据。
4. 修改后必须验证：配置校验、服务状态、端口监听、HTTP 状态码、容器日志或 systemd 日志。
5. 不要默认扩大公网暴露面。Marzban 面板、Remnawave 面板、Sub-Store 和 SillyTavern 推荐只监听 `127.0.0.1`，由 Caddy 反代对外提供 HTTPS。
6. Docker 服务部署根目录统一为 `/opt/<service>`，数据、配置、Caddy 配置、日志、备份分别使用 `/opt/<service>/data`、`/opt/<service>/config`、`/opt/<service>/etc`、`/opt/<service>/logs`、`/opt/<service>/backup` 等语义目录；不要使用 `docker-data` 这类额外前缀目录。
7. 遇到 502、404、timeout、unauthorized 等问题时，按链路逐层检查：DNS/防火墙 -> Caddy -> 本机端口 -> 容器或 systemd 服务 -> 应用配置。
8. Docker 网络统一采用“出口不设服务级限制、入口在最外层控制”的基线：先确认 Docker Engine `>= 28.0.0`，保留 Docker 自动维护的 NAT 和端口映射，IPv4 `FORWARD` 使用 `ACCEPT`，并在 `/etc/docker/daemon.json` 配置 `ip-forward-no-drop: true`。低于 28.0.0 时先升级，不要直接套用 `FORWARD ACCEPT`。不要为单个 Docker 网桥、容器网段、服务或远端目的地址创建出口白名单和 systemd oneshot；公网入口由云安全组、监听地址及必要时统一的 `DOCKER-USER` 规则控制。

## 服务速查

| 服务 | 主要目录 | 推荐监听 | 说明 |
|---|---|---|---|
| Caddy | `/opt/caddy` | `80/tcp`, `443/tcp` | 公网 HTTPS 入口，反代其他服务 |
| s-ui | `/usr/local/s-ui` | `2095`, `2096`, 入站端口如 `32676` | 面板、订阅、节点入站 |
| Marzban | `/opt/marzban` | `127.0.0.1:8000`, 入站端口按配置 | Xray-core 多用户面板，面板只给 Caddy 反代 |
| Remnawave | `/opt/remnawave` | `127.0.0.1:3010`, `127.0.0.1:3011` | Panel 管理面板；代理流量由 Remnawave Node 承载 |
| Remnawave Node | `/opt/remnawave-node` | 控制端口如 `2222` 只允许 Panel 访问，入站端口按配置 | 承载 Xray-core；不要把 Node 控制 API 直接暴露公网 |
| Sub-Store | `/opt/substore` | `127.0.0.1:3001`, `127.0.0.1:3002` | 前端和后端只给 Caddy 反代 |
| SillyTavern | `/opt/SillyTavern` | `127.0.0.1:7123` -> 容器 `8000` | 只给 Caddy 反代 |
| Tailscale DERP | `/opt/tailscale-derp` | Caddy `443/tcp` -> 本机 `33443/tcp`，`3478/udp` | 自管 Tailscale DERP relay；上游端口不要直接暴露公网 |

## 常用任务索引

- 新服务器基础环境、目录/域名/端口约定：看 `deployment.md`
- Caddy 部署、站点新增：看 `services/caddy.md`
- s-ui 安装、面板/订阅端口、入站、备份恢复：看 `services/s-ui.md`
- Marzban Docker 部署、面板反代、管理员、入站、备份恢复：看 `services/marzban.md`
- Remnawave Docker 部署、面板反代、节点接入入口：看 `services/remnawave.md`
- Sub-Store 部署、订阅聚合、`/mihomo` 重写、备份：看 `services/sub-store.md`
- SillyTavern 部署、白名单、API 类型：看 `services/sillytavern.md`
- Tailscale DERP relay、Caddy TLS 反代、STUN 验证：看 `services/tailscale-derp.md`
- 全链路健康检查：看 `deployment.md`「7. 全链路验证」
- 通用链路排查和基础状态采集：看 `deployment.md`「8. 通用排查」
- 502、证书、404、timeout、unauthorized、节点不通：看对应 `services/*.md` 的「排查」章节
- s-ui VLESS/Reality 真实案例：看 `services/s-ui.md`「s-ui VLESS Reality 真实案例」
- 修改前备份命令：看 `deployment.md` 和对应服务文档的备份章节

## 修改配置时的最小流程

1. 确认目标服务和对应章节。
2. 备份即将修改的文件或数据库。
3. 按 `services/` 中对应服务模板修改配置。
4. 先做本地配置校验，例如 Caddy 使用 `caddy validate`。
5. reload 或 restart 服务。
6. 用 `curl`、`docker logs`、`docker compose ps`、`systemctl status`、`journalctl` 验证结果。
7. 记录新增的域名、端口、路径或注意事项，但不要记录真实密钥。

## 高风险注意事项

- 不要把 s-ui 面板、Marzban 面板、Remnawave 面板、Sub-Store 后端、SillyTavern 容器端口随意暴露到公网。
- 不要把 OpenAI-compatible Chat Completions API 配到 SillyTavern 的 `Text Completion / Generic`。
- Caddy 反代 SillyTavern 时，上游端口是宿主机 `127.0.0.1:7123`，不是容器内部 `8000`。
- Sub-Store 读取同机 s-ui 订阅时，优先使用 `http://127.0.0.1:2096/sub/<SUB_PATH>`，避免绕公网域名。
- Marzban Docker 部署时，compose、`.env`、SQLite 数据库和 `xray_config.json` 都放在 `/opt/marzban` 下，不使用默认 `/var/lib/marzban` 数据路径。
- 同机同时运行 Marzban Master 和 Marzban Node 会启动两个 Xray 实例，容易出现入站端口冲突；单机部署优先直接使用 Marzban Master 入站，多地区服务器再单独部署 Marzban Node。
- Remnawave Panel 本身不跑 Xray-core；节点代理流量需要单独部署 Remnawave Node，并在面板里通过 Config Profile、Host、Internal Squad 关联。
- Remnawave Node 的 `NODE_PORT` 是 Panel 调 Node 的控制 API，不是用户代理端口；这是入口限制，不是 Panel 容器的出口白名单。Node 使用 host 网络时在 `INPUT` 控制来源，Node 通过 Docker 发布端口时在 `DOCKER-USER` 或云安全组控制来源。
- Tailscale DERP 的 `33443/tcp` 是 Caddy 到 derper 的本机上游端口，不要直接暴露公网；公网只走 Caddy `443/tcp`，STUN 单独放行 `3478/udp`。
- 对 iptables、防火墙、安全组做变更前，必须记录当前状态或备份规则。
- 不要把 Docker 的 `iptables` 功能设为 `false`，否则会破坏默认 bridge 的 NAT、端口映射和网络隔离。不要把运行中的 Docker 动态链整体写入静态固化文件；只固化宿主机基线策略，并让 Docker 在 daemon 启动时重建自己的链。
- Docker 发布到 `0.0.0.0` 的端口经过 DNAT 后不一定进入宿主机 `INPUT` 链；不能只靠 `INPUT` 规则限制这类端口。内部服务优先绑定 `127.0.0.1`，需要公网限制时使用云安全组或统一的 `DOCKER-USER` 入口规则。
- Docker Engine 低于 28.0.0 时，localhost 发布端口和未发布容器端口存在旧版 direct-routing 安全差异；升级并验证 Docker 版本之前，不要把全局 `FORWARD` 改成 `ACCEPT`。
- `iptables -P FORWARD ACCEPT` 不能覆盖链中已有的 `DROP`，也不能阻止旧 systemd oneshot 重加规则。切换基线前必须审计 `FORWARD`、`DOCKER-USER` 和相关 systemd 单元，精确清理旧出口限制；不要 flush Docker 自动维护的链。
