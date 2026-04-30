# MongoDB → PostgreSQL 迁移：表结构设计

> 输入：`docs/legacy-analysis/03-mongodb-collections.md`（72 个 Mongo 集合的盘点）
> 输出：`db/postgres/*.sql`（13 个按 schema 分组的 DDL 文件，未执行）
> 目标 PG 版本：**PostgreSQL 16+**（向下兼容到 14）

本设计**只做 schema/DDL**，不涉及业务代码改造、ETL 脚本或运行期数据双写。

---

## 0. TL;DR

| 维度 | 决策 |
|---|---|
| 整体策略 | **混合模式**：稳定字段拍成列 + 插件可扩展字段塞 `JSONB` |
| ID 表示 | `CHAR(24)` 域 `public.oid`（保留 Mongo ObjectId 字符串形态，跨表字符串 ID 100% 可比对） |
| 时间表示 | 全部统一为 `TIMESTAMPTZ`（Mongo 里的 ISO 字符串、epoch ms、BSON datetime 都归一） |
| 多态判别 | 保留 `_hierarchy TEXT[]`（GIN 索引）+ `_type TEXT`（B-Tree 索引），由应用层校验 |
| Schema 组织 | 按职责切 11 个 PG schema（`iam / platform / metamodel / device / monitoring / evt / alarm / job / telemetry / file / licensing`） |
| 时序数据 | `telemetry.datapoints`、`evt.events`、`alarm.alarms`、`job.jobs` 全部 **声明式 RANGE 分区**（按月） |
| GridFS | 提供 `file.fs_files + file.fs_chunks` 兼容表；**强烈建议**改对象存储 |
| TTL | PG 无原生 TTL；用分区 + cron `DROP PARTITION` |
| 加密字段 | 维持应用层加密（不改算法），列上加 `COMMENT` 标注密文出处 |

---

## 1. 设计哲学：为什么是"混合模式"？

PI 的 Mongo 模型是 **元数据驱动**——`metadatadefinitions` 里 541 条 JSON Schema 决定了 `baseobjects.specificProperties.pdu.*` 的字段长什么样。如果硬要把它们全展平成 PG 列，每加一个设备型号都得 ALTER TABLE，**等于把 PI 的核心扩展机制砍掉**。

但反过来，如果整库都用 `id + data JSONB`，等于把 Mongo 文档原封不动塞进 PG，那 SQL 的所有好处（外键、视图、CTE、聚合下推）都白瞎了。

折中方案：**冷热分层**

- **热**：被检索/排序/JOIN/聚合的字段 → 提升为真实列，建索引
  - 例：`base_objects.primary_category_programmatic_name`、`monitored_objects.distribution_status`、`events.timestamp`
- **冷**：插件扩展的、只读不查的、嵌套的 → 保留 JSONB
  - 例：`base_objects.specific_properties`、`monitoring_definitions.components`、`plugins.handlers`
- **GIN 索引兜底**：对所有大 JSONB 列建 `gin (col jsonb_path_ops)`，需要时仍可用 `@>` 查（性能不如列索引但可用）

每个表头部注释里都标注了"哪些字段被提升为列、哪些进 JSONB、为什么"，方便后续 review。

---

## 2. 跨表通用约定

### 2.1 ID：`public.oid` 域

```sql
CREATE DOMAIN public.oid AS CHAR(24)
    CHECK (VALUE ~ '^[0-9a-f]{24}$');
```

**为什么不用 `BIGSERIAL` 或 `UUID`？**

- Mongo 的 `_id` 是 12 字节 ObjectId（24 hex chars）；
- 但 PI 大量地方把 ObjectId **当字符串引用**（`monitoredobjects.objectId`、`events.resourceId`、`users._tenant`、`jobs.scheduledJobId` 全是 24 位 hex 字符串，不是 BSON 类型）；
- 用 `CHAR(24)` 做迁移期 ID，**所有这些跨集合字符串引用 1:1 直接等值比较**，零转换；
- 后续完全可以再加一个 `BIGSERIAL` 内部主键、把 `oid` 降级为 unique index——但那是第二阶段的事。

新行用 `public.gen_oid()`（毫秒前缀 + 8 字节随机数，仍然 24 hex），保持时间排序友好。

### 2.2 时间：全部 `TIMESTAMPTZ`

| Mongo 形式 | PG 列类型 | 转换 |
|---|---|---|
| ISO 字符串 `"2026-04-29T01:08:26.249Z"` | `TIMESTAMPTZ` | `value::timestamptz` |
| epoch ms `BIGINT`（`tsd.datapoints.timestamp`） | `TIMESTAMPTZ` | `public.epoch_ms_to_ts(value)` |
| BSON Date（`fs.files.uploadDate`） | `TIMESTAMPTZ` | 直接读出即可 |
| `YYYY-MM-DD` 字符串（`electricdatas.time`） | `DATE` | `value::date` |

### 2.3 多态：保留 `_hierarchy` 数组

PI 的多态全靠 Mongo 文档里的 `_hierarchy: ["BaseObject","Asset","Device"]` 数组判别。在 PG 里：

```sql
hierarchy   TEXT[]      NOT NULL,
type        TEXT        NOT NULL,        -- _hierarchy[-1] 的快照，方便 B-Tree 索引

CREATE INDEX ix_xxx_hierarchy ON ... USING gin (hierarchy);
```

查询模式：

```sql
-- 查所有 Device 类型的 baseobjects
SELECT * FROM device.base_objects
WHERE hierarchy @> ARRAY['Device'];

-- 查所有 Asset 子类（任意层）
SELECT * FROM device.base_objects
WHERE hierarchy @> ARRAY['Asset'];
```

**这件事 PG 不会替你校验**——和 Mongo 一样，类型链由应用层 `Auditable` 切面写入，DDL 层只做容器。

### 2.4 审计字段：标准化命名

Mongo 用 `_createdBy / _createdDateTime / _modifiedBy / _modifiedDateTime`，PG 全部统一为 `created_by / created_at / modified_by / modified_at`。提供了一个可选的 trigger：

```sql
CREATE TRIGGER tg_xxx_modified BEFORE UPDATE ON xxx
FOR EACH ROW EXECUTE FUNCTION public.tg_touch_modified();
```

迁移期建议**不挂 trigger**（让 ETL 直接搬运历史值），切流后再启用。

### 2.5 JSONB 而不是 JSON

全部用 `JSONB`：二进制存储 + 支持 `gin (col jsonb_path_ops)` + 支持 `@>` `?` `?|` 操作符。

---

## 3. 11 个 PG Schema 的边界

| Schema | 文件 | 收纳的 Mongo 集合 | 备注 |
|---|---|---|---|
| `iam` | `10_iam.sql` | `tenants, users, roles, permissions, relationships, apikey, trustcertificates` | 身份与通用关系图 |
| `metamodel` | `20_metamodel.sql` | `metadatadefinitions, coreschemas, dictionaryterms, localizedstrings, categoryexts` | 元模型 / 字典 / i18n |
| `platform` | `30_platform.sql` | `applications, plugins, pluginclassifications, commands, functions, topics, topiclisteners, wstopiclisteners, queues, queuelisteners, registry, systemsettings, defaultconfig, exporttransformations, exportdatamappings` | 插件运行时 |
| `device` | `40_device.sql` | `assetclassifications, baseobjects, monitoredobjects, protocolconfigurations, detectiontasks, discovery, discoveryconstraints, discoveredobjects, devicemgms, devicemodule, servermgms, trellisagent` | 设备实体与发现 |
| `monitoring` | `50_monitoring.sql` | `monitoringdefinitions, monitoringspecifications, productmonitoringmappings, resourcetemplates, resourcestatusrules` | 监控定义/规范/模板 |
| `evt` | `60_event.sql` | `events, eventlogs, audittrailgridmappings, transformationrules` | 事件与审计 |
| `alarm` | `70_alarm.sql` | `alarms, alarmactionconfigs, alarmactionnodes, alarmactionjobs, actionspersisted, notificationconfigs, notificationjobs, smsproviders, trapconstraints, trapdestinations` | 告警与通知 |
| `job` | `80_job.sql` | `jobs, scheduledjobs, locks` | 作业与锁 |
| `telemetry` | `85_telemetry.sql` | `tsd.datapoints, tsddata, electricdatas, electricrateconfigs` | 时序数据 |
| `file` | `90_file.sql` | `filemanager, fs.files, fs.chunks` | 文件与 GridFS |
| `licensing` | `95_licensing.sql` | `licensedstructures, internallicensedfeatures, licensedfeatures, licensedproducts` | 许可与配额 |

> `evt` 不用 `event` 是因为 `event` 在某些 SQL 方言里是保留字，可能产生歧义。

---

## 4. MongoDB ↔ PostgreSQL 完整对照表（72 集合）

### 4.1 IAM（7 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `tenants` | 1 | `iam.tenants` | `parent_id` 仍为 TEXT（'top' 或 oid），未来可改自引用 FK |
| `users` | 1 | `iam.users` | `tenant` → `tenant_id` 加 FK，`username/email` 用 `citext` |
| `roles` | 3 | `iam.roles` | 直接展平 |
| `permissions` | 248 | `iam.permissions` | 直接展平 |
| `relationships` | 462 | `iam.relationships` | 保持单表 + `(target_id, source_id, context)` 复合索引；后续按 `context` 拆 |
| `apikey` | 0 | `iam.api_keys` | 加 `owner_user_id` FK 到 users |
| `trustcertificates` | 1 | `iam.trust_certificates` | `fileData` BSON Binary → `BYTEA` |

### 4.2 metamodel（5 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `coreschemas` | 2 | `metamodel.core_schemas` | `_id` 是 schema URL，PG 直接做 PK；同时存 TEXT + 生成 JSONB 列 |
| `metadatadefinitions` | 541 | `metamodel.metadata_definitions` | `id`(URL) → `schema_id`，`(collection, modelType)` 走表达式索引 |
| `dictionaryterms` | 22 853 | `metamodel.dictionary_terms` | 高频字段提列，剩余进 `payload`；唯一约束改为 `(classification, programmatic_name)` |
| `localizedstrings` | 3 | `metamodel.localized_strings` | `message` 保留 JSONB（多语言扩展） |
| `categoryexts` | 30 | `metamodel.category_extensions` | 直接展平 |

### 4.3 platform（15 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `applications` | 1 | `platform.applications` | `dependencies` 进 JSONB |
| `plugins` | 42 | `platform.plugins` | `commands/handlers/topics/queueListeners` 全进 JSONB；`classification` 加 FK |
| `pluginclassifications` | 6 | `platform.plugin_classifications` | 全部布尔标志展列 |
| `commands` | 26 | `platform.commands` | `executionTimeout / expectedCompletionTime` 改 INTEGER 秒；`onExecuteCommand / clusterSelector` 进 JSONB |
| `functions` | 10 | `platform.functions` | `parameters / expressions` 进 JSONB |
| `topics` | 15 | `platform.topics` | 直接展平 |
| `topiclisteners` | 7 | `platform.topic_listeners` | `onTopicMessage` 进 JSONB |
| `wstopiclisteners` | 3 | `platform.ws_topic_listeners` | `(topic_name, ws_session_id)` 唯一索引；建议 TTL（见 §6.2） |
| `queues` | 3 | `platform.queues` | 直接展平 |
| `queuelisteners` | 3 | `platform.queue_listeners` | `onQueueEntryAdded` 进 JSONB |
| `registry` | 6 | `platform.registry` | `(category, key)` 唯一索引；`encrypted` 标志保留 |
| `systemsettings` | 1 | `platform.system_settings` | 单例表（`singleton BOOLEAN` + 部分唯一索引） |
| `defaultconfig` | 0 | `platform.default_config` | 占位 |
| `exporttransformations` | 1 | `platform.export_transformations` | 直接展平 |
| `exportdatamappings` | 1 | `platform.export_data_mappings` | 直接展平 |

### 4.4 device（12 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `assetclassifications` | 62 | `device.asset_classifications` | 直接展平 |
| `baseobjects` | 2 | `device.base_objects` | **核心多态表**：Device/Engine 字段全部 nullable，按子类型选择性填充；其余进 `extra` JSONB |
| `monitoredobjects` | 1 | `device.monitored_objects` | `objectId / engineId` 加 FK 到 base_objects；`requestTime` 改 TIMESTAMPTZ |
| `protocolconfigurations` | 3 | `device.protocol_configurations` | `snmp` 子文档保留 JSONB（密文不动） |
| `detectiontasks` | 61 | `device.detection_tasks` | `addingProperties / detectionRules` 进 JSONB |
| `discovery / discoveryconstraints / discoveredobjects` | 0/0/0 | `device.discoveries / discovery_constraints / discovered_objects` | 占位 + 索引对齐 |
| `devicemgms / devicemodule / servermgms / trellisagent` | 0/0/0/0 | 同名（snake_case） | 占位（确认无用后可 DROP） |

### 4.5 monitoring（5 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `monitoringdefinitions` | 30 | `monitoring.monitoring_definitions` | `(programmatic_name, protocol_identifier, override)` 唯一索引；`components` 进 JSONB |
| `monitoringspecifications` | 30 | `monitoring.monitoring_specifications` | `productReferences` → `TEXT[]` + GIN 索引 |
| `productmonitoringmappings` | 30 | `monitoring.product_monitoring_mappings` | `monitoringDefinitionReferences` → `TEXT[]` + GIN |
| `resourcetemplates` | 144 | `monitoring.resource_templates` | `commands` 流水线进 JSONB |
| `resourcestatusrules` | 7 | `monitoring.resource_status_rules` | `alarmMapping / targetResource` 进 JSONB |

### 4.6 evt（4 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `events` | 141 | `evt.events` | **按月分区**（PARTITION BY RANGE on `timestamp`）；`data/oldData/delta` 三件套合并进 `data` JSONB |
| `eventlogs` | 5 | `evt.event_logs` | 直接展平 |
| `audittrailgridmappings` | 131 | `evt.audit_trail_grid_mappings` | 直接展平 |
| `transformationrules` | 127 | `evt.transformation_rules` | `(source_path, type)` 唯一索引；`target` 进 JSONB |

### 4.7 alarm（10 张，几乎全空）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `alarms` | 0 | `alarm.alarms` | **按月分区**；`transitions/notes/data` 进 JSONB |
| `alarmactionconfigs` | 0 | `alarm.alarm_action_configs` | 占位 |
| `alarmactionnodes` | 0 | `alarm.alarm_action_nodes` | `config_id` 加 FK |
| `alarmactionjobs` | 0 | `alarm.alarm_action_jobs` | `alarm_id_list` → `TEXT[]` + GIN |
| `actionspersisted` | 0 | `alarm.actions_persisted` | 占位 |
| `notificationconfigs` | 0 | `alarm.notification_configs` | 占位 |
| `notificationjobs` | 0 | `alarm.notification_jobs` | `(alarm_id, trigger_time)` 索引 |
| `smsproviders` | 1 | `alarm.sms_providers` | 直接展平 |
| `trapconstraints` | 0 | `alarm.trap_constraints` | 占位 |
| `trapdestinations` | 0 | `alarm.trap_destinations` | `(ipv4, ipv6)` 唯一索引 |

### 4.8 job（3 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `jobs` | 836 | `job.jobs` | **按月分区**；`results` 进 JSONB；`startTime/endTime` 改 TIMESTAMPTZ |
| `scheduledjobs` | 6 | `job.scheduled_jobs` | `schedule.cronExpression` 仍在 JSONB（Quartz 兼容） |
| `locks` | 1 | `job.locks` | `_id` 是锁 key，PG 用 TEXT PK 直接保留 |

### 4.9 telemetry（4 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `tsd.datapoints` | 2 375 | `telemetry.datapoints` | **按月分区**；`value` 同时存 `value_num`(数值) + `value_text`(原文)；epoch ms → `TIMESTAMPTZ` |
| `tsddata` | 0 | `telemetry.tsd_data` | 占位（疑似已废弃，确认后 DROP） |
| `electricdatas` | 3 | `telemetry.electric_data` | `(device_id, day, hour)` 唯一索引；金额改 NUMERIC(20,6) |
| `electricrateconfigs` | 0 | `telemetry.electric_rate_configs` | 占位 |

### 4.10 file（3 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `filemanager` | 274 | `file.file_metadata` | `location.{type,address}` 拆为两列；`size` → `BIGINT` |
| `fs.files` | 302 | `file.fs_files` | GridFS 元数据直接对照 |
| `fs.chunks` | 1 129 | `file.fs_chunks` | `data BinData` → `BYTEA`；**强烈建议改 S3，见 §6.6** |

### 4.11 licensing（4 张）

| Mongo collection | docs | PG table | 关键变化 |
|---|---:|---|---|
| `licensedstructures` | 6 | `licensing.licensed_structures` | 直接展平 |
| `internallicensedfeatures` | 2 | `licensing.internal_licensed_features` | `count` → `quota_count` 重命名 |
| `licensedfeatures` | 0 | `licensing.licensed_features` | 占位 |
| `licensedproducts` | 0 | `licensing.licensed_products` | 占位 |

---

## 5. 分区策略：四张高速增长表

| 表 | 分区键 | 分区粒度 | 推荐保留期 | 说明 |
|---|---|---|---|---|
| `evt.events` | `timestamp` | 月 | 90 天热 + 1 年温 | 已 bootstrap 2026-04~06 的 3 个月分区 + 默认分区 |
| `alarm.alarms` | `timestamp` | 月 | 1 年（合规要求待确认） | 同上 |
| `job.jobs` | `created_at` | 月 | 30 天 | EngineMonitor 每 2 分钟一条，全量保留无意义 |
| `telemetry.datapoints` | `ts` | 月（如启用 TimescaleDB 改 7 天） | 12~36 个月 | 设备规模上去后这是最大的写入热点 |

**生产建议**：在每个分区表上挂 `pg_partman` + `pg_cron`，让分区创建/淘汰自动化：

```sql
-- 仅作示意，未在 DDL 中默认启用
SELECT partman.create_parent(
    p_parent_table => 'evt.events',
    p_control      => 'timestamp',
    p_type         => 'native',
    p_interval     => 'monthly',
    p_premake      => 4
);
```

如果选用 **TimescaleDB**，对 `telemetry.datapoints` 改成 `create_hypertable('telemetry.datapoints', 'ts', chunk_time_interval => interval '7 days')`，可以拿到自动 chunk + 压缩 + continuous aggregate。

---

## 6. 7 大坑的迁移对策

承接 `03-mongodb-collections.md` §6 提出的 7 个风险点，下面给 PG 侧的对应处理。

### 6.1 MongoDB 3.6 → PG 16

不再是问题：PG 16 完整支持 `JSONB`、`generated columns`、partitioning、`citext`、`UUID`、`TIMESTAMPTZ`、`gin_trgm_ops` 等所有需要的特性。
**迁移期注意**：Mongo 的 `Decimal128` 在 PG 用 `NUMERIC` 表示；`NumberLong` 用 `BIGINT`；其他数值默认 `DOUBLE PRECISION`。

### 6.2 TTL 缺失

PG 没有原生 TTL，但有更好的：

- **分区 + DROP**（已用于 `events / alarms / jobs / datapoints`）
- **pg_cron 定时清理**（适合 `wstopiclisteners` 这种短生命周期的小表）：

```sql
SELECT cron.schedule(
    'cleanup-ws-listeners',
    '*/5 * * * *',
    $$DELETE FROM platform.ws_topic_listeners
        WHERE created_at < now() - interval '30 minutes'$$
);
```

### 6.3 数据契约靠应用层

PG 提供两种加固方式：

**方案 A（轻量）**：CHECK 约束 + 部分外键
- 已在 DDL 中对 `_hierarchy / _type / programmatic_name / category` 加 NOT NULL；
- 关键引用（`monitored_objects.object_id → base_objects.id`）已加 FK；
- `apikey.owner_user_id`、`alarm_action_nodes.config_id`、`electric_data.device_id` 同上。

**方案 B（重量）**：在关键 JSONB 列上挂 `pg_jsonschema` 校验

```sql
ALTER TABLE device.base_objects
    ADD CONSTRAINT ck_base_objects_specific_props_schema
    CHECK (
        specific_properties IS NULL
        OR jsonb_matches_schema(
            (SELECT schema FROM metamodel.core_schemas WHERE id = '...'),
            specific_properties
        )
    );
```

> 默认 DDL 没启用 B 方案——它会让批量插入慢 5~10×；建议只对最容易出错的 3~5 张表启用。

### 6.4 `relationships` 是隐式图

DDL 里**先保留单表**做迁移，但同步在文档里登记后续拆表清单：

```
iam.relationships  →  按 context 拆为：
   iam.role_grants            (context='userRoles')
   iam.permission_grants      (context='uiapipermissiongrants')
   iam.tenant_principals      (context='tenantPrincipals')
   ...
```

第二阶段重构时按 `context` 各自建表 + 视图层兼容旧查询。

### 6.5 加密字段

- `iam.users.password_hash`：BCrypt（不动算法）
- `device.protocol_configurations.snmp.{readCommunity,writeCommunity}`：应用层 AES（保留密文，**密钥务必随数据一起迁移**，否则不可读）
- `platform.registry.encrypted = true` 的行：同上

DDL 里在这些列上加了 `COMMENT`，提醒维护者"这是密文不要明文输出到日志"。是否提升为 `BYTEA` + 列级 `pgcrypto` 是后续优化项。

### 6.6 GridFS 占了 98% 存储

DDL 提供两条路：

| 路线 | 操作 | 优劣 |
|---|---|---|
| **A. 直接把 GridFS 搬进来** | 用 `file.fs_files + file.fs_chunks` 表 | 1:1 迁移、零应用改动；但 PG 不擅长存大对象，DB 体积虚胖 |
| **B. 改对象存储** | 仅迁 `file.file_metadata`，把 `location_type='s3'` + `location_address='<bucket>/<key>'` | DB 缩到 ~5 MB；需要改一处 `FileServiceImpl` 把 'db' 分支改成 S3 client |

**推荐 B**。已在 `file.file_metadata.location_type` 上预留 `'s3' | 'fs' | 'db'` 三种值。

### 6.7 大量空骨架集合

DDL 里这些表 **建出来但不加 FK 也不加业务索引**（只保留 `_hierarchy GIN` + 主键）。文档明确标注"占位，确认后可 DROP"。

迁移上线前需要和产品确认下面这一组的去留：

```
device.{device_managements, device_modules, server_managements, trellis_agents}
device.{discoveries, discovery_constraints, discovered_objects}
alarm.{trap_constraints, trap_destinations, actions_persisted}
licensing.{licensed_features, licensed_products}
telemetry.{tsd_data, electric_rate_configs}
platform.default_config
iam.api_keys
```

---

## 7. DDL 文件清单与执行顺序

```
db/postgres/
├── 00_extensions.sql      # pgcrypto, btree_gin, pg_trgm, citext (+optional)
├── 01_schemas.sql         # 11 个 CREATE SCHEMA
├── 02_common.sql          # public.oid 域、gen_oid()、tg_touch_modified()、辅助函数
├── 10_iam.sql             # tenants/users/roles/permissions/relationships/api_keys/trust_certificates
├── 20_metamodel.sql       # core_schemas/metadata_definitions/dictionary_terms/localized_strings/category_extensions
├── 30_platform.sql        # applications/plugins/commands/functions/topics/queues/registry/system_settings/exports
├── 40_device.sql          # asset_classifications/base_objects/monitored_objects/protocols/detection/discovery/skeletons
├── 50_monitoring.sql      # monitoring_definitions/specs/mappings/templates/status_rules
├── 60_event.sql           # events(分区)/event_logs/audit_trail/transformation_rules
├── 70_alarm.sql           # alarms(分区)/action_*/notifications/sms/traps
├── 80_job.sql             # jobs(分区)/scheduled_jobs/locks
├── 85_telemetry.sql       # datapoints(分区)/electric_data/electric_rate_configs/tsd_data
├── 90_file.sql            # file_metadata/fs_files/fs_chunks
├── 95_licensing.sql       # licensed_structures/internal/licensed_features/products
└── 99_run_all.sql         # \i 所有上面的脚本（用 psql -v ON_ERROR_STOP=1）
```

**执行（仅在确认后**）：

```bash
createdb -h localhost -U pi pi_refactor
psql -h localhost -U pi -d pi_refactor -v ON_ERROR_STOP=1 \
     -f db/postgres/99_run_all.sql
```

---

## 8. 后续工作（不在本次范围）

按优先级排列：

1. **JPA / MyBatis 实体生成**：基于本 DDL 用 `jOOQ codegen` 或 `hibernate-tools` 生成 entity，比手写更可靠。
2. **ETL 脚本**：写 Mongo→PG 的数据搬运（可用 `mongoexport + jq + psql \copy`，或 Spring Batch）。
3. **双写灰度**：在 `GenericDomainService` 的 write path 里加 PG 影子写入，对账后切流。
4. **`relationships` 拆表**：按 §6.4 方案拆。
5. **`pg_jsonschema` 校验**：按 §6.3 方案 B 选 3~5 张关键表启用。
6. **`pg_partman / pg_cron` 自动化**：替换 bootstrap 的人工分区。
7. **GridFS → 对象存储切换**：按 §6.6 方案 B。
8. **JPA Auditable 切面**：用 Spring `@CreatedBy / @LastModifiedBy` 替代 Mongo 的同名切面。
9. **PG 性能基线**：用真实生产数据回放，确认 GIN 索引、JSONB 大小是否在预期内。

---

## 9. 复现工具

| 文件 | 作用 |
|---|---|
| `tools/mongo_analyze.py` | 抽样统计 Mongo 全量集合的 schema/索引 |
| `tools/mongo_summary.py` | 汇总成可读表格 |
| `tools/mongo_samples.py` | 输出关键集合的字段类型与样本 |
| `docs/legacy-analysis/mongo_report.json` | 上述脚本的结构化输出 |
| `docs/legacy-analysis/03-mongodb-collections.md` | Mongo 现状分析（本设计的输入） |
| `docs/migration/01-postgres-schema.md` | 本文 |
| `db/postgres/*.sql` | 本文产出的 13 个 DDL 文件（**未执行**） |
