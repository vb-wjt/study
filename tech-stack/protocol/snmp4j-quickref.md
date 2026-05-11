# SNMP4J 速查 (基于你 SI/Zero Engine 的实战)

标签:`[就绪]` `[需补充]` `[盲点]`⚠️ `[简历亮点]`⭐

> 你的 `tech-stack/protocol/SNMP4J.md` 只有 1 行 `todo`,但 SNMP4J 是 **SI / Zero Engine
> 的核心依赖**——这种"用得最多但沉淀最薄"的对比,是简历里被面试官追问时会**突然失语**的危险点。
>
> 这份文档基于 SNMP4J 官方常见用法 + 你工程上下文整理。**用过的内容请校对/补充实际经验**。

---

## 0. 一句话定位

**SNMP4J** 是 Java 生态最主流的 SNMP 客户端 / 服务端库,Apache 2.0 协议(开源),由 SNMP4J GmbH 维护。
扩展商业模块 **SNMP4J-SMI-PRO** 提供 MIB 解析能力(你 SI 4.1 用了)。

```
依赖:
  org.snmp4j:snmp4j               (核心库,免费)
  org.snmp4j:snmp4j-agent         (做 SNMP Agent / 模拟器)
  org.snmp4j:snmp4j-smi-pro       (商业,MIB 解析)
```

---

## 1. 核心 API 三件套

### 1.1 Snmp(协议引擎)

```java
TransportMapping<UdpAddress> transport = new DefaultUdpTransportMapping();
Snmp snmp = new Snmp(transport);
transport.listen();   // 监听端口(收 trap)
```

> **作用**:整个应用的 SNMP 入口,管理收发与会话。

### 1.2 Target(目标设备)

```java
CommunityTarget target = new CommunityTarget();
target.setCommunity(new OctetString("public"));
target.setAddress(GenericAddress.parse("udp:192.168.1.1/161"));
target.setRetries(2);
target.setTimeout(1500);  // ms
target.setVersion(SnmpConstants.version2c);  // v1 / v2c
```

**v3 用 UserTarget** + USM 配置:

```java
USM usm = new USM(SecurityProtocols.getInstance(),
                  new OctetString(MPv3.createLocalEngineID()), 0);
SecurityModels.getInstance().addSecurityModel(usm);

snmp.getUSM().addUser(new OctetString("alice"),
    new UsmUser(new OctetString("alice"),
                AuthSHA.ID, new OctetString("authPassword"),
                PrivAES128.ID, new OctetString("privPassword")));

UserTarget target = new UserTarget();
target.setSecurityName(new OctetString("alice"));
target.setSecurityLevel(SecurityLevel.AUTH_PRIV);
target.setVersion(SnmpConstants.version3);
target.setAddress(GenericAddress.parse("udp:192.168.1.1/161"));
```

### 1.3 PDU(数据单元)

```java
PDU pdu = new PDU();
pdu.add(new VariableBinding(new OID("1.3.6.1.2.1.1.1.0")));  // sysDescr
pdu.setType(PDU.GET);
```

> **PDU type**: `GET` / `GETNEXT` / `GETBULK` / `SET` / `TRAP` / `INFORM` / `RESPONSE`

---

## 2. 常用操作

### 2.1 GET (拉一个 OID)

```java
ResponseEvent event = snmp.send(pdu, target);
PDU response = event.getResponse();
if (response != null && response.getErrorStatus() == PDU.noError) {
    for (VariableBinding vb : response.getVariableBindings()) {
        System.out.println(vb.getOid() + " = " + vb.getVariable());
    }
}
```

### 2.2 异步 GET (推荐用这个,不阻塞)

```java
snmp.send(pdu, target, null, new ResponseListener() {
    @Override
    public void onResponse(ResponseEvent event) {
        ((Snmp)event.getSource()).cancel(event.getRequest(), this);
        // 处理 event.getResponse()
    }
});
```

### 2.3 Walk (遍历整个 MIB 子树)

```java
TreeUtils treeUtils = new TreeUtils(snmp, new DefaultPDUFactory());
List<TreeEvent> events = treeUtils.getSubtree(target, new OID("1.3.6.1.2.1.1"));
for (TreeEvent event : events) {
    if (!event.isError()) {
        for (VariableBinding vb : event.getVariableBindings()) {
            System.out.println(vb.getOid() + " = " + vb.getVariable());
        }
    }
}
```

> **walk** 实际上是反复 GETNEXT 直到下一个 OID 不在子树内。`TreeUtils` 帮你封装好了。

### 2.4 监听 Trap (Zero Engine 用)

```java
ThreadPool threadPool = ThreadPool.create("Trap", 2);
MultiThreadedMessageDispatcher dispatcher =
    new MultiThreadedMessageDispatcher(threadPool, new MessageDispatcherImpl());
TransportMapping<UdpAddress> transport =
    new DefaultUdpTransportMapping(new UdpAddress("0.0.0.0/162"));
Snmp snmp = new Snmp(dispatcher, transport);
snmp.getMessageDispatcher().addMessageProcessingModel(new MPv1());
snmp.getMessageDispatcher().addMessageProcessingModel(new MPv2c());
snmp.addCommandResponder(event -> {
    PDU pdu = event.getPDU();
    // 解析 trap...
});
transport.listen();
```

> **162** 是 trap 标准端口(GET 是 161)。

---

## 3. 你工程里实际用到的模式 (SI / Zero Engine)

### 3.1 设备发现 (SI 4.0)

> 详见 `origin/2-projects/vertiv/SI/experiences/v4.0/discovery.md`

**典型流程**:
```
1. 扫描 IP 段:用 Apache Commons Net + java-ipv6 解析 IP/CIDR/范围
2. 对每个 IP 异步 SNMP GET sysObjectID (1.3.6.1.2.1.1.2.0)
3. 通过线程池 + 信号量限流(避免对客户网络造成扫描压力)
4. sysObjectID 匹配设备型号驱动(taf-data-*)
5. 二阶段深度采集 sysDescr / sysName / sysLocation
6. 入库
```

### 3.2 实时信号采集 (Zero Engine)

> 详见 `origin/2-projects/vertiv/SI/experiences/v4.0/zero-engine.md`

**samplingScheduler** (默认 1000 线程):
- 每个设备一个采集任务
- 1 分钟周期(可配置)
- 每个任务:对设备的 OID 列表执行 SNMP GETBULK(批量取多个 OID)
- 数据点缓存到 Caffeine
- 数据点变化通知观察者

### 3.3 Trap 监听 + 策略模式解析

> 详见 [`../../_curated/projects/snmp-zero-engine.md`](../../_curated/projects/snmp-zero-engine.md) §3.3

**多厂商 trap 解析器**:
```
TrapResolver (接口)
├── SnmpTrapV2Resolver
├── GeistPduTrapResolver
├── LgpEventTrapResolver
└── UnityTrapResolver

工厂: TrapResolverFactory
  根据 trap 的 enterprise OID / 内容特征 路由到对应 Resolver
```

### 3.4 MIB 解析 (SI 4.1, SMI-PRO)

> 详见 [`../../_curated/projects/snmp-zero-engine.md`](../../_curated/projects/snmp-zero-engine.md) §2

```java
SmiManager smiManager = new SmiManager();
smiManager.loadMib(mibFile);                    // 加载 MIB
ObjectIdentifierValue oidValue = smiManager.findOid("sysDescr");
String numericOid = oidValue.toString();        // "1.3.6.1.2.1.1.1"
```

---

## 4. 常见踩坑 (面试可讲)

### 4.1 v1 / v2c 没有加密

- community 字符串以**明文**传输
- 测试网络可以 v2c,生产建议 v3 (USM AuthPriv)

### 4.2 Timeout 设置

- 太短:网络抖动就 timeout 了
- 太长:整个发现流程被拖慢
- **经验**:Vertiv 的设备发现 timeout 1.5s,retries 2

### 4.3 OID 字符串 vs 数字

- 字符串 OID(如 `sysDescr.0`)需要 MIB 解析才能转数字
- 数字 OID(如 `1.3.6.1.2.1.1.1.0`)是 SNMP 协议层真用的
- **没 MIB 解析的代码,只能用数字 OID**(这就是为什么 SI 4.1 引入 SMI-PRO)

### 4.4 GETBULK 的 max-repetitions

```java
pdu.setType(PDU.GETBULK);
pdu.setMaxRepetitions(20);   // 一次最多取 20 个
pdu.setNonRepeaters(0);
```

- **取多了**:UDP 包过大,可能超 MTU 被分片(性能差)
- **取少了**:多次往返
- **经验**:20-50 比较合适

### 4.5 线程模型

- 同步发送(`snmp.send`):阻塞,适合简单脚本
- 异步发送(`ResponseListener`):推荐,生产环境主用
- Trap 监听用 `MultiThreadedMessageDispatcher` 配 ThreadPool,避免单线程瓶颈

---

## 5. 关键 OID 速查 (System MIB 常用)

| OID | 名称 | 含义 |
|---|---|---|
| `1.3.6.1.2.1.1.1.0` | sysDescr | 设备描述 |
| `1.3.6.1.2.1.1.2.0` | sysObjectID | 设备型号(用于自动识别) |
| `1.3.6.1.2.1.1.3.0` | sysUpTime | 启动后运行时间 |
| `1.3.6.1.2.1.1.4.0` | sysContact | 管理员联系方式 |
| `1.3.6.1.2.1.1.5.0` | sysName | 设备名 |
| `1.3.6.1.2.1.1.6.0` | sysLocation | 设备位置 |
| `1.3.6.1.2.1.1.7.0` | sysServices | 提供的服务层(bitmap) |
| `1.3.6.1.6.3.1.1.4.1.0` | snmpTrapOID | 收到 trap 时,这是 trap 类型 |
| `1.3.6.1.6.3.1.1.4.3.0` | snmpTrapEnterprise | trap 的 enterprise OID |

> **sysObjectID 的格式**: `1.3.6.1.4.1.<vendor-id>.<product-id>...`
>
> - `4.1` 是 enterprises 子树
> - `<vendor-id>` 由 IANA 分配 (Vertiv? IBM? Cisco? 各有自己的)
> - 你**只需识别 enterprises 后面前几位** 就能知道厂商/型号

---

## 6. SNMP4J vs 同类库

| 库 | 优点 | 缺点 |
|---|---|---|
| **SNMP4J** | 主流,文档全,支持 v3,异步好 | 商业模块要付费(SMI-PRO) |
| **SNMP4J-Agent** | 用 SNMP4J 生态做 Agent / 模拟器 | (你做 RDU 模拟器可以用) |
| Mibble | 开源 MIB 解析 | 维护慢,功能不全 |
| OpenNMS Joesnmp | 老,不再维护 | 不推荐 |

---

## 7. 你应该补的实战经验

> 我手上没你的具体数字,你补上就有完整故事:

| 主题 | 你补什么 |
|---|---|
| 设备发现性能 | 1000 个 IP 段扫描多久?并发数多少? |
| 采集周期 | 默认 1 分钟,实际客户怎么调整? |
| Trap 解析准确率 | 厂商私有 trap 解析失败率? |
| SMI-PRO 引入前后 | 新设备 driver 开发耗时变化? |
| RDU 模拟器 (SI 4.0.1) | 用 snmp4j-agent 写过吗?模拟多少种故障? |
| v3 实战 | 你们生产用 v3 吗?key 怎么管理? |

---

## 8. 与你 `origin/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| SNMP 协议本身 | §0, §5 | `_build/outlines/3-tech_stack/protocol/SNMP.outline.md` |
| Zero Engine 实战 | §3.2 | `origin/2-projects/vertiv/SI/experiences/v4.0/zero-engine.md` |
| 设备发现实战 | §3.1 | `origin/2-projects/vertiv/SI/experiences/v4.0/discovery.md` |
| MIB 解析(SMI-PRO) | §3.4 | `origin/2-projects/vertiv/SI/experiences/v4.1/resolve-mib/design/resolve-mib.md` |
| 整合视角 | (本文) | [`../../_curated/projects/snmp-zero-engine.md`](../../_curated/projects/snmp-zero-engine.md) |

---

> 全部 `_curated/` 文件已写完!
> **下一步**: 回 [`../README.md`](../../_curated/README.md) 选你要看的方向,或直接去 [`../meta/inventory.md`](../../_curated/meta/inventory.md) 看全工程盘点。
