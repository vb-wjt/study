# 事后分析：CMD 延迟展开导致删除 C 盘事件

> **事件日期**：2026-06-02  
> **严重程度**：P0 — 生产环境数据损毁级别  
> **影响范围**：开发机 Windows C 盘被 `rmdir /s /q "\"` 部分递归删除  
> **根因类别**：AI 生成代码 + CMD shell 语义陷阱 + 验证盲区  
> **关联文档**：  
> - 回望时间线：[`retrospectives/ai-installanywhere-collaboration.md` §七](../4-methodology/ai-collaboration-retrospective.md)  
> - 修复 commit：`bb7ad1b`  
> - 安全审计脚本：**`scripts/verify-destructive-commands.ps1`**（内部真源，不随本目录）

---

## 一、事件概述

在 PI 安装器的 Zero Engine 服务链集成过程中，AI 助手为解决 "IA 变量替换引擎误解析 PowerShell `$nested` 变量" 的问题，将 JRE 解压脚本从 PowerShell 改为 CMD 批处理。改动引入了 CMD 延迟展开（Delayed Expansion）的经典陷阱，导致 `rmdir /s /q "\"` 在安装器以管理员权限运行时递归删除了目标 Windows 机器的 C 盘内容。

---

## 二、触发链路

### 2.1 问题背景

InstallAnywhere（IA）的 `ExecuteScript` 动作在 Windows 上通过 `cmd.exe` 执行脚本。IA 在将脚本传给 `cmd.exe` 之前，会先做自己的 `$VAR$` 变量替换。

Zero Engine 的 JRE 需要在安装后从 zip 解压并铺平子目录。最初使用 PowerShell 的 `$nested` 临时变量来引用解压后的子目录路径，但 IA 的变量引擎把 `$nested` 也当作 `$xxx$` 模式进行了替换，导致 JRE 解压失败。

### 2.2 AI 的修复（引入 bug 的 commit `4824a36`）

AI 将 PowerShell 逻辑改为 CMD 批处理，使用 `set` + `%var%` 来避免 IA 对 `$nested` 的误替换：

```batch
if "%OS%"=="Windows_NT" (
  set "JREDIR=$USER_INSTALL_DIR$\zeroengine\jre"
  set "ZIPNAME=zulu21.44.17-ca-jre21.0.8-win_x64"
  if not exist "%JREDIR%\bin\java.exe" (
    powershell -NoProfile -Command "Expand-Archive -Path '%JREDIR%\%ZIPNAME%.zip' ..."
    if exist "%JREDIR%\%ZIPNAME%" (
      xcopy /E /I /Y "%JREDIR%\%ZIPNAME%\*" "%JREDIR%"
      rmdir /s /q "%JREDIR%\%ZIPNAME%"
    )
  )
  ...
)
```

### 2.3 CMD 延迟展开陷阱

CMD 的 `( ... )` 复合语句有一个鲜为人知但致命的行为：

> **`%VAR%` 在整个 `( ... )` 块被解析时一次性展开，而不是在每行执行时逐行展开。**

这意味着：

| 步骤 | 代码 | 实际效果 |
|------|------|----------|
| 解析阶段 | `%JREDIR%` / `%ZIPNAME%` | 环境中不存在 → 展开为**空字符串** |
| 执行 set | `set "JREDIR=E:\...\jre"` | 成功设置，但为时已晚 |
| 执行 if | `if not exist "\bin\java.exe"` | 空路径 + `\bin\java.exe` → TRUE |
| 执行 if exist | `if exist "\"` | 根目录永远存在 → TRUE |
| **执行 rmdir** | **`rmdir /s /q "\"`** | **递归删除当前盘符根目录** |

### 2.4 为什么后果是灾难性的

- IA 安装器以**管理员权限**运行
- 安装器工作目录通常在 **C: 盘**
- `rmdir /s /q "\"` 等效于 `rmdir /s /q "C:\"`
- `/s` = 递归，`/q` = 不提示确认
- Windows 无法保护所有系统文件，大量用户数据、程序文件被删除

---

## 三、为什么没有被拦截

### 3.1 静态验证不覆盖运行时语义

改动后做了 XML parse 验证和全文搜索，但这些只能检查**结构正确性**，不能检测 **CMD 运行时的变量展开行为**。

### 3.2 AI 不了解 CMD/IA 的交叉边界

AI（Cursor）擅长代码生成和模式匹配，但：
- 不了解 CMD `( ... )` 块的解析时展开规则
- 不了解 IA `ExecuteScript` 通过 `cmd.exe` 执行的具体行为
- 不了解 IA 的 `$VAR$` 替换发生在 CMD 解析之前

这是一个**多层 shell 语义**问题（IA 变量层 + CMD 解析层 + CMD 执行层），AI 在单一层面上的推理是正确的（用 CMD 变量避免 IA 替换），但忽略了层间交互。

### 3.3 没有针对破坏性命令的专项检查

改动中包含 `rmdir /s /q`，但没有审计机制来验证其目标路径在所有可能的变量展开场景下是否安全。

---

## 四、修复措施

### 4.1 即时修复（commit `bb7ad1b`）

- **去掉所有 CMD 环境变量**（`set` + `%var%`），完全使用 IA 变量 `$USER_INSTALL_DIR$`
- **使用 IA 路径分隔符 `$\$`**（不是裸 `\`），与 IA Designer 创建的脚本模式一致
- **保留 CMD xcopy/rmdir**（不使用 PowerShell `$nested`），避免 IA 的 `$var$` 替换冲突

修复后的路径：

```
改前：rmdir /s /q "%JREDIR%\%ZIPNAME%"      → 展开为 rmdir /s /q "\"
改后：rmdir /s /q "$USER_INSTALL_DIR$$\$zeroengine$\$jre$\$zulu21...x64"
                                               → 展开为 rmdir /s /q "E:\...\zulu21...x64"
```

### 4.2 持久化防护（`scripts/verify-destructive-commands.ps1`）

新增的安全审计脚本在每次 `TAFCore.iap_xml` 改动后运行，检查：

| 检查项 | 级别 | 说明 |
|--------|------|------|
| CMD `%var%` 在 `( )` 块内 | CRITICAL | 延迟展开导致变量为空 |
| 破坏性命令路径为空/根路径 | CRITICAL | `rmdir /s /q ""` 或 `rmdir /s /q "\"` |
| 破坏性命令缺少 `if exist` 守卫 | HIGH | 无条件删除 |
| PowerShell `$xxx` 可能被 IA 误替换 | HIGH | IA 变量冲突 |
| 路径使用裸 `\` 而非 IA `$\$` | MEDIUM | 与 IA 既定模式不一致 |
| `substituteUnknownVariable=true` | HIGH | 未知变量被替换为空 |

---

## 五、根因分析

```
IA 剥离新增 objectID → 10+ 次构建失败
    ↓ 修复：复用已有 ExecuteScript，用 PowerShell 处理 JRE
PowerShell $nested 被 IA 的 $var$ 引擎误替换 → JRE 解压失败
    ↓ 修复：改用 CMD set + %var%
CMD 延迟展开陷阱 → %var% 在 ( ) 块内为空 → rmdir /s /q "\"
    ↓ 后果：删除 C 盘内容
```

**深层根因**：不是某个单一错误，而是三个系统的边界交互叠加：

1. **IA 的隐式行为**（静默剥离 objectID）迫使开发方式偏离正轨
2. **IA 的变量替换引擎**（全文 `$xxx$` 匹配）与 PowerShell 语法冲突
3. **CMD 的延迟展开规则**（`%var%` 解析时展开）与直觉相悖

每一步的局部推理都是合理的，但组合起来产生了灾难性后果。

---

## 六、教训与规则

### 6.1 IA ExecuteScript 中的绝对禁区

| 禁止 | 替代方案 | 原因 |
|------|----------|------|
| CMD `set` + `%var%` | 直接使用 IA `$VAR$` | CMD 延迟展开在 `( )` 块内使变量为空 |
| PowerShell `$xxx` 临时变量 | CMD xcopy/rmdir 处理 | IA 的 `$xxx$` 匹配会误替换 |
| 裸 `\` 拼接路径 | IA `$\$` 或 `$/$` 分隔符 | 与 IA Designer 既定模式保持一致 |
| 新增 objectID | 修改已有对象的属性 | IA Builder 静默剥离文本新增的 objectID |

### 6.2 AI 协作中的安全检查清单

每当 AI 生成涉及**文件系统操作**（删除、移动、覆盖）的代码时，人类审查者应逐项确认：

- [ ] **路径参数在所有可能的展开场景下是否安全**？（空值、未定义、特殊字符）
- [ ] **是否有 `if exist` 或等价守卫**？
- [ ] **是否涉及多层 shell/引擎**？（IA 变量层 → CMD 解析层 → CMD 执行层）
- [ ] **每一层的变量展开时机是否正确**？（解析时 vs 执行时）
- [ ] **安全审计脚本是否覆盖了这个命令**？（运行 `verify-destructive-commands.ps1`）

### 6.3 对 AI 辅助开发的更广泛建议

1. **AI 擅长单层推理，但多层交互是盲区**。当代码跨越多个执行环境（IA → CMD → PowerShell）时，人类需要特别审查层间边界。

2. **AI 生成的"修复"可能引入比原问题更严重的新问题**。每次修复后，不仅要验证修复是否生效，还要验证修复本身是否安全。

3. **破坏性命令（`rm -rf`、`rmdir /s /q`、`del /s`）应该有自动化审计**。不能依赖人工审查来发现空路径展开——这种 bug 对人眼来说几乎不可见。

4. **"编译通过 + 静态检查通过" 不等于安全**。涉及运行时行为的代码（特别是 shell 脚本中的变量展开）需要更深层的语义验证。

5. **在安装器/部署脚本中，错误的代价远高于普通应用**。安装器以管理员权限运行，一行错误命令就可能造成不可逆损害。应当建立比常规代码更严格的审查标准。

---

## 七、时间线速查

| 日期 | Build | 事件 |
|------|-------|------|
| 05-26~05-29 | 4–14 | 新增 objectID 方案，全部被 IA Builder 剥离 |
| 05-29~06-01 | 15–22 | 各种挂载策略，仍被剥离 |
| 06-01 | 23 | 方案 B：复用已有 ExecuteScript。首次执行成功，发现 `$nested` 问题 |
| **06-01** | **24** | **修复 `$nested`，引入 CMD 延迟展开 → 删除 C 盘** |
| 06-02 | — | 分析根因，修复为 IA `$\$` 路径分隔符，新增安全审计脚本 |
| 06-03 | 25 | 验证 ZE JRE/ZESvc 正常，修复 TAFsvc 启动 + ZE 卸载链 |

---

## 八、相关资源

- 修复 commit：`bb7ad1b` — `fix: replace cmd %var% with IA $\$ path separators to prevent catastrophic rmdir`
- 安全审计脚本：`taf-core-installer/scripts/verify-destructive-commands.ps1`
- AI 协作回望完整版：[`docs/retrospectives/ai-installanywhere-collaboration.md`](../4-methodology/ai-collaboration-retrospective.md)
- CMD 延迟展开详解：[`docs/links/cmd-delayed-expansion.md`](../1-foundations/cmd-delayed-expansion.md) — 两阶段解析模型、经典陷阱复现、`setlocal enabledelayedexpansion` 用法与注意事项
- CMD 延迟展开官方文档：[Microsoft `cmd /V`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cmd)
- IA ExecuteScript 文档：InstallAnywhere 2025 Help — "Execute Script" action
