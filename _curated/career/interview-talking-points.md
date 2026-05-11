# 面试可讲技术点 (Interview Talking Points)

> 这份文档帮你**预测面试官按你简历来问什么**,以及**你应该怎么答**。
>
> **使用方式**:
> 1. 简历投出去之前,把**自己感兴趣** 或**最有素材**的章节先过一遍
> 2. 每个 talking point 都附上"你工程里的具体素材出处",方便你回头看细节
> 3. 答案是骨架不是逐字稿——**你应该用自己的话讲**
>
> **核心原则**:面试官问"你做了什么"时,**你只有 60 秒** 让他听懂这件事的价值。
> 60 秒 = 4 句话 = (背景 + 任务 + 你的关键决策 + 量化结果)。

---

## 0. 通用原则:面试讲技术的 4 个层次

| 层次 | 大概水平 | 例子(以 Hazelcast 升级为例) |
|---|---|---|
| L1 知道 | "用过" | "我们用了 Hazelcast" |
| L2 会用 | 知道 API 和典型场景 | "用 IMap 做缓存,用 ITopic 做集群事件" |
| **L3 知道为什么这么用** | 能讲选型理由 / trade-off | "选 Hazelcast 是因为同时要 IMap + 跨节点 Lock + Quartz 主从协调,Caffeine 只能解决其中一项" |
| **L4 知道什么时候不该用** | 反思 / 局限 / 替代方案 | "其实 SI 单机部署的场景,Hazelcast 集群框架是杀鸡用牛刀;PI 4.0 重构的时候我建议全砍掉" |

**面试官打分**:L1 → 30 分,L2 → 60 分,L3 → 80 分,**L4 → 90+ 分**。
你的素材里**很多 L4 的料**(FerretDB 调研结论、PI 重构里"不要重蹈覆辙"的红线、Hazelcast 滥用反思),
**别讲到 L2 就停**。

---

## 1. 数据库 / 持久化

### 1.1 [面试高频]🎯 "为什么要从 MongoDB 切换到 PostgreSQL?"

**预期问法**:
- "你们为什么不继续用 MongoDB?"
- "FerretDB 不是兼容 MongoDB 协议吗?为什么不继续用?"
- "MongoDB 的 SSPL 协议到底有什么问题?"

**你的回答骨架**:
1. **触发因素**(30 秒): MongoDB 自 2018 年起改用 SSPL,2024 年进一步收紧,**已不被 OSI 认证为开源协议**。作为商业软件分发的 Vertiv 产品,继续用会有合规风险。
2. **替代方案评估**(30 秒): 评估了三条路线 ——
   - Plan A:换成 FerretDB(MongoDB wire 兼容层)→ 我亲自调研发现技术坑深(Windows 编译失败、低版本能力不全)
   - Plan B:用 PostgreSQL JSONB 模拟 MongoDB → 性能差,SI 已经踩过坑
   - Plan C:直接重写为 PG 关系型 schema → 工作量大但根治
3. **决策依据**(30 秒): 选 Plan C 的原因 —— **不只是合规问题,还有架构债**(动态 schema + 文档存储 + 运行时插件三件套限制了产品演进)。FerretDB 是治标不治本。
4. **教训**(30 秒): 这次决策的最大学习是 —— **看清楚是治标还是治本**。Plan A 看似快,但延续了"动态 schema"这个根本包袱;Plan C 看似慢,但是把架构债一次还清。

**素材出处**:
- `_curated/projects/ferretdb-research.md` (我会写)
- `tech-stack/database/ferretdb/ferretdb-no-docker.md`
- (PI 重构文档暂不记载)

### 1.2 [面试高频]🎯 "PostgreSQL 你最熟的特性是什么?"

**预期问法**:
- "你 schema 设计有什么经验?"
- "PG 的分区表 / JSONB / 索引 怎么用?"
- "PG 的事务 / 锁 / MVCC 你了解吗?"

**你的回答骨架**:
1. **挑一个你最熟的子领域,深入讲** —— 不要每个特性都浅浅讲一遍。
2. 推荐挑:**PG 原生 RANGE 分区**(PI 4.0 用来做时序数据存储,raw 30 天 / hourly 5 年 / daily 永久),因为有真实场景:
   - 为什么不用 TimescaleDB?(避免引入第三方扩展依赖)
   - 怎么设计分区策略?(按时间 RANGE,自动 drop 旧分区)
   - 索引怎么建?(分区字段 + 设备 ID 复合索引)
3. **暴露你的边界**:对于 PG 的某些深度特性(比如 GIN 索引内部、WAL 复制),可以坦白"了解但没在生产用过",**不假装**。

**素材出处**:
- `_build/outlines/database/postgresql.outline.md` (775 行,你最近大改)
- (PI 重构 schema 暂不记载)

### 1.3 "MongoDB → PostgreSQL 的数据迁移工具怎么做的?"

**预期问法**:
- "数据量多大?迁移多久?"
- "怎么保证数据一致性?"
- "增量迁移还是全量?"

**你的回答骨架**:
1. **离线 ETL 而不是在线双写**(为什么:不在线双写,因为 PI 4.0 完全推倒重写,模型不一致,双写复杂度爆炸)
2. **Python 工具链分 4 步**:`mongo_analyze`(分析集合) → `mongo_samples`(抽样核对模型) → `mongo_to_pg`(执行迁移) → `verify_migration`(一致性比对)
3. **强制先备份**:迁移前自动 dump 完整 Mongo,出问题可以回到 PI 3.x
4. **数据一致性比对**:行数核对 + 抽样字段值核对 + 业务关键路径(设备 + 告警 + 用户)全量核对
5. **实战教训**:[TODO: 如果你 ETL 跑过,有什么具体踩过的坑?填进来]

**素材出处**:
- (PI 重构 ETL 工具暂不记载)

---

## 2. 平台架构 / mtp-core

### 2.1 [面试高频]🎯 "你们的平台是怎么设计的?有什么亮点?"

**预期问法**:
- "你们的微服务怎么拆?"
- "为什么不用主流框架而是自研?"
- "插件机制怎么实现的?"

**你的回答骨架**(假设面试官问的是 PI 3.x / SI 现状):
1. **平台分三层**:
   - mtp-core:平台核心(Spring Boot + MongoDB + Hazelcast,提供 schema 引擎、插件加载、安全、调度)
   - taf-plugin-*:业务插件(运行时装载 jar,独立 ClassLoader + Spring Context)
   - taf-data-*:设备型号数据包
2. **核心创新点**:**Schema-driven** —— 所有"模型 / 资源"由 JSON Schema 定义,通用 REST 控制器把任意路径的 CRUD 映射到 MongoDB
3. **优势**:配置即开发,新增业务不用写 Controller / Service / Repository
4. **代价**(L4 反思,加分点!):
   - 类型不安全(只能在运行时知道 schema 错没错)
   - IDE 支持薄(JsonNode 满天飞)
   - 调试困难(Stack trace 跳到 Generic 控制器层就懵)
   - 这也是为什么 PI 4.0 要彻底推翻这套机制

**素材出处**:
- [`_curated/projects/mtp-core-framework.md`](../projects/mtp-core-framework.md)(mtp-core 优势 + 缺陷深度分析)
- `_build/outlines/2-projects/vertiv/SI/common/architecture/TAF-CORE.outline.md`

### 2.2 "插件机制是怎么实现的?"

**预期问法**:
- "怎么避免插件之间的类冲突?"
- "插件的生命周期怎么管理?"
- "如果一个插件挂了,会影响其他插件吗?"

**你的回答骨架**:
1. **每个插件独立 ClassLoader + 独立 Spring Context** —— 避免类冲突
2. **生命周期 3 阶段**:`OnPluginInit → OnPluginStart → OnPluginStop`
3. **隔离性**:一个插件抛异常,其他插件继续运行(对应你前面的 plugin failure 监控)
4. **L4 加分**:**这套设计是双刃剑** —— 灵活性高,但调试和热更新带来的复杂度,**不是中小团队能驾驭的**;PI 4.0 重构选择放弃这套机制,改用编译期 Maven 模块 + Spring Boot Starter

**素材出处**:同 §2.1

---

## 3. SNMP / 协议

### 3.1 [面试高频]🎯 "SNMP v1 / v2c / v3 的区别"

**预期问法**:经典基础题,后端面试常考(尤其网络 / 监控 / IoT 方向)。

**你的回答骨架**(可参考你 `SNMP.outline.md` 第 19-32 行):
- **v1**:最初版本,community 字符串认证,只有 GET / GETNEXT / SET / TRAP 4 操作
- **v2c**:兼容 v1,新增 **GET BULK**(批量取大块数据)和 **INFORM**(主动通知 + 接收方需 ACK)
- **v3**:**安全性大幅提升** —— USM(基于用户的安全模型)提供认证 + 加密;VACM(基于视图的访问控制)
- **业界使用**:v1 几乎不用了,v2c 因兼容性广泛存在,v3 是标准推荐

**L4 加分**:**讲一个具体踩过的坑**(从 zero-engine-analysis.md 找一个):
- "我们 SI 在做 trap 解析时,不同厂商的私有 trap 格式不一致(SnmpTrapV2 / GeistPduTrap / LgpEventTrap / UnityTrap),用策略模式把每种 trap 的解析逻辑封装,避免硬编码 if-else"

### 3.2 "MIB 文件你怎么解析的?"

**预期问法**:进阶题,只有真做过 SNMP 设备接入的才会被问。

**你的回答骨架**:
1. **MIB 不是简单文本**:它是 ASN.1 + 自定义关键字,有**模块依赖**(一个 MIB 可能 import 另一个),所以解析需要"模块依赖排序"
2. **技术选型**:三个候选 ——
   - **Mibble**(开源):活跃度低,功能不全
   - **SNMP4J-SMI-PRO**(商业):功能完整,但要付费
   - **自研**:工作量太大
3. **我们选 SNMP4J-SMI-PRO**:综合性价比 + 与已用的 SNMP4J 同生态
4. **实现流程**:多线程并行编译 → 模块依赖排序 → 语法/语义验证 → 持久化或入内存
5. **价值**:新设备 driver 开发耗时从 N 人天 → M 人天

**素材出处**:
- `origin/2-projects/vertiv/SI/experiences/v4.1/resolve-mib/design/resolve-mib.md` (754 行)

### 3.3 "Zero Engine 是怎么做实时采集的?并发量多大?"

**预期问法**:中高级后端,问的是你的并发设计能力。

**你的回答骨架**:
1. **采集模型**:`samplingScheduler` ScheduledExecutorService,默认 1000 线程,按设备分发任务
2. **数据流**:线程池接收任务 → SNMP get 请求 → 缓存到 Caffeine → 数据点变化通知观察者(`datapointService extends Observable`)
3. **告警流**:并行链路 —— 设备 trap → snmp#1.listen → consumer.accept → resolveTrap 解析 → 缓存 → JMS active-alarm topic → 多 SI 消费者
4. **观察者 + JMS 双层**:本地变化用观察者(快、低延迟),跨服务通知用 JMS(异步、解耦、不阻塞主线程)
5. **性能数字**:[TODO: 实际跑了多少 QPS / 多少设备 / 多少数据点]

**L4 加分**:讲**取舍**:为什么不全用 JMS / 为什么不全用观察者?
- 全 JMS:本地变化也走消息中间件,延迟高 + 维护复杂
- 全观察者:跨服务通知做不到
- 双层是合理的折中

**素材出处**:
- `origin/2-projects/vertiv/SI/experiences/v4.0/zero-engine-analysis.md` (基于源码分析)
- `_build/outlines/2-projects/vertiv/SI/common/flow/flow.outline.md` (4 页 256 行)

---

## 4. Java 升级 / 依赖管理

### 4.1 [面试高频]🎯 "Java 8 升 21 / Spring Boot 2 升 3 你怎么做的?"

**预期问法**:有"大版本升级"经验是高级岗位的差异化要求。

**你的回答骨架**:
1. **路径规划**: 不是直接 8 → 21,要考虑是否经过 17(团队评估)
2. **影响面识别**:
   - JRE 自身 unnamed module / sealed class / pattern matching(对反射类库影响)
   - Spring Boot 3:**javax → jakarta** 命名空间迁移(几乎所有依赖要跟版本)
   - Hazelcast 3 → 5:大量包路径变动(`com.hazelcast.core` 拆分到 cluster/map/topic/collection)
   - Spring Security 5 → 6:配置式 API 重写(WebSecurityConfigurerAdapter 已删)
3. **执行策略**:
   - 先升 JRE 单独跑通(不动框架)
   - 再升 SB(全套兼容版本对齐)
   - 最后升外围依赖(Hazelcast / 其他)
   - 每一步独立 PR + 独立验证
4. **回滚预案**:每步都可回滚到上一步
5. **结果**:OWASP 依赖扫描通过,无 HIGH+ 漏洞;启动时间 / 内存占用变化数据

**L4 加分**:讲**反思** —— 升级过程中识别出的"不该用"的东西(比如 SI 单机却用了 Hazelcast 集群),为后续 PI 4.0 重构打下基础。

**素材出处**:
- `origin/2-projects/vertiv/SI/experiences/v4.1/dependency-upgrade.md`
- `_build/outlines/3-business/SI/task/SI 依赖升级.outline.md`

### 4.2 "Hazelcast 你为什么决定砍掉?"

**你的回答骨架**:
1. **Hazelcast 在 PI/SI 的实际用途**:IMap (缓存)、ITopic (集群事件)、IQueue (队列)、Lock (分布式锁)、Quartz 主从协调、HTTP Session 复制
2. **我们的部署形态**:**单机 on-prem**(客户机房单实例)
3. **结论**:**单机不需要分布式中间件**,这些场景都有更轻量的替代:
   - IMap → Caffeine(本地缓存)
   - ITopic → Spring ApplicationEvent(进程内事件)
   - IQueue → LinkedBlockingQueue / Disruptor
   - Lock → ReentrantLock(JDK 自带)
   - Quartz 主从 → @Scheduled(单机不需要主从协调)
   - Session 复制 → Spring Session JDBC 或 in-memory
4. **代价**:Hazelcast 3.12 已 EOL,继续用是安全债 + license 风险
5. **决策**: PI 4.0 全砍

**素材出处**:
- `tech-stack/cache/Hazelcast.md`
- (PI 重构砍掉清单暂不记载)

---

## 5. 设计模式 / 软件设计

### 5.1 "你最近用过哪些设计模式?为什么用?"

**预期问法**:警惕陷阱题——**别背书**。要讲**真实场景**。

**你的回答骨架**(选 1-2 个深入讲,别堆砌):

**Case 1: 策略模式 (Trap 解析)** ✅
- 场景:Zero Engine 收到不同厂商的私有 trap 格式(SnmpTrapV2 / GeistPduTrap / LgpEventTrap / UnityTrap)
- 旧实现:if-else 分支判断 trap 类型 → 内容超长 → 加新厂商要改主流程
- 重构:`TrapResolver` 接口 + 多个实现类 + 工厂方法按类型路由
- 收益:加新 trap 类型只新增一个类,主流程零改动

**Case 2: 观察者模式 (信号变化通知)** ✅
- 场景:设备数据点采集后,需要通知多个下游(缓存 / 推送 / 告警判断)
- 实现:`datapointService extends Observable`,各下游 implements Observer
- 收益:松耦合,新增下游只要加 listener

**Case 3: 模板方法 (升级器)** [可选]
- 场景:`DataUpgraderX_Y_Z` 启动时按 semver 链路执行 schema 替换 + 数据迁移

**反面经验**(L4 加分):
- **mtp-core 的过度抽象**:为了"灵活性"用了大量动态机制(JSON Schema + Generic 控制器 + 运行时插件),最终代价是**调试地狱**和**类型不安全**。**模式不是越多越好,合适才好**。

### 5.2 "怎么理解 SOLID?"

**预期问法**:基础题,但用**真实场景**说明你**理解过**而不是只**听过**。

**你的回答骨架**:
- **单一职责**:`ApiMdGenerator` 原本既生成 JavaModel 又生成 Md 又生成 Json,**违反**;后来用策略模式拆分(GeneratorContext + GeneratorStrategy + 多个具体实现)
- **开闭**:同样这个 case,加新文档类型不用改原代码
- **里氏替换 / 接口隔离 / 依赖倒置**:能讲就讲一两句,讲不出就别勉强

**素材出处**:
- `tech-stack/design_patterns/设计模式相关.xmind` (outline 42 行)
- `tech-stack/design_patterns/策略模式.drawio` (你画的 UML)

---

## 6. 工程能力 / 方法论

### 6.1 "你怎么做技术调研 / 方案设计?"

**预期问法**:架构岗 / 高级开发岗常问。

**你的回答骨架**:
- **以 FerretDB 为例**:
  1. **明确目标**:不使用 docker 的前提下,在 windows / linux 上运行
  2. **理解组件**:FerretDB(Go,协议层) + PostgreSQL(存储) + DocumentDB(C 扩展,JSON 增强)
  3. **梳理可选路线**:Plan A 全改 / Plan B 半改 / Plan C 推倒
  4. **小步验证**:Test 1 跑通基础接入(成功) → Test 2 编译扩展(失败,深度分析根因)
  5. **根因不是表面**:不是"编译失败"而是"Windows 缺乏 POSIX + DLL 地狱 + 工具链碎片化"
  6. **结论与决策**:输出报告,推动 plan C(否定 plan A/B)
- **关键能力**:**不死磕表面问题,挖到根因**;**承认不可行,推动方向纠正**

### 6.2 "你怎么做大版本依赖升级?"

→ 见 §4.1

### 6.3 "你怎么做团队协作 / 跨团队沟通?"

> 你 `pre_action.md` 写"成熟开发者:能与老专家配合默契、懂业务懂沟通",**这是简历软实力**。

**举具体案例**:
- SNMP4J-SMI-PRO 的国外采购流程(跨时区配合)
- PI 重构需要联合 Zero Engine 团队、Trellis Agent 团队、前端团队
- "救火员"角色 [TODO: 你 action.md 里写的 V 型反转的具体 case]

---

## 6.5 中国移动 ASP 项目可讲点  ⭐⭐ [面试高频]🎯

> 2026-05 用户补充了详细素材后新增。详细见 [`../projects/asp-platform.md`](../projects/asp-platform.md) §4 + §5 + §8。
>
> ASP 项目和 Vertiv 项目**互补**:Vertiv 偏架构调研 + 大版本升级,ASP 偏**国企级业务复杂度 + 工程化封装**。

### 6.5.1 ⭐⭐ "为什么不用 ShardingSphere?"

**预期问法**:
- "你们这么多表怎么分库?"
- "怎么没用主流的分库分表中间件?"

**回答骨架**(60 秒):
1. **场景特殊**:不是纯垂直/水平拆分,是"**先整合再分库**" —— CRM/BRM 两套系统的上千张表先做模型整合再划分到 4 个中心
2. **配置爆炸**:每个存量应用都要单独配 ShardingSphere → 上线变更难统一管理
3. **能力不足**:大量多表关联 / 跨库 join / 分页排序 —— ShardingSphere 不能完美支持
4. **替代方案 = dbproxy**:在 Druid 处做代理层,自定义 DataSource,SQL 解析后查"中心字典"路由到目标库,**集成到应用内,零运维成本**

**L4 加分**:**"看清楚是治标还是治本"** —— ShardingSphere 是通用方案但不一定是好方案,具体场景要看数据规模、应用形态、变更成本。

### 6.5.2 ⭐⭐⭐ "你做过哪些 Spring 框架级的工程化封装?"

> 这是简历"框架使用者 → 框架建造者"的关键证据。

**素材**:**@RedisLock 注解 + AOP + Auto Configuration**

**回答骨架**:
1. **背景**:多微服务都需要分布式锁,各团队独立实现导致重复 + 实现质量参差不齐
2. **设计**:
   - `@RedisLock` 自定义注解(prefixKey / SpEL key / 等待时间)
   - `RedisLockAspect @Aspect` 环绕通知:解析 SpEL → tryLock → finally unlock
   - `RedisLockAutoConfiguration @Configuration` + spring.factories 自动装配
   - 公共 slib jar → 其他微服务**加依赖即可用**
3. **⭐ 关键决策**:`@Order(HIGHEST_PRECEDENCE)`
4. **结果**:N 个微服务复用,消除 X 行重复代码

**L4 反问钩子**:面试官 90% 会接着问 6.5.3 → 你顺势讲。

### 6.5.3 ⭐⭐⭐⭐ "为什么 @RedisLock 切面要 HIGHEST_PRECEDENCE?"

> 这是 **P7+ 级面试题** —— 答出来直接拉开和普通候选人的差距。

**4 条递进**:
1. **职责不同**:分布式锁是为了"多实例并发互斥",事务是为了"单实例原子性" → 这两件事是**正交的**,不能混
2. **加锁要在事务前**:**先获取锁,再开启事务**,这样事务执行期间锁始终持有
3. **释放锁要在事务后**:无论事务提交还是回滚,**锁都要等事务结束才释放** —— 否则:
   - 事务回滚 → 锁先释放 → 另一个线程拿锁 → 读到回滚前的脏数据 → 死锁或数据错乱
4. **AOP 顺序不指定就是不确定的**:Spring AOP 不显式 `@Order` 的多个切面执行顺序是**随机的** → **必须显式 HIGHEST_PRECEDENCE 让锁切面在事务切面外**

**素材出处**:`origin/2-projects/asp/knowledge.md` §RedisLockAspect / `_curated/projects/asp-platform.md` §4.4.1

### 6.5.4 ⭐ "HttpServletRequest body 重读问题"

**问法**:"网关或 Filter 链里 body 读不到怎么办?"

**回答**:
1. **根因**:HttpServletRequest 的 InputStream **只能读一次**(默认 ServletInputStream 不支持 reset)
2. **场景**:Filter A 读了 body 做鉴权 → DispatcherServlet 再读不到 → `@RequestBody` 抛 "required request body is missing"
3. **解决**:`CachedBodyHttpServletRequestWrapper extends HttpServletRequestWrapper`
   - 构造时一次性读完 body 缓存到 `byte[]`
   - 重写 `getInputStream()` / `getReader()` 返回基于缓存的新 InputStream
4. **挂载**:在 Filter 链最前 wrap 原始 request,后续所有人拿到的都是 Wrapper

**L4 加分**:**线上调试时为什么常常排查不出来** —— 因为问题往往是"加了一个不起眼的 LogFilter"导致的;**Filter 链改动后必须验证 body 重读**。

### 6.5.5 ⭐⭐ "缓存一致性怎么解决?"(可对照 PDF p.56-58)

ASP 项目有**两层架构**:Caffeine 本地缓存(1 分钟 TTL) + Redis 远程缓存。

**回答 4 种顺序的对比**:

| 方案 | 高并发问题 | 适用 |
|---|---|---|
| 先写 DB 再写缓存 | 网络抖动可能写缓存失败 → 缓存脏 | 低并发 + 同事务 |
| 先写缓存再写 DB | DB 写失败缓存脏(最严重) | ❌ 不推荐 |
| 先删缓存再写 DB | 高并发下读线程可能写回旧值 | 加缓存双删 |
| **先写 DB 再删缓存** ✅ | **少数极端情况会脏,概率小** | **ASP 选用** |

**ASP 还做了**:cache-cli + cache-server 工具(@ShellComponent)+ Redis pub/sub `convertAndSend(UPDATE_INFO_CHANNEL)` 通知所有节点本地缓存失效。

### 6.5.6 ⭐ "PortalReqContext + ThreadLocal 怎么设计的?"

ASP 网关 4 个 Filter 链(AuthFilter / OperatorAuthFilter / FrequentAccessFilter / ApiAuthZuulFilter)用 ThreadLocal 传递操作员上下文。

**面试可讲点**:
- 为什么用 ThreadLocal 不用方法参数 → 跨多个组件 / 跨方法调用栈
- ThreadLocal 内存泄漏 → 在 Filter 末尾 `remove()` 释放
- InheritableThreadLocal vs 普通 → 异步线程池场景的传递问题

### 6.5.7 ⭐ "国企特色的安全实践 —— 二次登录"

ASP 项目的"数据库密码不明文"方案:
1. 配置文件只放"logon 账户"(只有读取存储过程权限)
2. Druid `getConnection` 拦截 → logon 账户连库 → 执行 `AP_GETDBUSERANDPASS` 存储过程 → 解密得到真密码 → 重新连业务库

**L4 加分**:**这是国企/金融特有的安全合规模式** —— 在外企面试可作为"我做过严格安全合规场景"的差异化亮点。

### 6.5.8 ⭐ "Arthas 你会用吗?"

ASP knowledge.md 给出了**真用过**的命令:

```bash
sc -d com.alibaba.druid.filter.stat.StatFilter
ognl -c <classloader_hashcode> '@SpringUtil@getBean("statFilter").slowSqlMills=0'
```

**L4 加分**:讲一个具体故事 —— "线上 X 接口慢,通过 Arthas `ognl` 修改运行时阈值动态观察,不用重启就解决了问题"。

---

## 6.6 Java 通用知识可讲点(基于 `Java Study.pdf`)

> 详细索引 → [`../tech-stack/java-knowledge-map.md`](../tech-stack/java-knowledge-map.md)
>
> 这里只列**最高频** + **本工程能给故事化**的几道题:

### 6.6.1 ⭐⭐⭐⭐ HashMap

**预期问法**:扩容 / 红黑树 / 1.7 头插 vs 1.8 尾插 / 并发问题

**素材出处**:Java Study.pdf p.8 + 你工程内任何 HashMap 用法

### 6.6.2 ⭐⭐⭐⭐ ThreadLocal

**预期问法**:实现原理 / 内存泄漏 / InheritableThreadLocal / 弱引用

**素材出处**:PDF p.51-53 + ASP 网关 PortalReqContext 实战

### 6.6.3 ⭐⭐⭐⭐ 线程池

**预期问法**:5 参数 / 4 种内置 / CPU vs IO 密集型 / 拒绝策略 / 动态线程池

**素材出处**:PDF p.45-50 + SI Zero Engine `samplingScheduler`(1000 线程)实战

### 6.6.4 ⭐⭐⭐⭐ 数据库索引(B+树 / change buffer / 失效 9 种 / explain)

**素材出处**:PDF p.26-33 + ASP 项目 SQL 优化实战(knowledge.md §6.2)

### 6.6.5 ⭐⭐⭐⭐ 缓存三件套(穿透 / 击穿 / 雪崩)

**素材出处**:PDF p.54-55 + ASP cache-cli + SI Zero Engine 设备点缓存

### 6.6.6 ⭐⭐⭐⭐ 分布式事务(7 种方案对比)

**预期问法**:CAP / BASE / 2PC / 3PC / TCC / Seata / 本地消息表 / 消息事务 / 最大努力通知

**素材出处**:PDF p.65-87(**写得最完整**)+ ASP DAM XA 实战

### 6.6.7 ⭐⭐⭐⭐ Spring 事务(传播级别 + 失效场景)

**预期问法**:7 种传播级别 / 9 种失效场景 / @Transactional AOP 底层

**素材出处**:PDF p.88-91 + ASP @RedisLock 与事务的协作设计

> ⚠️ **PDF 严重盲点**(强烈建议补):**JVM / GC / JUC(AQS / volatile / synchronized 升级)** —— 详见 [`../tech-stack/java-knowledge-map.md` §3](../tech-stack/java-knowledge-map.md#3-pdf-的盲点我建议你补的)。

---

## 7. 软实力 / 行为面试

### 7.1 "你最近一次解决最复杂问题的经历?"

**素材推荐**:**FerretDB 调研** 或 **Hazelcast 3→5 升级**(都很有讲法)

### 7.2 "你最近一次失败 / 学到最多的经历?"

**素材推荐**:你 `action.md` 里的 V 型反转复盘(从触底到反弹的过程)

### 7.3 "你下一步想发展什么方向?"

**素材推荐**:你 `action.md` 里写的"短期 / 长期规划";结合 PI 4.0 重构的经历,表达你想**从开发往架构 / 平台化方向走**

### 7.4 "为什么离开 Vertiv?"(如果你在投简历)

> 这题陷阱多。**不要骂前公司、不要讲负面、不要讲薪资**。
>
> 推荐角度(选其一,看你真实想法):
> - 想在 PI 4.0 重构这种项目里,**承担更主导的角色**(而不是仅作为方案设计者)
> - 想去**业务复杂度更高 / 用户规模更大** 的场景验证学到的方法论
> - 想去**更现代的技术栈生态**(比如云原生、大数据、AI 基础设施)继续成长

---

## 8. 你应该**主动**抛给面试官的问题(反问环节)

> 反问环节是你**判断对方公司是否值得去**的关键 5 分钟。提前准备 3-5 个高质量问题。

候选(根据你的特点筛选):

- **架构 / 技术债**: "团队当前最大的技术债是什么?"
- **决策机制**: "你们的架构决策是怎么做的?有 ADR 流程吗?"
- **工程文化**: "Code Review 是必须的吗?平均一个 PR 会有几轮 review?"
- **测试**: "团队的单元测试 / 集成测试覆盖率大概是?"
- **学习**: "团队有哪些学习 / 分享机制?"
- **个人发展**: "进来后 3-6 个月,你期望我做出什么具体成果?"
- **真实痛点**: "你最近一次熬夜加班是为了解决什么问题?"

---

## 9. 面试前的准备清单

| 检查项 | 状态 |
|---|---|
| 是否能用 60 秒讲清楚 PI 4.0 重构? | ⬜ |
| 是否能用 60 秒讲清楚 Zero Engine 信号采集流? | ⬜ |
| 是否能用 60 秒讲清楚 Hazelcast 3→5 升级踩的坑? | ⬜ |
| 是否能讲清楚 FerretDB 三个方案的取舍? | ⬜ |
| 是否准备好了 3 个**反问** 问题? | ⬜ |
| 是否查过对方公司 / 业务 / 主要技术栈? | ⬜ |
| 是否找朋友 mock 一遍? | ⬜ |

---

> **下一步**:
> - 个人复盘 + L 给的反馈 → [`growth-and-feedback.md`](./growth-and-feedback.md)
> - 第二年谈话提炼(调薪 / 培养方向 / 今年行动清单)→ [`talking-2026-leader-feedback.md`](./talking-2026-leader-feedback.md)
