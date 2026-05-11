<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

# Zero Engine 代码分析(基于 ie-engine 源码)

> **代码仓库**: `D:\idea_workspace\ie-engine\ieengine-root`
> **技术栈**: Spring Boot 3.5.6 / Java 21 / snmp4j 3.8.2 / MyBatis Plus 3.5.5 / SQLite / ActiveMQ 5.16.3 / Caffeine / Undertow
> **分析时间**: 2026-05-11
> **关联文档**:
> - 提炼版 → [`_curated/projects/snmp-zero-engine.md`](../../../../../_curated/projects/snmp-zero-engine.md)
> - 设备发现 → [`discovery.md`](./discovery.md)
> - MIB 解析 → [`../v4.1/resolve-mib/design/resolve-mib.md`](../v4.1/resolve-mib/design/resolve-mib.md)

---

## 1. 项目结构

### 1.1 Maven 多模块

```
ieengine-root/
├── core                    共享模型/枚举/异常/插件 API
├── sampler                 采样器 SPI (AbstractSampler, Sampling 接口)
├── sampler-family/
│   ├── snmp-sampler        SNMP 采样器 (snmp4j 3.8.2, 打成 fat JAR)
│   ├── mock-sampler        Mock 采样器 (测试用)
│   └── etek8411-sdk        特殊设备 SDK
├── driver-family/
│   └── device-driver       驱动定义 (DeviceDriverContext, SamplerContext)
├── plugin-family/
│   ├── ie-plugin-monitoring   设备管理/调度/REST (DeviceContext, DynamicScheduler)
│   ├── ie-plugin-cache        Caffeine 缓存 + JMS 发布/订阅
│   ├── ie-plugin-alarm        告警解析 (AlarmResolverContext + Trap 解析器)
│   ├── ie-plugin-discovery    设备发现 (SnmpDiscoverProcessor)
│   ├── ie-plugin-entity       MyBatis 持久化层
│   ├── ie-plugin-gdd          GDD 元数据服务
│   ├── ie-plugin-tafprovider  TAF/Center 集成 (驱动推送, 数据回调)
│   ├── ie-plugin-notification 通知 (TODO, 未实现)
│   ├── ie-plugin-user         用户管理
│   └── ie-plugin-support      注册/加密/异常处理/审计
├── webapp                  Spring Boot WAR 入口 (zeengine)
└── rdu-mocker              RDU 模拟器 (独立小应用)
```

### 1.2 插件架构

```
Application (@PostConstruct)
  └── PluginContext.init()
        ├── AlarmPlugin.init()       (sequence=2) → AlarmResolverContext 加载 trap 规则
        ├── MonitoringPlugin.init()  (sequence=3) → DeviceContext.init() 加载设备/驱动
        └── ... 其他插件
  └── DeviceContext.listenEvent()   → 启动 SnmpReceiver 监听 trap
```

每个插件实现 `PluginLifecycle` 接口,由 `PluginContext` 按 sequence 顺序初始化。

### 1.3 采样器加载机制

`SamplerContext` 扫描配置的 `samplerPath` 目录下的 `.jar` 文件,通过反射加载 `com.avocent.taf.ieengine.sampler` 包下的 `Sampling` 实现。每个设备创建时通过 `cloneSampler()` 获得独立的采样器实例。

snmp-sampler 打成 `jar-with-dependencies` 独立 JAR,webapp 构建时通过 Ant 任务复制到运行时 `samplers/` 目录。

---

## 2. 信号采集流程

### 2.1 调度机制

```
DeviceContext.createCachedDevice()
  → new Device(...)  注入 datapointService, alarmService, samplerContext.cloneSampler()
  → device.startJob()
    → DynamicScheduler.scheduleWithFixedDelay(execute, 60s, 60s)
       使用 ScheduledThreadPoolExecutor (默认 1000 线程)
```

- 每个设备一个调度任务,默认 60 秒间隔(`scheduleWithFixedDelay`)
- 线程池大小由 `sampling.thread.pool` 配置,默认 1000

### 2.2 单次采集 (Device.execute)

```java
// Device.java execute() 核心流程 (简化)
if (status == STOPPED || sampler == null) return;

Map<String, Datapoint> datapointMap = new HashMap<>();

for (DatapointDefinition def : driver.getPolledDefinitions()) {
    for (String address : def.getAddresses()) {       // 每个 OID 地址
        try {
            ValueObject value = sampling.get(address); // 单个 OID 的 SNMP GET
            if (value != null) {
                datapointMap.put(def.getName(), toDatapoint(value));
                break; // 第一个成功的地址就够了,不再尝试后续
            }
        } catch (SamplingAuthenticationException e) {
            // SNMPv3 认证失败 → 触发通信告警 → 直接 return,跳过整个设备
            alarmService.handleCommunicationAlarm(deviceId, true);
            return;
        }
    }
}

datapointService.putMulti(datapointMap, deviceId);  // 写入缓存 + 通知观察者

// 通信健康检测
if (采集全部失败) {
    communicationMissingTicks++;
    if (超过阈值) detectCommunicationStatus() → handleCommunicationAlarm(deviceId, true);
} else {
    resetCommunicationStatus();  // 重置计数器
}
```

**关键点**:
- 每个 OID **单独一次 GET 请求**,不使用 GETBULK
- 一个 DatapointDefinition 可配多个 OID 地址(备选),按顺序尝试,第一个成功即停止
- SNMPv3 认证异常会直接中断整个设备的采集轮次
- 通信丢失检测通过 `communicationMissingTicks` 计数器实现

### 2.3 数据流转(观察者模式)

```
Device.execute()
  → datapointService.putMulti(data, deviceId)
    → Caffeine datapointCache 写入
    → notifyObservers(new DeviceDatapoint(deviceId, data))
      ├── TafService.update()     → HTTP POST 到注册的回调地址 + "/zedatapoints"
      └── 其他 Observer...
```

`DatapointService` 继承 `Observable`,数据点变化后通知所有注册的观察者。`TafService` 是主要观察者,负责将采集数据通过 HTTP 推送给上层 SI 系统。

### 2.4 SNMPv3 处理(SnmpSender)

#### USM 初始化

```java
// SnmpSender.initSnmpV3()
SecurityProtocols.addDefaultProtocols();
SecurityProtocols.addAuthenticationProtocol(new AuthMD5());
SecurityProtocols.addAuthenticationProtocol(new AuthSHA());
SecurityProtocols.addPrivacyProtocol(new PrivAES128());
SecurityProtocols.addPrivacyProtocol(new PrivDES());
```

#### 安全级别

| 配置值 | snmp4j SecurityLevel | 含义 |
|---|---|---|
| `noauth_nopriv` | NOAUTH_NOPRIV | 无认证无加密 |
| `auth_nopriv` | AUTH_NOPRIV | 仅认证 |
| `auth_priv` | AUTH_PRIV | 认证 + 加密 |

#### 认证/隐私协议映射 (MySecurityProtocols)

| 配置字符串 | snmp4j OID |
|---|---|
| MD5Auth | AuthMD5 |
| SHA1Auth | AuthSHA |
| DESPriv | PrivDES |
| AESPriv / AES128Priv | PrivAES128 |

#### Engine ID 发现机制

```
首次请求:
  1. 创建 UsmUser,engineId = null (未知)
  2. 发送 GET 请求
  3. 从响应中获取 authoritative engine ID
  4. 缓存 engineId
  5. 删除旧 USM 条目,重新添加绑定了 engineId 的 UsmUser

后续请求:
  - 使用缓存的 engineId 直接发送
  - 若响应为 null (可能是 v3 时间窗口过期)
    → removeEngineTime() 清除引擎时间缓存
    → 重试发送
```

#### V3 错误 OID 检查 (V3ErrorOIds)

GET 响应后调用 `V3ErrorOIds.checkForErrors()`,检查以下标准 SNMPv3 report OID:
- unsupported security level
- not in time window
- unknown user name
- unknown engine id
- wrong digest / decryption error

#### v3 GET vs v3 Trap

| 操作 | v3 支持情况 |
|---|---|
| **GET** (主动轮询) | 完整支持: ScopedPDU + USM + Engine ID 发现 |
| **Trap** (被动接收) | **不处理**: `SnmpReceiver.processPdu()` 只处理 `PDU.TRAP` (v1) 和 `PDU.V1TRAP`,v3 trap 不进入处理流程 |

---

## 3. 告警处理流程

### 3.1 告警来源

Zero Engine 中告警只有两个来源:

| 来源 | 触发方式 | 关键类 |
|---|---|---|
| **SNMP Trap** | 设备主动发送 trap → SnmpReceiver 监听 | AlarmResolverContext |
| **通信丢失** | 采集轮次全部失败 → communicationMissingTicks 累加 | Device.detectCommunicationStatus |

**注意**: 代码中 `NumericDatapointDefinition` 有 `threshold` 字段,但**没有任何消费者读取它做阈值评估**。即**不存在基于采集值的阈值告警**。

### 3.2 Trap 接收 (SnmpReceiver)

```
SnmpReceiver.run()
  → 绑定 UDP/TCP 0.0.0.0:{trap_port}
  → 注册 MPv1, MPv2c, MPv3 (协议处理器)
  → snmp.listen()

processPdu(event):
  仅处理 PDU.TRAP (v1) 和 PDU.V1TRAP
  → 构建 SnmpTrap 对象 (源 IP, varbinds, trapOID, sysUpTime)
  → consumer.accept(trap) → DeviceContext.doEvent(trap)
```

### 3.3 Trap 解析 (AlarmResolverContext)

```
DeviceContext.doEvent(trap)
  → AlarmResolverContext.resolveTrap(trap)
    │
    ├── trap 是 v2c → SnmpTrapV2Resolver (UPS 专用启发式解析)
    │
    └── trap 是 v1 → 按 enterprise OID 查找 SnmpTrapRuleEntity
        ├── 找到规则 → Spring Bean 名称查找对应 TrapResolver
        │   ├── GeistPduTrapResolver
        │   ├── LgpEventTrapResolver
        │   ├── UnityTrapResolver
        │   ├── IgnoredTrapResolver
        │   └── ... 其他厂商
        │
        └── 未找到规则 → ActiveEvent.buildCustomizedActiveEvent()
            → 自定义匹配: EventDefinition 中的 TrapRule
               varbind 操作符: equals / contains / exists / notExists
```

解析产出 `ActiveEvent`,如果 `event.isAlarm() == true`,则构建 `ActiveAlarm`。

### 3.4 告警状态管理 (AlarmService)

```java
// ConcurrentHashMap<String, ActiveAlarm> 内存缓存,key = alarm id

handleAlarm(alarm, publishing):
  if alarm.isActive():     // active = endTimestamp == null
    doHandleStartAlarm()
      → 忽略重复的 active 告警
      → 如果之前是 cleared 且新的 start 更晚,则替换
  else:
    doHandleEndAlarm()
      → 要求缓存中已有该告警
      → 从缓存的告警复制 startTimestamp

  → alarmEntityService.saveAlarm()   // 持久化到 SQLite
  → messagePublisher.publish()       // JMS 推送
```

**注意**: 无 "acknowledged" 字段,告警只有 active 和 cleared 两种状态。

### 3.5 JMS 推送链路

```
AlarmService.handleAlarm()
  → MessagePublisher.publish(alarm)
    → JmsTemplate.convertAndSend("active-alarm", alarm)

MessageSubscriber (@JmsListener(destination = "active-alarm"))
  → 通知注册的 Consumer<ActiveAlarm>
    ├── TafService → HTTP POST 到 callbackAddress + "/zealarms"
    └── NotificationContext → TODO (未实现)
```

---

## 4. 驱动管理

### 4.1 "驱动"的组成

一个驱动 **不是** 一个 MIB 文件或 ZIP 包,而是由 4 张数据库表组合而成的**设备监控模板**:

| 表 | 类 | 职责 |
|---|---|---|
| `monitoring_mapping` | MonitoringMappingEntity | 驱动身份: name, version, protocol, managementModule |
| `monitoring_definition` | MonitoringDefinition | 协议映射: datapoints, events, SNMP 地址, trap 规则 |
| `monitoring_specification` | MonitoringSpecification | 采集规格: 哪些 datapoint/event 需要采集 |
| `product_template` | ProductTemplate | 产品元数据: Product, BasicProperties, SpecificProperties |

四表组合成 `DeviceDriverDefinition`,由 `DeviceDriverContext` 在内存中缓存为 `driverNameDeviceDriverDefinitionMap`。

### 4.2 CRUD 行为

#### 创建/全量更新 — `POST /tafprovider/pushdriver`

```
DeviceDriverService.pushDeviceDriver(body):
  1. 校验并序列化 JSON (buildDeviceDriverProperties)
  2. 持久化 mapping, definition, specification, template 四表
  3. 重建运行时模型 → deviceDriverContext.saveDeviceDriver() / saveProductTemplate()
  4. 可选: 保存 detectionTasks + classificationTreeNodes (设备发现树)
     → 父节点校验,不存在则 CLASSIFICATION_TREE_NO_SUCH_PARENT_NODE
  5. discoverTreeContext.restoreCache()
```

**注意**: 压缩包解析和加密在上游 Center/TAF 端完成,ie-engine 接收的已是结构化 JSON。

#### 部分更新 — `POST /tafprovider/updatedriver`

```
updateDeviceDriver(body):
  1. 仅更新 monitoring_definition 和 monitoring_specification (DB)
  2. 原地修改缓存中的 DeviceDriverDefinition
  → 设备持有的是缓存引用,因此立即生效,无版本控制
```

#### 删除 — `DELETE /tafprovider/devicedrivers`

```
deleteDeviceDrivers(driverNames):
  1. getUsedDriverDevices() 扫描所有设备
     → 如果任何设备引用了待删驱动 → 直接返回失败 + usedDriverDevices 列表
     → "There are still some device using dirver"
  2. 每个驱动独立事务 (TransactionTemplate.executeWithoutResult)
     → DB 删除 + 缓存移除
     → 单个失败只回滚该驱动,不影响其他
  3. 失败的驱动聚合到 failedDrivers 返回
```

#### 校验 — `POST /tafprovider/checkdrivers`

比较 Center 下发的驱动列表与本地缓存:缺失的、版本变化的、多余的。

### 4.3 设备凭证加密

`DeviceContext` 中的加密/解密 (`encryptCommunicationProfile` / `decryptCommunicationProfile`) 针对的是**设备的 SNMP 通信凭证**(如 community string、v3 密码),**不是驱动包加密**。

---

## 5. 设计亮点(面试可讲)

| 设计模式/技术 | 用在哪 | 面试讲法 |
|---|---|---|
| **观察者模式** | DatapointService → TafService | 采集数据变化通知多个下游,松耦合 |
| **注册表 + Spring Bean 查找** | AlarmResolverContext → TrapResolver | 避免 if-else 硬编码多厂商 trap,新增厂商只需加 Bean |
| **双层通知** | 本地 Observable + 跨服务 JMS | 本地变化低延迟,跨服务异步解耦 |
| **插件架构** | PluginContext + PluginLifecycle | 各模块独立初始化/销毁,按顺序编排 |
| **采样器热加载** | SamplerContext 扫描 JAR | 新协议只需丢 JAR,不改主工程 |
| **SNMPv3 Engine ID 发现** | SnmpSender | 自动处理首次连接的 engineId 协商 |
| **通信健康检测** | communicationMissingTicks | 连续失败自动触发通信告警,成功自动清除 |
| **每驱动独立事务** | 批量删除 TransactionTemplate | 单个失败不影响其他,部分成功 |

---

## 6. 关键源文件索引

| 功能 | 文件 |
|---|---|
| 启动入口 | `webapp/.../Application.java` |
| 插件编排 | `webapp/.../init/PluginContext.java` |
| 设备管理 + 调度 | `ie-plugin-monitoring/.../service/DeviceContext.java` |
| 单设备采集 | `ie-plugin-monitoring/.../model/Device.java` (execute 方法) |
| 定时调度 | `ie-plugin-monitoring/.../service/DynamicScheduler.java` |
| SNMP 发送 (含 v3) | `snmp-sampler/.../service/SnmpSender.java` |
| SNMP 采样器 | `snmp-sampler/.../SnmpSampler.java` |
| Trap 接收 | `snmp-sampler/.../service/SnmpReceiver.java` |
| v3 错误检查 | `snmp-sampler/.../enums/V3ErrorOIds.java` |
| v3 协议映射 | `snmp-sampler/.../enums/MySecurityProtocols.java` |
| 告警解析 | `ie-plugin-alarm/.../service/AlarmResolverContext.java` |
| Trap 解析器 | `ie-plugin-alarm/.../protocols/snmp/SnmpTrapV2Resolver.java` 等 |
| 告警缓存 | `ie-plugin-cache/.../service/AlarmService.java` |
| 数据点缓存 | `ie-plugin-cache/.../service/DatapointService.java` |
| JMS 发布 | `ie-plugin-cache/.../service/MessagePublisher.java` |
| JMS 订阅 | `ie-plugin-cache/.../service/MessageSubscriber.java` |
| TAF 回调 | `ie-plugin-tafprovider/.../service/TafService.java` |
| 驱动 CRUD | `ie-plugin-tafprovider/.../service/DeviceDriverService.java` |
| 驱动上下文 | `driver-family/device-driver/.../DeviceDriverContext.java` |
| 驱动定义 | `driver-family/device-driver/.../DeviceDriverDefinition.java` |
| 采样器加载 | `driver-family/device-driver/.../SamplerContext.java` |
| 设备发现 | `ie-plugin-discovery/.../service/detection/SnmpDiscoverProcessor.java` |
