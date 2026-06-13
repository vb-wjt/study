# PostgreSQL 迁移与安装器重构：开发、架构与测试交付指南

> **最后更新**：2026-06-13  
> **文档用途**：指导开发与架构师理解 Vertiv PI Windows 安装器从「MongoDB + IE Engine」向「PostgreSQL 18.4 + Zero Engine + SQLite」架构演进后的系统拓扑、服务生命周期契约与配置收敛逻辑；同时为 QA 团队提供详尽的全新安装、异常回滚、卸载残留及多语言验证的测试场景与用例，作为项目交付的质量保障标准。

---

## 一、 架构演进与拓扑对比 (As-Is vs To-Be)

在本次重构中，Vertiv PI 进行了彻底的数据底座替换与采集引擎升级：
1. **数据库迁移**：从 MongoDB 4.4 彻底切换为 PostgreSQL 18.4。
2. **采集引擎升级**：从旧版闭源 C++ 编写的 Intelligent Engine (IE Engine) 彻底升级为现代轻量级的 Java 21 伴生采集引擎 Zero Engine (ZE)。
3. **伴生数据隔离**：纠正了以往关于 ZE 共享主库的误区，**Zero Engine 运行在独立的 SQLite 3 数据库上**，实现了物理级的数据隔离，仅通过内部 HTTP API 与 MTP Core 进行通信。

### 1. 部署拓扑与架构变化对比

```
[ 改造前 (As-Is)：MongoDB + IE Engine 拓扑 ]
+-----------------------------------------------------------------------------+
|  Windows Server 运行环境                                                    |
|                                                                             |
|   +------------------+             +------------------------------------+   |
|   |  TAFsvc (JSL)    | ----------> |  TAFdb (MongoDB 进程)              |   |
|   |  (MTP Core 21)   |  TCP 27017  |  (直接静态打包落盘)                |   |
|   +------------------+             +------------------------------------+   |
|            |                                                                |
|            | 内部调用 (TCP 4440)                                            |
|            v                                                                |
|   +---------------------------------------------------------------------+   |
|   |  IE Engine 5个 Windows 服务 (C++ 进程)                              |   |
|   |  (iesnmptrapd, ieelfsrvmanager, ieexportersrv, ieeventsrv, iemss)   |   |
|   +---------------------------------------------------------------------+   |
+-----------------------------------------------------------------------------+

[ 改造后 (To-Be)：PostgreSQL 18.4 + Zero Engine + SQLite 拓扑 ]
+-----------------------------------------------------------------------------+
|  Windows Server 运行环境                                                    |
|                                                                             |
|   +------------------+             +------------------------------------+   |
|   |  TAFsvc (JSL)    | ----------> |  TAFdb (PostgreSQL 进程)           |   |
|   |  (MTP Core 21)   |  TCP 5432   |  (动态 Zip 解压/平滑部署)          |   |
|   +------------------+             +------------------------------------+   |
|            |                                                                |
|            | 内部通信 (HTTP API, TCP 8088)                                  |
|            v                                                                |
|   +------------------+             +------------------------------------+   |
|   |  ZESvc (JSL)     | ----------> |  SQLite 数据库 (文件隔离)          |   |
|   |  (Zero Engine 21)| 本地文件读写|  (zero_engine.db)                  |   |
|   +------------------+             +------------------------------------+   |
+-----------------------------------------------------------------------------+
```

### 2. 关键核心参数对照表

| 维度 | 改造前 (As-Is: MongoDB + IE) | 改造后 (To-Be: PostgreSQL + ZE) |
| :--- | :--- | :--- |
| **主数据库** | MongoDB (端口 `27017`) | PostgreSQL 18.4 (端口 `5432`) |
| **主数据库服务名** | `TAFdb` | `TAFdb` (服务名保持一致，确保平滑过渡) |
| **伴生/集成引擎** | IE Engine (端口 `4440`) | Zero Engine (端口 `8088`) |
| **伴生引擎数据库** | 无独立数据库，依赖主系统或内存。 | **SQLite 3** (物理文件 `zero_engine.db`，完全隔离) |
| **伴生服务化形态** | 5 个独立 Windows 服务 (无 JSL 包装) | Zero Engine 通过 JSL 包装，注册为独立的 **`ZESvc`** 服务 |
| **打包与释放方式** | 静态打包：IA 静态编译 `bin` 目录，安装时直接落盘。 | 动态解压：完整 Zip 介质落盘后，安装期通过 `tar.exe` 动态解压并平滑展平。 |
| **账号体系契约** | 无 Windows 级权限隔离，单进程运行。 | **双用户隔离**：管理员 `mtpadmin`（初始化与建库）与普通用户 `mtpuser`（应用运行）。 |
| **客户端认证配置** | 默认免密/内部认证。 | `pg_hba.conf` 强控制：仅允许本地绑定 IP（如 `127.0.0.1` / `::1`）进行 MD5 密码认证。 |

---

## 二、 服务生命周期契约 (Lifecycle Contract)

在 Windows 运行环境下，系统服务由繁入简。改造前后的服务列表、依赖关系与启停顺序发生了根本性变化。

### 1. 改造前后的服务列表对比

*   **改造前服务列表**：
    *   数据库服务：`TAFdb` (MongoDB)
    *   MTP Core 服务：`TAFsvc` (MTP Core)
    *   IE Engine 服务（Windows，共 5 个）：
        *   `iesnmptrapd` (SNMP Trap 接收服务)
        *   `ieelfsrvmanager` (元素库管理服务)
        *   `ieexportersrv` (数据导出服务)
        *   `ieeventsrv` (事件处理服务)
        *   `iemssenginesrv` (主采集引擎服务)
    *   IE Engine 服务（Linux）：`mss-engine`
*   **改造后服务列表**：
    *   数据库服务：`TAFdb` (PostgreSQL 18.4)
    *   Zero Engine 服务：`ZESvc` (Zero Engine)
    *   MTP Core 服务：`TAFsvc` (MTP Core)

### 2. 服务启动顺序对比

```
[ 改造前启动顺序 ]
Step 1: TAFdb (MongoDB) ──> Step 2: 启动 5 个 IE 服务 (iesnmptrapd 等) ──> Step 3: TAFsvc (MTP Core)

[ 改造后启动顺序 ]
Step 1: TAFdb (PostgreSQL) ──(启动成功)──> Step 2: ZESvc (Zero Engine) ──(启动成功)──> Step 3: TAFsvc (MTP Core)
```

1. **`TAFdb` 优先启动**：作为数据底座，`TAFdb` 必须最先就绪。其在 Windows 服务控制管理器 (SCM) 中的启动类型为 `Automatic`。
2. **`ZESvc` 随后启动**：Zero Engine 依赖本地 SQLite 数据库，不依赖 PostgreSQL 启动，但为了保证 MTP Core 启动时能够顺利建立与 ZE 的 API 握手，其启动类型为 `Automatic`。安装器在注册表写入的基础上，追加了双保险命令：
   ```cmd
   sc config ZESvc start= auto
   ```
3. **`TAFsvc` 最后启动**：MTP Core 依赖 `TAFdb` 进行业务数据读写，同时与 `ZESvc` 进行内部通信。其在 SCM 中被配置为**显式依赖 `TAFdb`**（通过 `TAFsvc.ini` 中的 `dependencies=TAFdb` 契约约束）。

### 3. 停止与注销顺序 (卸载/回滚场景)

```
[ 改造前停止顺序 ]
Step 1: TAFsvc (MTP Core) ──> Step 2: 停止 5 个 IE 服务 ──> Step 3: TAFdb (MongoDB)

[ 改造后停止顺序 ]
Step 1: TAFsvc (MTP Core) ──(停止并解锁)──> Step 2: ZESvc (Zero Engine) ──(停止并解锁)──> Step 3: TAFdb (PostgreSQL)
```

*   在卸载或安装失败触发回滚时，必须**逆序**停止服务。
*   **关键点**：`TAFsvc` 和 `ZESvc` 在运行期间会锁定其各自目录下的 JAR、WAR 以及 JRE 文件。必须先向 SCM 发送停止信号并确保进程完全退出，才能进行文件和目录的物理删除，否则会导致“文件被占用”的删除失败残留。

---

## 三、 工作流程与安装界面变化 (As-Is vs To-Be)

### 1. 后台执行流程对比

```
[ 改造前后台流程 ]
1. 静态释放 MongoDB 编译后的 bin 目录文件。
2. 运行 "mongod.exe --install" 注册 TAFdb 服务。
3. 释放 ie_installer 目录，通过 IETemp 批处理脚本配置并注册 5 个 IE 服务。
4. 注册 TAFsvc 服务。

[ 改造后后台流程 ]
1. 启动时静默检查系统内置的 tar.exe 是否存在（Fail-Fast 门禁）。
2. 释放 pgsql.zip 并通过 tar.exe 动态解压平滑部署至 database 目录。
3. 初始化 PG 并应用 pg_hba.conf 本地 MD5 强认证。
4. 释放 zeroengine 介质，用 unzip.exe 解压其内置的 JRE 21。
5. 复制 jsl64.exe 为 ZESvc.exe，并运行 "ZESvc.exe -install" 注册服务。
6. 追加 "sc config ZESvc start= auto" 确保自启。
7. 注册 TAFsvc 服务。
```

### 2. 安装界面与步骤变化对比

| 界面步骤 | 改造前 (As-Is) | 改造后 (To-Be) |
| :--- | :--- | :--- |
| **前置检查界面** | 仅检查系统位数与基础 JRE。 | **新增：内置 `tar.exe` 兼容性检查**，若缺失则拦截并提示。 |
| **数据库配置界面** | 1. 数据库端口输入框（默认 `27017`）。<br>2. **无密码输入框**（MongoDB 默认免密）。 | 1. 数据库端口输入框（默认 `5432`）。<br>2. **新增：管理员 `mtpadmin` 密码输入框**。<br>3. **新增：普通用户 `mtpuser` 密码输入框**。 |
| **采集引擎配置界面**| **包含 IE 端口配置输入框**（默认 `4440`）。 | 1. **移除 IE 端口配置**。<br>2. **新增：Zero Engine 端口配置输入框**（默认 `8088`）。 |

---

## 四、 配置管理收敛 (Configuration Convergence)

在先前的版本中，安装器使用 InstallAnywhere 的 `ASCIIFileManipulator` 动作在安装期向 `application.properties` 动态拼接并追加配置属性。这种方式存在严重的维护痛点：
1. **多语言 (Locale) 冲突**：IA 的多语言本地化属性文件（如 `custom_zh_CN`、`custom_en`）会强制覆盖 `ASCIIFileManipulator` 的 `additionalText` 属性。一旦漏掉某国语言的同步修改，该语言系统下安装时就会丢失动态写入的配置。
2. **文件大小校验失效**：IA 在打包时会静态记录文件大小，动态修改文件内容会导致卸载或校验时因“文件大小不匹配”而报错。

### 1. 收敛方案：静态注入与 Locale 清理

为了彻底解决此问题，我们实施了**配置管理收敛重构**：
*   **静态注入默认值**：将 Zero Engine 和 TAF 服务的默认地址配置直接硬编码写入 `application.properties` 模板文件中，不再依赖安装期动态拼接：
  ```properties
  # Zero Engine / TAF service defaults
  zero.engine.service.address=localhost
  taf.service.address=localhost
  taf-plugin-monitoring.defaultEngineType=zeroEngine
  ```
*   **彻底清理动态动作**：清空了 `TAFCore.iap_xml` 中 `ASCIIFileManipulator`（objectID `f2b071bc983a`）的 `additionalText` 属性。
*   **同步清理多语言文件**：在 `custom_zh_CN` 和 `custom_en` 本地化属性文件中，同步将该动作的追加文本字段清空，彻底消除了 Locale 覆盖隐患：
  ```properties
  ASCIIFileManipulator.f2b071bc983a.additionalText=
  ```
*   **动态属性自适应**：对于必须根据用户输入动态变化的属性（如 `application-$PROFILE$.properties`），在 IA 中将其 `fileSize` 属性显式设置为 `-1`，指示编译器在安装期动态计算大小，规避校验冲突。

---

## 五、 质量保障与测试交付标准 (QA Test Suite)

为确保重构后的安装器在各种极端和边界条件下均能稳定运行，QA 团队应严格执行以下四大核心测试场景。

### 场景一：全新安装测试 (Clean Install)

#### 测试目的
验证在干净的 Windows 操作系统上，安装器能否顺利完成前置检查、动态解压、初始化建库、配置注入及服务自启。

#### 测试步骤与验证矩阵

| 步骤 | 操作内容 | 预期结果 (验证标准) | 验证方法 / 命令 |
| :--- | :--- | :--- | :--- |
| **1.1** | **前置兼容性检查** | 安装器启动时，静默检测系统是否内置 `tar.exe`。 | 若系统无 `tar.exe`，应弹出“系统兼容性检查失败”提示框并干净终止。 | 检查安装日志，或在无 `tar.exe` 的干净 Win Server 2016 上测试。 |
| **1.2** | **PG 介质平滑解压** | 安装器将 PostgreSQL 压缩包释放并动态解压到 `database` 目录。 | 解压过程无静默崩溃，`database` 目录下包含完整的 `bin`、`share`、`lib` 等目录。 | 检查安装后 `database` 目录结构是否完整，无缺失文件。 |
| **1.3** | **混合路径解压验证** | 验证解压脚本中的路径变量未被 IA 误解析。 | 解压命令中的 `binaries`、`share` 等字面量文件夹未被替换为 `bin` 或空值。 | 检查安装日志，确保无 `tar` 找不到路径的错误。 |
| **1.4** | **初始化建库与认证** | 自动执行 `initdb` 并将 `pg_hba.conf` 部署至数据目录。 | 数据目录 `db` 下成功生成 `pg_hba.conf`，且内容限制为本地 MD5 认证。 | 读取 `$USER_MAGIC_FOLDER_2$\db\pg_hba.conf` 确认内容。 |
| **1.5** | **服务注册与自启** | 注册 `TAFdb`、`ZESvc`、`TAFsvc` 服务并拉起。 | 三个服务均成功注册，状态为 `Running`，启动类型为 `Automatic`。 | PowerShell: `Get-Service TAFdb, ZESvc, TAFsvc` |
| **1.6** | **应用可用性验证** | 访问系统门户及 Zero Engine 接口。 | 页面加载正常，Zero Engine 8088 端口正常监听，且使用 SQLite 数据库。 | 执行 `netstat -ano \| findstr 8088`，并确认 `zeroengine/database/zero_engine.db` 文件生成。 |

---

### 场景二：异常与回滚测试 (Rollback on Failure)

#### 测试目的
验证在安装中途因各种原因（如数据库校验失败、用户主动取消、系统断电模拟）导致安装中断时，安装器能否干净地回滚，不留任何锁定的服务、进程和残留文件。

#### 测试步骤与验证矩阵

| 步骤 | 操作内容 | 预期结果 (验证标准) | 验证方法 / 命令 |
| :--- | :--- | :--- | :--- |
| **2.1** | **中途取消触发回滚** | 在安装进度条达到 80%（正在启动服务或执行建库）时，点击“取消”按钮。 | 安装器立即停止后续动作，启动回滚清理程序。 | 观察安装界面交互。 |
| **2.2** | **服务优雅停止与注销** | 回滚程序向 SCM 发送停止并删除 `ZESvc`、`TAFdb` 的信号。 | `ZESvc` 和 `TAFdb` 服务被成功停止，且在 SCM 中被彻底注销（不留 `Disabled` 状态）。 | PowerShell: `Get-Service ZESvc, TAFdb` 报告服务不存在。 |
| **2.3** | **进程无锁定清理** | 检查相关 Java 进程和数据库进程是否完全退出。 | `ZESvc.exe`、`postgres.exe` 进程完全退出，无句柄锁定。 | 任务管理器或 `tasklist \| findstr "postgres ZESvc"` |
| **2.4** | **残留目录彻底擦除** | 物理删除 `zeroengine` 和 `database` 目录。 | 安装路径下的 `zeroengine` 目录和 `database` 目录被 100% 干净删除，无任何文件残留。 | 检查安装目标路径，确保无残留文件夹。 |

---

### 场景三：卸载残留测试 (Uninstall Cleanup)

#### 测试目的
验证用户通过控制面板或卸载快捷方式手动卸载系统时，卸载器能否实现“零残留”交付。

#### 测试步骤与验证矩阵

| 步骤 | 操作内容 | 预期结果 (验证标准) | 验证方法 / 命令 |
| :--- | :--- | :--- | :--- |
| **3.1** | **执行标准卸载** | 运行 `$USER_INSTALL_DIR$\_installation\Change PowerInsight Installation.exe` 执行完全卸载。 | 卸载向导顺利执行完毕，无任何报错弹窗。 | 观察卸载向导界面。 |
| **3.2** | **服务彻底注销** | 检查 `TAFsvc`、`ZESvc`、`TAFdb` 在 Windows 服务列表中的状态。 | 三个服务在 SCM 中完全消失，不保留任何“标记为删除”或“已禁用”的僵尸服务。 | 打开 `services.msc` 刷新查看。 |
| **3.3** | **注册表干净擦除** | 检查安装器写入的注册表项。 | `HKLM\SYSTEM\CurrentControlSet\Services\` 下的 `TAFsvc`、`ZESvc`、`TAFdb` 注册表键值被完全删除。 | 运行 `reg query` 检查对应路径。 |
| **3.4** | **物理文件零残留** | 检查安装根目录。 | 除用户数据目录外，安装根目录及下属的 `zeroengine`、`database`、`jre` 目录被完全物理删除。 | 检查物理磁盘路径。 |

---

### 场景四：多语言环境测试 (Locale Testing)

#### 测试目的
验证在不同语言（中文、英文）的操作系统及安装语言选择下，配置文件的生成、字符集编码以及服务运行是否完全一致，消除 Locale 覆盖隐患。

#### 测试步骤与验证矩阵

| 步骤 | 操作内容 | 预期结果 (验证标准) | 验证方法 / 命令 |
| :--- | :--- | :--- | :--- |
| **4.1** | **英文系统+英文安装** | 在纯英文 Windows Server 操作系统上，选择 English 语言进行安装。 | 安装顺利完成，`application.properties` 字符编码正确，无乱码，ZE 静态配置成功注入。 | 读取配置文件，验证 `zero.engine.service.address=localhost` 存在。 |
| **4.2** | **中文系统+中文安装** | 在纯中文 Windows 操作系统上，选择 简体中文 语言进行安装。 | 安装顺利完成，配置文件中无任何因 Locale 覆盖导致的格式错乱，服务正常拉起。 | 检查服务状态与配置文件完整性。 |
| **4.3** | **多语言配置一致性对照** | 对比中英文安装产出的 `application.properties` 文件。 | 两个环境下的配置文件属性完全一致，文件大小校验无报错。 | 使用文件对比工具（如 `fc` 或 `diff`）进行静态比对。 |

---

## 六、 交付质量红线 (Quality Gates)

在将安装器交付给最终客户前，必须 100% 满足以下质量红线：
1. **安全红线**：工作空间内所有脚本必须通过 `verify-destructive-commands.ps1` 静态安全审计，**不允许存在任何未受保护的 `rmdir /s /q` 或 `rm -rf` 路径变量**。
2. **Fail-Fast 红线**：在不支持 `tar.exe` 的旧版本 Windows 系统（如 Windows Server 2012 R2 及以下）上，安装器必须在**启动阶段拦截并友好提示退出**，绝对不允许在中途解压失败导致系统处于半安装的尴尬状态。
3. **残留红线**：无论是安装回滚还是手动卸载，**`zeroengine` 和 `database` 目录下的所有可执行文件、JAR 包、JRE 及 SQLite 数据库文件必须 100% 擦除**，服务注册表项 100% 清理。
