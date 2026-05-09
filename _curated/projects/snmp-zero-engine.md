# SNMP 协议族 + MIB 解析 + Zero Engine 信号告警流

标签:`[就绪]` `[简历亮点]`⭐ `[面试高频]`🎯 `[跨主题]`🔗 `[源文]`

> 这份文档把你**4 块素材**串联起来:
> - SNMP 协议本身 (`SNMP.outline.md`, 97 行)
> - SNMP4J 客户端使用 (基本空白,对应 [`tech-stack/snmp4j-quickref.md`](../tech-stack/snmp4j-quickref.md))
> - MIB 解析方案设计 (`resolve-mib.md`, 754 行 + `snmp-smi-pro.outline.md`)
> - Zero Engine 信号采集 + 告警流(`zero-engine.md`, 6514 行 + `flow.outline.md`)
>
> 这条线是你 SI 4.0 + SI 4.1 的**核心技术骨架**,简历讲一定挑这条。

---

## 0. 全景图

```
┌─────────────────────────────────────────────────────────────────┐
│                         SNMP 设备 (UPS/PDU)                      │
└────────────────────┬─────────────────────────────────────────────┘
                     │ SNMP v1/v2c/v3
                     │ Get / GetNext / GetBulk / Set / Trap / Inform
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  Zero Engine (Java + SpringBoot + Undertow + ActiveMQ)          │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  设备接入层 (snmp4j)                                      │   │
│  │  ├── 设备发现 (网段扫描 + sysObjectID 探测)               │   │
│  │  ├── MIB 解析 (SNMP4J-SMI-PRO)                            │   │
│  │  └── 驱动管理 (taf-data-* 设备型号包)                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  采集层 (samplerContext + samplingScheduler)              │   │
│  │  ├── 实时信号采集 (SNMP get,1000 线程池,1 分钟周期)       │   │
│  │  ├── 数据点缓存 (Caffeine,本地)                           │   │
│  │  └── 数据点变化通知 (datapointService extends Observable) │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  告警层 (snmpReceiver)                                    │   │
│  │  ├── trap 监听 (snmp#1.listen)                            │   │
│  │  ├── trap 解析 (策略模式: SnmpTrapV2/Geist/Lgp/Unity)     │   │
│  │  ├── 告警缓存                                              │   │
│  │  └── JMS 推送 (active-alarm topic)                         │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────────────────┘
                     │ JMS (ActiveMQ)
                     │ topic: active-alarm
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  SI 多消费者 (messageSubscriber @JmsListener)                   │
│  ├── consumers-1 → SI#1 / SI#2 / SI#X                            │
│  └── 异步,不阻塞主线程                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. SNMP 协议核心 (面试基础题) 🎯

> 直接看 `_build/outlines/3-tech_stack/protocol/SNMP.outline.md` (97 行,内容详尽)。
>
> 我只**勾画结构**,加几个面试加分的点:

### 1.1 三个版本的本质差异

| 版本 | 认证 | 加密 | 新操作 | 实战使用 |
|---|---|---|---|---|
| v1 | community 字符串 | 无 | GET / GETNEXT / SET / TRAP | 几乎不用了 |
| v2c | community 字符串 | 无 | + GET BULK / INFORM | 兼容性广,主流 |
| v3 | USM(基于用户的安全模型) | DES/AES + MD5/SHA | + Report | 推荐,但配置复杂 |

**关键加分点**:
- v2c 的 **INFORM**:类似 trap 但**需要 ACK 确认**,不然会重发(对告警可靠性重要)
- v3 的 **VACM**(基于视图的访问控制模型):决定哪些 OID 可被访问

### 1.2 PDU 操作(面试常问)

| 操作 | 用途 | 谁发起 |
|---|---|---|
| GET | 取一个 / 多个 OID 的值 | NMS → Agent |
| GETNEXT | 取下一个 OID(用于遍历 MIB 树) | NMS → Agent |
| GETBULK | 一次取大块数据 | NMS → Agent (v2c+) |
| SET | 修改 OID 的值 | NMS → Agent |
| RESPONSE | 上面 4 个的响应 | Agent → NMS |
| TRAP | 设备主动发通知 | Agent → NMS |
| INFORM | 类似 trap,但需 ACK | Agent → NMS (v2c+) |

### 1.3 MIB 与 OID

- **MIB(Management Information Base)**: 被管理对象的集合
- **OID(Object Identifier)**: MIB 中每个对象的唯一标识,数字+点格式,如 `1.3.6.1.2.1.1.1`
- **层次结构**: 树状,顶层是 ISO/IETF 公共对象,下层是具体设备

---

## 2. MIB 解析 (SI 4.1 实战) ⭐

> 详细见 `file/2-projects/vertiv/SI/experiences/v4.1/resolve-mib/design/resolve-mib.md` (754 行) +
> `_build/outlines/.../snmp-smi-pro.outline.md`

### 2.1 业务背景

- **场景**: 管理员上传新设备的 MIB 文件 → 系统解析出所有 OID + 数据类型 + 描述 → 生成可被采集层使用的元数据
- **痛点**: 旧方案缺失,每个新设备型号都要驱动开发人员**手动维护 OID 列表**,效率低 + 易错

### 2.2 技术选型

> 这是面试的**关键加分点**:候选人能讲清楚选型 trade-off 的人不多。

| 方案 | 优点 | 缺点 | 选不选 |
|---|---|---|---|
| **Mibble** (开源) | 免费 | 活跃度低,功能不全(对一些自定义关键字解析不全) | ❌ |
| **SNMP4J-SMI-PRO** (商业) | 功能完整,与已用的 SNMP4J 同生态 | 商业 license,需采购 | ✅ |
| **自研** | 完全可控 | 工作量极大,ASN.1 + 模块依赖排序 + 语法检查都要从头做 | ❌ |

> **简历讲法**: "我做了 Mibble / SNMP4J-SMI-PRO / 自研三方案对比,从功能完备性、license 兼容性、维护活跃度、与已有生态契合度等维度产出对比报告,推动公司采购 SNMP4J-SMI-PRO,并完成了国外采购流程的跨时区配合"。

### 2.3 解析流程

```
1. 解析 MIB 文件为 ModuleInfo
2. 检查模块依赖关系并排序 (一个 MIB 可能 import 另一个,要按依赖顺序处理)
3. 语法检查和语义验证
4. 持久化到仓库目录或直接加载到内存

OID 解析子流程:
3.1 识别模块前缀和对象名称
3.2 查找对应 MIB 对象定义
3.3 如果是表索引,进行索引值解码
3.4 组合生成完整数字 OID

核心类: SmiManager
- 多线程并行编译 MIB 模块
- 线程安全的模块加载和访问
```

### 2.4 输出物

- 设计文档 754 行 (`resolve-mib.md`),含 SmiManager 核心类的扩展点
- 工程化产物:解析后的 MIB 对象集合 (mibObjectTypes / mibObjects / mibSyntaxs / points / alarms)

---

## 3. Zero Engine 信号采集 + 告警流 (SI 4.0 主战场) ⭐⭐ 🎯

> 详细见 `file/2-projects/vertiv/SI/experiences/v4.0/zero-engine.md` (**6514 行!**) +
> `_build/outlines/2-projects/vertiv/SI/common/flow/flow.outline.md` (4 页 256 行)
>
> **6500 行的素材是金矿**,但你 SI4.0.md 只写了 4 个 bullet。**[需补充]**:把这条线完整提炼一下。

### 3.1 Zero Engine 是什么

- **定位**: SI 4.0 的**采集层**服务,独立部署
- **背景**: 公司既有的采集层 IE Engine 是 C++,其他团队负责,SI 不可控;故新建 Java 版的 Zero Engine
- **职责**: 采集 SNMP 设备的信号 + 处理告警,支持分布式部署
- **未来**: 扩展更多协议 (Modbus 等)

### 3.2 信号采集(实时)

```
samplingScheduler: ScheduledExecutorService (默认 1000 线程)
  → 每个设备一个采集任务
  → 1 分钟周期(可配置)

线程池接收任务,采集信号
  → SNMP get (针对每个设备的 OID 列表)
  → 数据点变化检测
  → 缓存到 Caffeine (本地)
  → 通知观察者 (datapointService extends Observable)
    → 6. tafService (implements Observer)
    → XXX (implements Observer)
    → 7. 推送数据到指定应用 (RestTemplate)
```

> **使用了观察者模式** —— 数据点变化通知多个下游,松耦合。

### 3.3 告警流(异步)

```
真实设备 → snmp#1.listen()
  → consumer.accept(trap)
  → snmpReceiver.processpdu()
    → resolveTrap() 解析告警
      ├── snmp-v1-trap     (策略模式,每种 trap 类型一个解析器)
      ├── snmp-v2-trap
      ├── GeistPduTrap
      ├── LgpEventTrap
      ├── SnmpTrapV2
      └── UnityTrap
    → 缓存
    → 检查 (5)
    → [alarm]
    → JMS 推送 (topic: active-alarm)

JMS 订阅端 (SI 多消费者):
  messageSubscriber (@JmsListener(destination = "active-alarm"))
    → consumers-1 → SI#1 / SI#2 / SI#X
    → 从 caffeine 缓存中获取所有上层系统(默认 10 个 / 300s 过期)
    → 推送告警
```

> **关键设计**:
> - **策略模式**封装多厂商 trap 解析(避免 if-else 硬编码)
> - **JMS topic 订阅 / 发布** 支持多消费者、异步、不阻塞主线程
> - **观察者模式 + JMS 双层** —— 本地变化用观察者,跨服务通知用 JMS

### 3.4 设备发现

> 详见 `file/2-projects/vertiv/SI/experiences/v4.0/discovery.md` (2401 行)

```
两阶段发现:
1. 广播探测 (快速判活)
   → SNMP GET sysObjectID
   → 用 Apache Commons Net 扫描 IP 段 (单 IP / CIDR / 范围)

2. 深度采集 (确定型号)
   → 异步并行采集 sysDescr / sysName / sysLocation
   → 通过 sysObjectID 自动匹配设备型号驱动 (taf-data-*)
   → 入库
```

**性能控制**:
- 线程池 + 信号量限流(避免对客户网络造成扫描压力)
- 异步任务,jobId 跟踪进度

### 3.5 关键代码亮点(简历可讲)

> 来自你 `zero-engine.md` 开头部分 (`discoverDevices` 接口的 AI review):

- **职责分离**: Controller 只做参数转换 + 调用 service
- **DTO 转换**: BeanUtils.copyProperties(后续可改 MapStruct 提性能)
- **API 文档**: OpenAPI 3.0 注解(@Operation / @Parameter)
- **异步任务**: 返回 jobId 而非阻塞等待结果
- **统一响应**: TafResponse.successResponse / failedResponse
- **完整异常处理**: 不暴露 500 给客户端

---

## 4. 简历讲述模板

```
【模块】Zero Engine 实时信号采集 + 告警流 (SI 4.0)
【背景】SI 4.0 之前的产品仅支持 RDU 监控,不支持主流 SNMP 设备;同时公司既有的 C++ 采集层
       (IE Engine)是其他团队维护、SI 团队不可控,故新建独立的 Java 采集层服务 Zero Engine。

【贡献】
- 设计并实现了基于 SNMP4J 的设备发现机制,支持单 IP / IP 段批量扫描,内含异步线程池调度
  与去重去抖逻辑
- 实现了基于观察者模式的信号采集→缓存→变化通知数据流(SNMP 实时拉取 → Caffeine 本地缓存 →
  ApplicationEvent 通知 → ActiveMQ 跨服务推送)
- 用策略模式封装了 SNMP v1/v2c/v3 trap 的解析(SnmpTrapV2 / GeistPduTrap / LgpEventTrap /
  UnityTrap 等多个厂商私有 trap 类型),消除了硬编码 if-else 的维护负担
- 设计了告警的"采集层 → JMS Active-Alarm Topic → SI 多消费者"分布式订阅推送链路,
  消费端用 @JmsListener 异步消费 + 从 Caffeine 缓存中获取上层系统列表

【成果】
- Zero Engine 作为 SI 4.0 的核心采集层成功上线
- 自此团队对采集层完全可控,后续告警规则、采集模板的迭代不再受跨团队协作阻塞
- [TODO: 设备数 / 数据点 / QPS / 告警延迟 等量化数字]
```

---

## 5. 与你 `file/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| SNMP 协议详细 | §1 | `_build/outlines/3-tech_stack/protocol/SNMP.outline.md` |
| MIB 解析设计 | §2 | `file/2-projects/vertiv/SI/experiences/v4.1/resolve-mib/design/resolve-mib.md` |
| Zero Engine 全分析 | §3 | `file/2-projects/vertiv/SI/experiences/v4.0/zero-engine.md` (6514 行!) |
| 设备发现 | §3.4 | `file/2-projects/vertiv/SI/experiences/v4.0/discovery.md` (2401 行) |
| 告警流图 | §3.3 | `_build/outlines/2-projects/vertiv/SI/common/flow/flow.outline.md` |
| MIB OID 解析图 | §2 | `_build/outlines/.../snmp-smi-pro.outline.md` |
| SNMP4J 客户端速查 | §1.2 | [`tech-stack/snmp4j-quickref.md`](../tech-stack/snmp4j-quickref.md) |

---

## 6. [盲点]⚠️ 我看到的、你可能忽视的

1. **`zero-engine.md` 6500 行是 AI 对话记录** —— 内容质量高但**形式不利于阅读**(都是 Q&A 格式)。建议你**重新整理**成系统化文档(对应 [`meta/still-missing.md` §1.1](../meta/still-missing.md))
2. **OID 解析的索引解码细节没明示** —— `resolve-mib.md` §3.3 说 "如果是表索引,进行索引值解码",但**具体怎么做**?面试官可能会追问
3. **SNMP v3 你用过吗?** —— Outline 里讲了 v3 的 USM/VACM,但你**实际项目里用的是哪个版本**?如果只用过 v2c,简历不要写"精通 v3"

---

> **下一步**: 看 [`dependency-upgrade.md`](./dependency-upgrade.md) (SI 4.1 升级方法论)
