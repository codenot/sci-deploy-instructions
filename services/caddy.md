# Caddy 部署

> Caddy 是公网 HTTPS 入口，负责把域名反代到本机服务。基础 Docker、目录和端口约定见 [deployment.md](../deployment.md)。

## 创建目录

```bash
mkdir -p /opt/caddy/{etc,data,config,logs}
cd /opt/caddy
```

## docker-compose.yaml

```yaml
services:
  caddy:
    image: caddy:alpine
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./etc:/etc/caddy
      - ./data:/data
      - ./config:/config
      - /opt/share:/opt/share:ro
```

如果没有 `/opt/share` 静态文件目录，可以删掉最后一行 volume。

## Caddyfile 模板

```bash
cat > /opt/caddy/etc/Caddyfile <<'EOF'
silly.example.com {
    reverse_proxy 127.0.0.1:7123
}

sub.example.com {
    handle /mihomo {
        rewrite * /api/file/mihomo-auto
        reverse_proxy 127.0.0.1:3002
    }

    handle {
        reverse_proxy 127.0.0.1:3001
    }
}

marzban.example.com {
    reverse_proxy 127.0.0.1:8000
}

remnawave.example.com {
    reverse_proxy 127.0.0.1:3010
}
EOF
```

## 启动与验证

```bash
cd /opt/caddy
docker compose up -d
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker logs --tail 100 caddy
```

## 新增或修改站点

```bash
cd /opt/caddy
cp etc/Caddyfile etc/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)
vim etc/Caddyfile
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

## 备份

```bash
cp /opt/caddy/etc/Caddyfile /opt/caddy/etc/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)
```

## 排查

### 公网 502

常见原因：Caddy 能收到请求，但反代的上游端口没有监听，或端口写错。

检查：

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker logs --since 5m caddy
ss -lntup | grep -E ':3001|:3002|:7123|:8000|:3010'
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7123/
```

修复方向：

- SillyTavern 反代应指向宿主机 `127.0.0.1:7123`，不是容器内部 `8000`。
- Sub-Store 前端应指向 `127.0.0.1:3001`。
- Sub-Store 文件/API 应指向 `127.0.0.1:3002`。
- Marzban 面板应指向 `127.0.0.1:8000`。
- Remnawave Panel 应指向 `127.0.0.1:3010`。
- 上游没监听时，先修应用容器或 systemd 服务，不要先改 Caddy。

### 证书申请失败

检查：

```bash
dig +short silly.example.com
dig +short sub.example.com
dig +short marzban.example.com
dig +short remnawave.example.com
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
