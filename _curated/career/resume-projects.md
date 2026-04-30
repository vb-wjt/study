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

为了让这份文档真正能用,请[在 `gaps/still-missing.md` §5](../gaps/still-missing.md#5-简历语言版的输入-必须) 回答:

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

> 文档支撑:`file/2-projects/vertiv/SI/experiences/v4.0/zero-engine.md` (6514 行) +
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

> 文档支撑:`file/2-projects/vertiv/SI/experiences/v4.0/discovery.md` (2401 行)

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

> 文档支撑:`file/2-projects/vertiv/SI/experiences/v4.1/dependency-upgrade.md` (352 行) +
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

> 文档支撑:`file/2-projects/vertiv/SI/experiences/v4.1/resolve-mib/design/resolve-mib.md` (754 行) +
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

> 文档支撑:`file/3-tech_stack/database/ferretdb/ferretdb-no-docker.md` (215 行) +
> `file/unclassified/archived_chats.md` (你之前已经写好的简历语言版)

### 1.6 PI 4.0 重构 · 主导调研与方案设计  [简历亮点]⭐⭐⭐ [面试高频]🎯

> ⭐ 这是你**最高价值**的简历段——决策级 / 架构级 / 跨技术栈 / 跨阶段。

```
【模块】Vertiv Power Insight 4.0 全栈重构方案设计
【背景】PI 是 Vertiv 旗下面向小型机房的电源监控产品(已商用多年,部署在数据中心 / 银行 /
       医疗等行业),技术栈陈旧(Spring Boot 2.6.15 + Java 8 + MongoDB 3.6 + Hazelcast 3.12 +
       Angular 14),叠加 MongoDB 许可证风险,已不可持续。需要在保持业务等价的前提下完成
       全面重构。
【贡献】
- **代码架构反向工程**:克隆 PI 全套仓库(mtp-core 平台 + 25 个 taf-plugin-* 业务插件 +
  18 个前端 taf-* 库)到本地集中目录,产出 277 行的旧架构分析文档与 195 行的 MongoDB 集合
  拆解,作为重构基线
- **业务功能盘点**:基于产品手册逐章对齐到代码模块,产出 L1-L10 业务功能清单(从 UPS/PDU
  监控 / 告警 / 服务器关机 / 联动 / 通知 / 电费 / 系统设置 / vCenter 集成全覆盖),作为重构
  需求基线
- **新架构方案设计** (532 行 overview + 916 行 deep-dive):
  - 数据库:PostgreSQL 16(原生分区 + 降采样,代替 MongoDB + 自研 mtp.tsd)
  - 后端:Spring Boot 3.x + Java 21 LTS + JOOQ + Flyway,**全面砍掉 Hazelcast 集群框架**,
    改用 Caffeine + Spring Event + JDK 并发原语
  - 平台层:mtp-core 4.0 重写为多模块 Spring Boot Starter 库(无运行时插件加载、无动态
    Schema、无 ClassLoader 隔离)
  - 产品层:pi-server 模块化单体,10 个 feature 通过编译期模块 + 配置开关启用/关闭
  - 通信:领域事件 + 事务发件箱(Outbox)模式,替代 IMap.addEntryListener
- **数据迁移工具开发**:开发 Python ETL 工具链(mongo_analyze / mongo_samples / mongo_to_pg /
  verify_migration),实现 MongoDB → PostgreSQL 的全量数据迁移与一致性校验
- **PostgreSQL Schema 设计**:产出 14 个模块的 SQL 草稿(IAM / metamodel / platform / device /
  monitoring / event / alarm / job / telemetry / file / licensing 等),共 [TODO: 计算 SQL 行数] 行
- **风险与未决项管理**:识别 9 类主要风险并给出缓解方案;明确 7 个组织前提与 8.x 技术
  考量(可观测性 / 升级补丁 / 回滚 / 性能压测 / 安全审查 / 数据保留 / 浏览器兼容性 / 第三方
  设备 driver / License 兼容 / 培训文档迁移 / 合规认证 / 跨产品账户)等待团队决策
- **工期估算**:基于"有效人月"模型(扣除会议/Review/blocker)给出 3 / 5 / 10 人三档团队规模
  的工期对照(22-28 月 / 12-16 月 / 8-11 月),并明确"Brooks's Law"下的人力投入边际收益
【成果】
- 输出 [TODO: 总文档行数,我数了下大概是 2500+] 行的重构决策文档,作为团队评审与立项的核心
  依据
- 已通过的核心架构决策 [TODO: N 项],为后续 [TODO: 团队规模] 的实施团队提供清晰起点
```

> 文档支撑:`file/2-projects/vertiv/refactor_pi/` 整套(docs / db / tools / result)

### 1.7 内部工具 · Driver Hub  [简历亮点]⭐

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

> 文档支撑:`file/2-projects/vertiv/Tool/DriverHub.md` (素材较少,需补充展开)

---

## 2. 中国移动 · 全业务支持平台 [需补充]

> **2022.07 - 2024.03 · Java 后端开发**
>
> 这一段你工程里**几乎没有素材**(`projects_index.md` 只有一行)。我无法替你写有质量的简历段。
>
> 但 2 年的工作经历**简历必须有**,以下是骨架占位 + 你需要回答的问题。

### 待补充清单 ⚠️

```
【项目名称】中国移动 · 全业务支持平台 (融合 CRM 与 BRM 业务)
【在职时间】2022.07 - 2024.03
【项目角色】[TODO: 你的具体角色,Java 后端 / 全栈 / 模块负责人?]
【项目规模】[TODO: 团队人数 / 服务的省级/市级用户数]
【项目背景】
[TODO: 为什么要融合 CRM + BRM?之前是怎么做的?融合的业务/技术挑战?]

【主要职责】
- [TODO: 你具体做了什么模块?计费?客户?订单?账务?]
- [TODO: 用了什么技术栈?Spring Cloud?微服务?消息中间件?]
- [TODO: 解决过什么有技术含量的问题?并发?性能?数据一致性?]

【成果】
- [TODO: 量化数据,如吞吐量提升 / Bug 减少 / 上线节奏 / 客户反馈]
```

> **建议**:回想一下这 2 年最值得讲的 1-2 个事:
> - 解决过的最复杂的 Bug 或性能问题
> - 主导过的最有技术含量的设计
> - 学到的最深的业务知识(CRM / BRM 的运营商业务,在金融 / 互联网厂面试时是差异化亮点)

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

基于你 `action.md` / `pre_action.md` 里写的复盘:

```
- 在 Vertiv 的 1.5 年内,从"技术好但沟通差"成长为"能搞定棘手问题、能与老专家配合默契、
  懂业务懂沟通"的成熟开发者(具体来自[TODO: 引用某个项目里的协作案例])
- 曾承担"救火员"角色 [TODO: 哪些救火案例?——这是简历可写的差异化软实力]
- 跨团队协作能力:在 SI 4.1 SNMP4J-SMI-PRO 引入过程中,推动了国外采购流程,与 [TODO: 哪些
  团队 / 哪些供应商] 完成跨时区配合
- 技术决策能力:主导 FerretDB Windows 可行性调研,产出技术报告,直接影响 PI 4.0 重构
  路线决策
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
