# `_curated/` —— AI 视角的工程梳理

> 这个目录里的所有内容**由 AI 主动整理**,与
> - `file/` (你手写的源内容)
> - `_build/` (脚本自动从 xmind/drawio 解析出的 outline)
>
> 三者**互相独立、互不覆盖**。如果我说错了或归类不合适,请直接改 `_curated/` 下的文件,不影响你 `file/` 下的素材。

---

## 1. 这个目录解决什么问题

你的 `file/` 累积了 1 年多素材(Vertiv SI / PI 重构 / 各种技术栈笔记 / xmind / drawio),但:
- 缺一个**总入口**(`study_index.md` 是空的)
- **跨主题串联不足**(SI 和 PI 都用 mtp-core,但散在不同目录)
- **简历语言版**没有(写得多、能直接用的少)
- **盲点没人替你指出**(maven、linux 这种基础你只写了 `todo`)
- **xmind/drawio 内容**之前我读不到(已通过 `_build/outlines/` 解决)

`_curated/` 的产物分四类:
- `summaries/` —— **基于现有素材的提炼**(不抄原文,只整合/串联/点评)
- `expansions/` —— **素材稀缺,我替你补**(maven、linux 等)
- `career/` —— **可直接用于简历/面试的语言版**(STAR 结构 + 量化成果)
- `gaps/` —— **还缺什么**(我视角下的盲点清单)

---

## 2. 标签体系

每个文件**顶部**和**章节标题**会带标签,含义如下:

### 2.1 内容状态标签

| 标签 | 含义 |
|---|---|
| `[就绪]` | 内容完整,可直接对外输出 / 写进简历 / 给同事看 |
| `[需补充]` | 已写但缺某些关键细节(具体细节在文中标注) |
| `[待开始]` | 几乎没有素材,需要你提供更多信息 |
| `[源文]` | 该段直接归并 / 串联了你已有的 `file/` 下的素材,不算我"原创" |

### 2.2 价值标签 (我对你的判断)

| 标签 | 含义 |
|---|---|
| `[简历亮点]` ⭐ | 强烈建议放进简历,是你区别于普通后端的差异化经历 |
| `[面试高频]` 🎯 | 你这段经历对应的常见面试题,会问到 |
| `[盲点]` ⚠️ | 你目前没意识到 / 没重视,但我认为对你下一步发展重要 |
| `[优先级⭐]` | 推荐你**优先处理**(无论是补充内容、回答问题、还是写出来) |
| `[复盘]` 📝 | 个人 / 职业成长复盘相关,与 `1-meta/gate/` 呼应 |

### 2.3 关联标签

| 标签 | 含义 |
|---|---|
| `[跨主题]` 🔗 | 一份文档关联了多个主题(如 PI+SI+mtp-core 三件套) |
| `[未决]` ❓ | 我有疑问 / 看不懂的地方,需要你确认 |

> ⚠️ **标签不是装饰**:看到 `⚠️[盲点]` 就该停下想 1 分钟"这是不是我真的忽略了";看到 `[未决]❓` 就该回答它,而不是跳过。

---

## 3. 目录导航

```
_curated/
├── README.md                          ← 你正在看
├── 00-inventory.md                    ← 全工程内容总盘点 (从这里开始)
│
├── summaries/                         ← 基于现有素材的整合提炼
│   ├── pi-platform-deep-dive.md       ← MTP-Core / PI 现状 / PI 4.0 重构 / SI 三方对比 [跨主题]🔗
│   ├── mtp-core-framework.md          ← MTP-Core/TAF Core 框架 设计精华 + 缺陷反思 (源原 other.md/other2.md)
│   ├── postgresql-knowledge.md        ← PostgreSQL 知识体系 (xmind+SQL+迁移工程)
│   ├── ferretdb-research.md           ← FerretDB Windows 调研归档(技术结论 + 简历版)
│   ├── snmp-zero-engine.md            ← SNMP 协议族 + MIB 解析 + Zero Engine 信号告警流
│   └── dependency-upgrade.md          ← 大版本依赖升级方法论(SI 4.1 经验沉淀)
│
├── expansions/                        ← 素材稀缺,我替你补充
│   ├── maven-essentials.md            ← Maven 基础(原 file/3-tech_stack/build/maven.md 仅 1 行 todo)
│   ├── linux-filesystem-and-perms.md  ← Linux 文件系统 + 权限(扩展原 linux-privilege.md)
│   └── snmp4j-quickref.md             ← SNMP4J 速查(原 file/3-tech_stack/protocol/SNMP4J.md 仅 1 行 todo)
│
├── career/                            ← 工作 / 项目经历的简历版【你特别要求】
│   ├── resume-projects.md             ← 直接可用的简历项目段(STAR 法则 + 量化)
│   ├── interview-talking-points.md    ← 面试可讲的技术点(按主题/按项目分类)
│   └── growth-and-feedback.md         ← 成长复盘 + 你 pre_action.md 末尾 3 个问题的回答框架
│
└── gaps/
    └── still-missing.md               ← 还需要你补充才能总结的内容(我视角清单)
```

---

## 4. 推荐阅读顺序

**目的不同,顺序不同**:

### 4.1 想了解"我盘点出了什么" → 30 分钟

1. `00-inventory.md` (核心)
2. `gaps/still-missing.md`
3. 浏览 `summaries/` 各文件的开头(每个文件第一段都有"这份文档讲什么、来自哪些素材")

### 4.2 想准备面试 / 更新简历 → 1 小时

1. `career/resume-projects.md` ⭐ (最重要)
2. `career/interview-talking-points.md`
3. `summaries/pi-platform-deep-dive.md` (PI 重构是你最大的差异化)
4. `summaries/ferretdb-research.md`(已经写好可用的简历段)

### 4.3 想把工程的"盲点"补齐 → 2-3 小时

1. `gaps/still-missing.md`
2. `expansions/maven-essentials.md`
3. `expansions/linux-filesystem-and-perms.md`
4. `expansions/snmp4j-quickref.md`
5. `career/growth-and-feedback.md`(回答你 `pre_action.md` 末尾的 3 个问题)

### 4.4 想深入某个技术领域 → 各按需阅读

- 平台架构:`summaries/pi-platform-deep-dive.md` → `file/2-projects/vertiv/refactor_pi/docs/`
- 数据库:`summaries/postgresql-knowledge.md` → `_build/outlines/3-tech_stack/database/postgresql/postgresql.outline.md`
- SNMP:`summaries/snmp-zero-engine.md` → `_build/outlines/3-tech_stack/protocol/SNMP.outline.md`

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
- 如果新增了 `file/` 下的素材,可以让我"重新审视 `_curated/` 是否需要更新",而不是默默累积差异。
- `gaps/still-missing.md` 是动态的——你补一项,我们就划掉一项。

---

> **下一步**:从 [`00-inventory.md`](./00-inventory.md) 开始。
