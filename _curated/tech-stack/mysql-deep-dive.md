# MySQL 进阶(InnoDB 锁 / MVCC / 主从 / binlog)

> **写给**:已经会写 SQL / 懂索引 / 看得懂 explain 的你
> **目的**:从"会 SQL"到"懂 InnoDB 内部" → P6+ 必备
> **范围**:MySQL 8.0,InnoDB 引擎为主
> **配套**:`Java Study.pdf` p.23-43 已经覆盖了基础(隔离级别 / 索引类型 / explain / 优化 17 条),本文不重复

标签:`[P6基线]`⭐⭐⭐ `[与PDF重叠]`📚 `[与你项目]`🔗(ASP Oracle 多 / Vertiv MySQL→SQLite) `[国内大厂]`

---

## 0. 你的水位

| 概念 | 你的水位 | P6 基线 |
|---|---|---|
| 索引(B+树 / 失效 9 种) | ✅ PDF 已覆盖 | ✅ |
| explain 执行计划 | ✅ PDF 已覆盖 | ✅ |
| 事务隔离级别 + MVCC | ✅ PDF 已覆盖基础 | ⚠️ ReadView 细节缺 |
| **行锁 / 间隙锁 / 临键锁** | ⚠️ **PDF 没覆盖** | ❌ |
| **死锁排查** | ❌ | ❌ |
| **主从复制 + binlog 三种格式** | ❌ | ❌ |
| **索引下推 ICP** | ❌ | ❌(P7+) |
| **慢查询日志 + 优化流程** | ⚠️ PDF 提了 explain + profiling | ❌ |

---

## 1. ⭐⭐⭐ InnoDB 锁体系 `[P6基线]` `[国内大厂]`

### 1.1 锁分类(必背)

```
按粒度:
├─ 表锁 (Table Lock)
│   ├─ MyISAM 用
│   └─ InnoDB DDL / LOCK TABLES 用
└─ 行锁 (Row Lock) ← InnoDB 主战场
    ├─ Record Lock (记录锁) ← 锁单个索引记录
    ├─ Gap Lock (间隙锁)    ← 锁记录之间的"区间"
    └─ Next-Key Lock (临键锁) ← Record + Gap 组合(InnoDB 默认)

按属性:
├─ 共享锁 (S Lock,读锁)    ← SELECT ... LOCK IN SHARE MODE / FOR SHARE
└─ 排他锁 (X Lock,写锁)    ← SELECT ... FOR UPDATE / UPDATE / DELETE / INSERT
```

### 1.2 ⭐ 三种行锁详解

#### Record Lock(记录锁)
锁单个索引记录,只在**主键 / 唯一索引 + 等值查询**生效。

```sql
-- id 是主键,这条会获得 Record Lock(只锁 id=10 这一行)
SELECT * FROM t WHERE id = 10 FOR UPDATE;
```

#### Gap Lock(间隙锁)
锁**记录之间的开区间**,**不锁记录本身**。

```sql
-- 假设 t 中 id 有 5, 10, 15
-- 这条会锁 (5, 10) 这个区间
SELECT * FROM t WHERE id > 5 AND id < 10 FOR UPDATE;
```

**作用**:**防止幻读**(其他事务无法 INSERT 进这个区间)。

#### Next-Key Lock(临键锁,InnoDB 默认)
**Record Lock + Gap Lock** = 锁**左开右闭区间** `(a, b]`。

```sql
-- 假设 id 有 5, 10, 15
-- 这条会锁 (5, 10] 和 (10, 15] 两个区间
SELECT * FROM t WHERE id > 5 AND id < 15 FOR UPDATE;
```

### 1.3 ⭐⭐ 加锁规则(死磕的话看这个)

> **MySQL 官方**给的加锁规则简化版(8.0 / RR 隔离级别):

| 查询类型 | 索引 | 加什么锁 |
|---|---|---|
| 等值 | 主键/唯一索引 + 命中 | **Record Lock** |
| 等值 | 主键/唯一索引 + 未命中 | **Gap Lock** |
| 等值 | 普通索引 + 命中 | **Next-Key Lock** + 后一个 Gap Lock |
| 等值 | 普通索引 + 未命中 | **Gap Lock** |
| 范围 | 任何 | **Next-Key Lock**(每个匹配区间) |
| **未走索引** | — | **退化为表锁**(锁全表!) |

> ⚠️ **未走索引 = 表锁** 是**面试高频陷阱题**。

### 1.4 ⭐⭐ 隔离级别 + 锁的关系

| 隔离级别 | 间隙锁 | 临键锁 | 幻读 |
|---|---|---|---|
| READ UNCOMMITTED | ❌ | ❌ | 出现 |
| READ COMMITTED | ❌(关闭间隙锁) | ❌ | **出现** |
| **REPEATABLE READ**(MySQL 默认) | ✅ | ✅ | **InnoDB 通过 Next-Key 锁解决** |
| SERIALIZABLE | ✅ | ✅ + 所有 SELECT 加锁 | 不出现 |

> 🎯 **面试可讲**:**为什么 MySQL 默认 RR 而不是 RC?** → **历史原因**(早期 MySQL binlog 在 RC 下有问题,RR 安全);很多互联网公司其实手动改成 RC(性能更好,业务通过乐观锁补救)。

### 1.5 ⭐ 死锁排查实战

```sql
-- 1. 看当前锁信息(MySQL 8.0+)
SELECT * FROM performance_schema.data_locks;
SELECT * FROM performance_schema.data_lock_waits;

-- 2. 查最近的死锁日志
SHOW ENGINE INNODB STATUS;  -- 看 LATEST DETECTED DEADLOCK 段

-- 3. 看活跃事务
SELECT * FROM information_schema.INNODB_TRX;
```

**死锁经典场景**:
- **更新顺序不一致**:线程 A 锁行 1 再锁行 2;线程 B 锁行 2 再锁行 1
- **大量并发 INSERT 同区间**:间隙锁互相阻塞
- **gap 锁 + 唯一索引冲突**

**解决**:
- 业务层**统一加锁顺序**
- 缩短事务时间
- 必要时降级到 RC(去掉间隙锁)
- **死锁自动检测**:InnoDB 默认开启,会回滚代价小的事务

### 1.6 🔗 结合你项目

- ASP **@RedisLock** 设计 = **应用层分布式锁**,**避免数据库锁竞争** → P6+ 加分故事
- ASP **dbproxy** 拆库 → 跨库 SQL 自然不会用数据库行锁

### 1.7 🎯 面试可讲

> "InnoDB 在 RR 隔离级别下,默认用 Next-Key Lock 来解决幻读 —— 这是 InnoDB 的特殊性,而不是 SQL 标准里 RR 的承诺。Next-Key Lock = Record Lock + Gap Lock,锁左开右闭区间。一个常被忽略的坑是:如果 SQL 没走索引,行锁会退化为表锁。死锁排查我用 SHOW ENGINE INNODB STATUS 看 LATEST DETECTED DEADLOCK,或在 8.0 看 performance_schema.data_locks。"

---

## 2. ⭐⭐⭐ MVCC 详解 `[P6基线]`

> PDF p.25 提了 MVCC,这里展开**实现细节**。

### 2.1 MVCC 核心三件套

```
1. 隐藏字段(每行)
   ├─ DB_TRX_ID    ← 最近修改的事务 ID
   └─ DB_ROLL_PTR  ← 指向 undo log 的指针(组成版本链)

2. undo log(版本链)
   row1 (trx 5)  →  row1 (trx 3)  →  row1 (trx 1)
   ↑ 当前版本           历史版本

3. ReadView(读视图)
   - 创建时机:RC 每次读都建 / RR 第一次读建
   - 内容:活跃事务列表 + 最小 trx_id + 下一个 trx_id + 创建者 trx_id
   - 作用:决定看到哪个版本(沿版本链回溯)
```

### 2.2 ⭐ ReadView 的可见性判断

> 当前事务读到一行 (DB_TRX_ID = X),判断这行可见?

| X 的范围 | 是否可见 |
|---|---|
| X < min_trx_id | ✅ 已提交,可见 |
| X >= next_trx_id | ❌ 未来事务,不可见 |
| X 在活跃事务列表中 | ❌ 该事务未提交,不可见 → 沿 ROLL_PTR 找历史版本 |
| X 在 [min, next) 但不在活跃列表 | ✅ 已提交,可见 |
| X = creator_trx_id | ✅ 自己改的,可见 |

### 2.3 RC vs RR 的关键差别

```
事务 A (RC):    select v1 → 100  
                 (此时事务 B commit 把 v1 改成 200)
                 select v1 → 200  ⚠️ 不可重复读

事务 A (RR):    select v1 → 100  ← 第一次读建 ReadView
                 (此时事务 B commit)
                 select v1 → 100  ← 还看老版本(快照)
```

**核心差别**:**RC 每次读都建新 ReadView;RR 整个事务共享一个 ReadView**。

### 2.4 ⭐⭐ MVCC 与锁的关系(L4 加分)

- **快照读(Snapshot Read)**:普通 SELECT,**走 MVCC,不加锁**
- **当前读(Current Read)**:`SELECT ... FOR UPDATE` / `LOCK IN SHARE MODE` / `UPDATE` / `DELETE`,**加锁,看最新数据**

```sql
-- 快照读 → 走 MVCC
SELECT * FROM t WHERE id = 10;

-- 当前读 → 加 Next-Key Lock
SELECT * FROM t WHERE id = 10 FOR UPDATE;
UPDATE t SET v = 1 WHERE id = 10;
```

### 2.5 🎯 面试可讲

> "MVCC 通过隐藏字段 DB_TRX_ID + DB_ROLL_PTR 配合 undo log 形成版本链,再通过 ReadView 决定哪些版本可见。RC 每次 SELECT 都建新 ReadView,RR 整个事务共享。普通 SELECT 是快照读走 MVCC 不加锁;FOR UPDATE / UPDATE / DELETE 是当前读,看最新版本且加 Next-Key Lock。"

---

## 3. ⭐⭐ 主从复制 + binlog `[P6基线]` `[国内大厂]`

### 3.1 主从复制流程

```
Master                          Slave
  │                               │
  │ 1. 客户端写入 → 写 binlog       │
  │ ←──────────────────────────── │ 2. Slave I/O Thread 拉 binlog
  │ 3. dump 线程发 binlog ──────→  │ 4. 写到 relay log
  │                               │ 5. SQL Thread 重放 relay log
  │                               │ 6. 数据落到 Slave
```

### 3.2 ⭐ binlog 三种格式

| 格式 | 内容 | 优点 | 缺点 |
|---|---|---|---|
| **STATEMENT** | 原始 SQL | binlog 小 | 函数 / 自增 / NOW() 等**不安全**(主从结果不一致) |
| **ROW** (推荐) | 行级变更 | **安全** | binlog 大(批量更新爆炸) |
| **MIXED** | 自动判断 | 折中 | 复杂 |

> **生产实践**:**ROW 是默认,5.7+ 推荐**。

### 3.3 ⭐⭐ 主从延迟问题

**原因**:
1. **SQL Thread 单线程**(5.6 起支持 MTS 多线程,但仍可能慢)
2. **大事务**:Master 1 秒,Slave 1 分钟
3. **磁盘 IO 慢**
4. **网络抖动**

**解决**:
- **业务侧**:写完不立即查 Slave,或写主读主关键场景
- **架构侧**:**半同步复制**(Master 等至少一个 Slave 写完 relay log 才返回)
- **MGR / Group Replication**(8.0 推荐)

### 3.4 binlog vs redo log vs undo log

| 日志 | 谁产生 | 作用 | 大小 |
|---|---|---|---|
| **binlog** | Server 层 | 主从复制 / 备份恢复 | 全量,持久 |
| **redo log** | InnoDB 层 | **崩溃恢复**(WAL) | 循环写,固定 |
| **undo log** | InnoDB 层 | **MVCC + 事务回滚** | 段管理 |

### 3.5 ⭐ 两阶段提交(2PC)— 极高频面试题

> 为什么需要?**保证 binlog 和 redo log 一致**(否则主从数据会不同步)。

```
1. Prepare:redo log 进入 prepare 状态
2. 写 binlog
3. Commit:redo log 进入 commit 状态
```

**崩溃恢复时**:
- redo log 已 prepare + binlog 完整 → **commit**
- redo log 已 prepare + binlog 不完整 → **回滚**

### 3.6 🎯 面试可讲

> "主从复制 = binlog dump 给 Slave I/O Thread → relay log → SQL Thread 重放。binlog 三种格式 STATEMENT / ROW / MIXED,生产用 ROW 安全。延迟主要来自 SQL Thread 单线程 + 大事务,8.0 起用 MTS 缓解。binlog 和 redo log 通过两阶段提交保持一致 —— prepare → 写 binlog → commit,崩溃时按 binlog 完整性决定 commit 或 rollback。"

---

## 4. ⭐⭐ 索引下推 ICP `[P7加分]`

### 4.1 是什么

**MySQL 5.6+ 引入**:在二级索引(联合索引)上,**把 WHERE 条件下推到存储引擎层**进行过滤,**减少回表次数**。

```sql
-- 假设有联合索引 (name, age)
SELECT * FROM user WHERE name LIKE '张%' AND age = 30;
```

**没有 ICP**:
1. Server 层把 `name LIKE '张%'` 下推
2. 存储引擎按二级索引找出所有 name 以"张"开头的 → **回表**取所有列 → 返回 Server
3. Server 用 `age = 30` 过滤

**有 ICP**:
1. 存储引擎按二级索引找出 name 以"张"开头的
2. **直接在索引上判断 age = 30**(因为联合索引里有 age)
3. **只对满足条件的回表** → 减少回表次数

### 4.2 看是否启用

```sql
EXPLAIN ... → Extra 列出现 "Using index condition" = ICP 生效
```

### 4.3 🎯 面试可讲

> "ICP 是 5.6 引入的优化,在联合索引场景下把部分 WHERE 条件下推到存储引擎,减少回表。explain Extra 看到 Using index condition 就是 ICP 生效。"

---

## 5. ⭐ 慢查询排查实战 `[P6基线]` `[ROI高]`💎

### 5.1 慢查询日志

```sql
-- 开启
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;  -- 超过 1 秒算慢查询
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';

-- 工具:mysqldumpslow / pt-query-digest 分析慢查询日志
```

### 5.2 排查 4 步

```
1. 慢查询日志找出最慢 SQL
2. EXPLAIN 看执行计划(重点 type / key / rows / Extra)
3. 看是否符合 PDF p.32-33 的 9 种索引失效场景
4. 优化 SQL / 调整索引 / 改业务逻辑
```

### 5.3 ⭐ 常见优化套路

(PDF p.33-35 已经给了 17 条,本节只补**项目实战故事**)

#### 5.3.1 大 IN 列表
```sql
-- ❌ 坑:IN > 1000 个
SELECT * FROM t WHERE id IN (1, 2, ..., 5000);

-- ✅ 优化:分批 / 改 JOIN / 临时表
```

#### 5.3.2 深度分页
```sql
-- ❌ 坑:LIMIT 100000, 20
SELECT * FROM t ORDER BY id LIMIT 100000, 20;

-- ✅ 优化:子查询 + 索引
SELECT * FROM t WHERE id > (SELECT id FROM t ORDER BY id LIMIT 100000, 1) LIMIT 20;
```

#### 5.3.3 三户模型短路校验
🔗 **ASP knowledge.md 提到的**:校验失败也继续校验 → 浪费时间 → **重构为短路 + 批量校验**。

---

## 6. 🎯 高频面试题清单

| # | 题 | 答案位置 |
|---|---|---|
| 1 | 三种行锁(Record / Gap / Next-Key) | §1.2 |
| 2 | RR 怎么解决幻读 | §1.4 + §2.3 |
| 3 | MySQL 默认隔离级别为什么是 RR | §1.4 |
| 4 | MVCC 实现原理(隐藏字段 + undo log + ReadView) | §2 |
| 5 | RC vs RR 的核心区别(ReadView 创建时机) | §2.3 |
| 6 | 快照读 vs 当前读 | §2.4 |
| 7 | 主从复制流程 | §3.1 |
| 8 | binlog 三种格式 | §3.2 |
| 9 | 主从延迟原因 + 解决 | §3.3 |
| 10 | binlog / redo log / undo log 区别 | §3.4 |
| 11 | 两阶段提交 + 崩溃恢复 | §3.5 |
| 12 | 索引下推 ICP | §4 |
| 13 | 死锁排查 | §1.5 |
| 14 | 深度分页优化 | §5.3.2 |

---

## 7. 推荐资源

| 资源 | 备注 |
|---|---|
| **《MySQL 是怎样运行的》** 小孩子 | 极通俗,适合补底层 |
| **《高性能 MySQL》第 4 版** | 经典,深度足 |
| **MySQL 官方文档** | https://dev.mysql.com/doc/refman/8.0/en/ |
| **极客时间《MySQL 实战 45 讲》** 林晓斌 | 阿里 P9 写的,实战级 |

---

> 📌 **下一步**:[`redis-deep-dive.md`](./redis-deep-dive.md) → Redis 数据结构底层 / 持久化 / 主从
