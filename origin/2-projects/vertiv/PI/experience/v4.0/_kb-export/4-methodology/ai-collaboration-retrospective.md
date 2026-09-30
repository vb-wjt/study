# AI 协作回望：InstallAnywhere 安装器专项

> **创建时间**：2026-05-27  
> **用途**：记录如何使用 AI 协作处理 InstallAnywhere、Maven、GitLab CI、Windows 服务等安装器专项工作，并持续复盘和优化协作方式。  
> **维护方式**：后续当新的协作模式、有效提问方式、失败教训或可复用模板出现时，继续追加或修订本文。

---

## 中文版

### 一、背景

这份回望来自一次围绕 PI 安装器的连续协作。工作起点是移除 IE Engine 后的安装失败排查，随后逐步扩展到 JRE 版本修正、服务残留分析、Zero Engine 打包与 Windows 服务接入、GitLab CI 发布链路、Nmap 移除等任务。

整个过程说明：AI 在安装器专项工作中更适合作为“证据驱动的工程助手”，而不是直接替代开发者拍板。开发者负责提供真实上下文、业务边界和最终取舍；AI 助手负责读日志、追代码、枚举影响面、提出方案、执行机械且容易遗漏的改动，并把阶段性结论固化成文档。

### 二、开发者是如何使用 AI 的

协作方式大致从“排查真实问题”开始，而不是直接让 AI 改代码。先提供安装日志、构建日志、实际工程路径和观察到的现象，让 AI 从证据里判断问题类型，再决定是否修改。

每次涉及具体工程时，都会明确路径，例如 `<repo>\installer` 或 `<repo>\engine-packaging`。这减少了误改其他副本的风险，也让分析可以直接落到真实文件上。

在 JRE11/JRE21 问题中，先让 AI 对照 `pom.xml`、`TAFCore.iap_xml`、GitLab `build.txt` 和 `vm-packs` 目录，确认是 InstallAnywhere build configuration 的 bundled VM 配置导致回退，而不是 Maven 依赖本身的问题。

在 Zero Engine 接入中，没有一开始就要求实现，而是先分析 PI3.0 如何把 `mtp-core.war` 注册成 Windows 服务。确认 JSL wrapper 机制后，再决定复用同样模式为 Zero Engine 注册 `ZESvc`。

在方案存在多种选择时，会先要求 AI 助手进入计划和对比状态，例如 Zero Engine 的集成范围、Windows 部署布局、JRE 策略、SQLite 数据库、ActiveMQ 处理方式、GitLab CI job 设计等。开发者逐项拍板后，AI 助手再执行。

在每次执行后，会要求 AI 助手做本地可行验证，例如 XML parse、全文搜索残留、linter 检查、GitLab 日志关键行定位等。完整 GitLab 构建和安装验证仍由开发者完成。

### 三、有效的协作习惯

最有效的方式是先给真实输入，再问原因。比如安装日志、构建日志、服务状态、GitLab artifact 页面信息，比抽象描述“打包失败了”更容易得到准确判断。

第二个有效习惯是明确当前请求是“只分析”还是“可以改”。这可以避免 AI 在还没确认方案时过早动工程。

第三个有效习惯是让 AI 助手先枚举触点。InstallAnywhere 工程往往不是单点修改，一个功能可能同时涉及 `.gitlab-ci.yml`、`pom.xml`、`TAFCore.iap_xml`、locale 文件、脚本、文档和历史快照。先列触点，再改动，能显著降低漏改风险。

第四个有效习惯是把阶段性结论持久化。`docs/context-snapshot.md` 用于恢复项目上下文，`docs/migration-tasks/` 用于跟踪技术任务，本文则用于复盘协作方式本身。

第五个有效习惯是允许 AI 助手修正判断。比如 GitLab 403 问题中，先后讨论了 Windows classifier 缺失、group registry、project registry、groupId/projectId 误解、CI_JOB_TOKEN 权限等。随着新信息补充，结论也需要及时修正。

### 四、AI 助手适合承担的部分

AI 助手很适合读大文件和追链路。比如在 `TAFCore.iap_xml` 里定位某个安装动作、找出 `objectID` 与 `refID` 的关系、判断动作是否挂到 install children。

AI 助手也适合做机械但容易遗漏的同步修改。例如移除 Nmap 时，需要同步处理 CI 预置二进制、Maven 依赖、IA 安装/卸载动作、locale 残留和文档描述。

AI 助手适合解释构建日志和错误边界。比如区分“没有发布 Windows zip”与“Windows zip 已存在但 GitLab registry 仍 403”，并指出日志中具体哪一行能证明结论。

AI 助手适合生成和维护过程文档。尤其是在长期安装器迁移工作中，文档可以减少下一次对话的恢复成本，也可以帮助团队共享上下文。

### 五、开发者需要继续把控的部分

业务边界仍然需要开发者来定。例如 Zero Engine 接入做到 minimal service、production basic 还是 full lifecycle，Nmap 功能是否完全由 Zero Engine 接管，SQLite seed DB 是否随卸载删除等。

涉及 GitLab 权限、package registry 范围、项目间 token allowlist 的问题，AI 助手可以给排查方向，但最终需要开发者根据真实 GitLab 权限模型确认。

完整安装验证、跨机器环境验证和用户体验验证仍然需要开发者执行。AI 助手可以做静态验证和局部命令验证，但不能替代真实安装包在目标环境中的验证。

### 六、可复用提问模板

排查日志时：

```text
这是 GitLab/安装日志路径：<path>。请先分析失败原因，不要改工程。需要指出从日志哪些行能看出来。
```

限定工程时：

```text
工程路径是 <path>。只允许改这个工程，先搜索触点并说明影响面，再动手。
```

方案选择时：

```text
先不要改。请列出可选方案、区别、优劣和推荐方案，等待开发者确认后再执行。
```

执行改动时：

```text
按刚才确认的方案执行。改完后做本地可行验证，并说明哪些验证已完成，哪些还需要开发者在 GitLab 或安装环境中验证。
```

复盘沉淀时：

```text
把这次结论更新到项目文档中，方便后续对话恢复上下文。
```

### 七、踩坑记录：ZE 服务链 20+ 次构建的完整故事

> **时间跨度**：2026-05-26 ~ 2026-06-02  
> **涉及提交**：`c79cfb3` ~ `bb7ad1b`（20 次 TAFCore.iap_xml 改动，约 22 次 GitLab 构建 + 装机）  
> **严重后果**：最后一次 AI 生成的代码导致 `rmdir /s /q "\"` 递归删除了开发机 C 盘内容

#### 8.1 起因：让 AI 在 IA XML 中新增节点

Zero Engine 需要在 PI 安装时注册为 Windows 服务（`ZESvc`）。初始方案是在 `TAFCore.iap_xml` 中新增 `Exec`、`NTServiceController`、`MakeRegEntry` 等 IA 节点（`aa000002`–`aa000005`、`aa000006b13a` 等），挂到安装链上。

AI 负责生成这些 XML 节点、计算 `objectID`、处理 `refID` 引用和执行顺序。每次改完后做 XML parse 验证，本地静态检查通过。

#### 8.2 Build 4 ~ 14：构建成功但安装不生效

GitLab 构建总是成功的（`zeroengine(BUILD)` 出现在 build log），ZE 文件也被打包进安装介质。但在 Windows 装机后：

- `zeroengine\` 目录有时存在有时不存在
- `ZESvc.exe -install` **从未执行**
- 安装日志里找不到任何 ZE 服务注册记录

在这 10+ 次构建循环中，AI 每次都在调整 objectID 的挂载位置（`installChildren` vs `visualChildren`、`ruleExpression=CIAV572`、ref vs inline、不同父节点等），但结果始终不变——服务链 **静默不执行**。

#### 8.3 转折点：发现 IA Builder 剥离文本新增的 objectID

关键突破是开发者要求 AI **对比 IA Builder 实际使用的 `TAFCoreBuild.iap_xml` 和我们的源文件**。Diff 结果揭示了根因：

> **IA Builder 在 "Saving project" 阶段会剥离所有通过文本编辑新增的 objectID——只有 IA Designer GUI 创建的对象才会被保留。**

这解释了为什么 10+ 次修改全部失效：无论 objectID 放在哪里、如何挂引用，构建产物中根本没有这些节点。而 IA Builder **不报告任何警告**，只是静默丢弃。

#### 8.4 方案 B：复用已有 IA 注册的 ExecuteScript（build-23）

一旦确认 "不能新增 objectID"，策略立即转变：**修改已有 IA Designer 注册对象的属性**。

选择了 `d82cc271b581`（ExecuteScript，原 comment 为 `copy nginx`），因为：
- 它由 IA Designer 创建，objectID 不会被剥离
- 它的 `script` 属性**可以被文本修改**且构建后保留
- 执行时机正确：zeroengine 文件已落盘、TAFdb 尚未安装

AI 在该脚本末尾追加了 ZE 服务设置命令，包括 JRE 解压、copy TAFsvc.exe→ZESvc.exe、服务注册和启动。JRE 解压使用 PowerShell 的 `Expand-Archive` 和 `$nested` 临时变量来铺平子目录。

Build-23 装机后，ZE 服务安装链**首次出现在日志中**。但发现 4 个新问题。

#### 8.5 Build-24 的修复引入了灾难性 Bug

Build-23 的问题之一是：PowerShell 变量 `$nested` 被 IA 的 `$xxx$` 变量替换引擎误解析，导致 JRE 解压失败。

AI 的修复方案是改用 CMD 批处理变量：

```batch
set "JREDIR=$USER_INSTALL_DIR$\zeroengine\jre"
set "ZIPNAME=zulu21.44.17-ca-jre21.0.8-win_x64"
if not exist "%JREDIR%\bin\java.exe" (
    ...
    rmdir /s /q "%JREDIR%\%ZIPNAME%"
)
```

思路正确（避免 PowerShell 变量被 IA 误替换），但踩中了 **CMD 延迟展开经典陷阱**：

1. `set` 和 `%JREDIR%` 都在 `if "%OS%"=="Windows_NT" ( ... )` 复合块内
2. CMD 在**解析整个 `( ... )` 块时**一次性展开所有 `%var%`，此时 `set` **尚未执行**
3. `%JREDIR%` 和 `%ZIPNAME%` 展开为**空字符串**
4. `rmdir /s /q "%JREDIR%\%ZIPNAME%"` → `rmdir /s /q "\"` → **递归删除当前盘符根目录**

由于 IA 安装器以**管理员权限**运行、当前目录通常在 **C: 盘**，这条命令等效于 `rmdir /s /q "C:\"`。

#### 8.6 后果与修复

该代码在开发者的 Windows 装机验证中执行，**实际删除了 C 盘部分内容**。

修复方案（commit `bb7ad1b`）采用"双保险"策略：
1. **去掉所有 CMD 环境变量**（`set` + `%var%`），改用 IA 变量 `$USER_INSTALL_DIR$` 直接拼路径
2. **使用 IA 路径分隔符变量 `$\$`**（而非裸 `\`），与 IA Designer 创建的脚本模式一致
3. **用 CMD xcopy/rmdir 做铺平**（而非 PowerShell `$nested`），避免 IA 的 `$var$` 替换冲突
4. **新增持久化安全审计脚本** `scripts/verify-destructive-commands.ps1`，检测所有破坏性命令的路径安全性

#### 8.7 教训总结

| 编号 | 教训 | 根因 | 防范措施 |
|------|------|------|----------|
| L1 | **IA Builder 静默剥离文本新增的节点** | IA 只认 Designer 注册的 objectID | 只修改已有节点的属性，不新增 objectID；每次构建后对比 `TAFCoreBuild.iap_xml` vs 源文件 |
| L2 | **CMD `%var%` 在 `( )` 块内为空** | 延迟展开——`%var%` 在块解析时展开，而非逐行执行时 | 在 IA ExecuteScript 中**禁止使用 CMD 环境变量**，全部用 IA 变量替代 |
| L3 | **IA 的 `$xxx$` 替换会误伤 PowerShell 变量** | IA 对脚本做全文 `$...$` 匹配，不区分 shell 类型 | PowerShell 命令只接收 IA 预替换的字面路径，不使用 PS 临时变量 |
| L4 | **AI 生成的破坏性命令缺乏安全验证** | AI 不了解 CMD/IA 的交互边界 | 每次改动后运行 `verify-destructive-commands.ps1`；对 `rmdir`/`rm -rf` 路径做空值/根路径静态检测 |
| L5 | **静态 XML 验证不足以发现运行时问题** | XML parse 通过 ≠ 安装时行为正确 | 必须在真实环境装机验证；IA 特有行为（objectID 剥离、变量替换规则）需要构建后对比 |
| L6 | **路径拼接应遵循 IA 既定模式** | IA 用 `$\$` / `$/$` 作为路径分隔符 | 在 ExecuteScript/Exec 中统一使用 `$\$` 或 `$/$`，不使用裸 `\` 或 `/` |

#### 8.8 时间线速查

| 阶段 | Build | 核心事件 |
|------|-------|----------|
| 新增节点 | 4–14 | 10+ 次构建，ZE 服务链全部静默不执行 |
| 发现根因 | — | 对比 `TAFCoreBuild.iap_xml` → IA 剥离了所有新增 objectID |
| 复用已有节点 | 15–22 | 各种挂载方式（ref / inline / installChildren / visualChildren），仍被剥离 |
| 方案 B | 23 | 修改 `d82cc271b581` 的 script 属性→首次执行成功，发现 4 个次要问题 |
| CMD 陷阱 | 24 | 修复 `$nested` 问题时引入 `%var%` 延迟展开 bug → **删除 C 盘** |
| 最终修复 | 25 | IA `$\$` 路径分隔符 + 安全审计脚本 |

### 八、后续如何维护这份回望

当出现新的有效协作方式时，可以追加到“有效的协作习惯”。

当出现新的失败教训时，可以追加到“开发者需要继续把控的部分”或新增“踩坑记录”。

当形成稳定的提问方式时，可以追加到“可复用提问模板”。

当这份文档用于团队分享时，可以根据受众补充更多背景，例如 InstallAnywhere 的基本构建链路、Maven artifact classifier 的概念、GitLab CI job/stage/needs 的关系。

### 九、MongoDB 至 PostgreSQL 迁移专项攻坚（2026-06-09 ~ 2026-06-13）

在完成 Zero Engine 接入和 SI 移除后，项目迎来了最核心的重构任务：**将底层数据库从 MongoDB 100% 迁移至 PostgreSQL 18.4**。在连续 10 次的 GitLab 构建和装机验证（Build 30 ~ Build 39）中，AI 助手与开发者紧密协作，攻克了从脚本语法、Java 运行时、解压性能、服务注册、到 InstallAnywhere 编译器内存崩溃等一系列极具挑战性的难题。

以下是本次攻坚中遇到的 10 个典型问题、解决思路与解决方法：

#### 9.1 问题 1：CMD 嵌套双引号导致 `initdb` 语法错误
*   **现象**：在安装过程中，PostgreSQL 的 `initdb` 初始化静默失败，导致后续数据库无法启动。
*   **根因**：`TAFCore.iap_xml` 中执行 `initdb` 的命令类似于 `cmd /c "cd /d "path" && "path\initdb.exe" ..."`。CMD.exe 无法正确解析这种多层嵌套且未转义的双引号，导致路径被截断或报语法错误。
*   **解决方法**：修正 `TAFCore.iap_xml` 中的引号嵌套，将外层 `cmd /c` 的引号与内层路径的引号进行合理解耦与转义，确保 CMD 能够正确识别整条命令链。

#### 9.2 问题 2：`DatabaseConnector.java` 仍使用 MongoDB 专用的连接校验
*   **现象**：安装过程中在“数据库连接校验”面板卡住并触发回滚，提示无法连接数据库。
*   **根因**：Java Custom Code 中的 `DatabaseConnector.java` 仍硬编码使用 MongoDB 的 Java Driver 尝试建立 Mongo 连接，在 PostgreSQL 架构下必然失败。
*   **解决方法**：重构 `DatabaseConnector.java`，将其改造为**通用的 TCP Socket 端口连接校验**。该校验不依赖任何特定数据库的驱动 jar 包，仅通过底层 TCP 握手验证指定 IP 和 Port 的可用性，实现轻量、健壮且 100% 兼容 PostgreSQL。

#### 9.3 问题 3：安装失败回滚后，`ZESvc` 服务与 `zeroengine` 目录残留
*   **现象**：当安装过程因某种原因（如连接校验失败）触发 InstallAnywhere 自动回滚时，其他目录都被干净清除，但 `ZESvc` 服务依然在运行，且 `zeroengine` 文件夹被锁定无法删除。
*   **根因**：IA 的自动回滚机制只负责清除其自身释放的文件，而 `ZESvc` 是通过自定义脚本在安装期动态注册 of Windows 服务。IA 无法感知该服务，导致回滚时服务未停止、文件被占用锁定。
*   **解决方法**：在 Java Custom Code `PanelDatabaseConnectivityConfirmationAction.java` 的 `uninstall()` 方法（该方法在 IA 卸载和回滚时都会被触发）中，新增了**服务停止、删除与目录强制清理逻辑**。确保在回滚或手动卸载的第一时间，优雅停止并注销 `ZESvc`，解除文件锁定并彻底清除残留。

#### 9.4 问题 4：PostgreSQL 静态打包导致 `share` 和 `lib` 目录缺失
*   **现象**：`initdb` 报错提示缺失 `share/postgresql` 目录，导致初始化彻底失败。
*   **根因**：InstallAnywhere 的 `InstallDirectory` 静态打包机制存在“变量陷阱”和“空目录过滤”。当文件夹命名为 `share` 或 `binaries` 时，IA 编译器会将其误识别为内置路径变量（如 `$share$`）并进行错误替换，或者在打包时静默过滤掉其认为不重要的非可执行文件。
*   **解决方法**：
    1.  **动态解压方案（方案 B）**：在 `pom.xml` 中将完整的 PostgreSQL 官方 zip 包原封不动复制到 `binaries/` 下，由 IA 整体打包进安装介质。在安装期，通过 ExecuteScript 动作动态解压该 zip 包。
    2.  **混合路径模式（Hybrid Path Pattern）**：在 `TAFCore.iap_xml` 的解压和拷贝命令行中，引入 `$$\$` 隔离字面量路径（例如 `"$USER_INSTALL_DIR$$\\$database$\\$bin$\\$psql.exe"`），彻底规避 IA 路径变量替换引擎的误伤。

#### 9.5 问题 5：GnuWin32 `unzip.exe` 在现代 Windows 环境下静默崩溃
*   **现象**：在 Windows Server 2019+ 上，解压 PostgreSQL 压缩包极其缓慢，且解压出来的目录只有 `bin` 文件夹，其他关键文件夹（如 `share`、`lib`）全部缺失。
*   **根因**：项目原先集成的 GnuWin32 `unzip.exe` (v5.51-1) 依赖过时的 `msvcp60.dll` (VC++ 6.0 运行时)。在现代 Windows Server 系统上，由于缺失该 DLL，`unzip.exe` 在解压大文件时会发生**静默内存崩溃**，不报任何错误但解压提前中断。
*   **解决方法**：将解压工具彻底升级为 Windows 10 (Build 17063+) 和 Windows Server 2019+ 原生内置的 **`tar.exe`**。`tar.exe` 具备零外部 DLL 依赖、极高的解压性能，且原生支持 zip 格式的选择性解压（如排除 `pgAdmin`、`doc` 等无用目录），解压极为稳定。

#### 9.6 问题 6：缺少 `tar.exe` 导致的中途安装失败（Fail-Fast 机制）
*   **现象**：如果用户的 Windows 环境过于老旧，缺失 `tar.exe`，安装会在中途解压时报错中断，体验极差。
*   **根因**：我们需要在安装最开始阶段进行前置检查，避免中途失败。
*   **解决方法**：在 Java Custom Code `GetApplicationNames.java` 的 `install` 阶段，新增了对系统内置 `tar.exe` 的**静默前置兼容性检查**（兼容 GUI 模式与 Headless 命令行模式）。若检测到系统缺失 `tar.exe`，将弹出友好的系统兼容性检查失败提示框，并抛出 `FatalInstallException` 干净地终止安装，实现 Fail-Fast。

#### 9.7 问题 7：InstallAnywhere 2025 编译器堆损坏崩溃（错误码 -1073740940 / 0xC0000374）
*   **现象**：在 GitLab 构建结束、准备生成最终安装包时，`buildinstaller` 进程突然发生 **Heap Corruption (堆损坏)** 崩溃，导致 CI 任务失败。
*   **根因**：这是一个 InstallAnywhere 2025 编译器的底层 C++ 缺陷。当我们在 XML 中手动添加/克隆一个 inline 的 `keyFile` 节点（它在 IA 的对象树中属于孤立的 orphaned 节点），且该节点指向一个*已存在*的物理文件（如 `pg_hba.conf`），并将其 `fileSize` 属性设为 `-1` 时，IA 编译器在退出前会试图测量该文件大小并写回该节点。由于该节点没有正确的父上下文，写操作触发了 C++ 内存越界，导致堆损坏崩溃。
*   **解决方法**：
    1.  将组件的 `keyFile` 属性修改为引用组件内已有的、处于正常对象树中的物理文件节点（Windows 引用 `createdb.sql`，Linux 引用 `LICENSE-Community.txt`），彻底清除孤立的 `keyFile` 残留。
    2.  对于 `pg_hba.conf`，转而**劫持（Hijack）**已有的、处于正常对象树中的物理节点（Windows 节点 `3bcfb201b174`，Linux 节点 `3bd05399b17d`，原 `THIRD-PARTY-NOTICES.gotools`），将其重命名为 `pg_hba.conf`。由于这些节点拥有完美的父上下文，其 `fileSize` 设为 `-1` 能够被编译器安全、动态地处理。

#### 9.8 问题 8：`postgresql.conf` 日志路径拼写错误与 `TAFsvc` 启动失败
*   **现象**：数据库虽然启动，但数据目录下生成了字面量为 `$log` 的异常文件夹；同时 `TAFsvc` 无法启动。
*   **根因**：
    1.  `postgresql.conf` 中 `log_directory` 被错误配置为 `'$USER_MAGIC_FOLDER_2$/$log'`。由于 `$log` 不是合法的 IA 变量，被直接写入了配置文件。
    2.  `TAFsvc` 无法启动是因为 `pg_hba.conf` 部署失败，导致本地建库脚本无法通过 `psql` 连接数据库，建库链中断。
*   **解决方法**：
    1.  将 `log_directory` 修正为 `'$USER_MAGIC_FOLDER_2$/log'`，使 PostgreSQL 日志与应用日志完美合并。
    2.  在建库脚本中升级为**三保险路径拷贝逻辑**：无论 `pg_hba.conf` 被释放到根目录、`database` 目录还是 `database/bin` 目录下，脚本都能 100% 稳定地将其拷贝到 `$USER_MAGIC_FOLDER_2$\db\pg_hba.conf`，并执行 `pg_ctl reload`，彻底打通连接链。

#### 9.9 问题 9：`ZESvc` 服务在安装后无法开机自启动
*   **现象**：虽然 `ZESvc.ini` 中配置了 `starttype=auto`，但安装后服务在 SCM 中的启动类型仍为“手动”。
*   **根因**：安装脚本中为了修复 `ImagePath` 路径缺失引号的问题，执行了 `reg add ... /v ImagePath ...`。该注册表直接写入操作会无意中重置 Windows SCM 中该服务的 `Start` 属性为默认值（手动）。
*   **解决方法**：在注册表修复命令后，追加执行 **`sc config ZESvc start= auto`**（注意 `start=` 后必须有空格），作为“双保险”，强行将服务启动类型修正为自动。

#### 9.10 问题 10：Zero Engine 属性动态写入导致 locale 冲突与大小不匹配
*   **现象**：安装后 `application-prod.properties` 中的 Zero Engine 默认配置未生效，或在不同语言环境下行为不一致。
*   **根因**：原先使用 `ASCIIFileManipulator` 动态拼接配置，但该动作的 `additionalText` 属性在 `custom_zh_CN` 和 `custom_en` 等本地化文件中存在多余的重写，导致在特定语言下动态拼接被覆盖或失效。此外，`application.properties` 的物理节点文件大小被硬编码，导致大小校验不匹配。
*   **解决方法**：
    1.  将 Zero Engine 的默认配置**静态注入**到 `application.properties` 模板文件中，消除动态拼接的维护成本。
    2.  将 `ASCIIFileManipulator` 动作的 `additionalText` 属性在主 XML 及所有本地化属性文件（`custom_zh_CN`、`custom_en`）中**全部清空**，使其安全地成为空操作（No-op）。
    3.  将 `application-$PROFILE$.properties` 节点的 `fileSize` 设为 `-1`，支持动态大小测量。

### 十、 知识沉淀与归档专项（2026-06-13 ~ 2026-06-15）

在顺利打通 PostgreSQL 迁移、Zero Engine 替换并完成多轮 GitLab CI 构建与装机验证后，项目进入了**知识沉淀与归档专项阶段**。为了将攻坚期间积累的 niche 系统（InstallAnywhere、Windows 服务、JSL 封装、黑盒编译器行为）改造经验转化为团队的持久资产，并为后续开发、调试与 QA 奠定坚实基础，AI 助手与开发者再次深度协同，在 `docs/migration-remediation-archive/` 目录下建立了完整的四维归档体系。

以下是本次归档专项中沉淀的核心结论、纠偏事实与 AI 协同新模式：

#### 10.1 核心纠偏：Zero Engine 的独立 SQLite 3 数据隔离
*   **背景**：在前期分析中，曾误认为 Zero Engine 共享主应用的 PostgreSQL 数据库。
*   **事实纠偏**：经过对 Zero Engine 架构与配置的深度复盘，确认 **Zero Engine 使用的是同安装目录下的独立 SQLite 3 数据库 (`zeroengine/database/zero_engine.db`)**。
*   **架构意义**：这种设计实现了物理级的数据与性能隔离。Zero Engine 作为一个轻量级伴随引擎，通过本地 SQLite 存储自身状态与配置，与 MTP Core 之间仅通过端口 `8088` 的 HTTP API 进行轻量级通信。这一纠偏被无缝同步至全量归档文档中，确保了技术设计的 100% 准确性。

#### 10.2 深度梳理：IE Engine 5 大服务与 ZE 服务链内联提升 (Hoist)
*   **IE Engine 5 大 Windows 服务精确化**：在归档中，我们通过追溯历史打包配置 `TAFCore.iap_xml.2022.196` 和 Java 恢复代码 `RestoreService.java`，精确还原了改造前 IE Engine 在 Windows 上的 5 个服务名称：`iesnmptrapd`、`ieelfsrvmanager`、`ieexportersrv`、`ieeventsrv`、`iemssenginesrv`，以及 Linux 上的 `mss-engine`。这为 QA 团队提供了最精准的“As-Is”基线。
*   **ZE 服务链内联提升 (Hoist) 机制**：复盘了 Build-5 至 Build-11 期间 ZE 服务未注册的“断层”根因——IA 编译器会将挂载在非活跃组件（如 Linux）下的动作组静默忽略，即使在 Windows 序列中引用了该组。最终，我们采用 Python 脚本将 Action Group `ecdb7d1e9e76` 提升（Hoist）至 Windows 序列中，成功打通了 ZE 服务链。

#### 10.3 归档成果：高标准四维文档体系
我们在 `docs/migration-remediation-archive/` 下创建并重构了以下 4 个文档，作为团队交付与个人成长的双重资产：
1.  **`01-team-delivery-and-qa-guide.md`（团队交付与 QA 指南）**：包含 As-Is 与 To-Be 的拓扑对比、服务依赖、启动/停止顺序、安装界面与步骤变化（如端口 27017->5432, 4440->8088）以及 `tar.exe` 前置检查等细节，帮助 QA 同事快速上手。
2.  **`02-hardcore-technical-postmortems.md`（硬核技术复盘）**：对 IA 堆损坏崩溃（0xC0000374）、C 盘误删（CMD 延迟展开）、JSL 服务化封装（`ZESvc`）、卸载链修复、Action Group 提升（Hoist）等底层黑盒问题进行了极其详尽的源码级与机制级复盘。
3.  **`03-ai-assisted-reengineering-methodology.md`（AI 协同方法论）**：提炼了在 niche、闭源、遗留系统下，如何通过“控制变量法”、“多维 Diff 对照”和“静态安全沙箱”与 AI 高效协同的通用方法论，并以 ZE 服务链断层排查和 GnuWin32 `unzip.exe` 崩溃为例进行了实战拆解。
4.  **`04-career-portfolio-and-mock-interviews.md`（职业晋升与模拟面试）**：将本次攻坚的架构决策、疑难排查转化为 Staff/Principal 级别的 STAR 个人业绩描述，并设计了 5 道极具深度的架构师模拟面试题（涵盖轻量级伴随引擎的数据隔离设计、黑盒编译器故障排查等），实现技术攻坚向个人职业价值的完美转化。

#### 10.4 AI 协同新感悟：敏捷重构与证据驱动
*   **“事实纠偏”的敏捷响应**：在归档过程中，当开发者指出“SQLite 数据库”和“IE 5大服务名”等关键事实后，AI 助手展现了极强的上下文重构能力，在不破坏已有深度的情况下，一次性对 4 个大型文档进行了无缝重写与交叉验证，确保了文档间的一致性。
*   **“安全沙箱”的常态化**：在生成任何包含破坏性命令的文档或脚本时，坚持运行 `verify-destructive-commands.ps1` 进行静态安全审计，使“防范 C 盘误删”的教训真正融入了日常开发流程，形成了闭环的安全机制。

---

## English Version

### 1. Background

This retrospective comes from a continuous collaboration around the PI installer. The work started with diagnosing installation failures after removing the IE Engine, then expanded into Java runtime packaging, leftover Windows services, Zero Engine packaging, Windows service integration, GitLab CI publishing, and removing Nmap from the installer.

The overall lesson is that AI works best here as an evidence-driven engineering assistant, not as a replacement for developer decision making. The developer provides real context, business boundaries, and final decisions. The AI assistant reads logs, follows code paths, enumerates impact areas, proposes options, performs careful repetitive edits, and turns temporary findings into durable documentation.

### 2. How the Developer Used AI

The collaboration usually started with real evidence instead of direct code changes. Installation logs, build logs, actual project paths, and observed system behavior were provided first. AI was then asked to classify the issue and explain the root cause before making changes.

Whenever a concrete codebase was involved, the exact path was specified, such as `<repo>\installer` or `<repo>\engine-packaging`. This reduced the risk of modifying the wrong copy and allowed the investigation to be grounded in real files.

For the JRE 11 versus JRE 21 issue, AI compared `pom.xml`, `TAFCore.iap_xml`, GitLab `build.txt`, and the `vm-packs` directory. The conclusion was that InstallAnywhere build configurations were still pointing at the wrong bundled VM, causing fallback behavior, rather than Maven dependency declaration being the only issue.

For Zero Engine integration, implementation did not start immediately. AI first analyzed how PI 3.0 registers `mtp-core.war` as a Windows service. After confirming the JSL wrapper pattern, the same pattern was reused for `ZESvc`.

When multiple approaches existed, the AI assistant was first asked to compare options. This happened for the Zero Engine integration scope, Windows deployment layout, JRE strategy, SQLite database handling, ActiveMQ assumptions, and GitLab CI job design. The developer made the decisions, and the AI assistant executed the selected path.

After implementation, the AI assistant was asked to run feasible local checks, such as XML parsing, residual text searches, linter checks, and pinpointing relevant lines in GitLab logs. Full GitLab builds and installer validation remained developer-owned.

### 3. Effective Collaboration Habits

The most effective habit was providing real inputs before asking for conclusions. A concrete log file, service state, build artifact list, or GitLab package view is far more useful than saying "the build failed" in the abstract.

Another useful habit was clearly stating whether the current request was analysis-only or allowed to modify files. This prevented premature changes before the approach was confirmed.

Asking the AI assistant to enumerate touchpoints before editing was especially valuable. In InstallAnywhere projects, one feature can span `.gitlab-ci.yml`, `pom.xml`, `TAFCore.iap_xml`, locale files, scripts, documentation, and historical snapshots. Listing touchpoints first reduces missed changes.

Persisting conclusions was also important. `docs/context-snapshot.md` restores project context, `docs/migration-tasks/` tracks technical work, and this document captures the collaboration pattern itself.

Finally, it was important to allow the AI assistant to revise earlier conclusions. During the GitLab 403 investigation, the discussion moved through missing Windows classifiers, group registry scope, project registry scope, group ID versus project ID confusion, and `CI_JOB_TOKEN` access. The conclusion improved as new facts were introduced.

### 4. What the AI Assistant Is Good At

The AI assistant is useful for reading large files and tracing relationships. For example, it can locate actions inside `TAFCore.iap_xml`, connect `objectID` and `refID`, and check whether an action is actually attached to install children.

The AI assistant is also useful for repetitive edits that are easy to miss. Removing Nmap required updates to CI pre-staged binaries, Maven dependencies, InstallAnywhere install and uninstall actions, locale entries, and documentation.

The AI assistant is good at explaining build logs and distinguishing failure boundaries. For example, it helped separate "the Windows zip has not been published" from "the Windows zip exists, but GitLab registry access still returns 403", and pointed to the exact log lines supporting each conclusion.

The AI assistant is also useful for creating and maintaining process documentation. In long-running installer migration work, documentation reduces context recovery cost and makes it easier to share knowledge with the team.

### 5. What Developers Still Need To Own

Business boundaries still require developer decisions. Examples include whether Zero Engine integration should be minimal service, production basic, or full lifecycle; whether Nmap is fully replaced by Zero Engine; and whether the SQLite seed database should be removed during uninstall.

GitLab permissions, package registry visibility, and cross-project token allowlists also require developer confirmation. The AI assistant can suggest likely causes and investigation paths, but the actual permission model must be verified in GitLab.

Full installer validation remains developer-owned. The AI assistant can perform static checks and local lightweight validation, but it cannot replace installing the final package in the target environment.

### 6. Reusable Prompt Templates

For log diagnosis:

```text
Here is the GitLab or installer log path: <path>. Please analyze the failure first without modifying the project. Point out which log lines support the conclusion.
```

For limiting the scope:

```text
The project path is <path>. Only modify this project. First search for all touchpoints and explain the impact area, then proceed.
```

For comparing options:

```text
Do not modify files yet. List the possible approaches, their differences, pros and cons, and your recommendation. Wait for developer confirmation before executing.
```

For implementation:

```text
Apply the confirmed approach. After the change, run feasible local checks and explain what was verified locally and what still needs developer validation in GitLab or the installer environment.
```

For documentation:

```text
Update the project documentation with this conclusion so future conversations can restore the context.
```

### 7. Lessons Learned: The 20+ Build ZE Service Chain Story

> **Timeline**: 2026-05-26 to 2026-06-02  
> **Commits**: `c79cfb3` through `bb7ad1b` (20 TAFCore.iap_xml changes, ~22 GitLab builds + installations)  
> **Severe outcome**: The final AI-generated code ran `rmdir /s /q "\"`, recursively deleting the developer's C: drive

#### 8.1 Starting point: AI adding new nodes to IA XML

Zero Engine needed to register as a Windows service (`ZESvc`) during PI installation. The initial approach was to add new `Exec`, `NTServiceController`, and `MakeRegEntry` nodes to `TAFCore.iap_xml` with fresh `objectID` values, then wire them into the install chain.

AI generated these XML nodes, calculated objectIDs, managed `refID` references, and arranged execution order. Each change passed XML parse validation and local static checks.

#### 8.2 Builds 4–14: builds succeed, install does nothing

GitLab builds always succeeded (`zeroengine(BUILD)` appeared in build logs), and ZE files were packaged into the installer. But after Windows installation:

- The `zeroengine\` directory sometimes appeared, sometimes did not
- `ZESvc.exe -install` **never executed**
- No ZE service registration appeared in install logs

Over 10+ build cycles, AI adjusted the objectID mounting strategy (installChildren vs visualChildren, ruleExpression, ref vs inline, different parent nodes), but the result never changed — the service chain was **silently skipped**.

#### 8.3 The breakthrough: IA Builder strips text-added objectIDs

The key discovery came when the developer asked AI to **diff the IA Builder's actual `TAFCoreBuild.iap_xml` against the source file**. The diff revealed the root cause:

> **IA Builder silently strips all objectIDs added via text editing during its "Saving project" phase. Only objects created through the IA Designer GUI are preserved.**

This explained why 10+ changes all failed: regardless of where objectIDs were placed or how references were wired, the build output simply did not contain those nodes. IA Builder **reports no warnings** — it just silently discards them.

#### 8.4 Plan B: reuse an existing IA-registered ExecuteScript (build 23)

Once "cannot add new objectIDs" was confirmed, the strategy shifted immediately: **modify properties of existing IA Designer-registered objects only**.

The chosen node was `d82cc271b581` (ExecuteScript, originally commenting `copy nginx`), because:
- It was created by IA Designer, so its objectID would survive the build
- Its `script` property **could be text-edited** and was preserved after build
- Its execution timing was correct: after zeroengine files were installed, before TAFdb

AI appended ZE service setup commands to this script, including JRE extraction via PowerShell `Expand-Archive` with a `$nested` temporary variable for flattening subdirectories.

Build 23 was the first time ZE service commands **appeared in install logs**. However, four new issues were found during verification.

#### 8.5 Build 24: the fix that destroyed C: drive

One issue from build 23 was that the PowerShell variable `$nested` was misinterpreted by IA's `$xxx$` variable substitution engine, causing JRE extraction to fail.

AI's fix switched from PowerShell to CMD batch variables:

```batch
set "JREDIR=$USER_INSTALL_DIR$\zeroengine\jre"
set "ZIPNAME=zulu21.44.17-ca-jre21.0.8-win_x64"
if not exist "%JREDIR%\bin\java.exe" (
    ...
    rmdir /s /q "%JREDIR%\%ZIPNAME%"
)
```

The idea was sound (avoid PowerShell variables being misinterpreted by IA), but it hit the **classic CMD delayed expansion trap**:

1. Both `set` and `%JREDIR%` were inside the `if "%OS%"=="Windows_NT" ( ... )` compound block
2. CMD expands all `%var%` references when **parsing the entire block**, before any line executes
3. At parse time, `set` had not yet run, so `%JREDIR%` and `%ZIPNAME%` expanded to **empty strings**
4. `rmdir /s /q "%JREDIR%\%ZIPNAME%"` became `rmdir /s /q "\"` — **recursively deleting the current drive root**

Since the IA installer runs with **administrator privileges** and typically operates from **C: drive**, this was equivalent to `rmdir /s /q "C:\"`.

#### 8.6 Outcome and resolution

This code executed during the developer's Windows installation test, **actually deleting C: drive contents**.

The fix (commit `bb7ad1b`) uses a defense-in-depth approach:
1. **Eliminate all CMD environment variables** (`set` + `%var%`), using IA variables (`$USER_INSTALL_DIR$`) directly
2. **Use IA path separator variables `$\$`** (not bare `\`), matching the pattern of all IA Designer-created scripts
3. **Use CMD xcopy/rmdir for directory flattening** (not PowerShell `$nested`), avoiding IA's `$var$` substitution conflict
4. **Add a persistent safety audit script** `scripts/verify-destructive-commands.ps1` that checks all destructive commands for empty-path risks

#### 8.7 Lessons summary

| # | Lesson | Root cause | Prevention |
|---|--------|-----------|------------|
| L1 | **IA Builder silently strips text-added nodes** | IA only preserves Designer-registered objectIDs | Only modify existing node properties; diff `TAFCoreBuild.iap_xml` vs source after every build |
| L2 | **CMD `%var%` is empty inside `( )` blocks** | Delayed expansion — `%var%` is expanded at block parse time, not at line execution time | **Never use CMD environment variables** in IA ExecuteScript; use IA variables exclusively |
| L3 | **IA `$xxx$` substitution hits PowerShell variables** | IA does full-text `$...$` matching regardless of shell type | PowerShell commands should only receive IA-pre-substituted literal paths; no PS temporary variables |
| L4 | **AI-generated destructive commands lack safety verification** | AI does not understand CMD/IA interaction boundaries | Run `verify-destructive-commands.ps1` after every change; static-check all `rmdir`/`rm -rf` paths for empty/root values |
| L5 | **Static XML validation is insufficient** | XML parse pass ≠ correct runtime behavior | Always validate with real installation; diff `TAFCoreBuild.iap_xml` for IA-specific behaviors |
| L6 | **Path concatenation must follow IA conventions** | IA uses `$\$` / `$/$` as path separators | Use `$\$` or `$/$` consistently in ExecuteScript/Exec; never use bare `\` or `/` after IA variables |

#### 8.8 Timeline summary

| Phase | Build | Key event |
|-------|-------|-----------|
| New nodes | 4–14 | 10+ builds; ZE service chain silently skipped every time |
| Root cause | — | Diffing `TAFCoreBuild.iap_xml` revealed IA strips all text-added objectIDs |
| Mounting variations | 15–22 | ref, inline, installChildren, visualChildren — all stripped |
| Plan B | 23 | Modified existing script's `script` property → first successful execution; 4 secondary issues found |
| CMD trap | 24 | Fix for `$nested` introduced `%var%` delayed expansion bug → **C: drive deleted** |
| Final fix | 25 | IA `$\$` path separators + persistent safety audit script |

### 9. MongoDB to PostgreSQL Migration Campaign (2026-06-09 to 2026-06-13)

Following the completion of Zero Engine integration and SI removal, the project entered its most critical refactoring phase: **migrating the underlying database from MongoDB to PostgreSQL 18.4**. Over a series of 10 GitLab builds and installation verifications (Build 30 to Build 39), the AI assistant and the developer collaborated closely to overcome a series of highly challenging issues spanning script syntax, Java runtimes, extraction performance, service registration, and InstallAnywhere compiler memory crashes.

Here are the 10 typical problems, solving thoughts, and solutions encountered during this campaign:

#### 9.1 Problem 1: CMD Nested Double Quotes Causing `initdb` Syntax Error
*   **Symptom**: During installation, PostgreSQL's `initdb` initialization failed silently, preventing the database from starting.
*   **Root Cause**: The command executing `initdb` in `TAFCore.iap_xml` was structured like `cmd /c "cd /d "path" && "path\initdb.exe" ..."`. CMD.exe cannot correctly parse such nested, unescaped double quotes, causing the path to be truncated or throwing a syntax error.
*   **Resolution**: Corrected the quote nesting in `TAFCore.iap_xml` by decoupling and properly escaping the outer `cmd /c` quotes from the inner path quotes, ensuring CMD can correctly recognize the entire command chain.

#### 9.2 Problem 2: `DatabaseConnector.java` Still Using MongoDB-Specific Connection Check
*   **Symptom**: The installation hung at the "Database Connection Verification" panel and triggered a rollback, indicating that the database could not be reached.
*   **Root Cause**: The Java Custom Code in `DatabaseConnector.java` was still hardcoded to use MongoDB's Java Driver to establish a Mongo connection, which inevitably failed under the PostgreSQL architecture.
*   **Resolution**: Refactored `DatabaseConnector.java` to use a **generic TCP Socket connection check**. This check does not depend on any database-specific driver jar, but simply verifies the availability of the specified IP and Port via a low-level TCP handshake, making it lightweight, robust, and 100% compatible with PostgreSQL.

#### 9.3 Problem 3: `ZESvc` Service and `zeroengine` Directory Leftover After Installation Rollback
*   **Symptom**: When the installation failed and rolled back, other directories were cleanly removed, but the `ZESvc` service remained running and the `zeroengine` folder was locked and undeleted.
*   **Root Cause**: IA's automatic rollback only cleans up files it natively tracks. `ZESvc` is a Windows service registered dynamically during installation via custom scripts, which IA is unaware of, leaving the service running and files locked during rollback.
*   **Resolution**: Added **service stopping, deletion, and directory cleanup logic** to the `uninstall()` method of `PanelDatabaseConnectivityConfirmationAction.java` (which is triggered during both IA uninstallation and rollback). This ensures that `ZESvc` is gracefully stopped and unregistered at the very beginning of a rollback or manual uninstall, releasing file locks and completely removing leftovers.

#### 9.4 Problem 4: PostgreSQL Static Packaging Causing Missing `share` and `lib` Directories
*   **Symptom**: `initdb` failed with errors indicating that the `share/postgresql` directory was missing.
*   **Root Cause**: InstallAnywhere's `InstallDirectory` static packaging mechanism suffers from "variable traps" and "empty folder filtering". When folders are named `share` or `binaries`, the IA compiler misinterprets them as built-in path variables (like `$share$`) and performs incorrect substitutions, or silently filters out non-executable files it deems unimportant.
*   **Resolution**:
    1.  **Dynamic Extraction (Scheme B)**: Copied the complete official PostgreSQL zip archive unmodified into `binaries/` via `pom.xml`, letting IA package it as a single file, and then dynamically extracted it at installation time via ExecuteScript.
    2.  **Hybrid Path Pattern**: Introduced `$$\$` to isolate literal path names in `TAFCore.iap_xml` commands (e.g., `"$USER_INSTALL_DIR$$\\$database$\\$bin$\\$psql.exe"`), completely avoiding misinterpretation by IA's path variable substitution engine.

#### 9.5 Problem 5: GnuWin32 `unzip.exe` Silently Crashing in Modern Windows Environments
*   **Symptom**: Extracting PostgreSQL binaries on Windows Server 2019+ was extremely slow, and the extracted directory contained only the `bin` folder, with other critical folders (`share`, `lib`) completely missing.
*   **Root Cause**: The GnuWin32 `unzip.exe` (v5.51-1) pre-packaged in the project depends on the ancient `msvcp60.dll` (VC++ 6.0 runtime). On modern Windows Server systems lacking this DLL, `unzip.exe` suffers a **silent memory crash** when extracting large files, terminating prematurely without reporting any errors.
*   **Resolution**: Upgraded the extraction tool to **`tar.exe`**, which is natively built into Windows 10 (Build 17063+) and Windows Server 2019+. `tar.exe` has zero external DLL dependencies, offers extremely high extraction performance, and natively supports selective zip extraction (e.g., excluding useless directories like `pgAdmin` and `doc`), making extraction highly stable.

#### 9.6 Problem 6: Missing `tar.exe` Causing Mid-way Installation Failures (Fail-Fast Mechanism)
*   **Symptom**: On older Windows versions lacking native `tar.exe`, the installation would fail midway during extraction, leading to a poor user experience.
*   **Root Cause**: An early pre-flight check is required to prevent mid-way failures.
*   **Resolution**: Implemented a **silent pre-flight compatibility check** for `tar.exe` in the `install` phase of `GetApplicationNames.java` (Java Custom Code), supporting both GUI and Headless modes. If `tar.exe` is missing, it displays a friendly error dialog (or prints to stderr) and throws a `FatalInstallException` to cleanly abort the installation before any changes are made.

#### 9.7 Problem 7: InstallAnywhere 2025 Compiler Heap Corruption Crash (Error Code -1073740940 / 0xC0000374)
*   **Symptom**: At the end of the GitLab build, the `buildinstaller` process suddenly crashed with a **Heap Corruption** exception, failing the CI job.
*   **Root Cause**: A low-level C++ defect in the InstallAnywhere 2025 compiler. When we manually added/cloned an inline `keyFile` node (which is an orphaned node in the IA object tree) pointing to an *existing* physical file (like `pg_hba.conf`) and set its `fileSize` to `-1`, the compiler attempted to dynamically measure the file size and write it back. Lacking a proper parent context, this write operation caused a C++ memory out-of-bounds write and heap corruption upon `buildinstaller` exit.
*   **Resolution**:
    1.  Changed the component's `keyFile` property to reference an existing physical file node that is properly parented in the object tree (Windows references `createdb.sql`, Linux references `LICENSE-Community.txt`), completely removing the orphaned `keyFile` remnants.
    2.  For `pg_hba.conf`, **hijacked** existing physical nodes that are properly parented in the object tree (Windows node `3bcfb201b174`, Linux node `3bd05399b17d`, originally `THIRD-PARTY-NOTICES.gotools`) and renamed them to `pg_hba.conf`. Since these nodes have a valid parent context, their `fileSize` being set to `-1` is safely and dynamically handled by the compiler.

#### 9.8 Problem 8: `postgresql.conf` Log Path Typo and `TAFsvc` Startup Failure
*   **Symptom**: The database started but created an abnormal folder literally named `$log` in the data directory; meanwhile, `TAFsvc` failed to start.
*   **Root Cause**:
    1.  In `postgresql.conf`, `log_directory` was incorrectly configured as `'$USER_MAGIC_FOLDER_2$/$log'`. Since `$log` is not a valid IA variable in that context, it was written literally.
    2.  `TAFsvc` failed to start because `pg_hba.conf` deployment failed, preventing the database creation script from connecting via `psql`, breaking the database setup chain.
*   **Resolution**:
    1.  Corrected `log_directory` to `'$USER_MAGIC_FOLDER_2$/log'`, merging PostgreSQL logs with application logs.
    2.  Upgraded the database creation script with a **triple-path fallback copying logic**: regardless of whether `pg_hba.conf` is extracted to the root, `database`, or `database/bin` directory, the script is guaranteed to copy it to `$USER_MAGIC_FOLDER_2$\db\pg_hba.conf` and execute `pg_ctl reload` to establish the connection.

#### 9.9 Problem 9: `ZESvc` Service Failing to Auto-start After Installation
*   **Symptom**: Although `ZESvc.ini` configured `starttype=auto`, the service's startup type in Windows SCM remained "Manual" after installation.
*   **Root Cause**: The installation script executed `reg add ... /v ImagePath ...` to fix missing quotes in the service path. This direct registry write operation unintentionally reset the service's `Start` property in SCM to its default value (Manual).
*   **Resolution**: Appended **`sc config ZESvc start= auto`** (note the space after `start=`) to the installation script as "double insurance" to force the service startup type to automatic.

#### 9.10 Problem 10: Dynamic Writing of Zero Engine Properties Causing Locale Conflicts and Size Mismatches
*   **Symptom**: Zero Engine default configurations in `application-prod.properties` did not take effect after installation, or behaved inconsistently across languages.
*   **Root Cause**: `ASCIIFileManipulator` was used to dynamically append configurations, but its `additionalText` property was overridden in localization files like `custom_zh_CN` and `custom_en`, causing the appended text to be overwritten or lost in specific locales. Additionally, the physical node file size of `application.properties` was hardcoded, causing size verification mismatches.
*   **Resolution**:
    1.  **Statically injected** the Zero Engine default configurations into the `application.properties` template file, eliminating the maintenance cost of dynamic appending.
    2.  **Cleared** the `additionalText` property of the `ASCIIFileManipulator` action in both the main XML and all localization property files (`custom_zh_CN`, `custom_en`), making it a safe no-op.
    3.  Set the `fileSize` of the `application-$PROFILE$.properties` node to `-1` to support dynamic size measurement.

### 10. Knowledge Consolidation and Archiving Campaign (2026-06-13 to 2026-06-15)

Following the successful integration of PostgreSQL, the replacement of the IE Engine with the Zero Engine, and multiple rounds of GitLab CI builds and installation verifications, the project transitioned into the **Knowledge Consolidation and Archiving Campaign**. To transform the complex, black-box troubleshooting and refactoring experiences of niche systems (InstallAnywhere, Windows services, JSL wrappers, compiler heap corruption) into durable team assets, the AI assistant and the developer collaborated closely to establish a comprehensive four-dimensional archive in the `docs/migration-remediation-archive/` directory.

Here are the core findings, corrected facts, and new AI collaboration insights from this campaign:

#### 10.1 Core Correction: Zero Engine's Independent SQLite 3 Data Isolation
*   **Background**: In earlier phases, it was mistakenly assumed that the Zero Engine shared the main application's PostgreSQL database.
*   **Fact Correction**: Through deep architectural review and configuration audits, it was confirmed that **the Zero Engine utilizes an independent SQLite 3 database (`zeroengine/database/zero_engine.db`)** located within its own installation directory.
*   **Architectural Significance**: This design achieves physical-level data and performance isolation. As a lightweight companion engine, the Zero Engine stores its own state and configuration locally in SQLite, communicating with the MTP Core solely via lightweight HTTP APIs on port `8088`. This correction was seamlessly propagated across all archive files, ensuring 100% technical accuracy.

#### 10.2 Deep Dive: IE Engine's 5 Windows Services & ZE Service Chain Hoist Mechanism
*   **Precise Identification of IE Engine's 5 Windows Services**: By tracing the historical packaging configuration `TAFCore.iap_xml.2022.196` and Java recovery code in `RestoreService.java`, we precisely identified the 5 pre-migration Windows services of the IE Engine: `iesnmptrapd`, `ieelfsrvmanager`, `ieexportersrv`, `ieeventsrv`, and `iemssenginesrv` (and `mss-engine` on Linux). This provided the QA team with an accurate "As-Is" baseline.
*   **ZE Service Chain Hoist Mechanism**: We documented the root cause of the "gap" in ZE service registration during Build-5 to Build-11 — the IA compiler silently ignores action groups defined under inactive components (e.g., Linux), even if referenced in the active Windows sequence. The ultimate solution involved using a Python script to "Hoist" (elevate) Action Group `ecdb7d1e9e76` directly into the Windows-only sequence, bypassing the compiler's black-box isolation.

#### 10.3 Deliverables: High-Standard Four-Dimensional Archive System
We created and refactored 4 key documents under `docs/migration-remediation-archive/` to serve as both team delivery standards and career assets:
1.  **`01-team-delivery-and-qa-guide.md` (Team Delivery & QA Guide)**: Details the As-Is vs. To-Be topological comparisons, service dependencies, startup/shutdown sequences, installation UI/step variations (e.g., ports shifting from 27017->5432 and 4440->8088), and pre-flight `tar.exe` checks to help QA engineers ramp up instantly.
2.  **`02-hardcore-technical-postmortems.md` (Hardcore Technical Postmortems)**: Provides extremely thorough, source-level postmortems of the IA Heap Corruption (0xC0000374), C-drive deletion (CMD delayed expansion), JSL service wrappers (`ZESvc`), uninstallation chain repairs, and Action Group Hoisting.
3.  **`03-ai-assisted-reengineering-methodology.md` (AI-Assisted Reengineering Methodology)**: Distills a general methodology for collaborating with AI in niche, closed-source, and legacy systems using "controlled variables," "multi-dimensional diffs," and "static safety sandboxes," using the ZE service chain gap and GnuWin32 `unzip.exe` crash as practical case studies.
4.  **`04-career-portfolio-and-mock-interviews.md` (Career Portfolio & Mock Interviews)**: Translates architectural decisions and troubleshooting triumphs into STAR-formatted accomplishments at the Staff/Principal level, accompanied by 5 deep architectural mock interview questions (covering companion engine data isolation, black-box compiler debugging, etc.) to convert technical work into professional value.

#### 10.4 New Insights on AI Collaboration: Agile Refactoring & Evidence-Driven
*   **Agile Response to Fact Corrections**: When the developer provided critical corrections regarding the "SQLite database" and "IE's 5 Windows services," the AI assistant demonstrated exceptional contextual refactoring capabilities, rewriting and cross-validating all 4 massive documents in a single turn without sacrificing depth, ensuring perfect consistency.
*   **Normalizing the "Safety Sandbox"**: When generating documents or scripts containing potentially destructive commands, running `verify-destructive-commands.ps1` for static safety audits has become a standard practice. The lesson of "preventing C-drive deletion" is now deeply integrated into the daily development workflow, forming a closed-loop safety mechanism.

### 8. How To Maintain This Retrospective

When a new effective collaboration pattern appears, add it to "Effective Collaboration Habits".

When a new lesson or failure mode appears, add it to "What Developers Still Need To Own" or create a new "Lessons Learned" section.

When a prompt becomes reusable, add it to "Reusable Prompt Templates".

When this document is shared with a wider team, add any necessary background for the audience, such as the InstallAnywhere build flow, Maven artifact classifiers, or GitLab CI job, stage, and `needs` relationships.
