<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

# PI 4.0 重构总览（决策档案）

> **配套文档**：[`02-deep-dive.md`](./02-deep-dive.md) — 本文档每个章节的详细设计、研究方向与任务分配建议。
> **基线参考**：[`../legacy-analysis/01-architecture-overview.md`](../legacy-analysis/01-architecture-overview.md)（旧架构）、[`../legacy-analysis/02-business-features.md`](../legacy-analysis/02-business-features.md)（业务清单）、[`../legacy-analysis/03-mongodb-collections.md`](../legacy-analysis/03-mongodb-collections.md)（旧数据模型）。
> **数据库草稿起点**：[`../../db/postgres/10_iam.sql`](../../db/postgres/10_iam.sql)。

---

## 0. 结论速读 (TL;DR)

| 关键问题 | 答案 |
|---|---|
| 重构方式 | **完全推倒重写**（而非渐进改造），单产品聚焦 |
| 数据库 | **PostgreSQL 16**（替代 MongoDB）；**不引入 TimescaleDB**，靠原生分区 + 降采样 |
| 集群框架 | **彻底删除 Hazelcast**，以 Caffeine + Spring Event + JDK 并发原语替代 |
| 后端框架 | **Spring Boot 3.X + Java 21 LTS**（替代 Spring Boot 2.6 + Java 8）|
| 平台层 | **mtp-core 4.0 重写为多模块 Spring Boot Starter 库**（无运行时插件加载、无动态 Schema） |
| 产品层 | **pi-server 模块化单体**（10 个 feature，编译期模块 + 配置期开关） |
| 进程模型 | **单 JVM 进程**（不采用微服务） |
| 钩子机制 | Spring 领域事件 (`@TransactionalEventListener`) + Caffeine RemovalListener + 事务发件箱 |
| Zero Engine | **解耦于 PI**，通过 RestTemplate 双向集成；PI 中心化设备模型/采集模板/告警规则 |
| 历史数据 | **由 PI 持久化**（Postgres 原生分区 + 小时/天聚合，原始数据保留 30 天） |
| 打包工具 | **保留 InstallAnywhere**，文档列出 jpackage 作为后续研究项 |
| 运行环境 | Windows 主 + Linux 辅；PostgreSQL/JRE/应用统一打包至安装介质；不使用 Docker |
| 认证授权 | **Spring Security 6 + 自研 SecurityFacade 接口**；ACM（Licensing/Activation/PublicAPI）保留在 mtp-core 4.0，但 PI 不启用 |
| 跨产品账户 | 当前不需要，但 SecurityFacade 预留扩展点 |
| 备份还原 | 离线 ETL 工具（旧 PI → 新 PI），新 PI 不内置 Mongo 兼容读 |
| 前端策略 | **未决** — 候选方案甲（Angular 14 → 17 + 适配新后端）/ 方案乙（保留 Angular 14 + 仅适配） |
| 总工期估算 | 取决于团队规模：3 人 22–28 月（需削范围）/ 5 人 12–16 月（推荐底线）/ 10 人 8–11 月（推荐加速）；详见 §6.3 |

---

## 1. 重构背景

### 1.1 触发因素

1. **MongoDB 许可证变更**：MongoDB 自 2018 起改用 SSPL，2024 年进一步收紧，已不再视为开源协议；继续使用对作为商业软件分发的 PI 构成合规风险。
2. **技术栈陈旧带来的安全债**：Spring Boot 2.6.15（已 EOL）、Java 8（已停止公开免费更新）、Hazelcast 3.12（已停止维护）等多处老化，且**升级链相互卡死**——升 Spring Boot 要求驱动版本、驱动要求 MongoDB 版本、MongoDB 又涉及许可证。
3. **产品深度耦合于动态 JSON Schema + 文档数据库**：当前架构深度依赖"运行时 JSON Schema 校验 + Mongo 文档存储 + 运行时插件装载"三件套，这套组合既限制了产品演进（关系建模困难、查询性能差、跨实体一致性弱），也限制了团队效率（缺乏类型安全、调试困难、IDE 支持薄）。
4. **替代方案如 FerretDB 仅治标不治本**：用 Mongo wire-protocol 兼容层延续现状会持续承担"动态 Schema 包袱"，对长期维护不利。

### 1.2 重构目标

| 目标 | 验收标准 |
|---|---|
| 摆脱 MongoDB 依赖 | 全部数据迁移至 PostgreSQL 16，无任何 Mongo 相关运行时依赖 |
| 升级到现代技术栈 | Spring Boot 3.X + Java 21 LTS + PostgreSQL 16；通过 OWASP 依赖扫描、无 EOL/CVE 高危依赖 |
| 简化架构 | 移除运行时插件机制、Hazelcast、动态 Schema；模块化单体，单 JVM |
| 保持业务功能等价 | PI 3.x 帮助手册定义的所有业务在 4.0 一一对应 |
| 提供可控升级路径 | 离线 ETL 工具完成现网客户数据迁移，零数据丢失 |
| 改善长期维护性 | 类型安全（Java 21 records / sealed），编译期错误检查，单元测试覆盖率 ≥ 80% |
| 不丢失"按需启用业务模块"的优点 | 通过 Maven 多模块 + Spring Boot Starter + 配置开关实现 |

### 1.3 非目标

- ❌ 不追求与 PI 3.x 的运行时数据兼容（通过离线迁移工具处理）
- ❌ 不追求微服务化（单机产品不需要）
- ❌ 不引入容器化部署（offering 限制）
- ❌ 不追求多租户 SaaS（仍是单机 on-prem）
- ❌ 不引入分布式事务、消息中间件（Kafka/RabbitMQ）等不必要的复杂度

---

## 2. 新旧架构对比

### 2.1 旧架构（PI 3.x）— 概览

```
┌────────────────────────────────────────────────────────────────────────────┐
│                  浏览器 (Angular 14, hash router)                          │
│              meta-ui  +  18 个 taf-* lib (lazy loaded)                     │
└──────────────┬─────────────────────────────────────────────────────────────┘
               │ HTTPS 8443  ·  /api/rest/v1/**  ·  /ws (Hazelcast bridged)
               ▼
┌────────────────────────────────────────────────────────────────────────────┐
│  mtp-core / webapp  (Spring Boot 2.6 / Java 8 / war)                       │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  GenericModelController (集合名直接路由 → MongoTemplate 动态查询)    │    │
│  │  JSON Schema 引擎 (Draft v4 + 自定义关键字 → 全局 schemas Map)      │    │
│  │  Plugin Loader (运行时装载 taf-plugin-*.jar，独立 Spring Context)   │    │
│  │  Hazelcast 3.12 (IMap/IQueue/ITopic/Lock/Cluster Session)          │    │
│  │  CGA Roles/Perms · Captcha · ApiKey HMAC · License/Activation      │    │
│  │  Quartz (Hazelcast 主从协调) · WebSocket Handler (ITopic 桥接)     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                       ▼                                                    │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  MongoDB 4.4 (动态集合，文档结构由 JSON Schema 推断)                │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└──────────┬───────────────────────┬─────────────────────────────────────────┘
           │ SNMP / Modbus         │ HTTP REST
           ▼                       ▼
   设备 (UPS/PDU/Server)     Trellis Automation Agent · vCenter Plugin
```

**特征关键词**：单 war 部署 · 元数据驱动 · 动态 Schema · 文档存储 · 运行时插件 · 集群中间件单机用。

### 2.2 新架构（PI 4.0）— 概览

```
┌────────────────────────────────────────────────────────────────────────────┐
│                  浏览器 (Angular 14 或 17, 视前端策略而定)                  │
│        客户端通过 OpenAPI 生成 TS 客户端 + STOMP/SockJS WebSocket           │
└──────────────┬─────────────────────────────────────────────────────────────┘
               │ HTTPS 8443  ·  /api/v1/**  ·  /ws (Spring STOMP)
               ▼
┌────────────────────────────────────────────────────────────────────────────┐
│  pi-app  (Spring Boot 3.x / Java 21 / executable jar / 内嵌 Undertow)       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  pi-web (REST controllers, WebSocket, OpenAPI, exception handling)   │  │
│  ├──────────────────────────────────────────────────────────────────────┤  │
│  │  pi-feature-*  (10 个特性, 模块化单体, autoconfig 启用/关闭)          │  │
│  │  monitoring · alarm · device · energy-billing · server-shutdown       │  │
│  │  vcenter · notification · backup-restore · report · security         │  │
│  ├──────────────────────────────────────────────────────────────────────┤  │
│  │  pi-application (用例编排) · pi-domain (纯 Java 模型 + 端口) ·        │  │
│  │  pi-infra-* (Postgres / Zero Engine client / Trellis Agent client)   │  │
│  ├──────────────────────────────────────────────────────────────────────┤  │
│  │  mtp-core 4.0 starters (依赖)                                         │  │
│  │  security · data · cache · event · rest · i18n · audit · scheduler   │  │
│  │  acm (PI 不启用)                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  通信: Spring ApplicationEvent + Caffeine + Outbox + JDK Concurrency       │
│  调度: Spring @Scheduled                                                   │
│         ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  PostgreSQL 16 (内嵌于安装目录, 单实例)                                │  │
│  │  ─ 业务表 (设备/告警/规则/用户/...)                                    │  │
│  │  ─ 时序数据 (原生 RANGE 分区: raw 30d / hourly 5y / daily 永久)        │  │
│  │  ─ outbox_event (事务发件箱)                                          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└──────────┬─────────────────────────┬───────────────────────────────────────┘
           │ HTTP REST 双向           │ HTTP REST
           ▼                         ▼
    Zero Engine (独立服务)      Trellis Automation Agent · vCenter SDK
    采集执行 / 告警计算
```

**特征关键词**：模块化单体 · 编译期类型 · 关系建模 · 内嵌单库 · 显式领域事件 · 单一进程。

### 2.3 关键差异对比

| 维度 | PI 3.0 | PI 4.0 |
|---|---|---|
| **运行时** | Spring Boot 2.6.15 + Java 8 | Spring Boot 3.x + Java 21 LTS（已在 SI 验证至 3.5.6） |
| **打包** | war + 外置容器 / Tomcat | 可执行 jar + 内嵌 Undertow |
| **数据库** | MongoDB 3.6.18 + 动态集合 | PostgreSQL 16 + 强类型 schema |
| **ORM** | spring-data-mongodb + JsonNode | JOOQ 开源版 + record DTO |
| **DB Migration** | 自研 DataUpgraderX_Y_Z | Flyway |
| **Schema 校验** | 运行时 JSON Schema (Draft v4) | 编译期 Java 类型 + Bean Validation |
| **缓存** | Hazelcast IMap | Caffeine |
| **队列** | Hazelcast IQueue | LinkedBlockingQueue / Disruptor |
| **发布订阅** | Hazelcast ITopic | Spring ApplicationEvent |
| **锁** | Hazelcast Lock + 分布式 Lock | ReentrantLock（删除分布式） |
| **调度** | Quartz + Hazelcast 主从 | Spring `@Scheduled`（未来 ShedLock） |
| **会话** | Hazelcast 集群复制 | Spring Session JDBC（或 in-memory） |
| **WebSocket** | 自定义 Handler + ITopic 桥接 | Spring STOMP + SockJS |
| **插件机制** | 运行时 ClassLoader 装载 | 编译期 Maven 模块 + Spring Boot Starter |
| **REST 风格** | `/api/rest/v1/{collection}` 直暴露集合 | `/api/v1/{resource}` RESTful |
| **响应格式** | 各 endpoint 不一致 | 统一 `ApiResponse<T>` |
| **OpenAPI** | 无 | Springdoc 自动生成，前端 codegen |
| **认证** | HTTP Basic / API Key + 自研 Filter | Spring Security 6 + SecurityFacade |
| **配置存储** | Mongo + ConfigService | Postgres + `@ConfigurationProperties` |
| **多租户 (tenants)** | 顶级概念 | 保留（迁移自旧库） |
| **i18n** | ngx-translate（前端）+ 后端 ResourceBundle | 保持不变 |
| **vCenter 集成** | 独立 Spring Boot 服务 (Gradle, PG) | 收回为 pi-feature-vcenter |
| **采集器（SNMP/Modbus）** | 内置 taf-plugin-snmp 等 | 全部由 Zero Engine 承担 |
| **历史数据** | mtp.tsd (Mongo) | Postgres 原生分区 |
| **JRE / DB 打包** | InstallAnywhere 内嵌 | 仍 InstallAnywhere（jpackage 列为研究项） |

---

## 3. 项目仓库与模块结构

### 3.1 仓库布局

```
vertiv/
├── mtp-core/                       平台基础库 (多模块 Maven, 内部 Maven 仓发布)
├── pi-server/                      PI 4.0 后端 (多模块 Maven)
├── pi-web/                         PI 4.0 前端 (Angular)  ← 沿用现 meta-ui 演进
├── pi-installer/                   PI 4.0 安装包 (InstallAnywhere 工程)
├── pi-migration-tool/              [missing] 旧 PI Mongo → 新 PI Postgres 离线 ETL
├── trellis-automation-agent/       现状保留 (远程关机执行端)
└── (未来)
    ├── si-server/                  SI 重构后, 同样依赖 mtp-core
    └── platform-features/          [missing] 当多产品共享 feature 时再抽出
```

### 3.2 mtp-core 4.0 模块结构

```
mtp-core/
├── mtp-bom/                                ← BOM, 给下游统一依赖版本
├── mtp-parent/                             ← parent pom, 公共构建配置
├── mtp-core-common/                        ← 基础类型/异常/工具
├── mtp-core-security/                      ← Spring Security 6 扩展 + SecurityFacade 接口
│   └── mtp-core-security-spring-boot-starter
├── mtp-core-acm/                           ← 自研 ACM (PI 不启用, SI 启用)
│   ├── mtp-acm-licensing/
│   ├── mtp-acm-activation/
│   ├── mtp-acm-public-api/
│   └── mtp-acm-spring-boot-starter
├── mtp-core-data/                          ← JOOQ + Flyway 模板 + 公共审计字段
│   └── mtp-data-spring-boot-starter
├── mtp-core-cache/                         ← Caffeine 包装 + 命名规范
├── mtp-core-event/                         ← Spring Event 抽象 + 命名规范 + 事务事件
├── mtp-core-rest/                          ← 统一 ApiResponse + 全局异常处理
├── mtp-core-i18n/                          ← Spring MessageSource 工具
├── mtp-core-audit/                         ← 操作日志拦截器
├── mtp-core-scheduler/                     ← @Scheduled 包装 + 监控
└── mtp-core-actuator/                      ← 健康检查/指标扩展
```

**红线**（避免重蹈 mtp-core 3.x 覆辙）：
1. ❌ **不**做运行时插件加载、ClassLoader 隔离
2. ❌ **不**做"schema 即配置" 的动态机制
3. ❌ **不**做跨产品业务概念（Device/Server/Alarm 不能进 mtp-core）
4. ✅ 每模块独立 Spring Boot Starter，autoconfigure 默认关闭
5. ✅ 每模块可单独依赖（PI 不引 ACM 模块）

### 3.3 pi-server 模块结构（重点）

```
pi-server/                             (Maven 多模块)
├── pi-bom/
├── pi-parent/
│
├── pi-domain/                         【纯域】无框架依赖
│   ├── model/         Device, Server, Ups, Pdu, Rack, Site, Alarm, Tenant, User, ...
│   ├── event/         AlarmRaised, DeviceCreated, UserPasswordChanged, ...
│   └── port/          DeviceRepository, NotificationGateway 等抽象接口
│
├── pi-application/                    【应用服务】用例编排, 事务边界
│
├── pi-infra-persistence/              【持久化】 JOOQ 生成 + Repository 实现 + Flyway
├── pi-infra-zero-engine-client/       【ZE 集成】 RestTemplate 客户端 + push/ingest
├── pi-infra-trellis-agent-client/     【关机 Agent 集成】
│
├── pi-feature-monitoring/             【特性 1】实时监控
├── pi-feature-alarm/                  【特性 2】告警
├── pi-feature-device/                 【特性 3】设备 CRUD/拓扑
├── pi-feature-energy-billing/         【特性 4】电费结算
├── pi-feature-server-shutdown/        【特性 5】服务器关机
├── pi-feature-vcenter/                【特性 6】VMware vCenter 集成 (从独立工程收回)
├── pi-feature-notification/           【特性 7】通知中心 (Email/SMS/SNMP-Trap/Webhook)
├── pi-feature-backup-restore/         【特性 8】备份还原
├── pi-feature-report/                 【特性 9】报表 (能耗/告警/审计)
├── pi-feature-security/               【特性 10】用户/角色/权限管理 + 登录
│
├── pi-web/                            【Web 共性】 全局拦截器/异常/STOMP/OpenAPI
└── pi-app/                            【启动】 Spring Boot main + application.yml
```

**每个 pi-feature-* 是垂直切片**：
- 自带 domain submodel + service + repository + REST controller + 自己的 Flyway migrations + 自己的 i18n
- 独立 Spring Boot Starter, 通过 `pi.feature.<name>.enabled=true|false` 开关
- feature 之间禁止直接依赖对方 Repository；仅通过 `ApplicationEvent` 或 `pi-application` 暴露的接口通讯

详细 feature 职责与边界见 [`02-deep-dive.md` §3](./02-deep-dive.md)。

### 3.4 前端结构（保持现状演进）

```
pi-web (Angular) — 视前端策略而定
├── 方案乙 (保 14): meta-ui + 18 个 taf-* lib 沿用; 重写 service 层适配新 OpenAPI
└── 方案甲 (升 17): meta-ui 升 17 + lib 重组到 6-8 个合理边界 + 全面 standalone components
```

无论甲乙：
- 引入 OpenAPI Generator codegen TypeScript 客户端
- WebSocket 切换为 STOMP over SockJS
- 全局错误响应统一处理
- 静态化业务表单（设备/告警/通知/电费/用户）

详细前端改造点和工作量见 [`02-deep-dive.md` §12](./02-deep-dive.md)。

---

## 4. 技术栈对照与替代决策

### 4.1 砍掉/替换清单

| 旧技术 | 状态 | 替代方案 | 理由 |
|---|---|---|---|
| MongoDB 4.4 | **砍** | PostgreSQL 16 | 许可证风险 + 强类型建模 |
| spring-data-mongodb | **砍** | JOOQ 开源版 (Apache 2.0) | 类型安全、SQL 透明 |
| 自研 JSON Schema 引擎 | **砍** | Java record + Bean Validation | 编译期检查 |
| 动态集合 / GenericModelController | **砍** | RESTful 资源 endpoint | 显式 API 契约 |
| 运行时插件加载 (taf-plugin-*) | **砍** | Maven 多模块 + Spring Boot Starter | 编译期模块化 |
| taf-plugin-snmp/modbus/discovery | **砍**（迁出 PI） | Zero Engine 承担 | 采集职责剥离 |
| Hazelcast 3.12 — IMap | **砍** | Caffeine | 单机不需分布式 + 许可风险 |
| Hazelcast 3.12 — IQueue | **砍** | `LinkedBlockingQueue` / Disruptor | 同上 |
| Hazelcast 3.12 — ITopic | **砍** | Spring `ApplicationEvent` | 同上 |
| Hazelcast 3.12 — Lock | **砍** | `ReentrantLock` | 同上 |
| Hazelcast 集群 Session | **砍** | Spring Session JDBC | 同上 |
| Quartz + Hazelcast 主从 | **砍** | Spring `@Scheduled` (未来 ShedLock) | 单机简化 |
| 自研 WebSocket Handler | **砍** | Spring STOMP + SockJS | 标准化 |
| `IMap.addEntryListener` 钩子 | **砍** | 领域事件 + `@TransactionalEventListener(AFTER_COMMIT)` | 事务一致 |
| 不能丢的外部通知 | (新增) | 事务发件箱模式 (Outbox) + `@Scheduled` poller | 至少一次送达 |
| 自研 DataUpgraderX_Y_Z | **砍** | Flyway | 工业标准 |
| Spring Boot 2.6.15 | **升** | Spring Boot 3.x（与 SI 对齐至 3.5.6） | EOL + 安全 |
| Java 8 | **升** | Java 21 LTS | EOL + record/sealed/pattern matching |
| Tomcat 外置 | **改** | 内嵌 Undertow (jar) | 简化部署 + 更小内存占用 |
| pi-vcenter-plugin (独立工程) | **合** | pi-feature-vcenter | 减少进程 |

### 4.2 保留清单

| 旧技术/能力 | 状态 | 说明 |
|---|---|---|
| Angular 14 | **保留**（前端方案待定） | 视方案甲/乙 |
| ngx-translate | **保留** | 与现网客户的 i18n 资源兼容 |
| NgRx | **保留** | 状态管理仍主流 |
| Hash router | **保留** | Web 容器配置成本最低 |
| 自研 ACM (Licensing/Activation/PublicAPI) | **保留**（重写至 mtp-core 4.0） | SI 在用，PI 4.0 不启用，SecurityFacade 预留 |
| CGA 粗粒度权限 | **保留**（迁移至 Spring Security 6 PermissionEvaluator） | 业务依赖 |
| Captcha | **保留** | 安全要求 |
| BCrypt 密码 | **保留** | 直接迁移哈希 |
| HMAC API Key | **保留** | 兼容老接入方 |
| Trellis Automation Agent | **保留**（不动） | 稳定，独立运行 |
| InstallAnywhere | **保留** | 团队熟悉 + 客户认可 |
| 内嵌 PostgreSQL/JRE/应用打包模式 | **保留** | 与现交付链一致 |
| 8443 端口 + HTTPS | **保留** | 客户运维约定 |

### 4.3 关键开源协议清单（合规审查锚点）

| 组件 | 协议 | 风险等级 |
|---|---|---|
| Spring Boot 3.x | Apache 2.0 | ✅ 极低 |
| Java 21 (Eclipse Temurin) | GPL v2 + Classpath Exception | ✅ 低 |
| PostgreSQL 16 | PostgreSQL License (≈MIT) | ✅ 极低 |
| JOOQ 开源版 | Apache 2.0（仅开源 DB） | ⚠️ 低（双许可商业，但 PG 在开源版） |
| Caffeine | Apache 2.0 | ✅ 极低 |
| Flyway 开源版 | Apache 2.0 | ✅ 极低 |
| Springdoc OpenAPI | Apache 2.0 | ✅ 极低 |
| MapStruct | Apache 2.0 | ✅ 极低 |
| Lombok | MIT | ✅ 极低 |
| jpackage / jlink | OpenJDK | ✅ 内置 |
| InstallAnywhere | 商业 | ⚠️（已有 license） |

详细法律风险评估见 [`02-deep-dive.md` §14.2](./02-deep-dive.md)。

---

## 5. 限制条件与前提

### 5.1 业务/产品限制

1. **单机 on-prem 免费产品**：客户期待"开箱即用"，安装即装即跑；运维能力有限
2. **不能使用 Docker**：受 offering 政策限制，所有依赖必须直接打入安装包
3. **支持 Windows + Linux**：Windows 为主，Linux（主流发行版）为辅；不再支持 HP-UX/AIX/Solaris
4. **设备规模硬上限：100 台 UPS+PDU**（PI 3.x 帮助手册明确）
5. **业务功能等价**：4.0 必须覆盖 PI 3.x 帮助手册中的所有功能
6. **双语支持**：中文 + 英文必须保留
7. **8443 HTTPS 端口约定**：客户防火墙策略已开通，不应变更

### 5.2 技术约束

1. **Zero Engine 已独立运行**：PI 4.0 假定 ZE 部署完毕，作为对端服务
2. **Trellis Automation Agent 保持独立**：仍是 Java fat-jar、独立 RPM/MSI
3. **PI 与 SI 分仓**：物理仓分开，但通过共同依赖 mtp-core 4.0 实现平台复用
4. **跨产品账户当前不需要**：PI/SI 仍按"互斥"约束执行，4.0 仅预留扩展点
5. **InstallAnywhere 短期保留**：替换为 jpackage 是后续研究项

### 5.3 团队/组织前提（待你校准）

> [missing] 以下点尚未在讨论中明确，建议立项前盘点：

1. [missing] **团队规模与构成**：后端/前端/测试/DevOps 各几人？
2. [missing] **团队 Java 21 / Spring Boot 3 / Postgres 经验**：是否需要培训？
3. [missing] **团队 Angular 升级经验**：方案甲的可行性取决于此
4. [missing] **测试自动化能力**：当前 PI 3.x 是否有 E2E 套件？基线如何？
5. [missing] **CI/CD 基础设施**：Jenkins/GitLab CI/GitHub Actions？发布物如何归档？
6. [missing] **现网客户数与版本分布**：影响数据迁移工具的兼容范围
7. [missing] **是否有 PSO（专业服务团队）协助现网升级**：影响升级成本评估

---

## 6. 阶段规划与工作量

> 工期是**团队规模的函数**：本节先列阶段顺序与工作量估算，再给出 3 / 5 / 10 人三档下的工期对照。详细周级任务见 [`02-deep-dive.md` §13](./02-deep-dive.md)。

### 6.1 阶段划分（主线 · 逻辑顺序）

> 阶段下方的"持续期"是 **5 人团队 (推荐底线)** 下的估算；3 人 / 10 人下的整体伸缩参见 §6.3。

| 阶段 | 持续期 (5 人基线) | 关键产出 | 退出标准 |
|---|---|---|---|
| **S0 · 立项与盘点** | ~1 月 | 团队/资源/技能/客户盘点；架构评审通过；本文档及补充确认 | 评审会议签字 |
| **S1 · 平台底座** | 2–3 月 | mtp-core 4.0 各 starter 完成（除 ACM）；JOOQ codegen / Flyway 模板就绪；OpenAPI 生成基线；CI 可执行 | mtp-core 0.1.0 内部 release |
| **S2 · 核心域 + 持久化** （与 S1 并行后段） | 3–4 月 | pi-domain / pi-application 模型 + 用例；Postgres schema (IAM/设备/告警/规则/...)；pi-infra-persistence 完成 | 核心 CRUD 单元/集成测试通过 |
| **S3 · 特性模块** | 4–5 月 | 10 个 feature（monitoring/alarm/device/energy-billing/server-shutdown/vcenter/notification/backup-restore/report/security）实现 | 每 feature 80% 单测覆盖、契约测试通过 |
| **S4 · 集成 + ZE 对接** （与 S3 并行后段） | 3 月 | Zero Engine push/ingest 端点；Trellis Agent 集成；前端适配（service/WebSocket） | 端到端 happy path 跑通 |
| **S5 · 数据迁移工具** （与 S2–S3 并行） | 4 月 | pi-migration-tool 完成；至少 3 个真实客户数据集回归通过 | 离线迁移工具 GA |
| **S6 · 打包与安装** | 2 月 | InstallAnywhere 工程整合；安装/卸载/升级路径验证 | Windows + Linux 安装包通过 QA |
| **S7 · 系统测试 + 性能** | 2 月 | 100 台设备容量回归；性能基线（采集/告警/电费）；安全扫描；漏洞修复 | 性能 ≥ PI 3.x，无 CRITICAL/HIGH 漏洞 |
| **S8 · 试点上线 + 文档** | 2 月 | Pilot 客户灰度；运维手册/管理员手册/迁移指南；客户培训 | Pilot 客户验收 |
| **S9 · GA + 现网升级支持** | 持续 | 全量发布；现网升级窗口排期 | 首批升级客户稳定运行 |

### 6.2 工作量估算 (按模块, 不区分团队规模)

> **有效人月** = 实际产出工作量。考虑会议 / code review / blocker / 等待 等开销，**1 自然月 ≈ 0.6–0.7 有效人月**。
> 下表数字是中位估算，乐观/悲观可 ±20%。

| 模块 | 工作量 (有效人月) |
|---|---|
| mtp-core 4.0 (10 个 starter，含 ACM) | 10–14 |
| pi-domain + pi-application | 3–4 |
| pi-infra-* (持久化 / ZE Client / Trellis Agent Client) | 3–4 |
| pi-feature-* (10 个 feature) | 18–24 |
| pi-web (Web 共性：拦截器 / 异常 / OpenAPI / STOMP) | 1.5–2 |
| 前端 · 方案乙 (保 Angular 14 + 适配新后端) | 6–9 |
| 前端 · 方案甲 (升 Angular 17 + 适配新后端) | 8–12 |
| pi-migration-tool (Mongo → Postgres ETL) | 3–4.5 |
| pi-installer (InstallAnywhere 工程整合) | 1.5–2.5 |
| 集成测试 / 性能压测 / 安全审查 | 4–6 |
| 文档 / 培训 / 客户文档 / Release Note | 2–3 |
| **方案乙总计** | **52–73 有效人月** |
| **方案甲总计** | **54–76 有效人月** |

### 6.3 三种团队规模下的工期估算

#### 角色分配假设

| 团队规模 | 后端 | 前端 | 架构师 / Tech Lead | DevOps | QA | 备注 |
|---|---|---|---|---|---|---|
| **3 人** | 1.5（1 全栈兼） | 0.5（兼） | 1（兼后端 TL） | 0（外包/兼） | 0（外包/共用） | 单点风险极高 |
| **5 人** | 2.5 | 1 | 1（兼后端 Senior） | 0.5（兼） | 1（兼 DevOps） | 现实底线，紧张但可行 |
| **10 人** | 5 | 2 | 1（专职） | 1 | 2（1 Lead + 1） | 推荐基线，可同期含前端升级 |

> "兼" 表示一人多角色。

#### 工期对照

| 团队规模 | 方案乙 (保 Angular 14) | 方案甲 (升 Angular 17) | 主要瓶颈 / 备注 |
|---|---|---|---|
| **3 人** | **22–28 个月** + **必须削减范围** | **25–32 个月** + **必须削减范围** | 单点; 必须砍 vCenter / Webhook / PDF 报表 / 部分通知渠道; 强烈建议先扩到 5 人 |
| **5 人** | **12–16 个月** | **14–18 个月** | 前端 1 人成为长尾瓶颈; 关键路径压缩到极限; 推荐底线 |
| **10 人** | **8–11 个月** | **9–12 个月** | 前期 S0/S1 协调成本高; 后端可拆"平台 / 业务"两组并行; 推荐加速 |

#### 关键路径分析

无论团队多大，以下串行链是工期下限（理论最快 ~7–8 月）：

```
S0 立项 (~1m)
   └→ S1 mtp-core 平台 (2-3m)
         └→ S3 大部分 feature 起步
               └→ G3 迁移可用 + S6 打包
                     └→ S7 系统测试
                           └→ S8 Pilot
                                 └→ S9 GA
```

**Brooks's Law 提醒**：从 5 人加到 10 人不能等比例缩短工期（不是 12 月 → 6 月），因为：
- S0 / S1 早期阶段并行度有限（架构未稳，加人会等）
- 协调会议、code review、知识同步成本随规模上升
- 真正可并行的工作集中在 S3 多 feature 阶段

### 6.4 不同团队规模的策略建议

#### 3 人团队（强烈建议先扩到 5 人）

**必做的范围裁剪**：
- 暂不做 `pi-feature-vcenter`（PostgreSQL 数据迁移 + vSphere SDK 学习成本太高）
- 暂不做 `pi-feature-notification` 的 Webhook + SNMP-Trap（保留 Email + SMS 即可）
- 暂不做 `pi-feature-report` 的 PDF 导出（保留 Excel 即可）
- mtp-core 只做 5 个最必需 starter（security / data / event / rest / cache），其余延后
- 前端必须方案乙（无人力做 Angular 升级）
- QA 与 DevOps 完全外包或借用其他团队
- **工期估算 22–28 月**，单点风险极高，**不推荐**

#### 5 人团队（推荐底线，性价比最高）

- 全范围按业务价值排序：核心 monitoring/alarm/device 必出 GA；vCenter / 报表 / 备份还原可走"先内测后公开"
- 前端方案乙；GA 后另排 Angular 升级窗口（4.0.x 后续小版本）
- QA 兼 DevOps，但要有专职 1 人（不能完全外包）
- 后端 TL 兼任架构师；架构决策走 ADR 流程，不留口头决策
- **工期 12–16 月**，是性价比最优的工期

#### 10 人团队（推荐加速 / 同步前端升级）

- 全范围 + 方案甲（Angular 14→17 升级）同期完成
- 后端 5 人按"平台 2 人 + 业务 3 人"拆组并行，业务组按 feature 排 ownership
- 前端 2 人，1 主升级 1 主适配（避免互相阻塞）
- 专职 DevOps 负责 CI/CD + 安装包；专职 QA Lead + QA
- 架构师全职掌总，不下场写代码（避免被业务卷走、维护规划完整性）
- **工期 8–12 月**，最快但需强协调；适合资源充裕、希望"前后端一并现代化"的场景

### 6.5 关键里程碑判定门

| 门 | 通过标准 |
|---|---|
| **G1**（S1 末，平台就绪门） | mtp-core BOM 发布；最小 Spring Boot 应用能基于 mtp-core 启动；Postgres 容器化集成测试跑通 |
| **G2**（S3 末，特性完工门） | 所有规划 feature 单测覆盖率 ≥ 80%；feature 间事件流 e2e 测试通过 |
| **G3**（S5 末，迁移可用门） | 选定 3 个真实客户备份完整迁移成功；数据一致性自动比对脚本通过 |
| **G4**（S7 末，质量门） | 容量测试 (100 设备 + 30 天历史)；OWASP 扫描零 HIGH+；性能基线 ≥ PI 3.x 95 percentile |
| **G5**（S9，GA 门） | 至少 1 个 Pilot 客户运行稳定 ≥ 30 天 |

---

## 7. 风险与未决项

### 7.1 主要风险

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| 团队不熟悉 Java 21 / Spring Boot 3 / JOOQ | 中 | 高 | S0 阶段 2-3 周技术预研 + 培训；建立技术 Spike 项目 |
| Mongo → Postgres 数据迁移漏数据 | 中 | 极高 | pi-migration-tool 必须有自动化数据一致性比对；至少 3 个真实客户数据回归 |
| 业务功能漏移植 | 中 | 高 | 用 PI 3.x 帮助手册逐条勾兑，每条对应 4.0 验收 case |
| 性能不及 PI 3.x（特别是历史聚合查询） | 中 | 中 | S7 阶段专项性能基线，对比 PI 3.x；不达标可临时上 TimescaleDB |
| 前端与后端契约反复变更 | 高 | 中 | OpenAPI 在 S1 末冻结主轮廓；变更走正式 ADR |
| Zero Engine 接口本身仍在演化 | 高 | 高 | 在 S0 末 + ZE 团队共同冻结接口契约文档（双方签 ADR） |
| Angular 14 EOL 漏洞曝出 | 中 | 中 | 方案乙路线必须在 GA 后立即排前端升级窗口 |
| InstallAnywhere license 维护成本 | 低 | 中 | 后续启动 jpackage 替换可行性研究 |
| 客户拒绝迁移（怕折腾） | 中 | 中 | 提供 PSO + 数据迁移可回滚 + 客户文档 + 灰度试点 |

### 7.2 未决项

| # | 项 | 等待信息 | 期望解决时机 |
|---|---|---|---|
| 1 | **前端策略（甲含 Angular 14→17 升级 / 乙保 14）** | 用户决策 | S0 阶段末 |
| 2 | **InstallAnywhere → jpackage 替换决策** | 立项后调研 | S6 阶段 |
| 3 | **Java 8 → 21 的中间是否过 17** | 团队评估 | S0 阶段末 |
| 4 | [missing] **OpenAPI / WebSocket 契约 owner** | 责任人指定 | S0 阶段末 |
| 5 | [missing] **历史数据保留策略**（30 天 / 5 年是否需调整） | 产品/合规校准 | S2 阶段 |
| 6 | [missing] **现网客户基线**（数量、版本分布、迁移意愿） | 业务/PSO 提供 | S0 阶段 |
| 7 | [missing] **License 文件兼容性**（旧 PI 3.x license 能否在 4.0 直接用） | 业务决策 | S5 阶段 |

---

## 8. [missing] 我建议补充的考量

> 以下为我在分析过程中识别但你之前未明确表态的点，建议立项评审前确认。

### 8.1 [missing] 可观测性（Observability）

> **为什么重要**：PI 4.0 上线后将是单进程黑盒，缺乏分布式追踪意识可能让客户故障排查极难。

| 子项 | 建议 |
|---|---|
| 结构化日志 | Logback + JSON Layout（Logstash encoder）；统一字段 `traceId/userId/tenantId/feature` |
| 指标 | Spring Boot Actuator + Micrometer；本地暴露 `/actuator/prometheus` |
| 追踪 | Spring Cloud Sleuth / Micrometer Tracing；至少 traceId 贯穿一次请求 |
| 健康检查 | `/actuator/health` 含 Postgres、Zero Engine、Trellis Agent 探活 |
| 内置仪表盘 | （可选）Grafana 嵌入安装包，给客户运维看的监控视图 |
| 客户故障包导出 | "一键导出诊断包"功能（日志 + 配置 + DB schema 信息 + 系统快照）—— PI 3.x 是否有？ |

### 8.2 [missing] 升级 / 补丁策略

> **为什么重要**：旧 PI 用插件机制可以"替换 jar 即生效"打补丁；4.0 砍掉后，必须有清晰的补丁交付路径。

| 子项 | 建议 |
|---|---|
| 普通版本升级 | 全量重装（旧版备份 → 新版安装 → 数据导入）；30 秒重启可接受 |
| 紧急安全补丁 | 提供"小补丁包"（仅替换 pi-app.jar），停服 → 替换 → 启动；脚本化 |
| 客户如何获取补丁 | 客户门户下载（如有）/ 邮件分发 / PSO 上门 |
| 发布频率约定 | 主版本/次版本/补丁版本（SemVer）+ 发布节奏文档化 |
| 数据库 schema 兼容策略 | Flyway baseline；补丁尽量避免 schema 变更，必须变更时附自动迁移 |

### 8.3 [missing] 回滚策略

> **为什么重要**：客户首次升级到 4.0 出问题时，必须能回到 3.x。

| 子项 | 建议 |
|---|---|
| 升级前自动备份 | pi-migration-tool 强制先备份 PI 3.x 完整 Mongo dump + 配置 |
| 回滚操作 | 重新安装 PI 3.x → 恢复备份 → 启动 |
| 数据回滚（4.0 → 3.x） | 不支持（明确告知客户）；建议升级窗口 24h 内决策 |
| 灰度策略 | 选 3-5 个 Pilot 客户先升，稳定 30 天再全量 |

### 8.4 [missing] 性能容量基线与压测

> **为什么重要**：100 台设备硬上限是产品声明，必须有压测数据背书。

| 子项 | 建议 |
|---|---|
| 容量目标 | 100 台 UPS+PDU + 5000 个数据点 + 1 分钟采样 + 30 天原始历史 |
| 关键指标 | 实时数据接收吞吐、告警触发延迟、电费聚合查询响应时间、WebSocket 推送延迟 |
| 压测工具 | k6 / Gatling 模拟 ZE push；JMeter 模拟前端浏览 |
| 性能门槛 | ≥ PI 3.x 同场景 95% 分位 |
| 容量测试在 S7 阶段 | 配压测脚本 + 自动化报告 |

### 8.5 [missing] 安全审查

| 子项 | 建议 |
|---|---|
| 依赖扫描 | OWASP Dependency-Check + Snyk；CI 集成；零 HIGH+ 才能发布 |
| 静态代码分析 | SonarQube / Checkmarx；至少覆盖核心模块 |
| 渗透测试 | S7 阶段引入第三方或内部红队 |
| OWASP Top 10 自查清单 | 每个 feature 评审时附检查清单 |
| 密钥管理 | License 私钥 / API Key 加密 / 数据库密码 → 安装时随机生成或客户输入；不入仓 |
| TLS 证书 | 安装时自签 + 提供导入客户 CA 证书的途径 |

### 8.6 [missing] 数据保留策略

| 子项 | 建议 |
|---|---|
| 原始信号 | 30 天，按日分区，自动 drop 旧分区 |
| 小时聚合 | 5 年，按月分区 |
| 天聚合 | 永久（客户长周期电费分析用） |
| 告警 | 永久（合规审计） |
| 操作日志 / 审计 | 永久或客户配置（最少 1 年） |
| 客户可配置项 | 通过 Web UI 调整保留期限 |

### 8.7 [missing] 浏览器兼容性

> **当前 PI 3.x 支持哪些浏览器？是否还需兼容 IE 11？** 这直接影响前端 polyfill / Material 主题选择。建议立项前与产品/客户成功对齐。

### 8.8 [missing] 第三方设备 driver 兼容性

> **当前 PI 3.x 通过 14 个 `taf-data-*` 包支持的设备型号，迁移到 ZE 后是否一一对应覆盖？**
> 这是业务功能等价的硬指标，需要 ZE 团队 + PI 团队联合盘点。建议在 S0 末输出一份"设备型号支持矩阵"。

### 8.9 [missing] 客户配置与 License 兼容

> **PI 3.x 客户已发的 License 文件，能否在 PI 4.0 直接生效？**
> - 若能：4.0 的 License 校验逻辑必须兼容 3.x 格式
> - 若不能：升级时给客户重发 License，PSO 协助
> 这是业务决策，建议尽早明确。

### 8.10 [missing] 培训与文档迁移

| 子项 | 建议 |
|---|---|
| 内部研发培训 | Java 21 / Spring Boot 3 / JOOQ / Postgres 集中培训（S0–S1） |
| 内部 QA 培训 | 新 OpenAPI 工具链、新 STOMP WebSocket、新数据库结构 |
| 客户管理员手册 | 在 PI 3.x 帮助手册基础上重写章节（保留中英双语） |
| PSO 升级 SOP | 现网客户升级标准操作流程 |
| API Migration Guide | 给 PI 3.x 集成方（如有外部系统通过 PublicAPIRegistry 接入）的迁移指南 |

### 8.11 [missing] 合规与认证

> **PI 是否需要通过特定合规认证（ISO27001、等保 2.0、GDPR、HIPAA、industry-specific）？**
> 若是，需把对应控制项纳入设计阶段（数据加密、审计日志、访问控制粒度等）；建议立项前与法务/合规团队对齐。

### 8.12 [missing] 多产品共享场景前置思考

> **未来如果出现"PI + SI 同时部署"的客户场景**（即使现在按互斥设计），跨产品账户/SSO 走 SecurityFacade 接口。建议本期就：
> - 确定 SecurityFacade 接口形状
> - 在 mtp-core-acm 的 ACM Starter 里提供"对接 OIDC / SAML" 的预留实现位

---

## 9. 文档地图

| 文档 | 内容 | 用途 |
|---|---|---|
| 本文档 (`01-overview.md`) | 决策摘要 + 架构 + 阶段规划 + 风险/未决 | 评审、决策、对外汇报 |
| [`02-deep-dive.md`](./02-deep-dive.md) | 各模块详细职责、契约、研究方向、任务分配 | 实施参考 |
| [`../legacy-analysis/01-architecture-overview.md`](../legacy-analysis/01-architecture-overview.md) | PI 3.x 架构 | 旧基线 |
| [`../legacy-analysis/02-business-features.md`](../legacy-analysis/02-business-features.md) | PI 3.x 业务功能 | 业务对照 |
| [`../legacy-analysis/03-mongodb-collections.md`](../legacy-analysis/03-mongodb-collections.md) | PI 3.x Mongo 集合清单 | 迁移源 |
| [`../../db/postgres/10_iam.sql`](../../db/postgres/10_iam.sql) | IAM 模块 Postgres schema 草稿 | 数据库设计起点 |

---

**评审建议阅读顺序**：本文档第 0 节速读 → 第 2 节新旧对比 → 第 4 节技术替代 → 第 6 节阶段规划 → 第 8 节 [missing] 项 → 必要时下钻 [`02-deep-dive.md`](./02-deep-dive.md)。
