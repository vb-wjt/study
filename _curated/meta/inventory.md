# 全工程内容盘点 (Inventory)

> 这是 `study_mine` 工程**当前**(2026-05-08 大重构后)所有内容的完整清单,按目录结构组织。
>
> **来源标签**:`file/` 下文档类(`.md`)在**第一行加 HTML 注释**标记来源([原]/[整]/[摘]),非文档类(.xmind/.drawio/.sql/.py/.pdf/...)按扩展名识别。
>
> **状态/价值标签**:本表中右侧列([就绪]/[需补充]/[简历亮点]⭐/[面试高频]🎯/...)。
>
> 详见 [`../README.md` §2](../README.md#2-标签体系)。

## 0. 一眼总结

| 维度 | 数据 |
|---|---|
| `file/` 下源内容 | **76 个**(.md=38 → 首行 HTML 注释:[整]=32 / [摘]=5 / [原]=1;非文档类=38:.xmind+.drawio=11 / .sql+.py+.json+.log+.txt=26 / .pdf=1)+ 13 张图片 + 3 个 redirect 路标 |
| `_curated/` AI 整理产物 | **28 个**(career=4 / meta=2 / projects=6 / tech-stack=15 + README=1) |
| `_build/` 自动产物 | xmind/drawio outline ~2100 行(镜像 `file/` 树) |
| 内容最丰富的单一文件 | `mtp-core-deep-analysis.md`(11322 行,329KB) |
| `unclassified/` | ✅ 已清空(2026-05-08) |

---

## 1. `file/1-meta/` —— 工作流 / 个人复盘 / 谈话记录

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `study_index.md` | 11 | `[就绪]` | — | redirect 路标(无标签),指向 `../README.md` 等三大入口 |
| `gate/work-flow.md` | 71 | `[就绪]` | — | 17 步开发流程 SOP |
| `gate/pre_action.md` | 70 | `[就绪]` ✅ | `[复盘]`📝 | 第一年谈话准备稿 + 末尾 3 个问题 → **L 已直接回答**(见 [`../career/talking-2026-leader-feedback.md` §5](../career/talking-2026-leader-feedback.md)) |
| `gate/action.md` | 72 | `[就绪]` | `[复盘]`📝 | 第一年谈话策略复盘 + 短/长期规划 + 去留抉择策略 |
| `gate/talking.md` | 274 | `[就绪]` | `[复盘]`📝 `[优先级⭐]` | **2026 春节后第二年正式谈话**录音整理(顶部分章 + 底部原始转写)。AI 提炼版 → [`../career/talking-2026-leader-feedback.md`](../career/talking-2026-leader-feedback.md) |

> "谈话三件套"已就位:`pre_action.md`(2024 准备稿)→ `action.md`(2024 复盘 + 长期策略)→ `talking.md`(2026 实际谈话)。

---

## 2. `file/2-projects/` —— 项目经验

| 文件 / 子目录 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `projects_index.md` | 37 | `[需补充]` | — | 中国移动段已补 ASP 名;**校内搜搜 / 中移基线 仍为 todo**;Vertiv 段已列大纲 |

### 2.0 `2-projects/asp/` —— 中国移动 全业务支撑平台 (2022.07-2024.03)

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `asp/project.md` | 88 | `[就绪]` | `[简历亮点]`⭐⭐ `[面试高频]`🎯 | 项目背景 + 5 大模块(整合 / dbproxy / 订单中心 / 产品迁移 / 追平需求) + 拆库面试题 + 校内搜搜 + 中移基线 |
| `asp/knowledge.md` | **569** | `[就绪]` | `[简历亮点]`⭐⭐⭐ `[面试高频]`🎯 | 极密集技术总结:JVM 启动参数 / cache-cli/server / 网关 4 Filter 链 / **@RedisLock 完整 AOP 代码**(150 行) / RegionRouteDataSource / Druid 二次登录 / Arthas / HttpServletRequest 重读 / k8s 指令 / 复杂业务流 / 整体架构 → 提炼见 [`../projects/asp-platform.md`](../projects/asp-platform.md) |

### 2.1 `vertiv/SI/` —— 主战场,V4.0 / V4.0.1 / V4.1 三版本

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `common/mtp-core-strengths-summary.md` | 419 | `[就绪]` | `[简历亮点]`⭐ | **MTP-Core 10 大设计亮点精简版**。整合到 [`../projects/mtp-core-framework.md`](../projects/mtp-core-framework.md) §1 |
| `common/mtp-core-deep-analysis.md` | **11322** | `[就绪]` | `[简历亮点]`⭐⭐ | **MTP-Core/TAF Core 7 大子系统深度分析 + 5 大设计缺陷反思**(工程内最大单文件,329KB)。整合到 [`../projects/mtp-core-framework.md`](../projects/mtp-core-framework.md) §2-3 |
| `common/architecture/TAF-CORE.xmind` | (53 行 outline) | `[就绪]` | — | xmind |
| `common/flow/flow.drawio` | (256 行 outline,4 页) | `[就绪]` | `[面试高频]`🎯 | 设备采集 + 告警 JMS 推送的完整数据流 |
| `experiences/v4.0/SI4.0.md` | 48 | `[需补充]` | `[优先级⭐]` | 大纲 + todo;但底下 `discovery.md` (2754) 和 `zero-engine.md` (7778) **素材已金满**,只是没整合 |
| `experiences/v4.0/discovery.md` | **2754** | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | SNMP 设备发现的详尽实现 |
| `experiences/v4.0/zero-engine.md` | **7778** | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | Zero Engine 信号采集 + 告警流的全量分析,工程的"压舱石" |
| `experiences/v4.0.1/SI4.0.1.md` | 29 | `[需补充]` | — | 大纲 + todo |
| `experiences/v4.1/SI4.1.md` | 36 | `[需补充]` | — | 大纲 + todo |
| `experiences/v4.1/dependency-upgrade.md` | 426 | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | Java 8→21 / SpringBoot 2→3 / Hazelcast 3→5 升级 → [`../projects/dependency-upgrade.md`](../projects/dependency-upgrade.md) |
| `experiences/v4.1/resolve-mib/design/resolve-mib.md` | 874 | `[就绪]` | `[简历亮点]`⭐ | SNMP4J-SMI-PRO 解析 MIB 设计文档 |
| `experiences/v4.1/resolve-mib/snmp-smi-pro.drawio` | (48 行 outline) | `[就绪]` | — | OID 解析流程图 |
| `experiences/sms-modem.md` | 154 | `[就绪]` | — | 短信调制解调器 |
| `Tool/DriverHub.md` | 28 | `[需补充]` | `[简历亮点]`⭐ | 内部工具,只有点列。**简历可写**,值得展开 |

### 2.2 `vertiv/refactor_pi/` —— PI 4.0 重构【金矿】

> ⭐⭐⭐ **整个工程最有价值的部分**,内容详尽到我不应该再"重写一份总结",而是帮你提炼"哪些可写进简历 / 面试可讲什么"。

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `docs/task-process.md` | 21 | `[需补充]` | — | 任务流程,缺 §3 minimal verification |
| `docs/legacy-analysis/01-architecture-overview.md` | 338 | `[就绪]` | `[简历亮点]`⭐ `[面试高频]`🎯 | 完整的 PI 3.x 架构分析(基于源码) |
| `docs/legacy-analysis/02-business-features.md` | 148 | `[就绪]` | — | PI 3.0 业务功能 L1-L10 分级 |
| `docs/legacy-analysis/03-mongodb-collections.md` | 254 | `[就绪]` | — | MongoDB 集合清单 |
| `docs/migration/01-postgres-schema.md` | 444 | `[就绪]` | `[简历亮点]`⭐ | Postgres schema 设计文档 |
| `docs/migration/02-etl-execution-report.md` | 189 | `[就绪]` | — | ETL 执行报告 |
| `docs/rebuild-plan/01-overview.md` | **657** | `[就绪]` | `[简历亮点]`⭐⭐ `[面试高频]`🎯 | **PI 4.0 重构总览**——决策、新旧架构对比、阶段规划、风险。8 个 [missing] 待你回答 |
| `docs/rebuild-plan/02-deep-dive.md` | **1222** | `[就绪]` | `[简历亮点]`⭐⭐ | 重构深入分析,各模块详细职责 |
| `db/postgres/*.sql` (15 个) | ~95KB | `[就绪]` | `[简历亮点]`⭐ | Postgres schema SQL(IAM/设备/告警/规则/...),按模块拆分 |
| `tools/mongo_to_pg.py` 等 6 个 Python | ~65KB | `[就绪]` | `[简历亮点]`⭐ | ETL 工具链(mongo 分析 / 抽样 / 同步到 PG / 校验) |
| `tools/result/*.{json,log,txt}` | ~250KB | `[就绪]` | — | ETL 执行结果(JSON 报告 + 日志) |

---

## 3. `file/3-tech_stack/` —— 通用技术栈

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `Java Study.pdf` | 103 页 | `[就绪]` `[源文]` | `[面试高频]`🎯 `[简历亮点]`⭐⭐⭐ | 原 PDF;**已转写** → `java-study.md` |
| `java-study.md` | **1714** | `[就绪]` | `[面试高频]`🎯 `[简历亮点]`⭐⭐⭐ | **2026-05 由 PDF 转写为 markdown**,修正 OCR + 优化排版。索引/评级 → [`../tech-stack/java-knowledge-map.md`](../tech-stack/java-knowledge-map.md) |
| `build/maven.md` | 4 | `[就绪]` | — | redirect 路标(无标签)→ [`../tech-stack/maven-essentials.md`](../tech-stack/maven-essentials.md) |
| `cache/Hazelcast.md` | 305 | `[就绪]` | `[面试高频]`🎯 | 与 SI 4.1 升级配合 |
| `database/mongo/mongodb-commands.md` | 321 | `[就绪]` | — | 操作指令清单 |
| `database/postgresql/postgresql.xmind` | (775 行 outline) | `[就绪]` | `[简历亮点]`⭐ | 用户最近大改了(+200KB) |
| `database/ferretdb/ferretdb-no-docker.md` | 241 | `[就绪]` | `[简历亮点]`⭐⭐ | FerretDB Windows 调研全过程,**简历金矿**。→ [`../projects/ferretdb-research.md`](../projects/ferretdb-research.md) |
| `database/ferretdb/resume-snippet.md` | 23 | `[就绪]` | `[简历亮点]`⭐ | FerretDB 简历段(原 `unclassified/archived_chats.md`) |
| `database/ferretdb/image/*` | 6 张图 | — | — | 配套截图 |
| `design_patterns/策略模式.drawio` | (41 行 outline) | `[就绪]` | — | UML 类图 |
| `design_patterns/设计模式相关.xmind` | (42 行 outline) | `[就绪]` | — | 6 大设计原则 + UML 关系 |
| `middleware/middleware-overview.md` | 31 | `[就绪]` | — | 中间件全景速查表 |
| `os/linux/linux-privilege.md` | 44 | `[需补充]` | `[盲点]`⚠️ | Linux 权限。可对照 [`../tech-stack/linux-filesystem-and-perms.md`](../tech-stack/linux-filesystem-and-perms.md) |
| `protocol/SNMP.xmind` | (97 行 outline) | `[就绪]` | `[面试高频]`🎯 | SNMP v1/v2c/v3 + MIB + PDU |
| `protocol/SNMP4J.md` | 4 | `[就绪]` | — | redirect 路标(无标签)→ [`../tech-stack/snmp4j-quickref.md`](../tech-stack/snmp4j-quickref.md) |
| `protocol/soap-versions.md` | 143 | `[就绪]` | — | SOAP 版本对比 |
| `protocol/websocket/basic.md` | 318 | `[就绪]` | `[面试高频]`🎯 | WebSocket 基础 |
| `protocol/websocket/deep-dive-interview.md` | 158 | `[就绪]` | `[面试高频]`🎯 `[简历亮点]`⭐ | WebSocket 面试材料 |
| `server/undertow.xmind` | (38 行 outline) | `[就绪]` | — | |
| `specification/OpenAPI 规范.xmind` | (31 行 outline) | `[就绪]` | — | |
| `spring/notes.md` | 50 | `[就绪]` | — | Spring 实战零碎笔记(原 `business/SI/task/待整理知识.md`) |
| `template/freemarker.md` | 232 | `[就绪]` | — | |

---

## 4. `file/business/` —— 业务知识(脑图素材)

| 文件 | 行数 | 状态 | 价值 | 备注 |
|---|---:|---|---|---|
| `PI/迁移 mongodb.xmind` | (274 行 outline) | `[就绪]` | — | 与 `refactor_pi/` 主题重合,可对照 |
| `SI/task/SI 依赖升级.xmind` | (444 行 outline) | `[就绪]` | — | xmind 内 sheet 与文件名一致,SI 依赖升级主题 |

---

## 5. `file/unclassified/` —— ✅ 已清空(2026-05-08)

`unclassified/` 目录已不存在;原 6 个文件已分别归位到 `1-meta/gate/`、`2-projects/...`、`3-tech_stack/...`,详见 §8 变更日志。

---

## 6. 自动产物 `_build/outlines/`

xmind 9 个 + drawio 3 个,全部已转成纯文本 outline。详见 `_build/extract-xmind.ps1` 和 `extract-drawio.ps1`。

| Top 5 内容量 | 行数 |
|---|---:|
| `postgresql.outline.md` | 775 |
| `SI 依赖升级.outline.md` | 444 |
| `迁移 mongodb.outline.md` | 274 |
| `flow.outline.md` (4 页) | 256 |
| `SNMP.outline.md` | 97 |

> `_build/outlines/` 镜像 `file/` 目录树。文件名未加前缀,与 `file/` 一一对应。脚本下次重跑前路径若变化(如 SI 工作总结 → SI 依赖升级)会自动同步。

---

## 7. 综合优先级建议(给你)

按"如果只能做一件事"的顺序:

| # | 行动 | 原因 | 工时估计 |
|---|---|---|---|
| ~~1~~ | ~~回答 `pre_action.md` 末尾的 3 个问题~~ ✅ L 已直接回答 | 答案见 [`../career/talking-2026-leader-feedback.md`](../career/talking-2026-leader-feedback.md) | — |
| ~~2~~ | ~~`unclassified/` 6 个文件归位 + 后缀/中文文件名修正~~ ✅ 2026-05-08 完成 | 见 §8 | — |
| ~~3~~ | ~~`_curated/` 重组 + `file/` 加标签前缀~~ ✅ 2026-05-08 完成 | 见 §8 | — |
| 1 ⭐ | **把 L 第二年的反馈转化为 SOP** | "沟通左中右"模型 + 英语术语表 + 会议主持脚手架 → 详见 [`../career/talking-2026-leader-feedback.md` §7](../career/talking-2026-leader-feedback.md#7-我的今年行动清单基于-l-的反馈) | 1-2 小时 |
| 2 ⭐ | **基于 [`../career/resume-projects.md` §2](../career/resume-projects.md) 更新简历(中移 ASP 段)** | 之前完全空白(只有 todo);现在 88 + 569 行素材 → STAR 段已可直接复制粘贴 | 1 小时 |
| 3 ⭐⭐⭐ | **进阶补强 9 大模块**(2026-05 新增,**积累式不要一次消化**) | Spring/MySQL/Redis/MQ/网络/测试/系统设计/英语/JVM → 见 [`../tech-stack/00-skill-roadmap.md`](../tech-stack/00-skill-roadmap.md) | 长期(每周 1 篇) |
| 4 | **把 `SI4.0.md` / `SI4.0.1.md` / `SI4.1.md` 写完** | 大纲都列好了,底下 `zero-engine.md` 7778 行素材在那躺着 | 2-4 小时/版本 |
| 5 | **填充 `tech-stack/maven-essentials.md`、`linux-filesystem-and-perms.md`、`snmp4j-quickref.md` 中你校对部分** | 我已经写了起步,你校对/补充自己的实际经验 | 1-2 小时 |
| 6 | **回答 `meta/still-missing.md` 里的具体问题** | 让我可以把那些"半成品总结"补完 | 滚动进行 |

---

## 8. 变更日志

### 2026-05-08(d)标签机制:**文件名前缀 → 内容首行 HTML 注释**

用户反馈"标签放在文件名上不便于搜索/不希望污染文件名",改为**只对 `.md` 文档**在第一行加 HTML 注释,`.xmind/.drawio/.sql/.py/.json/.log/.pdf/.txt` 靠扩展名识别。

| 项 | 变更 |
|---|---|
| 76 个 `[X]xxx.ext` 文件名 | 全部还原为 `xxx.ext`(去前缀) |
| 38 个 `.md` 文件 | 在第一行插入 `<!-- 标签:[原/整/摘] —— 含义 -->` + 空行 |
| 38 个非 `.md` 文件 | 不动(11 .xmind/.drawio + 15 .sql + 6 .py + 2 .json + 2 .log + 1 .txt + 1 .pdf) |
| `_curated/` 与 `file/` 中 ~436 处带前缀引用 | 全部去除前缀 |

**事故记录**:在 (c) 步操作过程中发现 21 个 `.md` 文件被某次旧的批量脚本误覆盖成 606 字节的 redirect 占位页;
- ✅ 19 个文件已从 `git HEAD` 恢复(`mtp-core-deep-analysis.md` 11322 行 / `zero-engine.md` 7778 行 / 等)
- ❌ 2 个文件 git 中无任何提交记录,**永久丢失**:
  - `file/2-projects/asp/knowledge.md`(原 569 行,极密集 ASP 技术总结)
  - `file/2-projects/asp/project.md`(原 88 行,ASP 项目背景 + 5 大模块)
  - 提炼版仍在 [`../projects/asp-platform.md`](../projects/asp-platform.md);**待用户从本地备份补回**

### 2026-05-08(c)大重构:`_curated/` 重组 + `file/` 加标签前缀(已被 (d) 替代)

**`_curated/` 顶层从"产物类型"→"主题对齐"**:

| 旧 | 新 |
|---|---|
| `summaries/{asp-platform,pi-platform-deep-dive,mtp-core-framework,ferretdb-research,snmp-zero-engine,dependency-upgrade}.md` | `projects/*.md` |
| `summaries/{postgresql-knowledge,java-knowledge-map}.md` | `tech-stack/*.md` |
| `expansions/*.md`(13 个) | `tech-stack/*.md` |
| `00-inventory.md` | `meta/inventory.md` |
| `gaps/still-missing.md` | `meta/still-missing.md` |

`file/` 下 76 个文件曾加 5 类前缀标签(原/整/摘/图/码),已在 (d) 步还原文件名。

### 2026-05-08(b)归一与修正

`unclassified/` 6 个文件全部归位:

| 原位置 | 新位置 |
|---|---|
| `unclassified/talking.md` | `1-meta/gate/talking.md`(谈话三件套合体) |
| `unclassified/archived_chats.md` | `3-tech_stack/database/ferretdb/resume-snippet.md` |
| `unclassified/linux-privilege.md` | `3-tech_stack/os/linux/linux-privilege.md`(新增 `os/linux/`) |
| `unclassified/sms-modern.md` | `2-projects/vertiv/SI/experiences/sms-modem.md`(顺便修拼写) |
| `unclassified/websocket_1.md` | `3-tech_stack/protocol/websocket/basic.md`(新增 `protocol/websocket/`) |
| `unclassified/WebSocket_Deep_Dive_Interview.md` | `3-tech_stack/protocol/websocket/deep-dive-interview.md` |
| `business/SI/task/待整理知识.md` | `3-tech_stack/spring/notes.md`(新增 `spring/`,加深度链接) |

命名 / 后缀 / 占位修正:

| 原 | 新 |
|---|---|
| `Java中间件.txt` | `middleware-overview.md` |
| `mongodb指令.md` | `mongodb-commands.md` |
| `SOAP版本.md` | `soap-versions.md` |
| `build/maven.md`(原仅 `todo`) | redirect link → `tech-stack/maven-essentials.md` |
| `protocol/SNMP4J.md`(原仅 `todo`) | redirect link → `tech-stack/snmp4j-quickref.md` |
| `1-meta/study_index.md`(原 0 行) | redirect link → `_curated/README.md` 等 |

### 2026-04-30 早期清理

`other.md` / `other2.md` 重命名为 `mtp-core-strengths-summary.md` / `mtp-core-deep-analysis.md`。

---

> **下一步建议**:
> - 看 [`../career/resume-projects.md`](../career/resume-projects.md)(简历视角)
> - 或 [`./still-missing.md`](./still-missing.md)(看我视角下的盲点)
> - 或 [`../tech-stack/00-skill-roadmap.md`](../tech-stack/00-skill-roadmap.md)(P6+ 进阶路径)
