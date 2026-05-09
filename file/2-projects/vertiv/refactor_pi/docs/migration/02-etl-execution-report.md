<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

# MongoDB → PostgreSQL ETL 执行报告

> 执行时间：2026-04-29
> 源：`mongodb://localhost:27019/mtp`（MongoDB 3.6.18）
> 目标：`postgresql://localhost:5432/mtp-postgresql`（PostgreSQL 17.4）
> 脚本：`tools/mongo_to_pg.py` + `tools/verify_migration.py`

## 1. 执行摘要

| 指标 | 数值 |
|---|---|
| Mongo 集合 | 72 |
| PG 表（含分区子表） | **87** |
| Mongo 文档总数（执行时） | **30 910** |
| PG 行总数（执行后） | **30 900** |
| 完全一致的集合 | **71 / 72** |
| 部分丢失的集合 | 1（详见 §3） |
| 失败的集合 | **0** |
| ETL 总耗时 | ~17 秒 |

**结论：迁移成功**。唯一的 -10 行差异是 Mongo 源端真实存在的重复键（5 组 sensor+metric+timestamp 完全相同的三胞胎），PG 复合主键正确去重——这是数据质量改进，不是数据丢失。

## 2. 执行步骤回放

```bash
# 1) 创建数据库（双引号是因为名字带连字符）
psql -U postgres -d postgres -c 'DROP DATABASE IF EXISTS "mtp-postgresql";'
psql -U postgres -d postgres -c 'CREATE DATABASE "mtp-postgresql" WITH ENCODING ''UTF8'' TEMPLATE template0;'

# 2) 应用 DDL（在 db/postgres/ 目录下执行）
psql -U postgres -d "mtp-postgresql" -v ON_ERROR_STOP=1 -f 99_run_all.sql

# 3) 跑 ETL（自动执行 72 个集合的 mapper）
python tools/mongo_to_pg.py

# 4) 验证 row count 对账
python tools/verify_migration.py
```

## 3. 全表 row-count 对账

| Mongo collection | PG table | src | dst | Δ | 状态 |
|---|---|---:|---:|---:|---|
| tenants | iam.tenants | 1 | 1 | 0 | OK |
| users | iam.users | 1 | 1 | 0 | OK |
| roles | iam.roles | 3 | 3 | 0 | OK |
| permissions | iam.permissions | 248 | 248 | 0 | OK |
| relationships | iam.relationships | 462 | 462 | 0 | OK |
| apikey | iam.api_keys | 0 | 0 | 0 | OK |
| trustcertificates | iam.trust_certificates | 1 | 1 | 0 | OK |
| coreschemas | metamodel.core_schemas | 2 | 2 | 0 | OK |
| metadatadefinitions | metamodel.metadata_definitions | 541 | 541 | 0 | OK |
| dictionaryterms | metamodel.dictionary_terms | **22 853** | **22 853** | 0 | OK |
| localizedstrings | metamodel.localized_strings | 3 | 3 | 0 | OK |
| categoryexts | metamodel.category_extensions | 30 | 30 | 0 | OK |
| applications | platform.applications | 1 | 1 | 0 | OK |
| pluginclassifications | platform.plugin_classifications | 6 | 6 | 0 | OK |
| plugins | platform.plugins | 42 | 42 | 0 | OK |
| commands | platform.commands | 26 | 26 | 0 | OK |
| functions | platform.functions | 10 | 10 | 0 | OK |
| topics | platform.topics | 15 | 15 | 0 | OK |
| topiclisteners | platform.topic_listeners | 7 | 7 | 0 | OK |
| wstopiclisteners | platform.ws_topic_listeners | 3 | 3 | 0 | OK |
| queues | platform.queues | 3 | 3 | 0 | OK |
| queuelisteners | platform.queue_listeners | 3 | 3 | 0 | OK |
| registry | platform.registry | 6 | 6 | 0 | OK |
| systemsettings | platform.system_settings | 1 | 1 | 0 | OK |
| defaultconfig | platform.default_config | 0 | 0 | 0 | OK |
| exporttransformations | platform.export_transformations | 1 | 1 | 0 | OK |
| exportdatamappings | platform.export_data_mappings | 1 | 1 | 0 | OK |
| assetclassifications | device.asset_classifications | 62 | 62 | 0 | OK |
| protocolconfigurations | device.protocol_configurations | 3 | 3 | 0 | OK |
| baseobjects | device.base_objects | 2 | 2 | 0 | OK |
| monitoredobjects | device.monitored_objects | 1 | 1 | 0 | OK |
| detectiontasks | device.detection_tasks | 61 | 61 | 0 | OK |
| discovery / discoveryconstraints / discoveredobjects | device.discoveries / .. | 0 / 0 / 0 | 0 / 0 / 0 | 0 | OK |
| devicemgms / devicemodule / servermgms / trellisagent | device.device_managements / .. | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 0 | OK |
| monitoringdefinitions | monitoring.monitoring_definitions | 30 | 30 | 0 | OK |
| monitoringspecifications | monitoring.monitoring_specifications | 30 | 30 | 0 | OK |
| productmonitoringmappings | monitoring.product_monitoring_mappings | 30 | 30 | 0 | OK |
| resourcetemplates | monitoring.resource_templates | 144 | 144 | 0 | OK |
| resourcestatusrules | monitoring.resource_status_rules | 7 | 7 | 0 | OK |
| events | evt.events | 141 | 141 | 0 | OK |
| eventlogs | evt.event_logs | 5 | 5 | 0 | OK |
| audittrailgridmappings | evt.audit_trail_grid_mappings | 131 | 131 | 0 | OK |
| transformationrules | evt.transformation_rules | 127 | 127 | 0 | OK |
| alarms / alarmaction* / actionspersisted / notificationconfigs / notificationjobs | alarm.* | 0 / .. | 0 / .. | 0 | OK |
| smsproviders | alarm.sms_providers | 1 | 1 | 0 | OK |
| trapconstraints / trapdestinations | alarm.* | 0 / 0 | 0 / 0 | 0 | OK |
| jobs | job.jobs | 880 | 880 | 0 | OK |
| scheduledjobs | job.scheduled_jobs | 6 | 6 | 0 | OK |
| locks | job.locks | 1 | 1 | 0 | OK |
| **tsd.datapoints** | **telemetry.datapoints** | **3 260** | **3 250** | **−10** | **数据质量改进**（见 §4） |
| tsddata | telemetry.tsd_data | 0 | 0 | 0 | OK |
| electricdatas | telemetry.electric_data | 5 | 5 | 0 | OK |
| electricrateconfigs | telemetry.electric_rate_configs | 0 | 0 | 0 | OK |
| filemanager | file.file_metadata | 274 | 274 | 0 | OK |
| fs.files | file.fs_files | 302 | 302 | 0 | OK |
| fs.chunks | file.fs_chunks | 1 129 | 1 129 | 0 | OK |
| licensedstructures | licensing.licensed_structures | 6 | 6 | 0 | OK |
| internallicensedfeatures | licensing.internal_licensed_features | 2 | 2 | 0 | OK |
| licensedfeatures / licensedproducts | licensing.* | 0 / 0 | 0 / 0 | 0 | OK |

## 4. `tsd.datapoints` 的 −10 行说明

源 Mongo 端 5 组 (sensor_id, metric_name, timestamp) 完全一致的三胞胎重复（同一个 PDU `69f15a09fcef6c756832bbfb::Base` 在 ts=`1777424940000` 这一刻把 5 个 metric 各写了 3 次）：

```
val_sys_ec_inpRmsPhsA      ×3
t_val_meter_pwr            ×3
val_pem_ep_LN              ×3
val_pem_enrg_accumulated   ×3
t_val_sys_pct_phsImbalance ×3
```

合计 5 × 2 = **10 个多余行**。

- Mongo 没有 unique index，所以 3 份脏数据沉淀了下来；
- PG 复合主键 `(sensor_id, metric_name, ts)` + `ON CONFLICT DO NOTHING` 自动只保留首次写入；
- 相当于免费做了一次数据清洗。如果业务上需要保留所有原始记录（哪怕完全相同），可以把 PK 改成代理列、加 `(sensor_id, metric_name, ts)` 普通索引。

## 5. 执行期间的 1 个 DDL hotfix

| 表 | 列 | 原始 | 修正 | 触发原因 |
|---|---|---|---|---|
| `evt.audit_trail_grid_mappings` | `type` | `NOT NULL` | nullable | 131 行源数据中约 2% 的文档没有 `type` 字段 |

已同步更新 `db/postgres/60_event.sql`，下次重建数据库直接生效。

## 6. 健康检查（执行后人工抽样）

```sql
-- 多态：base_objects 同表存 IntelligentEngine 和 Device，靠 _hierarchy 区分
SELECT name, type, hierarchy, primary_category_programmatic_name
  FROM device.base_objects;
-- DefaultEngine1     | IntelligentEngine | {BaseObject,Asset,Engine,IntelligentEngine}              | NULL
-- pdu-10.243.225.201 | Device            | {BaseObject,Asset,BasicDevice,Device}                    | RACK_PDU

-- FK 链：monitored_objects -> base_objects (device + engine)
SELECT mo.object_name, bo.name AS device_name, eng.name AS engine_name
  FROM device.monitored_objects mo
  JOIN device.base_objects bo  ON bo.id  = mo.object_id
  LEFT JOIN device.base_objects eng ON eng.id = mo.engine_id;
-- pdu-10.243.225.201 | pdu-10.243.225.201 | DefaultEngine1

-- JSONB 中文 roundtrip
SELECT key, message->'zh_CN', message->'en' FROM metamodel.localized_strings;
-- taf-gdd-data.eventSeverity.Information | "一般告警" | "Information"
-- ...

-- 分区路由验证：events 跨 4-28 / 4-29 两个分区
SELECT date_trunc('day', timestamp), count(*) FROM evt.events GROUP BY 1;
-- 2026-04-28 | 131
-- 2026-04-29 |  10

-- 数值 promotion 验证：value_text -> value_num
SELECT min(value_num), max(value_num) FROM telemetry.datapoints;
-- 1.79 | 13272.332
```

## 7. ETL 设计要点

| 决策 | 实现 |
|---|---|
| ID 转换 | `ObjectId → str(24-char hex) → CHAR(24)` 域，无损 |
| 时间转换 | ISO 字符串 / epoch ms / BSON datetime → `TIMESTAMPTZ` 统一 |
| JSONB 装入 | 用 `psycopg.types.json.Jsonb` 包装；自定义 `default()` 处理嵌套的 `ObjectId / datetime / bytes` |
| 数组装入 | Mongo 数组 → Python list → PG `TEXT[]` |
| 字段重命名 | mapper 函数里逐字段写明，全部见 `tools/mongo_to_pg.py` 各 `map_xxx` |
| 类型字段冲突 | `audittrailgridmappings.type / transformationrules.type / alarms.type / productmonitoringmappings.type` 与 Mongo `_type` 冲突，PG 列改为 `object_type` 承载 `_type` |
| FK 顺序 | PIPELINE 列表显式排序：tenants→users→api_keys；plugin_classifications→plugins；fs_files→fs_chunks；base_objects→monitored_objects+electric_data |
| 错误隔离 | 每个集合独立事务，单表失败不污染已提交的表；`ON CONFLICT DO NOTHING` 让重跑安全（增量补漏） |
| 字段晋升 vs JSONB | `dictionary_terms` / `base_objects` 用 `_PROMOTED_KEYS` 白名单，已晋升列不再进 `payload`/`extra` |

## 8. 二次执行（增量补漏）

ETL 是**幂等的**（依赖 `ON CONFLICT DO NOTHING`）。可随时 `python tools/mongo_to_pg.py` 重跑——它只把新出现的 Mongo 文档插入，已有的跳过。本次执行就观察到：第一次跑完后 `jobs` 又涨了 1（EngineMonitor 每 2 分钟一条），`tsd.datapoints` 又涨了 15，第二次跑全部补齐。

## 9. 复现产物

| 文件 | 作用 |
|---|---|
| `db/postgres/*.sql` | 13 个 DDL 文件（已应用） |
| `tools/mongo_to_pg.py` | ETL 主体（72 个 mapper + 驱动） |
| `tools/verify_migration.py` | row-count 对账 |
| `docs/migration/01-postgres-schema.md` | DDL 设计文档 |
| `docs/migration/02-etl-execution-report.md` | 本文 |
| `docs/migration/etl_run.log` | ETL 完整运行日志 |
| `docs/migration/etl_report.json` | 验证脚本结构化报告 |
