# 全工程状态盘点与待办清单 (Todo & Status)

> **最后更新**：2026-06-13
> **用途**：全面归纳当前工程中已完成、未完成、需要用户确认/修订的事项，以及 AI 建议新增的强化内容。
> **位置**：工程根目录 `todo-and-status.md`

---

## 一、 已完成 / 已存在的内容 (Completed & Existing)

目前工程已经建立了非常完备的“动静分离”和“AI 友好”的结构，以下内容已完全就绪：

### 1. 核心框架与自动化
- **`docs/context-snapshot.md`**：项目上下文快照已建立，新会话启动时可秒级恢复上下文。
- **自动化大纲转换（`_build/`）**：通过 `extract-xmind.ps1` 和 `extract-drawio.ps1` 脚本，成功将二进制脑图和流程图转换为纯文本大纲（Outline），使 AI 能够深度理解业务。
- **双套标签体系**：
  - `origin/` 下的 `.md` 首行采用 HTML 注释进行来源分类（`[原]`、`[整]`、`[摘]`），不污染排版且便于检索。
  - `_curated/` 下采用状态标签（`[就绪]`、`[需补充]`）和价值标签（`[简历亮点]⭐`、`[面试高频]🎯`、`[盲点]⚠️`）。

### 2. 简历与项目提炼（`_curated/`）
- **`projects/asp-platform.md`**：中移 ASP 平台核心技术提炼（4 大模块、10 大面试题、简历段）。
- **`projects/ferretdb-research.md`**：FerretDB Windows 原生编译与可行性调研归档。
- **`projects/snmp-zero-engine.md`**：SNMP 协议族与 Zero Engine 信号告警流深度分析。
- **`projects/dependency-upgrade.md`**：大版本依赖升级方法论（SI 4.1 经验沉淀）。
- **`career/resume-projects.md`**：基于 STAR 法则的简历项目段，包含 Vertiv 和 ASP 平台的核心子项目（目前处于 `[TODO]` 待填状态）。
- **`career/talking-2026-leader-feedback.md`**：2026 春节后第二年谈话深度提炼（调薪、培养方向、行动清单）。

### 3. 技术栈深度文档（`tech-stack/`）
- **`tech-stack/00-skill-roadmap.md`**：P6+/P7 进阶补强总索引与优先级路线图。
- **`tech-stack/java/java-study.md`**：由 103 页 PDF 转写的高质量 Java 核心知识库。
- **`tech-stack/java/jvm-and-concurrency.md`**：JVM 内存、GC、JMM、锁升级、AQS 深度文档。
- **`tech-stack/java/spring-internals.md`**：Spring Bean 生命周期、循环依赖、AOP 源码解析。
- **`tech-stack/database/mysql-deep-dive.md`**：MySQL 锁机制、MVCC、主从复制原理。
- **`tech-stack/cache/redis-deep-dive.md`**：Redis 底层数据结构、持久化、集群架构。
- **`tech-stack/middleware/mq-essentials.md`**：MQ 三大问题（可靠性/顺序/重复）与 Kafka 架构。
- **`tech-stack/protocol/network-essentials.md`**：TCP 三/四次握手、HTTPS、WebSocket 协议。
- **`tech-stack/engineering/testing-and-engineering.md`**：单元测试、Git 工作流、Code Review 规范。
- **`tech-stack/system-design-primer.md`**：系统设计 7 步法与经典题型。

---

## 二、 待办 / 未完成的内容 (Pending & To-Do)

以下是工程中目前搭建了大纲，但内容仍处于空壳或需要进一步填充的“硬骨头”：

### 1. 核心项目笔记填充
- **`origin/2-projects/vertiv/SI/experiences/v4.0/SI4.0.md`**：目前仅有大纲和少量 bullet，需要基于 `discovery.md` 和 `zero-engine-analysis.md` 的素材进行内容充实。
- **`origin/2-projects/vertiv/SI/experiences/v4.0.1/SI4.0.1.md`**：性能测试场景、压测工具、RDU 模拟器故障注入等章节需要填充。
- **`origin/2-projects/vertiv/SI/experiences/v4.1/SI4.1.md`**：SCID-Fath 跨团队冲突解决细节、硬件搭建过程需要进一步展开。
- **`origin/2-projects/vertiv/Tool/DriverHub.md`**：作为简历亮点之一，目前仅有几行点列，需要展开其设计架构与实现细节。

### 2. 基础边缘补丁
- **`tech-stack/os/linux/linux-privilege.md`**：Linux 权限与文件系统，目前标记为 `[需补充]`。
- **`tech-stack/engineering/maven-essentials.md`**：Maven 多模块与依赖管理，需要校对与补充实际经验。

---

## 三、 需要用户确认、归纳与继续修订的内容 (User Decisions)

这部分是 **AI 无法代替你做决定**，或者需要你提供真实数据来“激活”简历亮点的核心部分：

### 1. 简历基础输入（急需确定）
- **求职意向**：期望的岗位级别（P6/P7/高级/资深）与公司类型（国内大厂/外企/出海/国企）。
- **求职状态**：目前是准备**内部 Talent Review**（语言偏内敛、重结果），还是准备**对外投递**（去 Vertiv 术语化、重普适性）。
- **优势与弱项**：你最不想被问到的“痛点”（如算法、高并发），以及你最擅长的“护城河”（如干净代码、复杂业务拆解）。

### 2. 核心项目量化数据（急需补齐）
打开 `_curated/career/resume-projects.md`，搜索 `[TODO:`，你需要补齐以下关键指标：
- **团队规模**：SI/PI 团队的后端、前端、测试人数。
- **设备发现（SI 4.0）**：扫描 N 个 IP 段的设备发现耗时，从旧方案的 `X ms` 降到新方案的 `Y ms`。
- **信号采集（SI 4.0）**：Zero Engine 支撑的每分钟数据点写入吞吐量。
- **备份恢复（SI 4.0.1）**：在 1.2 亿行（8.8G）和 10 亿行（56.1G）数据下的实际备份与恢复耗时。
- **大版本升级（SI 4.1）**：Hazelcast 3→5 升级涉及的 API 修改处数量；升级后服务启动时间提升百分比、内存下降百分比。
- **中移 ASP 平台**：
  - 服务的用户/客户规模、日均订单数、峰值 QPS。
  - dbproxy 实际处理的跨库 SQL 数量、涉及的表数量。
  - 存量数据同步最终采用的替代方案。
  - 聚餐时 Leader 提到你作为“救火员”的 1-2 个具体救火案例。

---

## 四、 AI 建议新增 / 强化的内容 (AI Recommendations)

> 💡 以下内容前均带有 `[AI provide]` 标签，代表 AI 建议在后续周末或空闲时间，由 AI 协助你逐步构建并加入工程的模块，旨在极大提升你的面试通过率与工程安全性。

### 1. 安全与工程化
- **`[AI provide]` 脚本安全防线（PowerShell Git 钩子）**：
  - **内容**：在 `_build/` 脚本中加入 Git 状态检查逻辑，若有未提交的改动则拒绝执行，防止再次发生类似 ASP 原始文件被误覆盖丢失的惨剧。
- **`[AI provide]` 跨文档双向链接校验脚本**：
  - **内容**：编写一个轻量级 Python 脚本，自动校验 `tech-stack/` 中的理论知识与 `_curated/projects/` 中的实战案例之间的双向超链接是否有效，确保知识库的网状结构不中断。

### 2. 求职与面试补强
- **`[AI provide]` 核心项目“压力面试”自测题库**：
  - **内容**：基于你简历中的 8 个核心子项目（如 @RedisLock 切面、dbproxy 自研代理、Hazelcast 升级、FerretDB 调研），模拟大厂/外企面试官的刁钻视角，生成一份“追问到底”的模拟题库。
  - **示例**：“你提到 @RedisLock 切面优先级高于事务切面，那如果事务在提交时失败了，锁已经释放了，怎么防止并发问题？如果 Redis 发生主从切换，锁丢了怎么办？”
- **`[AI provide]` 中英文技术博客与设计文档（RFC）输出模板**：
  - **内容**：针对外企（如 Vertiv 内部）和开源社区，提供一套标准的 RFC（Request for Comments）设计文档模板和中英文技术博客写作脚手架。
  - **目的**：方便你将 FerretDB 调研、大版本升级等极具价值的经历，转化为中英文博客或公司内部的标杆文档，呼应 L 反馈中提到的“专业英语与技术写作”硬指标。

### 3. 算法与系统设计实操
- **`[AI provide]` LeetCode 高频 100 题精选打卡表**：
  - **内容**：在 `tech-stack/00-skill-roadmap.md` 基础上，精选 100 道国内大厂（字节/美团/阿里）最常考的算法题，按数据结构分类，并在工程中建立一个极简的 Markdown 打卡表格。
- **`[AI provide]` 系统设计（System Design）实战映射表**：
  - **内容**：将 `system-design-primer.md` 中的系统设计理论（如 Rate Limiter、Notification System），直接映射到你 Vertiv 的 Zero Engine 告警推送系统和 ASP 平台的订单中心，教你如何在面试中把“系统设计题”引向“你的项目实战”。
