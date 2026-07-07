# SCI Deploy Instructions

新机器服务部署与排查手册，覆盖 Caddy、s-ui、Marzban、Remnawave、Sub-Store、SillyTavern、Tailscale DERP。通用约定和全局排查在总手册里，每个服务的部署和排查在自己的服务文档里。

Docker 服务默认部署在 `/opt/<service>`，宿主机挂载目录使用 `/opt/<service>/data`、`/opt/<service>/config`、`/opt/<service>/etc`、`/opt/<service>/logs` 等语义子目录，不使用 `docker-data` 这类额外前缀目录。

主文档：

- [deployment.md](./deployment.md)：基础 Docker、目录/域名/端口约定、全链路验证、通用排查、备份习惯。
- [servers.md](./servers.md)：`kr`、`tw`、`hk`、`hk2` 当前部署服务、目录、容器和端口清单。
- [asn-route.md](./asn-route.md)：电信、联通、移动常见 ASN、线路俗称、用途和价格水位速查。

单服务部署：

- [services/caddy.md](./services/caddy.md)
- [services/s-ui.md](./services/s-ui.md)
- [services/marzban.md](./services/marzban.md)
- [services/remnawave.md](./services/remnawave.md)
- [services/sub-store.md](./services/sub-store.md)
- [services/sillytavern.md](./services/sillytavern.md)
- [services/tailscale-derp.md](./services/tailscale-derp.md)
