# AGENTS.md

本仓库是新服务器部署与排障说明，主要服务包括 Caddy、s-ui、Sub-Store、SillyTavern。AI 接手本仓库时，先读本文件，再按任务类型读取部署或排查手册。

## 快速入口

- 部署手册：[DEPLOYMENT.md](./DEPLOYMENT.md)
- 排查手册：[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- 仓库说明：[README.md](./README.md)
- 本文件只保存 AI 操作指导和速查信息；具体命令、模板以部署手册为准，问题诊断以排查手册为准。

## AI 操作原则

1. 部署或改配置任务先定位到 `DEPLOYMENT.md` 对应章节；排障任务先定位到 `TROUBLESHOOTING.md` 对应章节。
2. 涉及真实服务器、真实域名、token、密码、API key、订阅地址时，不要写入仓库；文档中只保留占位符。
3. 修改线上配置前先备份，尤其是 Caddyfile、Sub-Store 数据、SillyTavern 配置、s-ui 数据库。
4. 修改后必须验证：配置校验、服务状态、端口监听、HTTP 状态码、容器日志或 systemd 日志。
5. 不要默认扩大公网暴露面。Sub-Store 和 SillyTavern 推荐只监听 `127.0.0.1`，由 Caddy 反代对外提供 HTTPS。
6. 遇到 502、404、timeout、unauthorized 等问题时，按链路逐层检查：DNS/防火墙 -> Caddy -> 本机端口 -> 容器或 systemd 服务 -> 应用配置。

## 服务速查

| 服务 | 主要目录 | 推荐监听 | 说明 |
|---|---|---|---|
| Caddy | `/opt/caddy` | `80/tcp`, `443/tcp` | 公网 HTTPS 入口，反代其他服务 |
| s-ui | `/usr/local/s-ui` | `2095`, `2096`, 入站端口如 `32676` | 面板、订阅、节点入站 |
| Sub-Store | `/opt/substore` | `127.0.0.1:3001`, `127.0.0.1:3002` | 前端和后端只给 Caddy 反代 |
| SillyTavern | `/opt/SillyTavern` | `127.0.0.1:7123` -> 容器 `8000` | 只给 Caddy 反代 |

## 常用任务索引

- 新服务器基础环境：看 `DEPLOYMENT.md`「2. 基础环境」
- Caddy 部署、站点新增：看 `DEPLOYMENT.md`「3. Caddy 部署」
- s-ui 安装、面板/订阅端口、入站、备份恢复：看 `DEPLOYMENT.md`「4. s-ui 部署」
- Sub-Store 部署、订阅聚合、`/mihomo` 重写、备份：看 `DEPLOYMENT.md`「5. Sub-Store 部署」
- SillyTavern 部署、白名单、API 类型：看 `DEPLOYMENT.md`「6. SillyTavern 部署」
- 全链路健康检查：看 `DEPLOYMENT.md`「7. 全链路验证」
- 502、证书、404、timeout、unauthorized、节点不通：看 `TROUBLESHOOTING.md`
- s-ui VLESS/Reality 真实案例：看 `TROUBLESHOOTING.md`「s-ui VLESS Reality 真实案例」
- 修改前备份命令：看两份文档的备份章节

## 修改配置时的最小流程

1. 确认目标服务和对应章节。
2. 备份即将修改的文件或数据库。
3. 按 `DEPLOYMENT.md` 模板修改配置。
4. 先做本地配置校验，例如 Caddy 使用 `caddy validate`。
5. reload 或 restart 服务。
6. 用 `curl`、`docker logs`、`docker compose ps`、`systemctl status`、`journalctl` 验证结果。
7. 记录新增的域名、端口、路径或注意事项，但不要记录真实密钥。

## 高风险注意事项

- 不要把 s-ui 面板、Sub-Store 后端、SillyTavern 容器端口随意暴露到公网。
- 不要把 OpenAI-compatible Chat Completions API 配到 SillyTavern 的 `Text Completion / Generic`。
- Caddy 反代 SillyTavern 时，上游端口是宿主机 `127.0.0.1:7123`，不是容器内部 `8000`。
- Sub-Store 读取同机 s-ui 订阅时，优先使用 `http://127.0.0.1:2096/sub/<SUB_PATH>`，避免绕公网域名。
- 对 iptables、防火墙、安全组做变更前，必须记录当前状态或备份规则。
