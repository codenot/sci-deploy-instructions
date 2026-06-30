# Sub-Store 部署

> Sub-Store 负责聚合机场订阅和自建节点订阅，并生成客户端使用的配置文件。基础约定见 [DEPLOYMENT.md](../DEPLOYMENT.md)。

## 创建目录

```bash
mkdir -p /opt/substore/data
cd /opt/substore
```

## docker-compose.yaml

```yaml
services:
  sub-store:
    image: xream/sub-store:http-meta
    container_name: sub-store
    restart: always
    network_mode: host
    environment:
      SUB_STORE_BACKEND_API_HOST: 127.0.0.1
      SUB_STORE_BACKEND_API_PORT: 3002
      SUB_STORE_FRONTEND_BACKEND_PATH: /api
      SUB_STORE_FRONTEND_PORT: 3001
      SUB_STORE_FRONTEND_HOST: 127.0.0.1
      PORT: 9876
      HOST: 127.0.0.1
    volumes:
      - ./data:/opt/app/data
```

说明：

- `network_mode: host` 是为了直接访问本机 s-ui 订阅地址 `127.0.0.1:2096`。
- 前端和后端都绑定 `127.0.0.1`，只允许 Caddy 对外暴露。

## 启动与验证

```bash
cd /opt/substore
docker compose up -d
docker compose ps

curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' http://127.0.0.1:3001/
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' http://127.0.0.1:3002/
curl -ksS -o /dev/null -w '%{http_code} %{content_type}\n' https://sub.example.com/
```

## 配置订阅

进入：

```text
https://sub.example.com/
```

推荐结构：

1. 创建机场原始订阅：

```text
name: airport-main
source: remote
url: <机场原始订阅 URL>
```

2. 创建自建节点订阅：

```text
name: self-hosted
source: remote
url: http://127.0.0.1:2096/sub/<SUB_PATH>
```

3. 创建 collection：

```text
name: all-airports
subscriptions:
  - airport-main
  - self-hosted
```

4. 创建 file：

```text
name: mihomo-auto
sourceType: collection
source: all-airports
platform: ClashMeta / Mihomo
download: true
```

Caddy 会把：

```text
https://sub.example.com/mihomo
```

重写到：

```text
/api/file/mihomo-auto
```

客户端订阅：

```text
https://sub.example.com/mihomo
```

## 备份

```bash
cp /opt/substore/data/sub-store.json \
  /opt/substore/data/sub-store.json.bak-$(date +%Y%m%d-%H%M%S)

tar czf /opt/substore-backup-$(date +%Y%m%d).tgz /opt/substore/data /opt/substore/docker-compose.yaml
```

## 排查

### 基础命令

```bash
cd /opt/substore
docker compose ps
docker compose logs -f
docker logs --tail 200 sub-store
curl -I https://sub.example.com/mihomo
curl -sS http://127.0.0.1:3002/api/file/mihomo-auto | head
```

### `/mihomo` 404

修复方向：

- Caddy 中 `/mihomo` 是否 rewrite 到 `/api/file/mihomo-auto`。
- Sub-Store file 名称是否正好叫 `mihomo-auto`。
- Caddy 是否把 `/mihomo` 反代到后端 `127.0.0.1:3002`，不是前端 `3001`。

### 下载为空

修复方向：

- collection 是否选中了订阅。
- 远程机场订阅是否能拉取。
- 自建 s-ui 订阅是否能从 Sub-Store 容器访问。
- file 的 `sourceType`、`source`、`platform` 是否正确。

### 自建节点没出现

检查：

```bash
curl -v http://127.0.0.1:2096/sub/<SUB_PATH>
docker inspect sub-store --format '{{.HostConfig.NetworkMode}}'
```

修复方向：

- Sub-Store 推荐使用 `network_mode: host`。
- s-ui 订阅地址推荐用 `127.0.0.1:2096`。
- 确认 s-ui 的 `Sub path` 没写错。

### 客户端提示格式错误

修复方向：

- file 的 platform/模板应选择 Mihomo/ClashMeta 对应格式。
- 用 `curl -sS https://sub.example.com/mihomo | head` 看输出是不是客户端期望格式。
