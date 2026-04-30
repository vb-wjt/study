# 全工程内容盘点 (Inventory)

> 这是 `study_mine` 工程当前(2026-04-30)所有内容的**完整清单**,按目录结构组织,每份素材都打了状态标签 + 价值标签。
>
> 标签含义见 [`README.md` §2](./README.md#2-标签体系)。

## 0. 一眼总结

| 维度 | 数据 |
|---|---|
| 源内容(`file/` 下) | **md/txt 共 30 个**(总 ~2000 行有效内容) + **xmind 8 个** + **drawio 3 个** + 各种图片/SQL/Python 工具 |
| 自动产物(`_build/outlines/`) | xmind 解析后 **1754 行** + drawio 解析后 **345 行** = **2099 行**纯文本大纲 |
| AI 整理产物(`_curated/`) | 见目录 (本目录所有文件) |
| 内容最丰富的单一主题 | **PI 4.0 重构** (`refactor_pi/` 下 ~2500 行 docs + 15 个 SQL + 6 个 Python ETL 工具) |
| 完全空 / 仅 todo 的文件 | 5 个(`maven.md`、`SNMP4J.md`、`待整理知识.md`、`study_index.md`、`projects_index.md` 部分段) |

---

## 1. `file/1-meta/` —— 工作流 / 个人复盘

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `study_index.md` | **0** | `[待开始]` | `[优先级⭐]` | 整个知识库的根索引,**完全空**。但 `_curated/` 已经替你建了导航 |
| `gate/work-flow.md` | 30 | `[就绪]` | — | 17 步开发流程 SOP |
| `gate/pre_action.md` | 51 | `[需补充]` | `[复盘]`📝 `[优先级⭐]` | 末尾新增了 3 个**未回答的问题**(项目经理沟通 / 例会表达 / 怎么更进一步) → 见 [`career/growth-and-feedback.md`](./career/growth-and-feedback.md) |
| `gate/action.md` | 63 | `[就绪]` | `[复盘]`📝 | V 型反转复盘 + 短/长期规划 + 去留抉择策略 |

---

## 2. `file/2-projects/` —— 项目经验

| 文件 / 子目录 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `projects_index.md` | 28 | `[需补充]` | — | "校内搜搜 / 中国移动" 段为 todo;Vertiv 段已列大纲 |

### 2.1 `vertiv/SI/` —— 主战场,V4.0 / V4.0.1 / V4.1 三版本

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `common/mtp-core-strengths-summary.md` ✏️ | 338 | `[就绪]` | `[简历亮点]`⭐ | **MTP-Core 10 大设计亮点精简版**(原名 `other.md`,2026-04-30 重命名)。整合到 [`summaries/mtp-core-framework.md`](./summaries/mtp-core-framework.md) §1 |
| `common/mtp-core-deep-analysis.md` ✏️ | **10299** | `[就绪]` | `[简历亮点]`⭐⭐ | **MTP-Core/TAF Core 7 大子系统深度分析 + 5 大设计缺陷反思**(原名 `other2.md`,2026-04-30 重命名)。整合到 [`summaries/mtp-core-framework.md`](./summaries/mtp-core-framework.md) §2-3 |
| `common/architecture/TAF-CORE.xmind` | (53 行 outline) | `[就绪]` | — | 通过 [`_build/outlines/.../TAF-CORE.outline.md`](../_build/outlines/2-projects/vertiv/SI/common/architecture/TAF-CORE.outline.md) 可读 |
| `common/flow/flow.drawio` | (256 行 outline,4 页) | `[就绪]` | `[面试高频]`🎯 | 设备采集 + 告警 JMS 推送的完整数据流 → outline |
| `experiences/v4.0/SI4.0.md` | 37 | `[需补充]` | `[优先级⭐]` | 大纲 + todo;但底下 `discovery.md` (2401 行) 和 `zero-engine.md` (6514 行) **素材已金满**,只是没整合 |
| `experiences/v4.0/discovery.md` | **2401** | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | SNMP 设备发现的详尽实现 |
| `experiences/v4.0/zero-engine.md` | **6514** | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | Zero Engine 信号采集 + 告警流的全量分析,工程的"压舱石" |
| `experiences/v4.0.1/SI4.0.1.md` | 21 | `[需补充]` | — | 大纲 + todo |
| `experiences/v4.1/SI4.1.md` | 27 | `[需补充]` | — | 大纲 + todo |
| `experiences/v4.1/dependency-upgrade.md` | 352 | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | Java 8→21 / SpringBoot 2→3 / Hazelcast 3→5 升级 |
| `experiences/v4.1/resolve-mib/design/resolve-mib.md` | 754 | `[就绪]` | `[简历亮点]`⭐ | SNMP4J-SMI-PRO 解析 MIB 设计文档 |
| `experiences/v4.1/resolve-mib/snmp-smi-pro.drawio` | (48 行 outline) | `[就绪]` | — | OID 解析流程图 |
| `Tool/DriverHub.md` | 18 | `[需补充]` | `[简历亮点]`⭐ | 内部工具,只有点列。**简历可写**,值得展开 |

### 2.2 `vertiv/refactor_pi/` —— PI 4.0 重构【金矿】

> ⭐⭐⭐ **整个工程最有价值的部分**,内容详尽到我不应该再"重写一份总结",而是帮你提炼"哪些可写进简历 / 面试可讲什么"。

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `docs/task-process.md` | 15 | `[需补充]` | — | 任务流程,缺 §3 minimal verification |
| `docs/legacy-analysis/01-architecture-overview.md` | **277** | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | 完整的 PI 3.x 架构分析(基于源码) |
| `docs/legacy-analysis/02-business-features.md` | 107 | `[就绪]` | — | PI 3.0 业务功能 L1-L10 分级 |
| `docs/legacy-analysis/03-mongodb-collections.md` | 195 | `[就绪]` | — | MongoDB 集合清单 |
| `docs/migration/01-postgres-schema.md` | **333** | `[就绪]` | `[简历亮点]`⭐ | Postgres schema 设计文档 |
| `docs/migration/02-etl-execution-report.md` | 158 | `[就绪]` | — | ETL 执行报告 |
| `docs/rebuild-plan/01-overview.md` | **532** | `[就绪]` | `[简历亮点]`⭐⭐ `[面试高频]`🎯 | **PI 4.0 重构总览**——决策、新旧架构对比、阶段规划、风险。8 个 [missing] 待你回答 |
| `docs/rebuild-plan/02-deep-dive.md` | **916** | `[就绪]` | `[简历亮点]`⭐⭐ | 重构深入分析,各模块详细职责 |
| `db/postgres/*.sql` (15 个) | ~95KB | `[就绪]` | `[简历亮点]`⭐ | Postgres schema SQL(IAM/设备/告警/规则/...),按模块拆分 |
| `tools/mongo_to_pg.py` 等 6 个 Python | ~65KB | `[就绪]` | `[简历亮点]`⭐ | ETL 工具链(mongo 分析 / 抽样 / 同步到 PG / 校验) |
| `tools/result/*` | ~250KB | `[就绪]` | — | ETL 执行结果(JSON 报告 + 日志) |

---

## 3. `file/3-tech_stack/` —— 通用技术栈

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `build/maven.md` | **1** | `[待开始]` | `[盲点]`⚠️ `[优先级⭐]` | 仅 `todo`。Java 后端基础,**面试常问**。→ [`expansions/maven-essentials.md`](./expansions/maven-essentials.md) |
| `cache/Hazelcast.md` | 235 | `[就绪]` | `[面试高频]`🎯 | 与 SI 4.1 升级配合 |
| `database/mongo/mongodb指令.md` | 287 | `[就绪]` | — | 操作指令清单 |
| `database/postgresql/postgresql.xmind` | (775 行 outline) | `[就绪]` | `[简历亮点]`⭐ | 你最近大改了(+200KB),outline 已重新提取 |
| `database/ferretdb/ferretdb-no-docker.md` | **215** | `[就绪]` | `[简历亮点]`⭐⭐ | FerretDB Windows 调研全过程,**简历金矿**。→ [`summaries/ferretdb-research.md`](./summaries/ferretdb-research.md) |
| `database/ferretdb/image/*` | 6 张图 | — | — | 配套截图 |
| `design_patterns/策略模式.drawio` | (41 行 outline) | `[就绪]` | — | UML 类图,关于 GeneratorStrategy |
| `design_patterns/设计模式相关.xmind` | (42 行 outline) | `[就绪]` | — | 6 大设计原则 + UML 关系 |
| `middleware/Java中间件.txt` | 22 | `[需补充]` | — | 4 条 Spring 知识点,**txt 后缀有点可疑** |
| `protocol/SNMP.xmind` | (97 行 outline) | `[就绪]` | `[面试高频]`🎯 | SNMP v1/v2c/v3 + MIB + PDU |
| `protocol/SNMP4J.md` | **1** | `[待开始]` | `[盲点]`⚠️ `[优先级⭐]` | 仅 `todo`。**SI 项目核心依赖**,反而最薄。→ [`expansions/snmp4j-quickref.md`](./expansions/snmp4j-quickref.md) |
| `protocol/SOAP版本.md` | 111 | `[就绪]` | — | |
| `server/undertow.xmind` | (38 行 outline) | `[就绪]` | — | |
| `specification/OpenAPI 规范.xmind` | (31 行 outline) | `[就绪]` | — | |
| `template/freemarker.md` | 175 | `[就绪]` | — | |

---

## 4. `file/business/` —— 业务知识

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `PI/迁移 mongodb.xmind` | (274 行 outline) | `[就绪]` | — | 与 `refactor_pi/` 主题重合,可对照 |
| `SI/task/SI 工作总结.xmind` | (444 行 outline) | `[就绪]` | — | 但 xmind 内部 sheet 名是 "**SI 依赖升级**",**与文件名不一致**(你说去确认) |
| `SI/task/待整理知识.md` | 6 | `[待开始]` | — | 4 条 Spring 零碎点,无展开 |

---

## 5. `file/unclassified/` —— 暂未归类

| 文件 | 行数 | 状态 | 价值 | 建议归类 |
|---|---:|---|---|---|
| `archived_chats.md` | 23 | `[就绪]` | `[简历亮点]`⭐ | FerretDB 调研简历段。**应归到 `3-tech_stack/database/ferretdb/`** |
| `linux-privilege.md` | 35 | `[需补充]` | `[盲点]`⚠️ | Linux 权限。**应归到 `3-tech_stack/os/linux/`**(目前 `3-tech_stack/` 下没有 OS 子类) |
| `sms-modern.md` | 137 | `[就绪]` | — | 短信调制解调器。**应归到 `2-projects/vertiv/SI/experiences/`** 或 `3-tech_stack/protocol/` |
| `websocket_1.md` | 285 | `[就绪]` | `[面试高频]`🎯 | 应归到 `3-tech_stack/protocol/websocket/` |
| `WebSocket_Deep_Dive_Interview.md` | 114 | `[就绪]` | `[面试高频]`🎯 `[简历亮点]`⭐ | 文件名带 "Interview" 标记,本来就是面试材料 |

---

## 6. 自动产物 `_build/outlines/`

xmind 8 个 + drawio 3 个,全部已转成纯文本 outline。详见 [`_build/extract-xmind.ps1`](../_build/extract-xmind.ps1) 和 [`_build/extract-drawio.ps1`](../_build/extract-drawio.ps1)。

| Top 5 内容量 | 行数 |
|---|---:|
| `postgresql.outline.md` | 775 |
| `SI 依赖升级.outline.md` | 444 |
| `迁移 mongodb.outline.md` | 274 |
| `flow.outline.md` (4 页) | 256 |
| `SNMP.outline.md` | 97 |

---

## 7. 综合优先级建议(给你)

按"如果只能做一件事"的顺序:

| # | 行动 | 原因 | 工时估计 |
|---|---|---|---|
| 1 | **回答 `pre_action.md` 末尾的 3 个问题** | 这 3 个问题决定你下半年的发展方向,空着不答=放弃机会 | 30 分钟 |
| ~~2~~ | ~~**重命名 `other.md` / `other2.md`**~~ ✅ 已完成 (2026-04-30) | 已分别改名为 `mtp-core-strengths-summary.md` / `mtp-core-deep-analysis.md`,git 历史保留 | — |
| 3 | **基于 `_curated/career/resume-projects.md` 更新简历** | 你的素材质量已经远超你简历目前在表达的 | 1 小时 |
| 4 | **把 `unclassified/` 5 个文件归位** | 都已经是 `[就绪]` 状态了,只缺一个 `mv` | 10 分钟 |
| 5 | **把 `SI4.0.md` / `SI4.0.1.md` / `SI4.1.md` 写完** | 大纲都列好了,底下 `zero-engine.md` 6500 行素材在那躺着 | 2-4 小时/版本 |
| 6 | **填充 `expansions/maven-essentials.md`、`linux-filesystem-and-perms.md`、`snmp4j-quickref.md`** | 我已经写了起步,你校对/补充自己的实际经验 | 1-2 小时 |
| 7 | **回答 `gaps/still-missing.md` 里的具体问题** | 让我可以把那些"半成品总结"补完 | 滚动进行 |

---

> **下一步建议**:
> - 看 [`career/resume-projects.md`](./career/resume-projects.md)(简历视角)
> - 或 [`gaps/still-missing.md`](./gaps/still-missing.md)(看我视角下的盲点)
