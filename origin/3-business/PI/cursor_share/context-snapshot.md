# 项目上下文快照

> **最后更新**：2026-05-27（build-6 无 ZE → IA v3：`InstallDirectory` 编入 zeroengine；待 build-7）  
> **用途**：新对话开始时先读此文件，快速恢复安装器专项上下文。  
> **工作空间**：`D:\cursor_workspace\pi-installer`

---

## 一、项目背景与决策

**pi-installer** 是个人工作空间，专门处理 Vertiv PI 的 **InstallAnywhere 安装器**相关任务，与 `refactor_pi`（ZE 运行时替换）分工明确。

| 决策 | 内容 |
|------|------|
| 工程名 | `pi-installer` |
| 源码位置（基线） | `D:\cursor_workspace\pi_origin`（可能落后于依赖升级） |
| **升级后源码** | `D:\cursor_workspace\cursor_out\copy`（依赖升级后的对照基准，2026-05-22 已用于校正文档） |
| 覆盖范围 | `taf-core-installer` + `trellis-automation-agent-installer` + `TAF-InstallerCustomCode` |
| ZE 打包 | PI 使用 `D:\idea_workspace\zero-engine-pi-installer`（Maven artifactId `zero-engine-pi-installer`）作为 ZE 打包工程；原 `zero-engine-installer` 仍保留给 SI 使用。PI ZE 包已收窄为 SQLite-only，并新增 Linux/Windows 双平台包；Windows 由 PI 安装器用 JSL 注册 `ZESvc` |
| 替换 IA | 独立子目录 `docs/replace-installanywhere/`，候选含 jpackage，**暂不展开分析** |
| Git | 不初始化（个人任务过程） |

**活跃任务方向**：
1. 从 PI 安装包移除 IE Engine 相关内容
2. 将 Zero Engine 打入安装包（形态待定）
3. 远期：评估 InstallAnywhere 替代方案

---

## 二、源码路径速查

| 组件 | pi_origin | cursor_out/copy（升级后） |
|------|-----------|---------------------------|
| PI 主安装器 | `taf-core-installer/` | 同左 |
| IA 主工程 | `src/main/TAFCore.iap_xml` | 另有快照 `TAFCore.iap_xml.2022.196` |
| 安装器版本（pom） | 旧基线 | `3.0.1-beta.2-SNAPSHOT` |
| 嵌入式 JRE | Zulu `8.90.0.19` | Zulu **`21`**（`jre.version`） |
| CustomCode 版本 | `1.12.3-SNAPSHOT` | **`1.12.4-SNAPSHOT`** |
| IE Maven | `ieinstaller:1.22.0` | 同左；依赖 classifier **`module`**，unpack 用 **`modwin`** |
| IE 安装脚本 | `installables/Unix/IETemp/*.sh` | 同左 |
| IE 解包目录 | `resources/binaries/ie_installer/` | 同左 |
| ZE Adapter 插件 zip | 无 | `taf-plugin-pi-zeadapter:1.1.0-SNAPSHOT`（Maven 依赖，非独立 ZE 引擎包） |
| Agent 安装器目录 | `trellis-automation-agent-installer/` | 同左 |
| Agent Maven artifactId | `vertiv-automation-agent-installer` | `2.5.2-SNAPSHOT` |
| Agent CustomCode JAR | 旧：`taf-installer-customcode.jar` | **`taf-automation-agent-installer-customcode.jar`** |
| PI 安装期 Java | `TAF-InstallerCustomCode/` | Java **21**，含 `com.avocent.ie.install.CheckPortsAvailableAction` |

---

## 三、IE 在安装器中的已知触点

- `pom.xml`：`taf-ieinstaller.version` + `ieinstaller`（`module` / unpack `modwin`）
- `TAFCore.iap_xml`：`Checking IE Port Availability`、`$IE_PORT$` 默认 **4440**、`taf-plugin-ieadapter.installer-engine-port=4440`
- 解压 `ie-functions`、`ie-installer-redhat-new.sh` 自 `resources/binaries/ie_installer/`
- Unix `IETemp/`：`install-ie-rh-taf-yum.sh`、`install-ie-rh-taf-rpms.sh`

详见 [`current-state/04-ie-engine-in-installer.md`](current-state/04-ie-engine-in-installer.md)。

**2026-05-25 Windows 安装回归发现**：
- 安装日志 `PowerInsight_安装_05_25_2026_08_40_57.log` 中大量 `UnsupportedClassVersionError`：`taf-installer-customcode.jar` 由 Java 21（class file 65）编译，但安装器运行 CustomCode 的 Java 只能识别到 Java 11（class file 55）。
- `TAF-InstallerCustomCode/pom.xml` 当前 `maven.compiler.source/target=21`；若继续使用当前 IA 运行时，应降到 11 或保证 IA 运行 CustomCode 的 VM 升到 21。
- 本次安装目录 `E:\software\PI3.0.1\main\jre\release` 实际为 Amazon Corretto 11.0.27，不是期望的 Java 21；`TAFsvc` 启动卡住需优先修正打包/VM pack。
- `taf-core-installer/pom.xml` 仅把 `com.zulu:zulu-jre:${jre.version}:*:vm` 复制到 `$IA_HOME/resource/installer_vms`；真正打包的 VM 由 `TAFCore.iap_xml` 的 build configuration 决定。2026-05-25 已把当前 `TAFCore.iap_xml` 中所有 build configuration 的 bundled VM 改为 `zulu-jre-21-win64.vm` / `zulu-jre-21-linux64.vm`。
- `src/main/resources/vm-packs` 当前未参与构建；2026-05-25 已移除 `pom.xml` 中指向该目录的旧 JRE8 `systemPath` 注释，并删除该目录下两个旧 JRE8 VM pack：`zulu8.90.0.19-ca-jre8.0.472-win_x64.vm`、`zulu8.90.0.19-ca-jre8.0.472-linux_x64.vm`。
- GitLab `build.txt` 明确确认：IA 2025 构建时找不到 `zulu-jre-8.90.0.19-win64.vm`，于是 Windows 包回退为 `AmazonCorretto11.0.27_Windows-x64.vm`；Linux 包回退为 `zulu-jre-17-linux64.vm`。
- Windows 服务查询只确认一个真实 `TAFsvc`（ServiceName），状态 `Start Pending`；服务重复现象需用 `Win32_Service` 的 `Name/DisplayName/PathName` 区分显示名重复或 UI 刷新问题。
- 卸载日志 `PowerInsight_卸载_05_25_2026_10_31_30.log` 显示 `TAFsvc.exe -remove` 和 `mongod.exe --remove -serviceName TAFdb` 返回成功，但卸载后 SCM 仍有 `TAFsvc`（`Start Pending` / `Disabled` / PID 26728）和 `TAFdb`（`Running` / `Disabled` / PID 30764）；需修正服务停止/删除后进程退出与重启前残留验证。
- 2026-05-25 已修复 Zero Engine 默认配置未写入 `application-prod.properties`：`ASCIIFileManipulator.f2b071bc983a` 定义存在但未挂到 install children，现已在 `TAFCore.iap_xml` 中加入 `<object refID="f2b071bc983a"/>`，位于 `application-$PROFILE$.properties` 安装与基础变量替换之后。

**2026-05-25/27 ZE PI installer 分析**：
- PI 工程：`D:\idea_workspace\zero-engine-pi-installer`，Maven 坐标 `com.avocent.taf:zero-engine-pi-installer:1.2.0-wjt-SNAPSHOT`，`install-package` profile 产出 `zero-engine-pi-installer-linux.tar.gz`；原 `zero-engine-installer` 继续作为 SI 使用 Zero Engine 时的打包工程。
- Payload：`zeengine.war`、`snmp-sampler` jar、`config/application-prod.properties`、`database/zero_engine.db`、`jre/`、`certs/keystore.p12`、`service/zesvc.service`、安装/升级/备份脚本。
- Linux 安装目标：`/opt/zeroengine`；服务名 `zesvc`；运行用户/组 `ze_app:ze`；JRE `zulu21.44.17-ca-jre21.0.8-linux_x64.tar.gz`；端口 `8088`，context path `/api`；SQLite DB `/opt/zeroengine/database/zero_engine.db`；ActiveMQ `tcp://localhost:61616`。
- 初始风险：此前未发现 Windows ZE 包；`ze-install.sh` 与 `jre_install.sh` 职责拆分；默认 SQLite 但 upgrade/backup/restore 脚本仍含 MySQL 逻辑。2026-05-26 已在 ZE Windows 服务接入执行中处理。

**2026-05-26 PI3.0 Windows 服务化链路**：
- PI Windows 上的 `TAFsvc` 不是由 `mtp-core.war` 直接注册，而是由 Java Service Launcher：`com.roeschter:jsl:0.991` / `jsl64.exe` 包装。IA 将 `resources/binaries/bin/jsl64.exe` 安装为 `$USER_INSTALL_DIR$/TAFsvc.exe`。
- `TAFsvc.ini` 随安装复制到 `$USER_INSTALL_DIR$` 并执行 IA 变量替换；其中 `servicename=TAFsvc`、`dependencies=TAFdb`、`jrepath=$USER_INSTALL_DIR$/jre`、`wrkdir=$USER_INSTALL_DIR$`、`cmdline=-Xmx1024m -Xms256m -jar mtp-core.war ... --spring.config.additional-location=./config/`。
- IA Windows 服务注册顺序：安装 `TAFsvc.exe` + `TAFsvc.ini` + `mtp-core.war` → 执行 `"$USER_INSTALL_DIR$/TAFsvc.exe" -install` → 写注册表 `HKLM\SYSTEM\CurrentControlSet\Services\TAFsvc\ImagePath` 为带引号路径 → `NTServiceController` 启动 `TAFsvc`。卸载时先 stop `TAFsvc`，再执行 `$USER_INSTALL_DIR$/TAFsvc.exe -remove`。
- ZE Windows 方案可复用该模式：复制 `jsl64.exe` 为 `ZESvc.exe` 或 `zesvc.exe`，提供 `ZESvc.ini` 指向 `zeengine.war`、JRE21、ZE config/database/certs 路径，再由 IA 执行 `-install/-remove` 和服务 start/stop。

**2026-05-26 ZE Windows 服务接入执行**：
- 计划已持久化：`docs/migration-tasks/04-zero-engine-windows-service-plan.md`。
- `D:\idea_workspace\zero-engine-pi-installer`：新增 `package/assembly-linux.xml`、`package/assembly-windows.xml`；平台专属文件统一放入 `platform/linux`、`platform/windows`，包括 `platform/windows/service/ZESvc.ini`、`platform/linux/service/zesvc.service`、`platform/*/jre/README.md`；`pom.xml` 新增 `windows-package` profile，Windows 产物为 `zero-engine-pi-installer-windows.zip`。
- `zero-engine-pi-installer` 已去掉 MySQL/MariaDB 残留：删除 `mysql_install.sh`、`generate_password.sh`、`database/my.cnf`、`database/zero-engine.sql.deprecated`；`backup.sh`/`restore.sh`/`upgrade.sh` 改为文件级处理；`application-prod.properties` 改为相对路径 `samplers`、`certs/keystore.p12`、`database/zero_engine.db`。
- `D:\cursor_workspace\cursor_out\copy\taf-core-installer`：`pom.xml` 使用 `com.avocent.taf:zero-engine-pi-installer:${zero-engine-pi-installer.version}:windows:zip` 依赖；`unpackZips`/`getWars` 排除该 artifact，并新增 `unpackZeroEngineWindows` 使用 `maven-dependency-plugin:unpack` 将 Windows zip 解包到 `src/main/resources/binaries/zeroengine`。
- `TAFCore.iap_xml`：新增安装 `zeroengine` 目录；安装时复制 `$USER_INSTALL_DIR$/TAFsvc.exe` 为 `$USER_INSTALL_DIR$/zeroengine/ZESvc.exe`，执行 `ZESvc.exe -install`、修正 `HKLM\SYSTEM\CurrentControlSet\Services\ZESvc\ImagePath`、启动 `ZESvc`；卸载时 stop/remove `ZESvc`。
- 已做本地静态验证：XML parse 通过；`zero-engine-pi-installer` 中搜索不到 `mysql/mysqld/mariadb/my.cnf/mysqldump/upgrade_sql` 等残留。
- GitLab 构建日志 `C:\Users\Wu.juntao\Desktop\PI\PI next release\build.txt` 显示早期失败点在 Maven 解析 `com.avocent.taf:zero-engine-pi-installer:zip:windows:1.2.0-wjt-SNAPSHOT`：访问 GitLab Maven group registry 返回 `403 Forbidden`，尚未进入 InstallAnywhere 打包阶段；修复方向是先发布/授权该 ZE Windows zip 依赖，并清理或强制刷新 runner Maven 缓存。
- `zero-engine-pi-installer` 的 `.gitlab-ci.yml` 已将原 `java-build` 拆成 `java-build-linux` 与 `java-build-windows`，同属 `java-build-stage`；Linux job 执行 `mvn ... clean deploy -P install-package,pi -U`，Windows job 通过 `needs: java-build-linux` 等 Linux 成功后执行 `mvn ... clean deploy -P windows-package,pi -U`，用于发布 `classifier=windows,type=zip` 的 ZE 包。
- `build-2.txt` 确认 ZE Windows 包存在后，`taf-core-installer` 仍 403 的原因不是缺少 classifier；用户最终确认 `14317851` 是 `TAF` 的 groupId，因此 `https://gitlab.com/api/v4/groups/14317851/-/packages/maven` endpoint 类型正确，剩余重点是 `taf-core-installer` 的 `CI_JOB_TOKEN` 是否被 `/TAF/max/zero-engine-pi-installer` 允许跨项目/子组读取 package registry，或改用具备 `read_package_registry` 的 deploy token/PAT。
- `build-3.txt` 已进入 InstallAnywhere 阶段，失败原因变为 IA 找不到 `$IA_PROJECT_DIR$\resources\binaries\zeroengine\`；日志显示 `zero-engine-pi-installer-...-windows.zip` 被解包/复制到了 `src/main/resources/binaries` 根目录，而非 `src/main/resources/binaries/zeroengine`。本地已修正 `taf-core-installer/pom.xml`，改为单独 `unpackZeroEngineWindows` 解到目标子目录。
- 2026-05-26 已从当前 `taf-core-installer` 生效链路移除 Nmap：`.gitlab-ci.yml` 不再预置 `nmap-win32.exe`/`nmap-linux_x86_64.rpm` 与 marker；`pom.xml` 删除 `org.nmap:nmap` 依赖与 `nmap.version`；`TAFCore.iap_xml` 删除 Windows Nmap 安装/卸载动作与 Linux RPM 安装动作，保留历史快照 `TAFCore.iap_xml.20*` 不动。

**2026-05-27 GitLab 构建成功 + 本地安装 ZE 未生效（已确认）**：
- 构建日志 `C:\Users\Wu.juntao\Desktop\PI\PI next release\build-4.txt`：`unpackZeroEngineWindows` 正常；`[buildinstaller] zeroengine(BUILD)` 约 11s，说明 **ZE payload 已编入安装介质**。
- 安装日志 `E:\software\PI3.0.1\main\_installation\Logs\PowerInsight_安装_05_27_2026_11_01_33.log`：安装器报告成功；功能含 `DB, Core, Common, Monitor, pi`；`TAFsvc`/`TAFdb` 正常；**无** `zeroengine` 目录安装记录、**无** `Preparing/Installing Zero Engine Service`、`ZESvc.exe -install` 或 `8088` 监听。
- 本机验证：`E:\software\PI3.0.1\main\zeroengine\` **不存在**；`Get-Service ZESvc` **不存在**；`application-prod.properties` 中 Zero Engine 默认配置 **已写入**（`f2b071bc983a` 动作有效）。
- **根因 A（文件未落盘）**：`TAFCore.iap_xml` 中 `InstallDirectory` `aa000001b13a`（`resources\binaries\zeroengine` → `$USER_INSTALL_DIR$\zeroengine`）位于 `Windows Only files` 组（`d4095d81b09b`），但 `totalSize=1`，安装时在 `TAFsvc.ini` 与 `console.url` 之间被 **静默跳过**（IA 未把该目录文件编入安装清单，需在 IA 中重扫目录或改为显式 `InstallFile`/`visualChildren`）。
- **根因 B（服务未注册）**：`ZESvc` 相关 `Exec`/`NTServiceController`（`aa000002`–`aa000005`）挂在 ActionGroup `ecdb7d1e9e76`（`Install TAF as a service`）内，该组主要挂在 **`AG- Core, si`** 组件；PI 实际路径是 `TAF CORE` 对 `ecdb7d1d9e78/79/7a` 的 **直接 ref**（仅 `TAFsvc`），故 ZE 服务链从未执行。
- **待改**（`cursor_out/copy/taf-core-installer` `TAFCore.iap_xml`）：① 修复 `zeroengine` `InstallDirectory` 文件清单；② 将 `aa000002`–`aa000005` 挂入 **PI `TAF CORE` 安装序列**（在 `TAFsvc.exe -install` 之前）；③ 重装后日志应出现 `zeroengine\` 安装与 `ZESvc` 启动，本机应有 `8088`。
- **2026-05-27 已实施 IA 修复**（A2 + B2 + A2-U）：见 [`migration-tasks/05-ze-ia-install-fix-plan.md`](migration-tasks/05-ze-ia-install-fix-plan.md)。`TAFCore.iap_xml` 已用 xcopy 部署文件、TAF CORE ref `ecdb7d1e9e76`、卸载 rmdir；静态验证通过。**待用户 GitLab 构建 + 本机安装验证**。
- **2026-05-27 已实施 SI 移除（Tier B）**：见 [`migration-tasks/06-remove-si-from-installer-plan.md`](migration-tasks/06-remove-si-from-installer-plan.md)。`TAFCore.iap_xml` 已删除 SI build config / bundle / 组件链（`AG- *, si`），并将许可证变量从 `$SI_LICENSE$` 改为 `$PI_LICENSE$`，读取文件改为 `pi_license.properties`。
- 资源收敛：已删除 `resources/si_script/`、`resources/variables/si.properties`、`TAFCorelocales_si/` 与 `src/assembly/si*.xml`；当前 `taf-core-installer` 目标为 **PI-only**。
- **2026-05-27 已实施 Linux ZE 集成**：见 [`migration-tasks/07-linux-ze-integration.md`](migration-tasks/07-linux-ze-integration.md)。`pom.xml` 新增 `unpackZeroEngineLinux` + `copyZeroEngine*Zip/Tar`；IA 在 **Linux Only Files** 下 `tar` + `ze-install.sh`；**Linux Services** 卸载 remove-all。
- **2026-05-27 build-5/6 装机仍无 ZE**：Maven 有 payload，但 IA **未** `zeroengine(BUILD)`；v2 的 `InstallFile`/`Exec` 缩进错误导致安装阶段在 `TAFsvc.ini` 后跳过 ZE 整段。v3：`aa000012b13a` `InstallDirectory`（`binaries\zeroengine` → `%INSTALL%\zeroengine`）+ `ecdb7d1e9e76` ref；脚本 `apply-ze-install-fix-v3.py`、`verify-ze-ia-structure.py`。**待 build-7**。

---

## 四、与 refactor_pi 的协作

- 运行时 IE→ZE 集成、Adapter、Trap：见 `../refactor_pi/docs/ze-migration/`
- 安装器任务进度不在 `refactor_pi/docs/task-process.md` 维护，以本工程 [`task-process.md`](task-process.md) 为准

---

## 五、可视化文档

- [`docs/visual/taf-core-installer-guide.html`](visual/taf-core-installer-guide.html) — 浏览器打开；含 Maven/IA/装机详细流程图，支持浅色/深色背景
- [`docs/retrospectives/ai-installanywhere-collaboration.md`](retrospectives/ai-installanywhere-collaboration.md) — AI 协作回望；记录本项目中如何使用 AI 处理 InstallAnywhere 安装器专项，并提供中英文双版，后续持续更新

## 六、下次对话启动方式

1. 读本文件
2. 读 [`task-process.md`](task-process.md) 看当前任务
3. 快速理解安装器：打开上述 HTML
4. 若改 IA 工程，以 `cursor_out/copy/taf-core-installer` 为基准
