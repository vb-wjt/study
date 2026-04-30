# PI 4.0 详细设计 · 研究方向 · 任务分配

> **配套文档**：[`01-overview.md`](./01-overview.md) — 总览与决策摘要。本文档是其各章节的展开。
> **阅读方式**：每个章节自包含；评审通过后用作研究方向、任务拆分、责任人指定的参考底本。

---

## 目录

1. [数据库设计](#1-数据库设计)
2. [mtp-core 4.0 各模块详细职责](#2-mtp-core-40-各模块详细职责)
3. [pi-server 各 feature 详细职责与边界](#3-pi-server-各-feature-详细职责与边界)
4. [Zero Engine 集成契约](#4-zero-engine-集成契约)
5. [通讯模式与钩子机制](#5-通讯模式与钩子机制)
6. [认证与授权](#6-认证与授权)
7. [打包与交付](#7-打包与交付)
8. [可观测性与运维](#8-可观测性与运维)
9. [测试策略](#9-测试策略)
10. [CI/CD pipeline](#10-cicd-pipeline)
11. [数据迁移工具](#11-数据迁移工具)
12. [前端改造详细](#12-前端改造详细)
13. [研究方向与任务分配建议](#13-研究方向与任务分配建议)
14. [附录](#14-附录)

---

## 1. 数据库设计

### 1.1 总体策略

- **单 PostgreSQL 16 实例**，安装时随 PI 一起部署
- **schema 划分**：按业务/feature 划分 schema，避免表名冲突
- **Flyway 管理迁移**：每 feature 独立 location（见 §2.4）
- **不引入 TimescaleDB / InfluxDB**：纯 Postgres 原生分区（见 §1.5）
- **JSONB 适度使用**：仅在"字段确实弹性"的场景（设备扩展属性、规则参数、事件 payload），不滥用

### 1.2 Schema 划分（推荐）

| Schema | 用途 | 拥有方 |
|---|---|---|
| `iam` | 租户 / 用户 / 角色 / 权限 / 关系 / 证书 / API Key | feature-security |
| `device` | 设备模型 / 设备实例 / 站点 / 机架 / 拓扑 | feature-device |
| `monitoring` | 实时缓存写库 / 信号定义 | feature-monitoring |
| `ts_signal` | 时序数据（分区表） | feature-monitoring |
| `alarm` | 告警规则 / 当前告警 / 告警历史 | feature-alarm |
| `billing` | 费率方案 / 时段规则 / 账单结果 | feature-energy-billing |
| `notify` | 通知策略 / 通知模板 / 通知历史 | feature-notification |
| `vcenter` | vCenter 凭据 / ESXi 主机 / 虚机映射 | feature-vcenter |
| `shutdown` | 关机策略 / 关机日志 | feature-server-shutdown |
| `report` | 报表模板 / 报表导出历史 | feature-report |
| `audit` | 操作日志 | mtp-core-audit |
| `outbox` | 事务发件箱 | mtp-core-event |
| `system` | 系统配置 / License / 激活状态 / 备份记录 | feature-security + acm |
| `flyway_history` | Flyway 元数据 | Flyway |

### 1.3 表命名约定

- 复数名词：`devices`, `alarms`, `users`
- 关联表：`<a>_<b>`，如 `users_roles`, `roles_permissions`
- 时序分区表：`<schema>.<base>_y<year>m<month>` 或 `_d<yyyymmdd>`
- 公共字段：`id`、`created_at`、`created_by`、`modified_at`、`modified_by`、`version`（乐观锁）
- 软删除：默认不用；如必要使用 `deleted_at TIMESTAMPTZ NULL`

### 1.4 类型规范

| 用途 | 推荐类型 |
|---|---|
| 主键 | `BIGINT GENERATED ALWAYS AS IDENTITY`（不再用 Mongo ObjectId） |
| 旧 ObjectId 兼容（迁移期） | `public.oid` 域类型（`TEXT CHECK (length=24)`），见 `db/postgres/10_iam.sql` |
| 时间戳 | `TIMESTAMPTZ`（绝不要无时区） |
| 字符串大小写不敏感 | `citext`（PG 扩展） |
| 弹性属性 | `JSONB`（必索引时建 GIN） |
| 数值 | `NUMERIC(p,s)`（金额/电费）/ `DOUBLE PRECISION`（信号值） |
| 枚举 | `TEXT CHECK (value IN (...))` 或 `ENUM` 类型；推荐前者（更易演进） |
| 文件二进制 | `BYTEA` 小文件 / 文件系统 + 路径列（大文件） |

### 1.5 时序数据策略（重点）

#### 三层表

```sql
-- 原始信号 · 30 天滚动 · 按天分区
CREATE TABLE ts_signal.raw (
    device_id   BIGINT      NOT NULL,
    signal_id   BIGINT      NOT NULL,
    ts          TIMESTAMPTZ NOT NULL,
    value       DOUBLE PRECISION,
    quality     SMALLINT,
    PRIMARY KEY (device_id, signal_id, ts)
) PARTITION BY RANGE (ts);

-- 小时聚合 · 5 年保留 · 按月分区
CREATE TABLE ts_signal.hourly (
    device_id   BIGINT      NOT NULL,
    signal_id   BIGINT      NOT NULL,
    hour        TIMESTAMPTZ NOT NULL,
    avg_value   DOUBLE PRECISION,
    max_value   DOUBLE PRECISION,
    min_value   DOUBLE PRECISION,
    sum_value   DOUBLE PRECISION,
    sample_count INTEGER,
    PRIMARY KEY (device_id, signal_id, hour)
) PARTITION BY RANGE (hour);

-- 天聚合 · 永久 · 按年分区
CREATE TABLE ts_signal.daily (...) PARTITION BY RANGE (day);
```

#### 分区管理

- **首选 `pg_partman` 扩展**（PostgreSQL License，≈MIT，无许可风险），自动创建/drop 分区
- **备选纯 SQL 维护**：写一个 Spring `@Scheduled` 每日凌晨执行：
  - 创建未来 7 天的 raw 分区
  - 创建未来 3 个月的 hourly 分区
  - drop 30 天前的 raw 分区

#### 聚合 Job

```java
@Scheduled(cron = "0 5 * * * *")  // 每小时第 5 分钟
@Transactional
public void aggregateLastHour() {
    // INSERT INTO ts_signal.hourly
    // SELECT device_id, signal_id, date_trunc('hour', ts), avg(value), max(value), ...
    // FROM ts_signal.raw
    // WHERE ts >= now() - interval '1 hour 5 min' AND ts < date_trunc('hour', now())
    // ON CONFLICT (device_id, signal_id, hour) DO UPDATE ...
}

@Scheduled(cron = "0 30 0 * * *")  // 每天 00:30
public void aggregateYesterday() { ... }
```

#### 容量估算（验证可行性）

100 台设备 × 50 信号 × 1 分钟采样 = **每天 720 万行原始数据**：
- 每行 ~50 字节（PG 优化后） → 每天 ~360MB
- 30 天 raw = ~11GB
- 5 年 hourly（原始的 1/60 → ~120K 行/天）= ~2.5GB
- 永久 daily（原始的 1/1440 → ~5K 行/天）= 长期可控

PG 16 单实例可轻松支撑此规模，无需 TimescaleDB。

### 1.6 索引策略

- 主键自动唯一索引
- 业务唯一约束：`UNIQUE INDEX`（如 `users.username`）
- 高频查询字段：`B-tree` 索引
- JSONB 字段查询：`GIN` 索引
- 时序表：`(device_id, signal_id, ts DESC)` 复合索引（覆盖最常见查询）
- **禁止**：随手在每列上建索引；每个索引都要经过审查

### 1.7 公共数据基线 (Reference Data)

> 旧 PI 通过 mtp-core 的 schema 引擎在启动时灌入 reference data（设备型号、告警等级、权限定义等）。新 PI 通过 Flyway `R__*.sql` repeatable 迁移注入：

```
db/migration/
├── core/
│   ├── V1__init_schemas.sql
│   ├── V2__create_iam.sql
│   └── R__seed_permissions.sql       ← 248 条权限定义
└── feature/
    ├── alarm/
    │   ├── V1__create_alarm_tables.sql
    │   └── R__seed_alarm_levels.sql  ← 告警等级 + i18n key
    └── device/
        ├── V1__create_device_tables.sql
        └── R__seed_device_models.sql ← 设备型号定义（与 ZE 同步源）
```

### 1.8 [missing] 待研究

- **逻辑备份 vs 物理备份**：`pg_dump` 还是 `pg_basebackup`？前者跨版本兼容好，后者快但锁版本
- **Postgres 内置审计**：用 `pgaudit` 扩展还是应用层审计？
- **数据库本地账户与 PI 应用账户**：装机时是否给客户管理员一个 DB 直连账号？默认建议关闭

---

## 2. mtp-core 4.0 各模块详细职责

### 2.1 mtp-core-common

提供：
- 基础类型：`Identifier<T>`、`Result<T,E>`、`Page<T>`、`Slice<T>`
- 异常基类：`MtpException`（business / system 子类）
- 工具：`MtpClock`（可注入）、`Json` 工具、`StringUtils`、`Validation`
- 不依赖 Spring（纯 Java），让任何 Java 模块都可用

**研究项**：是否引入第三方库（如 vavr 提供 `Try`/`Either`），还是自研最小集？建议自研最小集，避免大依赖。

### 2.2 mtp-core-data (Spring Boot Starter)

提供：
- `DataSource` 自动配置（HikariCP）+ Postgres 偏好的连接参数（reWriteBatchedInserts 等）
- JOOQ `DSLContext` 自动配置 + 默认 dialect = POSTGRES
- Flyway 自动配置 + 多 location 注册机制（`FeatureFlywayLocationRegistrar`）
- 公共审计字段拦截器（`@CreatedBy/@CreatedDate/@LastModifiedBy/@LastModifiedDate` JOOQ 集成）
- `Pageable` / `Sort` / `RsqlSpec` 公共查询参数
- 事务模板辅助类

### 2.3 mtp-core-cache

提供：
- `CacheRegistry` 接口包装 Caffeine
- 命名规范：`mtp:<module>:<feature>:<key>`
- 默认 TTL/Size/Policy 配置
- 与 Spring `@Cacheable`/`@CacheEvict` 集成

### 2.4 mtp-core-event

提供：
- 领域事件标记接口 `DomainEvent`
- `@TransactionalEventListener(AFTER_COMMIT)` 包装注解 `@AfterCommitListener`
- **事务发件箱（Outbox）框架**：
  - `OutboxEventEntity` 实体 + Repository
  - `OutboxPublisher` 抽象类（业务实现具体的发送逻辑）
  - 默认 `@Scheduled(fixedDelay)` 轮询 + `SELECT FOR UPDATE SKIP LOCKED` 分布式安全的并发抓取
- `EventNamingValidator` ArchUnit 规则（事件命名规范检查）

### 2.5 mtp-core-rest

提供：
- `ApiResponse<T>` 统一响应包络
- `@ControllerAdvice` 全局异常处理 → 统一错误码 + i18n key
- `RequestId` filter（每个请求生成唯一 traceId）
- 标准错误码字典（`E10001` 等）
- OpenAPI Springdoc 默认配置 + 标签命名规范

### 2.6 mtp-core-security (Spring Boot Starter)

提供：
- Spring Security 6 默认配置（HTTPS、CORS、CSRF、Session、Headers）
- **`SecurityFacade` 接口**（核心扩展点）：
  ```java
  public interface SecurityFacade {
      Optional<AuthenticatedPrincipal> authenticate(LoginRequest req);
      Set<Permission> getPermissions(String userId);
      boolean hasPermission(String userId, String resource, String action);
      void logout(String userId);
  }
  ```
- 默认实现 `LocalSecurityFacade`（基于 Postgres + BCrypt）
- `@PreAuthorize` 自定义 `PermissionEvaluator`（支持 CGA 风格 `feature.taf-monitor.pdu.view`）
- BCrypt 密码服务、Captcha 服务、HMAC API Key 校验
- 登录失败次数 / 密码策略 / Session 超时管理

### 2.7 mtp-core-acm (Spring Boot Starter, opt-in)

> PI 4.0 不启用，SI / 未来产品启用。

子模块：
- `mtp-acm-licensing`：License 文件 RSA 签名校验、过期检查、特性 flag 解析
- `mtp-acm-activation`：产品激活码校验 filter（未激活时只允许激活相关 endpoint）
- `mtp-acm-public-api`：HMAC API Key 注册中心（替代旧 `PublicAPIRegistry`）

激活方式：
```yaml
mtp.acm.enabled: true
mtp.acm.licensing.enabled: true
mtp.acm.activation.enabled: true
mtp.acm.public-api.enabled: true
```

### 2.8 mtp-core-i18n

- Spring `MessageSource` 配置（支持 classpath 多 location）
- 各 feature 自带 `i18n/feature-<name>/messages_<locale>.properties`
- 主语言：英文；次语言：简体中文
- 错误码 ↔ i18n key 映射策略

### 2.9 mtp-core-audit

- `@Auditable` 注解 + AOP 切面 → 自动写入 `audit.operations` 表
- 公共字段：`who / when / what / target / before / after / status / traceId`
- 异步写库（`@Async`）+ 失败兜底（写日志，不影响业务）

### 2.10 mtp-core-scheduler

- 包装 Spring `@Scheduled` + 监控（执行时长、失败率）
- **未来扩展**：当确实需要集群时，集成 ShedLock（仅 Postgres 锁，不引入新依赖）
- **不**集成 Quartz（Quartz 已不必要）

### 2.11 mtp-core-actuator

- Spring Boot Actuator 配置
- 自定义健康检查：Postgres、Zero Engine（HTTP ping）、Trellis Agent
- 内置 `/actuator/info` 包含版本、构建时间、git sha

### 2.12 [missing] 待研究

- **mtp-core 版本管理**：SemVer + 内部 Maven 仓 + Release Note 模板
- **mtp-core 兼容性测试矩阵**：PI 4.0、SI 4.0（未来）、各 starter 单独可用
- **是否拆 multi-repo 还是 mono-repo**：建议 mono-repo（Maven 多模块），方便联动发布

---

## 3. pi-server 各 feature 详细职责与边界

> 每个 feature 是 Maven 模块 + Spring Boot Starter。下方"配置开关"列指 `application.yml` 里的开关 key。

### 3.1 pi-feature-device

**职责**：设备模型 / 设备实例 / 站点 / 机架 / 拓扑层级管理。
**配置开关**：`pi.feature.device.enabled`（必启）

主要 endpoint：
- `GET/POST/PUT/DELETE /api/v1/devices`
- `GET /api/v1/sites/{id}/tree`（拓扑）
- `POST /api/v1/devices/discovery`（触发发现 → 转 ZE）

数据库：`device.devices`、`device.device_models`、`device.sites`、`device.racks`、`device.device_relationships`（拓扑邻接表）

发布事件：`DeviceCreatedEvent`、`DeviceUpdatedEvent`、`DeviceDeletedEvent`、`DeviceModelChangedEvent`

向 ZE 推送：设备模型变更后通过 `pi-infra-zero-engine-client` 推送

### 3.2 pi-feature-monitoring

**职责**：接收 ZE 推送的实时信号、缓存最近 8h、推送前端、查询历史聚合。
**配置开关**：`pi.feature.monitoring.enabled`（必启）

主要 endpoint：
- `POST /api/v1/internal/signals/ingest`（ZE → PI 推送，内部 endpoint，认证仅 ZE）
- `GET /api/v1/signals/realtime?deviceIds=...`（前端拉最新值）
- `GET /api/v1/signals/history?deviceId=...&signalId=...&from=...&to=...&granularity=hour|day`
- WebSocket: `/topic/device/{id}/signal` 推送实时值

数据库：`monitoring.signal_definitions`、`ts_signal.raw / hourly / daily`

订阅事件：`AlarmRaisedEvent`（更新设备状态卡片角标）

### 3.3 pi-feature-alarm

**职责**：告警规则 CRUD、接收 ZE 告警、生命周期、联动触发。
**配置开关**：`pi.feature.alarm.enabled`（必启）

主要 endpoint：
- `GET/POST/PUT /api/v1/alarm-rules`
- `POST /api/v1/internal/alarms/ingest`（ZE → PI 推送）
- `GET /api/v1/alarms/active`、`GET /api/v1/alarms/history`
- `POST /api/v1/alarms/{id}/acknowledge`、`POST /api/v1/alarms/{id}/clear`
- `POST /api/v1/alarms/export`

数据库：`alarm.rules`、`alarm.active`、`alarm.history`、`alarm.lifecycle_events`

发布事件：`AlarmRaisedEvent`、`AlarmAcknowledgedEvent`、`AlarmClearedEvent`、`AlarmRuleChangedEvent`

向 ZE 推送：告警规则变更后

### 3.4 pi-feature-energy-billing

**职责**：电费费率方案、时段规则、能耗账单生成。
**配置开关**：`pi.feature.energy-billing.enabled`

主要 endpoint：
- `GET/POST/PUT /api/v1/billing/rate-plans`
- `POST /api/v1/billing/calculate`（按选定设备 + 时间窗口生成账单）
- `GET /api/v1/billing/history`

依赖（接口调用）：`pi-feature-monitoring` 的 `EnergyAggregateQuery` 接口（小时聚合）

订阅事件：无关键订阅

### 3.5 pi-feature-server-shutdown

**职责**：服务器关机策略、顺序编排、调用 Trellis Agent 执行。
**配置开关**：`pi.feature.server-shutdown.enabled`

主要 endpoint：
- `GET/POST/PUT /api/v1/shutdown/policies`
- `POST /api/v1/shutdown/test`（测试单台）
- `GET /api/v1/shutdown/logs`

订阅事件：`AlarmRaisedEvent`（特定告警触发关机）

依赖：`pi-infra-trellis-agent-client`

数据库：`shutdown.policies`、`shutdown.logs`

### 3.6 pi-feature-vcenter

**职责**：VMware vCenter 集成（接管原 pi-vcenter-plugin 独立工程的功能）。
**配置开关**：`pi.feature.vcenter.enabled`（默认关闭，按客户购买情况开启）

主要 endpoint：
- `GET/POST/PUT/DELETE /api/v1/vcenter/credentials`
- `POST /api/v1/vcenter/discovery`（发现 ESXi/VM）
- `GET /api/v1/vcenter/hosts`、`GET /api/v1/vcenter/vms`

依赖：vCenter SDK（vSphere API）

数据库：`vcenter.credentials`（凭据加密存储）、`vcenter.hosts`、`vcenter.vms`

[missing] **研究项**：vCenter SDK 的 license / 版本兼容范围；旧 pi-vcenter-plugin 的 PostgreSQL 数据如何迁移

### 3.7 pi-feature-notification

**职责**：通知中心，支持邮件 / 短信 / SNMP Trap / Webhook。
**配置开关**：`pi.feature.notification.enabled`，子开关 `pi.feature.notification.email.enabled` 等

主要 endpoint：
- `GET/POST/PUT /api/v1/notifications/policies`
- `GET/POST /api/v1/notifications/templates`
- `GET /api/v1/notifications/history`

订阅事件：`AlarmRaisedEvent`、`AlarmClearedEvent`、`UserPasswordResetRequestedEvent`

依赖：JavaMail（Email）、第三方 SMS provider（如阿里云 SMS / Twilio，按客户）、SNMP4J（Trap 发送）

发件机制：**事务发件箱**（保证不丢通知）

数据库：`notify.policies`、`notify.templates`、`notify.history`

### 3.8 pi-feature-backup-restore

**职责**：业务数据备份 / 还原。
**配置开关**：`pi.feature.backup-restore.enabled`

主要 endpoint：
- `POST /api/v1/backup`（生成备份文件）
- `POST /api/v1/restore`（上传文件 → 还原）
- `GET /api/v1/backup/history`

实现：内部调用 `pg_dump` / `pg_restore`（用户态包装），或纯 SQL 导出业务表（不含 ZE 数据，因 ZE 不存数据）

数据库：`system.backup_records`

[missing] **研究项**：备份是否包含时序数据（raw 30 天）？建议默认仅备份业务表 + 聚合数据，提供"完整备份"选项

### 3.9 pi-feature-report

**职责**：能耗报表 / 告警报表 / 审计报表 / 导出 PDF/Excel。
**配置开关**：`pi.feature.report.enabled`

主要 endpoint：
- `GET /api/v1/reports/energy`
- `GET /api/v1/reports/alarms`
- `POST /api/v1/reports/{id}/export?format=pdf|xlsx`

依赖：Apache POI（xlsx）、iText / OpenPDF（PDF）

数据库：`report.templates`、`report.exports`

### 3.10 pi-feature-security

**职责**：用户 / 角色 / 权限 CRUD、登录、密码策略、Captcha、API Key 管理（仅 PI 用法，与 mtp-core-security 协作）。
**配置开关**：`pi.feature.security.enabled`（必启）

主要 endpoint：
- `POST /api/v1/auth/login`、`POST /api/v1/auth/logout`、`GET /api/v1/auth/me`
- `GET/POST/PUT/DELETE /api/v1/users`
- `GET/POST/PUT/DELETE /api/v1/roles`
- `GET /api/v1/permissions`（系统内置 248 项）
- `POST /api/v1/users/{id}/reset-password`

数据库：`iam.*`（草稿见 `db/postgres/10_iam.sql`）

发布事件：`UserCreatedEvent`、`UserPasswordChangedEvent`、`RoleAssignedEvent`、`UserLockedEvent`

### 3.11 Feature 间通讯总图

```
                ┌──────────────────────────────────────────┐
                │           ApplicationEventBus              │
                └──────────────────────────────────────────┘
                  ↑ publish                ↓ @TransactionalEventListener
   ┌──────────────────┐         ┌─────────────────────┐
   │ pi-feature-device │ → DeviceCreatedEvent → │ pi-feature-monitoring │ (订阅, 注册数据点)
   └──────────────────┘                          │ pi-feature-alarm      │ (订阅, 创建默认规则)
                                                 │ pi-feature-audit      │ (订阅, 写审计)
                                                 └─────────────────────┘

   ┌──────────────────┐         ┌─────────────────────┐
   │ ZE push          │ → /api/v1/internal/alarms/ingest │
   └──────────────────┘                                  │
                                       ↓ AlarmRaisedEvent
                                       ├→ pi-feature-notification (发邮件)
                                       ├→ pi-feature-server-shutdown (评估关机策略)
                                       ├→ pi-feature-monitoring (更新设备状态卡)
                                       └→ pi-feature-audit (审计)

  强契约调用 (应用接口):
   pi-feature-energy-billing → pi-feature-monitoring.EnergyAggregateQuery
   pi-feature-report         → pi-feature-alarm.AlarmHistoryQuery
                              → pi-feature-monitoring.EnergyAggregateQuery
```

### 3.12 [missing] 待研究

- 是否需要 `pi-feature-discovery`（设备发现 UI 和触发逻辑）？或合并到 `pi-feature-device`？建议合并
- 是否需要 `pi-feature-system-settings`（系统级配置 UI）？建议合并到 `pi-feature-security` 或单独立
- 多语言报表（PDF 模板）是否需要在 feature-report 设计时一并考虑？

---

## 4. Zero Engine 集成契约

### 4.1 集成边界

```
        PI                                         Zero Engine
   ┌────────────┐                            ┌─────────────────┐
   │  pi-server │                            │  zero engine    │
   │            │ ─── PUSH (设备模型/规则/凭据) ──→ │                 │
   │            │                            │   采集执行       │
   │            │ ←── PUSH (实时信号值/告警事件) ── │   告警计算       │
   │            │                            │                 │
   │            │ ─── PULL (健康检查/版本) ────→ │                 │
   └────────────┘                            └─────────────────┘
```

### 4.2 PI → ZE 推送（PI 主动 POST）

| 端点 | 时机 | Payload |
|---|---|---|
| `POST {ze}/api/internal/device-models` | 设备模型 CRUD 后 | `{ id, modelCode, signals: [...], commands: [...] }` |
| `POST {ze}/api/internal/devices/{id}/credentials` | 设备凭据更新 | `{ deviceId, snmpVersion, community/auth/priv, modbusAddr, ... }` |
| `POST {ze}/api/internal/alarm-rules` | 告警规则 CRUD 后 | `{ id, deviceId, signalId, condition, severity, ... }` |
| `POST {ze}/api/internal/discovery-jobs` | 触发设备发现 | `{ ipRange, ports, snmpVersions, ... }` |
| `DELETE {ze}/api/internal/devices/{id}` | 设备删除 | — |

### 4.3 ZE → PI 推送（ZE 主动 POST）

| 端点 | 时机 | Payload |
|---|---|---|
| `POST {pi}/api/v1/internal/signals/ingest` | 实时信号值（批量） | `[{ deviceId, signalId, ts, value, quality }]` |
| `POST {pi}/api/v1/internal/alarms/ingest` | 告警事件 | `{ ruleId, deviceId, signalId, triggerTs, severity, raised\|cleared, ... }` |
| `POST {pi}/api/v1/internal/discovery-results` | 发现完成 | `[{ ip, type, model, snmp/... }]` |

### 4.4 互信认证

**两种推荐方案**（择一）：

**A. mTLS 双向 TLS**：PI 装机时生成双方信任的 CA + 客户端证书，注入到 ZE。最安全但部署复杂。

**B. HMAC + Shared Secret**：PI 装机时生成共享密钥，写入 ZE 配置；每次 PI ↔ ZE 调用带 `X-Signature: HMAC-SHA256(secret, body+timestamp)`。简单且足够。

[missing] **研究项**：实际选哪个？建议 B（HMAC），运维成本低。

### 4.5 错误处理与重试

- PI → ZE 推送失败：通过事务发件箱重试，最多 N 次后置 FAILED 并告警运维
- ZE → PI 推送失败：ZE 端缓冲 + 重试（ZE 团队负责）；PI 端用幂等性设计（`PRIMARY KEY (deviceId, signalId, ts)` 自动去重）

### 4.6 契约文档化

- 在 `pi-infra-zero-engine-client` 模块下提供 OpenAPI 3 spec 文档（PI 视角的 ZE 调用契约）
- 在 `pi-feature-monitoring` / `pi-feature-alarm` 的 `internal` controller 提供 PI 视角的接收契约
- 双方在 S0 末签 Architecture Decision Record (ADR) 锚定契约

### 4.7 [missing] 待研究

- ZE 是否提供历史聚合查询 API？答否（已确认 PI 存历史），PI 不需要查 ZE 历史
- ZE 是否能在 PI 不在线时缓冲数据？多久？这影响 PI 维护窗口的容忍度
- ZE 与 PI 的版本兼容性策略（独立版本演进还是绑定）
- 多 ZE 实例下 PI 的处理（虽然现在只有 1 个 ZE，但要预留）

---

## 5. 通讯模式与钩子机制

### 5.1 模式总览

| 场景 | 模式 | 实现 |
|---|---|---|
| 弱耦合事件、一对多、单 JVM 内 | Spring 应用事件 | `ApplicationEventPublisher` + `@TransactionalEventListener(AFTER_COMMIT)` |
| 强契约同步调用、单 JVM 内 | 应用服务接口 | feature 在 `pi-application` 暴露接口，对方依赖接口 |
| 跨进程通讯（PI ↔ ZE / PI ↔ Trellis Agent / PI ↔ vCenter） | HTTP REST | `RestTemplate`（同步）/ `WebClient`（响应式，可选） |
| 不能丢的外部通知（推 ZE / 发邮件） | 事务发件箱 | `outbox.events` 表 + `@Scheduled` poller |
| 缓存被驱逐时清理 | Caffeine RemovalListener | Caffeine 内建 |
| 异步任务（进程内） | Spring `@Async` 或 `TaskExecutor` | 共享 `ThreadPoolTaskExecutor` |
| 定时调度 | Spring `@Scheduled` | Spring 内置 |

### 5.2 领域事件命名规范

- 形式：`<Aggregate><PastTenseVerb>Event`
- 例：`DeviceCreatedEvent`、`AlarmRaisedEvent`、`UserPasswordChangedEvent`
- 放在 `pi-domain/event/` 包下（纯 Java）
- 必须可序列化（即使现在不跨进程，未来 outbox 也需要）

### 5.3 事务事件最佳实践

```java
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void on(DomainEvent event) {
    // 这里执行后才能保证业务事务已 commit
    // 避免脏触发 (业务回滚但通知发出)
}

@TransactionalEventListener(phase = TransactionPhase.AFTER_ROLLBACK)
public void onRollback(DomainEvent event) {
    // 可选: 业务回滚时记录埋点
}
```

### 5.4 事务发件箱模式实现

```sql
CREATE TABLE outbox.events (
    id           BIGSERIAL   PRIMARY KEY,
    aggregate_id TEXT        NOT NULL,
    event_type   TEXT        NOT NULL,
    payload      JSONB       NOT NULL,
    headers      JSONB,                            -- traceId, userId, etc.
    target       TEXT        NOT NULL,             -- 'ZE' | 'EMAIL' | 'WEBHOOK' | ...
    status       TEXT        NOT NULL DEFAULT 'PENDING',  -- PENDING | SENT | FAILED
    retry_count  INT         NOT NULL DEFAULT 0,
    next_retry_at TIMESTAMPTZ,
    last_error   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at      TIMESTAMPTZ
);
CREATE INDEX ix_outbox_pending ON outbox.events (next_retry_at) WHERE status = 'PENDING';
```

**关键 SQL**（保证多 thread 抓取不重复）：
```sql
SELECT * FROM outbox.events
WHERE status = 'PENDING' AND (next_retry_at IS NULL OR next_retry_at <= now())
ORDER BY id
LIMIT 50
FOR UPDATE SKIP LOCKED;
```

### 5.5 钩子机制迁移决策表

| 旧 Hazelcast 钩子用途 | PI 4.0 替代 |
|---|---|
| `IMap.addEntryListener` 通用监听 | Spring 领域事件 + `@TransactionalEventListener(AFTER_COMMIT)` |
| 缓存失效联动 | Caffeine RemovalListener 或领域事件 |
| 业务规则触发（设备变更 → 告警重评） | 领域事件 |
| 审计 / 事件溯源 | 领域事件 + `@Async` |
| WebSocket 推送 | 领域事件 → `SimpMessagingTemplate.convertAndSend()` |
| 推 ZE / 发邮件 / Webhook | 事务发件箱 |
| `IExecutorService.submit` | `@Async` / `CompletableFuture.supplyAsync` |
| `IMap.executeOnKey` (atomic) | service 内 `ReentrantLock` + 普通修改 |
| 跨节点同步 | 删除（PI 单机） |

### 5.6 防御 "忘记发事件"

1. CRUD 模板基类强制发事件
2. PR review checklist
3. ArchUnit / 静态分析规则
4. 单元测试用 `@RecordApplicationEvents` 验证
5. **不**用 AOP 隐式发事件（违背显式优于隐式）

---

## 6. 认证与授权

### 6.1 认证方式（PI 4.0）

| 方式 | 用途 | 实现 |
|---|---|---|
| Form Login + Session Cookie | Web UI 登录 | Spring Security 6 `formLogin()` |
| HTTP Basic | 兼容旧 API 用户（如有） | Spring Security 6 `httpBasic()` |
| HMAC API Key | 第三方系统集成 | mtp-core-security 提供 `ApiKeyAuthenticationProvider` |
| (未来) OIDC / SAML | SSO | 通过 SecurityFacade 接口扩展 |

**JWT 不采用**：单机产品 Session-Cookie 更合适（更安全 + 简单 + 前端零改动）。

### 6.2 授权（CGA 风格）

权限粒度：`feature.<feature>.<resource>.<action>`，例：
- `feature.device.ups.view`
- `feature.device.ups.control`
- `feature.alarm.rule.create`
- `feature.notification.template.edit`

实现：
- 248 个权限定义存在 `iam.permissions` 表（`R__seed_permissions.sql` 初始化）
- 角色与权限多对多：`iam.roles_permissions`
- 用户与角色多对多：`iam.users_roles`
- Spring Security 自定义 `PermissionEvaluator`：
  ```java
  @PreAuthorize("hasPermission('ups', 'view')")
  public List<UpsDto> listUps() { ... }
  ```

### 6.3 SecurityFacade 抽象

详见 §2.6。本期 PI 仅用 `LocalSecurityFacade`（本地 Postgres + BCrypt）。未来跨产品 SSO 通过替换实现接入。

### 6.4 密码策略

- BCrypt（cost = 10）
- 默认策略：长度 ≥ 8、含大小写 + 数字、不与上 N 次密码重复、N 天过期、连续失败 N 次锁定
- 客户可在 UI 调整

### 6.5 Captcha

- 图形验证码（Kaptcha 库）
- 登录失败次数超过阈值后启用
- 也可在客户配置中强制始终启用

### 6.6 多租户 (Tenant)

- 旧 PI 已有 tenants 概念（迁移自 Mongo `tenants` collection）
- `iam.tenants` 表保留（见 `db/postgres/10_iam.sql`）
- 默认部署只有一个 tenant `top`；PI 4.0 不主动暴露多租户管理 UI（业务上 PI 单租户）

### 6.7 [missing] 待研究

- 旧 PI License 文件的 RSA 公钥能否在新 PI 复用？
- 是否引入 Spring Authorization Server 提供 OIDC？建议本期不引入，等真有 SSO 需求时再加
- 现网 API Key 的生命周期管理（轮换、撤销）

---

## 7. 打包与交付

### 7.1 总体方案

**短期（本期）**：保留 InstallAnywhere，把 PostgreSQL/JRE/pi-app.jar/pi-web 静态文件等全部打入安装包。

**长期（研究项）**：用 jpackage 替换 InstallAnywhere，详见下文。

### 7.2 InstallAnywhere 工程结构（保留 + 适配）

```
pi-installer/
├── installer.iap_xml                 ← InstallAnywhere 工程
├── resources/
│   ├── jre/                          ← JRE 21 (Eclipse Temurin)
│   ├── postgres/                     ← PostgreSQL 16 binary (Windows / Linux)
│   ├── app/
│   │   └── pi-app.jar
│   ├── web/                          ← 前端静态文件 (打包 npm build 产物)
│   └── conf/                         ← 默认配置模板
├── custom-code/                      ← TAF-InstallerCustomCode 类似的 Java 钩子
│   ├── postgres-bootstrap.java       ← 装机时初始化 DB (createdb + Flyway baseline)
│   ├── ssl-cert-gen.java             ← 自签证书生成
│   └── service-register.java         ← 注册 Windows Service / systemd
└── README.md
```

### 7.3 装机流程

1. 用户运行 `PI-Setup.exe` / `PI-Setup.sh`
2. InstallAnywhere GUI 引导：选择安装路径、端口、管理员账号
3. 解压资源 → 安装目录
4. 启动 Postgres（首次：`initdb` + 创建库 + Flyway 跑全量 migration）
5. 生成 SSL 自签证书
6. 注册系统服务（Windows Service / systemd unit）
7. 启动 PI 服务
8. 提示用户访问 `https://<host>:8443/setup` 完成首次配置（管理员密码、License 上传等）

### 7.4 升级流程

1. 用户运行新版 `PI-Setup.exe`
2. 检测到旧版安装 → 进入升级模式
3. 提示备份 → 自动调用 `pg_dump` 备份至 `<install>/backup/before-upgrade-<timestamp>.dump`
4. 停止 PI 服务
5. 替换 pi-app.jar / pi-web 静态文件 / Postgres binary（如需要）
6. 启动 PI → Flyway 自动跑增量 migration
7. 验证健康检查 → 升级完成

### 7.5 卸载流程

1. 停止 PI 服务
2. 提示用户：是否保留数据目录？
   - 保留 → 删除 app/runtime，保留 data/conf/logs
   - 完全删除 → 全部删除
3. 取消注册系统服务

### 7.6 jpackage 替换方案（研究项）

> **研究目标**：评估替换 InstallAnywhere 为 jpackage 的工程成本、风险、收益。

研究维度：
- jpackage 在 Windows + Linux 的产物（.msi / .deb / .rpm）是否满足客户期待
- 是否能保留现有装机 GUI 的体验（jpackage GUI 较简朴）
- TAF-InstallerCustomCode 类自定义 Java 钩子能否完整迁移
- 现有 InstallAnywhere license 成本 vs jpackage 零成本的 ROI
- 团队学习曲线
- 装机包大小对比

输出：研究报告 + POC（一个最小可装机的 .msi / .deb）+ 替换决策建议（建议在 PI 4.0 GA 后第二季度执行）

### 7.7 [missing] 待研究

- **离线安装介质**：客户机房通常无外网，必须自包含；这点应贯穿打包设计
- **多语言安装界面**：InstallAnywhere 支持，jpackage 较弱
- **数字签名**：Windows .msi / .exe 需要代码签名证书（防 SmartScreen 警告），有专门 license 开销
- **Linux 包签名**：.rpm GPG 签名 / .deb 签名

---

## 8. 可观测性与运维

### 8.1 日志

- **框架**：Logback + Spring Boot 默认配置
- **格式**：结构化 JSON（生产）/ 易读文本（开发）
- **公共字段**：`timestamp / level / logger / message / traceId / spanId / userId / tenantId / feature`
- **轮转**：按天 + 按大小（默认每天一个文件，单文件 100MB，保留 30 天）
- **路径**：`<install>/logs/pi-app.log`, `pi-app-error.log`, `audit.log`

### 8.2 指标

- **Spring Boot Actuator** 暴露：
  - `/actuator/health` 含自定义 indicator（Postgres、ZE、Trellis Agent）
  - `/actuator/info`（版本、git sha、构建时间）
  - `/actuator/metrics`（业务指标）
  - `/actuator/prometheus`（Prometheus scrape 端点）
- **Micrometer** 注册业务指标：
  - `pi.signals.ingested.count` (rate)
  - `pi.alarms.raised.count` (counter)
  - `pi.alarms.notification.duration.seconds` (histogram)
  - `pi.outbox.pending.size` (gauge)
  - `pi.zero-engine.push.errors.count` (counter)
  - 等

### 8.3 追踪（可选）

- Micrometer Tracing → Brave / OpenTelemetry
- 至少 traceId 贯穿 web → service → DB
- 可选导出至 Zipkin / Jaeger（客户运维通常不需要，但开发期非常有用）

### 8.4 诊断包导出

```
POST /api/v1/admin/diagnostics
→ 返回 .zip 包含：
  - 最近 7 天日志
  - 当前配置（脱敏）
  - DB schema 版本（Flyway info）
  - 系统健康快照
  - Heap / Thread dump（可选）
  - JVM 信息
```

用于客户报障时一键提供给 PSO。

### 8.5 健康监控仪表盘（可选）

- 在 PI 设置页提供"系统健康" 视图：CPU/内存/磁盘/数据库连接池/采集吞吐/告警活跃数
- 不依赖外部 Prometheus/Grafana，纯 Spring Boot Actuator + 前端 chart

### 8.6 [missing] 待研究

- 是否引入 SLF4J 标记机制 (`MDC`) 自动注入 `traceId/userId/tenantId`
- 客户场景下日志级别如何动态调整（建议提供 Web UI + Actuator endpoint）
- 是否提供 SNMP MIB 文件让客户用第三方 NMS 监控 PI 自身状态

---

## 9. 测试策略

### 9.1 测试金字塔

```
        ┌────────┐
        │   E2E  │   ← 5-10 个核心 flow (Cypress / Playwright)
       ┌┴────────┴┐
       │ 集成 / API │   ← 每 feature 5-10 个 API 测试 (RestAssured / Spring TestContainers)
      ┌┴──────────┴┐
      │  服务/单元  │   ← 80%+ 覆盖率 (JUnit 5 + AssertJ + Mockito)
      └────────────┘
```

### 9.2 单元测试（JUnit 5 + AssertJ + Mockito）

- 每个 service / domain 类对应一个 `*Test`
- AAA 结构（Arrange-Act-Assert）
- 命名：`methodName_scenario_expectedBehavior`
- 覆盖率：核心业务 ≥ 80%，整体 ≥ 70%

### 9.3 持久化层集成测试（Testcontainers）

```java
@Testcontainers
class DeviceRepositoryIT {
    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16");
    
    // ... 测试 JOOQ Repository
}
```

### 9.4 Web 层测试

- `@SpringBootTest` + `MockMvc` / `WebTestClient`
- 全链路 happy path + 关键 error path

### 9.5 契约测试

- OpenAPI spec 由后端生成 → 前端基于此 codegen
- 双向契约：前端用 mock 跑测试时校验请求符合 OpenAPI；后端 e2e 测试校验响应符合 OpenAPI

### 9.6 端到端 (E2E)

- 至少覆盖：登录 / 设备列表 / 设备详情实时刷新 / 告警确认 / 通知策略配置 / 备份还原 / 用户管理
- 工具：Cypress（推荐，与 Angular 生态契合）或 Playwright
- 在 CI 上跑：每晚回归 + PR 触发轻量子集

### 9.7 性能测试

- 工具：k6（模拟 ZE push）+ Gatling（前端模拟）
- 场景：
  - 100 设备 × 50 信号 × 1 分钟采样 持续 1 小时
  - 100 个并发用户浏览
  - 1000 个未确认告警下的列表加载
- 基线：≥ PI 3.x 同场景 95% 分位

### 9.8 安全测试

- OWASP Dependency-Check（CI 集成）
- SonarQube（CI 集成）
- 第三方渗透测试（S7 阶段）

### 9.9 [missing] 待研究

- Mutation Testing (PIT) 是否值得引入？建议先不引入，覆盖率达标后再考虑
- 数据迁移工具的测试（详见 §11）

---

## 10. CI/CD pipeline

### 10.1 推荐工具链

- **代码托管**：GitLab / GitHub（公司选择）
- **CI**：GitLab CI / GitHub Actions / Jenkins（公司选择）
- **构建**：Maven 3.9+
- **依赖仓库**：Nexus / Artifactory（内部 Maven 仓）
- **质量门**：SonarQube + OWASP Dependency-Check + JaCoCo
- **制品库**：内部 release 仓存放 mtp-core-* artifact 和 PI 安装包

### 10.2 Pipeline 阶段

```
[1] checkout → [2] build → [3] unit test → [4] integration test
   → [5] security scan → [6] sonar → [7] package → [8] e2e (PR 时跳过)
   → [9] publish artifact → [10] sign installer (release branch)
```

### 10.3 分支策略

- `main`：可发布
- `release/4.0.x`：发布分支，cherry-pick 修复
- `feature/<jira-id>-<desc>`：功能分支
- 严禁 force push 到 main / release

### 10.4 版本号策略（SemVer）

- mtp-core：`1.0.0`、`1.0.1`、`1.1.0`、`2.0.0`
- pi-server：`4.0.0`、`4.0.1`、`4.1.0`
- 重大变更必须 +major
- 内部 BOM 锁定下游用哪个版本

### 10.5 [missing] 待研究

- 是否搭建内部 OpenAPI portal（Swagger UI / ReDoc）供前端 + PSO + 客户集成方使用
- 安装包数字签名的自动化（Windows / Linux）
- 自动化生成 Release Note（基于 commit message 规范）

---

## 11. 数据迁移工具

### 11.1 目标

提供 `pi-migration-tool` 命令行/GUI 工具，将运行中的 PI 3.x（MongoDB）数据迁移到 PI 4.0（PostgreSQL）。

### 11.2 工具形态

- 独立 Java fat-jar（不嵌入 PI 4.0）
- 可在 PSO/客户机器运行
- 命令行参数：源 Mongo URI、目标 Postgres URI、迁移配置（保留多久历史、是否跳过某些 collection 等）

### 11.3 迁移流程

```
1. Pre-check  : 验证源 Mongo / 目标 Postgres 连通性、版本兼容
2. Schema-init: 在目标 Postgres 跑 PI 4.0 全量 Flyway baseline
3. Dump       : 从源 Mongo 全量导出 JSON (按 collection)
4. Transform  : 对每个 collection 应用转换规则 (Mongo doc → Postgres row)
5. Load       : 批量插入 Postgres (COPY 性能最佳)
6. Verify     : 数据一致性自动比对 (count / 关键字段抽检)
7. Report     : 输出迁移报告 (各 collection 行数、警告、错误)
```

### 11.4 集合 → 表的映射规则

详见 [`../legacy-analysis/03-mongodb-collections.md`](../legacy-analysis/03-mongodb-collections.md) 的集合清单。每个集合需要在 `pi-migration-tool` 中提供：
- 字段映射 (Mongo → Postgres 列)
- 类型转换规则 (ObjectId → BIGINT 或 oid 域、Date → TIMESTAMPTZ 等)
- 引用关系修正 (Mongo DBRef → Postgres FK)
- 数据清洗规则 (如某些字段在新模型中不再存在)

### 11.5 时序数据迁移

- 历史信号原始数据：默认**不迁移**（PI 3.x 的 `mtp.tsd` 容量大，迁移代价高，业务上影响小）
- 历史聚合数据：迁移到 `ts_signal.hourly` / `ts_signal.daily`（如旧库有）
- 客户可选：通过参数 `--migrate-raw-history-days=30` 迁移最近 N 天原始数据

### 11.6 测试

- 至少 3 个真实客户备份（去敏后）作为黄金数据集
- 每次工具修改 → 自动跑回归
- 一致性比对：行数、关键字段聚合（如 `device count`、`alarm count`）必须一致

### 11.7 [missing] 待研究

- **迁移期间业务可用性**：PI 3.x 必须停服迁移；停服时间评估？建议 < 4 小时
- **大数据量处理**：批量 COPY、并行处理多 collection
- **失败恢复**：断点续传？还是失败后清空目标库重来？建议后者（更简单、更可靠）
- **多版本源 PI 兼容**：PI 3.0 / 3.1 / 3.2... 数据结构是否完全一致？需要兼容多源版本吗？

---

## 12. 前端改造详细

### 12.1 改造范围（5 大触点）

详细见 [`01-overview.md` §0 - §6](./01-overview.md) 中"前端改造评估" 部分（已展开）。本节聚焦实施细节。

### 12.2 关键技术决策

| 项 | 选型 |
|---|---|
| HTTP 客户端 | Angular HttpClient + OpenAPI Generator 自动生成的 service |
| WebSocket 库 | `@stomp/rx-stomp`（Angular 14 兼容） |
| 表单 | Angular Reactive Forms（静态化为主） |
| 状态管理 | NgRx 14 沿用 |
| 国际化 | ngx-translate 沿用 |
| UI 库 | Angular Material 14 沿用 |
| 图表 | ECharts (taf-lumos) 沿用 |
| 测试 | Karma + Jasmine（单元）+ Cypress（E2E） |

### 12.3 OpenAPI codegen 集成

```bash
# 一次性安装
npm i -D @openapitools/openapi-generator-cli

# build 脚本
"scripts": {
  "api:generate": "openapi-generator-cli generate -i http://localhost:8443/v3/api-docs -g typescript-angular -o src/api-client --additional-properties=ngVersion=14.2,fileNaming=kebab-case"
}
```

每次后端 OpenAPI 更新 → 前端跑一次 → IDE 立刻看到契约变化。

### 12.4 WebSocket 重写

```typescript
// taf-utils/websocket.service.ts (新版)
@Injectable({providedIn: 'root'})
export class WebsocketService {
  constructor(private rxStomp: RxStomp) {
    this.rxStomp.configure({
      brokerURL: `wss://${location.host}/ws`,
      connectionTimeout: 5000,
      reconnectDelay: 5000,
      heartbeatIncoming: 10000,
      heartbeatOutgoing: 10000,
    });
    this.rxStomp.activate();
  }

  subscribe<T>(destination: string): Observable<T> {
    return this.rxStomp.watch(destination)
      .pipe(map(msg => JSON.parse(msg.body) as T));
  }
}

// 用法
this.ws.subscribe<SignalUpdate>(`/topic/device/${id}/signal`)
       .subscribe(update => this.handleSignal(update));
```

### 12.5 Lib 重组（方案甲必做、方案乙可选）

旧 18 个 `taf-*` lib 切分过细，建议合并到 ~8 个：

| 新 lib | 旧 lib 整合 |
|---|---|
| `pi-shell` | meta-ui 主体 |
| `pi-utils` | taf-utils（HTTP/WS/Auth/通用 service） |
| `pi-ui-kit` | taf-lumos + taf-shared-widgets + taf-svg-icon |
| `pi-i18n` | （从 taf-utils 拆出 i18n 部分） |
| `pi-feature-monitoring` | taf-monitor（含 home + device） |
| `pi-feature-alarm` | taf-alarm（含 active + history） |
| `pi-feature-admin` | taf-policy + taf-system + taf-tenant + taf-user |
| `pi-feature-energy-billing` | taf-billing |

### 12.6 表单静态化清单

| 表单 | 旧实现 | 新实现 |
|---|---|---|
| UPS / PDU 详情编辑 | 推测动态 | Reactive Form + 强类型 DTO |
| 告警规则配置 | 推测动态 | Reactive Form |
| 通知策略配置 | 推测动态 | Reactive Form（共用 channel 抽象） |
| 通知模板 | — | Reactive Form |
| 电费方案 | — | Reactive Form |
| 用户/角色/权限 | — | Reactive Form |
| 系统设置 (k-v) | 推测动态 | 保留动态（用 OpenAPI Schema 驱动） |

### 12.7 [missing] 待研究

- 现有 `taf-*` lib 中具体哪些是动态 schema 驱动的？需要 grep 确认
- 现有前端是否有 E2E 套件？基线如何？
- Angular 14 升级到 17 的具体路径（14→15→16→17）的踩坑清单
- 是否引入 Storybook 用作组件库开发与 review

---

## 13. 研究方向与任务分配建议

### 13.1 研究方向矩阵

| 主题 | 优先级 | 研究目标 | 输出 |
|---|---|---|---|
| 数据迁移工具设计 | 高 | 真实客户数据集兼容性、性能、容错 | 设计文档 + POC |
| Zero Engine 契约冻结 | 高 | 与 ZE 团队联合敲定双向 API | ADR + OpenAPI spec |
| jpackage 替换 InstallAnywhere | 中 | 工程成本、风险、收益 | 调研报告 + POC |
| Angular 14 升级到 17 | 中 | 升级路径风险、组件兼容性 | 调研报告 + 试点项目 |
| TimescaleDB 备选方案 | 中 | 万一原生分区不够性能时的预案 | 性能基线对比 |
| OIDC / SAML 接入 | 低 | SSO 接入路径预研 | 设计 ADR |
| 设备型号支持矩阵 | 高 | 与 ZE 团队联合盘点 | 矩阵文档 |
| 客户配置兼容（License/Captcha 等） | 高 | 旧 PI 配置能否直接用 | 兼容性表 |
| 性能基线工具链 | 中 | k6 + Gatling 自动化框架 | 测试套件 |
| 安全合规对齐 | 中 | OWASP / 等保 / GDPR | 合规检查清单 |

### 13.2 团队角色与责任建议

> 实际人选由研发负责人指定，本节是建议责任面。

| 角色 | 主责 | 候选模块 |
|---|---|---|
| 架构师（1） | 整体架构 / mtp-core / 跨 feature 协调 / 技术决策 ADR | mtp-core 全部 |
| 后端 Tech Lead（1） | pi-server 整体 / 性能 / 集成 | pi-domain / pi-application / pi-web / pi-app |
| 后端 Senior（2-3） | feature 开发 | 可拆为：监控/告警/设备一组；电费/关机/vCenter 一组；通知/备份/报表/security 一组 |
| 数据库工程师（0.5） | schema 设计 + 迁移工具 | DB schema 全部 + pi-migration-tool |
| 前端 Tech Lead（1） | 前端整体 + 升级研究（如方案甲） | meta-ui + lib 重组 |
| 前端 Senior（1-2） | feature 视图实现 | 与后端 feature 对应 |
| QA Lead（1） | 测试策略 + 自动化框架 | 测试金字塔全部 |
| QA（1-2） | 用例编写 + 执行 | feature 测试 |
| DevOps（1） | CI/CD + 安装包 + 环境 | pipeline + pi-installer |
| 产品 / PSO 代言（0.5） | 业务对齐 + 客户兼容性 + 现网升级 | 数据迁移 + 客户文档 |

### 13.3 任务分配的拆分原则

- **垂直切分**：尽量按 feature 切分给 1-2 人独立 ownership，避免多人横向修改同一 feature
- **跨切关注点**：架构师 / Tech Lead 把控 mtp-core 不被业务污染、feature 不互相侵入
- **轮换机制**：每个 feature 至少有 1 个 backup owner，避免单点失败
- **共享会议节奏**：每周一次架构对齐 + 每日 standup（按团队风格）

### 13.4 决策与变更流程

- 重大技术决策（架构变更、依赖增减、契约变更）→ 撰写 ADR（Architecture Decision Record）
- ADR 模板：背景 / 备选方案 / 决策 / 后果 / 状态
- 存放在 `docs/adr/0001-xxx.md`、`0002-xxx.md`...
- 评审通过后归档；变更需新 ADR 撤销/取代旧 ADR

---

## 14. 附录

### 14.1 详细技术选型对比

| 类别 | 候选 1 (推荐) | 候选 2 | 候选 3 | 决策 |
|---|---|---|---|---|
| ORM | JOOQ 开源版 | MyBatis-Flex | Spring Data JDBC | JOOQ（type-safe DSL，团队体验好；许可证风险低） |
| DB Migration | Flyway | Liquibase | 自研 | Flyway（YAML/SQL 简单，社区大） |
| 缓存 | Caffeine | Ehcache | (Hazelcast) | Caffeine（性能 + 简洁） |
| 调度 | Spring `@Scheduled` | Quartz | XXL-Job | Spring（无外部依赖；集群再上 ShedLock） |
| 时序存储 | PG 原生分区 | TimescaleDB | InfluxDB | PG 原生分区（零许可风险） |
| OpenAPI 生成 | Springdoc | Swagger Core | (手写) | Springdoc（Spring Boot 3 原生支持） |
| WebSocket | Spring STOMP | Atmosphere | (Hazelcast bridge) | Spring STOMP（标准化） |
| 验证码 | Kaptcha | EasyCaptcha | reCAPTCHA | Kaptcha（无外部依赖） |
| Email | Spring Mail | Apache Commons Email | (自研) | Spring Mail |
| Excel 导出 | Apache POI | EasyExcel | — | EasyExcel（流式，性能更好） |
| PDF 导出 | OpenPDF | iText 7 商业版 | — | OpenPDF（LGPL） |
| 测试容器 | Testcontainers | embedded-postgres | — | Testcontainers |
| HTTP 客户端 | RestTemplate | WebClient | OpenFeign | RestTemplate（同步、简单；ZE 集成够用） |

### 14.2 关键开源协议风险评估

| 组件 | 协议 | 我们的风险 |
|---|---|---|
| Spring Boot 3.x（已在 SI 验证至 3.5.6） | Apache 2.0 | 极低 |
| Java 21 (Eclipse Temurin) | GPL v2 + Classpath Exception | 低（CPE 允许商业使用） |
| PostgreSQL 16 | PostgreSQL License (≈MIT) | 极低 |
| JOOQ 开源版 | Apache 2.0 | 低（仅开源 DB 用，其余商业 DB 需付费 — 我们用 PG 不付费） |
| MyBatis-Flex | Apache 2.0 | 极低（备选方案） |
| Caffeine | Apache 2.0 | 极低 |
| Flyway 开源版 | Apache 2.0 | 极低 |
| Springdoc | Apache 2.0 | 极低 |
| MapStruct | Apache 2.0 | 极低 |
| Lombok | MIT | 极低 |
| Hibernate Validator | Apache 2.0 | 极低 |
| Apache POI | Apache 2.0 | 极低 |
| OpenPDF | LGPL v3 | 低（动态链接对闭源分发无影响） |
| EasyExcel | Apache 2.0 | 极低 |
| pg_partman | PostgreSQL License | 极低 |
| Kaptcha | Apache 2.0 | 极低 |
| @stomp/rx-stomp | Apache 2.0 | 极低 |
| ngx-translate | MIT | 极低 |
| NgRx | MIT | 极低 |
| Angular | MIT | 极低 |
| Angular Material | MIT | 极低 |
| ECharts | Apache 2.0 | 极低 |
| InstallAnywhere | 商业 | 已购 license |

### 14.3 [missing] 待补充的附录

- 完整 Postgres ER 图（建议 S2 阶段绘制）
- 完整 OpenAPI spec（S1 末输出主轮廓）
- 完整 STOMP destination 命名表
- 完整错误码字典
- 完整业务功能 → feature 映射矩阵
- ADR 索引

---

**文档版本**：v0.1（初稿）
**待补充**：以 `[missing]` 标记的项目；评审会议提出的修订
**下一步**：本文档评审通过后进入 S0 阶段；新增详细设计 ADR 时按 §13.4 流程归档
