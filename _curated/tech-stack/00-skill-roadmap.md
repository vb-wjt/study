# 进阶补强 · 总索引 + 标签体系

> **写给**:2022 毕业、4 年 Java 后端的你
> **目的**:把"我认为你需要 / 有优势 / 该补的"都列出来,**打上标签**,便于你按优先级和场景检索
> **使用方式**:**不是一口气看完**,而是根据你当下的诉求(面试 / 升级 / 项目)挑标签精读

---

## 1. 标签体系(后续所有文档都用这套)

### 1.1 状态标签

| 标签 | 含义 |
|---|---|
| `[就绪]` | 内容完整可读 |
| `[需补充]` | 待你补实战数据 / 校对 |
| `[草稿]` | 我快速起草,后续会迭代 |

### 1.2 优先级标签(对你而言)

| 标签 | 含义 |
|---|---|
| `[P6基线]`⭐⭐⭐ | **必学**;大厂笔试/二三面会问;不会 = 简历无法过技术筛 |
| `[P7加分]`⭐⭐ | 加分项;P7+ 起步要求;能让你和"会用"型候选人拉开差距 |
| `[ROI高]`💎 | 投入小产出大;**优先学** |
| `[长尾]` | 偶尔考;有时间补也好,没时间不影响 |
| `[需要积累]`⏳ | 不是看一遍能掌握的,需要长期反复 |

### 1.3 关联标签

| 标签 | 含义 |
|---|---|
| `[与你项目]`🔗 | 你 SI/ASP/PI 项目能讲实战 → **简历金矿** |
| `[与L反馈]`📝 | 与 L 第二年谈话给的发展方向呼应 |
| `[与PDF重叠]`📚 | `Java Study.pdf` 已部分覆盖 → 可对照 |
| `[盲点]`⚠️ | PDF 和工程都没覆盖的真盲点 |

### 1.4 公司类型偏好

| 标签 | 含义 |
|---|---|
| `[国内大厂]` | 阿里/腾讯/字节/美团 笔试/面试侧重(算法 / 八股 / 项目深度) |
| `[外企友好]` | 外企(像 Vertiv / 微软 / Google)更看重(代码品质 / 工程化 / 设计 / 英文沟通) |

---

## 2. 进阶文档清单(按学习路径排序)

### 2.1 ✅ 已就绪

| 文档 | 标签 | 行数 | 备注 |
|---|---|---:|---|
| [`jvm-and-concurrency.md`](./jvm-and-concurrency.md) | `[P6基线]`⭐⭐⭐ `[盲点]`⚠️ `[与你项目]`🔗 | 1100+ | JVM 内存 / GC / JMM / 锁升级 / AQS / JUC 集合 / CompletableFuture |
| [`maven-essentials.md`](./maven-essentials.md) | `[P6基线]`⭐⭐ `[ROI高]`💎 | 已有 | Maven 多模块 / dependencyManagement / Profile |
| [`linux-filesystem-and-perms.md`](./linux-filesystem-and-perms.md) | `[P6基线]`⭐ `[ROI高]`💎 | 已有 | Linux 文件系统 + 权限 |
| [`snmp4j-quickref.md`](./snmp4j-quickref.md) | `[与你项目]`🔗 SI 专属 | 301 | SNMP4J 速查 |

### 2.2 ✏️ 本批次新增(2026-05)

| # | 文档 | 标签 | 优先级 |
|---|---|---|---|
| 1 | [`spring-internals.md`](./spring-internals.md) | `[P6基线]`⭐⭐⭐ `[与PDF重叠]`📚 `[与你项目]`🔗 | **本月精读** |
| 2 | [`mysql-deep-dive.md`](./mysql-deep-dive.md) | `[P6基线]`⭐⭐⭐ `[国内大厂]` `[与你项目]`🔗 | **本月精读** |
| 3 | [`redis-deep-dive.md`](./redis-deep-dive.md) | `[P6基线]`⭐⭐⭐ `[国内大厂]` `[与你项目]`🔗 | **本月精读** |
| 4 | [`mq-essentials.md`](./mq-essentials.md) | `[P6基线]`⭐⭐ `[国内大厂]` | 季度内 |
| 5 | [`network-essentials.md`](./network-essentials.md) | `[P6基线]`⭐⭐ | 季度内 |
| 6 | [`testing-and-engineering.md`](./testing-and-engineering.md) | `[外企友好]` `[与L反馈]`📝 | **本月**(L 谈话强调英文+工程化) |
| 7 | [`system-design-primer.md`](./system-design-primer.md) | `[P7加分]`⭐⭐ `[国内大厂]` `[需要积累]`⏳ | 半年内 |

### 2.3 后续(本工程未覆盖,你目标公司决定要不要)

| 主题 | 标签 | 备注 |
|---|---|---|
| Netty 基础 | `[P7加分]` `[国内大厂]` | 看你是否做 IM / 实时通讯方向 |
| DDD / 领域建模 | `[外企友好]` `[长尾]` | 复杂业务公司(蚂蚁 / 京东) |
| 算法刷题路径 | `[P6基线]` `[国内大厂]` `[需要积累]`⏳ | LeetCode top 100 + 剑指 Offer |
| 云原生 / K8s 进阶 | `[P7加分]` | ASP knowledge 已涉及基础 |
| Kotlin / GraalVM / Project Loom | `[长尾]` | 前沿,看公司需求 |

---

## 3. 你的"已有优势"地图(简历可用)

> 不是所有候选人都有这些 —— **这些是你的护城河,简历必须强调**:

| 优势点 | 来自 | 简历用法 |
|---|---|---|
| ⭐⭐⭐ **业务广度**:国企级电信(中移) + 外企边缘机房(Vertiv) | 工作背景 | 简历自我评价段:"跨国企级 + 外企级业务复杂度" |
| ⭐⭐⭐ **工程化封装**:@RedisLock AOP / dbproxy / Driver Hub | ASP / Vertiv | 简历项目段(已写在 [`career/resume-projects.md`](../career/resume-projects.md)) |
| ⭐⭐⭐ **大版本依赖升级**:Java 8→21 / Spring Boot 2→3 / Hazelcast 3→5 | SI 4.1 | 简历项目 §1.3 |
| ⭐⭐ **跨团队 + 跨时区协作**:SNMP4J-SMI-PRO 国外采购 | SI 4.1 | 简历软实力段 |
| ⭐⭐ **架构反向工程 + 重构方案设计**:PI 4.0 | PI 重构 | 简历项目 §1.6(决策级 / 架构级) |
| ⭐⭐ **国产化栈实战**:联创磐基 + 宝兰德 BES + Activiti BPM | ASP | 简历"差异化"加分(投国内国企/政企客户的公司有用) |
| ⭐ **数据迁移工具开发**:Python ETL(Mongo→PG) | PI 重构 | 简历项目段 |
| ⭐ **国企级安全合规**:二次登录 / dbpass 不明文 | ASP | 投金融 / 政企方向加分 |

---

## 4. 你需要补的"高 ROI"清单(给 4 年 Java 后端)

> 按"补完后简历最值钱"排序:

### 4.1 第 1 优先级(本月)

1. **JVM/GC/JUC** ✅ 已写 [`jvm-and-concurrency.md`](./jvm-and-concurrency.md)
2. **Spring 进阶** → [`spring-internals.md`](./spring-internals.md)
3. **MySQL 锁 + MVCC** → [`mysql-deep-dive.md`](./mysql-deep-dive.md)
4. **Redis 持久化 + 主从** → [`redis-deep-dive.md`](./redis-deep-dive.md)
5. **生产 GC/OOM 排查实战故事** → 在你日常工作里**主动找一个 case** 补 `_curated/career/resume-projects.md`

### 4.2 第 2 优先级(季度内)

6. **MQ 三大问题** → [`mq-essentials.md`](./mq-essentials.md)
7. **TCP/HTTP/HTTPS** → [`network-essentials.md`](./network-essentials.md)
8. **单元测试 + 工程化** → [`testing-and-engineering.md`](./testing-and-engineering.md) (L 反馈也强调)
9. **系统设计入门** → [`system-design-primer.md`](./system-design-primer.md)

### 4.3 第 3 优先级(半年内)

10. **算法刷题** —— 目标 LeetCode top 100,大厂笔试关
11. **专业英语 + 技术写作** —— L 第二年谈话明确**硬指标**(详见 [`career/talking-2026-leader-feedback.md`](../career/talking-2026-leader-feedback.md))
12. **Netty / DDD / Kotlin** —— 看目标公司方向

---

## 5. 我不会替你写但你应该自己做的

> 这些**不是知识**,而是**习惯 / 训练**,只能你自己积累:

| 事 | 频率 | 为什么 |
|---|---|---|
| **写技术博客**(中英文都写) | 每月 1-2 篇 | 沉淀 + 输出倒逼输入 + 简历背书 |
| **读源码**(Spring / JUC) | 每月 1 个模块 | 4 年 Java 不读源码 → P7 卡死 |
| **每月找 1 个工作中的优化点 + 量化** | 每月 | 简历"我做了什么"的弹药库 |
| **季度自我面试模拟** | 每季度 | 校准实力 + 发现盲点 |
| **持续追踪 1-2 个开源项目** | 长期 | Github 履历 + 视野 |
| **每年至少 1 次外面试**(就算不跳) | 每年 | 校准市场价 + 知道短板 |

---

## 6. 标签使用示例(怎么按需检索)

> **场景 1**:本月想准备国内大厂面试
> → 看所有标 `[P6基线]` + `[国内大厂]` 的章节
>
> **场景 2**:本月想准备 Vertiv 内部 talent review
> → 看所有标 `[外企友好]` + `[与你项目]`🔗 的章节
>
> **场景 3**:想看哪些是 PDF 没覆盖的硬核盲点
> → 看所有标 `[盲点]`⚠️ 的章节
>
> **场景 4**:今天只有 30 分钟想学点东西
> → 看 `[ROI高]`💎 标签的章节

---

> 📌 **下一步**:
> - 看 [`spring-internals.md`](./spring-internals.md) 开始 P6+ 三件套
> - 或回到 [`career/talking-2026-leader-feedback.md`](../career/talking-2026-leader-feedback.md) 看你今年的硬目标
