# 系统设计入门(方法论 + 经典题型)

> **写给**:4 年 Java 后端、做过 SI/ASP/PI 复杂项目的你
> **目的**:把你**已有的项目经验**抽象成**系统设计语言**,从"做了"到"会讲会设计"
> **价值**:**P7+ 必备**(P6 之前可能是被问"项目经验",P7 起会被问"如果让你设计一个 X 怎么做")

标签:`[P7加分]`⭐⭐ `[需要积累]`⏳ `[国内大厂]` `[外企友好]` `[与你项目]`🔗

---

## 0. 你的水位 + 为什么这块需要长期积累

### 0.1 你的水位

| 维度 | 你的水位 |
|---|---|
| **设计过模块**(< 1 个服务) | ✅ 多次 |
| **设计过子系统**(几个服务协作) | ✅ ASP @RedisLock 公共组件 / SI Driver Hub |
| **设计过整个系统** | ⚠️ 没主导过从 0 到 1(PI 重构是反向工程) |
| **画过架构图**(C4 / Sequence) | ⚠️ 你工程内有 mtp-core / PI 的图,可继续 |
| **能讲清"我为什么这样设计"** | ⚠️ 看具体题 |

### 0.2 ⭐⭐ 为什么这块"需要积累"

**系统设计**不是看一本书就能学会,**靠的是**:
1. **看大量案例**(看 50-100 个真实系统怎么设计的)
2. **自己练习**(每周 1 题,白板画图)
3. **真实落地**(在工作里主导一个设计 + 复盘)

> 我能给你的是**方法论 + 经典题型骨架**,**不能替你练**。

---

## 1. ⭐⭐ 系统设计 7 步方法论 `[必背]`

> 任何系统设计题(面试 / 工作)都按这 7 步走,**不要乱**。

### Step 1. Clarify Requirements(澄清需求)5min

> **新人最大的坑**:听完题就开始画图。

**功能需求**:
- 核心场景是什么?(读多写少 / 写多读少 / 实时性?)
- 用户量级?并发量?
- 必须支持的功能?可选功能?

**非功能需求**:
- 可用性(SLA 99.99%?)
- 一致性(强 / 最终)
- 延迟(P99 < 100ms?)
- 数据规模(总量 / 增量)
- 安全 / 合规

> **示例题**(设计短链系统):
> - 写 / 读比例?(假设 1:100)
> - 日活? 1 亿用户每天生成 1 亿短链 → 每秒 ~1100 写
> - 短链长度?6-8 字符
> - 短链有效期?永久 or 7 天?

### Step 2. Capacity Estimation(容量估算)5min

| 维度 | 公式 |
|---|---|
| **QPS** | 日活 × 人均请求 / 86400 |
| **峰值 QPS** | 平均 × 3-5 倍 |
| **存储** | 数据量 × 单条 size × 时间 |
| **带宽** | QPS × 单条 size × 8(转 bit) |

> **数量级感**:
> - 1 亿条 × 100 字节 = 10 GB
> - 100 万 QPS / 单机 1 万 QPS = 100 台

### Step 3. API 设计 5min

```
POST /short
  body: { url: "..." }
  → { shortKey: "abc123" }

GET /short/{shortKey}
  → 302 Location: <original_url>
```

### Step 4. Data Model(数据模型)5min

```
CREATE TABLE short_url (
    short_key VARCHAR(8) PRIMARY KEY,
    original_url VARCHAR(2048),
    created_at DATETIME,
    expire_at DATETIME,
    creator_id BIGINT,
    INDEX idx_creator (creator_id, created_at)
);
```

讨论:
- SQL or NoSQL?
- 分库分表怎么分?
- 一致性 / 索引 / 缓存

### Step 5. High-Level Design(整体架构)10min

```
[Client] → [LB] → [API Gateway] → [Service Cluster] → [Cache Layer] → [DB]
                                          ↓
                                    [Async Queue] → [Worker]
```

**核心组件**:
- 负载均衡(LB)
- 网关 / API
- 业务服务(无状态)
- 缓存(Redis)
- 数据库(MySQL / PG)
- 消息队列(Kafka)
- 异步任务(Worker)
- CDN(静态资源)

### Step 6. Detailed Design(详细设计)15min

**针对 1-2 个核心模块深入**:
- 算法:短链生成怎么避免冲突?(发号器 / Hash / Base62)
- 数据库:分库分表怎么做?
- 缓存:LRU?TTL?击穿/雪崩?
- 一致性:最终?读写延迟?

### Step 7. Trade-offs / Bottlenecks / Future Work 5min

> 没有完美方案,**说出取舍**才显成熟。

- 我牺牲了什么?(成本?延迟?复杂度?)
- 哪里是瓶颈?
- 如果用户量再 10 倍?

---

## 2. ⭐ 系统设计的"思维武器库"

### 2.1 ⭐⭐ 核心架构模式

| 模式 | 解决问题 | 例子 |
|---|---|---|
| **微服务** | 大单体难维护 | 订单 / 支付 / 用户 拆分 |
| **CQRS** | 读写差异大 | 写 MySQL + 读 ES |
| **Event Sourcing** | 审计 / 时间回溯 | 银行流水 |
| **Saga** | 分布式事务长流程 | 跨服务订单流程 |
| **Circuit Breaker** | 依赖不稳定 | Hystrix / Sentinel |
| **Bulkhead** | 隔离故障域 | 线程池隔离 |
| **Sidecar** | 通用能力下沉 | Service Mesh / Envoy |

### 2.2 ⭐⭐ 数据存储选型

| 类型 | 适用 | 例子 |
|---|---|---|
| **关系型** | 强一致 / 事务 | MySQL / PG |
| **文档型** | 半结构化 / 灵活 schema | MongoDB |
| **KV** | 简单查询 / 高吞吐 | Redis / RocksDB |
| **时序** | 监控 / IoT | InfluxDB / TimescaleDB |
| **搜索** | 全文 / 复杂查询 | Elasticsearch |
| **图** | 关系网络 | Neo4j |
| **列式** | 分析 / OLAP | ClickHouse / HBase |

### 2.3 ⭐ 缓存策略

| 策略 | 描述 |
|---|---|
| **Cache-Aside** | 应用读 cache miss → 读 DB → 写 cache(最常用) |
| **Read-Through** | 应用读 cache,cache 自己查 DB |
| **Write-Through** | 应用写 cache,cache 写 DB(同步) |
| **Write-Back** | 应用写 cache,cache 异步写 DB(高性能,可能丢) |

🔗 你 ASP 的 cache-cli + cache-server 是 **Read-Through** + 分布式锁。

### 2.4 ⭐ 一致性

| 一致性 | 描述 | 例子 |
|---|---|---|
| **强一致** | 写后立刻能读到 | MySQL 主库 |
| **最终一致** | 一段时间后同步 | 主从复制 |
| **因果一致** | 有因果关系的操作有序 | Vector Clock |
| **会话一致** | 同会话内一致 | Redis 主写主读 |

### 2.5 ⭐ CAP / BASE / PACELC

> PDF p.83 已经讲过 CAP / BASE,补 **PACELC**:
>
> **PACELC** = "**P**artition-时 选 **A** vs **C**;**E**lse(正常时)选 **L**atency vs **C**onsistency"
>
> 例子:
> - **MySQL** = PC/EC(故障时也保 C,正常也保 C)→ 重一致
> - **Cassandra / DynamoDB** = PA/EL(故障时保 A,正常追求低延迟)→ 重可用

---

## 3. ⭐⭐⭐ 8 个经典系统设计题(骨架)

> 每题给你**思考骨架**,自己练时**按 §1 的 7 步走**。

### 3.1 设计短链系统(TinyURL)

**关键决策**:
- 短链算法:**发号器 + Base62**(推荐) vs Hash(冲突难处理)
- 存储:KV(Redis) + DB(MySQL,持久化)
- 容量:1 亿日新增 → 6 字符 Base62(~568 亿组合)够 N 年

### 3.2 设计朋友圈 / Feed 流

**关键决策**:
- **推 Pull vs 推 Push vs 混合**(微博就是混合)
- 大 V 怎么处理?(单独路由,异步推送)
- 存储:Redis ZSet(按时间) + MySQL(冷数据)

### 3.3 设计抢红包 / 秒杀

**关键决策**:
- **库存预扣 + Lua 原子** + Redis
- 异步落库(MQ)
- 限流(令牌桶 / 漏桶)
- 防重(幂等 token)
- 🔗 你的 ASP @RedisLock 在这里就有用武之地

### 3.4 设计推送系统(IM 消息)

**关键决策**:
- **长连接**:WebSocket 或 TCP 自定义
- 消息可达:ACK + 重试 + 离线消息
- 群消息:**写扩散**(给每人存)vs **读扩散**(读时拉)
- 🔗 你 SI 的 Zero Engine 是事件驱动,有相通

### 3.5 设计排行榜

**关键决策**:
- Redis ZSet(score = 分数,member = 用户)
- 实时榜 / 日榜 / 周榜:多 ZSet + key 包含日期
- 大量用户:分桶 + 合并

### 3.6 设计分布式 ID 生成器

> PDF p.93 已讲(雪花算法 / Leaf / 号段)。简化:

**方案**:
- **Snowflake**:64 位 = 时间戳 + 机器 ID + 序列号(主流)
- **号段模式**(美团 Leaf):DB 取号段,内存分配
- **TDDL Sequence**(阿里):多步进 + 多实例

### 3.7 设计监控告警系统

**关键决策**:
- 时序数据库(InfluxDB / Prometheus)
- 数据采集(Pull vs Push)
- 告警规则引擎
- 通知通道(邮件 / 短信 / IM)
- 🔗 你 SI / ASP 都用过 Prometheus + ELK,可讲

### 3.8 设计文件存储 / 网盘

**关键决策**:
- 大文件分片上传 + 续传
- 秒传(MD5 去重)
- 元数据(MySQL) + 文件(对象存储 S3 / OSS)
- CDN 加速下载

---

## 4. ⭐ 你已有项目映射到系统设计语言 `[与你项目]`🔗

> **价值**:面试时被问"设计 X",**你能用项目经验回答**而不是空想。

### 4.1 SI Zero Engine → 设计实时数据采集 + 分发系统

**你能讲**:
- 多协议接入(SNMP / Modbus / BACnet)→ Driver Hub
- 实时计算(Flink Job)
- 事件驱动(ITopic / Kafka)
- 高可用(Hazelcast 集群)
- 横向扩展(支持任意品牌设备 = 插件化)

### 4.2 ASP 全业务支持平台 → 设计多业务整合中台

**你能讲**:
- 数据接入层(CRM / BRM 多业务中心)
- 微服务拆分(order / query / manage / shopmgr)
- 中间件(dbproxy / 网关 / 缓存)
- 业务编排(Activiti BPM + Drools 规则引擎)
- 复杂场景(成员调度跨平台)

### 4.3 PI 4.0 重构 → 设计大版本依赖升级 + 反向工程

**你能讲**:
- 用 Python 写 ETL 工具(MongoDB → PG)
- 兼容性矩阵(Java 8 → 21 / Spring 2 → 3 / Hazelcast 3 → 5)
- 风险评估(决策级 / 架构级 / 工程级)
- 迁移策略(灰度 / 回滚)

### 4.4 ⭐ "请设计一个分布式锁" → 你直接用 ASP @RedisLock

> 你**已经做过**,这是**最强项目题**(很多候选人只能讲 Redisson 的用法)。
>
> 详见 [`projects/asp-platform.md` §4.4](../_curated/projects/asp-platform.md)

---

## 5. ⭐ 6 个面试时的"加分话术"

| 时机 | 话术 |
|---|---|
| 听完题先 | "Let me clarify requirements first..." |
| 估算时 | "Let's estimate the scale to inform our design..." |
| 选方案时 | "There are 2-3 approaches. Approach A is X with trade-off Y..." |
| 不确定时 | "I'm not 100% sure, but I'd lean towards X because..." |
| 收尾时 | "Given more time, I'd also consider..." |
| 被挑战时 | "That's a great point. Let me reconsider..." |

> 🔗 **结合 L 反馈**:**英文表达 + 沟通理论化**就是这一节的实战场景。

---

## 6. ⭐ 学习路径(建议)

### 6.1 入门(1-2 个月)

- 读 **System Design Primer**(GitHub 开源,中文版)
- 看 **Hello Interview** 视频(免费,Meta 工程师讲)
- 每周 1 题,**自己白板画 + 录视频自评**

### 6.2 进阶(3-6 个月)

- 看真实公司架构博客(High Scalability / 阿里淘系 / 字节技术)
- 在工作里**主动找 1 个机会主导设计**(把它作为简历亮点)

### 6.3 高阶(长期)

- 读 **DDIA(Designing Data-Intensive Applications)** —— 后端设计圣经
- 跟开源大型项目(Kafka / Flink / TiDB)看架构文档

---

## 7. 推荐资源

| 资源 | 备注 |
|---|---|
| **System Design Primer** GitHub | https://github.com/donnemartin/system-design-primer |
| **DDIA(数据密集型应用系统设计)** | **必读,封神之作** |
| **Hello Interview 视频** | YouTube,免费,质量高 |
| **High Scalability 博客** | http://highscalability.com/ |
| **《微服务架构设计模式》** Chris Richardson | 微服务专题 |
| **极客时间《从 0 开始学架构》** 李运华 | 国内方法论 |

---

## 8. 🎯 自检清单(看完该会的)

- [ ] 听到任何题能用 7 步走流程
- [ ] 能做容量估算(QPS / 存储 / 带宽)
- [ ] 能选数据库(SQL / NoSQL / KV / 时序 / 搜索)
- [ ] 能选缓存策略(4 种)
- [ ] 能讲 CAP / BASE / PACELC
- [ ] 能用项目经验回答 §4 的 4 个题
- [ ] 能在白板上画完整架构图(LB / Gateway / Service / Cache / DB / MQ)
- [ ] 能讲 trade-offs 而不是说"我选这个就最好"

---

> 📌 **回到** [`00-skill-roadmap.md`](./00-skill-roadmap.md) 看完整体系
