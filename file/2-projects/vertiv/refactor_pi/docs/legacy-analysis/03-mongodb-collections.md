# MongoDB 现状分析（实例数据 dump）

> 来源：本地 `mongodb://localhost:27019/mtp` 实例，使用 `tools/mongo_analyze.py` 抽样统计。
> 时间：2026-04-29，对应 `systemsettings.systemVersion = 1.31.6-pi`。
> 配套数据文件：`mongo_report.json`（结构化报告）、`mongo_samples.txt`（抽样字段+样本）。

---

## 0. 一句话结论

PI 把"业务模型 + 行为元数据 + 域字典 + 平台配置"全部沉淀到 **同一个 Mongo 库** 的 72 个集合里，
用 `_hierarchy` 数组做多态判别、用 `metadatadefinitions` 里的 JSON Schema 做字段约束、用 `dictionaryterms` 做运行时枚举字典——
**Java 端只剩通用容器（JsonNode + GenericDomainService），新增"设备类型/告警类型"基本不写 Java，全靠改 JSON 数据**。

这正是 01 文档中"元数据驱动"的物理证据，但也带来明显代价（见 §6）。

---

## 1. 实例规模

| 指标 | 数值 |
|---|---|
| MongoDB 版本 | **3.6.18**（2021-04 已 EOL） |
| 数据库 | `mtp` |
| 集合数 | **72** |
| 文档总数 | 约 **30 000** |
| 存储总量 | 约 **268 MB** |
| 其中 GridFS（`fs.chunks`） | **263 MB**（设备图片） |
| 实际业务数据 | 约 **5 MB**（很小，是初始化 + 1 台 PDU 的运行数据） |

> 这是一个"刚装完、接了 1 台 PDU 跑了几小时"的实例，业务量级几乎是 0；任何"该有几条"的判断需要拿到生产实例核对。

---

## 2. 通用文档形状（"鸭子表"模式）

几乎每个业务集合的文档都长这样：

```json
{
  "_id":              ObjectId(...),
  "_type":            "Plugin" | "Device" | "AlarmType" | ...,        // 短名
  "_hierarchy":       ["BaseObject","Asset","BasicDevice","Device"],   // 类型链
  "_createdBy":       "admin",
  "_createdDateTime": "ISO-8601",
  "_modifiedBy":      "admin",        // 可选
  "_modifiedDateTime":"ISO-8601",     // 可选
  "_tenant":          "<tenantId>",   // 仅 users 等少数集合
  "_owner":           "taf-plugin-x", // 仅 metadatadefinitions
  ...业务字段...
}
```

要点：
- **`_hierarchy` = 单表继承的判别列**。同一集合内多种实体共存，凭 `_hierarchy` 区分。
  - `baseobjects`：`Asset/Engine/IntelligentEngine` 与 `Asset/BasicDevice/Device` 并存
  - `protocolconfigurations`：`SNMPProtocolConfiguration`（未来还可有 ModbusProtocolConfiguration）
  - `licensedstructures`：`BasicLicensedStructure / LicensedOperation / DomainServiceLicensedOperation`
  - 几乎每个集合都自带 `_hierarchy_1` 索引。
- **`_createdBy / _modifiedBy` 审计字段全表统一**——即使是 schema 定义、字典词条也不例外，由 `Auditable` 切面写入。
- **没有任何外键约束**，跨表引用全部用字符串 ID（如 `monitoredobjects.objectId → baseobjects._id` 字符串形式）。

---

## 3. 集合按职责分组

按用途把 72 个集合切成 9 类（带 ★ 的是真正承载业务数据的核心表）。

### 3.1 平台元模型（schema / 字典 / 国际化）

| 集合 | 文档数 | 职责 |
|---|---:|---|
| ★ `metadatadefinitions` | 541 | 全部 JSON Schema 定义（含 `modelConfiguration`、`serviceConfiguration`），按 `id`(URL) / `path` / `(collection, modelType)` 索引 |
| `coreschemas` | 2 | JSON Schema 根/扩展（draft-04 + 自定义关键字） |
| ★ `dictionaryterms` | **22 853** | 域字典：AlarmType / EventType / DatapointType / Severity / UoM……每条带 `providedByPlugin` 标识来源插件 |
| `localizedstrings` | 3 | i18n 文案，`message` 字段是 `{zh_CN, zh, en, en_US}` 对象 |

> `dictionaryterms` 占了非 GridFS 文档数的 **76%**，是真正的"业务知识库"。

### 3.2 应用 / 插件 / 命令 / 总线（运行时元数据）

| 集合 | 文档数 | 职责 |
|---|---:|---|
| `applications` | 1 | 当前部署的应用（`power-insight 3.0.0`） |
| ★ `plugins` | 42 | 已安装插件清单，含 `commands/handlers/topics/queueListeners` 子文档 |
| `pluginclassifications` | 6 | 插件分类（`dataLoader / service / handler …`），决定生命周期策略 |
| ★ `commands` | 26 | 可调用命令（`taf-plugin-snmp.performGetData` 等），含执行超时/集群路由策略 |
| `functions` | 10 | 公式/计算函数（如"乘法"），用 `$(prop1) $(prop2) *` 表达式 |
| `topics` / `topiclisteners` / `wstopiclisteners` | 15 / 7 / 3 | Hazelcast / WebSocket 主题与监听器（处理器引用 Java bean 名） |
| `queues` / `queuelisteners` | 3 / 3 | Hazelcast 队列与处理器 |
| `audittrailgridmappings` | 131 | "哪些 path 上发生 哪种操作 → 走 审计 grid"映射表 |
| `transformationrules` | 127 | 把审计事件按 `sourcePath+type` 转换成业务事件（带 JSONPath `$.xxx` 模板） |

> 完整的"消息/命令/事件总线拓扑"是放在 DB 里、由 PluginLoader 在启动期注册到 Hazelcast / Spring 的。

### 3.3 设备建模（产品级模板，初始化数据）

| 集合 | 文档数 | 职责 |
|---|---:|---|
| `assetclassifications` | 62 | 设备分类法（如 `geist3PhaseWye6CircuitsAssets`） |
| `categoryexts` | 30 | 设备 category → 扩展点（`POWER_METER → powerMeter`） |
| `monitoringdefinitions` | 30 | 协议级采集定义（`systemItaSic` 等，平均 20 KB/条，包含 datapointMappings/eventMappings） |
| `monitoringspecifications` | 30 | 业务级采集规范（关联 `productReferences`，含 `monitoringProperties.reportingRate`） |
| `productmonitoringmappings` | 30 | 产品 → MonitoringDefinition 映射（按 `(productProgrammaticName, override)` 索引） |
| `resourcetemplates` | 144 | 设备型号模板（带 `commands` 流水线：Sample → JsonCommand → DomainServiceCall） |
| `resourcestatusrules` | 7 | 告警→设备状态映射规则 |
| `detectiontasks` | 61 | SNMP 探测规则（OID 正则匹配 → 写 extraProperties） |
| `protocolconfigurations` | 3 | SNMP 协议实例（community 字段加密存储） |

### 3.4 设备运行时（实际部署的 1 台设备）

| 集合 | 文档数 | 职责 |
|---|---:|---|
| ★ `baseobjects` | 2 | **真实设备 / 引擎对象本体**——本实例 = 1 个 IntelligentEngine + 1 台 PDU，靠 `_hierarchy` 区分 |
| ★ `monitoredobjects` | 1 | 该 PDU 的"监控配置 + 分发状态"快照 |
| `relationships` | 462 | **通用多对多**关系表（`sourceId, targetId, context, _type`）——主要承载权限授权（uiapipermissiongrants 等） |

### 3.5 时序数据（电力 / 传感器读数）

| 集合 | 文档数 | 职责 |
|---|---:|---|
| ★ `tsd.datapoints` | 2 375 | 真正的时序点（`name + tags.sensorId + timestamp`），值统一存为字符串 |
| `tsddata` | 0 | 空（疑似旧版字段，已废弃） |
| `electricdatas` | 3 | 小时级电耗聚合（含 `originValue / consumption / hour`） |
| `electricrateconfigs` | 0 | 电费率配置（未启用） |

> **注意**：`tsd.datapoints` 直接存到 Mongo 普通集合中，没有用 MongoDB 5.0+ 的 timeseries 集合（受限于 3.6）。当前 1 台 PDU 跑几小时已 2 375 行，规模上去后会成为最大的写入热点。

### 3.6 事件 / 审计 / 任务

| 集合 | 文档数 | 职责 |
|---|---:|---|
| ★ `events` | 141 | 业务事件（最丰富，平均 1.9 KB），含 `data / oldData / delta` 三件套（典型 JSON Patch 风格） |
| `eventlogs` | 5 | 系统级日志事件（短小） |
| ★ `jobs` | 836 | 命令执行历史（runMode/state/status/results），最活跃集合（Engine 监控每 2 分钟一条） |
| `scheduledjobs` | 6 | 调度器（Cron 表达式 `0 0/2 * * * ?` 等） |
| `actionspersisted` | 0 | 持久化动作（未启用） |

### 3.7 告警 / 通知 / 发现（**全部为空**，框架已就位但本实例未触发）

`alarms / alarmactionconfigs / alarmactionnodes / alarmactionjobs / notificationconfigs / notificationjobs / smsproviders(1) / trapconstraints / trapdestinations / discovery / discoveryconstraints / discoveredobjects / devicemgms / devicemodule / servermgms / trellisagent`

> 索引已经建好（如 `alarms` 上 `alarmTypeProgrammaticName / timestamp / resourceId`），说明这是产品骨架的一部分，只是当前数据集没产生过告警。

### 3.8 安全 / 多租户 / 许可

| 集合 | 文档数 | 职责 |
|---|---:|---|
| `tenants` | 1 | 单租户，`tenantName=TopTenant`，`parentId=top`（树形预留） |
| `users` | 1 | `admin`，BCrypt 密码，`providerType=Internal`，与 `tenants._id` 字符串关联 |
| `roles` | 3 | 仅 `Advanced User Role` 等三类应用预定义角色 |
| `permissions` | **248** | 极细粒度权限（`feature.taf-monitor.pdu.view` 等） |
| `apikey` | 0 | API Key（未启用） |
| `trustcertificates` | 1 | X.509 证书 + 原始字节直接存表 |
| `licensedstructures` | 6 | 受许可的资源/操作（`TAF_USER 创建`、`Device 创建`） |
| `internallicensedfeatures` | 2 | 内置特性配额（`CREATE_DEVICE = 100` 等） |
| `licensedfeatures / licensedproducts` | 0 / 0 | 外部许可（未启用） |

### 3.9 系统 / 文件 / 杂项

| 集合 | 文档数 | 职责 |
|---|---:|---|
| `systemsettings` | 1 | 全局配置（`systemVersion=1.31.6-pi, dbState=OK, licensingConfiguration.operationalState=FALLBACK`） |
| `defaultconfig` | 0 | 默认配置（未启用） |
| `registry` | 6 | 平台 KV（如 SNMPv3 算法白名单），自带 `encrypted` 标记 |
| `filemanager` | 274 | 文件元数据，`location.address` 指向 GridFS 的 `fs.files._id` |
| `fs.files` / `fs.chunks` | 302 / 1 129 | **GridFS 文件存储**（设备图片为主，单 chunk 261 KB） |
| `locks` | 1 | Quartz/Hazelcast 集群锁 |
| `exporttransformations` / `exportdatamappings` | 1 / 1 | 导出 CSV 时的列映射 / 字段转换 |

---

## 4. 关键索引模式

| 模式 | 出现场景 | 含义 |
|---|---|---|
| `_id_` | 全部 | 默认主键 |
| `_hierarchy_1` | 几乎所有业务集合 | 多态查询（按 `_type/_hierarchy` 反查同种实体） |
| `programmaticName_1` | `permissions / functions / commands / dictionaryterms / assetclassifications` | "字符串主键"，跨表引用都用它 |
| `(name, version)` | `resourcetemplates / metadatadefinitions` | 模板 / Schema 的版本化 |
| `(targetId, sourceId, context)` | `relationships` | 反向查关联（"谁拥有这个权限"） |
| `(name, tags.sensorId, timestamp)` + `timestamp_1` | `tsd.datapoints` | 时序范围扫描 |
| `(filename, uploadDate)` / `(files_id, n)` | `fs.files / fs.chunks` | GridFS 标准布局 |
| `(alarmTypeProgrammaticName, timestamp, resourceId)` | `alarms` | 告警视图（虽然现在表为空） |

> 没有看到任何 **TTL 索引** —— `jobs / events / tsd.datapoints` 都不会自动过期，需要靠 `retention` 命令清理（`taf-plugin-exports` 中已定义这种命令）。

---

## 5. 与 `01-architecture-overview` 的物理对应

| 架构文档中的描述 | DB 中的物理实体 |
|---|---|
| "Schema 引擎 + JSON Schema v4" | `metadatadefinitions(541) + coreschemas(2)` |
| "GenericModel Controller 动态集合" | 任意 `_type` 表，全凭 metadatadefinitions 决定字段 |
| "插件 JSON 装配" | `applications(1) + plugins(42) + pluginclassifications(6)` |
| "ITopic / IQueue（Hazelcast）" | `topics + topiclisteners + queues + queuelisteners + wstopiclisteners` |
| "Quartz 主从 + JobMgr" | `scheduledjobs(6) + jobs(836) + locks(1)` |
| "GenericDomainService" | 表内字段 `_type / _hierarchy / _createdBy / _modifiedBy` 是其副产品 |
| "CGA Roles/Perms（细到操作级）" | `roles(3) + permissions(248) + relationships(462)` |
| "NotificationManager / SMS / EventLog" | `notificationconfigs / smsproviders / eventlogs / events` |
| "数据字典（taf-gdd-data 插件）" | `dictionaryterms(22 853, providedByPlugin=taf-gdd-data 等)` |

---

## 6. 重构需要警惕的"坑"

1. **MongoDB 3.6.18 已 EOL（2021-04）**
   - 没有 timeseries 集合、没有 schema validation 的高级特性、没有 `$set` 数组聚合算子的部分语义。
   - 升级到 5.0/6.0 时要重测：JsonNode → BsonDocument 的字符串 `numberLong / decimal128` 表现差异、`$lookup` 行为差异。

2. **TTL 缺失，长期会膨胀**
   - `jobs` 1 天就 836 条（每 2 分钟一条 EngineMonitor），没有 TTL；
   - `events` 1 天 141 条；
   - `tsd.datapoints` 1 台 PDU 几小时 2 375 条；
   - 重构时建议给这三张表都加 TTL 或冷热分层（线上数据保留期需要先和产品确认）。

3. **多态由 `_hierarchy` 控制 + 没有 schema 验证 = 数据契约靠应用层**
   - Mongo 端没有任何 `$jsonSchema` 验证规则；
   - 全靠 Java 端 `metadatadefinitions` 在 RW 时校验；
   - 如果绕过 Java 端写库（比如 mongoimport / 数据迁移脚本），完全可以写出"破坏类型链"的脏数据；
   - 重构后建议至少把 `_type / _hierarchy` 在 Mongo 端用 `$jsonSchema` 锁住。

4. **`relationships` 是隐式的图表**
   - 462 条记录承载了用户-角色-权限-资源全部关联；
   - 重构成 RDB 时不要直接拉平为单一关联表，要按 `context` 拆出独立的关联表（`uiapipermissiongrants` 等），否则查询全靠 `(targetId, sourceId, context)` 复合索引硬扛。

5. **加密字段散落**
   - `protocolconfigurations.snmp.readCommunity` / `writeCommunity` 是密文（疑似 AES + 应用密钥）；
   - `users.password` 是 BCrypt；
   - `registry.encrypted` 是 bool 但内容是字符串；
   - 没有统一的"密文字段"标记 —— 重构时务必先列清单，密钥/算法不能丢。

6. **GridFS 占了 98% 存储但只有 302 个文件**
   - 几乎都是 `/product/images/*.png`；
   - 若改用对象存储（S3/MinIO）可以让 Mongo 缩到 ~5 MB；
   - 但 `filemanager.location.type='db'` 是硬编码的，迁移时要同步改 `location.address` 与 `type`。

7. **大量"空骨架"集合**
   - 告警全链路、自动发现、Trap、设备管理都是空表 + 已建索引的状态；
   - 重构前需要确认这些功能是 *真的没用* 还是 *本测试库没触发*；
   - 建议在产品/QA 那里拿到一份"功能矩阵 vs 集合"的对照表，避免误删。

---

## 7. 复现命令

```bash
python tools/mongo_analyze.py > docs/legacy-analysis/mongo_report.json
python tools/mongo_summary.py                                # 全集合汇总表
python tools/mongo_samples.py > docs/legacy-analysis/mongo_samples.txt  # 字段+样本
```

连接串：`mongodb://mtpuser:Passw0rd@localhost:27019/mtp?authSource=mtp`
