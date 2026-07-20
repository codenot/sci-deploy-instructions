# 三大运营商 ASN 与跨境线路判断

> 用途：部署代理节点、选购 VPS/独服或排查回国线路时，区分运营商骨干、国际网络、商业线路名称和实际 BGP 路径。

本文只记录公开注册信息和可复现的判断方法。线路质量会随地区、方向、时段、互联策略、带宽和商家超售变化，不能只凭一个 ASN 或商品名判断。

## 1. 先统一概念

### 1.1 ASN 是路由域标识，不是服务等级

从 BGP 的概念层次看，`AS4134`、`AS4809`、`AS4837`、`AS9929`、`AS9808`、`AS58453` 和 `AS58807` 都是自治系统编号。它们处于同一技术抽象层，但在各自运营商体系中的组织归属和网络角色并不相同。

需要分开看四件事：

1. **注册主体**：大陆运营商还是其国际子公司。
2. **网络角色**：公众互联网骨干、政企/精品承载网，还是国际网络。
3. **商业产品**：例如 GIA、GT、CMIN2；产品名不一定与单个 ASN 一一对应。
4. **实际路径**：某次去程和回程真正经过哪些 AS、城市和互联点。

因此不要使用下面这种简单二分：

```text
普通 ASN = 国内
精品 ASN = 国际
```

更准确的理解是：一张骨干网可以同时有境内节点、国际出口和海外 POP；国际子公司的网络也会与集团在中国大陆的骨干衔接。地理范围、网络角色和服务等级是三个不同维度。

### 1.2 ASN 能证明什么

- APNIC WHOIS 能确认 ASN 的登记主体和公开名称，但不能证明线路服务等级。
- BGP AS Path 能说明路由通告经过的自治系统，但不展示 AS 内部使用的 MPLS、流量工程或所有物理节点。
- traceroute 中的 IP/ASN 映射可能过期，也可能因 MPLS、ICMP 策略、第三方地址或路由器回包路径而不完整。
- 单次路由只能代表当时、该方向、该探测点到目标的路径；去程不等于回程。
- `59.43.*` 常用于辅助识别 CN2，但 IP 前缀或几个跳点仍不能单独证明 GIA、带宽保证或晚高峰质量。

## 2. 核心 ASN 与网络角色

以下“公开登记”以 APNIC WHOIS 为准；“常见称呼”包含运营商产品名和行业俗称，不表示它们完全等价。

| 运营商 | ASN | APNIC 公开名称/主体 | 更准确的网络角色 | 常见称呼 |
|---|---:|---|---|---|
| 中国电信 | `AS4134` | `CHINANET-BACKBONE` | ChinaNet 公众互联网骨干；既承载大陆业务，也具有国际互联和海外可达能力 | 163、ChinaNet、普通电信 |
| 中国电信 | `AS4809` | `CHINATELECOM-CORE-WAN-CN2` | 中国电信下一代承载网，是与 ChinaNet 并列的另一张骨干网，面向差异化、政企和高质量承载，也包含跨境能力 | CN2 |
| 中国电信国际 | `AS23764` | `CTGNet`, China Telecom Global Limited | 中国电信国际公司的全球网络和海外互联；可与 ChinaNet、CN2 衔接 | CTGNet、电信国际 |
| 中国联通 | `AS4837` | `CHINA169-Backbone` | China169 公众互联网骨干；既承载大陆公众业务，也可以参与国际路由 | 169、普通联通 |
| 中国联通 | `AS9929` | `CUII`, China Unicom Industrial Internet Backbone | 与 China169 分立的工业互联网/政企承载骨干，市场常作为高质量联通线路销售 | CUII、联通 A 网、9929 |
| 中国联通国际 | `AS10099` | `UNICOM-Global`, China Unicom Global | 中国联通国际网关和全球网络；可与 `AS4837` 或 `AS9929` 衔接 | CUG、联通国际 |
| 中国移动 | `AS9808` | `CHINAMOBILE-CN`, China Mobile Communications Group | 中国移动大陆 CMNET 公众互联网骨干 | CMNET、普通移动 |
| 中国移动国际 | `AS58453` | `CMI-INT-HK`, China Mobile International Limited | 中国移动国际运营的全球 IP 网络 | CMI、移动国际 |
| 中国移动国际 | `AS58807` | `CMI-INT-AS`, China Mobile International Limited | 中国移动国际运营的另一张国际网络，官方合同材料将 CMIN2 服务对应到该 ASN | CMIN2、N2 |

公开登记查询：[AS4134](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS4134)、[AS4809](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS4809)、[AS23764](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS23764)、[AS4837](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS4837)、[AS9929](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS9929)、[AS10099](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS10099)、[AS9808](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS9808)、[AS58453](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS58453)、[AS58807](https://wq.apnic.net/apnic-bin/whois.pl?searchtext=AS58807)。

## 3. 三家运营商的关系

以下结构图表示常见的组织和路由角色，不表示每条实际路径都必须依次经过所有节点。

### 3.1 中国电信

```text
                     中国电信体系
                          |
            +-------------+-------------+
            |                           |
    AS4134 ChinaNet              AS4809 CN2
    公众互联网骨干               下一代/差异化承载骨干
            |                           |
            +-------------+-------------+
                          |
                 国际互联、海外 POP
                          |
                AS23764 CTGNet 等
```

`AS4134` 与 `AS4809` 都是中国电信运营的 IP 骨干，不应解释为“国内网与国际网”。中国电信国际的公开产品页明确说明，其 Global Transit 可通过 ChinaNet（`AS4134`）或 CN2（`AS4809`）提供全球可达；`AS23764` 则是 China Telecom Global 登记的独立 AS。

CN2 和 GIA 也不是同义词：

- **CN2** 是网络/承载体系，核心 ASN 为 `AS4809`。
- **GIA** 是中国电信面向企业的 Global Internet Access 服务，官方资料说明它使用 CN2 的优质路径。
- **CN2 GT** 是市场常用的线路等级称呼，不能仅由 AS Path 中出现一次 `AS4809` 或 `59.43.*` 自动判定。

所以文档和脚本应写“路径出现 `AS4809`，与 CN2 一致”，不要直接写“检测到 CN2 GIA”。GIA 还需要合同/商品规格、双向路径和性能测试共同确认。

参考：[China Telecom Global IP 网络产品页](https://ipms.chinatelecomglobal.com/)、[China Telecom Europe GIA](https://www.chinatelecomeurope.com/product/global-internet-access/)。

### 3.2 中国联通

```text
                     中国联通体系
                          |
            +-------------+-------------+
            |                           |
    AS4837 China169              AS9929 CUII
    公众互联网骨干               工业互联网/政企承载骨干
            |                           |
            +-------------+-------------+
                          |
                AS10099 联通国际/CUG
                          |
                 海外 POP、其他 ASN
```

`AS4837` 与 `AS9929` 和电信两张骨干网的抽象方式相近：它们都是联通体系内独立的 IP 骨干/承载网络，不是简单的国内与国际之分。两者定位不同，均可能参与跨境路径；`AS10099` 的 APNIC 登记描述明确包含 China Unicom Global 和 International Gateway。

需要注意：

- “联通精品网”“A 网”是行业和商业语境；APNIC 对 `AS9929` 的正式描述是 China Unicom Industrial Internet Backbone。
- 海外路径常见 `AS10099 -> AS9929` 或 `AS10099 -> AS4837`，但这不是所有地区和方向的固定模板。
- 看到 `AS10099` 只能确认经过联通国际网络，不能单独证明大陆段是 `AS9929`。

### 3.3 中国移动

```text
                     中国移动体系
                          |
           中国大陆                         国际公司
              |                                |
       AS9808 CMNET              +-------------+-------------+
       公众互联网骨干             |                           |
                              AS58453 CMI                AS58807
                              国际 IP 网络                CMIN2/N2
                                  |                           |
                                  +-------------+-------------+
                                                |
                                       海外 POP、其他 ASN
```

移动与前两家的对应关系不同：

- `AS9808` 登记给中国移动集团，是大陆 CMNET 骨干。
- `AS58453` 和 `AS58807` 均登记给位于香港的 China Mobile International Limited。
- 中国移动国际的公开对等策略将 `AS58453` 称为其运营的 IP 网络；中国移动国际合同材料分别写明 CMI（`AS58453`）和 CMIN2（`AS58807`）。

因此 `AS9808` 与 `AS58807` 虽然都是 ASN，在运营商体系中的功能层次却不是“普通国内骨干 vs 精品国内骨干”：更准确的是**大陆公众网骨干 vs 国际公司运营的精品国际网络**。普通跨境路径常见 `AS9808` 与 `AS58453` 衔接，CMIN2 路径则可能出现 `AS58807`；实际路径仍以双向测量为准。

参考：[CMI AS58453 对等策略](https://www.cmi.chinamobile.com/pdf/zaqxwwtgblephes/Peering_Policy_For_External.pdf)、[CMI 合同中的 CMI/CMIN2 ASN](https://mainwebapi.cmi.chinamobile.com/uploads/20240124/e9d61ca808e6a26599f09b61cd91ebf3.pdf)。

## 4. 常见省网和区域 ASN

这些 ASN 主要用于识别接入、省网、城域网或 IDC。注册信息和实际用途可能调整，使用前应重新查询 APNIC，不要据此推断服务等级。

| 运营商 | 常见 ASN | 常见识别用途 |
|---|---|---|
| 电信 | `AS23724`、`AS4810`、`AS4811`、`AS4812`、`AS4813`、`AS4815`、`AS4816`、`AS23650`、`AS23662` | 北京、上海、广东、江苏、甘肃等区域骨干或 IDC 辅助识别 |
| 联通 | `AS4808`、`AS4814`、`AS17621`、`AS17622`、`AS17623`、`AS17816`、`AS134542`、`AS134543`、`AS135061` | 北京、上海、广东及部分 IDC 辅助识别 |
| 移动 | `AS24400`、`AS24444`、`AS56040`、`AS56041`、`AS56042`、`AS56044`、`AS56045`、`AS56046`、`AS56047`、`AS56048` | 各省移动网络和 IDC 辅助识别 |

CMI 还登记或运营多个区域 ASN。它们用于当地网络组织，不代表单独的“更高级线路”，也不应仅凭名称加入精品线路匹配规则。

## 5. 国外常见上游 ASN

国外 VPS 或独服的线路通常由“机房自己的 ASN + 一个或多个 IP Transit + IX/私有对等”组成。下面的 ASN 可用于识别常见国际上游，但不能仅凭品牌推断中国方向的去程、回程或性能。

### 5.1 全球和区域骨干

| ASN | 当前运营者/常见旧称 | 可确认的网络定位 | 选机时的正确解读 |
|---:|---|---|---|
| `AS3356` | Lumen；常沿用 Level 3 称呼 | Lumen 运营的大型全球 IP 网络，互联和覆盖范围广 | 常见于全球 Transit 和多上游 IDC。覆盖广不等于所有中国方向都最优；移动、电信、联通应分别测双向路径 |
| `AS9002` | RETN | 以欧洲和欧亚连接为重点的国际 IP/MPLS 网络 | 适合重点考察欧洲、中亚、高加索和欧亚路径。香港到欧洲是否走陆路、节省多少延迟由当时 BGP 和具体产品决定，不能从 ASN 固定推导 |
| `AS2914` | NTT DATA Global IP Network；NTT | 横跨美洲、欧洲、亚洲和大洋洲的单一 ASN 全球骨干；运营者称其为 Tier 1 | 在日本、亚太和跨太平洋选线中值得重点测试，但“到日本必然最优”仍取决于源运营商互联、入口城市和拥塞情况 |
| `AS17676` | SoftBank、Yahoo! BB、ULTINA | SoftBank 在日本运营的互联网骨干和接入网络之一 | 日本本地业务和日本方向选线的重要候选。是否与 `AS4809`/`AS9929` 直连、是否双向精品回程必须实测；出现该 ASN 也不能证明服务器 IP 是住宅 IP |
| `AS174` | Cogent Communications | 大型全球 IP Transit 网络，广泛用于数据中心上游 | 市场上常以覆盖广和价格竞争力著称，但合同价格不是公开固定属性；中国和部分区域路径需特别检查绕路、互联和晚高峰 |
| `AS3257` | GTT | GTT 运营的全球 Tier 1 IP 网络 | 欧洲和全球 Transit 的常见候选。不能用“中端”这类市场标签替代 PoP、对等关系、SLA 和实测结果 |
| `AS1299` | Arelion；原 Telia Carrier | Arelion 的全球互联网骨干，运营者称其为 Tier 1 | 欧洲、北美和全球 Transit 的常见上游；亚洲覆盖和中国方向质量应按具体城市及运营商验证 |
| `AS6939` | Hurricane Electric、HE | 大型全球双栈网络，IPv6 覆盖突出，公开对等策略较开放 | 常见于 IPv6 Transit、IX 和中小网络多上游。业界对其 Tier 级别存在不同口径；流媒体可用性属于 IP/平台策略问题，不能由 ASN 一概而论 |
| `AS3491` | PCCW Global / Console Connect | 以香港为重要基地的全球 IP 骨干，并非只覆盖香港本地 | 香港和亚洲选线的重要候选，也有跨洲网络。与三大运营商“有互联”不代表每条路由都直连或低拥塞，仍需逐网验证 |
| `AS137409` | Global Secure Layer、GSL Networks | GSL 的 NSP/骨干 ASN，提供多地网络和优化路由服务 | 常见于采用多上游和路由优化的 IDC；最终质量取决于目标 PoP、实际上游、BGP 策略和回程 |
| `AS7578` | Global Secure Layer Access、GSL | GSL 运营的另一 ASN；PeeringDB 当前将其网络类型标为 Content | 不应与 `AS137409` 无条件合并成同一种 Transit。先看前缀由哪个 AS 起源、路径中谁提供 Transit，再判断网络角色 |

官方或运营者资料：[Lumen AS3356](https://www.lumen.com/en-us/services/lumen-defender.html)、[RETN 欧亚网络](https://retn.net/)、[NTT AS2914](https://www.gin.ntt.net/)、[SoftBank AS17676](https://www.softbank.jp/business/service/network/smart-internet/lineup/dc-connect-s)、[Cogent IP Transit](https://www2.cogentco.com/files/docs/network/on_net/brochure_ip_transit.pdf)、[GTT AS3257](https://www.gtt.net/services/managed-networking/internet/)、[Arelion AS1299](https://www.arelion.com/resources/guides/what-is-as1299)、[HE 对等策略](https://www.he.net/peering.html)、[PCCW Global AS3491](https://www.consoleconnect.com/help/tools/)、[GSL AS137409](https://www.peeringdb.com/net/16620)、[GSL AS7578](https://www.peeringdb.com/net/7562)。

### 5.2 日本方向补充

| ASN | 网络 | 识别用途 |
|---:|---|---|
| `AS2497` | IIJ Global Backbone | IIJ 的日本全国及全球骨干。IIJ 官方将其作为日本方向 IP Transit 的主要网络 |
| `AS2516` | KDDI | KDDI 的主要互联网骨干 ASN 之一，日本和亚太路由中常见 |

日本方向还会看到 NTT 的其他接入 ASN、KDDI 体系 ASN、地区电信运营商和本地 IX 路由。不要把“日本公司 ASN”自动解释为日本住宅 IP，也不要把某个日本上游自动解释为对中国三网都有优化。

参考：[IIJ AS2497](https://www.iij.ad.jp/en/svcsol/service-providers/)、[KDDI/AS2516 PeeringDB](https://www.peeringdb.com/net/1022)。

### 5.3 关于 Tier 1、Tier 2 和价格

“Tier 1”通常指无需购买 IP Transit、可通过无结算对等到达整个互联网的网络，但互联网没有统一机构给运营商颁发或持续维护 Tier 名单。运营商自述、行业数据库和不同观察者的分类可能不同。

因此本文只在运营商明确自称时记录 Tier 1，不把 Tier 当作质量排名。以下结论都不能从 Tier 或 ASN 单独推出：

- 某地区一定低延迟或不拥塞。
- 与中国三大运营商一定直接互联。
- 去程和回程一定使用同一上游。
- 零售 VPS 获得了上游的完整带宽或最高优先级。
- IP 是住宅、商用宽带还是数据中心类型。
- Netflix、ChatGPT 等平台一定可用；这还取决于 IP 前缀、地理库、信誉和平台策略。

## 6. 国外 VPS 线路选型

采购目标应写成可验证条件，而不是只接受商家标签。

| 目标用户 | 高质量路径的常见信号 | 仍需确认 |
|---|---|---|
| 电信用户 | 大陆和跨境关键段持续出现 `AS4809`；供应商明确提供 CN2/GIA | 去程、回程、接入城市、带宽保证、晚高峰；出现 `AS4809` 不自动等于 GIA |
| 联通用户 | 大陆关键段出现 `AS9929`；海外可能经 `AS10099` 接入 | 是否只有单向 9929、是否转 `AS4837`、晚高峰表现 |
| 移动用户 | 跨境关键段出现 `AS58807`；普通优化常见 `AS58453` | 大陆 `AS9808` 衔接、双向路径、地区覆盖和晚高峰 |
| 三网用户 | 三个运营商分别提供明确的优化回程，且有多地测试 | “三网优化”不是标准化产品，必须逐网逐方向测试 |
| 大流量下载 | 普通 ChinaNet/CUG/CMI 或普通三网 BGP，带宽和流量充足 | 不要用精品 ASN 名称替代带宽、流量和拥塞测试 |

路由中出现目标 ASN 是必要信号之一，但不是质量保证。反过来，某跳因 MPLS 或 ICMP 不显示目标 ASN，也不能仅凭 traceroute 断言它完全没有经过对应承载网。

## 7. 验证方法

### 7.1 查登记主体

```bash
for asn in AS4134 AS4809 AS23764 AS4837 AS9929 AS10099 AS9808 AS58453 AS58807; do
  whois -h whois.apnic.net "$asn" \
    | grep -E '^(aut-num|as-name|descr|country):'
done
```

也可以查 RIPEstat 和 PeeringDB；前者适合查看观测到的路由信息，后者是网络运营者自行维护的互联资料。它们与 APNIC WHOIS 的用途不同。

```bash
curl -s 'https://stat.ripe.net/data/as-overview/data.json?resource=AS4809'
curl -s 'https://www.peeringdb.com/api/net?asn=58453'
```

### 7.2 测去程和回程

至少从目标用户所在运营商、所在区域测去程：

```bash
traceroute -n <VPS_IP>
mtr -nrzbw -c 100 <VPS_IP>
```

再从 VPS 测回中国大陆的电信、联通和移动测试 IP。不要用同一个目标代表三网，也不要把本机到 VPS 的 traceroute 当作回程。

记录以下信息：

- 测试时间、源城市、源运营商和目标地址。
- 去程与回程的 AS Path、跨境城市和明显绕路。
- 平峰与晚高峰的延迟、抖动、丢包和实际吞吐。
- ICMP 丢包是否延续到后续跳和终点；单个中间路由器不回 ICMP 不等于转发丢包。
- 商家承诺的线路、方向、带宽、流量和 SLA，而不只是商品标题。

### 7.3 判断模板

建议把结论写成：

```text
2026-07-20 21:00 CST，从上海电信到该 VPS 的去程在大陆和跨境关键段观察到
AS4809；VPS 回上海电信的回程也观察到 AS4809。晚高峰 100 次 MTR 的终点
丢包为 0%，平均延迟为 <VALUE> ms。该结果与双向 CN2 路径一致，但仅凭路由
不能独立证明商家的 GIA 合同等级或长期带宽保证。
```

不要写成：

```text
检测到 AS4809，所以一定是双向 CN2 GIA，且永不拥塞。
```

## 8. 常见误区

- “163”是 `AS4134` ChinaNet 的俗称，不是 `AS163`。
- `AS4134` 和 `AS4837` 不只负责国内；它们都有国际可达和跨境互联能力。
- CN2 是承载网，GIA 是基于 CN2 的企业互联网接入产品；二者不能直接画等号。
- `AS4809` 与 `AS4134`、`AS9929` 与 `AS4837` 可以理解为同一运营商内定位不同的骨干网，但这不意味着任何经过前者的零售 VPS 都获得同等级质量。
- `AS10099` 是联通国际网络，不是 `AS9929`；路径出现前者不保证大陆段进入后者。
- `AS9808` 属于中国移动大陆网络；`AS58453` 和 `AS58807` 属于中国移动国际。它们不是与电信、联通完全对称的三列映射。
- CMI 通常对应 `AS58453`，CMIN2 服务通常对应 `AS58807`；仍应把服务名与 ASN、实际路径、合同等级分开验证。
- 省网 ASN 主要帮助定位接入和落地位置，不代表单独售卖的精品线路。
- AS Path 相同不代表物理路径、QoS、带宽和拥塞程度相同。
