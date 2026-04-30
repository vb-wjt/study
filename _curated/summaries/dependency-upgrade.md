# 大版本依赖升级方法论 (SI 4.1 实战沉淀)

标签:`[就绪]` `[简历亮点]`⭐⭐ `[面试高频]`🎯 `[源文]`

> 这份文档把你 `dependency-upgrade.md` (352 行) + `SI 依赖升级.outline.md` (444 行) +
> `Hazelcast.md` (235 行) 整合,提炼**可复用的方法论**(不只是 SI 4.1 这一次的细节)。
>
> 升级经验是 senior 工程师的**差异化能力**——能讲清楚为什么升、怎么升、升完踩了什么坑的人,
> 直接拉开 80% 候选人。

---

## 0. SI 4.1 升级总览

| 依赖 | 模块 | 当前版本 | 升级目标 | 影响面 |
|---|---|---|---|---|
| Java | SI | zulu 8.58 | zulu 21.44 | JRE 自身 + 反射 + 模块系统 |
| Java | ZE | zulu 17.0 | zulu 21.44 | 较小(都是较新版本) |
| SpringBoot | SI | 2.7.18 | 3.5.6 | **巨大** (javax → jakarta) |
| SpringBoot | ZE | 3.3.5 | 3.5.6 | 较小(同 3.x 内升级) |
| Hazelcast | SI | 3.12.13 | 5.6.0 | **巨大** (大量包路径变动) |
| MySQL | ZE | 8.0.39 | **改用 SQLite** | License + 架构调整 |

> 数据来源: `dependency-upgrade.md` §dependency upgrade conclusion

---

## 1. 触发因素 (为什么要做这个项目)

### 1.1 安全债

- Spring Boot 2.6.x / 2.7.x 已 EOL(End of Life),不再有安全补丁
- Hazelcast 3.12 已停止维护,**严重 license 风险**
- Java 8 已停止公开免费更新

### 1.2 License 风险

> 这是这次升级**最值得讲的法律层面 trade-off**,简历加分点。

#### MySQL → SQLite (而不是 MariaDB)

你的 `dependency-upgrade.md` §detailed design 部分有详细分析:

| 组件 | 协议 | Risk | 解决 |
|---|---|---|---|
| MySQL Server (community) | GPLv2 | N (独立进程,网络通信) | No-change |
| **MySQL Client (jdbc)** | GPLv2 | **Y (嵌入代码,衍生作品)** | 切换 |
| MariaDB Client | LGPL | N (附加闭源条款) | 候选 |

**核心问题**: GPLv2 有"传染性",Java 应用嵌入 GPLv2 的 mysql-connector-java.jar 属于"衍生作品",**可能被要求开源** 或 付 license 给 Oracle。

**最终选 SQLite**(而不是 MariaDB):
- SQLite 是 Public Domain,无 license 风险
- ZE 的数据规模 [TODO: 实际数据量?] 不需要 MySQL 级别的能力
- 嵌入式部署,不需要独立 DB 进程,简化运维

> **简历讲法**: "我主导了 ZE 的 MySQL → SQLite 切换,**不只是技术选型,是基于 GPLv2 license 传染性风险的法律层面决策**"。

### 1.3 与公司平台升级路线对齐

- 公司平台 mtp-core 同步升级,不升级 = 落后版本受限
- SI 是先行者,**升级路径直接转化为 PI 4.0 重构方案的"已验证清单"**

---

## 2. 升级路径方法论 (可复用)

### 2.1 升级顺序

```
1. 先升 JRE (相对独立)
   → Java 8 → 21
   → 跑通基础应用,确认 JVM 没问题

2. 再升 Spring Boot (拖动整个生态)
   → 2.7.18 → 3.5.6
   → 每升一个大版本可能要跨 javax → jakarta
   → 所有依赖跟随版本对齐

3. 最后升外围依赖 (Hazelcast 等)
   → 3.12.13 → 5.6.0
   → 处理大量 API 包路径变动

4. 业务测试 + 性能基线
```

### 2.2 工具准备

| 工具 | 用途 |
|---|---|
| OWASP Dependency-Check | 升级后扫描漏洞 |
| Dependabot / Renovate | 后续依赖维护 |
| Maven `versions:display-dependency-updates` | 找出可升级依赖 |
| Maven `enforcer` plugin | 锁定关键依赖版本 |
| `jdeps`(JDK 自带) | 分析项目对 JRE 内部 API 的依赖 |

### 2.3 执行原则

- **每步独立 PR**: 一个 PR 一个升级,出问题方便回滚
- **每步独立测试**: 单元测试 + 集成测试都跑,不要堆叠
- **回滚预案**: 每步升级前 tag,回滚就 git revert
- **文档化**: 把每个 break change 写下来 → 这就是你 `dependency-upgrade.md`

---

## 3. SI 4.1 各项升级的关键 break change

### 3.1 Java 8 → 21

| 类别 | 影响 | 解决 |
|---|---|---|
| Module System(JPMS) | unnamed module 警告 | `--add-opens` JVM 参数,或重写代码避免反射访问 JDK 内部 |
| `sun.*` 内部 API | 已被封装 | 用替代标准 API |
| `javax.*` → `jakarta.*` | (Java 9+ 移除部分) | 用 jakarta.* 包 |
| GC 默认变化 | G1GC 成默认 | 评估是否需要 ZGC / Shenandoah |
| 字节码版本 | 8 (52) → 21 (65) | 编译器升级,部分老库可能不支持 |

**Java 21 新特性可用** (面试可讲):
- `record`(数据类)
- `sealed class`(限制继承)
- `pattern matching`(switch / instanceof)
- 文本块 (text block)
- `Virtual Threads` (Project Loom) —— 简历加分

### 3.2 Spring Boot 2 → 3

| 类别 | 影响 | 解决 |
|---|---|---|
| `javax.*` → `jakarta.*` | **几乎所有依赖跟着改** | sed 批量替换 / IDE 重构 |
| Spring Security 5 → 6 | `WebSecurityConfigurerAdapter` 已删 | 用 Lambda DSL + `SecurityFilterChain` Bean |
| Servlet API 4 → 5 | `HttpServletRequest` 等都搬到 jakarta | 跟随 |
| Hibernate 5 → 6 | DDL 生成行为变 | review schema 生成是否符合预期 |
| Actuator endpoint 路径 | 部分变化 | 配置兼容 |

### 3.3 Hazelcast 3 → 5 (这是大头)

> 你 `_build/outlines/.../SI 依赖升级.outline.md` (444 行) 详细列了变动。**核心痛点**:

| API | 旧位置 (com.hazelcast.core) | 新位置 |
|---|---|---|
| Member, Cluster, MembershipEvent | core | **cluster** |
| IAtomicLong | core | **cp** (CP Subsystem) |
| ItemListener, IQueue, QueueStore | core | **collection** |
| IMap, MapStore, MapEvent | core | **map** |
| ITopic, MessageListener, Message | core | **topic** |
| HazelcastInstanceFactory | instance | **instance.impl** |
| EntryObject | query | **query.PredicateBuilder** |

**应对策略**:
- 写一个 sed 脚本 / IDE structural search,**批量替换 import**
- 配置文件(hazelcast.xml)的 schema 也升级了,跟着改
- 测试每个用到 Hazelcast 的功能(IMap / ITopic / Lock)都重测

### 3.4 MySQL → SQLite (ZE)

- 取消 mysql-connector-java 依赖,加 sqlite-jdbc
- JDBC URL 改 `jdbc:sqlite:./data/ze.db`
- 单线程模式 vs 多线程(SQLite 默认 serialized 模式,WAL 模式可提升)
- DDL 语法兼容:大部分一样,但**没有 AUTO_INCREMENT**(用 `INTEGER PRIMARY KEY`),**没有部分类型** (TIMESTAMP 用 TEXT)

---

## 4. Hazelcast 升级带来的反思 [简历亮点]⭐

> 这是**升级之外的副产品**,但是简历的最大加分点。

### 4.1 升级过程发现的"滥用"

> 来自 `Hazelcast.md` §在 SI 中的作用,SI 用了 Hazelcast 7 大用途:
> 1. 分布式缓存 (IMap)
> 2. 分布式锁 (IMap<String, String>)
> 3. 分布式任务执行
> 4. 多优先级执行器服务
> 5. 集群发现和网络配置
> 6. 负载均衡机制
> 7. 队列监听机制

**问题**: SI 客户基本都是**单机部署**,这些"分布式"特性根本用不到。

### 4.2 升级 = 反思的契机

升级到 Hazelcast 5 后,可以**问自己**:
- 单机部署还需要 Hazelcast 吗?
- 替换成本 vs 维护 Hazelcast 5 的长期成本,哪个高?

> **结论**: PI 4.0 重构直接**全砍 Hazelcast**(详见 [`pi-platform-deep-dive.md`](./pi-platform-deep-dive.md) §3.3),改用:
> - IMap → Caffeine
> - ITopic → Spring ApplicationEvent
> - Lock → ReentrantLock
> - Quartz 主从 → @Scheduled

### 4.3 简历讲法

> "我在 SI 4.1 完成了 Hazelcast 3→5 升级,但这次升级**让我意识到 Hazelcast 在我们单机产品里是杀鸡用牛刀**。这个反思直接影响了 PI 4.0 重构方案——**全砍 Hazelcast,用 JDK / Spring 原生组件替代**。这是一次'升级 → 反思 → 决策更激进'的完整链路。"

---

## 5. 升级方法论 (可复用)

### 5.1 升级前

- [ ] 列出所有依赖 + 当前版本 (`mvn dependency:tree`)
- [ ] 识别 EOL / CVE 高危依赖 (OWASP)
- [ ] 设定升级目标 (target 版本 + 兼容矩阵)
- [ ] 估算工作量 (大版本升级:1-3 月不奇怪)

### 5.2 升级中

- [ ] 每步独立 PR,独立测试
- [ ] 把每个 break change 文档化(下次升级少走弯路)
- [ ] 跑 OWASP 扫描,确认没引入新漏洞
- [ ] 性能基线对比(启动时间 / 内存 / 关键 API 延迟)

### 5.3 升级后

- [ ] 反思:**这个组件还需要吗**?(像 SI 4.1 反思 Hazelcast)
- [ ] 输出"升级 SOP"供其他项目复用
- [ ] 写 `dependency-upgrade.md` 文档(你已经做了)
- [ ] [盲点]⚠️ 你做了吗:**生成可复用的"内部技术品牌资产"** —— 把这次升级的方法论分享给团队 / 写技术博客

---

## 6. 简历讲述模板

```
【项目】SI 4.1 大版本依赖升级
【时间】[TODO: 起止时间]
【角色】主导参与

【背景】SI 早期采用 Java 8 + Spring Boot 2.7 + Hazelcast 3.12 + MySQL,这些组件均存在
       严重的 EOL 安全风险(Spring Boot 2.x 已 EOL,Hazelcast 3.x 已停止维护)和 license
       风险(MySQL JDBC Driver 的 GPLv2 传染性)。

【贡献】
- 主导规划升级路径:JRE 8→21 / Spring Boot 2.7→3.5 / Hazelcast 3→5 / MySQL→SQLite,
  并产出完整的 break change 文档(包含影响面 + 解决方案 + 回滚预案)
- 攻克 Hazelcast 3→5 的 [TODO: 多少处] API 包路径变动(Member/IMap/ITopic 等核心类
  从 com.hazelcast.core 拆分到 cluster/map/topic/collection 等子包),通过 sed 批量改造
- 处理 Spring Boot 3 的 javax → jakarta 命名空间迁移、Spring Security 6 配置式 API 重写
- 完成 MySQL → SQLite 切换的法律层面决策(基于 GPLv2 license 传染性的法律风险评估,
  最终选 SQLite 因 Public Domain 无 license 风险 + 嵌入式部署降低运维成本)
- **副产品**: 通过升级过程的反思,识别出 Hazelcast 在单机部署场景下的"杀鸡用牛刀",
  为后续 PI 4.0 重构提出"全砍 Hazelcast"的激进方案

【成果】
- SI 4.1 成功上线,所有依赖通过 OWASP 依赖扫描,无 HIGH+ 安全漏洞
- 形成"大版本依赖升级 SOP",为同公司其他产品(如 PI 4.0)提供升级路线参考
- [TODO: 启动时间 / 内存 / 性能 等量化数字]
```

---

## 7. 与你 `file/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| SI 4.1 升级详细设计 | §1, §3 | `file/2-projects/vertiv/SI/experiences/v4.1/dependency-upgrade.md` (352 行) |
| 大量 break change 清单 | §3.3 | `_build/outlines/business/SI/task/SI 依赖升级.outline.md` (444 行) |
| Hazelcast 在 SI 中的用途 | §4 | `file/3-tech_stack/cache/Hazelcast.md` (235 行) |
| PI 4.0 砍 Hazelcast 决策 | §4.3 | `file/2-projects/vertiv/refactor_pi/docs/rebuild-plan/01-overview.md` §4.1 |
| Java / SB / Hazelcast 升级综合视角 | (本文) | [`pi-platform-deep-dive.md`](./pi-platform-deep-dive.md) §3 |

---

> **下一步**: 看 [`expansions/maven-essentials.md`](../expansions/maven-essentials.md) (Maven 是依赖升级的载体)
