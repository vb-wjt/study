# 网络基础(TCP / HTTP / HTTPS / WebSocket)

> **写给**:做后端但**网络没专门学过**的你
> **目的**:补 Java 后端必备的网络知识 → 接口排查 / 性能调优 / 面试基础题
> **配套**:你工程里 `file/3-tech_stack/protocol/websocket/basic.md` (318 行) + `deep-dive-interview.md` 已有 WebSocket 素材

标签:`[P6基线]`⭐⭐ `[盲点]`⚠️(工程内没系统总结) `[国内大厂]`

---

## 0. 你的水位

| 概念 | 你的水位 |
|---|---|
| HTTP 状态码 / 方法 / Header | ✅ 日常 |
| **TCP 三次握手 / 四次挥手** | ⚠️ 知道概念,**说不清细节** |
| **TIME_WAIT / CLOSE_WAIT** | ❌ 排查过吗? |
| **HTTP 1.x / 2 / 3 区别** | ⚠️ |
| **HTTPS 握手 / SSL/TLS** | ❌ |
| **WebSocket 协议升级** | ✅ 你工程已写 |
| **CDN / DNS / 反向代理** | ⚠️ |

---

## 1. ⭐⭐⭐ TCP `[P6基线]`

### 1.1 三次握手

```
Client                                Server
  │                                     │
  │  ─────── SYN, seq=x ─────────→     │   (Client: SYN_SENT)
  │                                     │
  │  ←───── SYN+ACK, seq=y, ack=x+1 ──  │   (Server: SYN_RCVD)
  │                                     │
  │  ───────── ACK, ack=y+1 ─────→     │   (Both: ESTABLISHED)
```

**为什么 3 次?**
- 1 次:客户端发了 → 服务端不知道客户端能不能收
- 2 次:服务端回了 → 客户端不知道服务端能不能再收(可能 ACK 丢)
- **3 次**:**双方都确认了"能发能收"**

### 1.2 ⭐⭐ 四次挥手

```
Client                                Server
  │                                     │
  │  ─────── FIN, seq=x ─────────→     │   (Client: FIN_WAIT_1)
  │                                     │
  │  ←─────── ACK, ack=x+1 ──────       │   (Client: FIN_WAIT_2 / Server: CLOSE_WAIT)
  │                                     │
  │       (Server 处理剩余数据)          │
  │                                     │
  │  ←─────── FIN, seq=y ────────       │   (Server: LAST_ACK)
  │                                     │
  │  ─────── ACK, ack=y+1 ───────→     │   (Client: TIME_WAIT 2MSL → CLOSED / Server: CLOSED)
```

### 1.3 ⭐⭐⭐ TIME_WAIT 和 CLOSE_WAIT(实战必懂)

#### TIME_WAIT(主动关闭方)

**为什么要 2MSL?**(MSL = 报文最大生存时间,通常 60s,所以 TIME_WAIT 通常 60s 或 120s)
1. **保证最后的 ACK 能到达**:Server 没收到 ACK 会重发 FIN,这时 Client 还能再 ACK
2. **让本次连接的所有报文消亡**,避免与新连接混淆

**坑**:**短连接 + 主动关闭** → 大量 TIME_WAIT 占满端口
```bash
# 排查
netstat -an | grep TIME_WAIT | wc -l

# 优化(谨慎,有副作用)
net.ipv4.tcp_tw_reuse = 1       # 允许复用 TIME_WAIT 端口
net.ipv4.tcp_tw_recycle = 0     # ⚠️ 4.12+ 已删除,有 NAT 问题
```

#### CLOSE_WAIT(被动关闭方)

**正常**:Server 收到 FIN 进入 CLOSE_WAIT → 应用层 close() → 进入 LAST_ACK
**异常**:**CLOSE_WAIT 堆积 = 应用层没 close()** → **代码 bug**(没 finally 关连接)

```bash
netstat -an | grep CLOSE_WAIT | wc -l   # 大量 = 检查代码资源关闭
```

### 1.4 流量控制 vs 拥塞控制

| 概念 | 解决什么 | 怎么做 |
|---|---|---|
| **流量控制** | 接收方处理不过来 | 滑动窗口(`rwnd`) |
| **拥塞控制** | 网络拥堵 | 慢启动 / 拥塞避免 / 快重传 / 快恢复 |

### 1.5 🎯 面试可讲

> "TCP 三次握手是为了双方都确认能发能收。四次挥手是因为关闭是单向的,Server 收到 FIN 后可能还有数据要发。TIME_WAIT 在主动关闭方,2MSL 是为了保证最后 ACK 能到达 + 让旧报文消亡。CLOSE_WAIT 在被动关闭方,堆积通常是应用层没 close 资源,是代码 bug。"

---

## 2. ⭐⭐ HTTP 协议 `[P6基线]`

### 2.1 HTTP 1.x

#### 1.0 → 1.1 主要变化
- **Keep-Alive**(默认开启,连接复用)
- **管道化**(Pipelining,可发多个请求,但**响应仍要按序**)
- **Host 头**(支持虚拟主机)
- **分块传输**(Chunked Transfer-Encoding)

#### 1.1 的痛点
- **队头阻塞(HoL)**:管道化后响应必须按序 → 一个慢响应阻塞后续
- **Header 冗余**:每次请求 Header 都重复发

### 2.2 ⭐ HTTP/2(2015)

**核心改进**:
1. **二进制分帧**(代替文本)
2. **多路复用**:一个连接上多个流并行 → **解决队头阻塞**
3. **Header 压缩**(HPACK 算法,字典编码)
4. **服务端推送**(Server Push,实践中很少用)
5. **优先级**(流可以设权重)

> 但 HTTP/2 在 **TCP 层仍有队头阻塞**(TCP 丢包会阻塞所有流)。

### 2.3 ⭐ HTTP/3(2022 RFC)

**核心改进**:**底层从 TCP 换成 QUIC(基于 UDP)**
1. **真正解决队头阻塞**(QUIC 流独立)
2. **0-RTT / 1-RTT 握手**(更快)
3. **连接迁移**(IP 切换不断连)

### 2.4 ⭐ 状态码必背

| 类型 | 例子 |
|---|---|
| **2xx** | 200 OK / 201 Created / 204 No Content |
| **3xx** | 301 永久重定向 / 302 临时 / 304 Not Modified(缓存) |
| **4xx** | 400 / 401 未鉴权 / 403 鉴权失败 / 404 / 409 冲突 / 429 太多请求 |
| **5xx** | 500 / 502 网关 / 503 不可用 / 504 网关超时 |

#### 易混淆题
- **401 vs 403**:401 = "你是谁?(没登录)"; 403 = "我知道你是谁,但你没权限"
- **301 vs 302**:301 = 永久(SEO 友好,浏览器缓存);302 = 临时

### 2.5 GET vs POST(经典坑题)

| 维度 | GET | POST |
|---|---|---|
| **语义** | 获取 | 提交 |
| **参数位置** | URL Query | Body |
| **幂等** | ✅ | ❌(默认) |
| **可缓存** | ✅ | ❌ |
| **长度限制** | URL 长度限制(浏览器 ~2KB) | 理论无限 |
| **是否安全** | 都看 HTTPS,**不是 GET vs POST 的事** |

> ⚠️ **坑**:很多人说 "GET 比 POST 不安全",**这是错的** —— 安全靠 HTTPS,不是方法。

---

## 3. ⭐⭐ HTTPS / SSL/TLS `[P6基线]`

### 3.1 HTTPS = HTTP + TLS

```
HTTP                ← 应用层
TLS                 ← 加密层(夹在 HTTP 和 TCP 之间)
TCP                 ← 传输层
```

### 3.2 ⭐ TLS 握手(简化版,1.2)

```
Client                                Server
  │                                     │
  │  ─── ClientHello (随机数1, 算法套件) ─→ │
  │  ←── ServerHello (随机数2, 选定套件)─── │
  │  ←──── Server Certificate ──────── │  (CA 签发的证书)
  │  ←──── ServerHelloDone ─────────── │
  │                                     │
  │  (验证证书 → 生成预主密钥 → 用证书公钥加密)
  │  ───── ClientKeyExchange ───────→  │
  │                                     │
  │  双方用 随机数1 + 随机数2 + 预主密钥 → 生成会话密钥(对称)
  │                                     │
  │  ───── ChangeCipherSpec ────────→  │
  │  ←──── ChangeCipherSpec ──────── │
  │                                     │
  │  (后续都用对称密钥加密)              │
```

### 3.3 ⭐ TLS 1.3 改进

- **1-RTT**(代替 1.2 的 2-RTT)
- **0-RTT 重连**(用之前的 PSK 直接发数据,有重放风险)
- **强制 PFS**(完美前向保密)
- **简化算法套件**

### 3.4 ⭐ 对称 + 非对称的混合

| 阶段 | 用什么 | 为什么 |
|---|---|---|
| **握手协商密钥** | 非对称(RSA / ECDHE) | 安全性高 |
| **数据传输** | 对称(AES) | 性能高 |

> **不直接用非对称加密所有数据** = 因为非对称太慢(性能 100-1000 倍差距)。

### 3.5 🎯 面试可讲

> "HTTPS 是 HTTP + TLS,TLS 握手用非对称加密协商出会话密钥,后续用对称加密传数据 —— 因为对称加密性能远高于非对称。TLS 1.2 是 2-RTT,1.3 优化到 1-RTT 还支持 0-RTT 重连。证书的作用是绑定公钥和域名,通过 CA 信任链验证。"

---

## 4. ⭐ WebSocket `[与你项目]`🔗(已有素材)

> 你工程已有 `file/3-tech_stack/protocol/websocket/basic.md` (318 行) 和 `deep-dive-interview.md` (158 行) —— 这里只补**面试关键 5 点**:

### 4.1 协议升级流程

```
Client → HTTP Upgrade Request:
  GET /chat HTTP/1.1
  Connection: Upgrade
  Upgrade: websocket
  Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
  Sec-WebSocket-Version: 13

Server → 101 Switching Protocols:
  HTTP/1.1 101 Switching Protocols
  Connection: Upgrade
  Upgrade: websocket
  Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

### 4.2 帧格式

WebSocket 是**帧式协议**,每帧有 opcode(text/binary/ping/pong/close)和 payload。

### 4.3 心跳

应用层 ping/pong(`opcode=0x9 / 0xA`),保持连接活跃,排除中间网络设备(LB / NAT)断连。

### 4.4 ⭐ WebSocket vs SSE vs Long Polling

| 协议 | 方向 | 适用 |
|---|---|---|
| **WebSocket** | 全双工 | IM / 实时游戏 / 实时数据推送 |
| **SSE** (Server-Sent Events) | 服务端 → 客户端单向 | 通知 / 股票推送 |
| **Long Polling** | 模拟双向 | 兼容老浏览器 |

### 4.5 🔗 结合你项目

PDF p.36-37 提到"导出大数据用 WebSocket 通知用户" —— 这是典型场景。SI 项目里也有实时数据推送可能用类似机制。

---

## 5. ⭐ DNS / CDN / 反向代理(快速过)`[长尾]`

### 5.1 DNS 解析过程

```
浏览器缓存 → OS 缓存 → 路由器缓存 → 本地 DNS(运营商)
   → 根 DNS(.) → 顶级 DNS(.com) → 权威 DNS(example.com)
```

### 5.2 CDN

**作用**:**就近返回静态资源**,减少回源次数。
**关键**:DNS 解析返回 CDN 边缘节点 IP(GeoDNS / Anycast)。

### 5.3 反向代理(你 Vertiv 用 Nginx)

| 维度 | 正向代理 | 反向代理 |
|---|---|---|
| **代理对象** | 客户端 | 服务端 |
| **典型场景** | 翻墙 / 公司出网 | Nginx / LB / CDN |

---

## 6. 🎯 高频面试题

| # | 题 | §位置 |
|---|---|---|
| 1 | 三次握手 / 四次挥手 | §1.1 / §1.2 |
| 2 | TIME_WAIT 为什么是 2MSL | §1.3 |
| 3 | CLOSE_WAIT 堆积怎么排查 | §1.3 |
| 4 | HTTP/1.1 / 2 / 3 区别 | §2.1-§2.3 |
| 5 | 401 vs 403 / 301 vs 302 | §2.4 |
| 6 | GET vs POST(易混淆) | §2.5 |
| 7 | TLS 握手流程 | §3.2 |
| 8 | 为什么对称 + 非对称混合 | §3.4 |
| 9 | WebSocket 升级流程 | §4.1 |

---

> 📌 **下一步**:[`testing-and-engineering.md`](./testing-and-engineering.md)
