# 测试 + 工程化(单测 / Mockito / TestContainers / Git / Code Review / 文档)

> **写给**:**4 年 Java 后端但工程内 0 单测沉淀**的你
> **目的**:**外企友好** + 与 L 第二年反馈呼应("沟通 / 文档 / 工程化"是发展方向)
> **价值**:这一块写出来 = **简历差异化** + **代码品质背书**

标签:`[外企友好]`⭐⭐⭐ `[与L反馈]`📝(L 强调专业英语 + 工程化) `[盲点]`⚠️ `[ROI高]`💎

---

## 0. 你的水位 + 为什么这块对你重要

### 0.1 你的水位(我的判断)

| 维度 | 你的水位 |
|---|---|
| 写过单测? | ⚠️ 不确定,工程内未见沉淀 |
| 用过 Mockito / TestContainers? | ❌ |
| Code Review 经验 | ✅ Vertiv 应该有 |
| Git workflow(rebase / cherry-pick) | ⚠️ 看习惯 |
| 写过英文 README / Javadoc | ⚠️ |
| TDD / BDD | ❌ |

### 0.2 ⭐⭐⭐ 为什么这块对你尤其重要

> **L 第二年谈话强调**:**专业英语 + 软实力 + 跨团队协作**(详见 [`career/talking-2026-leader-feedback.md`](../career/talking-2026-leader-feedback.md))。
>
> **外企面试** 很少考"算法/八股",**很常考**:
> - "你怎么写单测?覆盖率多少?"
> - "你做过 Code Review 吗?会指出什么问题?"
> - "你怎么写一个 design doc?"
> - "你怎么用 Git rebase 整理 commit?"
>
> **国内大厂**:这块也越来越被重视(P7+ 必备)。

---

## 1. ⭐⭐⭐ 单元测试 `[P6基线]` `[外企友好]`

### 1.1 JUnit 5 基础

```java
class CalculatorTest {
    @Test
    void shouldAddTwoNumbers() {
        // Given
        var c = new Calculator();
        // When
        var result = c.add(2, 3);
        // Then
        assertEquals(5, result);
    }
    
    @ParameterizedTest
    @ValueSource(ints = {1, 2, 3})
    void shouldHandleVariousInputs(int input) { ... }
    
    @BeforeEach    // 每个测试前
    @AfterEach     // 每个测试后
    @BeforeAll     // 一次(static 方法)
    @AfterAll
    
    @Disabled("WIP")
    @Tag("slow")   // 用于分组运行
}
```

### 1.2 ⭐ 测试金字塔

```
        ┌──────┐
        │  E2E │  少(慢、贵、易脆)
        ├──────┤
        │ 集成  │  适量
        ├──────┤
        │ 单元  │  ⭐ 大量(快、稳)
        └──────┘
```

**经验比例**:**单元 70% / 集成 20% / E2E 10%**。

### 1.3 ⭐⭐ 写好单测的 5 条原则

| 原则 | 含义 |
|---|---|
| **F.I.R.S.T** | Fast / Independent / Repeatable / Self-validating / Timely |
| **AAA / GWT** | Arrange (Given) - Act (When) - Assert (Then) |
| **一个测试一个意图** | 不要在一个 @Test 里测多个 case |
| **测试名称即文档** | `should_returnZero_when_arrayIsEmpty` |
| **避免测细节** | 测**行为**(行为不变测就稳),不测**实现** |

### 1.4 ⭐⭐ Mockito 实战

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {
    @Mock UserRepo userRepo;        // mock
    @Mock PayClient payClient;
    @InjectMocks OrderService svc;  // 把 mock 注入

    @Test
    void shouldRejectIfUserNotExists() {
        // Given
        when(userRepo.findById(1L)).thenReturn(Optional.empty());
        
        // When + Then
        assertThrows(UserNotFoundException.class, 
            () -> svc.create(1L, BigDecimal.TEN));
        
        verify(payClient, never()).pay(any());  // 验证未调用
    }
    
    @Test
    void shouldChargeAfterCreate() {
        when(userRepo.findById(any())).thenReturn(Optional.of(new User(1L)));
        when(payClient.pay(any())).thenReturn(PayResult.SUCCESS);
        
        var order = svc.create(1L, BigDecimal.TEN);
        
        verify(payClient, times(1)).pay(BigDecimal.TEN);
        assertEquals(OrderStatus.PAID, order.status());
    }
}
```

### 1.5 ⭐ TestContainers(集成测试神器)

> **痛点**:测 SQL 用 H2 内存库(行为和真 MySQL 不一样)→ 上线踩坑。
>
> **解决**:**TestContainers** —— 用 Docker 起真 MySQL/Redis/PG,测完销毁。

```java
@Testcontainers
class UserRepoIntegrationTest {
    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("test").withUsername("test").withPassword("test");
    
    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", mysql::getJdbcUrl);
        r.add("spring.datasource.username", mysql::getUsername);
        r.add("spring.datasource.password", mysql::getPassword);
    }
    
    @Test
    void shouldFindUserByEmail() {
        // 真 MySQL,行为和生产一致
    }
}
```

> 🎯 **简历可讲**:"我引入 TestContainers 替代 H2,集成测试从'通过 H2 但生产挂'变成'通过 = 上线安全'"。

### 1.6 测试覆盖率 + JaCoCo

```xml
<!-- pom.xml -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    ...
</plugin>
```

**目标**:**业务核心 80%+ 行覆盖**,**不追求 100%**(80→100 边际成本巨大)。

### 1.7 🎯 简历可写

```
- 主导团队 [TODO: ASP / Vertiv 模块] 的单元测试体系建设
- 引入 Mockito + JUnit 5 + TestContainers,核心模块行覆盖率从 [N] 提升到 [M]%
- 推动 PR 必须带单测的工程实践,Code Review 拒绝无测变更
```

---

## 2. ⭐⭐ Git 高级用法 `[P6基线]` `[ROI高]`💎

### 2.1 必会命令(超越 add/commit/push)

#### rebase(整理历史)
```bash
# 把本地 commits 合并 / 重排 / 改 message
git rebase -i HEAD~5
# 屏幕里:pick / squash / fixup / reword / drop / edit

# 把本地 branch rebase 到最新 main(避免 merge commit)
git pull --rebase origin main
```

#### cherry-pick(精确摘取 commit)
```bash
git cherry-pick <commit-hash>           # 把别的分支的某 commit 拉到当前
git cherry-pick <hash1>..<hash2>        # 一段范围
```

#### stash(临时保存)
```bash
git stash                               # 暂存
git stash pop                           # 恢复
git stash list / git stash apply 0
```

#### reset vs revert
| 命令 | 含义 | 安全 |
|---|---|---|
| `git reset --hard <hash>` | **丢弃** commits,本地强制回退 | ❌ 已 push 的别用 |
| `git revert <hash>` | 用**新 commit 反向**抵消 | ✅ 安全 |

### 2.2 ⭐ commit message 规范(Conventional Commits)

```
<type>(<scope>): <subject>

<body>

<footer>
```

```
feat(auth): add JWT refresh token

Implement refresh token endpoint that returns a new access token
when the old one expires. Closes #123.

BREAKING CHANGE: /auth/login response now includes refresh_token
```

| type | 含义 |
|---|---|
| feat | 新功能 |
| fix | bug 修复 |
| refactor | 重构(无功能变化) |
| perf | 性能优化 |
| docs | 文档 |
| test | 测试 |
| chore | 杂项(依赖升级 / 构建) |
| style | 格式(不影响功能) |

> **简历可讲**:"团队推行 Conventional Commits,自动生成 CHANGELOG"。

### 2.3 ⭐ 分支模型

| 模型 | 适用 |
|---|---|
| **Git Flow** | 严格版本发布(银行 / 金融) |
| **GitHub Flow** | 持续部署(SaaS) |
| **GitLab Flow** | 折中,有环境分支 |
| **Trunk-Based** | 大型工程 / Google / FB |

> **生产**:大部分公司用 **GitHub Flow 或简化 Git Flow**。

---

## 3. ⭐⭐ Code Review `[外企友好]` `[与L反馈]`📝

### 3.1 Review 看什么(从外到内)

| 维度 | 关注点 |
|---|---|
| **正确性** | 是不是真解决了问题?边界条件? |
| **可读性** | 命名 / 注释 / 函数长度 |
| **设计** | 责任划分?抽象合适? |
| **测试** | 有单测吗?覆盖率? |
| **性能** | 大数据量场景?N+1 查询? |
| **安全** | SQL 注入 / XSS / 鉴权 |
| **可维护性** | 6 个月后还能改吗? |

### 3.2 ⭐ Code Review 的"礼仪"

| ✅ Do | ❌ Don't |
|---|---|
| 提建议而非命令(Maybe / Could) | 你这写得不对,改 |
| 说"为什么" | 只说"改成 X" |
| 区分 nit / minor / major | 把所有问题混为一谈 |
| 表扬好的代码 | 只挑刺 |
| 讨论复杂的话题用面对面 | 在 PR 评论里争论 5 个回合 |

### 3.3 怎么提一个让人愿意 review 的 PR

| 做法 | 价值 |
|---|---|
| **PR 描述清晰**:做了什么 / 为什么 / 怎么测的 | reviewer 心智负担小 |
| **小 PR**(< 400 行) | review 质量高(大 PR 直接 LGTM) |
| **拆分 commit**(逻辑独立) | reviewer 可按 commit 看 |
| **自查清单**:格式化 / lint / 测试通过 / 自己 review 一遍 | 减少低级问题 |

### 3.4 🔗 结合 L 反馈

L 提到 **"沟通理论化(左中右模型)/ 会议主持脚手架"** —— **Code Review 评论也是同理**:
- **左**:接受方式(语气、措辞)
- **中**:核心建议
- **右**:讨论开放性(欢迎反驳)

---

## 4. ⭐⭐ 技术文档写作 `[与L反馈]`📝 `[外企友好]`

### 4.1 4 类技术文档

| 类型 | 用途 | 例子 |
|---|---|---|
| **README** | 项目入口 | 怎么 build / 怎么跑 / 怎么测 |
| **Design Doc / RFC** | 设计前对齐 | 你 PI 4.0 重构的 overview / deep-dive 就是 |
| **ADR**(Architecture Decision Record) | 记录决策 | "为什么选 PG 不选 MongoDB" |
| **Runbook / Playbook** | 运维 / 排障 | "OOM 时怎么排查" |

### 4.2 ⭐ Design Doc 模板(必备)

```markdown
# [Title]: 一句话目的

## Author / Date / Status / Reviewers

## 1. Context (为什么)
- 业务背景
- 现状问题
- 这次要解决什么

## 2. Goals & Non-goals
- 明确"不做什么"和"做什么"同样重要

## 3. Proposal
- 方案 A / B / C 对比
- 推荐方案 + 理由

## 4. Detailed Design
- API / Data Model / Sequence

## 5. Trade-offs
- 我们牺牲了什么(性能?简洁?灵活?)

## 6. Risks & Mitigations
- 已知风险 + 应对

## 7. Rollout Plan
- 灰度 / 监控 / 回滚

## 8. Open Questions
- 待回答(欢迎反馈)

## 9. References
```

### 4.3 ⭐ 英文技术写作的 5 个 tip(给非母语)

| Tip | 例子 |
|---|---|
| **主语用 "We" 或 "The system"**,少用 "I" | "We chose PG because..." |
| **现在时为主**,完成时讲已发生 | "The service handles..." / "We have decided..." |
| **避免长复合句** | 一句话 < 25 词 |
| **关键词加粗 / 表格化** | reviewer 扫读友好 |
| **结论先行**(BLUF) | Bottom Line Up Front,先给答案再展开 |

### 4.4 推荐的英文表达升级

| ❌ 不好 | ✅ 好 |
|---|---|
| make a decision | decide |
| in order to | to |
| due to the fact that | because |
| at this point in time | now |
| has the ability to | can |

> 🔗 **结合 L 反馈**:**今年硬指标 = 专业英语**。**写 design doc 是最好的练习方式**(比背单词有效 10 倍)。

---

## 5. ⭐ CI/CD 基础 `[P6基线]` `[ROI高]`💎

### 5.1 经典 Pipeline

```
Code Push 
  → Build (Maven / Gradle)
  → Unit Test
  → Static Analysis (SonarQube / SpotBugs)
  → Integration Test (TestContainers)
  → Build Image (Docker)
  → Deploy to Staging
  → Smoke Test
  → (Manual Approval)
  → Deploy to Production
  → Health Check
```

### 5.2 ⭐ 工具栈

| 工具 | 用途 |
|---|---|
| **Jenkins** | 老牌,你 ASP 在用 |
| **GitHub Actions** | 主流(开源 / SaaS 友好) |
| **GitLab CI** | GitLab 用户 |
| **CircleCI / TravisCI** | 老牌(收费) |
| **Argo CD** | K8s 部署(GitOps) |

### 5.3 🔗 结合你项目

ASP 用 Jenkins → Vertiv [TODO: 你 Vertiv 用什么 CI/CD?]
**简历可讲**:**完整的 CI/CD pipeline 实战经验** = 外企面试加分(很多国企开发只懂打 jar)。

---

## 6. 🎯 简历"工程能力"段升级版

```
【工程能力】
- 单元测试:JUnit 5 + Mockito,熟悉 AAA / GWT 编写规范;
  集成测试用 TestContainers 替代 H2 内存库,确保"测试通过 = 上线安全"
- 代码品质:Code Review 主动 + 被动经验,熟悉 Conventional Commits 规范
- 文档写作:能产出 RFC / Design Doc / ADR / Runbook 各类技术文档,
  PI 4.0 重构产出 2500+ 行决策文档(覆盖架构 / 风险 / 工期 / 未决项)
- CI/CD:Jenkins + Maven + Docker + K8s 全链路;熟悉 GitHub Actions
- Git workflow:熟悉 rebase / cherry-pick,推动团队规范化 commit message
- 中英双语技术沟通:[TODO: 你 Vertiv 日常英文比例?]
```

---

## 7. 🎯 高频面试题(外企尤其)

| # | 题 | §位置 |
|---|---|---|
| 1 | 什么是 F.I.R.S.T 测试原则 | §1.3 |
| 2 | Mockito 怎么 mock + verify | §1.4 |
| 3 | TestContainers vs H2 | §1.5 |
| 4 | 测试覆盖率多少合适 | §1.6 |
| 5 | git reset vs revert 区别 | §2.1 |
| 6 | 怎么写好的 commit message | §2.2 |
| 7 | Code Review 看什么 | §3.1 |
| 8 | Design Doc 包含什么 | §4.2 |

---

## 8. 推荐资源

| 资源 | 备注 |
|---|---|
| **《Clean Code》** Robert Martin | 必读,代码品质圣经 |
| **《Effective Java》** Joshua Bloch | Java 代码品味 |
| **《重构》** Martin Fowler | 重构手法 |
| **Google Engineering Practices** | https://google.github.io/eng-practices/(免费) |
| **Trisha Gee 的 Java 视频** | YouTube,JetBrains DevAdvocate |

---

> 📌 **下一步**:[`system-design-primer.md`](./system-design-primer.md)
