# JVM / GC / JUC 核心知识(P6+ 进阶补强)

> **写给**:2022 毕业、4 年 Java 后端经验的你
> **目的**:补齐 `Java Study.pdf` **严重缺失但 P6+ 必考**的 3 大块 —— **JVM 内存模型 + GC 收集器 + JUC 并发底层**
> **使用方式**:这是一份**进阶硬干货**,不抄八股 —— 默认你已经会"什么是线程 / 什么是 GC"等基础。每章末有:
>   - 🎯 **面试可讲故事**(怎么用一两句话回答)
>   - 🔗 **结合你项目** SI Zero Engine / ASP / PI 重构 (让知识点和实战绑定)
>   - ⚠️ **P7+ 加分点**(超出 P6 基线的深度)

标签:`[盲点]`⚠️ `[优先级⭐⭐]` `[面试高频]`🎯 `[源文]`(我替你补,**请你校对实战经验部分**)

---

## 0. 学这份的目标 + 4 年 Java 后端的水位

### 0.1 你目前的水位(我的判断)

| 维度 | 你的水位 | P6 基线 | P7 起步 |
|---|---|---|---|
| **Java 语言** | ✅ Java 8/21 都用 / 知道 Lambda/Stream/泛型 | ✅ | + 反射 / Annotation / SPI 实战 |
| **Spring 框架** | ✅ 注解 / Bean 都用 + 写过 AOP | ✅ | + Bean 生命周期 / 循环依赖 / SmartLifecycle |
| **JVM 内存** | ⚠️ **会调启动参数,但没生产调过 GC** | ❌ 缺 | ❌ 缺 |
| **GC 算法 / 收集器** | ⚠️ **知道有 G1,但说不出选型理由** | ❌ 缺 | ❌ 缺 |
| **并发(线程池)** | ✅ 在 SI/ASP 都用过 | ✅ | + 动态线程池 / 监控 / 拒绝策略实战故事 |
| **并发(synchronized)** | ⚠️ **只到"加锁"层,不知锁升级** | ❌ 缺 | ❌ 缺 |
| **并发(volatile/JMM)** | ⚠️ **听过但说不清** | ❌ 缺 | ❌ 缺 |
| **并发(AQS)** | ❌ **几乎是空白** | ❌ 缺 | ❌ 缺 |
| **并发(JUC 集合)** | ⚠️ ConcurrentHashMap 用过,内部不熟 | ❌ 缺 | ❌ 缺 |

> 🎯 **结论**:你的**业务广度 / 工程化能力**已经达到 P6 + 一只脚踏进 P7;但**JVM/JUC 底层**是**真盲点**,不补**会卡在大厂笔试 / 二三面的硬技术关**。

### 0.2 这份文档不是"看一遍就会"

> **你需要做的**:
> 1. **每章读完**问自己:"如果面试官问这个,我能讲 60 秒吗?"
> 2. **结合你的项目场景**:每章末"结合你项目"是最关键的部分 —— **不要跳过**
> 3. **看不懂的章节标记下来**,优先精读;看得懂的快速扫即可
> 4. **每周看 2-3 章** —— 一次看完会爆炸 / 留不下来

### 0.3 我没在这里写但很重要的(自己安排)

- **算法刷题**:LeetCode top 100 / 剑指 Offer —— 大厂笔试关
- **系统设计**:HLD/LLD / 微服务 / 海量数据 / 秒杀类 —— 二三面常问
- **DDD / 领域建模**:有时间补,看公司方向
- **分布式深度**:CAP / Raft / 一致性哈希 —— 一部分 PDF 已覆盖,可继续深挖

---

## 1. JVM 内存结构(运行时数据区)

### 1.1 五大区(JDK 8 起)

```
┌─────────────────────────────────────────────────────────┐
│                       JVM Memory                         │
├──────────────────────┬──────────────────────────────────┤
│      线程私有(随线程销毁)│      线程共享(随 JVM 销毁)        │
├──────────────────────┼──────────────────────────────────┤
│  程序计数器 (PC Reg)   │  Heap (堆)                      │
│  虚拟机栈 (VM Stack)   │     ├─ Young (Eden + S0 + S1)   │
│  本地方法栈 (Native)   │     └─ Old                      │
│                       │  Metaspace (元空间,JDK 8+)      │
│                       │  Direct Memory (直接内存,堆外)   │
└──────────────────────┴──────────────────────────────────┘
```

| 区域 | 作用 | OOM 类型 | 关键参数 |
|---|---|---|---|
| **PC 寄存器** | 当前线程下一条字节码地址 | ❌ 唯一不会 OOM 的区 | — |
| **虚拟机栈** | 方法栈帧(局部变量表/操作数栈/返回地址) | StackOverflowError / OOM | `-Xss512k` (单线程栈大小) |
| **本地方法栈** | 调用 native 方法用 | StackOverflowError | (Hotspot 与虚拟机栈合并) |
| **堆** | 所有对象 / 数组 | **OutOfMemoryError: Java heap space** | `-Xms`(初始) `-Xmx`(最大) |
| **元空间** | 类元信息(原 PermGen,JDK 8 移到本地内存) | OOM: Metaspace | `-XX:MetaspaceSize` `-XX:MaxMetaspaceSize=256M` |
| **直接内存** | NIO ByteBuffer / Netty / Hazelcast 用 | OOM: Direct buffer memory | `-XX:MaxDirectMemorySize=256M` |

### 1.2 ⭐ JDK 8 关键变化:PermGen → Metaspace

**之前(JDK 7-)**:
- PermGen 是堆的一部分,大小固定(`-XX:MaxPermSize`)
- 类一多就 `OutOfMemoryError: PermGen space`(经典问题)

**JDK 8+**:
- 元空间用**本地内存**(off-heap),理论上随系统内存扩展
- 默认无上限,**生产必须设 `-XX:MaxMetaspaceSize`**(否则类卸载不及时会吃光内存)

> 🔗 **结合你项目**:ASP knowledge.md 给的 `-XX:MaxMetaspaceSize=256M` 正好对应这里 —— 如果面试官问"为什么要设 MaxMetaspaceSize",你的答案是:**默认无上限 → 生产风险**。

### 1.3 ⭐⭐ 直接内存(Direct Memory)

**为什么有**:NIO `ByteBuffer.allocateDirect()` 跳过 JVM 堆,直接在 OS 上分配;读写速度更快,但分配代价高。

**用在哪**:
- **Netty**(IO 密集型场景)
- **Hazelcast**(IMap 大对象)
- **Kafka 客户端**

**坑点**:
- 不受 `-Xmx` 限制 → 容易**忘了 + 用满 OS 内存**
- GC 不直接管(只在 Full GC 时通过 Cleaner 回收)
- 必须显式设 `-XX:MaxDirectMemorySize=256M`,**不设 = 上限 = 等于 -Xmx**(默认)

> 🔗 **结合你项目**:
> - ASP knowledge.md 启动参数有 `-XX:MaxDirectMemorySize=256M` —— 这是**生产正确实践**
> - **PI 4.0 重构**砍掉 Hazelcast 后,**直接内存压力会大幅下降** —— 这是简历可写的**优化数字**(估算下降 N%)

### 1.4 栈帧(Stack Frame) - 简略

每次方法调用就是**入栈一帧**,帧内有:
- 局部变量表(参数 + 局部变量)
- 操作数栈(JVM 是栈式架构,运算靠操作数栈)
- 动态链接(运行时常量池)
- 返回地址

**经典问题**:
- 方法栈深 → `StackOverflowError`(最常见:无限递归)
- 单线程栈太大(`-Xss10M`)→ 总线程数受限(每个线程都吃 10M)

> 🎯 **面试可讲**:**为什么 Vertiv / ASP 都设 -Xss512k?** 答:**多线程服务**(SI Zero Engine 1000 线程,每个 512K = 500MB,如果 -Xss10M = 10GB,直接爆炸)。

### 1.5 本章面试必答 3 个问题

1. **PermGen 和 Metaspace 区别 / 为什么改?** → 类元数据移到本地内存,默认无上限
2. **直接内存什么时候用 / 怎么 OOM?** → NIO/Netty/Hazelcast,不设 MaxDirectMemorySize 会用满 OS
3. **StackOverflowError vs OutOfMemoryError 区别?** → 栈深(单线程) vs 堆/元空间/直接内存(全局)

---

## 2. 类加载机制(P6+ 必考)

### 2.1 类加载 5 阶段

```
加载(Loading) → 验证(Verification) → 准备(Preparation) → 解析(Resolution) → 初始化(Initialization)
```

| 阶段 | 做什么 |
|---|---|
| **加载** | 通过类全限定名读字节码 → 转为 `Class` 对象 |
| **验证** | 文件格式 / 元数据 / 字节码 / 符号引用 4 种验证 |
| **准备** | **静态变量**分配内存 + **零值初始化**(`int = 0`,**不是 = 用户值**) |
| **解析** | 符号引用 → 直接引用(常量池里的 #N 变成实际地址) |
| **初始化** | 执行 `<clinit>()` —— **静态变量赋值** + 静态代码块 |

> 🎯 **经典面试题**:
> ```java
> static int a = 1;  // 准备阶段 a=0,初始化阶段 a=1
> ```

### 2.2 ⭐⭐ 双亲委派模型

```
              BootstrapClassLoader (rt.jar / java.lang)
                          ↑ (parent)
              ExtensionClassLoader (ext目录)
                          ↑ (parent)
              AppClassLoader (classpath,用户类默认在这)
                          ↑ (parent,可有可无)
              CustomClassLoader (自定义)
```

**双亲委派工作流**:
1. 自定义 ClassLoader 收到加载请求
2. 先**委托给父加载器**
3. 父再委托父...直到 Bootstrap
4. **父加载不了**,才**自己尝试加载**

**好处**:
- 安全(`java.lang.String` 永远是 Bootstrap 加载的,你写不了同名类替换)
- 唯一(类的"标识"= **类名 + 加载器**)

### 2.3 ⭐⭐⭐ 打破双亲委派的场景

| 场景 | 怎么打破 |
|---|---|
| **JDBC SPI** (Driver) | `ServiceLoader` 用线程上下文 ClassLoader |
| **Tomcat** | 每个 Web 应用独立 ClassLoader,**先自己加载再委派**(避免应用间类冲突) |
| **OSGi** | 每个 Bundle 独立 ClassLoader 网状结构 |
| **Hazelcast Hot Restart** | 自己 ClassLoader 加载持久化的类 |

> 🔗 **结合你项目**:
> - **mtp-core / taf-plugin**:**典型的"打破双亲委派"应用** —— 每个 plugin 独立 ClassLoader + 独立 Spring Context,避免插件间类冲突
> - **PI 4.0 重构**:**主动放弃了这套机制**(改用编译期 Maven 模块) —— 你简历讲 PI 重构时,这是**最有 L4 深度**的反思 —— "为什么放弃?**插件 ClassLoader 隔离 + 动态 Schema 三件套**让调试地狱化"

### 2.4 ⭐ 一个会被问的细节:类加载器是不是单例?

**Bootstrap / Ext / App 都是单例**(JVM 启动时创建);**自定义可以多例**(比如 Tomcat 每个 Web 应用一个)。

**类的"身份"= 类名 + 加载器** —— 同一个 `com.foo.Bar`,在 ClassLoader A 加载和 B 加载里,**`a.getClass() == b.getClass()` 是 false**。

> 🎯 **面试 L4 加分**:Tomcat 同时跑两个 Web 应用,都包含 `com.foo.Bar`,**两套独立的 Class 对象互不干扰**。

### 2.5 本章面试必答

1. 双亲委派**为什么** + 怎么**打破**(SPI / Tomcat 的 WebappClassLoader)
2. 类的唯一标识是什么(**类名 + ClassLoader**)
3. 准备 vs 初始化的区别(零值 vs 用户赋值)

---

## 3. GC 算法 + 引用类型

### 3.1 ⭐ 可达性分析(GC Roots)

**判断对象是不是垃圾** = **从 GC Roots 出发,能否到达**?到不了 = 垃圾。

**GC Roots 包括**(必背):
1. 虚拟机栈中**正在引用的对象**(局部变量)
2. 方法区中**静态变量** 引用的对象
3. 方法区中**常量**引用的对象(`final` 常量池)
4. **本地方法栈**(JNI)中引用的对象
5. JVM 内部使用的对象(类加载器 / 异常对象等)
6. ⭐ **同步锁 synchronized 持有的对象**(JDK 1.7+)
7. 跨代引用(从老年代指向新生代的)

> 🎯 **经典面试题**:**`obj = null` 之后,对象一定被回收吗?** 不一定 —— 还要看是否还有其他 GC Roots 引用 + 是否过下次 GC 触发时机 + 是否有 finalize 复活。

### 3.2 ⭐⭐ 4 种引用类型(P6+ 必考)

```java
// 1. 强引用 (默认)
Object obj = new Object();        // GC 永远不回收

// 2. 软引用
SoftReference<Object> sr = new SoftReference<>(new Object());
                                  // 内存不足才回收 → 适合"缓存"

// 3. 弱引用
WeakReference<Object> wr = new WeakReference<>(new Object());
                                  // 下次 GC 必回收 → ThreadLocal 用

// 4. 虚引用
PhantomReference<Object> pr = new PhantomReference<>(new Object(), referenceQueue);
                                  // get() 永远返 null,只用于跟踪对象被 GC 的时刻
                                  // → DirectByteBuffer 用 Cleaner 释放堆外内存
```

> 🔗 **结合你项目**:
> - **ThreadLocalMap.Entry 的 key 是弱引用** —— 这是 ThreadLocal 内存泄漏的根本原因(Entry value 是强引用,如果 ThreadLocal 对象被 GC,Entry key 变 null 但 value 还在)
> - **ASP 网关 PortalReqContext** —— 你在 Filter 末尾必须 `remove()`,否则线程池场景下会泄漏(线程一直活着 → ThreadLocalMap 一直活着)
> - **DirectByteBuffer 内存释放** = 通过 Cleaner(基于 PhantomReference)在 Full GC 时回收

### 3.3 GC 算法 4 大类(每个 GC 收集器都是组合)

| 算法 | 优点 | 缺点 | 用在哪 |
|---|---|---|---|
| **标记清除** | 简单 | 内存碎片化 | CMS 老年代 |
| **复制** | 无碎片,效率高 | **只能用一半内存** | 新生代 (Eden + S0 / S1) |
| **标记整理** | 无碎片 | 整理成本高 | Parallel Old / G1 老年代 |
| **分代收集** | 综合 | (是个**思想**,不是单算法) | 新生代复制 + 老年代标记整理 |

### 3.4 ⭐⭐ 分代收集的"代"

```
Heap
├── Young (1/3 默认)
│    ├── Eden (8/10)        ← 新对象进这
│    ├── Survivor 0 (1/10)
│    └── Survivor 1 (1/10)
└── Old (2/3 默认)            ← 长寿对象 / 大对象 / Survivor 反复幸存
```

**对象晋升老年代的 4 种方式**:
1. **Survivor 反复幸存**(年龄 ≥ MaxTenuringThreshold,默认 15)
2. **大对象**(>= `-XX:PretenureSizeThreshold`,默认 0 = 关闭)
3. **动态年龄判断**(Survivor 中相同年龄对象总和 > Survivor 50% → 该年龄 + 上的全晋升)
4. **空间分配担保**(Minor GC 后 Survivor 放不下 → 直接到 Old)

> 🎯 **面试 L3-L4**:讲到这一层就**已经超过 70% Java 后端候选人**。

### 3.5 GC 类型(必清楚)

| 类型 | 范围 | 触发 | STW |
|---|---|---|---|
| **Minor GC / Young GC** | 新生代 | Eden 满 | **短**(几 ms) |
| **Major GC** | 老年代 | (CMS 单独老年代回收) | 较长 |
| **Full GC** | 整个堆 + 元空间 | Old 满 / Metaspace 满 / System.gc() | **长**(几百 ms - 几秒) |
| **Mixed GC** | Young + 部分 Old | G1 特有 | 中等 |

**生产铁律**:
- **Full GC 是大问题** —— 一次 Full GC = 一次接口超时
- 监控指标:**Full GC 频率 / 单次 Full GC 时长**

### 3.6 本章面试必答

1. **可达性分析 + GC Roots 7 种**
2. **4 种引用 + ThreadLocal 用哪种 + 为什么**
3. **对象怎么晋升老年代 4 种**
4. **Minor / Major / Full / Mixed GC 区别**

---

## 4. GC 收集器(P6+ 重灾区)

### 4.1 ⭐ 经典 7 种 + 现代 2 种

| 收集器 | 区域 | 算法 | 特点 | JDK 默认 | 状态 |
|---|---|---|---|---|---|
| **Serial** | 新生代 | 复制 | 单线程,STW | — | 客户端模式 / 极小堆 |
| **ParNew** | 新生代 | 复制 | 多线程 Serial | — | 配合 CMS |
| **Parallel Scavenge** | 新生代 | 复制 | 多线程,**关注吞吐量** | JDK 7-8 默认 | ✅ |
| **Serial Old** | 老年代 | 标记整理 | 单线程 | — | CMS 失败兜底 |
| **Parallel Old** | 老年代 | 标记整理 | 多线程 | JDK 7-8 默认 | ✅ |
| **CMS** | 老年代 | 标记清除 | 关注**低停顿**,并发 | — | **JDK 9 已弃用,JDK 14 移除** ❌ |
| **G1** | 整堆 | Region + 标记整理 + 复制 | 平衡 STW + 吞吐 | **JDK 9+ 默认** | ✅ 主流 |
| **ZGC** | 整堆 | 染色指针 + Region | **STW < 10ms,大堆王者** | — | JDK 11 实验 / **JDK 15+ 生产可用** |
| **Shenandoah** | 整堆 | Brooks Pointer | **STW < 10ms** | — | OpenJDK 12+ |

### 4.2 ⭐⭐ G1(必背 — 你大概率在用)

**核心思想**:
- 把堆分成 **2048 个左右** Region(每个 1-32MB)
- Region 不固定属于 Young/Old,**动态分配**
- 每次 GC **挑收益最高的 Region 回收**(Garbage First → G1)
- **可预测停顿**:`-XX:MaxGCPauseMillis=200` 默认,GC 算法尽量满足

**G1 的 GC 阶段**:
1. **Young GC**:Eden 满 → 复制存活到 Survivor / Old → STW
2. **Concurrent Marking**:并发标记老年代存活对象(类似 CMS)
3. **Mixed GC**:回收 Young + 部分 Old → STW(短)
4. **Full GC**:**G1 失败兜底**(单线程 Serial Old) → STW(很长,**生产应避免**)

**关键参数**:
```bash
-XX:+UseG1GC                    # 启用 G1(JDK 9+ 默认)
-XX:MaxGCPauseMillis=200        # 期望最大停顿
-XX:G1HeapRegionSize=16M        # Region 大小(默认基于堆)
-XX:InitiatingHeapOccupancyPercent=45  # 老年代占比触发并发标记
```

### 4.3 ⭐⭐⭐ ZGC(JDK 11+,P7 必备)

**核心创新**:**染色指针**(把 GC 标记位放在指针的高位,不存对象头)

**优势**:
- STW < 10ms(**几乎不依赖堆大小**)
- 支持 **TB 级**堆
- 并发回收 + 并发标记 + 并发整理

**适用**:
- 大堆(> 16GB)
- 低延迟(金融 / 实时计算)
- JDK 17+(LTS)开始**强烈推荐**生产用

**关键参数**:
```bash
-XX:+UseZGC                     # 启用 ZGC
-Xmx16g                         # ZGC 在大堆上才有优势
```

> 🔗 **结合你项目**:
> - **PI 4.0 重构 → Java 21 LTS** → **可以直接用 ZGC** → **简历 / 面试可写**:"重构后 GC 收集器从 G1 升级到 ZGC,STW 从 200ms 级降到 < 10ms"
> - **SI 4.1 升级到 Java 21** 也一样

### 4.4 ⭐ 怎么选?(决策树)

```
小堆(< 4G)+ 老服务      → Parallel + Parallel Old
中堆(4-16G)+ 业务服务    → G1(默认即可)
大堆(> 16G)+ 低延迟      → ZGC / Shenandoah
极小堆 + 启动快          → Serial(嵌入式 / Serverless)
```

> 🎯 **面试可讲**:**为什么 SI/PI 选 G1 / ZGC?** 答:**G1 是 JDK 9+ 默认,平衡;ZGC 在我们升级到 Java 21 后启用,大堆下 STW 显著下降**。

### 4.5 本章面试必答

1. **G1 怎么工作 / 为什么默认**
2. **ZGC vs G1 区别 / 何时选 ZGC**
3. **CMS 为什么被弃用**(标记清除导致碎片化 / 并发模式失败 → Full GC 兜底很慢)

---

## 5. ⭐⭐⭐ GC 调优实战(P6+ 加分)

> **这是从"知道 GC"到"调过 GC"的分水岭**。生产排查过 = 简历写得出 case = 面试官加分。

### 5.1 GC 日志(必看)

**JDK 8 启用**:
```bash
-XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/path/gc.log
```

**JDK 9+ 统一**:
```bash
-Xlog:gc*=info:file=/path/gc.log:time,uptime,level,tags:filecount=10,filesize=10M
```

**示例日志(G1)**:
```
[2026-04-30T10:23:45.123+0800][12.345s][info][gc] GC(0) Pause Young (Normal) (G1 Evacuation Pause) 100M->50M(512M) 12.345ms
                                                       ↑ Young GC 类型      ↑ Heap 前→后(总)  ↑ 耗时
```

**看什么**:
- ✅ **Young GC 频率 + 时长**:几秒一次 + < 50ms = 正常
- ⚠️ **Full GC 频率**:`grep "Full GC" gc.log` —— **每天 > 几次 = 异常**
- ⚠️ **GC 后 Old 不下降**:**内存泄漏先兆**

### 5.2 ⭐⭐ 常用参数(必背 + 知道含义)

```bash
# ===== 堆 =====
-Xms2g -Xmx2g                   # 初始 = 最大,避免动态扩展抖动
-Xmn1g                          # 新生代大小(也可用 -XX:NewRatio=2,Old:Young = 2:1)
-XX:SurvivorRatio=8             # Eden:S0:S1 = 8:1:1

# ===== 元空间 =====
-XX:MetaspaceSize=128M          # 触发 Metaspace GC 的初始阈值
-XX:MaxMetaspaceSize=256M       # 上限(必设,默认无限!)

# ===== 直接内存 =====
-XX:MaxDirectMemorySize=256M    # NIO 用(默认 = -Xmx)

# ===== GC 选择 =====
-XX:+UseG1GC                    # G1 (JDK 9+ 默认)
-XX:MaxGCPauseMillis=200        # G1 期望停顿
-XX:+UseZGC                     # ZGC (JDK 11+)

# ===== OOM 自救 =====
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/dump.hprof
-XX:OnOutOfMemoryError="kill -9 %p"      # OOM 直接挂(配合 K8s 重启)

# ===== 容器友好(K8s 必备) =====
-XX:MaxRAMPercentage=70.0       # 用容器内存的 70%(代替 -Xmx)
-XX:InitialRAMPercentage=70.0
```

> 🔗 **结合你项目**:**ASP knowledge.md** 给的启动参数完整覆盖了这些 —— 你在中移**已经实战用过**,只是可能没主动归纳。

### 5.3 ⭐⭐⭐ OOM 排查(实战故事级)

**4 类 OOM**:

| OOM 类型 | 报错 | 怎么查 |
|---|---|---|
| **Heap** | `OutOfMemoryError: Java heap space` | `jmap -dump:live,format=b,file=dump.hprof <pid>` → MAT 分析 |
| **Metaspace** | `OutOfMemoryError: Metaspace` | `-XX:MaxMetaspaceSize`,看类是否反复加载(动态代理 / Groovy) |
| **Direct Memory** | `OutOfMemoryError: Direct buffer memory` | `jcmd <pid> VM.native_memory` |
| **Stack** | `StackOverflowError` | 看递归 / `-Xss` |

**MAT 分析 dump 关键 3 步**:
1. **Histogram**:看哪些类占内存最多
2. **Dominator Tree**:看**单个**对象支配了多少内存
3. **Path to GC Roots**:**为什么这个对象还活着** → 找泄漏源

**线上排查工具**:
```bash
# 看 GC 实时
jstat -gcutil <pid> 1000           # 每秒打印 GC 状态

# 看堆 / 类
jmap -heap <pid>                   # 堆配置
jmap -histo <pid> | head -50       # 看类对象数

# 看线程
jstack <pid>                       # dump 线程栈,排查死锁 / 阻塞

# 看系统信息(JDK 11+)
jcmd <pid> VM.flags                # 看启动参数
jcmd <pid> GC.heap_info            # 看堆细节
jcmd <pid> Thread.print            # 线程栈
```

### 5.4 ⭐ 实战 case 写法(简历可用)

**模板**:
```
背景:[服务名] 上线后 [某时段] 频繁 Full GC / OOM / 卡顿
症状:接口超时率从 0.1% 升到 5% / Full GC 5 分钟一次
排查:
  1. jstat -gcutil 看到 Old 区使用率 95%,GC 后只回收 5%
  2. jmap dump 后用 MAT 分析,看到 [某类] 对象占 70% 堆
  3. Path to GC Roots 发现是 [缓存 / ThreadLocal / 静态集合] 持有
解决:
  - 加缓存上限 / 用 ThreadLocal.remove() / 限制集合大小
  - 调整 -XX:MaxGCPauseMillis 或换 ZGC
结果:Full GC 从 5 分钟 → 数小时一次,接口超时率回到 0.1%
```

> 🔗 **你需要的故事**:**ASP / SI / PI 里有没有踩过 GC / OOM 的坑?** 如果有,补一段进去 —— 这是简历**最有质感的素材**。

### 5.5 本章面试必答

1. **怎么排查 OOM?** → 4 类 OOM + jmap dump + MAT 三步
2. **GC 日志关键指标** → Young 频率/时长 + Full 频率 + Old 不下降
3. **MaxRAMPercentage vs Xmx** → 容器场景必用 Percentage

---

## 6. JMM(Java Memory Model)

### 6.1 主内存 + 工作内存

```
Thread A    Thread B    Thread C
  ↓           ↓           ↓
[work mem]  [work mem]  [work mem]   ← CPU 缓存(不是真物理内存,是 JVM 抽象)
   ↑           ↑           ↑
       共享变量(主内存 = 堆)
```

每个线程**有自己的工作内存**(本质是 CPU 缓存) → **变量必须先从主内存 load 到工作内存** → 修改后再 store 回去 → 这就是**可见性问题**根源。

### 6.2 三大特性(必懂)

| 特性 | 含义 | 解决方式 |
|---|---|---|
| **原子性** | 操作要么全成功要么全失败 | `synchronized` / Lock / Atomic |
| **可见性** | 一个线程的修改对其他线程可见 | `volatile` / synchronized / final |
| **有序性** | 程序按代码顺序执行 | `volatile`(禁止指令重排) / synchronized |

### 6.3 ⭐⭐ Happens-Before 8 条规则

> **意思是**:如果 A 操作 happens-before B 操作,**B 一定能看到 A 的结果**。

| # | 规则 | 含义 |
|---|---|---|
| 1 | 程序顺序 | 同一线程内,前面的代码 happens-before 后面 |
| 2 | 监视器锁 | 解锁 happens-before 下一次加锁 |
| 3 | volatile | 写 volatile happens-before 后续读 |
| 4 | 线程启动 | `start()` happens-before 线程内任意操作 |
| 5 | 线程终止 | 线程内最后操作 happens-before `join()` 返回 |
| 6 | 中断 | `interrupt()` happens-before 检测到中断 |
| 7 | 对象初始化 | 构造函数 happens-before `finalize()` |
| 8 | 传递性 | A→B + B→C → A→C |

### 6.4 ⭐⭐⭐ volatile 详解(必考)

**volatile 解决**:**可见性 + 有序性**(**不解决原子性**!)

**实现机制**:
- **写**:写完后立即刷到主内存 + **使其他 CPU 的缓存行失效**(MESI 缓存一致性协议)
- **读**:从主内存读 / 重新读
- **禁止指令重排**:在 volatile 写前后插入**内存屏障**

**典型场景**:
```java
public class DCL {  // 双重检查锁单例
    private static volatile DCL instance;  // ⚠️ volatile 不能省!
    public static DCL getInstance() {
        if (instance == null) {
            synchronized (DCL.class) {
                if (instance == null) {
                    instance = new DCL();   // 这步有 3 个动作:
                    // 1. 分配内存  2. 初始化对象  3. 引用赋值
                    // 没 volatile,可能被 JIT 重排为 1-3-2,导致其他线程看到"半成品"对象
                }
            }
        }
        return instance;
    }
}
```

> 🎯 **L4 加分**:**为什么 volatile 不能解决原子性?** → 例子:`volatile int i = 0; i++;` 是 3 步(读/算/写),**volatile 只保证每步从主内存读**,**不保证 3 步连起来不被打断**。

### 6.5 final 的内存语义

**final 字段在构造函数内的赋值**有特殊保证:**构造函数返回前,final 字段对所有线程可见**(即使没用 synchronized / volatile)。

**坑**:**this 引用不能在构造函数中逃逸**(否则其他线程可能看到 final 字段的零值)。

```java
public class Foo {
    final int x;
    public Foo() {
        this.x = 5;
        ListenerRegistry.register(this);  // ❌ this 逃逸!其他线程可能看到 x=0
    }
}
```

### 6.6 本章面试必答

1. **volatile 解决什么 + 不解决什么** → 可见性 + 有序性,不解决原子性
2. **DCL 为什么 volatile 不能省** → 防止指令重排
3. **Happens-Before 几条记 5 条以上** → 程序顺序 / volatile / 监视器锁 / start / join

---

## 7. ⭐⭐ synchronized 锁升级(P6+ 必考)

### 7.1 对象头 Mark Word

64 位 JVM 中,对象头有 8 字节 Mark Word(存储锁信息):

| 状态 | Mark Word 内容(部分) | 锁标志位 |
|---|---|---|
| **无锁** | hashcode / age / 0 | 01 |
| **偏向锁** | 线程 ID / age / 1 | 01 |
| **轻量级锁** | 指向栈中 Lock Record 的指针 | 00 |
| **重量级锁** | 指向 Monitor(ObjectMonitor 内核对象)的指针 | 10 |
| **GC 标记** | — | 11 |

### 7.2 锁升级路径(单向,不可逆)

```
无锁
 ↓ (第一次有线程加锁)
偏向锁(同一线程多次加锁,几乎零成本)
 ↓ (有第二个线程参与)
轻量级锁(CAS 自旋,适合竞争少 / 持有时间短)
 ↓ (自旋失败 / 自旋次数过多)
重量级锁(操作系统 Mutex,挂起线程,STW 切换上下文)
```

### 7.3 4 种锁的细节

#### 偏向锁(JDK 6 引入,JDK 15 弃用,JDK 18 默认关)
- **思想**:大部分锁只被一个线程访问,直接记录线程 ID,不做 CAS
- **撤销代价**:在 STW 安全点撤销,JDK 15 后认为不值得 → 弃用

#### 轻量级锁
- 在线程栈上分配 Lock Record,**用 CAS** 把对象 Mark Word 替换成指向 Lock Record
- 失败 → **自旋等待**(默认 10 次,超过升级)

#### 重量级锁
- 通过 ObjectMonitor(C++ 实现) → **进入 EntryList**(等待线程队列)
- **线程挂起** → 内核态切换 → **昂贵**(微秒级)

### 7.4 锁优化(JIT 自动)

| 优化 | 含义 |
|---|---|
| **锁消除** | JIT 检测到锁对象**不可能被共享** → 直接去掉锁(`StringBuffer.append` 在局部变量场景) |
| **锁粗化** | 连续多次加锁同一对象 → 合并成一次 |
| **自旋锁 / 自适应自旋** | 短时间内能得到锁就别挂线程,**自旋次数 JIT 自适应** |

> 🎯 **面试 L3-L4**:**为什么 StringBuilder 不是线程安全,但生产却用得多?** 答:**JIT 锁消除** + **绝大部分场景是单线程局部变量,直接消除 synchronized 开销**。

### 7.5 本章面试必答

1. **synchronized 4 种锁状态 + 升级路径**(单向)
2. **偏向锁为什么被弃用**(JDK 15+)
3. **锁消除 / 锁粗化 / 自旋锁**

---

## 8. ⭐⭐⭐ AQS(AbstractQueuedSynchronizer)

> **AQS 是 JUC 的灵魂** —— ReentrantLock / Semaphore / CountDownLatch / ReentrantReadWriteLock 都是基于它。

### 8.1 核心结构

```java
public abstract class AbstractQueuedSynchronizer {
    private volatile int state;            // 同步状态(int)
    private transient volatile Node head;  // 等待队列头
    private transient volatile Node tail;  // 等待队列尾(双向链表)
    
    static final class Node {
        volatile int waitStatus;           // -1:SIGNAL / 1:CANCELLED / -2:CONDITION
        volatile Node prev;
        volatile Node next;
        volatile Thread thread;
    }
}
```

**核心 = state(int) + 等待队列 CLH(双向链表)**

### 8.2 ⭐ ReentrantLock 源码理解(50 行讲清楚)

```java
// 加锁
public void lock() {
    sync.lock();        // sync = NonfairSync / FairSync
}

// 非公平锁的 lock
final void lock() {
    if (compareAndSetState(0, 1))   // 1. 直接 CAS 抢
        setExclusiveOwnerThread(currentThread);  // 抢到 → 设置持有者
    else
        acquire(1);     // 抢不到 → 走 acquire 流程
}

// AQS.acquire
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}

// 子类实现 tryAcquire(state 是不是可以拿)
protected boolean tryAcquire(int arg) {
    int c = getState();
    if (c == 0) {
        if (compareAndSetState(0, arg)) {           // CAS 抢
            setExclusiveOwnerThread(currentThread);
            return true;
        }
    } else if (currentThread == getExclusiveOwnerThread()) {
        setState(c + arg);                          // 重入(state++)
        return true;
    }
    return false;
}
```

### 8.3 ⭐⭐ 公平 vs 非公平

```java
// 非公平:直接 CAS 抢(可能插队)
final void lock() {
    if (compareAndSetState(0, 1))
        setExclusiveOwnerThread(currentThread);
    else
        acquire(1);
}

// 公平:先看队列里有没有等待者
protected boolean tryAcquire(int arg) {
    if (!hasQueuedPredecessors()  // ⭐ 关键差异!
        && compareAndSetState(0, arg)) {
        ...
    }
}
```

> 🎯 **面试**:**默认非公平锁?为什么?** → 性能更好(避免唤醒 + 上下文切换);代价是**可能饥饿**(但概率小)。

### 8.4 Condition / await / signal

```java
ReentrantLock lock = new ReentrantLock();
Condition cond = lock.newCondition();

// 线程 A
lock.lock();
try {
    while (!ready) cond.await();    // 释放锁 + 进入条件队列
} finally { lock.unlock(); }

// 线程 B
lock.lock();
try {
    ready = true;
    cond.signal();                  // 唤醒条件队列上一个线程,挪到等待队列
} finally { lock.unlock(); }
```

> 🎯 **面试可讲**:**Condition 和 wait/notify 区别** → Condition **可以创建多个**(不同等待场景),`wait/notify` 只有一个隐式队列。

### 8.5 ⭐⭐ 共享模式 = Semaphore / CountDownLatch / ReadLock

| 类 | state 含义 |
|---|---|
| **ReentrantLock** | 重入次数 |
| **Semaphore(N)** | 剩余许可数,acquire = state--,release = state++ |
| **CountDownLatch(N)** | 倒计数,countDown = state--,await 等 state = 0 |
| **ReentrantReadWriteLock** | state 高 16 位 = 读次数,低 16 位 = 写次数 |

### 8.6 本章面试必答

1. **AQS 的 state + 等待队列**
2. **ReentrantLock 加锁流程**(CAS / acquireQueued / park)
3. **公平 vs 非公平区别 + 默认为什么非公平**
4. **Condition 怎么用 / 跟 wait-notify 区别**

---

## 9. CAS / Atomic / ABA

### 9.1 CAS 底层

`compareAndSwap(oldVal, newVal)` —— 比较内存值是不是 oldVal,是就改成 newVal,**整个过程原子**。

底层:**CPU 指令 `cmpxchg`**(单条指令,硬件级原子) → JDK 通过 `Unsafe.compareAndSwapInt` 暴露 → 各 Atomic 类用它。

### 9.2 ⭐ ABA 问题

```
线程 1:读 A
线程 2:改 A → B → A     (这期间值变过,但 CAS 看不出来)
线程 1:CAS(A → C) 成功    ⚠️ 但中间 A 经历过变化
```

**解决**:
- **AtomicStampedReference**:加版本号,CAS 比较 (值 + 版本)
- **AtomicMarkableReference**:加布尔标记

> 🎯 **面试**:**什么场景 ABA 会有问题?** → 链表 / 栈 的并发操作(节点被复用)。

### 9.3 LongAdder vs AtomicLong(⭐ 高并发优化)

**AtomicLong**:所有线程 CAS 同一变量 → 高并发下大量自旋失败

**LongAdder**:**分段累加**,每个线程操作自己的 Cell,最终求和 → 高并发吞吐**远高于** AtomicLong

> 🎯 **面试加分**:**统计计数场景应该用 LongAdder 而不是 AtomicLong**(JDK 8+)。

---

## 10. JUC 并发集合

### 10.1 ⭐⭐⭐ ConcurrentHashMap(必考)

#### JDK 7
- **分段锁(Segment)**:HashMap 拆成 16 个 Segment,各自加锁
- 默认并发度 16

#### JDK 8(⭐ 重点)
- **取消 Segment**,改用 **CAS + synchronized 锁单个桶**
- **桶头节点用 CAS 写**(无竞争零成本)
- **桶有冲突就 synchronized 该头节点**
- **链表 → 红黑树**(同 HashMap)

> 🎯 **面试 L3-L4**:
> - **JDK 8 为什么放弃分段锁?** → 锁粒度更细(单桶 vs 16 段),性能更好
> - **size() 怎么算?** → 通过 baseCount + CounterCell 数组分段累加(类似 LongAdder)
> - **不可有 null 键 null 值** —— 因为多线程下无法区分"没找到" vs "值是 null"

### 10.2 CopyOnWriteArrayList

- **读不加锁**(读快)
- **写加锁 + 复制整个数组 + 新数组写完后替换引用**
- **适合读多写少 + 数据量小**(否则复制成本爆炸)
- **典型场景**:Spring `EventListener` 列表 / JDK Observable

### 10.3 BlockingQueue 6 种(必背)

| 队列 | 容量 | 特点 |
|---|---|---|
| **ArrayBlockingQueue** | 有界(必填) | 数组,FIFO |
| **LinkedBlockingQueue** | 可有界可无界(默认 Integer.MAX_VALUE) | 链表 / **⚠️ 默认无界,线程池用要小心** |
| **PriorityBlockingQueue** | 无界 | 堆,按优先级 |
| **DelayQueue** | 无界 | **延迟出队**(Quartz 用) |
| **SynchronousQueue** | 容量 0 | **生产者必须等消费者**(CachedThreadPool 用) |
| **LinkedTransferQueue** | 无界 | JDK 7+,transfer 方法保证消费者拿到 |

> 🔗 **结合你项目**:
> - **SI Zero Engine `samplingScheduler`**:用 ScheduledExecutorService → 内部是 **DelayQueue**
> - **ASP 任务调度**:可能用 LinkedBlockingQueue → ⚠️ **默认无界 = 任务堆积 = OOM**(必须显式指定容量)

### 10.4 本章面试必答

1. **ConcurrentHashMap JDK 7 vs 8** → 分段锁 → CAS+synchronized 桶
2. **size() 怎么算** → CounterCell 分段
3. **6 种 BlockingQueue** → 重点 LinkedBlockingQueue 无界陷阱
4. **CopyOnWriteArrayList 适用场景**

---

## 11. ThreadLocal 深入(PDF 没说的)

> PDF 已经讲了基础和内存泄漏,这里补 PDF 没说的:

### 11.1 ⭐ 为什么 ThreadLocalMap 用**线性探测开放定址**(不是 HashMap 的链表)?

- ThreadLocal 数量通常很少(< 100 / 线程)
- 开放定址 = 数组 + 线性探测,**缓存命中率高**
- 链表代价不值得

### 11.2 ⭐⭐ 0x61c88647(黄金分割数)

ThreadLocal hash 增量 = 0x61c88647(2^32 / 黄金分割比),让 hashcode **均匀分布**。

> 🎯 **面试 L4 加分**:**为什么是这个魔数?** → 黄金分割,Fibonacci 散列法,散列均匀。

### 11.3 ⭐ TransmittableThreadLocal(TTL)

> 阿里开源,**线程池场景**下传递 ThreadLocal。

**问题**:`InheritableThreadLocal` 只在线程**创建时**复制父线程,但**线程池里线程是复用的**,新任务无法继承提交者的上下文。

**TTL 解决**:**每次任务提交时**捕获当前线程上下文 → 任务执行时设置 → 执行完恢复。

> 🎯 **面试 L4 加分**:**线程池 + ThreadLocal 怎么传递?** → InheritableThreadLocal 不行,**用 TTL**。

---

## 12. CompletableFuture(JDK 8 + 必备)

> 你简历会写"用过 CompletableFuture",但面试官会追问**底层 + 实战**。

### 12.1 核心 API 三类

| 类型 | 方法 | 返回值 | 用途 |
|---|---|---|---|
| **变换** | `thenApply` / `thenAccept` / `thenRun` | 有/无 | 同步流转换 |
| **组合** | `thenCompose` / `thenCombine` / `allOf` / `anyOf` | CompletableFuture | 多 Future 串行 / 并行 |
| **异步** | `*Async` 后缀 | CompletableFuture | 在线程池执行 |

### 12.2 ⭐⭐ 默认线程池陷阱

```java
CompletableFuture.supplyAsync(() -> ...);   // ⚠️ 默认用 ForkJoinPool.commonPool()
```

**坑**:
- ForkJoinPool 大小 = CPU 核心数 - 1(默认)
- 多个业务共用 = **互相干扰**
- **生产必须显式传线程池**:

```java
ExecutorService bizPool = Executors.newFixedThreadPool(20);
CompletableFuture.supplyAsync(() -> ..., bizPool);
```

### 12.3 异常处理

| 方法 | 含义 |
|---|---|
| `exceptionally(Throwable -> T)` | 捕获 + 转换 |
| `handle((T, Throwable) -> R)` | 同时处理结果和异常 |
| `whenComplete((T, Throwable) -> void)` | 只观察,不改值 |

> 🎯 **面试可讲**:**CompletableFuture 异常的传播规律** —— 默认会**短路**(后续 stage 不执行),除非显式 `exceptionally` / `handle` 处理。

---

## 13. ⭐⭐⭐ 实战:与你已有项目结合(简历可写故事)

> **这一节是你最该花时间的** —— 把上面的知识点和你的真实场景绑定。

### 13.1 SI Zero Engine 1000 线程池调优(L3-L4 故事)

**素材**:`samplingScheduler` 1000 线程的 ScheduledExecutorService

**可讲点**:
1. **为什么 1000 不是 100 / 10000?**
   - SNMP 采集是**网络 IO 密集型** → 线程数 ≈ CPU * (1 + IO 等待 / CPU 时间)
   - 实际取决于:设备数 + 采集间隔
2. **拒绝策略选了哪个?为什么?**
   - 默认 AbortPolicy(抛异常) vs CallerRunsPolicy(调用者跑) vs DiscardPolicy / DiscardOldestPolicy
   - 采集场景:**丢弃旧的**?还是**让调用者背压**?
3. **ScheduledExecutorService 的坑** → 内部是 DelayQueue,**任务异常会吞掉** → 必须 try-catch 包住

**面试故事框架**:
```
我们 SI Zero Engine 的 SNMP 采集层用的是 ScheduledExecutorService,1000 个核心线程。
线程数选 1000 是因为:N 个设备 × 采集间隔 / 单次采集耗时,加上 SNMP 是 IO 密集 → 我们做过 [TODO: 具体压测数据]。
拒绝策略我们选 [TODO: AbortPolicy / CallerRunsPolicy],原因是 [TODO]。
还踩过一个坑 —— ScheduledExecutorService 任务里抛异常会被吞,后续不再执行,我们必须每个任务用 try-catch 包住保证调度链不断。
```

### 13.2 ASP @RedisLock 的并发实现深度(L4 故事)

**素材**:`@RedisLock` 注解 + AOP + spring.factories

**可讲点**:
1. **为什么用 AOP 而不是手动 try-finally?** → 减少重复代码 + 标准化
2. **`@Order(HIGHEST_PRECEDENCE)` 的深度** → 这是 §6.5.3 已经讲过的 P7+ 题
3. **lockKey 用 SpringEL 解析** → 灵活但有性能代价(每次反射) → 是否缓存解析结果?
4. **DistributedLock 内部用 SET NX EX + Lua 删除** → 必须保证**加锁 + 删锁原子**

**面试故事框架**:
```
我们在中移项目里把 Redis 分布式锁封装成 @RedisLock 注解 + AOP,通过 spring.factories
让多个微服务一加依赖就能用。
最关键的设计决策是 @Order(HIGHEST_PRECEDENCE) —— 让锁切面在事务切面之前执行,
确保「先加锁,再开事务」、「先提交事务,再释放锁」,避免事务回滚时锁先释放导致的脏数据问题。
当时还遇到一个细节:lockKey 用 SpringEL 表达式,每次反射解析有性能代价,后来加了
解析结果的 Caffeine 缓存。
```

### 13.3 PI 4.0 重构 GC 收集器升级(L4 故事)

**素材**:Java 8 → Java 21 + Hazelcast 砍掉

**可讲点**:
1. **G1 → ZGC 切换** → STW 从 200ms 级降到 < 10ms(理论数字,**你需要实测验证**)
2. **Hazelcast 砍掉后,直接内存压力大幅下降** → 简历写"Direct Memory 占用从 N MB → M MB"
3. **JDK 21 的 Virtual Thread** → 是否考虑了?(你简历可加分点)

**面试故事框架**:
```
PI 4.0 重构里,我们从 Java 8 升级到 Java 21,顺势把 GC 收集器从 G1 切到 ZGC。
原因是 PI 部署在客户机房,堆通常 4-16GB,业务对延迟敏感(实时监控),ZGC 的 STW
能控制在 10ms 以下,对告警实时性是关键。
另一个变化是砍掉了 Hazelcast 集群框架,直接内存占用大幅下降 —— Hazelcast IMap 的
off-heap 存储是直接内存大户,改用 Caffeine 后整个 JVM 的 -XX:MaxDirectMemorySize 
都不需要再设大值了。
```

### 13.4 ⭐ 简历专业技能段升级版(直接复制)

```
【后端核心】
- Java 8 / 21 LTS,熟悉 Lambda / Stream / 泛型类型擦除 / 函数式接口
- 并发:线程池 5 参数 + 4 种内置选型 + IO/CPU 密集型配比、CompletableFuture 异步编排、
  ThreadLocal 实现原理(0x61c88647 哈希 / 弱引用) + InheritableThreadLocal / TTL 在
  线程池场景的传递、AQS 体系(ReentrantLock / Semaphore / CountDownLatch)
- 同步:synchronized 锁升级(无锁 → 偏向 → 轻量 → 重量) / volatile JMM / DCL 单例
- JUC 集合:ConcurrentHashMap JDK 7→8 演进(分段锁 → CAS+synchronized 桶级)、
  6 种 BlockingQueue、CopyOnWriteArrayList
- JVM:运行时数据区、双亲委派 + Tomcat/SPI 打破场景、可达性分析 + 4 种引用、对象晋升
  老年代 4 种方式
- GC:G1(JDK 9+ 默认) + ZGC(JDK 11+ 大堆低延迟,在 PI 4.0 重构中启用)
- 排查:jstat / jmap / jstack / MAT / Arthas 实战,曾在生产环境定位过
  [TODO: 具体一个 case]

【中间件 / 数据库】
- (你简历原有的内容)
```

---

## 14. 学习路径建议(给 4 年 Java 后端的你)

### 14.1 第 1 个月(本月)

- [ ] **每周精读 2-3 章**(本文档)
- [ ] **每章末"结合你项目"那一段**:回到代码 / 文档查证
- [ ] **GC 日志练手**:在你 Vertiv 本地 SI 环境**开 GC 日志看一周**

### 14.2 第 2-3 个月

- [ ] **AQS 源码精读** → 看 ReentrantLock + Semaphore + CountDownLatch
- [ ] **ConcurrentHashMap JDK 8 源码** → 1500 行,值得啃
- [ ] **MAT 实战** → 找你项目的 dump.hprof / 自己造一个 OOM
- [ ] **配合 LeetCode 并发题**:[1114] [1115] [1116] [1117]

### 14.3 第 4-6 个月

- [ ] **Spring Bean 生命周期 / 循环依赖三级缓存**
- [ ] **MQ 三大问题 + Redis 持久化主从**
- [ ] **MySQL InnoDB 行锁 / 间隙锁 / 临键锁**
- [ ] **Netty 基础** → 看你目标公司方向

### 14.4 半年后

- [ ] **系统设计 / DDD / 领域建模**
- [ ] **分布式深度** → Raft / 一致性哈希
- [ ] **算法精进** → 大厂笔试关

---

## 15. 推荐资源(精选,不堆)

| 资源 | 备注 |
|---|---|
| **《深入理解 Java 虚拟机》第 3 版**(周志明) | 必读,JVM 圣经 |
| **《Java 并发编程的艺术》**(方腾飞) | JUC 入门 |
| **《Java 并发编程实战》**(JCIP,Doug Lea 等) | 经典,英文版更好 |
| **《Effective Java》第 3 版** | 提升代码品味 |
| **OpenJDK Wiki / JEP** | 最权威,英文,适合查具体特性 |
| **美团技术博客** | "美团 + JVM" / "美团 + 线程池" 都有质量文 |

> ⚠️ **不推荐**:
> - 各类"八股文" / "面试题大全" → 浅 + 错 + 无场景
> - B 站 / 知乎随便搜的视频 → 错的多

---

## 16. 我的反思(给你)

写完这份文档后我对你的判断:

### ✅ 你的优势
- **业务广度** + **工程化封装能力**(@RedisLock / dbproxy / Driver Hub) → 这是大部分 4 年 Java 候选人**没有**的
- **跨技术栈视野**(Java 8/21 / Spring 2/3 / Mongo/PG / SNMP) → 简历**篇幅不缺**,缺**深度证据**
- **架构思考**(PI 4.0 重构、Hazelcast 砍掉决策) → 已经有 P6+ 影子

### ⚠️ 你最该补的(按 ROI)
1. **JVM/GC/JUC 底层**(本文档目标) → 1-3 个月
2. **生产环境 GC / OOM 排查实战故事** → 等下一次有机会
3. **算法 / 系统设计** → 大厂面试关

### 💡 战略建议
- **不要"看完八股就投简历"** —— 你已经过这个阶段了
- **把每个知识点和你的项目绑定** —— 这是 4 年 vs 1 年候选人的真实差距
- **半年内**出去面试一次**(就算不跳)** —— 试水当前水位
- **每季度复盘**这份文档 —— 知识不复盘 90 天后只剩 30%

---

> 📌 **下一步**:
> - 选 3 章精读(建议:§4 GC 收集器 + §6 JMM/volatile + §8 AQS)
> - 看完后**找一道 LeetCode 1114**(按序打印)练手
> - **告诉我你卡在哪一章** → 我可以单独再深入展开
