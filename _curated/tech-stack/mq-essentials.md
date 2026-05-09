# 消息队列(MQ)核心:三大问题 + Kafka / RocketMQ

> **写给**:用过 Kafka 或类似 MQ 的你
> **目的**:**会用 → 懂三大问题 → 选型有理由**
> **配套**:`Java Study.pdf` p.83-87 已讲消息事务 + 最大努力通知,本文补**通用 MQ 三大问题 + 主流产品对比**

标签:`[P6基线]`⭐⭐ `[与PDF重叠]`📚 `[国内大厂]` `[与你项目]`🔗(ASP 用 Kafka 配合日志)

---

## 0. 你的水位

| 概念 | 你的水位 | P6 基线 |
|---|---|---|
| MQ 基本概念(Producer / Consumer / Topic) | ✅ | ✅ |
| 你用过的 MQ:**Kafka(ASP)/ ActiveMQ(Vertiv)** | ✅ | ✅ |
| **可靠性 / 顺序 / 重复 三大问题** | ⚠️ 听过没系统理解 | ❌ |
| **Kafka vs RocketMQ vs RabbitMQ 选型** | ❌ | ❌ |
| **消费者组 / Partition / Offset** | ⚠️ | ❌ |
| **Kafka 高吞吐原因(顺序写 / 零拷贝 / 批量)** | ❌ | ⚠️(P7+ 必备) |

---

## 1. ⭐⭐⭐ MQ 三大问题(必考)`[P6基线]`

### 1.1 问题一:消息可靠性(不丢)

```
Producer ──→ Broker ──→ Consumer
   ⚠️           ⚠️         ⚠️
  发送丢       存储丢       消费丢
```

#### 三个环节都要保

##### Producer 端(发送不丢)

| 方案 | 含义 |
|---|---|
| **同步发送 + 确认** | `producer.send(msg).get()` 阻塞等 ACK |
| **异步发送 + Callback** | 异步,失败回调里补偿 |
| **本地消息表 / 事务消息**(更强) | 业务事务 + 发消息原子 |

##### Broker 端(存储不丢)

| 方案 | 含义 |
|---|---|
| **持久化** | Kafka:`acks=all` + `min.insync.replicas=2` |
| **副本机制** | Kafka 多副本 + ISR;RocketMQ 主从同步 |
| **刷盘策略** | 同步刷盘(慢但安全) vs 异步刷盘 |

##### Consumer 端(消费不丢)

| 方案 | 含义 |
|---|---|
| **手动提交 offset** | 业务处理完再 commit(autoCommit=false) |
| **幂等消费** | 即使消息重发也不出问题(见 §1.3) |

### 1.2 ⭐ 问题二:消息顺序

#### 全局顺序(很难,代价大)
- **单分区 / 单队列** + **单消费者**
- 吞吐量低,几乎不用

#### **业务有序**(常用)
- 按业务 key(如订单 ID)路由到同一分区
- **分区内有序**,跨分区无序
- Kafka:`producer.partitioner.class` 自定义 / 使用 key
- RocketMQ:`MessageQueueSelector`

#### 经典坑:消费者多线程会乱序
```java
// ❌ 乱序
@KafkaListener
public void onMsg(ConsumerRecord r) {
    threadPool.submit(() -> handle(r));  // 多线程并发 → 乱序
}

// ✅ 有序
// 按 key hash 到内部队列,每个队列单线程处理
```

### 1.3 ⭐ 问题三:消息重复(幂等性)

#### 重复的根因
- Producer 重试:发送成功但 ACK 丢失 → 重发
- Broker 故障:Consumer 拉了消息但没 commit offset
- 网络抖动 / 超时

#### 幂等消费方案

| 方案 | 含义 | 适用 |
|---|---|---|
| **数据库唯一索引** | 业务表加唯一约束(订单号 + 状态) | 简单 |
| **Redis SETNX** | 消费前 setnx 消息 ID,过期回收 | 高并发 |
| **状态机** | 状态变更只走合法路径(订单 PAID 后再收到 PAID 直接忽略) | 业务相关 |
| **Token / Version** | 业务对象版本号 + CAS | 通用 |

### 1.4 🎯 面试可讲

> "MQ 三大问题:可靠性、顺序、重复。可靠性要 Producer + Broker + Consumer 三端都保 —— Producer 同步确认,Broker 多副本 + 同步刷盘,Consumer 手动提交 offset。顺序一般不追求全局,而是按业务 key 路由到同一分区做局部有序。重复消费的根本解决方案是消费端幂等,常用方案是数据库唯一索引、Redis SETNX、状态机。"

---

## 2. ⭐⭐ Kafka 核心架构 `[P6基线]` `[国内大厂]`

### 2.1 核心概念

```
Producer ──→ Topic ──→ Consumer Group
                ↓
        ┌───────────────┐
        │  Partition 0  │ ← Leader (Broker A) + Followers (B, C) → ISR
        │  Partition 1  │
        │  Partition 2  │
        └───────────────┘
            ↓
     每个 Partition 是有序追加日志
```

| 概念 | 含义 |
|---|---|
| **Topic** | 消息类别(逻辑) |
| **Partition** | Topic 物理分片,**最小并行单位** |
| **Replica** | 副本,Leader + Followers |
| **ISR**(In-Sync Replicas) | 与 Leader 同步的副本集合 |
| **Consumer Group** | 一组消费者协作消费一个 Topic |
| **Offset** | 消费者在 Partition 内的位置 |

### 2.2 ⭐⭐ 为什么 Kafka 高吞吐?

> **P7+ 必备题**。

1. **顺序写磁盘**(磁盘顺序写 > 内存随机写) → Partition 是追加日志
2. **零拷贝(sendfile)**:消息从 PageCache 直接发到网卡,跳过用户态
3. **批量 + 压缩**:Producer 攒批 + Snappy/LZ4 压缩
4. **PageCache 利用**:Broker 不维护堆内缓存,依赖 OS PageCache(对 GC 友好)
5. **分区并行**:每个 Partition 独立并行

### 2.3 ⭐ Consumer Group 平衡(Rebalance)

**触发**:Consumer 加入 / 离开 / 心跳超时
**过程**:**Stop the World** —— 期间所有消费者停消费,直到分区重新分配

**坑**:频繁 Rebalance 会**严重影响吞吐** → 调 `session.timeout.ms` / `max.poll.interval.ms`

### 2.4 Kafka 写入可靠性 `acks` 配置

| acks | 含义 | 可靠性 | 性能 |
|---|---|---|---|
| 0 | 不等任何 ACK | 最低 | 最高 |
| 1 | 只等 Leader 确认 | 中 | 中 |
| **all / -1** | 等所有 ISR 确认 | **最高** | 最低 |

**生产级**:`acks=all` + `min.insync.replicas=2`(2 个副本写成功才算)。

---

## 3. ⭐ Kafka vs RocketMQ vs RabbitMQ `[P6基线]`

### 3.1 选型对照

| 维度 | Kafka | RocketMQ | RabbitMQ |
|---|---|---|---|
| **吞吐量** | 极高(百万 QPS) | 高(十万 QPS) | 中(万 QPS) |
| **延迟** | 毫秒级 | 毫秒级 | 微秒级 |
| **顺序** | 分区内 | **严格顺序消息**(独有) | 队列内 |
| **事务消息** | ✅(0.11+) | ✅(成熟) | ❌ |
| **延时消息** | ❌(需自实现) | ✅(18 个固定级别) | ✅(插件) |
| **死信队列** | ⚠️(2.4+) | ✅ | ✅ |
| **消息回溯** | ✅ | ✅ | ❌ |
| **协议** | 自定义 | 自定义 | AMQP / MQTT |
| **运维** | 中(ZK 依赖,3.0+ 可去 ZK) | 中 | 简单 |
| **典型场景** | **大数据 / 日志收集** | **金融 / 订单 / 交易** | **业务消息 / 异步解耦** |

### 3.2 🎯 选型决策

> "如果是大数据 / 日志,选 Kafka(吞吐第一);如果是金融 / 电商订单,选 RocketMQ(事务消息 + 顺序消息成熟);如果是简单业务异步解耦 + 不追求超高吞吐,选 RabbitMQ(运维简单 + 协议标准)。"

---

## 4. ⭐ RocketMQ 特色 `[P6基线]`(国内大厂高频)

### 4.1 顺序消息(独有 / 严格)

通过 `MessageQueueSelector` 把同一业务 key 的消息路由到同一队列,且消费时**单队列单线程**消费 → **严格顺序**。

### 4.2 事务消息(2PC 半消息)

> PDF p.84 已讲,简化:

```
1. 半消息 → Broker(对消费者不可见)
2. 执行本地事务
3. Commit/Rollback 给 Broker
4. 如果 Broker 长时间没收到 → 反查接口
```

### 4.3 延时消息(18 个固定级别)

```java
msg.setDelayTimeLevel(3);  // 10s
// 1=1s 2=5s 3=10s 4=30s 5=1m 6=2m 7=3m 8=4m 9=5m 10=6m
// 11=7m 12=8m 13=9m 14=10m 15=20m 16=30m 17=1h 18=2h
```

不能任意时间,但覆盖大部分业务场景。

---

## 5. 实战经验 `[与你项目]`🔗

### 5.1 ASP Kafka 用途

> ASP knowledge.md 提到 "Kafka(配合日志)"

可讲点:
- 日志收集架构:微服务 → Kafka → ELK
- 为什么用 Kafka 不直接 Logstash:**削峰 + 解耦**

### 5.2 Vertiv ActiveMQ 用途

> 在 Zero Engine 里 active-alarm topic 推告警给 SI

可讲点:
- **JMS Topic vs Queue**:Topic 是发布订阅(多消费者各拿一份),Queue 是点对点(消息只被一个消费)
- ActiveMQ 是经典 JMS 实现,但**生产规模上不如 Kafka/RocketMQ**

---

## 6. 🎯 高频面试题

| # | 题 | §位置 |
|---|---|---|
| 1 | 怎么保证消息不丢(三端) | §1.1 |
| 2 | 怎么保证消息顺序 | §1.2 |
| 3 | 怎么保证消息幂等(不重复消费) | §1.3 |
| 4 | Kafka 为什么高吞吐(5 点) | §2.2 |
| 5 | Consumer Rebalance 流程 + 坑 | §2.3 |
| 6 | acks=0/1/all 区别 | §2.4 |
| 7 | Kafka vs RocketMQ vs RabbitMQ 选型 | §3 |
| 8 | RocketMQ 事务消息流程 | §4.2 |
| 9 | RocketMQ 顺序消息原理 | §4.1 |

---

## 7. 推荐资源

| 资源 | 备注 |
|---|---|
| **《深入理解 Kafka》** 朱忠华 | 国内最系统的 Kafka 书 |
| **RocketMQ 官方文档** | https://rocketmq.apache.org/ |
| **Kafka 源码** | 想冲 P7 看 LogManager / GroupCoordinator |

---

> 📌 **下一步**:[`network-essentials.md`](./network-essentials.md)
