# PostgreSQL 知识体系

标签:`[就绪]` `[简历亮点]`⭐ `[面试高频]`🎯 `[源文]`

> 这份文档是你 `postgresql.xmind` (775 行 outline) + `refactor_pi/db/postgres/*.sql` (15 个文件) +
> `refactor_pi/docs/migration/01-postgres-schema.md` 三组素材的**整合视图**。
>
> **不抄你的 outline**(那已经够详细了),只做**主题划分 + 实战关联**。

---

## 0. 你的 PostgreSQL 知识全景

```
┌─────────────────────────────────────────────────────────────┐
│              PostgreSQL 知识体系 (你目前覆盖度)              │
├─────────────────────────────────────────────────────────────┤
│  L1 基础:                                                   │
│    SQL 语法 / DDL / DML / 事务 / 视图           ✅ outline  │
│                                                             │
│  L2 进阶特性 (你最近大改 xmind 加的):                       │
│    自定义数据类型 (复合 / 枚举 / 基础 / 域)     ✅ outline  │
│    表继承                                       ✅ outline  │
│    JSONB                                       ✅ outline  │
│    数组类型                                     ✅ outline  │
│    函数 / 触发器 / 存储过程                     ✅ outline  │
│                                                             │
│  L3 性能与运维:                                             │
│    索引设计 (B-tree / GIN / GiST / BRIN)        ⚠️ 需补充   │
│    分区表 (RANGE / LIST / HASH)                ⚠️ 需补充   │
│    查询优化 / 执行计划 (EXPLAIN ANALYZE)        ⚠️ 需补充   │
│    连接池 (pgBouncer / HikariCP)                ⚠️ 需补充   │
│                                                             │
│  L4 实战经验:                                               │
│    PI 4.0 schema 设计 (refactor_pi/db/postgres/) ✅ 14 模块 │
│    Mongo → PG 数据迁移 (mongo_to_pg.py)         ✅ 实操    │
│    Flyway 数据库版本管理                         ⚠️ 文档提了 │
│                                                             │
│  L5 架构级:                                                 │
│    时序数据存储策略 (替代 TimescaleDB)           ✅ 文档提了 │
│    备份恢复 (pg_dump / pg_basebackup)            ⚠️ 待开始   │
│    主从复制 / 高可用                             ❌ 暂不需要 │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. 你 outline 里讲到的 (基础 + 进阶) `[源文]`

> 直接看 [`_build/outlines/3-tech_stack/database/postgresql/postgresql.outline.md`](../../_build/outlines/3-tech_stack/database/postgresql/postgresql.outline.md)。
>
> 这一节我只**勾画结构**,让你知道整个 outline 在讲什么:

### 1.1 基本信息 (§1)

- 对象-关系型数据库 (与 MySQL 的本质区别)
- 自定义数据类型 4 种 (复合 / 枚举 / 基础 / 域)
  - 每种都有"优势 / 弊端 / 与 JSONB 协作"
- 表继承 (含弊端 6 条:外键失效 / 唯一性复杂 / ORM 支持差等)
- ...... (outline 后续覆盖事务、索引、JSONB 等)

### 1.2 我特别想强调的几个点

#### A. 自定义类型不是装饰品 [面试高频]🎯

很多 Java 后端面试官知道 PG 有自定义类型,但**没用过**。如果你能讲:
- **复合类型**做"地址"这种聚合属性,比拆 3 列更内聚
- **域类型**统一所有"邮箱"字段的格式校验
- **JSONB + 复合类型协作**,把外部 JSON 转成预定义类型

→ 直接拉开 80% 候选人。

#### B. 表继承是双刃剑 [盲点]⚠️

你的 outline 详尽列了表继承的 6 个弊端(外键失效 / 唯一性复杂 / 查询计划低效 / 架构复杂度激增 / ORM 支持差 / 数据迁移困难)。

> **结论**: PG 的表继承,**绝大多数场景不该用**。它是"PG 历史早期分区表的实现",已经被声明式分区(`PARTITION BY`)替代。
>
> **简历不要写**:"我用过 PG 表继承做继承关系建模"——会被追问"那为什么不用关联表"。

#### C. JSONB 不是"塞进 JSON 就完事" [面试高频]🎯

你 outline 里应该有 JSONB 的内容(我没全部看完)。面试常问:
- JSONB vs JSON 的区别(JSONB 二进制存储,有 GIN 索引支持)
- JSONB 里建索引的两种方式(GIN 索引 / 表达式索引)
- 什么时候用 JSONB,什么时候应该拆成关系表(经验法则:**字段固定就拆,字段不固定才用 JSONB**)

---

## 2. 实战经验:PI 4.0 schema 设计

> 这是你**简历可讲的硬核实战**。素材在 `refactor_pi/db/postgres/`(14 个 SQL 文件)。

### 2.1 模块化拆分

```
00_extensions.sql       PG 扩展 (pgcrypto / uuid-ossp 等)
01_schemas.sql          创建 schema (按业务域拆,如 iam / device / alarm)
02_common.sql           跨模块通用表 (审计字段 / 公共枚举)
10_iam.sql              身份与权限 (User / Role / Permission)
20_metamodel.sql        元数据模型 (从 mtp-core 的 metadata definition 演进)
30_platform.sql         平台层表 (插件 / 配置 / 系统状态)
40_device.sql           设备 (UPS / PDU / Server)
50_monitoring.sql       监控数据 (datapoint / 实时信号)
60_event.sql            事件日志
70_alarm.sql            告警 (规则 / 历史 / 通知)
80_job.sql              异步任务
85_telemetry.sql        遥测 (替代 mtp.tsd)
90_file.sql             文件管理
95_licensing.sql        License (PI 不启用,但 schema 预留)
99_run_all.sql          按顺序执行所有 SQL 的入口
```

### 2.2 几个值得讲的设计 [简历亮点]⭐

#### A. 命名规范 + 编号
按 `00 / 10 / 20 ... / 99` 编号,**前置依赖明确**(extensions 必须在 schemas 之前,iam 在 device 之前)。这是 Flyway / Liquibase 的最佳实践。

#### B. 按业务域(而不是按表类型)拆 schema
- `iam.users`, `device.devices`, `alarm.rules` 而不是把所有表放在 `public`
- 优点:**权限隔离**(可以给 `iam_admin` 用户只赋 `iam` schema 权限)
- 优点:**数据库 dump 可按 schema 分块**

#### C. 时序数据用原生分区(而不是 TimescaleDB)
- 表:`monitoring.datapoint_history`
- 分区:RANGE(created_at),按天分区
- 保留策略:raw 30 天 / hourly 5 年 / daily 永久
- **实现**:用 `@Scheduled` 任务每天 00:00 自动 detach 并 drop 30 天前的分区,创建明天的分区

> **面试讲法**: "我没用 TimescaleDB,因为我们的产品要求**不引入第三方扩展**(降低安装包复杂度 + 长期维护成本),原生分区 + 自动化运维任务就够用"。

---

## 3. 实战经验:Mongo → PostgreSQL 迁移

### 3.1 工具链

`refactor_pi/tools/` 下 6 个 Python 脚本:

| 脚本 | 职责 |
|---|---|
| `clone_pi_repos.py` | 克隆所有 PI 仓库到本地 |
| `mongo_analyze.py` | 分析 Mongo 集合 (字段分布、嵌套深度、文档数量) |
| `mongo_samples.py` | 抽样导出每个集合的样本(供建模参考) |
| `mongo_summary.py` | 生成全库汇总报告 (`mongo_report.json`) |
| `mongo_to_pg.py` | **主迁移脚本** (47KB,核心) |
| `verify_migration.py` | 一致性校验(行数 + 抽样字段值) |

### 3.2 迁移方法论 [简历亮点]⭐

```
步骤 1: 摸底
  → mongo_analyze.py + mongo_samples.py
  → 输出:每个集合的字段分布、嵌套深度、文档数

步骤 2: 建模
  → 基于摸底结果设计 PG schema (refactor_pi/db/postgres/*.sql)
  → 决策:哪些字段拍平到列、哪些保留为 JSONB、哪些拆成关联表

步骤 3: 离线全量迁移
  → mongo_to_pg.py 批量执行
  → 每批次 N 条,中间提交,失败可重试

步骤 4: 一致性校验
  → verify_migration.py
  → 比对:行数 / 关键字段抽样值 / 业务约束(如 user.id 唯一)

步骤 5: 报告
  → etl_report.json + etl_run.log 归档
```

### 3.3 这块面试必问的点

- **为什么不在线双写**:推倒重写,模型不一致,双写复杂度爆炸
- **数据丢失怎么处理**:迁移前 mongodump 强制完整备份,出问题回到 PI 3.x
- **嵌套文档怎么映射**:取决于嵌套用途——
  - 如果是"一对多关联",拆成关联表
  - 如果是"组合属性"(如 address),用复合类型 / JSONB
- **null 与默认值的差异**:Mongo 字段缺失 vs PG 的 NULL,迁移时要明确处理(明确写 NULL / 用默认值 / 报错跳过)

---

## 4. 你**还没**做(或没沉淀的) [需补充]

| 主题 | 缺什么 | 优先级 |
|---|---|---|
| 索引设计实战 | outline 里讲了索引概念,但没实战经验沉淀(refactor_pi/db/postgres 里的 CREATE INDEX 是怎么决策的?) | ⭐ |
| EXPLAIN ANALYZE | 没看到任何"我用 EXPLAIN 优化了一个慢查询"的笔记 | ⭐ |
| 连接池调优 | HikariCP 配置参数(maximumPoolSize / connectionTimeout)的实战值 | ⭐ |
| 备份恢复 | pg_dump / pg_basebackup / 增量备份方案 | 中 |
| 监控指标 | pg_stat_* 视图的实战使用 (慢查询识别 / 锁等待识别) | 中 |
| 主从复制 | 短期不需要,但简历可加分 | 低 |

---

## 5. 与你 `origin/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| PG 全部知识点 | §1 | `_build/outlines/3-tech_stack/database/postgresql/postgresql.outline.md` (775 行) |
| PI 4.0 schema 设计 | §2 | `origin/2-projects/vertiv/refactor_pi/db/postgres/*.sql` |
| Schema 设计文档 | §2 | `origin/2-projects/vertiv/refactor_pi/docs/migration/01-postgres-schema.md` |
| Mongo → PG ETL | §3 | `origin/2-projects/vertiv/refactor_pi/tools/*.py` |
| FerretDB 不可行的根因 | §A 决策背景 | [`./ferretdb-research.md`](./ferretdb-research.md) |
| MongoDB 集合清单 | §3 摸底 | `origin/2-projects/vertiv/refactor_pi/docs/legacy-analysis/03-mongodb-collections.md` |

---

> **下一步**: 看 [`ferretdb-research.md`](./ferretdb-research.md) (PG 故事的另一面)
