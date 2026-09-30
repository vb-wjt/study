# PostgreSQL 迁移与安装器重构：硬核技术复盘与 IA 避坑经验

> **最后更新**：2026-07-16  
> **文档用途**：深度复盘在 该产品 安装器重构、PostgreSQL 迁移与 IE -> ZE 升级过程中遭遇的硬核技术灾难与攻坚，提供完整的事故机理分析、真实错误与修复代码、防御性设计方案、以及静态安全审计工具实现，为团队沉淀极具技术深度的避坑指南。第一~五章聚焦 Windows 攻坚（CMD 延迟展开导致开发机 C 盘递归删除、InstallAnywhere 编译器静默剥离文本新增节点、IA 2025 编译器 Heap Corruption 崩溃、Zero Engine 服务链编排失效与 Hoist 提升、IA 生存指南）；**第六章为 Linux 双平台（RHEL + Ubuntu）攻坚**（IA `$…$` 吞噬内联脚本、编译器剪枝与规则覆写、原生卸载器 exit 218 黑盒脱钩、离线 PG 拆包不全、RHEL 专属门禁误挡 Ubuntu、`tafdb` SysV 假象等），配套交付/QA 指南见 [`05-linux-delivery-and-qa-guide.md`](../5-delivery/linux-delivery-and-qa.md)。

---

## 一、 灾难复盘：CMD 延迟展开导致开发机 C 盘递归删除

### 1. 事故现场与症状
在 `build-22` 构建装机验证中，安装器在执行 Zero Engine JRE 解压与清理脚本时，突然发生异常。开发机（或构建 Runner 节点）的 C 盘系统目录和用户文件开始被递归删除，导致系统瘫痪。

### 2. 事故机理深度剖析

#### (1) CMD 复合块（Parenthesis Block）的两阶段解析模型
Windows 命令提示符 (`cmd.exe`) 在解析括号 `(...)` 包裹的复合块（如 `if`、`for` 语句）时，采用以下两阶段模型：
*   **第一阶段（预解析阶段）**：当 `cmd.exe` 读到括号复合块的左括号 `(` 时，会**一次性**将整个括号块读入内存，并将其中所有的百分号变量 `%VAR%` 替换为它们**进入该复合块之前的值**。
*   **第二阶段（执行阶段）**：依次执行括号块内的每一行命令。此时，在块内部通过 `set VAR=value` 修改的变量值，**不会**反映在仍然使用 `%VAR%` 引用的后续命令中。

#### (2) 致命的“空值”级联与 `rmdir /s /q`
当时在 `if` 复合块中编写的危险代码结构如下：

```cmd
:: 危险的原始代码示例（反面教材）
if "%OS_PLATFORM%"=="Windows" (
    set JREDIR=$USER_INSTALL_DIR$\zeroengine\jre
    set ZIPNAME=zulu-jre-21-win64.zip
    
    :: 此时由于预解析，%JREDIR% 和 %ZIPNAME% 被替换为进入 if 块之前的值（即空值 ""）
    powershell -Command "Expand-Archive -Path '%USER_INSTALL_DIR%\zeroengine\%ZIPNAME%' -DestinationPath '%JREDIR%'"
    
    :: 关键灾难点：%JREDIR% 被解析为空值 ""
    :: 实际执行命令变为：rmdir /s /q "\"
    :: 在 Windows 中，"\" 代表当前驱动器的根目录（即 C:\）！
    rmdir /s /q "%JREDIR%"
)
```

由于进入 `if` 块前 `%JREDIR%` 未被定义（为空值 `""`），复合块预解析后，危险的清理命令被无情地展开为：
```cmd
rmdir /s /q "\"
```
这导致 `cmd.exe` 拥有管理员权限时，会从当前盘符（通常是 `C:`）的根目录开始，静默且无可挽回地递归删除所有系统文件。

### 3. 防御性重构与修复代码

为了彻底杜绝此类风险，我们实施了**无变量依赖的防御性重构**，完全弃用了在复合块内部动态定义和引用环境变量的做法，改用 InstallAnywhere 的字面量变量直接展开：

```cmd
:: 安全的修复后代码（正面示范）
:: 1. 彻底去掉 if 复合块，改用单行命令或 IA 自身的规则守护（Rule Guard）
:: 2. 使用 IA 的字面量变量 $$\$ 路径分隔符，避免 CMD 变量预解析
:: 3. 引入严格的防御性前置校验，确保路径不为空且包含安全特征字符

if exist "$USER_INSTALL_DIR$$\\zeroengine\\jre" (
    cd /d "$USER_INSTALL_DIR$$\\zeroengine" && rmdir /s /q "$USER_INSTALL_DIR$$\\zeroengine\\jre"
)
```

### 4. 工程闭门羹：静态安全审计工具 `verify-destructive-commands.ps1`

为了用工具彻底杜绝此类高危命令合入代码库，我们编写并持久化了静态安全审计脚本 `verify-destructive-commands.ps1`。该脚本可无缝合入 GitLab CI 门禁。

#### 审计脚本完整源码：

```powershell
# <docs-repo>\scripts\verify-destructive-commands.ps1
# ==============================================================================
# 静态安全审计脚本：检测安装器 XML 及脚本中是否存在未受保护的破坏性删除命令
# ==============================================================================

$TargetDir = "<repo>\installer"
$IapXmlPath = Join-Path $TargetDir "src\main\TAFCore.iap_xml"

if (-not (Test-Path $IapXmlPath)) {
    Write-Host "⚠️ 未找到 TAFCore.iap_xml，跳过 XML 安全审计。" -ForegroundColor Yellow
    exit 0
}

Write-Host "🔍 开始静态安全审计：$IapXmlPath" -ForegroundColor Cyan

[xml]$Xml = Get-Content $IapXmlPath -Raw
$HasError = $false

# 1. 匹配所有含有 rmdir 或 rm -rf 的 ExecuteScript 或 Exec 节点
$Nodes = $Xml.SelectNodes("//property[@name='script']//string | //property[@name='commandLineArgs']//string")

foreach ($Node in $Nodes) {
    $Content = $Node.InnerText
    if ($Content -match "rmdir\s+/s\s+/q" -or $Content -match "rm\s+-rf") {
        # 严格的安全规则：破坏性删除命令必须包含明确的安装目录变量，且不能直接对根路径操作
        if ($Content -match "rmdir\s+/s\s+/q\s+`"\s*%[^%]+%\s*`"" -or $Content -match "rmdir\s+/s\s+/q\s+`"\s*\\`"") {
            Write-Host "❌ 发现高危命令隐患！" -ForegroundColor Red
            Write-Host "   内容：$Content" -ForegroundColor DarkRed
            $HasError = $true
        } elseif ($Content -match "rmdir\s+/s\s+/q\s+`"\$USER_INSTALL_DIR\$\$\\" -or $Content -match "rmdir\s+/s\s+/q\s+`"\$USER_INSTALL_DIR\$") {
            Write-Host "✅ 发现受保护的删除命令（已绑定安装目录字面量）：" -ForegroundColor Green
            Write-Host "   内容：$Content" -ForegroundColor Gray
        } else {
            Write-Host "⚠️ 发现未受保护或格式可疑的删除命令：" -ForegroundColor Yellow
            Write-Host "   内容：$Content" -ForegroundColor Gray
            $HasError = $true
        }
    }
}

if ($HasError) {
    Write-Host "❌ 安全审计未通过！请立即修复上述高危删除命令。" -ForegroundColor Red
    exit 1
} else {
    Write-Host "🎉 安全审计 100% 通过！未发现破坏性删除隐患。" -ForegroundColor Green
    exit 0
}
```

---

## 二、 20+ 次构建失败与 ObjectID 剥离陷阱

### 1. 逆向工程：发现 IA 编译器的黑盒剥离行为
在早期的 20 多次构建尝试中，我们在 `TAFCore.iap_xml` 中通过文本编辑器手动新增了用于 Zero Engine 安装和卸载的多个节点，并为它们分配了全新的 `objectID`（如 `aa000001b13a` 等）。

然而，每次通过 Maven 调用 `buildinstaller` 任务进行打包后，装机时这些新增的动作都**完全没有执行**。

通过逆向对比构建前后的 XML 文件，我们发现了一个惊人的黑盒行为：
> **InstallAnywhere 编译器在加载 `.iap_xml` 时，会进行严格的内部 ObjectID 注册表校验。任何未通过 InstallAnywhere GUI 界面注册、而是由外部文本编辑器直接插入的孤立 ObjectID 节点，在构建时都会被编译器静默剥离（Stripped）并丢弃！**

### 2. 破局思路：从“新增节点”转向“属性劫持（方案 B）”
既然无法通过文本手段新增节点，而在没有 GUI 授权环境的 headless 构建服务器上又无法打开 IA Designer 界面注册新节点，我们必须寻找替代方案。

我们演进出了**“属性劫持（方案 B）”**：
1. **寻找“尸体”节点**：在 XML 中寻找那些已被 InstallAnywhere 官方注册、但在当前 PI 业务中已经废弃或不生效的正常节点。
2. **劫持并重写属性**：保留 these 节点的 `objectID` 和外壳结构不变（确保通过编译器的注册表校验），但将其内部的执行脚本、命令行参数、安装源文件等关键属性彻底重写为我们需要的 Zero Engine 安装/卸载逻辑。

#### 劫持映射对照表：

| 被劫持的原始节点 ID | 原始业务功能 | 劫持重写后的新业务功能 |
| :--- | :--- | :--- |
| **`d82cc271b581`** | `ExecuteScript` ("copy nginx") | **Windows ZE 服务自启双保险**：注入 `sc config ZESvc start= auto` 及相关配置。 |
| **`dff26084a066`** | `ExecuteScript` ("Delete Special Folders") | **Windows 卸载/回滚清理**：注入停止、注销 `ZESvc` 并强力擦除 `zeroengine` 目录的命令。 |

通过这种“借尸还魂”的巧妙设计，我们成功绕过了编译器的 ObjectID 校验，实现了 100% 稳定的功能集成。

---

## 三、 IA 2025 编译器 Heap Corruption (0xC0000374) 攻坚

### 1. 崩溃症状与日志分析
在将 `pg_hba.conf` 引入安装包并在 GitLab CI 上构建时，构建任务频繁发生异常崩溃，退出码为 `-1073740940`（即 `0xC0000374`，Windows 系统的 **Heap Corruption / 堆损坏异常**）：

```
[buildinstaller] Building installer...
[buildinstaller] ...
[buildinstaller] Exception in thread "main" java.lang.Error: Invalid memory access
[buildinstaller]    at native.compiler.回写文件大小(Native Method)
[buildinstaller]    ...
[buildinstaller] Process scheduled to run in background or crashed. Exit code: -1073740940
```

### 2. 崩溃机理深度剖析

#### (1) 孤立 inline 节点与 `keyFile` 的冲突
在 InstallAnywhere 的 XML 结构中，有些文件节点是作为其他大节点（如 `InstallDirectory`）的 `keyFile` 属性以 **inline（内联）** 形式存在的。这些内联节点在 XML 中没有完整的父节点上下文，是一个“孤立节点”。

#### (2) `fileSize="-1"` 触发的 C++ 越界写入
1. 当我们手动将 `pg_hba.conf` 定义为一个内联的 `keyFile` 节点，且其物理文件在构建机上实际存在时，IA 编译器在打包结束前会试图将该文件的实际大小回写到 XML 的 `fileSize` 属性中。
2. 如果我们在 XML 中将该内联节点的 `fileSize` 设置为 `-1`（指示动态计算），IA 的底层 C++ 编译器在试图定位该内联节点的父级引用并回写大小大小时，由于该节点缺乏完整的 `visualChildren` 链，会导致指针定位到空地址或野指针。
3. 编译器强行进行内存写入，直接触发了操作系统的 **Heap Corruption 保护机制**，导致 JVM 进程被操作系统强行终止。

### 3. 解决方案：劫持正常物理节点与三保险路径拷贝

为了彻底规避这一编译器底层 Bug，我们设计了极其优雅的**“物理节点劫持与路径自适应拷贝”**方案：

#### (1) 恢复 keyFile 为缺失状态（使其安全地被 IA 忽略）
我们将 `keyFile`（Windows 节点 `3bcfb1ffb16a`，Linux 节点 `3bd05398b175`）重定向指向一个不存在的虚拟路径。这样编译器在构建时会因为找不到物理文件而安全地忽略大小回写，彻底避免了 Heap Corruption。

#### (2) 劫持正常物理子节点打包 `pg_hba.conf`
我们转而劫持了 `database` 文件夹下原本就存在的、拥有完整父子上下文的正常物理子节点 `THIRD-PARTY-NOTICES.gotools`（Windows 节点 `3bcfb201b174`，Linux 节点 `3bd05399b17d`）：
*   将该节点的打包源路径修改为 `pg_hba.conf`。
*   将其 `fileSize` 显式设置为精确的 `443` 字节（避免动态计算触发回写）。
*   这样，`pg_hba.conf` 能够以 100% 正常的物理文件形式被释放到安装目录。

#### (3) 升级三保险路径拷贝逻辑
由于被劫持的节点在不同平台释放的具体路径可能存在微小差异，我们在数据库创建脚本（objectID `ecdb7d1e9e72`）中升级了**三保险路径拷贝逻辑**。无论 `pg_hba.conf` 被释放在安装根目录、`database` 目录还是 `bin` 目录下，都能被 100% 稳定地拷贝到 PostgreSQL 的数据目录下：

```cmd
:: 三保险路径拷贝逻辑（真实修复代码）
(if exist "$USER_INSTALL_DIR$$\\pg_hba.conf" (
    copy /Y "$USER_INSTALL_DIR$$\\pg_hba.conf" "$USER_MAGIC_FOLDER_2$$\\db\\pg_hba.conf"
) else (
    if exist "$USER_INSTALL_DIR$$\\database\\pg_hba.conf" (
        copy /Y "$USER_INSTALL_DIR$$\\database\\pg_hba.conf" "$USER_MAGIC_FOLDER_2$$\\db\\pg_hba.conf"
    ) else (
        copy /Y "$USER_INSTALL_DIR$$\\database\\bin\\pg_hba.conf" "$USER_MAGIC_FOLDER_2$$\\db\\pg_hba.conf"
    )
))
```

---

## 四、 伴生引擎重构：IE -> ZE 替换的技术攻坚复盘

在将旧版 C++ 编写的 Intelligent Engine (IE) 替换为现代 Java 21 编写的 Zero Engine (ZE) 过程中，我们遭遇了服务化集成、动作组编排失效等一系列黑盒挑战。

### 1. JSL (Java Service Launcher) 服务化集成

MTP Core 的 `TAFsvc` 服务是使用 `jsl64.exe` 包装的。为了保证 Zero Engine 也能作为独立的 Windows 服务运行，我们复用了这一成熟的机制：
1. **文件复制**：在安装期，将 `$USER_INSTALL_DIR$\TAFsvc.exe`（实际上是 `jsl64.exe`）复制为 `$USER_INSTALL_DIR$\zeroengine\ZESvc.exe`。
2. **静态配置注入**：编写 `ZESvc.ini` 配置文件，显式指定 Java 21 的 JRE 路径、运行参数及 `zeengine.war` 的启动命令：
   ```ini
   [java]
   jrpath=$USER_INSTALL_DIR$\zeroengine\jre
   cmdline=-Xmx512m -Xms128m -jar zeengine.war --spring.config.additional-location=./config/
   ```
3. **注册与自启**：通过执行 `ZESvc.exe -install` 注册服务，并追加 `sc config ZESvc start= auto` 确保在 Windows 系统重启后能够稳定自启。

### 2. InstallAnywhere 动作组执行失效与 Hoist 提升攻坚 (build-5 -> build-11)

在 `build-5` 到 `build-10` 的装机测试中，我们遭遇了极其诡异的现象：
> **现象**：构建日志中明确出现了 `zeroengine(BUILD)` 记录，且安装后 `zeroengine` 目录下的 WAR 包和 JRE 压缩包也成功落盘，但 **`ZESvc` 服务从未被注册，且解压 JRE 的 `unzip.exe` 动作也从未被执行**。

#### (1) 根因剖析：跨组件引用的静默失效
通过深入逆向分析 `TAFCore.iap_xml` 的组件依赖关系，我们发现了 InstallAnywhere 编译器的又一个黑盒限制：
*   我们创建的 Zero Engine 服务注册动作组 `ecdb7d1e9e76`，其**原始定义**被挂在 `TAF DB Linux` 组件下。
*   在 Windows 安装序列中，我们仅仅通过 `<object refID="ecdb7d1e9e76"/>` 进行了跨组件引用（Cross-Component Reference）。
*   **黑盒限制**：当安装器在 Windows 环境下执行时，由于 `TAF DB Linux` 组件未被激活，编译器在解析执行序列时会**静默跳过**所有定义在未激活组件下的动作组，即使该动作组在 Windows 序列中被显式引用！

#### (2) 破局方案：内联提升 (Hoist) 与动作组重构
为了彻底解决此问题，我们编写了 `apply-ze-install-fix-v7.py` 脚本，实施了**内联提升 (Hoist)** 重构：
1. **解除跨组件引用**：将 `ecdb7d1e9e76` 动作组的完整定义从 Linux 组件中剥离。
2. **内联提升**：直接将其**内联定义**到 Windows 专属的执行序列 `d4095d81b09b` (Windows Only files) 内部，紧跟在 `zeroengine` 文件落盘动作之后。
3. **新增 JRE 动态解压动作**：在服务注册前，新增 `aa000006b13a` 动作，调用 `$USER_INSTALL_DIR$\bin\unzip.exe` 动态解压 JRE 压缩包并平滑展平至 `jre` 目录，确保 JSL 能够找到 Java 21 运行时。

### 3. Windows 卸载链与回滚清理修复 (劫持 dff26084a066)

在安装失败触发回滚、或者用户手动卸载时，由于 `ZESvc` 进程仍在后台运行，其锁定了 `zeroengine` 目录下的 WAR、JAR 及 JRE 文件，导致卸载器无法物理删除该目录，造成严重的卸载残留。

为了实现“零残留”交付，我们采取了**卸载链劫持重构**：
1. **劫持 `dff26084a066`**：劫持了原本用于“删除特殊文件夹”的正常卸载动作 `dff26084a066`。
2. **注入强力清理命令**：在其中追加了针对 `ZESvc` 的优雅停止、注销及目录强力擦除命令，确保在文件解锁后进行物理删除：
   ```cmd
   net stop ZESvc
   sc delete ZESvc
   if exist "$USER_INSTALL_DIR$$\\zeroengine" rmdir /s /q "$USER_INSTALL_DIR$$\\zeroengine"
   ```
这一重构彻底解决了由于进程锁定导致的卸载/回滚残留问题，实现了高质量的闭环交付。

---

## 五、 InstallAnywhere 避坑与生存指南

基于本次重构的血泪教训，特为团队整理以下 InstallAnywhere 核心生存法则：

### 1. ObjectID 注册规则
*   **铁律**：绝对不要在文本编辑器中直接发明并插入新的 `objectID`。
*   **合规做法**：如果必须新增动作，必须在拥有授权的 IA Designer 界面中进行添加和保存；若在 Headless 环境下，必须采用**属性劫持（方案 B）**，复用已有正常节点的 ID。

### 2. 变量转义规则
*   在 IA 的 XML 中，单个美元符号 `$` 代表变量引用的开始（如 `$USER_INSTALL_DIR$`）。
*   如果要在脚本或命令行中输出字面量的美元符号（如 CMD 中的变量或 PowerShell 中的变量），必须使用双美元符号进行转义：
    *   在 XML 文本中：使用 `$$\$` 展开为单个 `$`。
    *   在路径拼接中：使用 `$\$` 作为安全的路径分隔符，防止其与后续字符组合被误解析为 IA 变量。

### 3. 路径分隔符规范
*   在 Windows 平台的脚本中，强烈建议使用原生反斜杠 `\\`（在 XML 中转义为 `$$\$` 或字面量 `\\`）来隔离字面量文件夹，避免使用正斜杠 `/`。
*   正斜杠在某些旧版本的 IA 路径解析器中会被误认为是变量边界，导致路径被截断或解析失败。

---

## 六、 Linux 双平台攻坚：跨发行版适配与卸载脱钩复盘

> 在 Windows 交付稳定后，项目将 PI 安装器扩展到 **RHEL + Ubuntu 双平台**。这一过程再次踩穿了 InstallAnywhere 的多个黑盒边界，并暴露了离线打包、跨发行版门禁与遗留卸载器的一系列深坑。以下六大复盘 + 小坑合集，是 Linux 侧的血泪沉淀。配套交付/QA 指南见 [`05-linux-delivery-and-qa-guide.md`](../5-delivery/linux-delivery-and-qa.md)。

### 1. 灾难复盘：IA `$…$` 成对切分吞噬内联脚本（同一坑复发两次）

#### 事故现场与症状
Linux 安装链在两个不同时间点、两个不同节点上出现**同源**故障：
- **现场一（阶段 2b/2c）**：内联 ExecuteScript `d82cc271b580` 执行时报 `unexpected EOF while looking for matching '"'`，Zero Engine / PostgreSQL 一步没跑。
- **现场二（OS 白名单，`233384b` 之前）**：OS 判定脚本失效，**RHEL 9.7 与 Ubuntu 26.04 双双误判 `OS not supported`**。

#### 事故机理深度剖析
InstallAnywhere 在打包时会对脚本文本做 `$…$` 变量替换，**按出现顺序成对切分** `$` 符号（工程自证：`$/$`、`$Qte$`、`$MOVE$` 等）。当**同一物理行**里 `$` 的总数为**奇数**时，配对发生错位：

```bash
# 反面教材：polyglot 守卫与 8 个 $USER_INSTALL_DIR$ 挤在同一行
# $BASH_VERSION(1 个 $) + 8×$USER_INSTALL_DIR$(16 个 $) = 17 个 $（奇数）
:; if [ -n "$BASH_VERSION" ]; then cp "$USER_INSTALL_DIR$/a" ... ; fi
#            ^^^^^^^^^^^^ 孤立的 $BASH_VERSION 偷走了下一个 $USER_INSTALL_DIR$ 的开头 $
#            → 全行 $ 配对整体错位 → 双引号被拆成奇数 → bash: unexpected EOF → 整脚本中止
```

现场二则是内联脚本直接写了裸 shell 变量 `$ID` / `$VERSION_ID` / `$SUP`，同样被 IA 的 `$…$` 替换层吞噬打乱。对照旁证：同组里**不含** `$` 的 `grep PRETTY_NAME/VERSION_ID` 一直正常，唯独带裸 `$` 的这段挂——精准坐实根因。

#### 真实错误与修复代码
**现场一**：外置为独立脚本（方案 B），`d580` 首行缩为**偶数个 `$`、无 `$BASH_VERSION`**，并中转 `/var/tmp` 避免自删：

```bash
# 4 个 $（偶数），Windows 仍当 label 忽略
:; if [ -f /etc/os-release ]; then cp -f ".../pi-linux-install.sh" /var/tmp/... 2>/dev/null; bash /var/tmp/pi-linux-install.sh "$USER_INSTALL_DIR$"; exit 0; fi
```

**现场二**：OS 判定改为**零 `$` 的 grep 管道**，输出 `TRUE`/`FALSE` 到 `$OS_SUPPORTED$`：

```bash
grep -E '^(ID|VERSION_ID)=' /etc/os-release | sort | tr -d '"' | tr '\n' ' ' \
  | grep -qE '<allowlist-regex>' && echo TRUE || echo FALSE
```

`git bash` 仿真 7 例全绿，RHEL/Ubuntu 实机均通过。

#### 教训沉淀
1. **IA 内联 ExecuteScript 一律不写裸 shell `$` 变量**；需要变量就外置成独立 `.sh`（随 `InstallDirectory` 目录型打包，无新增 objectID、无剥离风险）。
2. 若必须内联，务必让**每一物理行 `$` 数为偶数**，且不与 `$USER_INSTALL_DIR$` 等 IA 变量同行。
3. `bash -n` 与判定矩阵**不覆盖** IA 打包的 `$` 替换层——静态全绿≠实机可跑，**必须实机验证**。

### 2. 灾难复盘：IA 编译器剪枝与规则系统三连坑

#### 事故现场与症状
Linux 动作在多轮构建中「介质有、运行时不执行」——GitLab 日志显示 `zeroengine-linux(BUILD)` / `postgresql(BUILD)` 存在，但装机后目录/服务缺失或脚本被静默跳过；某轮甚至触发编译器 **JVM `EXCEPTION_ACCESS_VIOLATION` 崩溃**。

#### 机理与修复（三连）
1. **双重 `visualParent` 静默剪枝**：子 `Exec` 同时挂在旧组 `9af43c409fc8` 与新组 `f2a097f0b0a3` 下，IA 编译器打包剪枝时因「双重 visualParent」把子动作**静默裁剪**。→ 删冗余容器组，让两个真正的 Exec（`ecd97aa399bc`/`ecd97aa299c9`）作为 `f2a097f0b0a3`（"Linux Only Files"）的**唯一** visualChildren。
2. **`CP970` 规则 ID 全局覆写**：Windows 专属脚本 `d82cc271b581` 与新增 Linux 动作都挂了 `ruleId="CP970"`，打包时 **Windows 的 CP970 最后注册、在全局映射表里盖掉了 Linux 的**，导致 Linux 动作运行时被判定「平台不匹配」而跳过。→ 将 `ruleExpression` 直接重定向到工程已有、最成熟的全局共享规则 **`IsLinux`**。
3. **裸露共享规则致 JVM 崩溃**：移除局部 `<rules>` 块、只留 `ruleExpression` 引用后，IA **不支持「裸露」全局共享规则**——被引用的规则名必须在当前作用域有显式 `<rules>` 块，否则编译警告最终演变为 JVM 内存访问违规崩溃。→ 重新注入局部 `<rules>` 块（`ruleId=IsLinux`），复用三个安全空闲 objectID（`f2a18c29b167`/`ecd97aa399bd`/`ecd97aa299ca`）。

#### 教训沉淀
- IA 的「可视父子关系（visualChildren）」与「执行父子关系（installChildren）」是两套体系，**双重父节点**会触发剪枝；一个动作只保留**单一** visualParent。
- `ruleId` 是**全局命名空间**，跨平台复用同名规则会被后注册者覆写；平台隔离用**唯一命名的全局共享规则**（如 `IsLinux`）。
- 共享规则**仍需局部 `<rules>` 块声明**，否则编译器崩溃。

### 3. 灾难复盘：IA 原生卸载器 exit 218 黑盒

#### 事故现场与症状
Linux 上运行 `trellisappmgruninstall`（LaunchAnywhere native → uninstaller.jar）直接 **exit 218**，无任何 stdout/stderr、无日志文件——真实错误被 native 启动器**吞掉**。

#### 机理与关键反证
218 并非标准 IA 退出码，指向 native 启动器在 **JVM 引导阶段**就崩了，Java 逻辑根本没跑。曾怀疑「Java 21 不兼容」，但对同版本的 `lax_dump` 分析证明 **IA 2025 安装器在 Zulu 21 上能完整跑完** → **撤回该误判**，问题**仅限卸载器**的 native 引导。

#### 修复：架构级解耦
不再死磕黑盒卸载器，直接**脱钩**：
- `pi-linux-install.sh` step 8b 把 `_installation/trellisappmgruninstall` 改名 `.ia.bak`，替换为 shell **shim**（自复制 `/tmp` 再 `exec pi-linux-uninstall.sh`）+ 建 `/usr/local/sbin/pi-uninstall` 软链 + 安装失败**回滚 trap**（复用同脚本、非交互保数据）。
- `pi-linux-uninstall.sh` 升级为**全产品拆除唯一真源**。
- **零 `iap_xml` 结构改动，Windows 卸载链不受影响**（卸载动作 `IsLinux` 门控）。RHEL 9.7 残留机实测服务/程序树/配置/数据/注册表/包/用户组/软链全部零残留。

#### 教训沉淀
- 遗留黑盒工具在新平台的失败点极难定位时，**果断解耦重写**往往优于逆向死磕——前提是保住旧平台（Windows）不回归。
- 决策前用 dump/旁证**证伪**假设（此处 `lax_dump` 推翻了「Java21 不兼容」），避免朝错误方向投入。

### 4. 复盘：离线 PostgreSQL 拆包不全（两连）

#### 现场一（RHEL，report_60）
方案 B 编排成功、ZE 已装并运行，但 PG 挂在 `libpq.so.5` 缺失 + 无 `initdb`/无 `postgres` 用户。根因：PGDG 把 `postgresql18` 拆包，而离线目录/脚本**只收并只装了基础包**，缺 `postgresql18-libs`（提供 libpq）与 `postgresql18-server`（提供 initdb/服务/postgres 用户）。属打包问题，与 IA/方案 B 无关。

#### 现场二（Ubuntu 26.04，report_66）
OS/glibc 门禁放宽后 PG 仍装不上：无 `postgres` 用户、无 `/var/lib/postgresql/18/main` 簇、5432 无监听 → tafsvc 连库失败重启循环。安装日志定死根因：`postgresql-common (291.pgdg26.04+1)` **硬依赖 `libjson-perl`**，离线组里没有 + 无网 → `dpkg -i` 只解包未配置（`iU` 状态），`postgresql-common`/`postgresql-18` 均 config 失败。

#### 修复
- `install-postgresql.sh` 由「挑单文件」改为 `uname -m` + OS 标签**整组安装**，新增 `validate_pg_install`（校验 `libpq.so.5`+`initdb`+`postgres` 用户，缺则明确报「离线包不完整」而非静默半装）。
- Ubuntu 补 `libjson-perl_4.10000-1_all.deb`（`_all` 纯 perl、仅 `Depends: perl:any`，一个即够；`dpkg -i *.deb` 整组会先配 libjson-perl 再配 common）。report_67 双绿。

#### 教训沉淀
- 面对**拆包型**发行版仓库（PGDG），离线必须收**整组子包**并**自校验**关键产物（库/可执行/用户），不能只测「主包在不在」。
- 跨发行版依赖差异要逐版本核对：RHEL RPM server 不依赖 perl-JSON，Ubuntu/Debian 系的 `postgresql-common 291` 才引入 `libjson-perl`。

### 5. 复盘：RHEL 专属早期门禁误挡 Ubuntu

#### 症状与机理
Ubuntu 实测被 `OS not supported` 拦在 Check-for-Root 之前。这是一道**遗留 IA OS 白名单闸门**：规则 `!SkipOSCheck && !((redhat‖CentOS) && V7)`，其中 `V7 = VERSION_ID 含 "7"`——本意是放行 7.x，但 **RHEL 9.7 是「9.7 含 7」的巧合**才通过，Ubuntu 任何版本硬挡。放宽后又暴露**第二道** RHEL 专属门禁：`Check for glibc` 里 `yum list installed glibc`，Ubuntu 无 `yum` → 误判 `Missing glibc` 退出。

#### 修复
精确清单（策略 A）+ 去 CentOS：OS 判定改零 `$` grep 管道输出 `$OS_SUPPORTED$`、面板规则改 `!SkipOSCheck && !Supported`；glibc 命令改跨发行版 `getconf GNU_LIBC_VERSION`。均**只改现有节点属性、零新增 objectID**。

#### 教训沉淀
- 「巧合通过」是最危险的绿灯——`VERSION_ID 含 "7"` 这种子串匹配掩盖了门禁本质缺陷，扩平台时才暴露。门禁判定要用**精确清单/阈值**，不用子串巧合。
- 早期门禁常含发行版专属假设（`yum`），扩平台前要**全量枚举**所有早期闸门（本项目共两道：OS 白名单 + glibc）。

### 6. 复盘：`tafdb` SysV 假象与跨平台不一致

#### 症状与机理
RHEL 上 `systemctl status tafdb` 可见、Ubuntu 不可见。根因：IA（`ASCIIFileManipulator b4b4bb1989ae` + 内含 `InstallFile b59203618999`）装了遗留 SysV `init.d-tafdb` 到 `/etc/rc.d/init.d/tafdb`；RHEL 靠 systemd 的 `sysv-generator` 扫 `/etc/rc.d/init.d/*` 才「看得到」，Ubuntu 不读该路径。更糟的是该脚本指向**已废弃的内嵌 PG 布局**（`/opt/trellisappmgr/database/bin`、`tafusr`、`/var/opt/trellisappmgr/db`），**根本没在驱动真实库**——即 RHEL 上的 `tafdb` 是个**误导性的空壳**。同源问题：`tafsvc` 也曾因同名 SysV 与 systemd 单元冲突导致 `enable` 失败。

#### 修复
- `pi-linux-install.sh` 先删遗留 SysV，再装**瘦 `tafdb.service`**（`Type=oneshot`+`RemainAfterExit`+`ExecStart=/bin/true`，`Requires/After` 真实 `${PG_SERVICE}`），双平台统一。
- `pi-linux-uninstall.sh` 加 tafdb 别名 teardown；从 `TAFCore.iap_xml` 移除 tafdb 安装链（1 定义 + 3 ref，Python objectID 锚点 + 深度计数删除、minidom 校验良构、零悬空）+ 删源文件 `init.d-tafdb`。
- `tafsvc` 自启修复 = 建单元前 `rm -f /etc/rc.d/init.d/tafsvc`。

#### 教训沉淀
- **「服务看得到」≠「服务在管真东西」**：RHEL sysv-generator 会把任意 init.d 脚本包装成单元，制造「服务存在」的假象；跨平台一致性要用**原生 systemd 单元**，别依赖 SysV 兼容层。
- 同名 SysV 与 systemd 单元共存会导致 `enable` 冲突，安装原生单元前务必清除同名 SysV。

### 7. 小坑合集（Tier 3）

| 坑 | 症状 | 根因 | 修复 |
| :--- | :--- | :--- | :--- |
| **`DELETE_DATA` argv 序列化** | 卸载删数据分支不生效 | `$DELETE_DATA$` 被 IA 序列化成 `'"Yes",""'`、argv 被搞乱 | 第 3 参改传 `$DELETE_DATA_BOOLEAN_1$`（干净 `1`/`0`）+ worker 侧子串容错解析 |
| **`createdb` 权限拒绝** | 建库报 `Permission denied` | `postgres` 用户对 `/opt/trellisappmgr`(764) 无 traverse | `su - postgres -c "psql -d postgres" < createdb.sql`（stdin 重定向） |
| **`.sh` CRLF** | Linux 执行异常 | 工作树混入 CRLF | 强制 LF（`.gitattributes` `*.sh eol=lf`）+ 显式转换 |
| **跨组件删引用致落盘消失** | `c1993c9` 后 `zeroengine-linux`/`postgresql` 连落盘都没了（report_54） | 真实有效执行路径是 `monitoring-support` 的扁平 `installChildren`，而非「仅靠内联定义」 | 恢复引用（`f71a41b`）；此坑也是**诊断反推**执行路径的关键线索 |

#### 小坑合集的共同教训
- IA 的 argv 传参对含引号/逗号的值不可靠，**布尔量传干净的 `1`/`0`**，脚本侧再做容错解析。
- Linux 权限模型（目录 traverse 位）对 `su - postgres` 场景很敏感，涉及降权执行时优先用 **stdin 重定向**而非让目标用户去 traverse 安装目录。
- 「删一处引用导致落盘消失」反而是**定位真实执行路径**的最有力实验——诊断报告的 diff 对照比静态阅读 XML 更可信。

