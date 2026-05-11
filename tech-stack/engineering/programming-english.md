# 编程领域专业英语 + 中文对照

> **写给**:中英双语后端开发者(你)
> **目的**:补 L 第二年反馈强调的"专业英语"硬指标 + 写英文 design doc / PR / standup 不卡壳
> **原则**:**只收日常工作 + 面试 + Code Review 真正用得上的**;"教科书词汇"不收

标签:`[与L反馈]`📝 `[外企友好]`⭐⭐⭐ `[ROI高]`💎 `[需要积累]`⏳

---

## 0. 怎么用这份文档

### 0.1 按场景分类

| 场景 | 看哪节 |
|---|---|
| 日常 Standup / 1:1 | §1 协作 + 流程 / §2 工作状态 / §10 句型 |
| 写 PR / Code Review | §3 代码品质 / §11 PR 句型 |
| 写 Design Doc / RFC | §4 架构设计 / §12 文档句型 |
| 技术面试 / 准备简历 | §5-§8 技术词汇 |
| 跟外籍同事会议 | §1 + §13 会议句型 |

### 0.2 ⭐ 我的判断 — **5 个最容易错的中式英语**

| ❌ 中式 | ✅ 地道 |
|---|---|
| "I have **a question**." | "**Quick question** — ..." / "**Just to clarify** — ..." |
| "We **decide to** use Redis." | "We **decided to** use Redis." / "**We're going with** Redis." |
| "The code has **a problem**." | "There's **an issue** with..." / "**This breaks** when..." |
| "I **know**." | "**Got it.**" / "**Makes sense.**" / "**Understood.**" |
| "OK / yes / no" 单字回 | 至少 1 句完整说明 — "Sounds good, will do." |

---

## 1. ⭐⭐⭐ 协作 + 流程词汇

### 1.1 Agile / Scrum

| English | 缩写 | 中文 | 备注 |
|---|---|---|---|
| sprint | — | 冲刺 / 迭代 | 通常 2 周 |
| backlog | — | 待办列表 | product backlog / sprint backlog |
| user story | — | 用户故事 | "As a [user], I want [X], so that [Y]" |
| story point | SP | 故事点 | 估算工作量(1/2/3/5/8 斐波那契) |
| **standup** | — | 站会 / 晨会 | 也叫 daily scrum |
| retrospective | retro | 复盘会 | 冲刺末做 |
| grooming / refinement | — | 需求梳理 | 把需求细化 |
| planning | — | 计划会 | sprint 开始时 |
| **demo / showcase** | — | 演示 | sprint 末展示 |
| velocity | — | 速度 | 团队每 sprint 完成 SP 数 |
| burn-down chart | — | 燃尽图 | 跟踪进度 |
| MVP | — | Minimum Viable Product 最小可行产品 | |
| acceptance criteria | AC | 验收标准 | 写在 user story 里 |
| DoD | — | Definition of Done 完成定义 | "代码合并 + 测试通过 + doc 更新" |

### 1.2 协作动作

| English | 中文 | 例句 |
|---|---|---|
| **align** (on / with) | 对齐 / 达成共识 | "Let's **align on** the API contract" |
| sync (with) | 同步信息 | "Quick **sync** at 3pm?" |
| **catch up** | 跟进 / 追赶 | "Let me **catch up on** the PR" |
| follow up | 跟进 | "I'll **follow up** with John" |
| loop in | 拉某人入群 | "**Looping in** Sarah for context" |
| ping | 戳 / 提醒一下 | "**Ping me** when ready" |
| escalate | 升级(到上级 / 优先级) | "We need to **escalate this to** the manager" |
| **block / blocker** | 阻塞 / 阻塞项 | "I'm **blocked on** the API spec" |
| unblock | 解阻塞 | "Can you **unblock** me by EOD?" |
| **EOD / EOW** | End of Day / Week 当天/本周末 | "I'll send it by **EOD**" |
| **ASAP** | as soon as possible | 但**别滥用**,会显得有命令感 |
| FYI | for your information | 写信常用 |
| TL;DR | too long; didn't read 简版 | 长文档开头 |

### 1.3 ⭐ 时间表达(地道)

| ❌ 中式 | ✅ 地道 |
|---|---|
| at next Monday | **on next Monday** / **next Monday** |
| in this week | **this week** / **by Friday** |
| after lunch | **after lunch** ✓ |
| **soon** (太模糊) | **by EOD** / **by Friday** / **within 2 days** |
| 2 weeks later | **in 2 weeks** / **2 weeks from now** |

---

## 2. 工作状态 / 进度词汇

| English | 中文 | 备注 |
|---|---|---|
| **WIP** | Work In Progress 进行中 | PR 标题前缀 `[WIP]` |
| **TBD** | To Be Determined 待定 | |
| **TBA** | To Be Announced 待宣布 | |
| **N/A** | Not Applicable 不适用 | 表格填这个比留空好 |
| ETA | Estimated Time of Arrival 预计完成时间 | "ETA: tomorrow EOD" |
| punted / parked | 延后 | "We **parked** this for next sprint" |
| de-prioritized | 降级 | |
| spike | 调研 / 探索性任务 | sprint 里花 3 天调研某技术 |
| hotfix | 紧急修复 | 生产 bug 紧急上线 |
| rollback | 回滚 | |
| stale | 过时的 | "This PR is **stale**, please rebase" |
| flake / flaky | 不稳定 | "The test is **flaky**" 测试时好时坏 |

---

## 3. ⭐⭐ 代码品质 / Code Review

### 3.1 PR / Code Review 高频词

| English | 缩写 | 中文 | 用法 |
|---|---|---|---|
| **LGTM** | — | Looks Good To Me 我看着没问题 | 批准 PR |
| **SGTM** | — | Sounds Good To Me 听起来不错 | 同意方案 |
| **WFM** | — | Works For Me | 可以 |
| nit | nitpick | 吹毛求疵的小问题 | "**nit:** typo here" 表示这条不阻塞合并 |
| **suggestion** | — | 建议 | 软性提议,可以采纳也可以不 |
| **blocker** | — | 阻塞性问题 | 必须修才能合 |
| **must / should / may** | — | 必须 / 应该 / 可以 | RFC 标准用语;**评论强度** |
| **rubber-stamp** | — | 走过场审 | "I just **rubber-stamped** it" 没认真看 |
| ship it | — | 直接上 | 同 LGTM |

### 3.2 ⭐ Code Review 中常用句型

```text
✅ 软性建议:
- "Consider X here..."
- "How about [alternative]?"
- "Could we [verb] this?"
- "Maybe we should..."

✅ 表达困惑:
- "I'm not sure I follow — could you explain why we [X]?"
- "Could you add a comment explaining [Y]?"

✅ 指出问题:
- "This will fail when [edge case]."
- "Concurrency issue: if two threads call this..."
- "Memory leak: we never release [resource]."

✅ 表扬:
- "Nice catch!"
- "Clean implementation."
- "Love this refactor."

✅ 同意 / 妥协:
- "Fair point, let's go with your approach."
- "I see your point. Defer to you on this."
- "Let's revisit this in a follow-up."
```

### 3.3 代码品质常用词

| English | 中文 | 备注 |
|---|---|---|
| **refactor** | 重构 | "Let's refactor this method" |
| regression | 回归(老 bug 重现) | "regression test" |
| edge case | 边界情况 | |
| corner case | 极端边界 | 比 edge case 更刁钻 |
| happy path | 正常流程 | 与 edge case 相对 |
| race condition | 竞态条件 | 并发常见 bug |
| deadlock | 死锁 | |
| starvation | 饥饿 | 线程长期拿不到资源 |
| **idempotent / idempotency** | 幂等 / 幂等性 | MQ 必备 |
| **boilerplate** | 样板代码 | "lots of boilerplate" 减肥目标 |
| **DRY** | Don't Repeat Yourself 别重复 | |
| **YAGNI** | You Aren't Gonna Need It | 别提前优化 |
| **KISS** | Keep It Simple, Stupid | 保持简单 |
| **SOLID** | 5 大设计原则缩写 | S:单一 / O:开闭 / L:里氏 / I:接口隔离 / D:依赖倒置 |
| smell / code smell | 代码异味 | "this method has a **code smell**" |
| **technical debt** | 技术债 | "We accumulated lots of **tech debt**" |

---

## 4. ⭐⭐ 架构 / 设计词汇

### 4.1 性能 / 容量

| English | 中文 | 单位 / 备注 |
|---|---|---|
| **throughput** | 吞吐量 | QPS / TPS / RPS |
| latency | 延迟 | ms / μs |
| **P50 / P95 / P99** | 50/95/99 百分位延迟 | 必背 |
| **SLA / SLO / SLI** | 服务等级协议 / 目标 / 指标 | "SLA 99.99%" |
| MTTR | Mean Time To Recovery 平均恢复时间 | |
| MTBF | Mean Time Between Failures | |
| RTO | Recovery Time Objective 恢复时间目标 | 灾备指标 |
| RPO | Recovery Point Objective 恢复点目标 | 可丢失多少数据 |
| capacity | 容量 | "**capacity planning**" |
| bottleneck | 瓶颈 | "the DB is the **bottleneck**" |
| degrade / degradation | 降级 | "**graceful degradation**" 优雅降级 |
| fail over / failover | 故障转移 | |
| circuit breaker | 熔断器 | Hystrix / Sentinel |
| backpressure | 背压 / 反压 | 下游处理不过来时的反馈机制 |

### 4.2 一致性 / 可用性

| English | 中文 |
|---|---|
| consistency | 一致性 |
| **strong / eventual consistency** | 强 / 最终一致性 |
| availability | 可用性 |
| **partition tolerance** | 分区容忍性 |
| CAP / BASE / PACELC | (理论) |
| idempotent | 幂等的 |
| atomic | 原子的 |
| **race condition** | 竞态条件 |
| **happy path / sad path** | 正常 / 异常路径 |

### 4.3 架构模式

| English | 中文 |
|---|---|
| **monolith** | 单体 |
| microservices | 微服务 |
| service mesh | 服务网格(Istio / Linkerd) |
| sidecar | 边车(模式) |
| API gateway | 网关 |
| **load balancer** | 负载均衡 (LB) |
| reverse proxy | 反向代理 |
| **scale up / scale out** | 垂直扩展(加配置) / 水平扩展(加机器) |
| sharding | 分片 |
| replication | 复制 |
| **read / write replica** | 读 / 写副本 |
| event-driven | 事件驱动 |
| pub-sub | 发布订阅 |
| fan-out / fan-in | 扇出 / 扇入 |
| **stateless / stateful** | 无状态 / 有状态 |
| immutable | 不可变的 |

---

## 5. ⭐ 数据库词汇

| English | 中文 | 备注 |
|---|---|---|
| schema | 模式 / 表结构 | |
| table / row / column | 表 / 行 / 列 | |
| primary key (PK) | 主键 | |
| foreign key (FK) | 外键 | |
| **unique constraint** | 唯一约束 | |
| index / **composite index** | 索引 / 联合索引 | |
| **clustered / non-clustered index** | 聚簇 / 非聚簇索引 | InnoDB 主键是聚簇 |
| **covering index** | 覆盖索引 | 不回表 |
| **B+ tree** | B+ 树 | |
| **execution plan** | 执行计划 | EXPLAIN 看 |
| query optimizer | 查询优化器 | |
| transaction | 事务 | |
| **ACID** | 原子 / 一致 / 隔离 / 持久 | |
| **isolation level** | 隔离级别 | RU / RC / RR / Serializable |
| **dirty read** | 脏读 | |
| **non-repeatable read** | 不可重复读 | |
| **phantom read** | 幻读 | |
| **MVCC** | 多版本并发控制 | |
| deadlock | 死锁 | |
| row lock / gap lock / next-key lock | 行 / 间隙 / 临键锁 | |
| **sharding / partitioning** | 分库分表 / 分区 | |
| **replication lag** | 主从延迟 | |
| binlog / redo log / undo log | (MySQL 三种日志) | |
| **OLTP / OLAP** | 在线事务 / 在线分析 | |
| **DML / DDL / DCL** | 数据 / 定义 / 控制语言 | |

---

## 6. ⭐ 缓存 / Redis 词汇

| English | 中文 |
|---|---|
| **cache hit / miss** | 缓存命中 / 未命中 |
| **hit ratio** | 命中率 |
| **eviction** | 淘汰 |
| **LRU / LFU** | (淘汰算法) |
| TTL | Time To Live 过期时间 |
| **cache penetration** | 缓存穿透 |
| **cache breakdown** | 缓存击穿 |
| **cache avalanche** | 缓存雪崩 |
| **cache stampede** | 缓存惊群(同 breakdown) |
| **read-through / write-through / write-back** | (缓存策略) |
| **cache aside** | 旁路缓存 |
| stale data | 过时数据 |
| invalidation | 失效(主动让缓存失效) |
| warm up | 预热(冷启动时) |

---

## 7. ⭐ 并发 / JVM 词汇

| English | 中文 |
|---|---|
| **thread pool** | 线程池 |
| **deadlock / livelock** | 死锁 / 活锁 |
| **race condition** | 竞态条件 |
| atomic | 原子的 |
| **mutex / monitor** | 互斥锁 / 监视器 |
| reentrant | 可重入的 |
| **fair / unfair lock** | 公平 / 非公平锁 |
| spin lock | 自旋锁 |
| **CAS** | Compare-And-Swap 比较并交换 |
| **ABA problem** | ABA 问题 |
| heap / stack | 堆 / 栈 |
| **GC / garbage collection** | 垃圾回收 |
| **STW (stop-the-world)** | (GC 时全暂停) |
| **OOM** | Out Of Memory 内存溢出 |
| **memory leak** | 内存泄漏 |
| heap dump | 堆转储 |
| thread dump | 线程转储 |
| profiler | 性能分析器 |

---

## 8. ⭐ 网络 / 协议词汇

| English | 中文 |
|---|---|
| **handshake** | 握手 |
| TCP/IP / UDP | (协议) |
| **payload** | 载荷(数据本身) |
| header / body | 头 / 体 |
| **endpoint** | 端点 / 接口地址 |
| port | 端口 |
| socket | 套接字 |
| **HTTPS / SSL / TLS** | |
| **CORS** | Cross-Origin Resource Sharing 跨域资源共享 |
| **CDN** | Content Delivery Network 内容分发网络 |
| **DNS** | Domain Name System 域名系统 |
| **VPN** | 虚拟专网 |
| firewall | 防火墙 |
| nat / **NAT traversal** | 网络地址转换 / 穿透 |
| bandwidth | 带宽 |
| RTT | Round-Trip Time 往返时延 |
| timeout | 超时 |
| retry | 重试 |
| backoff / **exponential backoff** | 退避 / 指数退避 |

---

## 9. DevOps / 部署词汇

| English | 中文 |
|---|---|
| **CI/CD** | 持续集成 / 持续交付 |
| pipeline | 流水线 |
| build / **artifact** | 构建 / 构建产物 |
| **deploy / deployment** | 部署 |
| **rollout / rollback** | 上线 / 回滚 |
| canary / blue-green | 金丝雀 / 蓝绿(部署) |
| **smoke test** | 冒烟测试 |
| **regression test** | 回归测试 |
| **staging / production** | 预生产 / 生产 |
| **dry run** | 试跑(不真执行) |
| provisioning | 环境准备 |
| orchestration | 编排(K8s) |
| container | 容器 |
| image / registry | 镜像 / 镜像仓库 |
| **helm chart** | (K8s 部署模板) |
| Kubernetes / K8s | |
| pod / node / cluster | (K8s 概念) |
| **observability** | 可观测性 |
| **metrics / logs / traces** | 指标 / 日志 / 链路追踪 |
| alerting | 告警 |
| dashboard | 仪表盘 |

---

## 10. ⭐⭐⭐ Daily Standup 句型

> **3 句话模板**:**昨天做了什么 / 今天打算做什么 / 有没有 blocker**

```text
✅ 模板:
"Yesterday I [verb-ed] ...
Today I'm going to [verb] ...
[No blockers / I'm blocked on ...]"

✅ 实例:
"Yesterday I finished the auth module and pushed the PR.
Today I'm going to start on the rate limiter and review John's PR.
No blockers."

✅ 进度延期 (politely):
"Yesterday I made progress on the migration but hit an unexpected
issue with the index. I'm going to need another day. No blockers
for the team — just digging into it myself."

✅ 求助:
"I'm blocked on the API spec from the frontend team.
Could someone help me sync with them?"
```

### 不会说时的救命短语

```text
"Let me think about that for a second..."
"I want to make sure I understand correctly — are you saying [X]?"
"Could you give me an example?"
"Let me check and get back to you."
"I'd like to discuss this offline / in a separate meeting."
```

---

## 11. ⭐⭐⭐ PR 描述模板

```markdown
## Summary
Briefly describe what this PR does and why.

## Changes
- Added X
- Modified Y to do Z
- Removed deprecated W

## Why
The previous implementation had [issue]. This change [addresses
it by ...].

## Testing
- [x] Unit tests added
- [x] Integration tests passing
- [x] Manually tested on staging

## Screenshots / Logs
(if applicable)

## Notes for Reviewers
- The change in `XYZ.java` looks bigger than it is — it's mostly
  rename + format
- Open question: should we [X] or [Y]?

## Related
- Closes #123
- Related to #456
```

### PR 标题命名

```text
✅ 好:
[feat] Add JWT refresh endpoint
[fix] Handle null user in OrderService.create
[refactor] Extract caching logic into CacheService
[perf] Reduce DB roundtrips in listOrders by 50%
[docs] Update README setup section
[test] Add integration tests for payment flow
[chore] Bump Spring Boot to 3.2.0

❌ 差:
"update code"
"fix bug"
"changes"
```

---

## 12. ⭐⭐ Design Doc / RFC 句型

### 12.1 开头 (Bottom Line Up Front)

```text
✅ 好(BLUF):
"This document proposes migrating our auth service from
session-based to JWT to support multi-region deployment.
Pros: A, B, C. Cons: D, E. Recommendation: proceed."

❌ 差(铺垫太多):
"As we all know, our auth service has been running for years..."
```

### 12.2 提议方案

| English | 中文 |
|---|---|
| "We propose to ..." | 我们提议 |
| "**The recommended approach** is ..." | 推荐方案 |
| "There are several options. We chose X because Y." | 有几个选项,选 X 因为 Y |
| "**Pros: ... / Cons: ...**" | 优点 / 缺点 |
| "**Trade-offs**: we sacrifice X for Y." | 权衡:为 Y 牺牲 X |

### 12.3 表达不确定 / 限制

```text
✅ 地道:
"This assumes [precondition]."
"This may not work if [scenario]."
"We're explicitly **not addressing** [out-of-scope thing]."
"**Open question**: [unresolved item]."
"This needs further investigation."
```

### 12.4 ⭐ 5 个写作 tip(给非母语)

| Tip | 例子 |
|---|---|
| **主语用 "We" 或 "The system"**,少用 "I" | ✅ "We chose PG..." ❌ "I think we should..." |
| **现在时为主**(讲方案);**完成时**讲已发生 | ✅ "The service handles..." / "We **have decided** to..." |
| **结论先行 (BLUF)** | 第一段就给结论 |
| **避免长复合句** | 一句话 < 25 词 |
| **关键词加粗 / 表格化** | reviewer 扫读友好 |

### 12.5 表达升级

| ❌ 啰嗦 | ✅ 简洁 |
|---|---|
| make a decision | **decide** |
| in order to | **to** |
| due to the fact that | **because** |
| at this point in time | **now** |
| has the ability to | **can** |
| in the event that | **if** |
| the majority of | **most** |
| despite the fact that | **although** |
| **utilize** | **use** |

---

## 13. ⭐ 会议主持 / 参与句型

> **配套**:这一节直接呼应 [`career/talking-2026-leader-feedback.md`](../../_curated/career/talking-2026-leader-feedback.md) §3 — L 的"会议主持脚手架"反馈。

### 13.1 开会(主持人)

```text
✅ 开场:
"Thanks everyone for joining. Today's agenda is [1, 2, 3].
We have 30 minutes. Let's get started."

✅ 控制节奏:
"Let's table that for now and come back to it."
"For the sake of time, can we move on?"
"Let's take this offline / in a separate thread."

✅ 总结 / 收束:
"To summarize, we've decided X, Y, Z."
"Action items: [Person] will [Action] by [Date]."
"Any questions before we wrap up?"
```

### 13.2 开会(参与者)

```text
✅ 礼貌打断:
"Sorry to interrupt — can I add one thing?"
"Quick question on that..."

✅ 表达不同意见:
"I see your point, but I'd push back on [X] because..."
"I'm not sure I agree. Have we considered [Y]?"
"From my perspective, [different angle]..."

✅ 没听清:
"Sorry, could you repeat that?"
"Can you say that one more time?"
"I missed the last part — what was the takeaway?"

✅ 表示理解:
"Got it." / "Makes sense." / "That tracks." / "Fair."

✅ 同意但有保留:
"Agreed, with the caveat that..."
"Yes, although we should keep in mind..."
```

### 13.3 ⭐ 1:1 / 绩效面谈

```text
✅ 介绍工作:
"Over the last quarter I worked on [X], which delivered [outcome]."
"My main contribution was [specific impact]."

✅ 谈成长:
"I'd like to grow into [role] by developing [skill]."
"I see myself focusing on [direction]."

✅ 寻求反馈:
"What's one thing I should be doing differently?"
"What would it take for me to be ready for [next level]?"

✅ 提加薪 / 升级 (delicate):
"Based on my contributions over [period], I'd like to discuss
my compensation / level."
"What's the path to [next level] for someone in my position?"
```

---

## 14. ⭐ 写邮件 / Slack 句型

### 14.1 开头

| 场合 | 句型 |
|---|---|
| 正式邮件 | "Dear [Name]," / "Hi [Name]," |
| 一般邮件 | "Hi team," / "Hi all," |
| Slack | "Hey [Name]," / "Quick question..." |
| 第一次联系 | "I hope this email finds you well." (略 formal,有人嫌套话) |

### 14.2 求助 / 提问

```text
✅ 礼貌:
"Could you help me with [X]?"
"Would you be able to [verb] by [date]?"
"I'd appreciate it if you could..."

✅ 紧急(说明原因):
"This is time-sensitive because [reason]. Could you..."

❌ 太硬:
"Please do X."
"You need to fix this."
```

### 14.3 表达感谢

| 程度 | 句型 |
|---|---|
| 一般 | "Thanks!" |
| 多一点 | "Thanks for [specific thing]." |
| 正式 | "Much appreciated." / "I really appreciate your help." |
| 写信结尾 | "Best," / "Thanks," / "Regards,"(都 OK) |

### 14.4 拒绝 / 推迟

```text
✅ 礼貌拒绝:
"I'd love to help, but I'm tied up with [X] this week."
"That's not something I can prioritize right now,
but I could revisit next sprint."

✅ 推迟:
"Let me circle back on this next week."
"Can we revisit this after [milestone]?"
```

---

## 15. 易错点 / 中式 vs 地道

| ❌ 中式 | ✅ 地道 |
|---|---|
| "I am very thank you" | "Thank you very much" / "Thanks a lot" |
| "Please give me your suggestion" | "I'd love your **feedback**" / "What do you think?" |
| "How to do X?" (单独成问) | "**How do I do** X?" / "**What's the right way to** X?" |
| "I have a question about ..." | "**Quick question** — ..." |
| "Discuss with you" | "**Discuss this with you**" (不能省 this) |
| "I think it's a good idea" (软) | "**Solid plan**" / "**Sounds good**" / "**LGTM**" |
| "Do you understand?"(质问感) | "**Does that make sense?**" / "**Was that clear?**" |
| "**Please** do this" (写在 Slack 给人命令感) | "**Could you** ..." / "**When you have a chance**, ..." |
| "Sorry to bother you" | "Sorry to **bug** you" / "Quick interruption" |
| "It doesn't matter" (听起来冷) | "**No worries**" / "**It's fine**" |
| "Maybe / perhaps" 太多 | 直接给观点;太多 maybe 显得不自信 |

---

## 16. ⭐⭐ 你这一年的"专业英语行动清单"(基于 L 反馈)

> 与 [`testing-and-engineering.md` §4](./testing-and-engineering.md) + [`career/talking-2026-leader-feedback.md`](../../_curated/career/talking-2026-leader-feedback.md) 联动。

### 16.1 每周(累计)

- [ ] 写 1 个 PR description(用 §11 模板)
- [ ] standup 至少**有 1 次用完整 §10 模板**(不要只说 "I'm working on X")
- [ ] 读 1 篇英文技术博客(High Scalability / Martin Fowler)

### 16.2 每月

- [ ] 写 1 个内部小 design doc(中文 OR 英文都行,但**用 §12 模板**)
- [ ] 做一次跨团队 sync 会议主持(中文也行,**用 §13 脚手架**)

### 16.3 每季

- [ ] 写 1 篇英文 blog / Confluence 文档
- [ ] 试着主持一次有外籍同事的会议

### 16.4 ⭐ "去中式化"练习

每天写完一段英文先**自检 4 件事**:
1. 有没有不必要的 "**I think / maybe / perhaps**"?
2. 有没有从中文直译的副词("**very**" "**really**" 太多)?
3. 主谓宾**有没有省掉**(中文常省主语,英语不行)?
4. 长句**能不能拆成两句**?

---

## 17. 推荐资源

| 资源 | 备注 |
|---|---|
| **Hacker News / Lobste.rs** | 技术文章 + 评论区学日常表达 |
| **Martin Fowler 的博客** | 英文技术写作典范 |
| **Google Engineering Practices** | (免费)https://google.github.io/eng-practices/ |
| **The Pragmatic Engineer (Gergely Orosz)** | Substack,中性 + 准 |
| **YouTube: "Stand-up meeting examples"** | 看真人怎么说 |
| **Grammarly(写作检查)** | 自动检查语法 / tone |

---

## 18. 一页速查(打印贴墙)

```
日常 5 句:
- "Got it." / "Makes sense."
- "Let me check and get back to you."
- "Quick question — ..."
- "Could you elaborate on [X]?"
- "I'm blocked on [Y]."

PR 5 句:
- "LGTM"
- "Nit: ..."
- "Consider [alternative]"
- "Could we [verb] this?"
- "Nice catch!"

会议 5 句:
- "Let's align on ..."
- "For the sake of time, can we move on?"
- "Let's take this offline."
- "To summarize: ..."
- "Action items: [Person] will [Action] by [Date]."

写作避雷 5 条:
- BLUF(结论先行)
- 一句 < 25 词
- 主语 We / The system,少用 I
- 现在时为主
- 关键词加粗 / 表格化
```

---

> 📌 **下一步**:回到 [`tech-stack/00-skill-roadmap.md`](./00-skill-roadmap.md) 看完整体系
> 或 [`career/talking-2026-leader-feedback.md`](../../_curated/career/talking-2026-leader-feedback.md) 看 L 反馈
