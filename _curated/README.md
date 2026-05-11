# `_curated/` —— AI 视角的工程梳理

> 这个目录里的所有内容**由 AI 主动整理**,与
> - `origin/` (你手写的项目/个人源内容)
> - `tech-stack/` (技术栈统一目录,2026-05-11 从 `origin/3-tech_stack/` + `_curated/tech-stack/` 合并)
> - `_build/` (脚本自动从 xmind/drawio 解析出的 outline)
>
> 四者各有分工。如果我说错了或归类不合适,请直接改对应目录下的文件。
>
> **2026-05-11 整合**:将 `origin/3-tech_stack/` 和 `_curated/tech-stack/` 合并到顶层 `tech-stack/`,按主题子目录组织;`_curated/` 不再包含 tech-stack 子目录。
>
> **2026-05-10 整理**:将 `file/` 重命名为 `origin/`;删除冗余 / 分析不佳的文档(mtp-core-deep-analysis、zero-engine、refactor_pi 整套、asp 原始文件等);修正并补充了部分问题的答案。
>
> **2026-05-08 大重构**:`_curated/` 顶层从"产物类型"(summaries/expansions/gaps)改为"主题对齐"(meta/projects/tech-stack/career),与 `origin/` 的内容分类对齐;`origin/` 下文档类原文(`.md`)在**首行加 HTML 注释**标签([原]/[整]/[摘]),非文档类(.xmind/.drawio/.sql/.py/.pdf/...)按扩展名识别。详见 [`meta/inventory.md §8 变更日志`](./meta/inventory.md#8-变更日志)。

---

## 1. 这个目录解决什么问题

你的 `origin/` 累积了 2 年多素材(Vertiv SI / PI 重构 / 中移 ASP / Java Study / 各种技术栈笔记 / xmind / drawio),但:
- **跨主题串联不足**(SI 和 PI 都用 mtp-core,但散在不同目录)
- **简历语言版**没有(写得多、能直接用的少)
- **盲点没人替你指出**(P6+ 必考的 JVM/JUC/Spring/MySQL/Redis/MQ/网络/系统设计;maven、linux、SNMP4J 等基础)
- **xmind/drawio 内容**之前我读不到(已通过 `_build/outlines/` 解决)

`_curated/` 的产物分四大主题:
- `meta/` —— 工程级元信息(全工程盘点 + 缺口清单)
- `projects/` —— 项目级 summary(SI / PI / ASP / FerretDB / mtp-core / 依赖升级)
- `tech-stack/` —— 技术深度文档(Spring/MySQL/Redis/MQ/JVM/网络/系统设计/英语 等)
- `career/` —— 简历/面试/复盘(可直接用于对外输出的语言版)

---

## 2. 标签体系

工程内有**两套**标签:

### 2.1 ⭐ 内容来源标签(`origin/` 下文档类的首行注释)

`origin/` 下文档类(`.md`)的**第一行**是一条 HTML 注释,标明**文件来源性质**:

```markdown
<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->
```

HTML 注释**渲染时不显示**,只在源码里可见,不打扰阅读;但 grep / IDE 大纲都能搜到。

| 标签 | 含义 | 数量 | 例子 |
|---|---|---:|---|
| `[原]` | **原始素材**:录音转写 / 草稿 / 随手记 / 未经整理 | 1 | `talking-analyze-detailed.md`(2026 年第二年谈话录音转写) |
| `[整]` | **整理稿**:你下功夫写的成稿,可作简历 / 面试素材 | — | `dependency-upgrade.md`、`resolve-mib.md`、`DriverHub.md` |
| `[摘]` | **转载 / 外部收集**:网上找的资料、别人的题集汇编、通用速查清单 | — | `java-study.md`、`mongodb-commands.md`、`Java Study.pdf` |

**非文档类不打首行标签,靠扩展名 + 父目录识别**:

| 类型 | 扩展名 | 数量 | 含义 |
|---|---|---:|---|
| 脑图 | `.xmind` / `.drawio` | 8 | 用 xmind / drawio 工具打开,outline 见 `_build/outlines/` |
| 外部资料 | `.pdf` | 1 | `Java Study.pdf`(参考资料,转写版见同目录 `java-study.md`) |
| 嵌入图片 | `.png` | 13 | 文档配图 |

> **`_curated/` 下的 `.md` 不打这个标签**:`_curated/` 全部由 AI 生成,整体自带"AI 产物"语义。
>
> 2026-05-10 删除了大量冗余/分析不佳的文档后,部分 `[整]` 标记的文件已不在 `origin/` 中,但提炼版仍保留在 `_curated/` 内。

#### 怎么用这套标签?

- **看到 `[原]` 的文件 → 不要直接给别人看**(可能有口水话/口误/错字)
- **看到 `[整]` 的文件 → 简历/面试可以直接引用**(已经整理过)
- **看到 `[摘]` 的文件 → 用于自己学习参考**,但不要写进简历(不是你的原创)

### 2.2 内容状态标签(用在 `_curated/` 内)

| 标签 | 含义 |
|---|---|
| `[就绪]` | 内容完整,可直接对外输出 / 写进简历 / 给同事看 |
| `[需补充]` | 已写但缺某些关键细节(具体细节在文中标注) |
| `[待开始]` | 几乎没有素材,需要你提供更多信息 |
| `[源文]` | 该段直接归并 / 串联了你已有的 `origin/` 下的素材,不算我"原创" |

### 2.3 价值标签(我对你的判断)

| 标签 | 含义 |
|---|---|
| `[简历亮点]` ⭐ | 强烈建议放进简历,是你区别于普通后端的差异化经历 |
| `[面试高频]` 🎯 | 你这段经历对应的常见面试题,会问到 |
| `[盲点]` ⚠️ | 你目前没意识到 / 没重视,但我认为对你下一步发展重要 |
| `[优先级⭐]` | 推荐你**优先处理**(无论是补充内容、回答问题、还是写出来) |
| `[复盘]` 📝 | 个人 / 职业成长复盘相关,与 `1-meta/gate/` 呼应 |

### 2.4 关联标签

| 标签 | 含义 |
|---|---|
| `[跨主题]` 🔗 | 一份文档关联了多个主题(如 PI+SI+mtp-core 三件套) |
| `[未决]` ❓ | 我有疑问 / 看不懂的地方,需要你确认 |

> ⚠️ **标签不是装饰**:看到 `⚠️[盲点]` 就该停下想 1 分钟"这是不是我真的忽略了";看到 `[未决]❓` 就该回答它,而不是跳过。

---

## 3. 目录导航

```
_curated/
├── README.md                              ← 你正在看
│
├── meta/                                  ← 工程级元信息
│   ├── inventory.md                       ← 全工程内容总盘点(从这里开始)
│   └── still-missing.md                   ← 还需要你补充才能总结的内容(我视角清单)
│
├── projects/                              ← 项目级 summary
│   ├── mtp-core-framework.md              ← MTP-Core/TAF Core 框架 设计精华 + 缺陷反思
│   ├── asp-platform.md                    ← 中国移动 ASP 提炼(整合 project.md+knowledge.md,4 大模块 + 简历段 + 10 大面试题)⭐⭐
│   ├── ferretdb-research.md               ← FerretDB Windows 调研归档(技术结论 + 简历版)
│   ├── snmp-zero-engine.md                ← SNMP 协议族 + MIB 解析 + Zero Engine 信号告警流
│   └── dependency-upgrade.md              ← 大版本依赖升级方法论(SI 4.1 经验沉淀)
│
│   (tech-stack/ 已独立为顶层目录,见下方 §3.1)
│
└── career/                                ← 工作 / 项目经历的简历版
    ├── resume-projects.md                 ← 直接可用的简历项目段(STAR 法则 + 量化)
    ├── interview-talking-points.md        ← 面试可讲的技术点(按主题/按项目分类)
    ├── growth-and-feedback.md             ← 成长复盘 + pre_action.md 末尾 3 问的回答框架(已结合 L 第二年反馈修订)
    └── talking-2026-leader-feedback.md    ← 2026 春节后第二年谈话提炼(调薪 7.7% / 培养方向 / 今年行动清单) ⭐
```

### 3.1 `tech-stack/` —— 技术栈统一目录(2026-05-11 整合)

> 原 `origin/3-tech_stack/`(用户笔记)和 `_curated/tech-stack/`(AI 深度文档)合并到此。

```
tech-stack/
├── 00-skill-roadmap.md             ← 进阶补强总索引
├── system-design-primer.md         ← 系统设计 7 步法
├── linux-filesystem-and-perms.md   ← Linux 文件系统 + 权限
├── freemarker.md / undertow.xmind / OpenAPI 规范.xmind
│
├── java/                           ← Java 核心 (5 files)
├── database/                       ← 数据库 (PostgreSQL/MySQL/Mongo/FerretDB)
├── cache/                          ← 缓存 (Hazelcast + Redis)
├── middleware/                     ← 中间件 (MQ)
├── protocol/                       ← 协议 (SNMP/WebSocket/HTTP)
├── design_patterns/                ← 设计模式
└── engineering/                    ← 工程实践 (测试/Maven/英语)
```

---

## 4. 推荐阅读顺序

**目的不同,顺序不同**:

### 4.1 想了解"我盘点出了什么" → 30 分钟

1. [`meta/inventory.md`](./meta/inventory.md)(核心)
2. [`meta/still-missing.md`](./meta/still-missing.md)
3. 浏览 `projects/` 各文件的开头(每个文件第一段都有"这份文档讲什么、来自哪些素材")

### 4.2 想准备面试 / 更新简历 → 1.5 小时

1. [`career/resume-projects.md`](./career/resume-projects.md) ⭐(最重要;§1 Vertiv + §2 中国移动 ASP 都已就绪)
2. [`career/interview-talking-points.md`](./career/interview-talking-points.md)(§1-§5 Vertiv + §6.5 ASP + §6.6 Java 通用)
3. [`projects/asp-platform.md`](./projects/asp-platform.md) ⭐⭐(中国移动 ASP 项目提炼)
5. [`tech-stack/java/java-knowledge-map.md`](../tech-stack/java/java-knowledge-map.md)(Java 通用知识地图,基于 PDF)
6. [`projects/ferretdb-research.md`](./projects/ferretdb-research.md)(已经写好可用的简历段)

### 4.3 想把工程的"盲点"补齐 → 长期(不要一次消化)

> 先读 [`tech-stack/00-skill-roadmap.md`](../tech-stack/00-skill-roadmap.md) 看完整体系 + 标签 + 优先级,再按需精读单篇。

**P6+ 三件套(本月精读)**:
1. [`jvm-and-concurrency.md`](../tech-stack/java/jvm-and-concurrency.md) ⭐⭐⭐(P6+ 必读,16 章)
2. [`spring-internals.md`](../tech-stack/java/spring-internals.md) ⭐⭐⭐(Bean/AOP/启动/事务)
3. [`mysql-deep-dive.md`](../tech-stack/database/mysql-deep-dive.md) ⭐⭐⭐(锁/MVCC/主从)
4. [`redis-deep-dive.md`](../tech-stack/cache/redis-deep-dive.md) ⭐⭐⭐(底层/持久化/Cluster)

**季度内**:

5. [`mq-essentials.md`](../tech-stack/middleware/mq-essentials.md)(三大问题 + Kafka)
6. [`network-essentials.md`](../tech-stack/protocol/network-essentials.md)(TCP/HTTPS/WS)
7. [`testing-and-engineering.md`](../tech-stack/engineering/testing-and-engineering.md)(外企友好 + L 反馈呼应)
8. [`system-design-primer.md`](../tech-stack/system-design-primer.md)(P7 加分)
9. [`programming-english.md`](../tech-stack/engineering/programming-english.md)(L 反馈硬指标 — 长期积累)

**基础补丁**:

10. [`maven-essentials.md`](../tech-stack/engineering/maven-essentials.md)
11. [`linux-filesystem-and-perms.md`](../tech-stack/linux-filesystem-and-perms.md)
12. [`snmp4j-quickref.md`](../tech-stack/protocol/snmp4j-quickref.md)

**复盘相关**:

13. [`meta/still-missing.md`](./meta/still-missing.md)
14. [`career/growth-and-feedback.md`](./career/growth-and-feedback.md) + [`career/talking-2026-leader-feedback.md`](./career/talking-2026-leader-feedback.md)

### 4.4 想深入某个技术领域 → 各按需阅读

- 数据库:[`tech-stack/database/postgresql-knowledge.md`](../tech-stack/database/postgresql-knowledge.md) → `_build/outlines/3-tech_stack/database/postgresql/postgresql.outline.md`
- SNMP:[`projects/snmp-zero-engine.md`](./projects/snmp-zero-engine.md) → `_build/outlines/3-tech_stack/protocol/SNMP.outline.md`

---

## 5. 我的方法论(让你知道我是怎么"看"你的工程的)

为了让你能判断我的输出,以下是我的偏见:

1. **我偏向"少而精"**:能用 1 句话讲清楚就不写 1 段。看到我写得很短的地方,可能是因为没必要展开。
2. **我偏向"暴露问题"**:相比于全是好话,我会主动指出你忽视的 / 不一致的地方。`[盲点]⚠️` 标签会比较多。
3. **我不抄你的原文**:`refactor_pi/docs/` 你已经写得非常详尽,我不再写一份"PI 重构总结"复述你。我做的是"从中读出你没明说的"(关键决策、可复用模式、对你简历的价值)。
4. **我把"用得上"放在"全面"前面**:面试要讲、简历要写、下次同样问题不重复踩坑——优先于"知识体系完整"。
5. **我标注的"工作量估算 / 经验数字"是我的判断,不是你说过的**:看到时请校验,如果不准确请告诉我我会改。
6. **我会犯错**:技术细节我可能记错版本号、API 名称、参数。看到可疑的请验证后告诉我,我会更正。

---

## 6. 维护建议(给你的)

- 这个目录的所有文件**你可以自由编辑**(不像 `_build/outlines/` 是脚本生成,改了下次重跑会被覆盖)。
- 如果某个 summary 你不认可,直接改;改完的内容如果想我以后参考,就保留;不想保留的删掉就行。
- 如果新增了 `origin/` 下的素材,可以让我"重新审视 `_curated/` 是否需要更新",而不是默默累积差异。
- [`meta/still-missing.md`](./meta/still-missing.md) 是动态的——你补一项,我们就划掉一项。

### 6.1 `origin/` 下新增文件时怎么打标签?

**只对 `.md` 文档加首行注释**,其他类型靠扩展名识别。

按 §2.1 的判断:
- 你**自己写的**(项目笔记、工作日志、架构设计) → `[整]`
- 你**录音 / 草稿**(谈话、想法草稿) → `[原]`
- **网上找的 / 抄的**(题集、命令清单、版本对比表) → `[摘]`
- 脑图(.xmind/.drawio) / 代码工具产物(.sql/.py/.json/.log) → **不需要标注**(扩展名已说明)

新增 `.md` 时,在文件**第一行**加这条 HTML 注释:

```markdown
<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

# 你的标题
...
```

三个标签全文(直接复制其中一条):

```markdown
<!-- 标签:[原] —— 用户原稿(原话/录音转写/未经编辑) -->
<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->
<!-- 标签:[摘] —— 用户摘录稿(从 PDF/网络/课程摘抄) -->
```

---

> **下一步**:从 [`meta/inventory.md`](./meta/inventory.md) 开始。
