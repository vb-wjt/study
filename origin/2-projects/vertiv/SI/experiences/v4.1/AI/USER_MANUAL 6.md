## 目录

**主路径（建议按序阅读）**

1. [平台简介与核心概念](#1-平台简介与核心概念)
2. [安装与日常运维](#2-安装与日常运维)
3. [首次配置与快速上手](#3-首次配置与快速上手)
4. [角色管理](#4-角色管理)
5. [工作流编排](#5-工作流编排)
6. [运行监控与人工审批](#6-运行监控与人工审批)

**次路径（按需查阅）**

7. [Pack 导入导出](#7-pack-导入导出)
8. [批量管理与全局搜索](#8-批量管理与全局搜索)
9. [设置与系统健康](#9-设置与系统健康)
10. [官方示例工作流场景](#10-官方示例工作流场景)

**进阶与架构细节（工作流设计必读）**

11. [运行时的容器文件结构与节点共享通道](#11-运行时的容器文件结构与节点共享通道)
12. [密钥、工作流变量与共享文件机制](#12-密钥工作流变量与共享文件机制)
13. [AI 自动回环打回判定与配置指南](#13-ai-自动回环打回判定与配置指南)
14. [节点单点重试与人工反馈注入机制](#14-节点单点重试与人工反馈注入机制)
15. [执行历史占满磁盘时如何清理](#15-执行历史占满磁盘时如何清理)

**附录**

- [术语表](#附录-a-术语表)
- [常见问题](#附录-b-常见问题)
- [相关文档索引](#附录-c-相关文档索引)

---

## 1. 平台简介与核心概念

### 1.1 平台定位

**Agent Orchestra** 是一个多智能体工作流编排平台，在 Docker 沙箱中隔离执行，并提供全流程可视化、日志归档与人工介入能力。

### 1.2 核心概念

| 概念 | 含义 |
|------|------|
| **角色 (Role)** | AI 智能体模板：系统提示词 + 技能 / 规则 / 文档附件 |
| **工作流 (Workflow)** | 可复用的 DAG 模板：节点、边、工作流级变量、共享文件 |
| **运行 (Run)** | 某次对工作流的实例化执行；含实时 DAG、日志、产物 |
| **节点** | 三种可编排类型：**LLM**（运行智能体）、**人工**（暂停等待决策）、**Shell**（执行命令） |
| **边** | **FLOW**（无条件前进）或 **CONDITION**（按分支标签或表达式选路；回环边用于打回重做） |
| **变量** | 工作流级键值；在 Prompt 中用 `{{vars.key}}` 引用；在 Shell 命令中同样可用；标记「必填」的变量在启动前会校验 |
| **密钥占位符** | 仅在 **Shell 节点**命令中可用 `{{secrets.GITLAB_TOKEN}}` 等；值来自 **设置 → API 密钥**，运行时注入，不会出现在 LLM Prompt 明文里 |

### 1.3 界面总览

![仪表盘](./images/dashboard.png)

- **左侧导航**：仪表盘、角色管理、工作流、设置
- **顶栏搜索**：`Ctrl+K`（macOS 为 `⌘K`）打开命令面板，可搜索工作流、角色、运行记录
- **底部**：语言切换（中 / EN）、明暗主题切换

**仪表盘**展示四项统计（工作流、角色、执行总数、活跃中）、系统健康状态，以及最近执行记录。统计卡片可点击跳转到对应模块。

---

## 2. 安装与日常运维

平台支持离线部署模式：通过 GitLab 下载打包好的离线安装包（通常为 zip 格式），直接解压并在本机通过 Docker 运行。无需自行拉取源码、无需在本机配置 Node.js 运行环境。

**前置条件**

- **Docker Desktop**（Windows / macOS）或 **Docker Engine**（Linux），且保持运行状态。
- 从 GitLab 获取的 **离线安装包**（解压后包含 `start-docker.ps1`、`images/` 等文件）。
- **Cursor API Key**（运行 LLM 节点必需，见第 3 章）。

### 2.1 快速开始与安装部署

1. **下载安装包**：
   访问 GitLab Package Registry 页面：[https://gitlab.com/vertiv-co/apac/TAF/multi-agents/-/packages/61478871](https://gitlab.com/vertiv-co/apac/TAF/multi-agents/-/packages/61478871)
   下载最新发布的离线部署压缩包（`agent-orchestra-docker-1.1.0.zip`）。

2. **解压文件**：
   将下载好的 zip 压缩包解压到本地的任意目录（建议路径中不包含中文和空格，且路径深度不宜过深，如 `C:\agent-orchestra`）。

3. **启动平台**：
   确认 Docker Desktop 已启动。
   在解压后的目录中，使用 PowerShell（管理员权限）运行启动脚本：

   ```powershell
   .\start-docker.ps1
   ```

   *注：由于系统整体跨平台设计，解压包中亦包含用于 macOS/Linux 系统的 `./start-docker.sh` 脚本（运行前请先执行 `chmod +x start-docker.sh`）。若您的开发团队统一使用 Windows 系统，可直接忽略 `.sh` 文件。*

   首次启动时，系统会自动将 `images/` 目录下的离线镜像导入 Docker（由于镜像文件体积较大，导入可能需要 1~2 分钟，请耐心等待）。导入完成后，系统会自动执行数据库迁移和初始化，并预先植入 **3 个入门示例工作流** 与 **4 个官方内置角色**。

4. **访问平台**：
   启动成功后，在浏览器中打开：**http://127.0.0.1:5173**
   *（后端 API 网关默认运行在 http://127.0.0.1:4000）*

5. **首次配置**：
   参考第 3 章说明，在设置页面中配置您的 **Cursor API Token**。

您的业务数据（包括设计的工作流、运行记录、上传的附件和日志）都会持久化保存在解压目录下的 **`data/storage/`** 目录中。


### 2.2 日常使用

| 操作 | 做法 |
|------|------|
| **每天启动平台** | 在解压目录再次执行 `start-docker.ps1`（或 `start-docker.sh`） |
| **关闭平台** | 在解压目录执行：`docker compose --profile app down` |
| **查看日志** | 在解压目录执行：`docker compose --profile app logs -f` |

关闭电脑或退出 Docker Desktop 后，需重新执行启动脚本才能继续使用 Web UI。

### 2.3 版本升级

向管理员索取**新版本安装包**后：

1. 在旧目录执行 `docker compose --profile app down` 停止服务
2. 备份 `data/storage/`（含你的工作流与运行数据）
3. 解压新包到新目录（或覆盖除 `data/` 外的文件），将备份的 `data/storage` 拷回
4. 运行 `start-docker.ps1` 启动

不确定升级步骤时，请联系管理员。

### 2.4 入门示例

首次启动会自动植入 3 个可删示例（人工审核、并行、AI 打回），用于熟悉平台。删除后一般不会自动恢复；需要时可请管理员协助，或通过 **Pack 导入**（第 7 章）恢复同事分享的工作流。

### 2.5 故障排查

1. 确认 **Docker Desktop 正在运行**
2. 打开 Web **设置** 页，查看数据库、Redis、Docker、Cursor 令牌是否均为正常
3. 首次安装失败时：检查磁盘空间是否充足、`docker load` 是否报错；阅读解压目录内 **`README-OFFLINE.md`**
4. 仍无法解决：将 `docker compose --profile app logs` 输出提供给管理员

研发与发版说明见 [SETUP.md](./SETUP.md)、[DOCKER_RELEASE.md](./DOCKER_RELEASE.md)（维护人员文档，普通用户可忽略）。

---

## 3. 首次配置与快速上手

### 3.1 首次访问引导

首次打开 Web UI 会弹出 **欢迎使用 Agent Orchestra** 引导页，可粘贴以下 Token（均可跳过，稍后在设置中配置）：

| Token | 是否必需 | 用途 |
|-------|----------|------|
| **Cursor Token** | **必需**（运行 LLM 节点） | 通过 @cursor/sdk 执行 Agent |
| **GitLab Token** | 可选（拉私有仓库时 **必需**） | Shell 节点 `git clone` 鉴权；命令中用 `{{secrets.GITLAB_TOKEN}}`，见 [第 11 章](#11-运行时的容器文件结构与节点共享通道) |
| **Figma Token** | 可选 | UI/UX 类智能体访问 Figma |

点击 **保存并继续** 或 **全部跳过** 进入主界面。

### 3.2 在设置页保存 Token

![设置页](./images/settings.png)

1. 左侧导航 → **设置**
2. 在 **API 密钥** 区域填写 Token（留空表示保持已保存的值）
3. 点击 **保存设置**
4. 确认 **可用模型** 列表已加载（依赖 Cursor Token；未配置时列表为空）

密钥写入存储前会使用 `MASTER_KEY` 进行 **AES-256-GCM** 加密。

### 3.3 确认系统健康

在 **仪表盘** 或 **设置** 页的 **系统健康** 区域，确认以下四项均为 **正常**（绿色）：

- 数据库
- Redis
- Docker
- Cursor 令牌

任一项 **异常** 时，LLM 节点或 Run 可能无法启动，需先修复基础设施。

### 3.4 五分钟上手：运行第一个工作流

1. 左侧导航 → **工作流**
2. 在列表中找到官方模板（如 **AngularJS → Angular14 翻新流水线**）
3. 点击卡片上的 **运行**
4. 若 preflight 提示缺少必填变量或 Token，按提示补全后重试
5. 自动跳转到 **运行详情** 页，观察：
   - 左侧 DAG 节点状态着色
   - 右侧 **执行日志**、**最近尝试**、**产物**

> **Preflight 说明**：启动 Run 前，平台会检查 Cursor Token 是否已配置，以及工作流中标记为「必填」的变量是否已填写。未通过则无法启动。

---

## 4. 角色管理

### 4.1 页面入口

左侧导航 → **角色管理**（路径 `/roles`）。

![角色管理](./images/roles.png)

页头提供 **导入**、**批量管理**、**+ 创建角色**。

### 4.2 创建与编辑角色

点击 **+ 创建角色**，填写：

| 字段 | 说明 |
|------|------|
| **角色名称** | 全局唯一，不可与已有角色重复 |
| **描述** | 简要说明能力范围（展示在卡片上） |
| **系统提示词** | 该智能体的核心 persona，运行时注入 LLM 上下文 |

点击已有角色卡片（非批量模式）可打开 **编辑角色** 对话框，修改上述字段。

### 4.3 技能、规则与文档

每个角色卡片底部有三个计数按钮：

| 类型 | 含义 | 运行时注入路径 |
|------|------|----------------|
| **技能** | Cursor Skill 文件 | `.cursor/skills/` |
| **规则** | Cursor Rule 文件 | `.cursor/rules/` |
| **文档与参考资料** | 参考文档 | `.cursor/docs/` |

**操作方式：**

- 点击按钮左半部分 → 打开文件列表（查看、下载、删除；支持全选批量删除）
- 点击右半部分上传图标 → 选择文件上传

**上传限制：**

- 单文件 ≤ 5MB
- 支持 `.md`、`.txt`、`.json`、`.yaml`、`.yml`、`.zip`
- `.zip` 会解压到对应类型目录，适合批量导入 Cursor skill 目录结构

> 平台不提供在线编辑文件内容，请在本机编辑后重新上传。

### 4.4 运行时行为

- **系统提示词** → 进入 LLM 节点的 Prompt 组装（节点 Prompt 中可用 `{{role.systemPrompt}}` 引用）
- **技能 / 规则 / 文档** → 复制 to Runner 工作区的 `.cursor/` 子目录，由 Cursor Agent 机制生效

### 4.5 删除角色

- 卡片右上角垃圾桶 → 确认删除
- 删除会**级联删除**该角色全部附件，**不可恢复**
- 若工作流 LLM 节点仍绑定该角色，需先在编辑器中更换角色

### 4.6 在工作流中使用角色

在工作流编辑器中选中 **LLM 节点** → 右侧 Inspector **角色** 下拉 → 选择已创建的角色。详见 [第 5 章](#5-工作流编排)。

---

## 5. 工作流编排

### 5.1 工作流列表

![工作流列表](./images/workflows-list.png)

左侧导航 → **工作流**。每张卡片显示运行次数、节点数、节点标签预览、更新时间。

| 操作 | 说明 |
|------|------|
| **+ 新建工作流** | 进入空白画布编辑器 |
| **编辑** | 打开画布 |
| **历史** | 查看该工作流全部 Run |
| **运行** | Preflight 通过后启动 Run，跳转运行详情 |
| **导出** | 导出为 `.aopack.zip`（自动附带节点引用的角色） |
| **删除** | 删除工作流及全部 Run 记录 |

**删除时有活跃 Run：** 会提示 **强制取消并删除**。注意：已启动的 Runner 容器可能需等待自身超时（默认最长约 30 分钟）才会停止，期间仍可能消耗 API 配额。

### 5.2 画布编辑器

![工作流编辑器](./images/workflow-editor.png)

#### 工具栏

| 按钮 | 说明 |
|------|------|
| **历史** | 跳转该工作流的执行历史（需已保存） |
| **保存** | 创建或更新工作流 |
| **保存并运行** | 先保存 → Preflight → 启动 Run |

编辑过程中离开页面时，若有未保存更改，会提示 **留下** / **丢弃并离开** / **保存并离开**。

#### 节点调色板

从左上角拖入画布：

| 类型 | 用途 |
|------|------|
| **LLM** | 运行 LLM 智能体（需绑定角色） |
| **人工** | 暂停，等待人工决策 |
| **Shell** | 在容器中执行 Shell 命令 |

**提示：** 双击节点打开详情大窗；从节点边缘锚点拖线可连线。

#### 连线规则

- 禁止节点连接自身
- 禁止重复边
- **FLOW 边**不允许形成环（检测到环会拒绝连线）
- 若连线目标位于源的**上游**，自动创建 **CONDITION 回环边**（默认最大回环 3 次）

### 5.3 节点配置（Inspector / 节点详情）

选中节点后，右侧 **Inspector** 显示配置项；双击节点打开 **NodeDetailDialog** 大窗，内容等价。

#### LLM 节点

| 字段 | 说明 |
|------|------|
| **标签** | 节点显示名；也用于 `{{output.标签}}` 引用上游输出 |
| **描述** | 内部备注，不发送给模型 |
| **角色** | 绑定 [第 4 章](#4-角色管理) 创建的角色 |
| **提示词** | 节点级 Prompt；可用 `{{output.上游标签}}`、`{{vars.key}}` |
| **模型** | 从 Cursor 可用模型列表选择；**Auto** 为默认 |
| **模型参数** | 可选 effort、context 等自定义参数 |
| **MCP 服务** | 多选 **Figma** / **Playwright**；勾选后 Runner 才启动对应 MCP（Figma 需在设置页配置 Token）。新建 LLM 节点默认不勾选 |
| **超时（秒）** | 单 attempt 最长执行时间 |
| **最大尝试** | 该节点最多 attempt 次数（取消 / 打回也占用编号） |

#### 人工节点

| 字段 | 说明 |
|------|------|
| **展示给审核者的提示** | 运行到此节点时弹窗显示的文字 |
| **选项（逗号分隔）** | 审核按钮列表，默认 `approve,reject`；**reject** 会触发打回上游 |

#### Shell 节点

| 字段 | 说明 |
|------|------|
| **命令** | 在 Runner 容器中执行的 Shell 命令（常用于 `git clone` 等初始化） |

私有 Git 仓库拉取与 `{{secrets.GITLAB_TOKEN}}` 用法见 [第 11 章](#11-运行时的容器文件结构与节点共享通道)。

### 5.4 边配置

选中边后，Inspector 显示：

| 类型 | 说明 |
|------|------|
| **FLOW（无条件）** | 上游完成后无条件触发下游 |
| **CONDITION（求值路径）** | 按条件选路 |

**CONDITION 两种模式：**

1. **表达式**：路径（如 `data.verdict.approved`）+ 运算符 + 值
2. **分支标签**：LLM 输出中选择 `_branch.label` 匹配的分支

**回环边**（拖到上游时自动创建）额外显示 **最大回环次数**。超过次数后，引擎可 **升级 (ESCALATE)** 到人工节点，由人工决定 approve / restart / abort。

### 5.5 工作流级变量

未选中节点/边时，Inspector 下方显示 **Variables** 面板：

- 点击 **+** 添加键值对
- 勾选 **必填** 后，启动 Run 前 preflight 会校验
- 在 LLM 节点 **提示词** 中用 `{{vars.key}}` 引用
- 在 Shell 节点 **命令** 中同样用 `{{vars.key}}` 引用

变量定义与 Prompt 用法的完整说明见 [第 12 章](#12-密钥工作流变量与共享文件机制)。

### 5.6 共享文件

**Shared files** 面板（需先保存工作流）：

- 上传文件或 `.zip`（zip 会解压）
- 下载、删除已上传文件
- 运行时自动投影到 Runner 内 **`/shared/`** 路径（如 `/shared/handbook/`）

官方 Angular 迁移流水线建议将产品手册上传到 `handbook/` 前缀目录，详见 [第 10 章](#10-官方示例工作流场景)。

### 5.7 循环与打回（用户可见效果）

```mermaid
flowchart LR
  upstream[上游节点完成] --> branch{路由}
  branch -->|FLOW 边| next[继续下游]
  branch -->|CONDITION 回环| retry[上游重新执行]
  branch -->|超过 maxLoops| human[升级到人工节点]
  reject[人工 reject] --> retry
```

用户无需了解引擎 Intent 协议，只需知道：

- Agent 可在输出中声明打回（loopback），附带反馈注入下次 Prompt
- 人工选择 **reject** 时需指定 **打回目标** 节点
- 回环次数耗尽时会弹出人工决策，选项可能包含 restart / approve / abort

---

## 6. 运行监控与人工审批

### 6.1 启动 Run 的三种方式

| 入口 | 路径 |
|------|------|
| 工作流列表 **运行** | `/workflows` 卡片 |
| 画布 **保存并运行** | `/workflows/:id/edit` |
| 执行历史 **新建运行** | `/workflows/:id/runs` |

启动前均会 **Preflight**：检查 Cursor Token、必填变量等。

### 6.2 执行历史

工作流卡片 → **历史**，或运行详情顶栏 → **历史**。

列表展示每次 Run 的 **状态**、**编号**、**调用**（已用 / 上限）、**耗时**、**创建时间**。有活跃 Run 时每 5秒自动刷新。点击任一行进入运行详情。

### 6.3 运行详情页

**布局：**

- **左侧**：只读执行 DAG，节点按最新 execution 着色
- **右侧**：执行日志、最近尝试、产物

**顶栏信息：** 工作流名、Run 短 ID、API 调用配额、Run 状态徽章。

**操作：**

| 按钮 | 说明 |
|------|------|
| **返回** | 回到上一页 |
| **历史** | 跳转该工作流执行历史 |
| **取消** | 取消进行中的 Run（RUNNING / PENDING / INITIALIZING） |

**节点交互：** 双击节点 → 打开节点详情，查看各 attempt 的输入载荷、输出 JSON、产物路径、Intents。

**侧栏：**

- **执行日志**：实时流式输出；可 **清空** 本地日志视图
- **最近尝试**：快速跳转节点 attempt
- **产物**：输出文件路径列表

### 6.4 Run 状态

| 状态 | 含义 |
|------|------|
| PENDING | 已创建，等待调度 |
| INITIALIZING | 初始化 RunPlan / 环境 |
| RUNNING | 执行中 |
| COMPLETED | 全部节点成功完成 |
| FAILED | 某节点失败且未恢复 |
| PAUSED | 暂停（如等待人工） |
| CANCELLED | 用户取消 |

典型流转：`PENDING` → `INITIALIZING` → `RUNNING` → `COMPLETED` / `FAILED` / `CANCELLED`。

**节点 execution 状态**（DAG 着色）：QUEUED、RUNNING、COMPLETED、FAILED、**PENDING_HUMAN**（紫色）、CANCELLED、SUPERSEDED。

### 6.5 人工审批

当 Run 到达 **人工** 节点时：

1. 自动弹出 **需要人工决策** 对话框
2. 展示：**审核提示**、**上游节点输出**、选项按钮、可选 **反馈**（会注入后续 Prompt）
3. 选择 **approve** 等选项 → 提交，Run 继续
4. 选择 **reject** → 必须选择 **打回目标** 上游节点 + 填写反馈 → 上游重新执行

关闭弹窗后，同一 pending 节点不会重复自动弹出（直到状态变化）；可通过浮动 **需要人工决策** 按钮重新打开。

### 6.6 失败与单节点重试

Run 状态为 **FAILED** 或 **CANCELLED** 时：

1. 双击失败节点 → 节点详情（mode: 可编辑重试）
2. 修改配置（如 Prompt、模型、最大尝试次数）
3. 点击 **保存并重试节点**

效果：从该节点重新执行，**保留上游产物**；下游 execution 标记为 SUPERSEDED。

> **Attempt 预算**：取消、打回、手动重试均占用 attempt 编号。若「下次 attempt 序号 > 最大尝试次数」，需先在 Inspector 提高 **最大尝试** 再重试。

---

## 7. Pack 导入导出

Pack（`.aopack.zip`）用于在团队或环境间迁移 **角色 + 工作流**，无需共享数据库。

### 7.1 导出

| 入口 | 内容 |
|------|------|
| 角色卡片 **导出** | 单个角色及其全部附件 |
| 工作流卡片 **导出** | 工作流 + 节点引用的角色（自动收集） |

下载文件命名形如 `ao-export-<timestamp>.aopack.zip`。

### 7.2 导入

1. **角色管理** 或 **工作流** 页头 → **导入**
2. 选择 `.zip` / `.aopack.zip`
3. 平台 **预览** 包内容（角色数、工作流数）
4. 若与现有数据冲突（按 `packId` 或名称匹配），逐项选择：
   - **覆盖**（替换同名/同 packId 项）
   - **新建副本**（自动重命名，如 `xxx (import)`）
   - **跳过此项**
5. 点击 **确认导入**

### 7.3 与管理员分发包的区别

| 方式 | 适用场景 |
|------|----------|
| **UI Pack 导入/导出** | 同事之间分享、迁移你自己创建或修改的工作流与角色 |
| **管理员安装包（zip）** | 首次安装平台、升级平台版本；由 IT/维护者统一分发 |

---

## 8. 批量管理与全局搜索

### 8.1 批量管理

**角色管理** 与 **工作流** 页均提供 **批量管理**：

1. 点击 **批量管理** 进入多选模式
2. 点击卡片勾选
3. 点击 **批量删除** → 确认

> 批量模式**仅支持删除**，不支持批量 Pack 导出。

角色 **文件列表** 弹窗内支持 **全选 + 批量删除** 附件。

### 8.2 全局搜索（Ctrl+K / ⌘K）

顶栏搜索框或快捷键打开命令面板：

- **快捷跳转**：仪表盘、角色管理、工作流、新建工作流、设置
- **搜索工作流** → 直接进入编辑器
- **搜索角色** → 跳转角色管理页
- **搜索运行记录** → 最近 10 条 Run，点击进入运行详情

---

## 9. 设置与系统健康

### 9.1 系统健康

仪表盘与设置页均展示四项依赖状态：

| 组件 | 异常时的常见原因 |
|------|------------------|
| 数据库 | 应用容器未就绪；确认已执行 `start-docker.ps1` 且 Docker 正常 |
| Redis | Redis 未启动 |
| Docker | Docker Desktop 未运行 |
| Cursor 令牌 | 未配置或 Token 无效 |

### 9.2 API 密钥

见 [第 3 章](#3-首次配置与快速上手)。保存后可在 **可用模型** 区域确认 Cursor 模型列表。

若 Runner 日志报 **unknown model**，在此核对模型 ID 与工作流节点配置是否一致。

### 9.3 Network & Trust

设置页 **Network & Trust** 区块（企业网络环境）：

- 显示 Node TLS 信任库状态，用于应对 Zscaler 等企业 MITM 代理
- **Probe TLS**：探测与 `api.cursor.com` 的 TLS 连通性
- **Refresh Trust**：刷新信任库

若 Cursor API 调用因证书问题失败，可在此排查。

---

## 10. 官方示例工作流场景

首次安装后，工作流列表中会出现 **3 个入门示例**（人工审核、并行、AI 打回），可直接运行体验。管理员也可能通过安装包或 Pack 下发更多场景模板。

### 10.1 AngularJS → Angular14 翻新流水线

**路径：** `workflows/angular14-migration/` · **6 个节点**

```text
拉取源码
  → spec生成（老动线 + 新图纸 + 老逻辑 → spec 包）
  → 规格审查 (人工，reject 可打回 spec生成)
  → 页面开发 ⇄ 代码审核
  → 视觉验收（截图 + diff + 审计 + 打回页面开发）
```

**推荐绑定的通用角色**（安装包首次启动已植入）：

| 角色 | 职责 |
|------|------|
| 规格工程师 | 多源合并为可审查规格（本流水线具体路径见节点 prompt） |
| 前端实现工程师 | 按已批准规格实现；项目 skills/rules/docs 由用户上传到该角色 |
| 代码审核专家 | 只读审核、结构化评分与 pass/rework |
| 视觉验收工程师 | 截图对比、分级问题与验收报告 |

**运行前需准备：**

| 资源 | 提供方式 |
|------|----------|
| 产品手册 | 工作流编辑器 **共享文件** 上传（建议 `handbook/` 前缀）→ 运行时 `/shared/handbook/` |
| 老代码仓库 | Shell 节点 `git clone`（需 **GitLab Token**）→ `/shared/source/` |
| Figma 设计 | 工作流变量 `figmaFileUrl`（spec生成、页面开发、视觉验收共用） |

### 10.2 Visual Review（最小验证）

**路径：** `workflows/visual-review-minimal/`

拓扑：`Prep (Shell)` → 状态矩阵 (LLM) → 视觉验收 (LLM) → 客观校验 (LLM) → 审计 (LLM)

**必填变量：** `figmaUrl`（Figma 设计链接）

适合作为 POC，验证 Playwright + Figma MCP 视觉验收链路。

### 10.3 关于 prompts 目录

日常请在 **UI 工作流编辑器** 中直接修改节点 Prompt。通过 Pack 导入的工作流会一并带入其提示词配置。

---

## 11. 运行时的容器文件结构与节点共享通道

在平台执行某个工作流时，引擎会在本地宿主机和隔离的 Docker 容器（Runner）中建立清晰的文件投影与挂载机制。要设计高级/复杂的工作流，必须深入理解它们的底层物理结构、运行时的 Working Directory (CWD)、拉取代码后存放的位置，以及节点间共享文件的核心通道。

### 11.1 宿主机与隔离容器的物理文件映射

每次工作流**启动运行（Run）**，平台都会为该次运行分配一个唯一的随机 ID `runId`。整个生命周期内宿主机与容器的路径映射结构如下表：

| 宿主机实际物理路径（相对于 `<解压目录>/data/`） | 容器内挂载点（Runner 容器） | 访问权限 | 节点适用类型 | 说明 / 作用 |
|:---|:---|:---|:---|:---|
| `storage/shared/<runId>/` | `/shared` | **读写 (RW)** | **所有节点** (Shell & LLM) | **核心共享空间**：多个节点传递源码、构建产物、依赖缓存、截图的核心物理媒介。 |
| `storage/shared/<runId>/new-project/` | `/shared/new-project` | **读写 (RW)** | **所有节点** (Shell & LLM) | 平台专为 VDA 与经典项目工程构建保留的工程子目录。 |
| `storage/shared/<runId>/output/` | `/shared/output` | **读写 (RW)** | **所有节点** (Shell & LLM) | 存放最终输出、报告、截图，可在前端 UI 的“产物”页中直观浏览。 |
| `storage/workspaces/<runId>/<planNodeId>/` | `/workspace` | **读写 (RW)** | **LLM 节点专用** | **独立工作区**：对应具体的 LLM 节点，节点 A 绝对无法读取节点 B 的私有工作区，保障隔离。 |
| `storage/workspaces/<runId>/<planNodeId>/.cursor/` | `/workspace/.cursor` | **读写 (RW)** | **LLM 节点专用** | **Cursor 引擎配置区**：运行前，平台会自动把智能体角色的 Skills/Rules 拷贝到此，供底层 AI 自激活。 |
| `storage/files/<roleId>/` | — | 宿主只读拷贝 | — | 角色的物理附件存储目录，在执行前用于单向拷贝到 workspace。 |

### 11.2 Shell 节点的执行基准与 Git 拉代码流向

* **Shell 节点的运行基准（CWD）**：
  在配置工作流的 Shell 节点命令时，容器内部执行时的当前工作目录（CWD）被强制指定为 **`/shared`**。
* **代码拉到了哪里？**
  若在 Shell 脚本中运行了以下命令：
  ```bash
  mkdir -p /shared/source && cd /shared/source && git clone ... project-a
  ```
  该命令执行完毕后，代码将被拉到宿主机的 `storage/shared/<runId>/source/project-a` 下。在后续所有的节点容器中，这等价于容器内的 **`/shared/source/project-a`**。
* **命令基准点建议**：
  由于 Shell 节点以 `/shared` 为基准目录运行，如果在脚本中直接执行 `git clone ...`（无 `cd` 操作），克隆出的仓库文件夹将直接呈现在 `/shared/<repo-name>`。

### 11.3 Agent 节点如何直接使用/修改 Pull 下下来的文件？

* **Agent 节点的运行基准（CWD）**：
  LLM 节点容器启动时，底层的 Cursor Agent 进程会在 **`/workspace`** 目录（即节点的私有工作区）下激活。
* **跨越隔离读取源码**：
  Agent 在运行时，除了能看到 `/workspace`，还同时挂载了 `/shared`！
  因此，只要在 LLM 节点的提示词或 System Prompt 中，明确告诉 Agent **“请观察并修改 `/shared/source/project-a` 目录下的代码”**，Agent 的 Cursor 引擎就能通过绝对路径 `/shared/source/` 穿透过去，对拉下来的代码进行完整的静态分析、依赖重写（如重构 `package.json`）和代码修改。
* **文件访问拓扑结构图**：
  ```text
  [宿主机存储 storage/]
     ├── shared/<runId>/   <─── 挂载为容器内 /shared (Shell 的 CWD)
     │      └── source/
     │            └── project-a/  <─── Shell 拉取到的源码存放于此
     │
     └── workspaces/<runId>/<NodeId>/  <─── 挂载为容器内 /workspace (LLM 的 CWD)
                  └── .cursor/
                        ├── rules/      <─── 自动投影该智能体绑定的 Rules
                        └── skills/     <─── 自动投影该智能体绑定的 Skills
  ```

### 11.4 节点间“文件分享/传递”的最佳实践

工作流不仅支持单目录深度读写，还支持标准的**依赖拓扑输出传递**。

1. **手动在 `/shared` 目录下指定子文件夹传递**：
   - 比如前置 Node A 运行完后，将生成的 `spec.json` 写到 `/shared/specs/spec.json`。
   - 后置 Node B 启动后，直接在提示词中声明：“读取 `/shared/specs/spec.json`”。这是最通用、直观的共享方式。
2. **利用 `{{files.上游节点标签}}` 自动路径注入**：
   - 如果在 LLM 节点的提示词中写了：
     `请读取上游规格：{{files.规格生成}}`
   - 运行时，平台会将该占位符替换为：
     `/shared/<upstreamPlanNodeId>`
   - 这对于严格遵守输入/输出拓扑、使用 Pack 迁移的工作流设计非常高效。

---

## 12. 密钥、工作流变量与共享文件机制

平台提供了三个维度的配置与注入管道：**安全密钥（Secrets）**、**动态变量（Variables）**和**静态共享参考文件（Shared Files）**。它们在运行时的注入位置和生命周期大不相同。

### 12.1 密钥（Secrets）安全注入机制

密钥（如 `CURSOR_API_KEY`、`GITLAB_TOKEN`、`FIGMA_TOKEN`）在 Web 设置页面配置，采用 **AES-256-GCM** 加密持久化。
* **`CURSOR_API_KEY` 注入**：
  - **自动注入**：平台在调度任何 LLM 节点启动时，会自动将其作为容器的环境变量（`CURSOR_API_KEY`）注入，供容器内的 `@cursor/sdk`（Cursor Agent）与官方云端服务完成授权。
  - **安全红线**：用户**完全不需要、也禁止**在任何 Prompt 里显式书写该 API KEY。
* **`GITLAB_TOKEN` 注入**：
  - **限定 Shell 节点使用**：`{{secrets.GITLAB_TOKEN}}` 占位符**仅在 Shell 节点命令字段**中有效。在执行底层 `sh -c` 前，由后台引擎进行文本解密与硬替换。
  - **双仓库拉取 POSIX sh 终极示例**：
    ```sh
    mkdir -p /shared/source && cd /shared/source && RAW_A="{{vars.gitRepoUrlA}}" && STRIPPED_A="${RAW_A#https://}" && echo "Cloning Project A..." && git clone "https://oauth2:{{secrets.GITLAB_TOKEN}}@${STRIPPED_A}" project-a && cd project-a && git checkout -b upgrade/angular22 && cd .. && RAW_B="{{vars.gitRepoUrlB}}" && if [ -n "$RAW_B" ]; then STRIPPED_B="${RAW_B#https://}" && echo "Cloning Project B..." && git clone "https://oauth2:{{secrets.GITLAB_TOKEN}}@${STRIPPED_B}" project-b && cd project-b && git checkout -b upgrade/angular22 && cd ..; else echo "No project B provided"; fi && echo "Initialization completed."
    ```
    *注：此 sh 脚本排除了 bash 依赖，100% 兼容 Runner 容器默认的 POSIX sh 解释器，并且通过 GitLab 推荐的 `oauth2:<token>@` 格式无密安全拉取。*
* **`FIGMA_TOKEN` 注入**：
  - **MCP 挂载驱动**：当 LLM 节点勾选了 Figma MCP 时，平台会自动在 Runner 容器内启动一个 `figma-developer-mcp` 服务，并将解密后的 Token 注入该 MCP。Agent 通过 MCP 协议与 Figma 进行像素和图纸交互。

### 12.2 工作流变量（Variables）的生命周期与定义

1. **定义**：在画布空白处点击，即可在 Inspector 中定义工作流变量（如 `gitRepoUrlA`、`userNotes`），支持设置默认值 and 必填标记。
2. **填写**：在启动运行前，平台会 Preflight 检查，如有必填项为空，会弹出表单强求用户填写。
3. **注入位置**：
   - **Shell 节点命令**：运行时替换其中的 `{{vars.变量名}}`。
   - **LLM 节点 Prompt**：在智能体开始生成对话前，系统会递归解析节点 Prompt 字段，将其中的 `{{vars.变量名}}` 完整替换为变量值明文。
   - **典型应用**：在 Prompt 末尾留下空间注入备注：
     ```markdown
     【📝 用户补充备注与定制要求】
     {{vars.userNotes}}
     ```

### 12.3 工作流静态共享文件（Shared Files）的拷贝投影

在工作流编辑器的 **Shared files** 面板中上传静态参考材料（例如：*企业前端开发规范.mdc*、*升级规范.zip*、*产品说明书.pdf*）。
* **投影时机**：在每次 Run 初始化（`INITIALIZING`）阶段，平台会立刻将这些共享文件物理拷贝到宿主机的 `storage/shared/<runId>/` 目录下。
* **访问方法**：在任意 Shell 节点或 LLM 节点的代码/脚本中，可以直接通过相对路径 `/shared/参考材料.pdf` 或 `/shared/rules/` 进行直接读取。

---

## 13. AI 自动回环（打回/Rework）判定与配置指南

多智能体系统的精髓在于**闭环自愈**。平台通过边上的 **CONDITION 边** 与 AI 输出的 **路由标记**，实现高内聚的闭环重跑。

```mermaid
flowchart TD
    dev[依赖升级与重构专家] -->|FLOW| audit[自动化构建与启动审计]
    audit -->|CONDITION 边: rework| dev
    audit -->|CONDITION 边: pass| push[交互式提交与分支推送]
```

### 13.1 CONDITION 边与回环边（Back Edge）

* **自动识别回环**：当在编辑器中拉出一条指向**上游节点**的线时，平台连线引擎会自动识别，并将其类型锁定为 **CONDITION 边** 且标记为 **回环边**。
* **设置 `maxLoops`（重试上限）**：
  - 为了防止 AI 逻辑出现死循环而耗尽您的 API 配额，回环边必须强制配置 `maxLoops`（默认 3，可调整为 12 或更高）。
  - **升舱机制 (Escalate)**：如果重跑次数达到了 `maxLoops` 上限，平台引擎将自动暂停运行（PAUSED），并将控制权**升级交付到人工节点**或提示人工干预，由人决定放行、强制中断（Abort）或彻底重置。

### 13.2 引擎分支路由协议（Branch Label）与配置方法

回环边的触发基于 **分支标签 (Branch Label)**。配置步骤如下：

1. **配置边上的分支属性**：
   - 点击回环边（例如从「审计」指向「开发」），在 Inspector 中将 **分支（Branch）** 属性写为一个特定标示，如 `"rework"`。
   - 点击通过边（例如从「审计」指向「推送」），在 Inspector 中将 **分支（Branch）** 属性写为另一个标示，如 `"pass"`。
2. **自动注入路由声明（System Prompt 增益）**：
   - 只要节点下游存在 CONDITION 出边，平台在生成该节点的 System Prompt时，**会自动在末尾注入一段路由说明书**，告诉 AI 哪些分支是合法的：
     ```text
     [ROUTING RULES]
     You must end your response with a markdown code block targeting one of the branches:
       - "rework" (reresolve the issue and rewrite files)
       - "pass" (audit successfully, pass to pushing)
     Format:
     ```branch
     {
       "branch": "your_selected_branch"
     }
     ```
     ```
3. **AI 的输出职责**：
   - 审核智能体（如 Quality Auditor Agent）在执行完毕后，只需正常输出诊断过程，并最终附带路由 JSON：
     - 若编译失败，输出：
       ```branch
       {
         "branch": "rework"
       }
       ```
     - 若编译启动探活全绿，输出：
       ```branch
       {
         "branch": "pass"
       }
       ```
   - 平台引擎解析到 ` ```branch ` 标记的代码块后，会自动沿着匹配 of CONDITION 边继续推进。

---

## 14. 节点单点重试与人工反馈（Feedback）注入机制

当 AI 执行了打回重跑，或者运行失败人工介入时，前一轮的报错、指令以及人工填写的意见，是如何传递给下一轮的？

### 14.1 自动打回反馈机制 (Feedback Message)

1. **消息路由包装**：
   当审核节点输出 `"branch": "rework"` 并附带诊断说明时，引擎会将**审核节点的输出文本全文**作为 `FLOW` 类型的 Message（带着 `feedback` 字段）写进数据库。
2. **提示词自动增益组装（Assemble Prompt）**：
   在开发专家节点被重新拉起并生成全新 `Attempt`（尝试）时，引擎的 `assemblePrompt` 模块会自动触发：
   - 读取最近的 Rework Feedback。
   - 在用户的 Prompt 最上方，**强行拼接注入上一轮的诊断说明**。
   - **物理呈现效果**：
     ```markdown
     === PREVIOUS ATTEMPT FEEDBACK (Loop 1 from 自动化构建与启动审计) ===
     [依赖升级与重构专家] 提交的代码在 project-a 中存在如下报错：
     src/app/main.ts:12:15 - error TS2307: Cannot find module '@angular/core' or its corresponding type declarations.

     === INSTRUCTION ===
     Address the feedback above and resubmit.

     === USER PROMPT ===
     你是 Angular Developer Agent。你的职责是升级依赖并进行克制重构：...
     ```
   - 开发 Agent 将能非常直观、明确地看到上轮问题，直接实现精准的“自愈 inner-loop”。

### 14.2 人工介入中的 Rework 反馈

如果工作流遇到了**人工审核节点**：
1. 审核者可以点击 UI 上的 **reject**。
2. 弹窗会强求选择 **“打回目标节点”**（例如选择打回到“重构专家”）并必须填写 **“打回反馈/修改意见”**。
3. 提交后，此人工填写的反馈同样会化作 `feedback`，在上游节点重新运行时，以完全相同的 `=== PREVIOUS ATTEMPT FEEDBACK ===` 标记前置注入到 Agent 的 Prompt 中，保证人机顺畅对话。

### 14.3 单节点手动重试 (Selective Retry & Superseded) 逻辑

如果某个 Run 整体失败变红（`FAILED`）或被取消（`CANCELLED`），你可以选择**局部针对性修复而无需从头重新执行**：

1. **双击失败节点**，直接进入 Node 详情。
2. **就地修改** 它的节点提示词、选用的模型等。
3. 点击 **保存并重试节点**：
   - **作废下游（Supersede）**：引擎会自动通过 BFS 拓扑遍历，将该节点的所有严格下游节点（如后置审计、推送等）的前序执行状态标记为 **`SUPERSEDED`（作废）**，清理环境，杜绝脏数据。
   - **复活 Run**：将整体运行状态从 `FAILED` 拨回 `RUNNING`。
   - **新建 Attempt**：触发一次新的 FLOW 消息，节点 Attempt 计数加 1 并立刻进入隔离容器开始重新运行。前序节点（如 Pull 代码节点）的产物目录 `/shared/` 完全保留，实现极速重试。

---

## 15. 执行历史占满磁盘时如何清理

每次 Run 会在 **`data/storage/`** 目录下产生 **工作区、共享产物、归档日志** 等物理文件。Run 越多、节点越多（尤其含 `git clone`、`npm install`、截图产物），磁盘占用越大。

### 15.1 storage 根目录在哪

业务数据与 Run 产物均保存在离线安装包解压目录下的 **`data/storage/`** 中（与 [2.1 快速开始](#21-快速开始与安装部署) 一致）。

下文路径均相对于 `<解压目录>/data/storage/`。

### 15.2 按 Run 可安全删除的目录（释放空间主力）

在 **确认该 Run 已结束**（COMPLETED / FAILED / CANCELLED）且不再需要其产物后，可删除以下以 `<runId>` 为名的目录（`<runId>` 为运行详情页 URL 或执行历史列表中的 Run ID）：

| 路径（相对 `data/storage/`） | 内容 | 可否删 | 说明 |
|:---|:---|:---|:---|
| `shared/<runId>/` | 跨节点共享目录：clone 的源码、`output/` 产物、截图等 | ✅ 可删 | 最主要的体积来源，含拉下来的 Git 仓库和 `node_modules` |
| `workspaces/<runId>/` | 各 LLM/Shell 节点的独立 workspace、trace、result.json | ✅ 可删 | 包含各个智能体节点运行时的本地工作空间 |
| `logs/<runId>/` | 各节点 execution 的归档日志 `.jsonl` | ✅ 可删 | 存放所有终端输出和 LLM 交互日志文件 |

**PowerShell 示例**（删除单个 Run）：

```powershell
$runId = "cmxxxxxxxxxxxx"
$root = "C:\path\to\agent-orchestra\data\storage"
Remove-Item -Recurse -Force "$root\shared\$runId", "$root\workspaces\$runId", "$root\logs\$runId" -ErrorAction SilentlyContinue
```

**macOS / Linux 示例**：

```bash
RUN_ID=cmxxxxxxxxxxxx
ROOT=/path/to/agent-orchestra/data/storage
rm -rf "$ROOT/shared/$RUN_ID" "$ROOT/workspaces/$RUN_ID" "$ROOT/logs/$RUN_ID"
```

> 删除上述目录 **不会** 自动清除 Web UI「执行历史」里的数据库记录；历史列表仍可见，但对应产物与日志文件已不可恢复。若需连同历史记录一并删除，见下文 15.5。

### 15.3 可选：清理 Docker 临时镜像

部分 Run 可能产生 `agent-orchestra/base:run-<runId>` 等临时镜像。查看并清理：

```bash
docker images "agent-orchestra/base"
docker image rm agent-orchestra/base:run-<runId>   # 按 Run 删除
docker image prune -f                              # 清理 dangling 镜像（谨慎）
```

### 15.4 不要误删的目录

| 路径（相对 `data/storage/`） | 说明 |
|:---|:---|
| `files/` | **角色** 上传的技能 / 规则 / 文档附件（删掉会导致角色失效） |
| `workflows/<workflowId>/` | **工作流共享文件**（如产品手册 zip） |
| `certs/` | 企业 CA 证书 bundle |
| PostgreSQL 数据 | 在 Docker volume 中，**不在** `data/storage/` 里；删 storage 不会清库 |

### 15.5 连同执行历史记录一起删除

当前 UI **没有**「单独删除某条 Run 记录」的按钮。若希望 **数据库记录 + 磁盘文件** 一并清理：

1. **删除整个工作流**（工作流卡片 → **删除**）会级联删除该工作流下的全部 Run 记录。
2. 磁盘上 `shared/`、`workspaces/`、`logs/` 下对应 `<runId>` 文件夹 **不会自动删除**。删除工作流后，建议按 [15.2](#152-按-run-可安全删除的目录释放空间主力) 手动扫一遍旧 Run 目录，或批量删除已无对应 DB 记录 of orphan 文件夹。

---

## 附录 A. 术语表

| 术语 | 说明 |
|------|------|
| **RunPlan** | Run 启动时从工作流模板克隆的执行计划；运行中改 plan 不污染模板 |
| **Attempt** | 某 plan 节点的一次执行尝试；有独立编号与状态 |
| **Intent** | 节点输出中的路由指令（如 loopback）；用户通常通过 UI 审批或边配置间接使用 |
| **Preflight** | 启动 Run 前的检查（Token、必填变量等） |
| **Back edge / 回环边** | 指向上游的 CONDITION 边，用于打回重做 |
| **Artifact** | 节点执行产出的文件或目录路径 |
| **Pack** | `.aopack.zip` 格式的角色/工作流迁移包 |
| **origin** | 数据来源标记：OFFICIAL / USER / DEV |
| **SUPERSEDED** | 下游 execution 因上游重跑而作废的状态 |

---

## 附录 B. 常见问题

**Q：模型列表为空？**  
A：请先在设置页保存有效的 **Cursor API Token**，保存后刷新页面。列表无占位数据，未配置 Token 前为空是正常现象。

**Q：点击「运行」无反应或提示 preflight 失败？**  
A：检查 Cursor Token 是否已配置；检查工作流 **Variables** 中标记必填的变量是否已填写默认值。

**Q：Run 创建后一直 PENDING？**  
A：确认已执行 `start-docker.ps1` 且 Docker Desktop 在运行；在解压目录执行 `docker compose --profile app ps`，确认 `ao-worker` 等容器为 `running`；查看设置页系统健康是否全绿。

**Q：如何分享工作流给同事？**  
A：在工作流或角色页使用 **导出 Pack**，对方 **导入** 即可（见第 7 章）

**Q：Shell 节点 git clone 报 Username / 鉴权失败？**  
A：在设置页配置 **GitLab Token**，Shell 命令使用 `https://oauth2:{{secrets.GITLAB_TOKEN}}@...` 格式，见 [第 11 章](#11-运行时的容器文件结构与节点共享通道)。

**Q：如何在 Prompt 里使用用户填写的备注？**  
A：在工作流 Variables 定义键（如 `userNotes`），LLM Prompt 中写 `{{vars.userNotes}}`，见 [第 12 章](#12-密钥工作流变量与共享文件机制)。

**Q：执行历史太多，硬盘满了怎么办？**  
A：删除 `<解压目录>/data/storage/shared/<runId>/`、`workspaces/<runId>/`、`logs/<runId>/` 释放空间，见 [第 13 章](#15-执行历史占满磁盘时如何清理)。不要删 `files/` 和 `workflows/`。
