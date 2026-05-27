# 案例实操明细：我做了什么、怎么做的

> **用途**：团队分享时可对照本文件展示「具体操作」，配合幻灯片 [`cursor-team-share-outline.md`](cursor-team-share-outline.md)  
> **范围**：主线 Step 1–4 + 案例 #2 / #5 / #10 / SI 移除（效率对照）  
> **说明**：`pi-installer` 仓库内**没有**历史对话或 GitLab 的截图文件；下文列出**可截取的画面**与**日志关键词**，请在本机按路径打开后自行截图（演示前建议打码路径）。  
> **原话**：摘自真实对话；每条先中文后 **English**（plain wording，便于国外同事对照）。

---

## 一、主线：接到任务后我做了什么（总览）

| 步骤 | 我做了什么 | 怎么做的 | 沉淀在哪里 |
|------|------------|----------|------------|
| **1. 建独立工作区** | 从 `refactor_pi` 抽出安装器相关认知，不跟运行时 ZE 迁移混在一个对话里 | 建 `pi-installer`；写 `docs/context-snapshot.md`、`task-process.md`；用 [`links/refactor-pi-crossrefs.md`](../links/refactor-pi-crossrefs.md) 指到 `refactor_pi` 文档 | 本仓库根目录与 `docs/` |
| **2. 摸清现状** | 确认源码在 `cursor_out/copy`（非 `pi_origin`）；盘点 IE 触点、打包链 | 让 AI 读 `pom.xml`、`TAFCore.iap_xml`、`current-state/04-ie-engine-in-installer.md`；对照升级后基线校正文档 | `context-snapshot.md`、`current-state/` |
| **3. 分阶段执行** | 阶段 1 去 IE + 打包验证；阶段 2 接 ZE + 打包/装机验证 | 每阶段：先文档/Plan → 限定工程路径 → AI 改 → 我跑 GitLab/本机 | `migration-tasks/`、`completed/` |
| **4. 长期研究** | 登记「是否替换 InstallAnywhere」为远期，不阻塞 IE→ZE | 子目录 `docs/replace-installanywhere/`，任务在 `task-process.md` 标为未开始 | `replace-installanywhere/` |

**你可截的图（Step 1）**

| 序号 | 截什么 | 在哪里 |
|------|--------|--------|
| S0-1 | `pi-installer` 目录树（`docs/`、`migration-tasks/`、`.cursor/rules/`） | 资源管理器或 Cursor 侧栏 |
| S0-2 | `refactor-pi-crossrefs.md` 中「何时查阅 refactor_pi」表 | 本仓库 `docs/links/` |
| S0-3 | `task-process.md` 里 P1 去 IE / 打 ZE 勾选进度 | 本仓库 `docs/` |

---

## 二、案例 #2：JRE 11 而不是 21（思路：先自读 → 猜想+依据 → AI 验证）

### 2.1 背景（一句话）

`pom.xml` 声明 JRE 21，但 GitLab 打出的安装包实际嵌的是 JRE 11（Corretto 11 回退）。

### 2.2 我做了什么（按时间）

| 序号 | 我的动作 | 目的 |
|------|----------|------|
| 1 | 去掉 IE 后本机安装，发现报错；把**完整安装日志路径**发给 AI，要求**先分析、不改工程** | 先分类问题（与 JRE 案例交叉，但 #2 焦点在打包 JRE） |
| 2 | 指定工程路径：`D:\cursor_workspace\cursor_out\copy\taf-core-installer` | 避免改错副本 |
| 3 | 自己看到 `vm-packs` 下有 JRE8 文件，**不确定是否参与构建**，向 AI 提问 | 排除干扰项 |
| 4 | 阅读 GitLab **`build.txt`** 后，主动提出**猜想+两条依据**，请 AI 分析日志是否支持 | 用证据验算，而非让 AI 盲改 |
| 5 | AI 用日志行号确认回退链后，我要求改 **bundled VM** 为 21，并确认删除无用 `vm-packs` | 我批准后才改 |
| 6 | 纠正 AI「看不到 vm-packs 文件」：给出**绝对路径**让其再读 | 坚持以真实文件为准 |

### 2.3 我怎么做的（方法 + 原话要点）

**思路**：自己先读 → 形成猜想和依据 → 交给 AI 判断对错 → 再批准修改。

**我发给 AI 的核心表述（摘自对话，可放在分享页「原话」）**：

**① 先提供现象与路径（安装回归后，过渡到 JRE 问题前也常这样问）**

中文：

```text
我把 ie engine 从 taf-core-installer 去掉后，打包安装了，但提示
「安装完毕，但安装期间出现了一些错误」。
完整安装日志见 E:\software\PI3.0.1\main\_installation\Logs\PowerInsight_安装_05_25_2026_08_40_57.log。
请先分析和总结日志里总共有哪几类问题。
```

English:

```text
After I removed IE Engine from taf-core-installer and installed the package,
I got “installation finished, but some errors occurred during installation.”
Full install log: E:\software\PI3.0.1\main\_installation\Logs\PowerInsight_安装_05_25_2026_08_40_57.log.
Please analyze first and summarize how many types of issues are in the log.
```

**② 提出 JRE 疑问**

中文：

```text
打包工程的路径为 D:\cursor_workspace\cursor_out\copy\taf-core-installer，
为什么打出来的包是 jre11 而不是 jre21？
且我在工程目录下看到了 vm-packs 下的 jre8，有起作用么？
```

English:

```text
The build project path is D:\cursor_workspace\cursor_out\copy\taf-core-installer.
Why does the package ship JRE 11 instead of JRE 21?
I also see JRE 8 files under vm-packs — do they actually take effect in the build?
```

**③ 猜想 + 依据，请 AI 验证**

中文:

```text
我有个猜想：TAFCore.iap_xml 里面寻找 "zulu-jre-8.90.0.19-win64.vm" 找不到，
就使用了 InstallAnywhere 内置的 "AmazonCorretto11.0.27_Windows-x64.vm"。
依据：1. 能在 TAFCore.iap_xml 里找到该引用
      2. gitlab 打包日志 build.txt 请你分析
```

English:

```text
My guess: TAFCore.iap_xml still looks for "zulu-jre-8.90.0.19-win64.vm".
When it cannot find it, InstallAnywhere falls back to the built-in
"AmazonCorretto11.0.27_Windows-x64.vm".
Evidence: (1) I can still see that reference in TAFCore.iap_xml.
(2) Please analyze the GitLab build log build.txt.
```

**④ 确认后批准修改**

中文:

```text
根据上面的分析和结论，帮我改 cursor_out\copy\taf-core-installer；
同时 vm-packs 下的 jre8 应该不需要，你也确认下。
注意别改错工程。
```

English:

```text
Based on the analysis above, please update cursor_out\copy\taf-core-installer.
I also think the JRE 8 files under vm-packs are not needed — please confirm.
Be careful not to edit the wrong project.
```

**⑤ 纠正 AI（坚持以真实文件为准）**

中文:

```text
我确实看到有那两个 .vm 文件啊。你看不到？
请再看绝对路径 D:\cursor_workspace\cursor_out\copy\taf-core-installer\src\main\resources\vm-packs
```

English:

```text
I do see those two .vm files. Can you not see them?
Please check this absolute path again:
D:\cursor_workspace\cursor_out\copy\taf-core-installer\src\main\resources\vm-packs
```

**AI 主要帮我**：对照 `pom.xml`、`TAFCore.iap_xml`、`build.txt`；指出证明「找不到 8 → 回退 11」的**具体日志行**；确认 `vm-packs` 未参与当前构建。

**我亲自做的验证**：GitLab 重新打包；本机安装看 `jre\release`；必要时再读安装日志。

### 2.4 产出与文档

| 类型 | 位置 |
|------|------|
| 结论快照 | [`docs/context-snapshot.md`](../context-snapshot.md) § 2026-05-25 Windows 安装回归 |
| 工程改动 | `cursor_out/copy/taf-core-installer`：`TAFCore.iap_xml` bundled VM → `zulu-jre-21-win64.vm`；删除 `vm-packs` 旧 JRE8 |

### 2.5 可截图素材（请在本机截取）

| 序号 | 建议画面 | 文件/关键词（打码路径即可） |
|------|----------|------------------------------|
| S2-1 | Cursor 对话：猜想 + 「先分析 build.txt」 | 对话记录 |
| S2-2 | `build.txt` 搜索 **`zulu-jre-8.90.0.19-win64.vm`** 与 **`AmazonCorretto11`** | 用户路径示例：`...\PI next release\build.txt` |
| S2-3 | `TAFCore.iap_xml` 搜索 **`zulu-jre-21-win64`**（改后） | 工程内 |
| S2-4 | 安装目录 `jre\release` 显示 **21**（验证成功时） | `E:\software\PI3.0.1\main\jre\release` |

---

## 三、案例 #5：删 IE 后 IA XML 解析失败（思路：不熟大 XML，AI 重活 + 人验算）

### 3.1 背景（一句话）

刚接手 InstallAnywhere；`TAFCore.iap_xml` 约 **4 万行**。用脚本/AI 批量删 IE 后，GitLab `buildinstaller` **退出码 100**，XML 无法解析。

### 3.2 我做了什么

| 序号 | 我的动作 | 目的 |
|------|----------|------|
| 1 | 委托 AI 按任务文档**批量删除** IE 相关 ActionGroup/依赖（阶段 1） | 自己不敢手改超大 XML |
| 2 | GitLab 失败后，自己看日志，确认是 **`ParseException` / `</visualChildren>`** 不匹配 | 区分「结构坏」vs「业务/Maven」 |
| 3 | 要求 AI **修正删除策略**（按 ActionGroup 边界删，不剪坏父级闭合标签） | 第二轮小步、可验证 |
| 4 | 要求改完后做 **XML 开闭标签数量校验**、更新 `apply_ie_removal.py` | 流程兜住 AI 误删 |
| 5 | 把教训写进 **`remove-ie-and-zero-engine-defaults.md`** § 四 | 以后可复用 |

### 3.3 我怎么做的

**思路**：敢用 AI 做重活；默认会错；用构建/解析失败当反馈；缩小范围再改；文档记教训。

**原话（本 case 多为「失败后第二轮」表述，归档文档中还原）**

中文:

```text
GitLab 打包在 buildinstaller 阶段失败，退出码 100。
请先根据日志判断是 XML 结构问题还是 Maven/依赖问题，不要先大范围改代码。
如果是删 IE 时破坏了 TAFCore.iap_xml 结构，请按 ActionGroup 边界修正删除方式，
删完后校验 visualChildren / installChildren 标签开闭是否一致。
```

English:

```text
GitLab build failed at the buildinstaller stage with exit code 100.
Please read the log first and tell me whether this is an XML structure problem
or a Maven/dependency problem. Do not make large edits blindly.
If removing IE broke TAFCore.iap_xml, fix the delete strategy by ActionGroup boundaries,
then verify that visualChildren / installChildren open-close tags still match.
```

**日志关键行（适合截图高亮）**：

```text
XMLScriptReader: unable to parse the provided script file.
com.zerog.xml.parser.ParseException: No matching end element: </visualChildren>
```

**根因（已归档，分享时可一句带过）**：脚本删 IE 时误删父级 `</visualChildren>` / `</object>`，与 IE Maven 依赖无关。

**修复方向（我推动的）**：

- 按 ActionGroup **起始行缩进** 定位该组自己的 `</object>` 再删；
- 嵌套组保留外层闭合标签；
- 删除后校验 `<visualChildren>` / `<installChildren>` 开闭数量一致。

### 3.4 产出与文档

| 类型 | 位置 |
|------|------|
| 变更记录 + 打包失败说明 | [`docs/migration-tasks/completed/remove-ie-and-zero-engine-defaults.md`](../migration-tasks/completed/remove-ie-and-zero-engine-defaults.md) § 四 |
| 脚本 | `taf-core-installer/scripts/apply_ie_removal.py`（及后续修正） |
| IE 触点盘点 | [`docs/current-state/04-ie-engine-in-installer.md`](../current-state/04-ie-engine-in-installer.md) |

### 3.5 可截图素材

| 序号 | 建议画面 | 在哪里 |
|------|----------|--------|
| S5-1 | GitLab Job 失败：**exit code 100**，阶段 `buildinstaller` | GitLab CI 页面 |
| S5-2 | `build-fail-log.txt` 或 build 日志中的 **ParseException** 两行 | 文档 § 四 已摘录 |
| S5-3 | `remove-ie-and-zero-engine-defaults.md` 中「修复策略」表格 | 本仓库 |
| S5-4 | Cursor：我要求「小步 + 校验标签」的第二轮对话 | 对话记录 |

---

## 四、案例 #10：构建/安装都成功但没有 ZESvc（思路：Plan 选型 → 拍板 → Agent 执行）

### 4.1 背景（一句话）

`build-4.txt` 显示 **`zeroengine(BUILD)`** 有耗时；本机安装 UI 成功，但无 `%INSTALL%\zeroengine\`、无 **`ZESvc`**、无 **8088**。

### 4.2 我做了什么

| 序号 | 我的动作 | 目的 |
|------|----------|------|
| 1 | 提供 **`build-4.txt`** + **安装日志目录**，先让 AI **判断我说的对不对** | 先对齐事实，不急着改 |
| 2 | 确认「介质里有 ZE、装机没跑 ZE 链」后，要求 **先列方案、不要直接改** | 进入 Plan |
| 3 | 追问 **A1/A2、B1/B2** 含义与「适合有 IA 环境」指什么 | 搞清选项再选 |
| 4 | 明确约束：**本机无 InstallAnywhere GUI**；**taf-core-installer 只服务 PI** → 选 **A2 + B2** | 我拍板 |
| 5 | 要求 **切换 Plan**：生成 plan 文档 → 我确认 → 再 **Agent 执行**并归档 | agent → plan → agent |
| 6 | 确认后发送：**「可以切换为 agent 来执行这个 plan 了」** | 执行边界清晰 |
| 7 | **GitLab 构建 + 本机安装** 仍由我完成 | 最终验收在人 |

### 4.3 我怎么做的（原话要点）

**① 先对齐事实**

中文:

```text
Gitlab 打包成功了；安装包也在本地安装成功了；
但是我在本地找不到 zesvc 的服务或者 8088。
打包日志：C:\Users\...\PI next release\build-4.txt，
安装日志：E:\software\PI3.0.1\main\_installation\Logs。
你先确定下我说的对不对；确实是这种情况的话，再结合信息分析下原因。
```

English:

```text
GitLab build succeeded and local install also reported success,
but I cannot find the ZESvc service or port 8088 on my machine.
Build log: C:\Users\...\PI next release\build-4.txt.
Install logs: E:\software\PI3.0.1\main\_installation\Logs.
First confirm whether my description is correct.
If it is, then analyze the cause based on the evidence.
```

**② 要求先列方案**

中文:

```text
你帮我改动 taf-core-installer 工程，有多种方案么？
有的话先提出来我决定后再改；并且，注意工程目录，别改错。
```

English:

```text
Please help change the taf-core-installer project.
Are there multiple options?
If yes, list them first and wait for my decision before editing.
Also watch the project path — do not edit the wrong repo.
```

**③ 搞清选项含义**

中文:

```text
A1, A2 具体是什么？能详细解释下不？
还有推荐度里面的「适合有 IA 环境」是指？
B1, B2 同上。
```

English:

```text
What exactly are A1 and A2? Please explain in detail.
In the recommendation, what does “fits when IA environment is available” mean?
Same question for B1 and B2.
```

**④ 拍板（约束 + 选择）**

中文:

```text
因为本地 windows 无法安装 InstallAnywhere，且不能每次打包都还要在某个 windows 上手动整下。
问题1 选 A2，但就像你说的，需要把卸载也考虑进去；
问题2 我选择 B2，因为目前 taf-core-installer 只服务于 PI 打包，
SI 已有别的体系和工程来打包了，且我想让 ze 和 PI 打包能尽可能集中一处好管理和维护。
```

English:

```text
I cannot install InstallAnywhere on my local Windows machine,
and I cannot rely on manual steps on a Windows box for every build.
For question 1 I choose A2, and uninstall must be included as you said.
For question 2 I choose B2, because taf-core-installer is PI-only now.
SI has its own packaging flow, and I want ZE and PI packaging in one place for easier maintenance.
```

**⑤ Plan → 确认 → Agent**

中文:

```text
我希望你切换成 plan，把需要我确定的给我，
同时生成 plan 文档给我确认，确认没问题后再切为 agent 类型执行，
并且把 plan 文档和执行结果归档到本工程里面。
```

English:

```text
Please switch to Plan mode and show me what still needs my decision.
Generate a plan document for my review.
After I confirm, switch to Agent mode to execute.
Archive both the plan and the execution results in this project workspace.
```

中文:

```text
确认。可以切换为 agent 来执行这个 plan 了。
```

English:

```text
Confirmed. You can switch to Agent mode and execute this plan now.
```

**⑥ 持久化要求（同类表述）**

中文:

```text
你当前有哪些 rules？怎么没把这个问题也持久化到当前工程里面？
```

English:

```text
What rules do you currently have? Why was this issue not persisted into the project workspace?
```

**我的决策摘要（分享用，不展开技术）**：

| 决策项 | 我的选择 | 我为什么这样选（思路） |
|--------|----------|------------------------|
| 文件落盘 | **A2**（xcopy 等脚本化） | 无 IA GUI，不能靠界面重扫目录 |
| 服务注册 | **B2**（挂到 PI `TAF CORE` 链） | 只打 PI 包，SI 链不走 |
| 流程 | Plan 文档 → 确认 → Agent | 反差大问题要先选型 |

### 4.4 产出与文档

| 类型 | 位置 |
|------|------|
| Plan + 实施 | [`docs/migration-tasks/05-ze-ia-install-fix-plan.md`](../migration-tasks/05-ze-ia-install-fix-plan.md) |
| 背景与根因（详细） | [`04-zero-engine-windows-service-plan.md`](../migration-tasks/04-zero-engine-windows-service-plan.md) § 2026-05-27 安装验证 |
| 脚本 | `cursor_out/copy/taf-core-installer/scripts/apply-ze-ia-fix.py`、`verify-ze-ia-fix.py` |

### 4.5 可截图素材（反差对照最重要）

| 序号 | 建议画面 | 关键词 / 对比 |
|------|----------|----------------|
| S10-1 | **build-4.txt** 搜索 **`zeroengine(BUILD)`** 或 **`[buildinstaller] zeroengine`** | 证明编进介质 |
| S10-2 | **安装日志** 搜索 **`ZESvc`** / **`zeroengine`** / **`8088`** → 无安装记录 | 证明装机未执行 |
| S10-3 | 本机 **`Get-Service ZESvc`** 或 services.msc 无 ZESvc | 现象 |
| S10-4 | `05-ze-ia-install-fix-plan.md` 决策表 **A2 / B2** | 本仓库 |
| S10-5 | Cursor：**Plan 文档确认 → agent 执行** 两段对话 | 对话记录 |
| S10-6 | 可选：`application-prod.properties` 已有 ZE 默认配置（说明「配置写了但服务没装」） | 安装目录 `config\` |

**一页对比表（可直接贴 PPT）**：

| 证据来源 | 构建阶段 | 安装阶段 |
|----------|----------|----------|
| 日志关键词 | 有 `zeroengine(BUILD)` | 无 `ZESvc.exe -install`、无 `zeroengine\` 复制 |
| 本机检查 | GitLab 绿 | 无 `zeroengine` 目录、无 8088 |

---

## 五、案例补充：SI 移除（效率对照，非分享主案例）

### 5.1 我做了什么

| 序号 | 我的动作 |
|------|----------|
| 1 | 要求 AI **评估**「从 taf-core-installer 删掉整个 SI 打包/组件/许可证逻辑」的工作量 |
| 2 | 细节多时要求走 **Plan**：列出 → 我确认 → 生成 plan → 归档 → 执行 |
| 3 | 确认 **Tier B（PI-only + SI_LICENSE→PI_LICENSE）** 后批准执行 |
| 4 | 强调：**归档相关内容和文档** |

### 5.2 我怎么做的（原话要点）

中文:

```text
你分析下整个 SI 打包/组件/许可证逻辑从 taf-core-installer 删掉这个目标，需要做多少内容？
你自己决定：如果还有很多细节需要我决定的话，可以切换成 plan，
重复上面的步骤：列出 - 我确认 - 生成 plan - 归档 - 执行。
```

English:

```text
Please analyze how much work is needed to remove all SI packaging / component / license logic
from taf-core-installer.
If many details still need my decision, switch to Plan mode and repeat:
list items → I confirm → generate plan → archive → execute.
```

中文:

```text
可以开始执行这个 plan。请注意：归档相关内容和文档。
```

English:

```text
You can start executing this plan. Please archive the related content and documents.
```

**相关（ZE 接入阶段，Plan 模式的原话，可与 #10 对照）**

中文:

```text
我接下来的想法和步骤：
1. 你对 zero engine 还有哪些需要确认的信息
2. 你和我确认 PI 接入 zero engine 需要做到什么程度、目标
3. 希望你能切换到 plan 模型，有不同的方向和方案则先给出来让我决定后再说；
   注意：你要尽量获取到绝大部分需要获取的内容和我确定后再开始执行计划
```

English:

```text
My next steps and expectations:
1. What else do you still need to confirm about Zero Engine?
2. Align with me on the target scope for PI integration with Zero Engine.
3. Please switch to Plan mode: if there are multiple directions or options,
   present them first and wait for my decision before execution.
   Try to gather most required information and confirm with me before you start.
```

中文:

```text
你目前只需要先改动 zero-engine-installer 和 taf-core-installer 的工程，
不需要做整套流程的验证（由我自己去 Gitlab 打出整个安装包后自行验证），
但你改动后的，能验证则还是验证下；把上面的也加到 plan 里面。
```

English:

```text
For now, only change the zero-engine-installer and taf-core-installer projects.
Do not run full end-to-end validation — I will build the full installer on GitLab myself.
Still run whatever local checks you can, and add this constraint to the plan.
```

中文:

```text
最后，我希望你能把这份计划文件及结果持久化到当前工程里面（不是 C 盘某个用户下），
作为后续的输入和追踪；然后你可以开始执行了。
```

English:

```text
Finally, persist this plan and its results in the current project workspace
(not under a user folder on C:), for follow-up and tracking.
Then you can start execution.
```

### 5.3 产出

[`docs/migration-tasks/06-remove-si-from-installer-plan.md`](../migration-tasks/06-remove-si-from-installer-plan.md)

### 5.4 效率粗算（分享用）

| 范围 | 粗算 |
|------|------|
| 人工改 SI 相关（不含完整验收） | **约 4 人天** |
| Cursor 协助同类改动 | **约 30 分钟** |
| 验收 | 仍由我驱动，目标整体约 **1 人天量级** |

### 5.5 可截图素材

| 序号 | 建议画面 |
|------|----------|
| S4-1 | `06-remove-si-from-installer-plan.md` 改动清单 § 2 |
| S4-2 | `TAFCore.iap_xml` 搜索 **`SI_LICENSE`** → 0 处，**`PI_LICENSE`** 有命中（改后） |
| S4-3 | `task-process.md` 中 SI 移除已勾选 |

---

## 六、三个案例 ↔ 四种思路（对照表）

| 案例 | 对应主线步骤 | 思路标签 | 我干的核心 |
|------|--------------|----------|------------|
| **#2** | Step 2 摸清现状 | 猜想验证 | 自读 build 日志 → 猜想+依据 → AI 行号验证 → 批准改 VM |
| **#5** | Step 3 阶段 1 去 IE | 小步验算 | 敢让 AI 删大 XML → 解析失败 → 缩范围改脚本 → 写教训 |
| **#10** | Step 3 阶段 2 接 ZE | Plan 选型 | 双日志对齐事实 → A/B 方案 → 选 A2+B2 → Plan 归档 → Agent 执行 |
| **SI** | Step 3 收敛 PI-only | Plan + 批量执行 | 要评估量 → Plan 确认 Tier B → 执行并归档 |

---

## 七、截图文件夹建议（你可自行创建）

仓库内暂无 `docs/presentations/screenshots/`。若要为分享准备图，建议：

```text
docs/presentations/screenshots/
├── README.md                 ← 列出每张图对应本文件序号 S2-1 …
├── case02-build-jre-fallback.png
├── case05-xml-parse-error.png
├── case10-build-vs-install-contrast.png
└── case-si-plan-checklist.png
```

把本机截好的 PNG 放进上述目录后，在 Markdown 中可写：

```markdown
![build 日志中的 JRE 回退](screenshots/case02-build-jre-fallback.png)
```

---

## 八、相关文件索引（无截图，可打开即「证据」）

| 文件 | 用途 |
|------|------|
| [`cursor-team-share-outline.md`](cursor-team-share-outline.md) | 幻灯片大纲 |
| [`cursor-team-share-script-zh.md`](cursor-team-share-script-zh.md) | 中文口播稿 |
| [`cursor-team-share-script-en.md`](cursor-team-share-script-en.md) | 英文口播稿 |
| [`../retrospectives/ai-installanywhere-collaboration.md`](../retrospectives/ai-installanywhere-collaboration.md) | 协作方式回望 |
| [`../visual/taf-core-installer-guide.html`](../visual/taf-core-installer-guide.html) | 安装器流程图（浏览器打开，可截全图） |

---

> **最后更新**：2026-05-27  
> **维护**：有新 case 或新截图时，在本文件追加「我做了什么 / 可截图素材」行即可。
