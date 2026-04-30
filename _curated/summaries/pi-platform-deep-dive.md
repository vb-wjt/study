# MTP-Core 平台 · PI 现状 / PI 4.0 重构 / SI 三方对比

标签:`[就绪]` `[简历亮点]`⭐⭐ `[面试高频]`🎯 `[跨主题]`🔗 `[源文]`

> **这份文档不重复你已写的内容**,而是把你 `file/` 下散落的 mtp-core 相关素材**串联**起来,
> 让你可以一眼看懂 "**MTP-Core 是什么 → PI 现状如何 → 为什么要重构 → 重构成什么 → SI 在这个故事里在哪里**"。
>
> **所有引用的"原文"都是你自己写的**(refactor_pi/docs/ + SI/common/mtp-core-strengths-summary.md / mtp-core-deep-analysis.md),
> 我只做整合、对照和点评。

---

## 0. 一图看懂三者关系

```
                           ┌──────────────────────────┐
                           │       MTP-Core           │
                           │  (Trellis App Framework  │
                           │     / TAF Core)          │
                           │  Schema-driven 平台底座   │
                           └────────┬───────┬─────────┘
                                    │       │
                       ┌────────────┘       └────────────┐
                       │                                  │
                       ▼                                  ▼
            ┌────────────────────┐            ┌────────────────────┐
            │   PI (Power        │            │   SI (Smart        │
            │   Insight)         │            │   InfraSight)      │
            │                    │            │                    │
            │ 商用多年, 老旧     │            │ 新生产品, 沿用     │
            │ Spring Boot 2.6   │            │ Spring Boot 3.x    │
            │ Java 8            │            │ Java 21            │
            │ MongoDB 3.6       │            │ MongoDB → FerretDB │
            │ Hazelcast 3.12    │            │ Hazelcast 5.6      │
            │ Angular 14        │            │ Angular ?          │
            │                    │            │                    │
            │ → 4.0 推倒重写     │            │ → 4.x 持续迭代     │
            └────────────────────┘            └────────────────────┘
```

**核心信息**:
- **MTP-Core** 是平台底座,被多个 Vertiv 产品共用
- **PI 和 SI 都依赖 mtp-core**,但**当前用的版本不同**(SI 已经把 mtp-core 升到了与 SB 3 兼容的版本,PI 还停留在老版本)
- **SI 是"先升级"的试验田**,SI 4.1 升级路径基本就是 PI 4.0 重构的"路标"

---

## 1. MTP-Core 是什么(从你的素材里读出来的)

> ✅ **2026-04-30 重命名**: `other.md` → `mtp-core-strengths-summary.md`;`other2.md` → `mtp-core-deep-analysis.md`。
> 框架视角的完整提炼见 [`mtp-core-framework.md`](./mtp-core-framework.md);本节只做"PI/SI/重构"对比所需的最小复述。

### 1.1 Schema-driven 的核心设计

按你 `mtp-core-strengths-summary.md` 提炼的:

| 维度 | 传统 Spring Boot | MTP Core |
|---|---|---|
| 服务定义 | Java 代码(Controller/Service) | JSON Schema 配置 |
| 数据验证 | `@Valid` + Bean Validation | JSON Schema 多级验证 |
| API 生成 | 手动编写 | 自动生成 |
| 扩展性 | 修改代码重新编译 | 修改 Schema 热加载 |
| 开发周期 | 2-3 天/服务 | 0.5-1 天/服务 |

**核心创新**:
- 所有"模型 / 资源"由 **JSON Schema (Draft v4 + 自定义关键字)** 定义
- **GenericModelController** 把任意路径的 CRUD/查询/动作映射到 MongoDB 文档
- **运行时插件加载**:`taf-plugin-*.jar` 通过独立 ClassLoader + Spring Context 装载,合并 schema、注册 REST、注册 handlers/actions
- **多层次验证**:READ / CREATE / UPDATE / DELETE / IMPORT 等不同级别用不同严格度的 schema 校验

### 1.2 关键技术细节(简历可讲)

- **HATEOAS 风格**:`GenericRootController` 暴露根目录,客户端可发现可用 model
- **租户感知**:`tenantAware: true` 的 schema 自动按租户隔离
- **存储策略灵活**:`repositoryType` 可选 inMemory / storage / asynchronous / mapListener / postgres
- **事件驱动**:`onBeforeCreate / onAfterCreate / onBeforeUpdate / onAfterUpdate` 等 hook 支持 Java/JavaScript/Groovy/BSH 多语言处理器
- **投影机制**:Schema 内置 projection 字段,客户端按需取数,减少数据传输

> **L4 反思** (从你 PI 重构文档里挖出来的): 这套设计**优雅但有代价**——
> - 类型不安全(JsonNode 满天飞)
> - 调试困难(stack trace 跳到 Generic 控制器层就懵)
> - IDE 支持薄
> - 跨实体一致性弱(关系建模困难)
>
> 这就是为什么 PI 4.0 决定**砍掉这套机制**。

---

## 2. PI 当前状态 (PI 3.x)

> 直接 ref 你 `refactor_pi/docs/legacy-analysis/01-architecture-overview.md`(277 行,你自己写的,不重复)。
>
> **核心信息浓缩**:

| 维度 | 现状 |
|---|---|
| 后端 | mtp-core(Spring Boot 2.6 + Java 8) + 25 个 taf-plugin-* + 14 个 taf-data-* 设备包 |
| 数据库 | MongoDB 4.4 (动态集合,文档结构由 JSON Schema 推断) |
| 集群 | Hazelcast 3.12 (会话复制 / ITopic / IQueue / Lock / Quartz 主从) |
| 前端 | Angular 14 (meta-ui 壳 + 18 个 taf-* lazy load 库) |
| 部署 | InstallAnywhere 单机安装(Win/Linux),嵌入式 MongoDB + Zulu JRE |
| 业务上限 | 100 台 UPS+PDU(产品级硬约束) |

**业务功能 L1-L10 重要程度**(参考 `02-business-features.md`):
- L1 UPS/PDU 监控 → L2 告警 → L3 服务器关机 → L4 联动自动化 → L5 通知 → L6 电费 → L7 系统运维 → L8 vCenter 集成 → L9 用户接入 → L10 安装部署

**痛点**(简历可讲):
- MongoDB SSPL 协议合规风险
- 多个组件 EOL(SB 2.6 / Java 8 / Hazelcast 3.12)
- **升级链相互卡死**(升 SB 要驱动版本,驱动要 MongoDB 版本,MongoDB 又涉及许可证)
- 动态 Schema 三件套(JSON Schema + Mongo + 运行时插件)既限制产品演进又限制团队效率

---

## 3. PI 4.0 的关键决策(从你 `01-overview.md` 提炼)

> 这一节**只列你已经决策的、非显而易见的、面试值得讲的部分**。具体细节请直接看原文 532 行。

### 3.1 七大核心决策

| 维度 | 决策 | 不显而易见的是 |
|---|---|---|
| 重构方式 | **完全推倒重写**(而非渐进改造) | 渐进改造看似低风险,但**根本架构债无法在渐进中消除** |
| 数据库 | PostgreSQL 16 + 原生分区(**不引入 TimescaleDB**) | 避免引入第三方扩展,降低长期维护成本 |
| 集群框架 | **彻底删除 Hazelcast** → Caffeine + Spring Event + JDK 并发原语 | 单机产品不需要分布式中间件,杀鸡用牛刀 |
| 后端框架 | Spring Boot 3.x + Java 21 LTS | 与 SI 升级对齐,共享经验 |
| 平台层 | mtp-core 4.0 重写为**多模块 Spring Boot Starter 库** | **无运行时插件加载、无动态 Schema、无 ClassLoader 隔离** —— 红线 |
| 钩子机制 | Spring 领域事件 (`@TransactionalEventListener`) + **事务发件箱模式** | **Outbox 解决"不能丢的外部通知",至少一次送达** |
| 进程模型 | **单 JVM 进程**(不采用微服务) | 单机 on-prem 产品,微服务徒增运维复杂度 |

### 3.2 mtp-core 4.0 的"红线"(避免重蹈覆辙)

```
❌ 不做运行时插件加载、ClassLoader 隔离
❌ 不做"schema 即配置"的动态机制
❌ 不做跨产品业务概念(Device/Server/Alarm 不能进 mtp-core)
✅ 每模块独立 Spring Boot Starter,autoconfigure 默认关闭
✅ 每模块可单独依赖(PI 不引 ACM 模块)
```

> **L4 价值** (面试可讲): 这 5 条红线本质是"**抽象不是越多越好**"——3.x 的 mtp-core 试图为所有 Vertiv 产品提供"通用平台",结果谁都不能修改谁,版本永远卡死。4.0 改用 BOM + Starter 模式,**让产品有自由度,平台只提供"组件"而非"框架"**。

### 3.3 砍掉清单(简历可讲点)

你 `01-overview.md §4.1` 列了完整清单,关键的:

| 旧技术 | 替代方案 | 砍的理由 |
|---|---|---|
| MongoDB | PostgreSQL 16 | 许可证 + 强类型 |
| spring-data-mongodb | JOOQ 开源版 (Apache 2.0) | 类型安全、SQL 透明 |
| 自研 JSON Schema 引擎 | Java record + Bean Validation | 编译期检查 |
| 动态集合 / GenericModelController | RESTful 资源 endpoint | 显式 API 契约 |
| 运行时插件加载 (taf-plugin-*) | Maven 多模块 + Spring Boot Starter | 编译期模块化 |
| Hazelcast (全部 6 类用途) | Caffeine / BlockingQueue / Spring Event / ReentrantLock / @Scheduled / Spring Session JDBC | 单机不需要分布式 + 许可风险 |
| 自研 DataUpgraderX_Y_Z | Flyway | 工业标准 |
| 自研 WebSocket Handler | Spring STOMP + SockJS | 标准化 |

> **关键洞察**: 这张表里大部分"砍" 都不是 "因为 X 不好",而是 "**因为我们的场景用不上 X 提供的高级特性,而它带来的复杂度大于价值**"。**这是 senior 工程师的判断力**。

### 3.4 工期估算的方法论 [面试高频]🎯

你 `01-overview.md §6` 给出了 3/5/10 人三档对照,**核心方法论**:

- **有效人月** = 实际产出工作量 = 1 自然月 × 0.6~0.7
- 关键路径(无论团队多大): S0 立项 → S1 平台 → S3 feature → G3 迁移 → S6 打包 → S7 测试 → S8 Pilot → S9 GA
- **Brooks's Law**: 5 人 → 10 人不能等比例缩短工期(协调成本上升,早期阶段并行度有限)
- 团队规模 vs 工期(方案乙):3 人 22-28 月 / 5 人 12-16 月 / 10 人 8-11 月

> **面试讲法**: "我做的是工期估算,**不是拍脑袋**——基于'有效人月'扣除会议/Review/blocker 的实际产出,按关键路径串行依赖,再叠加 Brooks's Law 的边际收益递减"。

---

## 4. SI 在这个故事里的位置

> 这是你**现有素材里没明说但很重要**的视角。

### 4.1 SI = "PI 4.0 的先行者 + 试验田"

时间线:
1. **2024.07 你入职 Vertiv** → 主要做 SI(SI 4.0 阶段)
2. **SI 4.0**: SNMP / 设备发现 / Zero Engine 信号告警流(经典老技术栈,与 PI 类似)
3. **SI 4.0.1**: MongoDB → FerretDB 切换尝试(**这就是你 FerretDB 调研的来源**)
4. **SI 4.1**: Java 8→21 / SB 2→3 / Hazelcast 3→5 / MySQL→SQLite(**这就是 PI 4.0 重构会借鉴的升级路径**)
5. **后来**: 你被拉去做 PI 4.0 重构调研(因为 SI 4.1 的经验直接可复用)

### 4.2 SI 的经验 → PI 4.0 决策映射

| SI 经验 | 对 PI 4.0 的指导 |
|---|---|
| FerretDB 调研失败(SI 4.0.1) | **PI 4.0 跳过 FerretDB 阶段,直接迁 PG** |
| Hazelcast 3→5 升级踩坑(SI 4.1) | **PI 4.0 直接砍 Hazelcast** |
| Java 8→21 升级路径已跑通(SI 4.1) | **PI 4.0 复用同一升级路径** |
| MySQL→SQLite 切换经验(SI 4.1) | (PI 4.0 不需要,但有数据库切换方法论) |

> **简历金句**: "SI 4.1 的升级实践,直接转化为 PI 4.0 重构方案的'技术风险已验证'清单——这是我能在 PI 4.0 决策中做出 confident 判断的底气"。

### 4.3 PI 与 SI 不同的地方

| 维度 | PI 4.0 (重构方向) | SI (现状) |
|---|---|---|
| 走 ACM | 不启用 | 启用(licensing/activation) |
| 业务边界 | 监控 + 关机 + 电费 | 监控 + 资管 + 多协议(更广) |
| 设备规模 | 100 台硬上限 | 更大规模 |
| 运行环境 | Win 主 / Linux 辅,无 Docker | Win 主 / Linux,部分场景 Docker |
| 前端 | Angular 14 → 17 (待定) | Angular ? |

---

## 5. 你能从这条线**学到的方法论** [简历亮点]⭐

> 这一节是我提炼的"**抽象方法论**"——可以**脱离 PI/SI** 应用到任何老系统重构中。

### 5.1 三阶段重构方法

```
阶段 1: 反向工程 (Understand)
  ├── 全量代码本地化(克隆所有相关仓库到统一目录)
  ├── 架构维度盘点(每个子系统的职责、技术栈、依赖关系)
  ├── 业务维度盘点(基于产品手册 / 客户文档,逐章对齐到代码模块)
  └── 数据模型盘点(MongoDB 集合 / 表结构 / 关键索引)

阶段 2: 决策 (Decide)
  ├── 列出可选路线(全砍 / 半改 / 推倒)
  ├── 对每条路线评估:工作量、风险、技术债、长期成本、团队能力
  ├── 主动 surface 风险与未决项(refactor_pi 里 9 类风险 + 12 个 [missing])
  └── 输出决策文档,作为团队评审与立项依据

阶段 3: 工程化执行 (Execute)
  ├── 数据迁移工具优先(数据是最不能丢的)
  ├── 平台层先行(底座稳了再做业务)
  ├── 业务模块按优先级实施
  └── 每阶段有明确的"门" (G1...G5),不通过不进入下一阶段
```

### 5.2 几条"反直觉"的判断

1. **"看似快"的渐进改造,经常是"实际更慢"** —— 因为根本架构债无法在渐进中消除
2. **"少即是多"** —— PI 4.0 的核心动作是**砍**(MongoDB / Hazelcast / 插件机制 / 动态 Schema 全砍),不是加
3. **"决策不要拖到 bottleneck"** —— refactor_pi 的 12 个 [missing] 应该尽早回答,而不是等到工程开始才发现卡死
4. **"工期估算要基于有效人月"** —— 自然月 × 0.6~0.7,不要给客户 / 老板拍脑袋

---

## 6. 与你 `file/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| MTP-Core 框架优势 + 缺陷反思 | §1.1, §1.2 | `file/2-projects/vertiv/SI/common/mtp-core-strengths-summary.md` + `mtp-core-deep-analysis.md` (整合见 [`mtp-core-framework.md`](./mtp-core-framework.md)) |
| TAF-CORE 架构图 | §1 整体 | `_build/outlines/2-projects/vertiv/SI/common/architecture/TAF-CORE.outline.md` |
| PI 3.x 架构 | §2 | `file/2-projects/vertiv/refactor_pi/docs/legacy-analysis/01-architecture-overview.md` |
| PI 业务功能 L1-L10 | §2 | `file/2-projects/vertiv/refactor_pi/docs/legacy-analysis/02-business-features.md` |
| MongoDB 集合 | §2 | `file/2-projects/vertiv/refactor_pi/docs/legacy-analysis/03-mongodb-collections.md` |
| PI 4.0 七大决策 | §3 | `file/2-projects/vertiv/refactor_pi/docs/rebuild-plan/01-overview.md` |
| 模块详细职责 | §3 | `file/2-projects/vertiv/refactor_pi/docs/rebuild-plan/02-deep-dive.md` |
| Postgres schema | §3.1 | `file/2-projects/vertiv/refactor_pi/db/postgres/*.sql` |
| ETL 工具 | §3 | `file/2-projects/vertiv/refactor_pi/tools/*.py` |
| FerretDB 调研 | §4.2 | [`./ferretdb-research.md`](./ferretdb-research.md) |
| 依赖升级方法论 | §5.1 | [`./dependency-upgrade.md`](./dependency-upgrade.md) |

---

## 7. [盲点]⚠️ 我看到的、你可能忽视的

1. ~~**`other.md` / `other2.md` 的命名问题**~~ ✅ 已重命名 (2026-04-30) → `mtp-core-strengths-summary.md` + `mtp-core-deep-analysis.md`
2. **SI 与 PI 的对照分析没有独立文档**: 你 SI 4.x 的笔记和 PI refactor 的文档分别存在,但**没人把它们对照起来**——你心里清楚,但**离职后接班人不知道**。
3. **mtp-core 4.0 的 "5 个最必需 starter" 是哪 5 个?** `01-overview.md §6.4` 三人团队建议只做 5 个 starter,但**没列出来**。这是隐含决策,但应该明示。
4. **PI 与 SI 共用 mtp-core 4.0 的版本管理策略没明说**: 双方更新节奏不同,谁主导版本演进?谁负责 BC?

---

> **下一步**:看 [`postgresql-knowledge.md`](./postgresql-knowledge.md)(数据库) 或 [`dependency-upgrade.md`](./dependency-upgrade.md)(升级方法论)
