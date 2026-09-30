# Linux 安装器攻坚：交付、架构与测试交付指南

> **最后更新**：2026-08-31
> **文档用途**：作为 **`01-team-delivery-and-qa-guide.md`**（Windows 篇）的 **Linux 平行卷**，指导开发与架构师理解 该产品 从「仅 Windows 交付」扩展到「RHEL + Ubuntu 双平台交付」后，Linux 侧的平台支持矩阵、systemd 服务生命周期契约、离线 PostgreSQL 打包契约、以及卸载脱离 InstallAnywhere 原生卸载器的架构决策；同时为 QA 团队提供 Linux 全新安装、异常回滚、卸载残留、离线包完整性与不支持 OS 行为的测试场景与用例，作为 Linux 交付的质量保障标准。
> **安全整改回归**（运行权限 / 防火墙 / 加解密 / TLS 等）不在本文展开 → 见 **`../security-fix/qa-impact-and-regression-scope.md`**（内部真源，不随本目录）。
> **配套**：硬核技术复盘见 [`02-hardcore-technical-postmortems.md`](../3-postmortems/migration-and-platform.md) **第六章「Linux 双平台攻坚」**；执行入口见 **`../plans/linux-ze-fix-plan.md`**（内部真源，不随本目录）。
> **体例**：本文只描述**现状**；历次修订过程见 git log。

---

## 一、平台支持矩阵与架构差异 (Platform Support & Topology)

### 1. 支持的操作系统矩阵

Linux 侧采用**精确清单（allowlist）**策略，只放行经过验证的发行版与小版本，其余（含 CentOS / Rocky / Alma / Debian 及清单外版本）一律在安装器早期门禁拒绝。

| 发行版 | 支持版本 | 架构 | 说明 |
| :--- | :--- | :--- | :--- |
| **RHEL** | 8.10 / 9.6 / 9.7 / 9.8 / 10.0 / 10.1 / 10.2 | x86_64 | 无 ARM64（无 `rpm/aarch64` 离线包） |
| **Ubuntu** | 24.04 / 26.04 | amd64（+ arm64 待补） | `postgresql-common` 291 需 `libjson-perl` |
| ~~CentOS~~ | — | — | **本轮移除**（原 `centos`/`V7` 规则留为失效死规则） |
| ~~Debian~~ | — | — | **明确拒绝** |

> **逃生门**：对清单外的 OS，可在安装器命令行传 `-DOSOK=TRUE` 跳过 OS 检查继续安装（尽力而为，**不保证完全无问题**）。详见 §三之 1。

> **前置依赖**：
> - **Ubuntu**：安装器运行需 `apt-get install libsvn1`（安装器自身依赖）；离线 PostgreSQL 另需 `libjson-perl`（见 §三之 3，与 `libsvn1` 是两回事——前者是安装器前置，后者是 PG 包依赖）。
> - **RHEL**：glibc 由门禁 `getconf GNU_LIBC_VERSION` 校验（见 §三之 2）。

### 2. RHEL vs Ubuntu 关键差异速查

同一套安装脚本 `pi-linux-install.sh` 通过读取 `/etc/os-release` 的 OS family 分支，屏蔽了两大发行版的路径与服务名差异：

| 维度 | RHEL (PGDG) | Ubuntu (PGDG) |
| :--- | :--- | :--- |
| **PG 服务名** (`$PG_SERVICE`) | `postgresql-18` | `postgresql`（伞状单元，真实实例 `postgresql@18-main`） |
| **PG 数据目录** | `/var/lib/pgsql/18/data` | `/var/lib/postgresql/18/main` |
| **PG bin 目录** | `/usr/pgsql-18/bin` | `/usr/lib/postgresql/18/bin` |
| **initdb 方式** | `postgresql-18-setup initdb` | `pg_createcluster 18 main --start`（装包时 postgresql-common 已自动建簇，此为幂等兜底） |
| **离线包格式** | `rpm -Uvh --force --nodeps *.rpm` | `dpkg -i *.deb` |
| **glibc 名称** | `glibc` | `libc6`（`/lib/x86_64-linux-gnu/libc.so.6`） |

> **易误读点**：Ubuntu 上 `systemctl status postgresql` 显示 `active (exited)` 是**伞状单元的正常态**，真实 postmaster 在 `postgresql@18-main`。QA 报告脚本 `diagnose-pi.sh` 已对 Ubuntu 额外打印 `postgresql@18-main` 以免误判「数据库没起来」。

### 3. Linux 服务拓扑

```
[ Linux (RHEL / Ubuntu) 运行环境 · systemd ]
+-----------------------------------------------------------------------------+
|                                                                             |
|   +------------------+             +------------------------------------+   |
|   |  tafsvc.service  | ----------> |  真实 PG 单元 (postgresql-18 /     |   |
|   |  (MTP Core 21)   |  TCP 5432   |   postgresql@18-main)              |   |
|   |  端口 8443       |             |  (PGDG 离线包安装)                 |   |
|   +------------------+             +------------------------------------+   |
|            |                                  ^                             |
|            | 内部通信 (HTTP API, TCP 8088)    | Requires/After              |
|            v                                  |                             |
|   +------------------+             +------------------------------------+   |
|   |  zesvc.service   | ----------> |  tafdb.service (瘦 systemd 别名)   |   |
|   |  (Zero Engine 21)| 本地 SQLite |  oneshot, ExecStart=/bin/true      |   |
|   +------------------+             |  (RHEL+Ubuntu 统一, 反映真实库状态)|   |
|                                    +------------------------------------+   |
+-----------------------------------------------------------------------------+
```

- **端口**：`zesvc` 8088（ZE API）、`tafsvc` 8443（MTP Core）、PostgreSQL 5432。
- **关键路径（Linux）**：
  - 程序树：`/opt/trellisappmgr`（PI 主程序）、`/opt/zeroengine`（Zero Engine，运行用户/组 `ze_app:ze`）
  - 配置：`/etc/opt/pi`（含 license）
  - 数据：`/var/opt/pi`（应用数据）、PG 数据目录（RHEL `/var/lib/pgsql/18` · Ubuntu `/var/lib/postgresql/18`）
  - IA 注册表：`/var/.com.zerog.registry.xml`
- **`tafdb`**：一个 `Type=oneshot` + `RemainAfterExit=yes` 的瘦 systemd 别名，`Requires`/`After` 真实 PG 单元，`ExecStart=/bin/true`。它本身不跑 postmaster，只让 `systemctl status/start tafdb` 在 RHEL 与 Ubuntu 上**行为一致**地反映/拉起真实数据库（背景见 §三与 [`02`](../3-postmortems/migration-and-platform.md) 第六章 6「`tafdb` SysV 假象与跨平台不一致」）。

---

## 二、服务生命周期契约 (Lifecycle Contract · systemd)

### 1. 服务清单（Linux）

| 服务 | 类型 | 职责 | 备注 |
| :--- | :--- | :--- | :--- |
| 真实 PG 单元 | 原生 PGDG | 数据底座 | RHEL `postgresql-18` / Ubuntu `postgresql`(+`@18-main`) |
| `zesvc` | 原生 systemd | Zero Engine（独立 SQLite） | 端口 8088，运行用户/组 `ze_app:ze` |
| `tafsvc` | 原生 systemd | MTP Core（`mtp-core.war`） | 端口 8443，`After/Wants` PG，运行用户/组 **`pi_app:pi`**（安全回归见 **qa-impact**（内部真源，不随本目录）；Linux 门禁实机仍可能待验） |
| `tafdb` | oneshot 别名 | PG 状态别名（跨平台一致） | `Requires/After` 真实 PG 单元 |

### 2. 启动顺序

```
Step 1: 真实 PG 单元 ──(pg_isready 就绪)──> Step 2: zesvc ──> Step 3: tafsvc
                          └──> tafdb (别名, 随真实 PG 反映状态)
```

- `pi-linux-install.sh` 在建库/建角色成功后，用 `pg_isready` 双保险轮询等待 PG 就绪，再依次拉起 `zesvc`、`tafsvc`，并 enable 开机自启。
- `tafsvc` 通过 `--spring.config.additional-location=/etc/opt/pi/` 读取配置。

### 3. 停止与注销顺序（卸载 / 回滚）

```
Step 1: tafsvc ──> Step 2: zesvc ──> Step 3: tafdb (别名) ──> Step 4: 真实 PG 单元
```

- 卸载或安装失败回滚时，由 `pi-linux-uninstall.sh` **逆序**停止 `tafsvc` → `zesvc` → `tafdb` → 真实 PG，再清理程序树、配置、（受 `DELETE_DATA` 保护的）数据与 `postgres` 用户。
- **关键点**：`tafdb` 只是别名，停它**不会**停 PostgreSQL；真正的 PG 停止由卸载脚本对真实 PG 单元的停用循环完成。

### 4. systemd 化与遗留 SysV 清理

- 历史 IA 曾用 `ASCIIFileManipulator` 向 `/etc/rc.d/init.d/` 落 SysV 脚本（`tafsvc`、`tafdb`）。这在 RHEL 上被 systemd 的 `sysv-generator` 包装成单元而「看得到」，在 Ubuntu 上则完全不生效。
- 本轮统一为**原生 systemd 单元**：安装前先 `rm -f /etc/rc.d/init.d/{tafsvc,tafdb}` 与 `/etc/init.d/tafdb`，再写原生 `.service`。IA 中安装遗留 `init.d-tafdb` 的节点（`ASCIIFileManipulator b4b4bb1989ae` + `InstallFile b59203618999`）已从 `TAFCore.iap_xml` 移除。

---

## 三、安装器变动 (As-Is → To-Be · Linux)

### 1. OS 白名单门禁重构

| 维度 | 改造前 (As-Is) | 改造后 (To-Be) |
| :--- | :--- | :--- |
| **判定逻辑** | 仅放行「RHEL/CentOS 且 `VERSION_ID` 含 `7`」（本为 7.x）；RHEL 9.7 靠「9.7 含 7」巧合放行，Ubuntu 全挡 | 精确清单：RHEL 8.10/9.6/9.7/9.8/10.0/10.1/10.2 + Ubuntu 24.04/26.04 |
| **实现节点** | `ExecuteScript 6bc46ade9b62`（原 Get OS_ID） | 同节点，脚本改为**零 `$` 的 grep 管道**读 `/etc/os-release`，输出 `TRUE`/`FALSE` 到 `$OS_SUPPORTED$` |
| **面板规则** | `!SkipOSCheck && !((redhat‖CentOS)&&V7)` | `!SkipOSCheck && !Supported`（`Supported` = `$OS_SUPPORTED$` contains `TRUE`） |

> **踩坑铁律**：内联 ExecuteScript **禁止**写裸 shell `$` 变量（`$ID`/`$VERSION_ID`/`$SUP` 等）——会被 IA 的 `$…$` 替换层吞噬打乱。必须用零 `$` 的管道式写法。深度机理见 [`02`](../3-postmortems/migration-and-platform.md) 第六章 1「IA `$…$` 成对切分吞噬内联脚本」。

### 2. glibc 门禁跨发行版化

- 改造前：ActionGroup `Check for glibc` 里 `Exec b7fd946b96ef` 跑 `yum list installed glibc`——Ubuntu 无 `yum` → 误判 `Missing glibc` 退出。
- 改造后：命令改为 `getconf GNU_LIBC_VERSION`（RHEL/Ubuntu 均输出 `glibc 2.xx` + exit 0，契合现有规则），narrative 文案中性化。这是全 XML **唯一**一处包管理器预检。

### 3. 离线 PostgreSQL 全量打包

- 改造前：离线目录只收「基础包」，缺 `-libs`（提供 `libpq.so.5`）与 `-server`（提供 `initdb`/服务/`postgres` 用户）→ PG 装不起来。
- 改造后：`install-postgresql.sh` 按 `uname -m` + OS 标签**整组安装**（`rpm -Uvh --force --nodeps <arch>/<tag>/*.rpm` 或 `dpkg -i <arch>/<tag>/*.deb`），并新增 `validate_pg_install` 校验 `libpq.so.5`+`initdb`+`postgres` 用户，缺则明确报「离线包不完整」。
- **目录结构**：`rpm/<arch>/<tag>/`、`deb/<arch>/<tag>/`（tag=rhel8.10/9.6/9.7/9.8/10.0/10.1/10.2、pgdg24.04/26.04），随 `InstallDirectory ec659cf385da` 递归打包，**加包无需改 XML**。
- **Ubuntu 特例**：`postgresql-common (291)` 硬依赖 `libjson-perl`，须把 `libjson-perl_4.10000-1_all.deb` 放进 `deb/amd64/{pgdg24.04,pgdg26.04}`（`_all` 纯 perl，一个即够）。arm64 待补。

### 4. 卸载脱离 IA 原生卸载器（架构级决策）

| 维度 | 改造前 (As-Is) | 改造后 (To-Be) |
| :--- | :--- | :--- |
| **入口** | `trellisappmgruninstall`（LaunchAnywhere native → uninstaller.jar） | **两层**：外层 shell **shim**（`trellisappmgruninstall` / `pi-uninstall` 软链）负责删数据问询、解析 `DELETE_DATA`；内层 worker `pi-linux-uninstall.sh` 做全产品拆除 |
| **可靠性** | Linux 上 **exit 218**，真错被 native 启动器吞掉（`lax_dump` 证明安装器 Zulu21 能跑，问题仅限卸载器） | shell 全程可控、可日志化 |
| **回滚复用** | 无 | 安装失败 `trap` 复用同一 `pi-linux-uninstall.sh`（非交互、**保数据**） |
| **控制台输出** | IA 卸载向导（进度条 / 完成页） | 纯 shell 明文 + 单行删数据提示 + 退出码 0 |
| **日志** | IA 落盘 | 复原落盘至 `<install>/_installation/Logs/PI_Uninstall_<MM_DD_YYYY_HH_MM_SS>.log`（守卫式自重执行 + `tee`，刻意保留 `_installation/Logs`） |

- **单一事实源**：`pi-linux-uninstall.sh` 是全产品拆除的唯一真源——始终删 app 树 / `/etc/opt/pi` / IA 注册表 / 软链；`/var/opt/pi` + PG 数据 + `postgres` 用户受 `DELETE_DATA` 保护。
- **删数据传参**：外层 shim 询问后 `exec pi-linux-uninstall.sh <INSTALL_DIR> <DATA_DIR> <DELETE_DATA>`；worker **故意非交互**（只读第 3 参，因回滚 trap 共用、必须非交互保数据）。实参形如：

```bash
# worker 由安装脚本落盘在 $INSTALL_DIR/pi-linux-uninstall.sh（默认 /opt/trellisappmgr）
# 三个位置参数：<INSTALL_DIR> <DATA_DIR> <DELETE_DATA(1=删/0=留)>
# 卸载并删除数据（等价于交互时输入 Yes / 1）
bash /opt/trellisappmgr/pi-linux-uninstall.sh /opt/trellisappmgr /var/opt/pi 1

# 卸载但保留数据（默认，等价于 No / 0）
bash /opt/trellisappmgr/pi-linux-uninstall.sh /opt/trellisappmgr /var/opt/pi 0
```

- **删数据文案**（对齐旧 IA）：`In addition to deleting PI, would you like to delete the data folder and all its content? [Yes/No] (default No):`，兼容 `Yes/No` 与旧 `1/0`。
- **`DELETE_DATA` 传参修正**：IA 直接传 `$DELETE_DATA$` 会序列化成 `'"Yes",""'` 被 argv 搞乱 → 改传 `$DELETE_DATA_BOOLEAN_1$`（干净 `1`/`0`）。
- **⚠️ 验证注意**：不要直接 `sh ./pi-linux-uninstall.sh` 无参跑（INSTALL_DIR 空 → 跳过树清理与落盘、DELETE_DATA 空 → 默认不删不问，卸载残缺）。正确 = 走 shim/软链，或 worker 补参 `... /opt/trellisappmgr /var/opt/pi 1`。

### 5. Windows 链零影响（隔离契约）

- 所有 Linux 安装/卸载动作均由全局共享规则 **`IsLinux`** 或平台门控（`Linux Preparations` / `CP495` / `CP970`）严格门控。
- Windows 卸载仍走 IA 原生卸载器（在 Windows 上工作正常），Windows 库服务 `TAFdb` 走独立 `pg_ctl register`，与 Linux `tafdb` 别名无关。
- **零 `iap_xml` 结构改动风险**：本轮 Linux 改动尽量只改现有节点属性 / 外置 `.sh`，避免新增 objectID（IA Builder 会静默剥离文本新增节点，见 [`02`](../3-postmortems/migration-and-platform.md) **第二章「20+ 次构建失败与 ObjectID 剥离陷阱」**）。

---

## 四、配置管理与建库 (Configuration & Bootstrap)

- **安装向导采集输入项**（与 Windows 共用 IA 面板，Linux 行为一致）：安装路径、**数据库端口（默认 5432）**、**管理员 `mtpadmin` / 普通用户 `mtpuser` 密码**、**应用 HTTPS 端口（默认 8443）**。安装完成后经 `https://<host>:8443` 完成首次配置。
- **角色**：建库前幂等 `CREATE ROLE mtpadmin WITH LOGIN SUPERUSER`（Linux `initdb` 默认超级用户为 `postgres`，故显式补建 `mtpadmin`）；应用普通用户 `mtpuser`。
- **建库**：`su - postgres -c "psql -d postgres" < createdb.sql`（**stdin 重定向**），绕开 `postgres` 用户对 `/opt/trellisappmgr`(764) 无 traverse 权限的 `Permission denied`。
- **许可证**：`pilnx.xml` 补打 `pi_license.properties`（此前仅 `piwin.xml` 有）。
- **配置读取**：`tafsvc` 以 `--spring.config.additional-location=/etc/opt/pi/` 加载。

---

## 五、质量保障与测试交付标准 (QA Test Suite · Linux)

> QA 可直接使用工程内两个报告脚本生成结构化报告：
> - 安装后：`docs/security-fix/scripts/ops/diagnose-pi.sh`（服务 `zesvc`/`tafsvc`/`tafdb`/PG + Ubuntu `postgresql@18-main`、端口 8088/8443/5432、DB 角色、日志关键字扫描）。
> - 卸载后：`docs/security-fix/scripts/ops/uninstall-and-verify.sh`（残留审计 + 从原路径拼接卸载日志）。

### 场景一：全新安装测试 (Clean Install)

#### 测试目的
验证在受支持的 RHEL 与 Ubuntu 上，安装器能通过 OS/glibc 门禁、完成离线 PG 全量安装、初始化建库建角色、拉起并自启所有服务。

#### 测试步骤与验证矩阵（**至少覆盖 RHEL 9.7 + Ubuntu 26.04 各一遍**）

| 步骤 | 操作内容 | 预期结果 (验证标准) | 验证方法 / 命令 |
| :--- | :--- | :--- | :--- |
| **1.1** | OS 白名单门禁 | 受支持 OS 顺利通过，无 `OS not supported` | 观察安装界面；失败见 `$OS_SUPPORTED$` 判定 |
| **1.2** | glibc 门禁 | RHEL 与 Ubuntu 均通过，无 `Missing glibc` | `getconf GNU_LIBC_VERSION` 输出 `glibc 2.xx` |
| **1.3** | 离线 PG 全量安装 | 所有 PG 子包 **配置完成**（非 `iU` 半配置） | RHEL `rpm -qa \| grep postgresql18`；Ubuntu `dpkg -l \| grep postgresql`（状态列须 `ii`） |
| **1.4** | `postgres` 用户 + 数据簇 + 端口 | `postgres` 用户存在、数据目录生成、5432 监听 | `id postgres`；检查数据目录；`ss -tlnp \| grep 5432` |
| **1.5** | 服务注册与自启 | `zesvc`/`tafsvc`/`tafdb`/真实 PG 均 active 且 enabled | `systemctl status zesvc tafsvc tafdb`（Ubuntu 另看 `postgresql@18-main`） |
| **1.6** | 端口监听 | 8088(ZE) / 8443(tafsvc) / 5432(PG) 均监听 | `ss -tlnp \| grep -E '8088\|8443\|5432'` |
| **1.7** | 建库建角色 | `mtp` 库建成、`mtpadmin`/`mtpuser` 角色存在 | `su - postgres -c "psql -c '\\du'"` |
| **1.8** | `tafdb` 跨平台一致性 | RHEL 与 Ubuntu 上 `systemctl status tafdb` 均可见且反映真实库 | `systemctl status tafdb` |
| **1.9** | 安装版本号 | 安装向导/控制台欢迎语为 `Welcome to the Power Insight v4.0.0.0 Setup wizard.`（原 3.0.0.0，源自 Maven `build.version.major`；此提示 Linux 控制台亦可见） | 观察 `-i console` 或 GUI 欢迎界面 |

### 场景二：不支持 OS 行为测试 (Unsupported OS)

#### 测试目的
验证清单外 OS 被正确拦截，且逃生门可用、Debian 被拒。

| 步骤 | 操作内容 | 预期结果 | 验证方法 |
| :--- | :--- | :--- | :--- |
| **2.1** | 清单外 OS 直接安装 | 弹出 / 打印 `OS not supported` 并干净退出 | 观察界面/控制台 |
| **2.2** | 逃生门 `-DOSOK=TRUE` | 跳过 OS 检查继续安装（尽力而为，不保证完全无问题） | `./vertiv-pi-installer.bin -i console -DOSOK=TRUE` |
| **2.3** | Debian | 被拒绝（不在清单） | 观察拦截 |

### 场景三：异常与回滚测试 (Rollback on Failure)

> 本场景的**触发手段、验证标准与回滚清理细节**统一维护在 **security-fix · qa-impact 附录 B（手动制造安装回滚）**（内部真源，不随本目录）——Linux 见其 **B.1**（SIGINT 触发 `trap` 回滚、`DELETE_DATA=0` 保数据、清 `pi_app`/`pi_db`/`pi` 账号 + 服务单元 + 防火墙，及回滚后重装的两条恢复须知；一键脚本 `scripts/ops/pi-rollback-test.sh`）。此处不再单列，避免与真源重复、口径漂移。

### 场景四：卸载残留测试 (Uninstall Cleanup)

#### 测试目的
验证 shell shim 卸载「零残留」，且 `DELETE_DATA` 分支正确，日志落盘。

| 步骤 | 操作内容 | 预期结果 | 验证方法 |
| :--- | :--- | :--- | :--- |
| **4.1** | 走真实入口卸载 | shim/软链执行，退出码 0，控制台为 shell 明文 | 运行 `trellisappmgruninstall` 或 `pi-uninstall` |
| **4.2** | 卸载日志落盘 | 生成 `_installation/Logs/PI_Uninstall_*.log` | 检查日志文件与内容 |
| **4.3** | `DELETE_DATA=No`（默认） | 程序/服务清除，**数据保留** | `uninstall-and-verify.sh` §3 |
| **4.4** | `DELETE_DATA=Yes`（输入 1） | PG 数据 / `/var/opt/pi` / `postgres` 用户随之删除 | 日志显示 `DELETE_DATA='1'->1`；检查数据目录 |
| **4.5** | 残留审计零残留 | 服务（含 `tafdb`）、`/etc/opt`·`/var/opt/pi`、IA 注册表、`pi-uninstall` 软链、遗留 SysV 全清 | `uninstall-and-verify.sh` §3.1~3.5 全 `[CLEAN]` |

### 场景五：离线包完整性测试 (Offline Package Integrity)

#### 测试目的
验证离线 PG 包组在无网环境下完整可装（尤其 Ubuntu 依赖链）。

| 步骤 | 操作内容 | 预期结果 | 验证方法 |
| :--- | :--- | :--- | :--- |
| **5.1** | 无网安装 | 全程不联网、不 apt/yum 拉包 | 断网环境测试 |
| **5.2** | Ubuntu `libjson-perl` | `deb/amd64/{pgdg24.04,pgdg26.04}` 含该包，`postgresql-common` 正常配置 | `dpkg -l \| grep libjson-perl` |
| **5.3** | `validate_pg_install` | 缺包时明确报「离线包不完整」而非静默半装 | 故意缺包测试脚本输出 |

### 场景六：静默安装（已移除 · 不在交付范围）

#### 说明（产品定论 D-K9，2026-07-29）

与 Windows 篇一致：**PI 4.0 已移除静默安装官方交付**。随包不再提供 Unix `silentsample.txt`；**不要**再按 `-i silent -f installer.properties` 做交付必测。

| 项 | 现状 |
| :--- | :--- |
| 样例文件 | 活跃工程中 **已删除** |
| QA | 场景一～五仍为 Linux 交付必测；本场景仅作范围声明 |
| 非官方路径 | 手搓响应文件属无 SLA；安全协同见 **qa-impact**（内部真源，不随本目录） |

---

## 六、交付质量红线 (Quality Gates · Linux)

1. **换行红线**：所有 `.sh` 必须 LF 换行（`.gitattributes` `*.sh eol=lf`），严禁 CRLF 混入导致 Linux 执行异常。
2. **IA 变量红线**：内联 ExecuteScript **零裸 `$` shell 变量**，避免被 IA `$…$` 替换层吞噬（`bash -n` + 判定矩阵**不覆盖** IA 打包 `$` 替换层，必须实机验证）。
3. **安全红线**：所有递归删除走 `safe_rm_rf()`（拒空/根/系统顶层目录）；`userdel/groupdel` 用 `getent` 守卫 + `|| true`；通过 `verify-destructive-commands.ps1` 静态审计（CHECK 8：`.sh` 的 `rm -rf` 必须走 `safe_rm_rf`）。
4. **离线红线**：离线安装 PG 全程不得联网拉包；缺包必须 `validate_pg_install` 显式报错。
5. **隔离红线**：Windows 链绝对不受影响（Linux 动作全部 `IsLinux`/平台门控）；每次改动 `bash -n` + 结构门禁 + 安全审计全绿。
6. **残留红线**：无论回滚还是手动卸载，程序树 / 配置 / 服务（含 `tafdb`）/ IA 注册表 / 软链 100% 清除；数据仅在 `DELETE_DATA=Yes` 时删除。
7. **静默安装**：产品已移除官方静默交付；不得再以 `silentsample.txt` / `-i silent` 作为 Linux 交付必测项。

---

## 七、交付级行为变化清单 (QA 须知并逐项确认)

> 以下是 Linux 相对旧版 / Windows 的**可见行为变化**——QA 必须知晓并**逐项验证确认**。相关细节在前文各场景/表格已有分散说明，本节作为 QA 面向的**集中总览**。

### A 组：安装器界面 / 交互级变化

| # | 变化点 | 旧行为 | 新行为（Linux） | QA 验证动作 |
| :--- | :--- | :--- | :--- | :--- |
| **A1** | **卸载控制台输出** | IA 卸载向导：进度条 + 完成页 | 纯 shell 明文 + 退出码 0 | 确认无向导、明文正常、退出码 0；**原基于 IA 界面的测试步骤/截图需在 Linux 上改写** |
| **A2** | **删数据问询交互** | IA 面板勾选 | 单行文本 `In addition to deleting PI, would you like to delete the data folder and all its content? [Yes/No] (default No):` | 验证 `Yes` / `No` / `1` / `0` / 回车默认(No) 各分支行为正确 |
| **A3** | **卸载入口本质** | `trellisappmgruninstall` = IA native 卸载器 | 同名命令实为 **shell shim**（原二进制存为 `.ia.bak`），另有 `/usr/local/sbin/pi-uninstall` 软链 | 验证两个入口均可执行且行为一致 |
| **A4** | **卸载日志内容** | IA 日志 | 路径/命名照旧（`_installation/Logs/PI_Uninstall_<MM_DD_YYYY_HH_MM_SS>.log`），但**内容为 shell 明文** | 验证日志文件生成、内容完整可读 |
| **A5** | **OS 不支持时的行为** | 旧门禁靠「版本号含 7」巧合放行 | 清单外 OS 打印 `OS not supported` 退出；`-DOSOK=TRUE` 可跳过（尽力而为，不保证） | 矩阵内通过 / 矩阵外拦截 / 逃生门可用，**三态都验** |
| **A6** | **安装失败回滚输出** | IA 回滚向导 | shell 明文自动回滚（复用卸载脚本、**保数据**） | 触发失败，确认自动回滚 + 数据保留 + 明文输出 |

### B 组：运维 / 验证方法层面的变化（不知会误判）

| # | 变化点 | 说明 | QA 验证 / 认知动作 |
| :--- | :--- | :--- | :--- |
| **B1** | **`systemctl status tafdb` 现双平台可见** | 以前 Ubuntu 看不到 `tafdb`、RHEL 看到的是不管真库的空壳 | RHEL 与 Ubuntu 都验 `tafdb` 可见且反映真实库状态 |
| **B2** | **Ubuntu 上 PG 查看方式** | `systemctl status postgresql` 显 `active (exited)` 是**伞状单元正常态**，真实 postmaster 在 `postgresql@18-main` | **勿误判「库没起来」**；用 `systemctl status postgresql@18-main` + `pg_isready` 确认 |

