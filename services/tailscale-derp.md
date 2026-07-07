# Tailscale DERP

> 目标：部署自管 Tailscale DERP relay。基础目录、Caddy 和防火墙约定见 [deployment.md](../deployment.md)。

Tailscale 官方把自管 DERP 视为高级/alpha 用法。优先确认是否真的需要自管 DERP；如果只是同网段内中继，优先评估 Tailscale Peer Relay。本文只记录部署和排障步骤，不记录真实域名、tailnet policy、token 或私钥。

## 前提

- 一个指向服务器公网入口的 `<DERP_DOMAIN>`。
- Caddy 已监听公网 `80/tcp` 和 `443/tcp`，并能为 `<DERP_DOMAIN>` 申请证书。
- 云安全组和系统防火墙至少允许：

```text
80/tcp
443/tcp
3478/udp
ICMP inbound/outbound
```

如果使用 Caddy 反代 DERP，必须确保 `Upgrade: DERP` 能透传到上游。Caddy 上游传输要固定为 HTTP/1.1。

## 目录

```bash
mkdir -p /opt/tailscale-derp/{bin,certs,config,logs,backup}
chown -R <SERVICE_USER>:<SERVICE_USER> /opt/tailscale-derp
```

关键文件：

```text
/opt/tailscale-derp/bin/derper
/opt/tailscale-derp/certs/<DERP_DOMAIN>.crt
/opt/tailscale-derp/certs/<DERP_DOMAIN>.key
/opt/tailscale-derp/config/derper.key
/etc/systemd/system/tailscale-derp.service
```

`config/derper.key` 是 DERP 节点私钥，不要提交到仓库。

## 构建 derper

如果服务器能访问 Go proxy：

```bash
apt update
apt install -y golang-go

env GOPROXY=https://goproxy.cn,direct \
  GOSUMDB=sum.golang.google.cn \
  GOBIN=/opt/tailscale-derp/bin \
  go install tailscale.com/cmd/derper@<TAILSCALE_VERSION>

/opt/tailscale-derp/bin/derper --version
/opt/tailscale-derp/bin/derper --help
```

Tailscale 新版本的 `derper` 可能要求显式 `-c <config path>`；不要照搬旧的纯 flag 启动命令。

## 上游 TLS 证书

Caddy 对公网提供正式 TLS；derper 上游也可以使用本机自签证书，实现 Caddy 到上游的 TLS 反代：

```bash
cd /opt/tailscale-derp

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout certs/<DERP_DOMAIN>.key \
  -out certs/<DERP_DOMAIN>.crt \
  -subj "/CN=<DERP_DOMAIN>" \
  -addext "subjectAltName=DNS:<DERP_DOMAIN>"

chmod 600 certs/<DERP_DOMAIN>.key
chmod 644 certs/<DERP_DOMAIN>.crt
```

只把 `.crt` 复制给 Caddy 信任；不要把 `.key` 复制到 Caddy 或仓库。

## systemd 服务

示例让 derper 的 HTTPS 上游监听 `33443/tcp`，STUN 监听 `3478/udp`。因为 derper 的 STUN 会绑定到 `-a` 的同一个监听 IP，若要公网 STUN，`-a` 不能只写 `127.0.0.1`。用 iptables 阻止公网直接访问 `33443/tcp`，只允许本机 Caddy 访问。

```ini
[Unit]
Description=Tailscale DERP relay for <DERP_DOMAIN>
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=<SERVICE_USER>
Group=<SERVICE_USER>
WorkingDirectory=/opt/tailscale-derp
ExecStartPre=+/bin/sh -c '/usr/sbin/iptables -C INPUT -p tcp --dport 33443 ! -i lo -j DROP 2>/dev/null || /usr/sbin/iptables -I INPUT 1 -p tcp --dport 33443 ! -i lo -j DROP'
ExecStart=/opt/tailscale-derp/bin/derper -c=/opt/tailscale-derp/config/derper.key -hostname=<DERP_DOMAIN> -a=:33443 -http-port=-1 -certmode=manual -certdir=/opt/tailscale-derp/certs -stun=true -stun-port=3478 -home=blank
ExecStopPost=+/bin/sh -c '/usr/sbin/iptables -D INPUT -p tcp --dport 33443 ! -i lo -j DROP 2>/dev/null || true'
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/tailscale-derp

[Install]
WantedBy=multi-user.target
```

启动：

```bash
systemd-analyze verify /etc/systemd/system/tailscale-derp.service
systemctl daemon-reload
systemctl enable --now tailscale-derp
systemctl status tailscale-derp --no-pager -l
```

## Caddy 反代

修改前备份：

```bash
cp /opt/caddy/etc/Caddyfile /opt/caddy/backup/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)
install -m 0644 /opt/tailscale-derp/certs/<DERP_DOMAIN>.crt /opt/caddy/etc/derp-upstream-ca.crt
```

Caddyfile 示例：

```caddyfile
<DERP_DOMAIN> {
    reverse_proxy https://127.0.0.1:33443 {
        transport http {
            versions 1.1
            tls_server_name <DERP_DOMAIN>
            tls_trust_pool file /etc/caddy/derp-upstream-ca.crt
        }
    }
}
```

如果这台机器的 Caddy 只绑定指定内网 IP，保留既有 `bind <PRIVATE_IP>` 风格，不要改成全接口监听，除非确认不会影响现有站点。

校验并 reload：

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
docker logs --since 2m caddy
```

## Tailnet DERP map

服务端部署完成后，还需要在 Tailscale 管理端或 tailnet policy 里加入 DERP map。示例只保留结构，按实际 tailnet 配置：

```json
{
  "Regions": {
    "900": {
      "RegionID": 900,
      "RegionCode": "custom",
      "RegionName": "Custom DERP",
      "Nodes": [
        {
          "Name": "custom-1",
          "RegionID": 900,
          "HostName": "<DERP_DOMAIN>",
          "DERPPort": 443,
          "STUNPort": 3478
        }
      ]
    }
  }
}
```

不要把完整 tailnet policy、真实组织信息或私有配置提交到仓库。

## 验证

服务端：

```bash
systemctl is-active tailscale-derp
journalctl -u tailscale-derp --since '5 minutes ago' --no-pager
ss -lntup | grep -E ':33443|:3478|:80|:443'
iptables -S INPUT | grep 33443

curl -sS -D- -o /dev/null https://<DERP_DOMAIN>/derp/probe
curl -sS -D- -o /dev/null https://<DERP_DOMAIN>/generate_204
```

DERP 协议升级应返回 `101 Switching Protocols`：

```bash
printf 'GET /derp HTTP/1.1\r\nHost: <DERP_DOMAIN>\r\nConnection: Upgrade\r\nUpgrade: DERP\r\n\r\n' \
  | openssl s_client -connect <DERP_DOMAIN>:443 -servername <DERP_DOMAIN> -quiet
```

直连 `33443/tcp` 应该从公网失败，防止绕过 Caddy：

```bash
nc -vz -w 5 <DERP_DOMAIN> 33443
```

客户端加入 DERP map 后：

```bash
tailscale netcheck
tailscale ping <PEER_NAME>
```

注意：Tailscale 的 STUN server 只响应带 Tailscale `SOFTWARE=tailnode` 和 fingerprint 的 STUN 请求；普通最小 STUN 测试包可能超时，不代表服务异常。

## 排查

### `/derp/probe` 不通

按链路检查：

```bash
dig +short <DERP_DOMAIN>
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker logs --since 5m caddy
systemctl status tailscale-derp --no-pager -l
curl --cacert /opt/tailscale-derp/certs/<DERP_DOMAIN>.crt \
  --resolve <DERP_DOMAIN>:33443:127.0.0.1 \
  -sS -D- -o /dev/null https://<DERP_DOMAIN>:33443/derp/probe
```

常见原因：

- Caddy 没拿到 `<DERP_DOMAIN>` 证书。
- Caddy 上游没有使用 HTTP/1.1，导致 `Upgrade: DERP` 失败。
- derper 没带 `-c`，新版本启动后立刻退出。
- 上游自签证书没有被 Caddy 信任，或 `tls_server_name` 与证书 SAN 不一致。

### DERP 升级不是 101

检查：

```bash
printf 'GET /derp HTTP/1.1\r\nHost: <DERP_DOMAIN>\r\nConnection: Upgrade\r\nUpgrade: DERP\r\n\r\n' \
  | openssl s_client -connect <DERP_DOMAIN>:443 -servername <DERP_DOMAIN> -quiet
```

如果返回 426、502 或连接被关闭，重点查 Caddy 的 `transport http { versions 1.1 }` 和 derper 日志。

### STUN 不通

检查监听：

```bash
ss -lunp | grep ':3478'
journalctl -u tailscale-derp --since '5 minutes ago' --no-pager
```

如果本机 Tailscale 风格 STUN 请求有响应，但公网没有响应，通常是云安全组或外层防火墙没放行 `3478/udp`。系统 iptables `INPUT` 默认放行时，不要只盯本机规则。

### 客户端没有使用自管 DERP

确认 DERP map 已应用到 tailnet，并在客户端重新登录或等待策略下发：

```bash
tailscale netcheck
tailscale debug prefs
```

如果 `netcheck` 仍只看到官方区域，先查 tailnet policy，不要先重启服务器。

## 备份

```bash
mkdir -p /opt/tailscale-derp/backup
tar czf /opt/tailscale-derp/backup/tailscale-derp-$(date +%Y%m%d-%H%M%S).tgz \
  /opt/tailscale-derp/config \
  /opt/tailscale-derp/certs \
  /etc/systemd/system/tailscale-derp.service \
  /opt/caddy/etc/Caddyfile
```

备份文件可能包含私钥，只保留在服务器安全位置，不提交仓库。
