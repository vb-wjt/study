# Redis 进阶(数据结构 / 持久化 / 主从 / Cluster)

> **写给**:已经会用 5 大基础类型 / 缓存三件套你
> **目的**:从"会用"到"懂底层" → P6+ 必备
> **配套**:`Java Study.pdf` p.54-65 已经覆盖了缓存三件套(穿透/击穿/雪崩)+ 双写一致性 + 分布式锁

标签:`[P6基线]`⭐⭐⭐ `[与PDF重叠]`📚 `[与你项目]`🔗(SI/ASP 都用) `[国内大厂]`

---

## 0. 你的水位

| 概念 | 你的水位 | P6 基线 |
|---|---|---|
| 5 大基础类型(String/List/Hash/Set/ZSet) | ✅ | ✅ |
| 缓存穿透/击穿/雪崩 | ✅ PDF 已覆盖 | ✅ |
| 双写一致性 4 种方案 | ✅ PDF 已覆盖 | ✅ |
| Redis 分布式锁(SET NX EX + Lua) | ✅✅ ASP 实战 | ✅ |
| **底层数据结构(SDS / dict / skiplist)** | ❌ | ❌ |
| **持久化 RDB / AOF / 混合** | ⚠️ 听过没细看 | ❌ |
| **主从复制 + 哨兵 + Cluster** | ⚠️ 听过 | ❌ |
| **过期淘汰策略 8 种** | ❌ | ❌ |
| **大 key / 热 key 处理** | ✅ PDF 提了 | ✅ |

---

## 1. ⭐⭐ 5 大类型底层数据结构 `[P7加分]`

> 这是 P6+ 区分点 —— "知道有这 5 个" vs "知道每个底层是什么"。

### 1.1 String → SDS(Simple Dynamic String)

```c
struct sdshdr {
    int len;          // 已用长度
    int free;         // 剩余空间
    char buf[];       // 数据
}
```

**为什么不用 C 原生字符串?**
1. **O(1) 取长度**(C 字符串是 O(N),要遍历到 \0)
2. **二进制安全**(可存图片 / 序列化对象)
3. **预分配空间**减少频繁扩容(< 1MB 翻倍,> 1MB 多分配 1MB)
4. **杜绝缓冲区溢出**

### 1.2 List → quicklist (Redis 3.2+)

```
quicklist = 双向链表 + 每个节点是 listpack(原 ziplist)
```

**为什么不直接用链表?**
- 链表 next/prev 指针占内存
- listpack 把多个元素紧凑存在一块连续内存,节约空间

### 1.3 Hash → listpack 或 hashtable

**小 Hash**(元素少 / 单元素小)用 **listpack**(节省内存);**大 Hash** 用 **hashtable**(O(1) 查找)。

阈值(可配):`hash-max-listpack-entries 128` / `hash-max-listpack-value 64`。

### 1.4 Set → intset 或 hashtable

**全是整数 + 元素少**:**intset**(有序数组,二分查找)
**否则**:**hashtable**

### 1.5 ⭐ ZSet → listpack 或 skiplist

**小 ZSet**:**listpack**
**大 ZSet**:**skiplist + hashtable**(双结构,既支持排序 也支持 O(1) 查 score)

#### 跳表(skiplist)简介

```
Level 3:  1 ─────────→ 7 ─────────→ 12
Level 2:  1 ───→ 4 ───→ 7 ───→ 9 ──→ 12
Level 1:  1 → 3 → 4 → 6 → 7 → 8 → 9 → 11 → 12
```

**为什么 ZSet 不用红黑树?**
1. **范围查询更友好**(链表顺序遍历)
2. **实现简单**(红黑树代码量大,bug 多)
3. **内存可控**(每层指针数随机,平均 O(log N))

### 1.6 🎯 面试可讲

> "Redis 5 大类型底层都是动态变化的:String 是 SDS,List 是 quicklist(双向链表 + listpack),小 Hash/Set/ZSet 用 listpack 节省内存,大的转成 hashtable / skiplist。ZSet 用跳表而不是红黑树,主要因为范围查询友好 + 实现简单 + 内存可控。"

---

## 2. ⭐⭐⭐ 持久化:RDB / AOF / 混合 `[P6基线]`

### 2.1 RDB(快照)

**原理**:**fork 子进程**做内存全量快照,生成二进制文件 `dump.rdb`。

```
触发方式:
1. SAVE       ← 主线程做(❌ 阻塞)
2. BGSAVE     ← fork 子进程(✅ 推荐)
3. 自动:save 900 1 / save 300 10 / save 60 10000
4. shutdown / replication 时触发
```

**优点**:
- 文件**紧凑**(二进制),恢复**快**
- 备份友好(打包发走就行)

**缺点**:
- **数据丢失风险**(两次快照之间宕机,丢中间所有写入)
- fork 子进程**短暂阻塞主线程**(写时复制 COW,大内存可能慢)

### 2.2 AOF(Append-Only File)

**原理**:**记录每条写命令**到日志文件,恢复时**重放**。

```
配置:
appendfsync always       ← 每条命令都 fsync,最安全但慢
appendfsync everysec     ← 每秒 fsync(默认,折中)
appendfsync no           ← 由 OS 决定,最快但不安全
```

#### AOF 重写(Rewrite)

**问题**:AOF 文件无限增长(同一个 key 反复 SET)
**解决**:**定期重写** —— 根据当前内存状态生成最小命令集

```
触发:
1. BGREWRITEAOF 手动触发
2. auto-aof-rewrite-percentage 100   ← 比上次重写后增长 100% 触发
   auto-aof-rewrite-min-size 64mb
```

### 2.3 ⭐ 混合持久化(Redis 4.0+)

**痛点**:
- 纯 RDB:数据可能丢
- 纯 AOF:文件大 / 恢复慢

**混合方案**(`aof-use-rdb-preamble yes`):
- AOF 文件**前半段**是 RDB 快照(快速恢复)
- AOF 文件**后半段**是增量命令(覆盖快照后的变更)

> **生产推荐**:**AOF + 混合持久化**。

### 2.4 ⭐ RDB vs AOF 决策矩阵

| 场景 | 推荐 |
|---|---|
| 缓存服务(数据可丢) | RDB(简单) |
| 重要业务数据 | **AOF + 混合**(默认) |
| 需要主从快速复制 | **RDB**(主从全量 sync 用 RDB) |
| 备份归档 | **RDB**(文件小) |

### 2.5 🎯 面试可讲

> "Redis 持久化有 RDB(快照,fork 子进程做)和 AOF(命令日志)。RDB 紧凑恢复快但可能丢数据,AOF 安全但文件大恢复慢。Redis 4.0 起有混合持久化:AOF 文件前半 RDB 快照后半增量命令,既快又安全。生产一般用 AOF+混合。"

---

## 3. ⭐⭐⭐ 主从复制 + 哨兵 + Cluster `[P6基线]`

### 3.1 主从复制(Replication)

```
Master                          Slave
  ↓ 1. 全量同步(首次)
  ├─ BGSAVE 生成 RDB
  ├─ 发 RDB 给 Slave        →
  ├─ 同时缓冲期间写命令     →
  
  ↓ 2. 增量同步(后续)
  ├─ 实时 propagate 写命令  →   重放
```

#### 主从复制 3 个关键概念

| 概念 | 作用 |
|---|---|
| **runid** | 节点唯一 ID,主从握手用 |
| **offset** | 复制偏移量,用于断线重连定位 |
| **复制积压缓冲区**(repl_backlog) | 主节点维护的环形缓冲,断线重连用 |

### 3.2 ⭐ 哨兵(Sentinel)— 主从切换

**作用**:**自动故障转移**(Master 挂了选个 Slave 当新 Master)。

```
3 个 Sentinel 进程
   ↓ 监控 Master + Slaves
1. 主观下线(SDOWN):某 Sentinel 觉得 Master 挂了
2. 客观下线(ODOWN):多数 Sentinel 都觉得挂了
3. Sentinel 之间选举:Raft-like 选出 Leader
4. Leader 选 Slave 提升为 Master(基于 priority / offset / runid)
5. 通知客户端切换
```

**最少配置**:**3 个 Sentinel + 1 主 2 从**(避免脑裂)。

### 3.3 ⭐⭐ Cluster(分片)— Redis 3.0+

**作用**:**横向扩展 + 高可用**(单机内存上限 10-50G,过了用 Cluster)。

#### 核心概念

```
16384 个槽(Slot)
  ↓
分布在 N 个节点
  ↓
每个 key 通过 CRC16(key) % 16384 定位到槽 → 槽对应节点
```

**节点角色**:每个节点是一个**主从对**(主负责读写,从备份)。

#### 跨槽操作的限制

```
MGET key1 key2 key3   ← key1/key2/key3 在不同槽,会报错!
```

**解决**:**Hash Tag**(`{user1}:profile` / `{user1}:posts` 都按 `user1` 哈希,落同一槽)。

### 3.4 ⭐ 一致性问题(L4 加分)

| 问题 | 现象 | 解决 |
|---|---|---|
| **主从延迟** | 写主立刻读从,可能读不到 | 重要场景**写主读主** |
| **脑裂(split-brain)** | 网络分区导致两个 Master | 配置 `min-replicas-to-write 1`(至少 1 个 Slave 在线才允许写) |
| **故障切换数据丢失** | 切换瞬间未复制的命令丢了 | 同上 + 业务侧补偿 |

### 3.5 🎯 面试可讲

> "Redis 高可用三档:主从复制(基础,只解决备份不解决故障切换),哨兵(自动故障转移,3 哨兵+1主2从最小配置),Cluster(分片+高可用,16384 槽+CRC16 路由)。生产中小规模用哨兵,大规模(>50GB)用 Cluster。Cluster 跨槽操作要用 Hash Tag 强制落同槽。"

---

## 4. ⭐⭐ 过期淘汰 `[P6基线]`

### 4.1 过期 key 的删除策略

| 策略 | 含义 | 优点 | 缺点 |
|---|---|---|---|
| **定时删除** | 设置时启动定时器到期就删 | 内存友好 | CPU 压力大 |
| **惰性删除** | 访问时才检查是否过期 | CPU 友好 | 内存浪费(大量过期 key 不被访问) |
| **定期删除** | 周期性抽样删除 | 折中 | 抽样可能漏 |

**Redis 实际策略**:**惰性删除 + 定期删除**(每秒 10 次,每次抽 20 个,过期 > 25% 重抽)。

### 4.2 ⭐ 内存满了 → 8 种淘汰策略

```bash
maxmemory-policy
```

| 策略 | 范围 | 算法 |
|---|---|---|
| `noeviction` | — | **不淘汰,直接报错**(默认) |
| `allkeys-lru` | 全部 key | LRU |
| `allkeys-lfu` ⭐ | 全部 key | **LFU**(Redis 4.0+,推荐缓存场景) |
| `allkeys-random` | 全部 key | 随机 |
| `volatile-lru` | 设了 TTL 的 key | LRU |
| `volatile-lfu` | 设了 TTL 的 key | LFU |
| `volatile-random` | 设了 TTL 的 key | 随机 |
| `volatile-ttl` | 设了 TTL 的 key | 优先淘汰 TTL 短的 |

> **生产推荐**:**`allkeys-lfu`**(纯缓存场景);**`volatile-lfu`**(混合场景,持久 key 不删)。

### 4.3 LRU vs LFU(经典面试题)

| 维度 | LRU(最近最少使用) | LFU(最少使用) |
|---|---|---|
| 依据 | **访问时间** | **访问频率** |
| 抗污染 | ❌(突发流量把热点冲掉) | ✅ |
| 实现 | 双向链表 + Hash | 频率链表 + 老化机制 |

> 🎯 **L4 加分**:**为什么 Redis 4.0 引入 LFU?** → LRU 抗污染差,**一次大批量扫描**会冲掉热点缓存(典型场景:批处理任务跑一遍,把所有热点 key 都淘汰)。

---

## 5. ⭐ 大 key / 热 key 处理 `[P6基线]` `[与PDF重叠]`📚

> PDF p.58-59 已经讲过,这里只补**实战工具**:

### 5.1 找大 key

```bash
# Redis 自带
redis-cli --bigkeys

# rdb 文件分析
redis-rdb-tools

# 在线扫描(SCAN + DEBUG OBJECT,生产慎用,避免阻塞)
SCAN 0 MATCH * COUNT 1000
DEBUG OBJECT keyname
```

### 5.2 找热 key

```bash
# Redis 4.0+ 内置
redis-cli --hotkeys     # 需要 maxmemory-policy 是 LFU 类才能看

# 抓包分析
redis-faina(大批量分析 monitor 输出)

# 客户端打点(更准)
```

### 5.3 ⭐ 处理方案

| 问题 | 方案 |
|---|---|
| 大 key | 拆分(big hash → 多 hash,big list → 队列) / 压缩 / 异步删除(`UNLINK` 不阻塞) |
| 热 key | 多副本(key + 1/2/3 后缀分散)/ 本地缓存兜底 / 限流 |

### 5.4 🔗 结合你项目

ASP 的 `cache-cli + cache-server` 设计 = **避免每次都查大表 + 分布式锁防多刷** —— 这是**热 key + 缓存击穿**的工程级解决方案。

---

## 6. ⭐ Redis 性能调优 `[P7加分]`

### 6.1 单线程模型(理解前提)

> Redis 6.0 之前**主线程是单线程的**(网络 IO + 命令处理同一个线程)。
> Redis 6.0 起**多线程仅用于网络 IO**(命令处理仍单线程,保证顺序)。

**性能瓶颈**:
- **网络带宽**(批量命令优化)
- **CPU**(命令复杂度,O(N) 命令慎用)
- **内存**(大 key + 数据结构选错)

### 6.2 ⭐ 性能优化套路

```
1. 批量命令:MGET / MSET / Pipeline   ← 减少 RTT
2. 避免 O(N) 命令:KEYS / SMEMBERS(大集合)/ HGETALL(大 hash)
   → 用 SCAN / HSCAN / SSCAN 替代
3. 慢查询日志:slowlog-log-slower-than 10000 (μs)
4. 持久化时机:fork COW 大内存场景调大 vm.overcommit_memory
5. 数据压缩:自定义 + GZIP(大 value)
```

### 6.3 ⭐⭐ Lua 脚本

**为什么用**:
1. **原子性**(单 Redis 实例内,Lua 期间不会被其他命令打断)
2. **减少网络 RTT**(多命令打包发送)
3. **复杂逻辑**(条件判断 / 循环)

```lua
-- 经典:释放分布式锁的 Lua 脚本(避免误删)
if redis.call('get', KEYS[1]) == ARGV[1] then
    return redis.call('del', KEYS[1])
else
    return 0
end
```

> 🔗 你 ASP `@RedisLock` 解锁就是用这个 Lua 脚本(PDF p.63 + ASP knowledge.md)。

---

## 7. 🎯 高频面试题清单

| # | 题 | 答案位置 |
|---|---|---|
| 1 | 5 大类型底层数据结构 | §1 |
| 2 | ZSet 为什么用跳表不用红黑树 | §1.5 |
| 3 | RDB vs AOF | §2 |
| 4 | 混合持久化(4.0+) | §2.3 |
| 5 | 主从复制流程 | §3.1 |
| 6 | 哨兵故障转移 | §3.2 |
| 7 | Cluster 16384 槽 + Hash Tag | §3.3 |
| 8 | 过期 key 删除策略(惰性 + 定期) | §4.1 |
| 9 | 8 种淘汰策略 | §4.2 |
| 10 | LRU vs LFU + 为什么 4.0 引 LFU | §4.3 |
| 11 | Redis 单线程为什么快 | §6.1 |
| 12 | Redis 6.0 多线程是什么 | §6.1 |
| 13 | 大 key / 热 key 处理 | §5 |
| 14 | Lua 脚本原子性 | §6.3 |

---

## 8. 推荐资源

| 资源 | 备注 |
|---|---|
| **《Redis 设计与实现》** 黄健宏 | 国内最经典,讲底层 |
| **Redis 官方文档** | https://redis.io/docs/ |
| **Redis 源码** | C 语言写的,但易读,推荐看 dict.c / t_string.c |

---

> 📌 **下一步**:[`mq-essentials.md`](./mq-essentials.md) → MQ 三大问题 / Kafka / RocketMQ
