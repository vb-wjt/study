# 简历项目段 (Resume Projects)

> 这份文档把你工程里所有**素材**翻译成**可以直接复制粘贴到简历里的项目段**。
>
> **使用方式**:
> 1. 看一遍每段,如果某段适合你目标岗位,**整段复制**到简历里
> 2. **`[TODO: ...]`** 占位是我手上没有的具体数字 / 名词,你填一下
> 3. 不喜欢某段措辞,直接改;你的最终简历你说了算
>
> **重要警告**:
> - 我用了**STAR 法则**(Situation / Task / Action / Result)的隐形结构,不要破坏这个节奏
> - 我**用过去时**写,因为简历项目都是已发生
> - 我**先讲业务价值再讲技术**,因为面试官第一句通常问"这做了什么"
> - 我倾向**主动语态 + 量化数字**,这是简历最大的优化方向

---

## ⚠️ 你需要先告诉我的

为了让这份文档真正能用,请[在 `meta/still-missing.md` §5](../meta/still-missing.md#5-简历语言版的输入-必须) 回答:

1. 目标岗位级别(P5/P6/P7 / 中级 / 高级 / 资深)
2. 目标公司类型(国内大厂 / 外企 / 创业公司 / 出海)
3. 不想被问到的问题
4. 你的优势侧重(代码 / 设计 / 业务 / 沟通 哪个最强)

**当前默认假设**:你目标是**中高级 Java 后端 / 后端架构方向**,投递**外企或重视架构的国内厂**。

---

## 1. Vertiv (维谛) · 数据机房基础设施监控平台 [简历亮点]⭐⭐ [就绪]

> **2024.07 - 至今 · Java 后端开发(后期承担架构与重构主导)**
>
> 这是你简历的**核心拼图**,内含 4 个独立可写的子项目。建议简历里**主项目段写概览**(§1.0),**详细子段挑 2-3 个**(优先 §1.4 PI 4.0 重构 + §1.1 Zero Engine + §1.3 依赖升级)。

### 1.0 项目主段(简历主标题用)

```
【项目名称】Vertiv Smart InfraSight (SI) + Power Insight (PI) 数据机房监控平台
【在职时间】2024.07 - 至今
【项目角色】Java 后端开发工程师 → 后端骨干(承担依赖大版本升级、PI 4.0 重构主导分析)
【项目规模】[TODO: 团队人数,如"后端 N 人 / 前端 M 人"]、[TODO: 服务客户数 or 设备规模]
【项目背景】
SI/PI 是 Vertiv 面向边缘机房、中小机房和分布式机房场景的新一代基础设施融合管理产品。
SI 由全新自研团队负责,采用 Spring Boot + Hazelcast + MongoDB 的技术栈,核心在于支持 SNMP/Modbus
等多协议的设备接入与实时监控;PI 则是历史悠久的产品,正面临 MongoDB 协议变更带来的合规风险与
技术栈整体老化(Spring Boot 2.6 / Java 8 / Hazelcast 3.12),需要全面重构。

【主要职责】
- 主导参与 SI 多个版本的核心模块开发(设备发现、信号采集告警流、MIB 解析、依赖大版本升级)
- 主导 PI 4.0 重构的全栈技术调研与方案设计(MongoDB→PostgreSQL、Hazelcast→单机化、SB2→SB3+Java21)
- 推动并完成内部工具 Driver Hub 的设计与开发,提升驱动开发效率
- 编写自动化数据迁移工具(Mongo → Postgres ETL),覆盖 [TODO: N 个真实客户数据集]
```

> **写作 tip**:简历主段不要超过 5 行,**让面试官想多问**。所有细节留到下面子段或面试时讲。

### 1.1 SI 4.0 · Zero Engine 信号采集与告警流  [简历亮点]⭐ [面试高频]🎯

```
【模块】Zero Engine 实时信号采集 + 告警流
【背景】SI 4.0 之前的产品仅支持 RDU 监控,不支持主流 SNMP 设备;同时公司既有的 C++ 采集层
       (IE Engine)是其他团队维护、SI 团队不可控,故新建独立的 Java 采集层服务 Zero Engine。
【贡献】
- 设计并实现了基于 SNMP4J 的设备发现机制,支持单 IP / IP 段批量扫描,内含异步线程池调度
  与去重去抖逻辑,扫描 [TODO: N] 个 IP 段的设备发现耗时从 [TODO: 旧 ms] → [TODO: 新 ms]
- 实现了基于观察者模式的信号采集→缓存→变化通知数据流(SNMP 实时拉取 → Caffeine 本地缓存 →
  ApplicationEvent 通知 → ActiveMQ 跨服务推送),支撑 [TODO: N] 个数据点 / 分钟的写入吞吐
- 用策略模式封装了 SNMP v1/v2c/v3 trap 的解析(SnmpTrapV2 / GeistPduTrap / LgpEventTrap /
  UnityTrap 等多个厂商私有 trap 类型),消除了硬编码 if-else 的维护负担
- 设计了告警的"采集层 → JMS Active-Alarm Topic → SI 多消费者"分布式订阅推送链路,
  消费端用 @JmsListener 异步消费 + 从 Caffeine 缓存中获取上层系统列表(默认 10 个 / 300s 过期)
【成果】
- Zero Engine 作为 SI 4.0 的核心采集层成功上线,支持 [TODO: 已接入设备型号数] 种 SNMP 设备
- 自此团队对采集层完全可控,后续告警规则、采集模板的迭代不再受跨团队协作阻塞
```

> 文档支撑:`origin/2-projects/vertiv/SI/experiences/v4.0/zero-engine-analysis.md` (基于源码分析) +
> `_build/outlines/.../flow.outline.md` (256 行)

### 1.2 SI 4.0 · SNMP 设备发现  [简历亮点]⭐

```
【模块】SNMP 设备发现服务
【背景】SI 4.0 需要支持用户输入 IP 段后,自动发现网络中所有可被监控的 SNMP 设备(UPS / PDU /
       服务器 / 交换机等),并自动匹配设备型号驱动。
【贡献】
- 实现了基于 SNMP4J + Apache Commons Net 的网络段扫描(支持 IPv4 单 IP / CIDR / 范围)
- 设计了"先广播探测再深度采集"的两阶段发现流程:第一阶段用 SNMP GET sysObjectID 快速判活,
  第二阶段对存活 IP 异步并行采集 sysDescr / sysName / sysLocation 等基础元信息
- 引入线程池 + 信号量限流,避免对客户网络造成 [TODO: 多少 PPS 上限] 的扫描压力
- 实现了"设备型号 OID → 驱动包"的自动匹配逻辑,新增设备时无需手动选择型号
【成果】
- 设备发现的端到端耗时较 [TODO: 旧方案 / 行业基线] 减少 [TODO: 数字]%
- 支持 [TODO: N] 种厂商的设备型号自动识别
```

> 文档支撑:`origin/2-projects/vertiv/SI/experiences/v4.0/discovery.md` (2401 行)

### 1.3 SI 4.1 · 大版本依赖升级 [简历亮点]⭐⭐ [面试高频]🎯

```
【模块】Java / Spring Boot / Hazelcast 大版本升级
【背景】SI 早期采用 Java 8 + Spring Boot 2.7.8 + Hazelcast 3.12.13 + MySQL,这些组件均存在
       严重的 EOL 安全风险(Spring Boot 2.x 已 EOL,Hazelcast 3.x 已停止维护)。同时为了与
       公司平台的统一升级路线对齐,需要在保持业务零中断的前提下,将技术栈整体升级。
【贡献】
- 主导规划了升级路径:JRE 8 → JRE 21 / Spring Boot 2.7.8 → 3.5.5 /
  Hazelcast 3.12.13 → 5.6.0 / MySQL → SQLite,并产出了完整的影响范围分析与回滚方案
- 攻克 Hazelcast 3 → 5 的 [TODO: 多少处] API 包路径变动(Member / IMap / ITopic 等多个核心类
  从 com.hazelcast.core 拆分到 com.hazelcast.cluster / map / topic / collection 等子包),
  通过精心设计的 sed/AST 替换脚本批量改造,避免逐文件人工修改
- 处理了 Spring Boot 3 的 javax → jakarta 命名空间迁移、Spring Security 6 配置式 API 重写、
  以及 Java 21 引入的 unnamed module / sealed class 兼容性问题
- 重新审视了 Hazelcast 在 SI 中的实际使用场景,**识别出大量"杀鸡用牛刀"的滥用**(单机也起
  了集群框架),为后续可能的 Hazelcast 替换打下基础
【成果】
- SI 4.1 成功上线,所有依赖通过 OWASP 依赖扫描,无 HIGH+ 安全漏洞
- 升级后服务启动时间 [TODO: 提升 N%]、内存占用 [TODO: 下降 N%]
- 形成了"大版本依赖升级 SOP",为同公司其他产品(如后续 PI 4.0)提供了路线参考
```

> 文档支撑:`origin/2-projects/vertiv/SI/experiences/v4.1/dependency-upgrade.md` (352 行) +
> `_build/outlines/.../SI 依赖升级.outline.md` (444 行)

### 1.4 SI 4.1 · MIB 解析(SNMP4J-SMI-PRO 引入) [简历亮点]⭐

```
【模块】MIB 文件解析与 OID 数据库构建
【背景】SI 需要支持新设备型号时,管理员上传该设备的 MIB 文件,系统自动解析出所有
       OID / 数据类型 / 描述,并生成可被采集层使用的元数据。原方案缺失,导致每个新设备型号
       都需要驱动开发人员手动维护 OID 列表,效率极低且易错。
【贡献】
- 完成了 MIB 解析方案的技术选型:对比 Mibble (开源) / Snmp4j-SMI-PRO (商业) / 自研三个方案,
  从功能完备性、license 兼容性、维护活跃度、性能等维度产出技术对比报告
- 推动了 SNMP4J-SMI-PRO 的国外采购流程([TODO: 跨团队 / 跨时区配合细节])
- 设计了 MIB 文件批量解析流程:多线程编译 → 模块依赖排序 → 语法/语义验证 → 持久化或入内存
- 实现了"MIB OID → 业务字段"的双向映射,支持 OID 解析时按表索引解码、按字段名快捷查找
- 输出了完整的设计文档,包括 SmiManager 核心处理类的职责边界与扩展点
【成果】
- 新设备型号的 driver 开发耗时从 [TODO: N 人天] → [TODO: M 人天]
- 已支持 [TODO: N] 种 MIB 模块的解析,覆盖主流 UPS / PDU / 服务器型号
```

> 文档支撑:`origin/2-projects/vertiv/SI/experiences/v4.1/resolve-mib/design/resolve-mib.md` (754 行) +
> `_build/outlines/.../snmp-smi-pro.outline.md`

### 1.5 SI 4.0.1 · MongoDB → FerretDB 切换调研  [简历亮点]⭐⭐ [面试高频]🎯

```
【模块】MongoDB 开源协议风险应对(FerretDB 可行性调研)
【背景】MongoDB 自 2018 起改用 SSPL 协议(已不再视为 OSI 认证开源),作为商业软件分发的 SI/PI
       面临严重的合规风险。FerretDB 是基于 PostgreSQL + Microsoft DocumentDB 扩展的 MongoDB
       wire protocol 兼容层,被视为最有潜力的开源替代方案,需要完整调研其落地可行性。
【贡献】
- 在 Windows 原生环境(无 Docker)下完成 FerretDB v2.7 的源码编译(Go 工具链)和接入验证,
  成功通过 mtpuser 账户连接已有 PostgreSQL 实例
- 对 Microsoft DocumentDB(C 编写的 PostgreSQL 扩展)在 Windows 下的编译进行了深度排查,
  系统性分析了 Visual Studio 工具链 / CMake / "DLL 地狱" / Windows NT 与 Unix POSIX 内核差异
  等问题,得出"Windows 原生编译该类系统级 C 组件不具备工程可持续性"的结论
- 验证了低版本 FerretDB v1.24(不依赖 DocumentDB)的可行性,发现因索引能力不全(缺
  partialFilterExpression)、协议消息体大小限制(48MB)等问题,**否定**了该路线
- 输出了完整的技术调研报告,推动团队最终决策为 **plan C(基于 AI 工具分析,推倒重写为
  PostgreSQL 关系型方案)**,即后续的 PI 4.0 重构方向
【成果】
- 排除了不稳定的 Windows 原生 + FerretDB 部署方案,为团队规避了潜在的运行时兼容性风险
  与高昂的长期维护成本
- 调研结论直接指导了 PI 4.0 重构的技术路线决策(放弃 MongoDB 兼容层,直接迁移到 PostgreSQL)
```

> 文档支撑:`tech-stack/database/ferretdb/ferretdb-no-docker.md` (241 行) +
> `tech-stack/database/ferretdb/resume-snippet.md` (你之前已经写好的简历语言版,2026-05-08 已归位)

### 1.6 内部工具 · Driver Hub  [简历亮点]⭐

```
【模块】Driver Hub —— 设备驱动开发与调试工具
【背景】Vertiv 设备型号众多(UPS / PDU / 服务器),每个新设备型号都需要驱动开发人员手动
       配置 OID 表、SNMP 类型、信号采集逻辑,过程繁琐且容易出错。缺少统一的开发与调试工具
       导致驱动开发效率低、bug 多。
【贡献】
- 设计并实现了 Driver Hub 内部工具,集成 MIB 解析 / SNMP4J walk / SNMP4J trap receiver /
  驱动包导入导出等核心能力
- 提供 GUI 操作界面,允许驱动开发人员一键导入 MIB → 选择 OID → 测试 SNMP get/walk → 模拟
  trap → 导出驱动包
- 与 SI 主程序的驱动加载机制对接,确保 Driver Hub 导出的包可在 SI 上无缝加载
【成果】
- 驱动开发的端到端耗时减少 [TODO: N%]
- 团队 [TODO: N] 名驱动开发人员日常使用,被认可为标杆内部工具
```

> 文档支撑:`origin/2-projects/vertiv/Tool/DriverHub.md` (素材较少,需补充展开)

---

## 2. 中国移动 · 全业务支撑平台 (CHBN/ASP)  [简历亮点]⭐⭐ [面试高频]🎯 [就绪]

> **2022.07 - 2024.03(1 年 8 个月)· Java 后端开发**
>
> 2026-05 用户补充了 `origin/2-projects/asp/project.md` (87 行) + `knowledge.md` (570 行) 两份密集材料,
> 详细技术提炼见 [`_curated/projects/asp-platform.md`](../projects/asp-platform.md)。
>
> 下面是简历可直接复制的**精简版**(挑了最有讲法的 4 个模块);你可以根据目标岗位**裁剪**(投架构岗
> 强化 dbproxy + 微服务化;投业务岗强化整合 + 追平需求)。

### 2.0 项目主段(简历主标题用)

```
【项目名称】中国移动 · 全业务支撑平台 (CHBN/ASP)—— CRM+BRM 融合
【在职时间】2022.07 - 2024.03
【项目角色】Java 后端开发(后期承担骨干 / 子模块负责)
【项目规模】[TODO: 团队人数] / 服务于中国移动广东省 [TODO: 用户/客户规模]
【项目背景】
中国移动 CRM(客户)和 BRM(计费)两套系统跨系统办理流程繁琐、双系统数据维护成本高,
项目目标:整合数据 + 业务,构建面向"个人/家庭/政府/企业"的一站式融合销售统一门户。

【主要职责】
- 主导 / 参与多个核心模块:数据整合(拆库)/ SQL 解耦(dbproxy)/ 订单中心微服务化 /
  产品迁移(BRM/CRM → 新平台)/ 与外围平台(能运/DICT/集客大厅/电渠/BBOSS)对接
- 抽象与封装公司级 slib(@RedisLock 注解 + AOP + Auto Configuration),被多个微服务复用
- 解决经典工程坑(HttpServletRequest body 重读、@ComponentScan slib bean 重复等)
```

> **写作 tip**:简历主段不超过 5 行,详细子段挑 2-3 个进**面试材料库**。

### 2.1 ⭐⭐ 数据整合(拆库)+ SQL 解耦(dbproxy)  [面试高频]🎯

```
【模块】CRM/BRM 数据整合 + 跨中心 SQL 路由
【背景】CRM 和 BRM 合计上千张表,需按业务划分到 4 大中心(订单/客户/产商品/公共能力)。
       拆库后存量 Spring 应用里大量 SQL 是跨中心的,直接不可执行。
【贡献】
- 完成数据库表的差异化融合 + 业务归属划分,产出 4 个中心的表模型
- ⭐ 评估并放弃 ShardingSphere 方案,基于"先整合再分库 / 上千表 / 多表关联跨库"的实际
  约束,选择自研轻量代理:
  - dbproxy 在 Druid 处做代理,自定义 DataSource
  - 处理流程:解析 SQL 表名 → 字典查中心 → 配置查中心地址 → 远程发 SQL → 拿结果返回
  - 集成在存量应用内(不是独立中间件),零运维额外成本
- 旧数据下沉到新数据库;新增数据用定时任务同步(原计划 DataX/Canal 因数据量受限,
  采用替代方案 [TODO: 实际方案])
【成果】
- 解决了 [TODO: N+ 张表 / N+ 个存量应用] 的跨库 SQL 兼容问题
- dbproxy 方案被作为 [TODO: 部门/项目群] 内的标准 SQL 解耦实现
```

> 文档支撑:`origin/2-projects/asp/project.md` §2 + `knowledge.md` §SQL → 提炼见 `projects/asp-platform.md` §2.1-§2.2

### 2.2 ⭐ 订单中心微服务化  [面试高频]🎯

```
【模块】订单可视化 + 订单中心 5 微服务
【背景】BRM 业务以"产品订购"为核心,需要在新平台支持完整订购全流程并提供环节可视化。
【贡献】
- 设计并实现订单中心的 5 个微服务架构:
  - orderentry:订单处理(下单/审批/签章/合同打印/补录/商务验收)
  - orderquery:订单查询    - ordermanage:订单管理
  - shopmgr:购物车         - orderProv:省订单中心(对接省公司)
- 用 BPMX(基于 Activiti)做流程编排,适配不同产品的差异化订购流程
- 联动脚本从 uee 重构为 formily(表单引擎),迁移产品属性配置
【成果】
- 订单中心微服务集群成功上线,支撑 [TODO: 量化:QPS / 日均订单数]
- 完成 [TODO: N 个] 主流产品的迁移与上线
```

### 2.3 ⭐⭐⭐ 公共能力封装 · @RedisLock 注解 + AOP  [面试高频]🎯

> ⭐ 这是 P6+ 面试官**最爱听**的素材:**框架使用者 → 框架建造者**的典型证据。

```
【模块】Redis 分布式锁 slib 公共组件
【背景】公司多微服务都需要分布式锁,各团队独立实现导致重复代码 + 实现质量参差不齐。
【贡献】
- 设计 @RedisLock 自定义注解,支持 prefixKey / SpringEL key / 等待时间 / 是否抛异常等参数
- 实现 RedisLockAspect 切面,基于 Spring AOP,环绕通知中:
  解析 SpEL → 计算锁 key → tryLock → 业务逻辑 → finally 解锁
- ⭐ 切面 @Order(Ordered.HIGHEST_PRECEDENCE)—— 确保锁切面比事务切面先执行,实现:
  ① 锁在事务外(锁是为了多实例并发,事务是为了单实例原子) ② 先加锁后开事务,
  事务回滚时锁仍正确释放(避免死锁)
- 通过 spring.factories + RedisLockAutoConfiguration 实现 Spring Boot 自动装配,
  其他微服务"加依赖即可用"
【成果】
- @RedisLock 被 [TODO: N 个] 微服务复用,消除 [TODO: 估算] 行重复代码
- 在 sprint 评审中被推广为团队的最佳实践
```

> 文档支撑:`origin/2-projects/asp/knowledge.md` §RedisLock 完整代码(150 行)

### 2.4 [可选,看篇幅] 复杂业务流 · 成员下发全流程  [简历亮点]⭐

```
【模块】成员下发任务的全流程(实时接口 + 定时任务 + 后台进程 + 文件接口 + 外围平台联动)
【背景】省公司下发成员变更需求,涉及多个外围平台(BBOSS / 能运 / DICT)和多种集成方式
       (实时接口 / 文件 SFTP / 异步定时),逻辑复杂、难调试。
【贡献】
- 梳理并落地完整流程:省公司下发 → 网关 → jbusiness 入任务表 → 后台进程处理 → 生成订单 →
  存量 BRM 定时任务扫表 → 生成 SFTP 文件 → 外围平台反馈文件 → 文件入站定时任务 → 状态机更新 →
  后台进程恢复 → 同步到省库 → 历史表归档
- 排查并解决 SFTP 算法协商失败(国密/标准算法适配)、@RequestBody 取不到 body
  (HttpServletRequestWrapper 缓存)等典型问题
【成果】
- 成员下发流程稳定上线,日均处理 [TODO: N] 笔
- 形成"复杂跨系统业务流"的标准排查 SOP
```

> 文档支撑:`knowledge.md` §复杂业务

### 2.5 当前**待你确认**的细节(填了简历能更有冲击力)

| # | 待补 | 用途 |
|---|---|---|
| 1 | 你的具体子模块负责度(主导 / 参与 / 修复) | §2.0-§2.4 角色描述 |
| 2 | 服务的用户数 / 订单数 / QPS 等量化数据 | §2.0 / §2.2 |
| 3 | dbproxy 实际处理的 SQL 量 / 表数 | §2.1 |
| 4 | "存量数据没整成"的最终方案(用户在 project.md 标了"存疑?") | §2.1 |
| 5 | "救火员"具体案例(L 第二年聚餐反馈) | §5 软实力 |

---

## 3. 校内搜搜 (实习) [待开始]

> 你写了"todo"。如果是大学实习,可以**简化**或**删除**(中国移动 + Vertiv 已 4 年经验,实习占位价值有限)。
>
> 如果保留,**建议格式**:
>
> ```
> 【公司·项目】校内搜搜 · [TODO: 做什么的]
> 【在职时间】[TODO: 几月-几月] (实习)
> 【贡献】[TODO: 1-2 句最有亮点的事]
> ```

---

## 4. 技术栈一句话总结(简历末尾用)

> 简历末尾的"专业技能"段可以参考:

```
【后端】
- 语言:Java (8 / 21 LTS,熟悉 record / sealed / pattern matching)
- 框架:Spring Boot 2.x / 3.x、Spring Security 5/6、Spring MVC、MyBatis-Plus、JOOQ、Hazelcast 3/5
- 服务器:Undertow、Tomcat;消息中间件:ActiveMQ、Caffeine
- 数据库:PostgreSQL 16(分区 / 索引 / Flyway 迁移)、MongoDB、MySQL、SQLite
- 协议:SNMP v1/v2c/v3 (snmp4j)、SOAP、REST、WebSocket、JMS

【架构与方法】
- 设计模式:策略 / 观察者 / 模板方法等(实战使用,非死记硬背)
- 性能优化:索引设计、缓存层级(Caffeine + Hazelcast)、异步线程池调优
- 大版本升级:Java 8→21 / Spring Boot 2→3 / Hazelcast 3→5 实战经验
- 重构方法论:基于源码反向工程 + 业务需求基线 + 风险/未决项识别的完整重构流程

【运维与基础】
- Linux (基本命令、文件系统、权限) [TODO: 补充实战]
- Maven 多模块、Git workflow、Code Review
- Docker [TODO: 看你 ferretdb 调研提到了,但日常工作用得多吗?用得多就写,少就别写]

【其他】
- 跨团队协作(SI / PI / Zero Engine 团队 + 国外采购流程 + 跨时区配合)
- 技术调研与方案设计(FerretDB Windows 可行性 / PI 4.0 重构方案,均产出 200+ 行决策文档)
- 中英双语技术写作 [TODO: 你 Vertiv 是外企,确认一下日常 doc / commit 是英文还是中文]
```

---

## 5. 软实力(简历末尾"个人评价"或求职信用)

基于你 `action.md` / `pre_action.md` / `talking.md`(2026 春节后第二年谈话)的复盘:

```
- 在 Vertiv 近 2 年内,从"技术好但沟通差"(第一年中评:做事偏慢、沟通成本高)
  成长为"扎实、有耐心、项目结果有针对性改进"的开发者(部门 leader 第二年谈话原话);
  具体来自[TODO: 引用某个项目里的协作案例]
- 第二年获 7.7% 调薪 + 1.5x 绩效系数,在公司中国区 Vendor 员工平均调薪 < 2% 的大环境下被特殊处理
- 曾被部门 leader 在聚餐中评为"救火员"角色 [TODO: 哪些具体救火案例?——这是简历可写的差异化软实力]
- 跨团队协作能力:在 SI 4.1 SNMP4J-SMI-PRO 引入过程中,推动了国外采购流程,与 [TODO: 哪些
  团队 / 哪些供应商] 完成跨时区配合
- 技术决策能力:主导 FerretDB Windows 可行性调研,产出技术报告,直接影响 PI 4.0 重构
  路线决策
- 部门 leader 在 2026 第二年正式谈话中明确"按独当一面 / 技术高手方向培养",
  分配的任务通常涉及底层检查或跨小组沟通(详见 _curated/career/talking-2026-leader-feedback.md)
```

---

## 6. 简历投递前的最终检查清单

| 检查项 | 状态 |
|---|---|
| 是否所有 `[TODO: ...]` 都已填? | ⬜ |
| 量化数字是否有?(没有就别写"提升 N%") | ⬜ |
| 项目段是否每段都按 STAR 结构?(背景 / 任务 / 行动 / 成果) | ⬜ |
| 是否避免了"参与了 / 协助了 / 配合了"等弱主语? | ⬜ |
| 技术栈是否与你**真的精通**对齐?(写"精通 Hazelcast" 但只用过 IMap 是面试灾难) | ⬜ |
| 公司敏感信息是否脱敏?(具体客户名、内部代号) | ⬜ |
| 不同岗位投递前**是否针对性裁剪**?(投架构岗 → 强化 §1.6 PI 重构;投业务岗 → 强化 §1.0 概览) | ⬜ |
| 找一个朋友(最好是面试官 / HR 背景) review 一遍? | ⬜ |

---

> **下一步**:看 [`interview-talking-points.md`](./interview-talking-points.md) —— 简历写完后,要
> 准备**面试官按简历来问的问题**和你的标准答案。
