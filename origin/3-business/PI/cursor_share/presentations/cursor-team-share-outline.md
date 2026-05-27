# Cursor 团队分享 — 幻灯片大纲（中英分版）

> **建议时长**：10 分钟 + 可选 5 分钟 Q&A  
> **分享重点**：接到 IE→ZE 迁移任务后，我的解题路径与执行方法  
> **主案例**：#2、#5、#10（以思路为主，不展开技术细节）  
> **关联回望**：[`docs/retrospectives/ai-installanywhere-collaboration.md`](../retrospectives/ai-installanywhere-collaboration.md)

---

## 推荐主题 / 标题

| 语言 | 主标题 | 副标题（可选） |
|------|--------|----------------|
| **中文** | **从 IE Engine 到 Zero Engine** | 接到任务后，我如何拆解、推进并验证 |
| **English** | **From IE Engine to Zero Engine** | How I broke down and drove the migration task |

---

# 中文版 — 幻灯片（约 11 页，10 分钟）

---

### Slide 1 — 封面

**从 IE Engine 到 Zero Engine**  
接到任务后，我如何拆解、推进并验证  

分享人：[你的名字] · 约 10 分钟  
范围：`taf-core-installer`（InstallAnywhere + Maven + GitLab）

---

### Slide 2 — 先补充 6 句背景（给不熟同事）

1. PI 是我们的产品平台，这次改的是它的安装包构建链路。  
2. IE Engine 是 PI 过去使用的旧引擎能力，历史上已经嵌在安装流程里。  
3. Zero Engine 是目标替代方案，我们希望把它作为新的引擎能力打进安装包。  
4. InstallAnywhere 是当前用于生成跨操作系统安装包的构建工具，也是这次改造的主要操作面。  
5. 当前任务本质是：在 `taf-core-installer` 里完成 IE Engine → Zero Engine 的迁移并通过打包验证。  
6. 所以我今天分享的重点不是某个报错怎么修，而是我如何拆解任务并逐步推进。  

---

### Slide 3 — 我接到任务后的 4 步解题路径

```text
Step 1: 从 refactor-pi 抽取安装包相关逻辑，建立独立 pi-installer 工作区
Step 2: 盘点现状（触点/打包方式/日志证据/验证方式）
Step 3: 分阶段执行
  - 阶段 1：去除旧 IE Engine 内容并打包验证
  - 阶段 2：把 Zero Engine 打进安装包并验证
Step 4: 长期研究是否替换 InstallAnywhere，实现多 OS 打包路径
```

---

### Slide 4 — 今天的 3 个主案例（对应 #2 / #5 / #10）

| 案例 | 处于哪一步 | 我想展示的思路 |
|------|------------|----------------|
| **#2 JRE 11 vs 21** | Step 2 盘点现状 | 先自读日志 → 提猜想和依据 → 让 AI 验证对错 |
| **#5 四万行 XML 失败** | Step 3 阶段 1 去 IE | 工具陌生也要推进：AI 干重活，人做小步验算 |
| **#10 绿灯但无 ZESvc** | Step 3 阶段 2 接 ZE | 反差大时先 Plan 比方案，再拍板执行 |

---

### Slide 5 — 案例 #2：先自读，再验猜想

**一句话场景**：`pom` 写 21，打包却是 11。  

**我的步骤**

1. 自己先看 `build.txt` 里的 Java/VM/fallback 关键词。  
2. 提出带依据的猜想（不是“帮我改好”）。  
3. 让 AI 判断猜想是否成立，并指出支持日志行。  
4. 我确认后再批准修改。  

**讲给听众的话**  
> AI 在这里是“验算器”，不是“替我想答案的人”。

---

### Slide 6 — 案例 #5：不熟大 XML，也要可控推进

**一句话场景**：刚接手 InstallAnywhere，`TAFCore.iap_xml` 很大，删 IE 后构建失败。  

**我的步骤**

1. 承认陌生：先让 AI 做重活，但默认“可能会错”。  
2. 用失败日志定位问题类型（结构问题 vs 业务问题）。  
3. 第二轮不盲改：缩小范围、改策略、小步验证。  
4. 把教训写回文档，防止重复踩坑。  

**讲给听众的话**  
> 大文件场景下，关键不是“AI 一次改对”，而是“流程能兜住错误”。

---

### Slide 7 — 案例 #10：反差强时，先 Plan 再 Agent

**一句话场景**：GitLab 构建成功、安装提示成功，但没有 `ZESvc`。  

**我的步骤**

1. 先对齐事实：构建日志和安装日志是否一致支持结论。  
2. 不急着讲根因，先进入 Plan：列方案、比优劣、看约束。  
3. 我拍板选方案，再让 Agent 执行。  
4. 执行后由我做 GitLab + 真机验证闭环。  

**讲给听众的话**  
> 反差大的问题，价值在“如何选方案”，不是“先讲一堆底层细节”。

---

### Slide 8 — 可复制的方法模板（4 句）

```text
① 先给日志和我的猜想：请判断对错，指出证据行，先别改代码
② 先给工程绝对路径：只改这份，先列触点和影响面
③ 遇到多方案：先 Plan 比较优劣，等我拍板再执行
④ 执行后：说清楚你验证了什么、我还需要验证什么
```

**边界**：产品范围、权限配置、最终验收始终由我负责。

---

### Slide 9 — 效率对比（你可以只讲一句）

| 事项 | 粗算工作量 | 说明 |
|------|------------|------|
| 人工移除 `taf-core-installer` 中 SI 相关（不含完整验收） | 约 4 人天 | 触点多，容易漏改 |
| Cursor 协助改动 | 约 30 分钟 | 快速列触点 + 批量改 + 残留检查 |
| 验收 | 目标压到约 1 人天 | 构建和装机验证仍由我主导 |

---

### Slide 10 — 长期规划（Step 4）

- 当前先把 IE→ZE 迁移路径做稳（可打包、可安装、可验证）。  
- 并行开展替代 InstallAnywhere 的研究：是否能用新方案支持多 OS 打包。  
- 原则：先保证现有链路可交付，再推进工具替代。  

---

### Slide 11 — 收尾

1. 标题是 IE→ZE，但我真正想分享的是“接到任务后怎么解题”。  
2. 三个案例对应三种思路：验猜想、小步验算、Plan 选型。  
3. 可复制的是方法：拆解任务、阶段推进、证据驱动、文档沉淀。  

---

# English Version — Slides (~11 slides, 10 min)

---

### Slide 1 — Title

**From IE Engine to Zero Engine**  
How I broke down and drove the migration task  

[Your name] · ~10 minutes  
Scope: `taf-core-installer` (InstallAnywhere + Maven + GitLab)

---

### Slide 2 — Six quick context lines

1. PI is our product platform; this work is about its installer build chain.  
2. IE Engine is the old engine capability already embedded in the installer flow.  
3. Zero Engine is the target replacement we want to ship in the installer.  
4. InstallAnywhere is our current cross-OS installer build tool and the main workspace for this migration.  
5. The core task is IE Engine → Zero Engine migration in `taf-core-installer`, with build validation.  
6. So this talk is about my problem-solving path, not low-level troubleshooting details.  

---

### Slide 3 — My 4-step problem-solving path

```text
Step 1: extract installer-related logic from refactor-pi, create pi-installer workspace
Step 2: map the current state (touchpoints, packaging flow, evidence, validation path)
Step 3: execute by phases
  - Phase 1: remove old IE Engine content and validate build
  - Phase 2: package Zero Engine and validate
Step 4: long-term research: can we replace InstallAnywhere for multi-OS packaging?
```

---

### Slide 4 — The 3 main cases (#2 / #5 / #10)

| Case | Which step | Thinking pattern |
|------|------------|------------------|
| #2 JRE 11 vs 21 | Step 2 | read first, form a hypothesis, ask AI to verify |
| #5 huge XML failure | Step 3 / Phase 1 | let AI do heavy edits, validate in small safe steps |
| #10 green but no ZESvc | Step 3 / Phase 2 | align facts, use Plan to compare options, then execute |

---

### Slide 5 — Case #2: hypothesis first

- Read logs myself first.  
- Send AI a hypothesis with evidence.  
- Ask AI to prove/disprove with log lines.  
- Approve changes only after validation.  

> AI is my fast checker, not my replacement thinker.

---

### Slide 6 — Case #5: control in a scary XML

- New to InstallAnywhere and large XML.  
- AI can edit fast, but errors are normal.  
- Use build/parse failures as feedback signals.  
- Narrow scope, fix in small steps, write lessons down.  

> The key is not “one-shot success”; the key is a process that catches mistakes.

---

### Slide 7 — Case #10: contrast → Plan first

- Build is green, install looks green, outcome is wrong.  
- Align facts from build/install logs first.  
- Compare options in Plan mode.  
- I choose; Agent executes; I own final validation.  

> On strong-contrast issues, option selection is the value.

---

### Slide 8 — Four reusable prompts

1. Give logs + my hypothesis; verify first, no edits yet.  
2. Give absolute project path; edit this repo only.  
3. If multiple options exist, compare first in Plan mode.  
4. After execution, separate AI-verified checks and my required checks.  

---

### Slide 9 — Productivity note

- Manual SI-related removal in `taf-core-installer`: about 4 person-days (without full sign-off).  
- Similar edit scope with Cursor: about 30 minutes.  
- Validation is still mine; target is around one person-day total verification effort.  

---

### Slide 10 — Long-term direction

- Stabilize IE→ZE delivery first.  
- In parallel, research replacing InstallAnywhere for multi-OS packaging.  
- Keep the order: deliver now, modernize next.  

---

### Slide 11 — Close

1. The title is IE→ZE, but the core sharing is “how I solve migration tasks.”  
2. Three cases, three patterns: hypothesis check, small-step validation, plan-before-execute.  
3. The reusable part is the method: staged plan, evidence-driven decisions, and documentation.  

---

## 演示建议（主讲人备忘）

| 分钟 | 内容 |
|------|------|
| 0:00–1:20 | Slide 1–3（标题 + 6 句背景 + 4 步路径） |
| 1:20–6:50 | Slide 4–7（三个主案例） |
| 6:50–8:20 | Slide 8（4 句模板 + 边界） |
| 8:20–9:10 | Slide 9（效率一句） |
| 9:10–10:00 | Slide 10–11（长期规划 + 收尾） |

**注意**：你要讲的是方法，不是细节修复教程。  
**敏感信息**：路径打码，保留关键词即可。
