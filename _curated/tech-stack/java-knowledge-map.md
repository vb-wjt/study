# Java 知识地图 (基于 `Java Study.pdf` 索引)

> **来源**:`file/3-tech_stack/Java Study.pdf` (103 页,用户在中移 / 实习期间整理)
> **目的**:这份文档**不抄原文**(原 PDF 已经写得很完整),只做:
> 1. **章节索引导航** —— 哪个题在 PDF 哪一页
> 2. **面试高频度评估** —— 标注哪些是必准备 / 哪些是冷门
> 3. **PDF 的盲点 / 应补强** —— 哪些主题该有却没覆盖
> 4. **与本工程其他素材的串联** —— 把 PDF 的知识点 link 到你做过的项目场景

标签:`[就绪]` `[面试高频]`🎯 `[源文]` `[跨主题]`🔗

---

## 0. 一眼盘点

| 维度 | 数据 |
|---|---|
| 总页数 | **103 页** |
| 一级章节 | **9 个**(前端 / JavaSE / SSM / 数据库 / 多线程 / 缓存 / 分布式 / 调优 / 服务器&Linux) |
| 内容形态 | **面试题问答式**(每题先问后答,排版偏 Q&A) |
| 大致整理时间 | 中移在职期间(2022-2024)|
| 我的总体评价 | ⭐⭐⭐ **覆盖广 + 实战气足**(很多题来自真实开发遇到的问题,不是单纯抄书) |

> ✅ **已转写**(2026-05):[`file/3-tech_stack/java-study.md`](../../file/3-tech_stack/java-study.md) (1714 行),修正了 OCR 错别字 + 优化排版,原 PDF 仍保留可对照。

---

## 1. 章节索引(按 PDF 顺序)

> 列出每个一级 / 二级标题 + 大致页码 + 我对其面试价值的评级。

### 1.1 前端(p.2-5,2 题,价值 ⭐ 偏低)

| 子题 | 页码 | 评级 |
|---|---|---|
| `=` vs `==`,null/undefined/NaN 区别 | p.3 | ⭐ 后端面试基本不问 |
| 跨域(JSONP / Nginx / CORS) | p.4-5 | ⭐⭐ 后端会问 CORS 配置 |

> 💡 **建议**:你目标是 Java 后端,前端章节可以**最低优先级回看**。

### 1.2 JavaSE(p.6-13,6 题,价值 ⭐⭐⭐ 必准备)

| 子题 | 页码 | 评级 | 备注 |
|---|---|---|---|
| JDK 中用到的设计模式(7 个) | p.7 | ⭐⭐ 概念题 | 单例/工厂/适配器/观察者/原型/装饰器/建造者 |
| ArrayList(扩容机制) | p.8 | ⭐⭐⭐ 基础题 | 1.5x 扩容、初始 10、查询 O(1) |
| HashMap(扩容机制) | p.8 | ⭐⭐⭐ **必考** | 0.75 阈值、2x 扩容、初始 16、1.7 头插 → 1.8 尾插、链表 → 红黑树阈值 8/64 |
| 重载 vs 重写 | p.9 | ⭐⭐ 基础题 | 重写规则:返回类型 / 异常 / 修饰符约束 |
| 泛型(类型擦除 / 通配符) | p.10-11 | ⭐⭐⭐ | `<T>` `<? extends>` `<? super>` |
| Lambda 表达式 | p.12-13 | ⭐⭐ | 函数式接口 / @FunctionalInterface |

> 🎯 **重点**:HashMap 几乎是 Java 后端面试 100% 会问 —— 准备到 L4 (能讲红黑树退化、并发问题、负载因子选择理由)。

### 1.3 SSM(p.14-22,价值 ⭐⭐⭐ 必准备)

#### 1.3.1 Spring(p.14-16,3 题)

| 子题 | 页码 | 评级 |
|---|---|---|
| Spring 常用注解(26 个) | p.15-16 | ⭐⭐ 列表题 |
| Spring 用到的设计模式(8 个) | p.16 | ⭐⭐ 概念题 |

> 💡 **PDF 没覆盖但**面试**会问**:
> - Bean 生命周期(实例化 / 属性注入 / Aware / 初始化前 BeanPostProcessor / 初始化 / 初始化后 / 使用 / 销毁)
> - Spring AOP 实现原理(JDK 动态代理 vs CGLIB)
> - 循环依赖三级缓存机制 (singletonObjects / earlySingletonObjects / singletonFactories)
> - **建议补强**:在你写的 ASP knowledge.md 里有 `RedisLockAspect` 的实战 → 可以围绕这个讲 AOP

#### 1.3.2 SpringMVC(p.16-19,3 题)

| 子题 | 页码 | 评级 |
|---|---|---|
| SpringMVC 工作原理(10 步) | p.17 | ⭐⭐⭐ **必考** |
| `@RestController` vs `@Controller` | p.18 | ⭐⭐ |
| SpringMVC 常用注解(19 个) | p.18-19 | ⭐⭐ |

#### 1.3.3 MyBatis(p.20-22,2 题)

| 子题 | 页码 | 评级 |
|---|---|---|
| MyBatis 分页 | p.21 | ⭐⭐ |
| **PageHelper 工作原理** | p.22 | ⭐⭐⭐ **L4 加分**:讲 ThreadLocal + Interceptor 拦截器机制 |

> 💡 **PDF 没覆盖但**:
> - MyBatis 一级缓存 / 二级缓存(可在 knowledge.md 里看到提到了一句"无")
> - `${}` vs `#{}`(SQL 注入 + 见 PDF p.40 问题 13)
> - MyBatis-Plus(你简历列了)与原生 MyBatis 区别

### 1.4 数据库(p.23-43,16 题,价值 ⭐⭐⭐⭐ 高频)

> 这是 PDF **最大的章节**,也是简历"PostgreSQL / Oracle / MySQL"必备的弹药库。

| # | 子题 | 页码 | 评级 | 简评 |
|---|---|---|---|---|
| 1 | 分库分表(垂直 / 水平) | p.23 | ⭐⭐ |
| 2 | Oracle 分区 | p.23 | ⭐ 可选 |
| 3 | 事务 ACID | p.23-24 | ⭐⭐⭐ **必考** |
| 4 | 事务隔离级别 + MVCC | p.24-25 | ⭐⭐⭐ **必考** |
| 5 | **索引选型 + B+树 vs B树** | p.26 | ⭐⭐⭐⭐ **必考** |
| 5.2 | MySQL Innodb (B+) vs Oracle (B) 索引区别 | p.26-27 | ⭐⭐⭐ |
| 5.3 | **唯一索引 vs 普通索引(change buffer)** | p.27-28 | ⭐⭐⭐ **L4** 加分点 |
| 5.4 | **explain 执行计划详解** | p.29-31 | ⭐⭐⭐⭐ **必考** |
| 5.4 | profiling | p.32 | ⭐⭐ |
| 5.5 | **索引失效场景(9 种)** | p.32-33 | ⭐⭐⭐⭐ **必考** |
| 6 | **数据库优化操作(17 条)** | p.33-35 | ⭐⭐⭐⭐ **必考** |
| 7 | SQL 慢查询排查 | p.35 | ⭐⭐⭐ |
| 8 | **海量数据导入导出(Job/MQ/EasyExcel/WebSocket)** | p.36-38 | ⭐⭐⭐ **L4** 工程实战 |
| 9 | 设计数据库表的注意事项(15 条) | p.38 | ⭐⭐ 列表题 |
| 10 | `select for update` 加什么锁 | p.39 | ⭐⭐⭐ **必考** |
| 11 | `count(*)` / `count(1)` / `count(id)` 区别 | p.39 | ⭐⭐⭐ **必考** |
| 12 | 加密数据模糊查询 | p.40 | ⭐⭐ 巧题 |
| 13 | **SQL 注入防范** | p.40-41 | ⭐⭐⭐ |
| 14 | varchar(64) → varchar(640) 影响 | p.41-42 | ⭐⭐ |
| 15 | B+树 / B树 详解 | p.42 | ⭐⭐⭐ |
| 16 | inner / left / right / full join 区别 | p.43 | ⭐⭐ |

> 🎯 **重点准备 5 个**:索引失效 9 种 / explain / B+树 vs B树 / change buffer / 数据库优化 17 条
> 这 5 个题是 P5+ 后端的"**生死线**"。

### 1.5 多线程(p.45-53,2 大主题,价值 ⭐⭐⭐⭐ 高频)

#### 1.5.1 线程池(p.45-50)

| 子题 | 页码 | 评级 | 简评 |
|---|---|---|---|
| 线程池作用 | p.45 | ⭐⭐ |
| **线程池 5 个参数** | p.45-46 | ⭐⭐⭐⭐ **必考** | core / max / keepAlive / queue / handler |
| **线程池执行流程** | p.46-47 | ⭐⭐⭐⭐ **必考** | 4 步:核心 → 队列 → 非核心 → 拒绝策略 |
| 4 种内置线程池 | p.47-49 | ⭐⭐⭐ | Single / Fixed / Scheduled / Cached |
| **CPU 密集型 vs IO 密集型 配置** | p.45 | ⭐⭐⭐ **必考** |
| **动态线程池(美团方案)** | p.50 | ⭐⭐⭐⭐ **L4 加分** | 配置中心 + 监控告警 |

#### 1.5.2 ThreadLocal(p.51-53)

| 子题 | 页码 | 评级 | 简评 |
|---|---|---|---|
| ThreadLocal vs Synchronized | p.51 | ⭐⭐ |
| **ThreadLocal 实现原理** | p.52 | ⭐⭐⭐⭐ **必考** | ThreadLocalMap / Entry 弱引用 / 0x61c88647 hash |
| InheritableThreadLocal | p.52 | ⭐⭐⭐ | 父子线程传递 |
| ThreadLocal 使用场景 | p.53 | ⭐⭐⭐ | SimpleDateFormat / 用户上下文 / DB Connection |
| **ThreadLocal 内存泄漏** | p.53 | ⭐⭐⭐⭐ **L4 必问** | 弱引用 + 强引用链 |

> 💡 **PDF 没覆盖但**:
> - **AQS**(AbstractQueuedSynchronizer):ReentrantLock / CountDownLatch / Semaphore 底层
> - **CAS** + Unsafe + ABA 问题 + AtomicStampedReference
> - **JUC 包**:CompletableFuture / ForkJoinPool / ConcurrentHashMap 详解
> - **synchronized 锁升级**(无锁 → 偏向锁 → 轻量级锁 → 重量级锁)
> - `volatile` + 可见性 / 有序性 / Happens-Before
>
> ⚠️ **这些都是 P6+ 必考** —— 强烈建议补强。

### 1.6 缓存(p.54-61,7 题,价值 ⭐⭐⭐⭐ 高频)

| # | 子题 | 页码 | 评级 |
|---|---|---|---|
| 1 | **缓存穿透**(布隆过滤器 + 缓存空值) | p.54 | ⭐⭐⭐⭐ **必考** |
| 2 | **缓存击穿**(加锁 + 永不过期) | p.54-55 | ⭐⭐⭐⭐ **必考** |
| 3 | **缓存雪崩**(随机过期时间 + 高可用 + 服务降级) | p.55 | ⭐⭐⭐⭐ **必考** |
| 4 | **DB / 缓存双写一致性 4 种顺序** | p.56-58 | ⭐⭐⭐⭐ **L4** 经典 | **这是 PDF 写得最完整最深的部分**,值得**反复看** |
| 5 | 大 key 问题 | p.58 | ⭐⭐ |
| 6 | 热 key 问题 | p.59 | ⭐⭐⭐ |
| 7 | **集群下本地缓存一致性 3 方案** | p.60-61 | ⭐⭐⭐ **L4** | TTL / 配置中心 / Caffeine.refreshAfterWrite |

> 🎯 **缓存三件套(穿透/击穿/雪崩)**:几乎每场后端面试都会问 —— 答得快、答得全、答得有新意 = 加分。

### 1.7 分布式(p.62-94,**最长**,价值 ⭐⭐⭐⭐⭐ 王炸)

#### 1.7.1 分布式锁(p.62-65)

| 子题 | 页码 | 评级 |
|---|---|---|
| 单机 Redis 分布式锁(SET NX EX) | p.63 | ⭐⭐⭐⭐ **必考** |
| RedLock(集群 Redis) | p.63 | ⭐⭐⭐ L4 加分 |
| Jedis / Lettuce / **Redisson** 对比 | p.64 | ⭐⭐⭐ |
| **ZooKeeper 分布式锁(临时顺序节点 + 监听)** | p.64 | ⭐⭐⭐ |
| 数据库分布式锁(悲观 / 乐观) | p.65 | ⭐⭐ |

> 💡 **可对照**:你 ASP knowledge.md 里有 `@RedisLock` 注解 + Aspect 完整代码 → **结合面试时讲**(从单机锁的工程化封装讲起,再讲为什么 HIGHEST_PRECEDENCE)。

#### 1.7.2 分布式事务(p.65-87,**这是 PDF 最详尽的章节**)

| 子题 | 页码 | 评级 | 简评 |
|---|---|---|---|
| 场景(订单 + 库存 + 客户) | p.65 | ⭐⭐⭐ |
| **CAP 理论** | p.66 | ⭐⭐⭐⭐ **必考** |
| **BASE 理论** | p.67-68 | ⭐⭐⭐⭐ **必考** |
| **2PC + XA** | p.68-72 | ⭐⭐⭐⭐ **必考** | 包括极端故障分析 |
| **Seata(2PC AT 模式)** | p.73-77 | ⭐⭐⭐⭐ |
| ASP 平台 DAM(自家 XA 实现) | p.78 | ⭐⭐ 内部专属 |
| 3PC | p.78-80 | ⭐⭐ |
| **TCC** | p.81-83 | ⭐⭐⭐⭐ |
| **本地消息表** | p.83 | ⭐⭐⭐⭐ **常考** |
| **消息事务(RocketMQ)** | p.84 | ⭐⭐⭐⭐ |
| 最大努力通知 | p.85-87 | ⭐⭐⭐ |

> 🎯 **分布式事务**这块是 P6+ 候选人**核心差异化** —— PDF 这部分写得**接近系统课级别**,可以直接当作面试复习材料。

#### 1.7.3 Spring 事务(p.88-91)

| 子题 | 页码 | 评级 |
|---|---|---|
| **事务回滚机制(AOP + RuntimeException 默认)** | p.88 | ⭐⭐⭐⭐ |
| **7 种传播级别** | p.89 | ⭐⭐⭐⭐ **必考** |
| `@Transactional` AOP 底层 | p.90 | ⭐⭐⭐⭐ **L4** |
| **事务失效 9 种场景** | p.91 | ⭐⭐⭐⭐ **必考** |

> 💡 **可对照**:你 ASP knowledge.md 提到"@RedisLock 切面要在事务前执行" → 结合 §1.7.1 + 这里讲一个**完整故事**:**为什么分布式锁必须在事务外**。

#### 1.7.4 分布式 ID / Session(p.91)
> ⚠️ 标了标题但没展开 —— 这是 PDF 的**盲点**,需要补:
> - **雪花算法(Snowflake)** + 优化方案(美团 Leaf)
> - **分布式 Session**:Redis / Spring Session / JWT 三种方案对比

#### 1.7.5 综合例子(p.92-94)

> 订单 + 账户 + 库存的"超扣"问题 + 异步补偿 + 一致性方案。
> ⭐⭐⭐ **价值高** —— 直接可作为系统设计题的回答模板。

### 1.8 调优(p.96-97,1 题,价值 ⭐⭐⭐⭐ 高频)

| 子题 | 页码 | 评级 | 简评 |
|---|---|---|---|
| Java 应用性能监控 + 调优 | p.96-97 | ⭐⭐⭐⭐ | 工具:JConsole / VisualVM / **JMC** / JProfiler / GCViewer / MAT |
| 压测:JMeter / Gatling | p.96 | ⭐⭐⭐ |
| **JVM 调优 + JIT + GC 调优** | p.96-97 | ⭐⭐⭐⭐ **简略,需补强** |

> 💡 **PDF 严重盲点**:
> - **JVM 内存模型**(堆 / 栈 / 方法区 / 元空间 / 直接内存) —— 必考
> - **GC 算法**(标记清除 / 复制 / 标记整理 / 分代)
> - **GC 收集器**(Serial / Parallel / CMS / G1 / ZGC / Shenandoah)—— ⭐⭐⭐⭐ 必考
> - **GC 调优实战**(MaxGCPauseMillis / SurvivorRatio / NewRatio)
> - **OOM 排查**(MAT 分析 dump 文件)
>
> ⚠️ 这是 PDF 最**薄弱**的部分,Vertiv L 也强调过"专业英语 + 软技能",但**调优这块也得补**(P6+ 强需求)。

### 1.9 服务器 & Linux(p.98-102,价值 ⭐⭐ 中等)

#### 1.9.1 Nginx(p.98-100)

| 子题 | 页码 | 评级 |
|---|---|---|
| Nginx 配置文件结构 | p.99 | ⭐⭐ |
| Nginx 性能优化(9 条) | p.100 | ⭐⭐⭐ |

> 💡 你 ASP knowledge.md 还有 nginx-ingress-controller 的更深入分析 → 可结合讲 **K8s 入口流量**这一层。

#### 1.9.2 Linux(p.100-102)

| 子题 | 页码 | 评级 |
|---|---|---|
| 防火墙(iptables / firewalld) | p.101 | ⭐⭐ |
| 常用命令(top/scp/yum/crontab/rsync/mount/traceroute/netstat) | p.102 | ⭐⭐ |

> 💡 你 `_curated/tech-stack/linux-filesystem-and-perms.md` 已经有更深的内容 → **PDF 这部分可以略过,优先看 expansions 那份**。

---

## 2. PDF 与本工程素材的串联(怎么用)

### 2.1 PDF 知识点 ↔ 你的项目场景

| PDF 知识点 | 工程内对应实战 | 怎么用 |
|---|---|---|
| HashMap 扩容机制 | — | 概念题,讲清楚 |
| ThreadLocal 实现原理 + 内存泄漏 | ASP `PortalReqContext`(网关 4 个 Filter 用) | **结合实战讲**(我**真用过** ThreadLocal + 知道为什么要 remove) |
| 线程池 5 参数 + 4 种类型 | SI Zero Engine 的 `samplingScheduler`(1000 线程) | **真在生产用过 ScheduledExecutorService** |
| 数据库 17 条优化原则 | ASP 的"大数据量 IN/JOIN 优化"(knowledge §6.2) | **真踩过这些坑** |
| explain 执行计划 | ASP 优化历史(knowledge "执行慢 → 不走索引") | **真用过 explain 排查** |
| Redis 分布式锁(SET NX EX) | ASP `@RedisLock` AOP(knowledge §4.4) | **完整工程化封装,L4 故事** |
| 缓存击穿 / 雪崩 | SI Zero Engine 的 Caffeine + JMS;ASP 的 cache-cli/server | **真在两个项目里都做过** |
| 分布式事务 BASE / TCC | ASP 的 DAM (XA 实现) | **真接触过 XA + 国企级强一致性场景** |
| Spring 事务失效 9 种 | ASP 调试 + 一些 try-catch 吞异常的踩坑 | 经典面试题 |
| @Transactional AOP 底层 | ASP `RedisLockAspect` HIGHEST_PRECEDENCE 设计 | **L4 加分** |
| Nginx 性能优化 | ASP nginx-ingress-controller(knowledge §6) | 实战 |

> 🎯 **关键洞察**:**你不缺知识,缺的是"把知识和实战故事绑定"**。
> 面试官问"线程池怎么用"时,**别背 PDF**,直接讲"我们 SI Zero Engine 用 1000 线程的 ScheduledExecutorService 做 SNMP 采集" + 选型理由。

### 2.2 PDF 与本 `_curated/` 内现有文档的关联

| PDF 章节 | 对应 _curated 文档 | 状态 |
|---|---|---|
| 1.3 SSM | [`tech-stack/spring-internals.md`](../tech-stack/spring-internals.md) ✏️新增 | ✅ Bean 生命周期 / 循环依赖 / AOP / Boot 启动 / @Transactional |
| 1.4 数据库 | `tech-stack/postgresql-knowledge.md` + [`tech-stack/mysql-deep-dive.md`](../tech-stack/mysql-deep-dive.md) ✏️新增 | ✅ MySQL InnoDB 锁 / MVCC / 主从 / binlog / ICP |
| 1.5 多线程 | [`tech-stack/jvm-and-concurrency.md`](../tech-stack/jvm-and-concurrency.md) | ✅ 完整覆盖 |
| 1.6 缓存 | [`tech-stack/redis-deep-dive.md`](../tech-stack/redis-deep-dive.md) ✏️新增 | ✅ 数据结构底层 / 持久化 / 主从 / Cluster / 淘汰策略 |
| 1.7 分布式 | [`tech-stack/mq-essentials.md`](../tech-stack/mq-essentials.md) ✏️新增 + [`tech-stack/system-design-primer.md`](../tech-stack/system-design-primer.md) ✏️新增 | ✅ MQ 三大问题 + 系统设计方法论 |
| 1.8 调优 | [`tech-stack/jvm-and-concurrency.md` §5](../tech-stack/jvm-and-concurrency.md) | ✅ |
| 1.9 Nginx/Linux | `tech-stack/linux-filesystem-and-perms.md` + [`tech-stack/network-essentials.md`](../tech-stack/network-essentials.md) ✏️新增 | ✅ TCP/HTTP/HTTPS/WebSocket |
| **新增维度** | [`tech-stack/testing-and-engineering.md`](../tech-stack/testing-and-engineering.md) ✏️新增 | ✅ 单测 / Git / CR / 文档(外企友好+L 反馈) |

---

## 3. PDF 的盲点(我建议你补的)

> 这些是 **PDF 没覆盖但 P6+ 后端面试会问的**:

| 盲点 | 重要度 | 状态 / 优先级 |
|---|---|---|
| ~~**JVM 内存模型 + GC 收集器**~~ | ⭐⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/jvm-and-concurrency.md` §1-§5](../tech-stack/jvm-and-concurrency.md) |
| ~~**AQS 源码理解**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/jvm-and-concurrency.md` §8](../tech-stack/jvm-and-concurrency.md) |
| ~~**synchronized 锁升级 / volatile JMM**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/jvm-and-concurrency.md` §6-§7](../tech-stack/jvm-and-concurrency.md) |
| ~~**ConcurrentHashMap / CAS / CompletableFuture**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/jvm-and-concurrency.md` §9-§12](../tech-stack/jvm-and-concurrency.md) |
| ~~**Spring Bean 生命周期 / 循环依赖三级缓存**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/spring-internals.md` §1-§2](../tech-stack/spring-internals.md) |
| ~~**Spring AOP 实现原理(JDK 动态代理 vs CGLIB)**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/spring-internals.md` §3](../tech-stack/spring-internals.md) |
| ~~**MySQL InnoDB 行锁 / 间隙锁 / 临键锁**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/mysql-deep-dive.md` §1](../tech-stack/mysql-deep-dive.md) |
| ~~**Redis 持久化(RDB/AOF) / 主从 / 哨兵 / 集群**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/redis-deep-dive.md`](../tech-stack/redis-deep-dive.md) |
| ~~**MQ 三大问题(可靠性 / 顺序 / 重复)**~~ | ⭐⭐⭐⭐ | ✅ **已补** → [`tech-stack/mq-essentials.md`](../tech-stack/mq-essentials.md) |
| ~~**TCP 三次握手 / 四次挥手 / TIME_WAIT**~~ | ⭐⭐⭐ | ✅ **已补** → [`tech-stack/network-essentials.md` §1](../tech-stack/network-essentials.md) |
| ~~**HTTP/HTTPS / SSL/TLS**~~ | ⭐⭐⭐ | ✅ **已补** → [`tech-stack/network-essentials.md` §2-§3](../tech-stack/network-essentials.md) |
| **MyBatis 一二级缓存 / Plugin 机制** | ⭐⭐⭐ | ❌ 季度内(本工程未覆盖) |
| **分布式 ID(雪花算法)** | ⭐⭐⭐ | ⚠️ 系统设计 §3.6 略提 → [`tech-stack/system-design-primer.md` §3.6](../tech-stack/system-design-primer.md) |
| **Java NIO / Netty 基础** | ⭐⭐⭐ | ❌ 长尾(看你目标公司方向) |

---

## 4. 我对 PDF 的整体评价

### 4.1 ✅ 优点

1. **覆盖广** —— 9 大类几乎全后端必备
2. **实战气重** —— 不是抄书,看得出有真实项目经验做支撑(尤其 ASP knowledge.md 里的内容融入)
3. **分布式事务部分极完整** —— 7 种方案 + 极端故障分析 + 落地场景对照
4. **缓存双写一致性的 4 种顺序分析** —— 这是 PDF 写得最深的章节,值得反复看
5. **数据库优化 17 条 + 索引失效 9 种** —— 直接可背的清单

### 4.2 ⚠️ 缺点

1. **JVM / GC 部分严重不足** —— 这是 P6+ 后端的"生死线",PDF 几乎没展开
2. **并发(JUC / AQS / volatile / synchronized 升级)缺失** —— 大厂必考但 PDF 没覆盖
3. **Spring 进阶(Bean 生命周期 / 循环依赖 / AOP 原理)缺失**
4. **没有索引到自己项目** —— 知识点是孤立的,缺少"我用过这个" 的故事化
5. **PDF 形态不便维护** —— 后面增改困难,**建议转 markdown**

### 4.3 💡 我的具体建议(给你)

**短期(1 个月)**:
1. **挑 PDF 中标 ⭐⭐⭐⭐ 的题**(约 25 题)各准备一段 60 秒应答
2. **每题最后加一句**:"我们项目里这块是 [具体场景]" → 知识 → 实战
3. **补 JVM/GC/并发** 三个核心盲点(可写 `_curated/tech-stack/jvm-and-concurrency.md`,我可以帮你起草)

**中期(3 个月)**:
1. 把 PDF 转 markdown(`file/3-tech_stack/java-study.md`),便于增改 / link / grep
2. 整理 §3 列出的 13 个盲点,逐个补强
3. 用本工程的"知识 + 实战"双轨结构来构建你的"求职复习包"

**长期**:
1. 这份 PDF 是你**职业初期的复习清单**,过 1-2 年应该升级为"**实战决策案例集**"(比如 PI 4.0 重构的决策日志)
2. 简历水平的提升 = 从"我知道 X" → "我做过 X" → "我决策过 X"

---

## 5. 简历视角:这份 PDF 怎么变现

### 5.1 在简历"专业技能"段如何落地

```
【后端】
- Java 8 / 21 LTS,熟悉 HashMap / ArrayList 内部机制、泛型类型擦除、Lambda 函数式编程
- ⭐ 并发:线程池(5 参数 + 4 种内置类型 + CPU/IO 密集型选型)、ThreadLocal 实现原理与
  内存泄漏防范、AQS 基础(进行中)
- 数据库:索引设计(B+树 / change buffer / 索引失效 9 种)、explain 执行计划分析、SQL 优化
  17 条原则、MySQL/Oracle 事务隔离与 MVCC
- 缓存:三级架构(Caffeine + Redis + DB)、缓存三件套(穿透/击穿/雪崩)解决方案、
  双写一致性 4 种顺序对比、集群下本地缓存一致性
- 分布式:Redis 分布式锁(单机 + RedLock)、CAP/BASE 理论、分布式事务 7 种方案
  (2PC / 3PC / TCC / Seata / 本地消息表 / 消息事务 / 最大努力通知)、Spring 事务传播 + 失效场景
- ⚠️ JVM 调优(进行中):内存模型 + GC 收集器选择 + 实战监控(JConsole/VisualVM/MAT)
```

### 5.2 在面试"反问"环节使用

> 反问可以变相**展示知识深度**:
>
> Q (你→面试官): "我注意到贵公司是 XX 业务规模,在 [缓存击穿 / 分布式事务一致性] 上是用什么方案?"
>
> 看似在问对方,实际**展示自己想到了这个层面**。

---

## 6. 待用户决定的事

| # | 决策点 | 我的建议 |
|---|---|---|
| 1 | PDF 是否转 markdown? | ✅ **建议** —— 便于以后增改 + grep |
| 2 | 是否补 JVM/GC/JUC 三个盲点? | ✅ **强烈建议**(P6+ 必考) |
| 3 | 是否单独写"MySQL"知识 summary? | 看目标公司用不用 MySQL,不用就不写 |
| 4 | 是否把 PDF 内容拆到对应主题文件? | **不建议** —— 保留 PDF 作档案,在 `_curated/` 写**精炼指南**就好 |

---

> 📌 **下一步**:
> - 这份 map 是**面试复习的索引** —— 配合 [`career/interview-talking-points.md`](../career/interview-talking-points.md) 一起看
> - 如果你接受我的建议(补 JVM/JUC 盲点),告诉我,我帮你起草
