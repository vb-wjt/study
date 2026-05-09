# 还缺什么 (Still Missing)

> 这份清单是 **AI 视角下的盲点 / 待补内容** —— 我之所以无法直接为你总结某个主题,是因为缺了下面这些具体信息。
>
> **使用方式**:你回答其中任意一条,我就能把对应的 summary / expansion 文件补完。
>
> 标签:
> - `[必须]` —— 不补这个,对应文档基本写不出来
> - `[强化]` —— 现在能写出基础版,补了之后能从 60 分到 90 分
> - `[次要]` —— 锦上添花

---

## 1. SI 项目相关 (V4.0 / V4.0.1 / V4.1 三版本)

### 1.1 SI 4.0 `[必须]`

文件 `file/2-projects/vertiv/SI/experiences/v4.0/SI4.0.md` 的大纲列了:
- ✅ SNMP 协议 / SNMP4J / Mongodb (前置知识) ——> 已有素材
- ✅ 设备发现 ——> `discovery.md` 2401 行,**有素材但 SI4.0.md 里只写了 4 个 bullet**
- ✅ Zero Engine 信号采集 + 告警流 ——> `zero-engine.md` 6514 行
- ❓ **信号和告警流图** ——> `flow.drawio` 已经能解析,但 SI4.0.md 没有说明性描述
- ❓ **驱动管理的具体业务规则**:
  - "增:驱动压缩包,加密..." —— **加密怎么做的?用什么算法?谁解密?**
  - "删:失败时只回滚当前驱动相关内容" —— **回滚的具体边界?事务还是补偿?**
  - "改:有设备的时候需要额外处理" —— **额外处理是什么?设备是先迁移还是先重置?**

### 1.2 SI 4.0.1 `[必须]`

文件 `SI4.0.1.md` 21 行,几乎全是 todo。需要回答:
- **性能测试范围**:测了哪些场景?压测工具是什么?基线是什么(QPS / 延迟)?
- **优化方案 - 新索引**:新建了哪些索引?在哪些字段?优化前后的数据(对比 metric)?
- **RDU 模拟器**:模拟什么设备?用什么技术(Java / Python / SNMP4J Agent)?如何注入故障场景?
- **备份恢复**:备份哪些数据(Mongo / 文件 / 配置)?恢复时间(RTO)和数据丢失(RPO)?
- **MongoDB → FerretDB 迁移**:**这部分 `business/PI/迁移 mongodb.xmind` 有覆盖吗?还是 SI 自己有一份?**

### 1.3 SI 4.1 `[必须]`

文件 `SI4.1.md` 27 行,大纲已列。需要回答:
- **解析 MIB 的技术选型**:
  - 为什么选 SNMP4J-SMI-PRO 而不是 Mibble / 自研?(`resolve-mib.md` 754 行有详细方案,但**选型对比理由没明说**)
  - 商业 license 的成本和谁买单?
- **SCID-Fath 是什么**?手册 / 标准里的术语?
- **跨团队合作 / 联调** —— 具体和哪些团队?在哪个环节出现过冲突?怎么解决的?(这是面试常问题)
- **硬件搭建** —— 是 RDU 设备?机柜?机房?需要去现场吗?

### 1.4 关键时间点 / 量化数据 `[强化]`

无论哪个版本,简历都需要量化。我手上找不到:
- 项目周期(开始 - 结束 / GA 时间)
- 团队规模(后端 / 前端 / 测试 各几人)
- 你负责的代码量 / PR 数 / commits 数(粗略即可)
- 性能改进数字(SI 4.0.1 的索引优化,前后对比 ms / QPS)
- Hazelcast 升级后的影响(JAR 大小 / 启动时间 / 内存占用变化)
- 客户规模 / 设备数量(产品已上线后的)

---

## 2. PI 重构相关

### 2.1 你已自答的 `[missing]` `[必须]`

`refactor_pi/docs/rebuild-plan/01-overview.md` 里你自己标了 12 个 `[missing]`,我**先复制过来,等你回答**:

#### §5.3 团队/组织前提
1. 团队规模与构成?(后/前端/测试/DevOps 各几人?)
2. 团队 Java 21 / Spring Boot 3 / Postgres 经验?
3. 团队 Angular 升级经验?
4. 测试自动化能力?(PI 3.x 是否有 E2E 套件?)
5. CI/CD 基础设施?
6. 现网客户数与版本分布?
7. 是否有 PSO(专业服务团队)?

#### §7.2 未决项
4. OpenAPI / WebSocket 契约 owner?
5. 历史数据保留策略(30 天 / 5 年是否需调整)?
6. 现网客户基线?
7. License 文件兼容性(旧 PI 3.x license 能否在 4.0 直接用)?

#### §8.x 我建议补充的考量(已在你文档里列出 12 大类)
> 这些点不是"必须",是 **我希望你心里有数**。详见原文,我不再展开。

### 2.2 我有疑问的 `[强化]`

- `01-overview.md §6.2`:**52-76 有效人月** 这个估算是基于什么样本?是参考过类似规模的重构(SI 4.1 升级?)还是经验拍脑袋?如果有依据,简历可强化;如果是拍脑袋,要小心被面试官追问。
- `02-deep-dive.md` 我没逐行看,如果有让你回头反问"我当初为什么这样设计"的地方,值得回答一下。

### 2.3 `task-process.md` 的 §3 minimal verification `[必须]`

这一章只有 `1.` 没内容。需要补:计划如何做 minimal verification?是否已经做了?结果?

---

## 3. PostgreSQL `[强化]`

### 3.1 `xmind` 大改后的内容

`postgresql.xmind` 你最近大改了(+200KB,从 1280KB 到 1475KB)。outline 已经 775 行,信息很密。

**我视角的疑问**:
- 你新增的内容**为什么是这些**?是项目要用?还是面试准备?还是兴趣?
- 如果是项目要用 —— 在 `refactor_pi/db/postgres/*.sql` 里能体现哪些?
- 如果是面试准备 —— 给我一个目标岗位 / 公司 / JD,我可以帮你**针对性提炼面试可讲点**

### 3.2 实操记录的缺失 `[必须]`

`postgresql.outline.md` 里全是知识点(类型 / 索引 / 事务 / 性能优化 / 备份),但缺少:
- **你自己做过的**操作(比如建 partition table 的命令、踩过的坑)
- **`refactor_pi/db/postgres/`** 那 15 个 SQL 文件**为什么这么拆模块**?(IAM / metamodel / platform / device / monitoring / event / alarm / job / telemetry / file / licensing)

---

## 4. FerretDB `[强化]`

`ferretdb-no-docker.md` 215 行已经写得很完整,但:
- 你提到了 plan A/B/C(全改 / 半改 / AI 重构),最后选了 **plan C 推倒重写**,**这个决策是怎么形成的**?谁拍板?(简历可讲)
- **Discussion Conclusion (4/15)** —— 这个 4/15 是 4 月 15 日的讨论会?谁参加?讨论了多久?
- 这次调研在公司内的影响:**有没有被写进正式文档 / 决策评审 / 给客户的回应**?

---

## 5. 简历语言版的输入 `[必须]`

为了让 [`career/resume-projects.md`](../career/resume-projects.md) 更准确,需要:

### 5.1 你的目标岗位
- Java 后端 ? 后端 + 架构 ? 全栈 ? DevOps ? 数据库相关 ?
- 国内大厂 / 外企 / 创业公司 / 出海 ? 这些岗位侧重点不同
- 期望 level (P5/P6/P7 之类) ? 这影响你**展示的高度**(实施 vs 设计 vs 决策)

### 5.2 你的"反例"
- 你**最不想被问到**的问题是什么?(避免简历给面试官递刀)
- 你**最不擅长**但简历得有的部分?(比如算法 / 系统设计 / 高并发)

### 5.3 你的优势侧重
- **代码能力**(写干净代码 / 单测覆盖) vs **设计能力**(架构 / 选型) vs **业务理解**(需求拆分 / 落地推动) vs **沟通能力**(跨团队 / 客户面对面)
- 你 `pre_action.md` 写"成熟开发者"是因为**今年沟通有突破**,但简历可能还没体现

---

## 6. 个人成长 / 复盘相关

### 6.1 ~~`pre_action.md` 末尾 3 个问题~~ ✅ L 已直接回答 (2026 春节后谈话)

```
和项目经理的沟通怎么样      → L:有进步(sprint 不再"惊吓"别人) + 但还缺乏理论化(给了"左-中-右"模型)
开讨论会, 例会上的表达     → L:比以前好,简洁不绕,准备工作好;需提升:会议进程主动管理
怎么更进一步               → L:5 条具体路径(业务摸瓜 / 专业英语 / 会议管理 / 跨国合作 / 沟通理论化)
                                + 培养方向 = "独当一面的技术高手"
```

详细整理 → [`career/talking-2026-leader-feedback.md`](../career/talking-2026-leader-feedback.md) §5 + §3 + §4。

> 自答框架仍保留在 [`career/growth-and-feedback.md`](../career/growth-and-feedback.md) §1 ——
> 因为 L 是**外部视角**,你自己的内部视角(主动同步频率、模式自评等)依然有价值,**两者结合**才是完整画像。

### 6.2 `action.md` 里"去留抉择" `[强化]`

你写了去留的策略,但**当前的决策是什么**?(留 / 走 / 观望)对应 `_curated/career/` 文件的写法不同:
- 留 → 简历是**内部 talent review** 用,语言不用太"外向"
- 走 → 简历是**对外投递**用,语言要更**普适**(去 Vertiv 化术语)

---

## 7. 工程结构本身的盲点

### 7.1 ~~`other.md` / `other2.md` 命名~~ ✅ 已完成 (2026-04-30)

已分别改名为:
- `other.md` → `mtp-core-strengths-summary.md`
- `other2.md` → `mtp-core-deep-analysis.md`

git 历史保留(用 `git mv`)。整合后的 `_curated/` 文档见 [`../projects/mtp-core-framework.md`](../projects/mtp-core-framework.md)。

### 7.2 ~~`unclassified/` 是个临时区~~ ✅ 已清空 (2026-05-08)

6 个文件全部归位,详见 [`meta/inventory.md §8 变更日志`](./inventory.md#8-变更日志)。

### 7.3 `business/SI/task/SI 工作总结.xmind` `[未决]`❓

文件名是 `SI 工作总结`,但 xmind 内部 sheet 名是 `SI 依赖升级`。**不一致**。需要你确认是改文件名还是改 sheet 名。

### 7.4 ~~`Java中间件.txt` 用 .txt 后缀~~ ✅ 已修正 (2026-05-08)

已改后缀 + 改名为 `middleware-overview.md` + 加了表格化结构 + 链接到 `_curated/tech-stack/`。

### 7.5 `1 行 todo 占位文件` ✅ 已修正 (2026-05-08)

- `build/maven.md`(原 `todo`)→ redirect link 到 `tech-stack/maven-essentials.md`
- `protocol/SNMP4J.md`(原 `todo`)→ redirect link 到 `tech-stack/snmp4j-quickref.md`
- `1-meta/study_index.md`(原 0 行)→ redirect link 到 `_curated/README.md` 等三大入口

### 7.6 中文文件名 ✅ 已修正 (2026-05-08)

- `database/mongo/mongodb指令.md` → `mongodb-commands.md`
- `protocol/SOAP版本.md` → `soap-versions.md`
- 工程内剩余中文文件名:`business/PI/迁移 mongodb.xmind` 和 `business/SI/task/SI 工作总结.xmind`(用户最早整理的脑图,**保留**)

---

## 8. 完全不存在但应该有的 `[盲点]`⚠️

我浏览整个工程,**没看到**以下你应该考虑的点(2026-05 更新:用户补了 `Java Study.pdf` 103 页 + `asp/knowledge.md` 570 行后,**多项已被覆盖**):

| 缺失主题 | 为什么要有 | 覆盖状态 |
|---|---|---|
| `Spring 框架` 专题 | Java 后端核心,你天天用 | ✅ **已补**:[`tech-stack/spring-internals.md`](../tech-stack/spring-internals.md)(Bean 生命周期 / 循环依赖 / AOP / Boot 启动 / 自动装配 / @Transactional)+ ASP @RedisLock 实战 |
| `JVM` / GC / 调优 | 面试必问,简历"Java 后端"必须有 | ✅ **已补**:[`tech-stack/jvm-and-concurrency.md` §1-§5](../tech-stack/jvm-and-concurrency.md) |
| `MySQL` 进阶 | SI 4.1 里 MySQL→SQLite 切换 | ✅ **已补**:[`tech-stack/mysql-deep-dive.md`](../tech-stack/mysql-deep-dive.md)(InnoDB 锁 / MVCC / 主从 / binlog / ICP) + PDF p.23-43 基础 |
| `单元测试 / Mockito / TestContainers` | 代码质量加分项 | ✅ **已补**:[`tech-stack/testing-and-engineering.md`](../tech-stack/testing-and-engineering.md)(JUnit5 / Mockito / TestContainers / Git / CR / 文档写作) |
| `Docker / 容器化` | FerretDB 调研里你提了 | ⚠️ **半覆盖**:ASP knowledge.md 有 K8s 指令 / Dockerfile 流程,但**缺独立深度** |
| `Git workflow` / Code Review 经验 | 团队协作 | ✅ **已补**:[`tech-stack/testing-and-engineering.md` §2-§3](../tech-stack/testing-and-engineering.md) |
| `English` 技术写作 | Vertiv 是外企,你日常应该会写英文 doc / commit / PR? | ✅ **已补**:[`tech-stack/programming-english.md`](../tech-stack/programming-english.md)(731 行,词汇 + 句型 + Standup/PR/Design Doc/会议 模板)+ [`tech-stack/testing-and-engineering.md` §4](../tech-stack/testing-and-engineering.md)。**实操还需用户长期积累**。 |
| **JUC / AQS / volatile / synchronized 锁升级** | P6+ **必考** | ✅ **已补**:[`tech-stack/jvm-and-concurrency.md` §6-§12](../tech-stack/jvm-and-concurrency.md) |
| **Redis 持久化 / 主从 / 哨兵 / 集群** | 后端必考 | ✅ **已补**:[`tech-stack/redis-deep-dive.md`](../tech-stack/redis-deep-dive.md)(数据结构底层 / RDB+AOF+混合 / 主从+哨兵+Cluster / 8 淘汰策略) |
| **MySQL InnoDB 行锁 / 间隙锁 / 临键锁** | P6+ 必考 | ✅ **已补**:[`tech-stack/mysql-deep-dive.md` §1](../tech-stack/mysql-deep-dive.md) |
| **Spring Bean 生命周期 / 循环依赖三级缓存** | P6+ 必考 | ✅ **已补**:[`tech-stack/spring-internals.md` §1-§2](../tech-stack/spring-internals.md) |
| **MQ 三大问题(可靠性/顺序/重复)** | 后端必考 | ✅ **已补**:[`tech-stack/mq-essentials.md`](../tech-stack/mq-essentials.md)(三大问题 + Kafka 架构 + RocketMQ vs Kafka vs RabbitMQ 选型) |
| **TCP / HTTP / HTTPS / WebSocket** ⚠️新增 | 后端必考 | ✅ **已补**:[`tech-stack/network-essentials.md`](../tech-stack/network-essentials.md)(三/四次握手 / TIME_WAIT / HTTP123 / TLS 握手 / WS 升级) |
| **系统设计方法论** ⚠️新增 | P7 加分 | ✅ **已补**:[`tech-stack/system-design-primer.md`](../tech-stack/system-design-primer.md)(7 步法 + 8 经典题 + 你项目映射) |
| **算法刷题路径** ⚠️新增 | 国内大厂笔试关 | ❌ **仍空白**(不是知识,是训练 → 看 [`tech-stack/00-skill-roadmap.md` §5](../tech-stack/00-skill-roadmap.md)) |
| **Netty / DDD / Kotlin** | 看目标公司 | ❌ **仍空白**(长尾,不紧急) |

---

## 9. 优先级 Top 5 (我的推荐)

如果时间有限,只补 5 个,我建议(**2026-05 更新**:进阶 7 大模块写完后,优先级再调整):

1. ~~**回答 `pre_action.md` 末尾 3 个问题**~~ ✅ L 已答 → 转为:**把 [`career/talking-2026-leader-feedback.md` §7](../career/talking-2026-leader-feedback.md#7-我的今年行动清单基于-l-的反馈) 的行动清单转化为 SOP**(1-2 小时,影响今年绩效)
2. ⭐ **基于新增的中移 ASP 素材更新简历 §2 段**(1 小时,从"几乎空白"到"4 个完整 STAR 段") —— 见 [`career/resume-projects.md` §2](../career/resume-projects.md)
3. ~~⭐ **补 JVM/GC/JUC 三个 PDF 盲点**~~ ✅ 已写 → 转为:**长期消化进阶 7 模块**(见 [`tech-stack/00-skill-roadmap.md`](../tech-stack/00-skill-roadmap.md) 的优先级排序,**积累式不要一次消化**)
4. **回答 §5 简历语言版的输入**(目标岗位 / 反例 / 优势)(30 分钟,让 `resume-projects.md` 真正有用)
5. **填充 SI 4.0 / 4.0.1 / 4.1 各自的具体细节** + **回答 §2.1 PI 重构 12 个 `[missing]`**(滚动进行)

> 已不在 Top 5 但重要:
> - ~~**归位 `unclassified/` 5 个文件**~~ ✅ 2026-05-08 完成(6 个归位 + 命名修正,见 [`meta/inventory.md §8`](./inventory.md#8-变更日志))
> - ~~**决定 `Java Study.pdf` 是否转 markdown**~~ ✅ 2026-05 完成 → [`file/3-tech_stack/java-study.md`](../../file/3-tech_stack/java-study.md) 1714 行
> - **算法刷题** —— 国内大厂笔试关,需要长期训练,本工程内未覆盖

---

> 我会根据你**回答的内容**滚动更新这份文档,把已答的项划掉。
> 你不用一次答完——回答 1 条,我就能补完对应的下游文件。
