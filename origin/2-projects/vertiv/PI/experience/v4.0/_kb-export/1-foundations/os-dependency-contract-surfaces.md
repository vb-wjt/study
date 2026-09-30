# 安装器对操作系统的依赖契约面（16 项）

> **这是什么**：从一个具体项目的「OS 依赖契约」文档中节选出的**方法部分**——契约面总表（按层）、16 项逐项说明、以及环境指纹采集项与判读标准（五档判读）。
> **没有纳入什么**：原文的采集脚本规格、与选包文档的边界划分、以及两个附录里的具体版本值（release notes 预期值基线、各版本实测指纹）。那些是项目特定的数据，而且过期即废。
>
> **可迁移的是这套做法本身**：把「软件对操作系统的隐式依赖」显式化成一张可逐项判定的表，每一项标注「它在受支持的版本之间会不会变、变了是否影响本系统」。
> 做完这张表，「支持哪些版本」才从「测过几台」变成可论证；而表里标「高」的那几项，就是每出一个新版本必须重测的清单。
>
> ⚠️ **配套必读**：这套论证是**割集论证**（代码是同一份 → 跨版本差异只能来自 OS → 穷举 OS 依赖面即可覆盖），**不是全集**。四个已知漏洞见机理复盘「方法论边界」一节：穷举完备性是假设、应用层解耦只是近似、最小验证集不测行为正确、对非 OS 依赖完全沉默。

---

## 一、契约面总表（按层）

「版本敏感性」= 该项在受支持的小版本之间是否会变、变了是否影响 PI。

| # | 契约项 | 实现位置 | 版本敏感性 |
|---|--------|---------|-----------|
| C-1 | `/etc/os-release` 的 `ID` / `VERSION_ID` | `TAFCore.iap_xml` 内联脚本（白名单） | **高**（决定是否放行） |
| C-2 | OS 版本 → PG 包标签映射 | `install-postgresql.sh` | **高**（每版本不同二进制） |
| C-3 | 系统 OpenSSL 符号版本 | 被自带 PG 动态链接 | **高**（ABI 单向兼容） |
| C-4 | 系统 libicu 版本 | 被自带 PG 链接（collation） | **高** |
| C-5 | glibc / libstdc++ 版本 | 自带 Zulu JRE 与 PG 的运行底线 | **高**（跨**大**版本敏感：2.28 / 2.34 / 2.39 三档。同大版本内实测稳定，见[附录 A.2](#a2-已推翻的论据rhel-9-内部-glibc-并未-rebase)） |
| C-6 | `rpm` / `dpkg` 行为 | `install-postgresql.sh` | 低 |
| C-7 | `useradd` / `shadow-utils` | `pi-linux-install.sh:140-145` | 低 |
| C-8 | systemd 版本与指令支持 | `pi-linux-install.sh` heredoc 生成单元 | **低**（仅用基础指令） |
| C-9 | SELinux 策略与端口标签 | **无代码处理** | **高**（小版本间会变，且零适配） |
| C-10 | firewalld 存在性与版本 | `pi-linux-install.sh:643-648` | 低 |
| C-11 | 系统 crypto-policy | **不适用**（自带 Zulu JRE 不读它） | **无**（关键解耦点） |
| C-12a | 端口占用检测（插件声明端口 / DB 端口 / 服务端口） | `InstallerPreflightChecks`（CustomCode）+ IA 探测动作 `ss -lntu` + `WCHECKPORT`/`LCHECKPORT` 规则 | **低**（`ss` 在全部目标版本均自带） |
| C-12b | 系统已存在的 Java / PostgreSQL 安装 | 无显式检测 | **中偏高**（RHEL 9.8 / 10.2 与 Ubuntu 26.04 的系统仓库均提供 **PostgreSQL 18**，与自带 PGDG 18 同版本，冲突面最大，见[附录 A.3](#a3-逐项发现按契约面归类)） |
| C-13 | `/tmp` 挂载选项（`noexec`）与执行控制 | IA LaunchAnywhere 解包执行 | 中（`noexec` 会直接启动失败；**另需考虑 `fapolicyd`**，见[附录 A.3](#a3-逐项发现按契约面归类)） |
| C-14 | X11 / GUI 库 | **不适用**——Linux 默认走 console 模式 | 无 |
| C-15 | locale / 字符集 | 中英文 i18n 面板 | 低 |
| C-16 | 磁盘 I/O 与内存 | 运行期（tafdb checkpoint） | 低（与 `ze.log` 重复注册 bug 相关，作基线；相关内核机制——fsync / page cache / dirty ratio / OOM killer / THP——见 [`05` 第四节](linux-deployment-gotchas.md#四进程--服务运行期systemd-深水区)） |

---

## 二、逐项说明

### C-1 · OS 白名单校验

实现为 `TAFCore.iap_xml` 中的内联 shell（刻意不使用 shell 变量，因 IA 会替换成对的 `$...$` 记号而破坏 `$ID` / `$VERSION_ID`）：

```3894:3894:<repo>\installer\src\main\TAFCore.iap_xml
if grep -E '^(ID|VERSION_ID)=' /etc/os-release | sort | tr -d '"' | tr '\n' ' ' | grep -qE 'ID=rhel .*VERSION_ID=(8\.10|9\.6|9\.7|9\.8|10\.0|10\.1|10\.2) |ID=ubuntu .*VERSION_ID=(24\.04|26\.04) '; then echo TRUE; else echo FALSE; fi
```

结果写入 `$OS_SUPPORTED$`，由规则 `Supported`（`$OS_SUPPORTED$ contains TRUE`）判定。不通过时展示「OS not supported」，规则表达式为 `!SkipOSCheck && !Supported`。

**机制要点**：`^(ID|VERSION_ID)=` 不会误匹配 `ID_LIKE=`（要求 `=` 紧随）；`sort` 保证 `ID` 行恒在 `VERSION_ID` 行之前（`I` < `V`）；版本后的**尾随空格**使匹配精确（`VERSION_ID=9.81` 不会被 `9\.8` 命中）。

**旁路**：`$OSOK$` 为 `TRUE` 时命中 `SkipOSCheck` 规则、跳过整个校验。该旁路在 `InstallReadme.txt` 中公开记录（`-DOSOK=TRUE`），测试时可用于在非白名单版本上做对比安装。

**遗留死规则**：`$OS_SUPPORTED$ contains centos` 与 `$VERSION_ID$ contains 7` 是 CentOS 7 时代残留——`OS_SUPPORTED` 现在只可能是 `TRUE` / `FALSE`，两条规则永不成立。

### C-2 · PG 包标签映射

见 **`01` 层 2** 与 **`06-postgresql18-package-selection.md`**。

**因白名单在前而不可达的分支**（无需测试）：Rocky / Alma / Oracle / CentOS 分支、Debian 分支、`8.x`（非 8.10）→ `rhel8.10` 映射、`9.0–9.5` 拒装分支、`9.8+` / `10.2+` 向前兜底、Ubuntu 非 24.04/26.04 的拒装分支。

### C-3 / C-4 · OpenSSL 与 libicu

自带 PG 动态链接系统的 `libssl` / `libcrypto` / `libicu`。RHEL 9/10 在小版本间**新增** OpenSSL 符号版本，故老 OS 无法满足新构建包的符号需求（单向兼容）。PI 通过按小版本分目录打包规避，但安装使用 `rpm -Uvh --force --nodeps`：

```228:228:<repo>\installer\src\main\resources\installables\Unix\postgresql\install-postgresql.sh
    if ! rpm -Uvh --force --nodeps "$@"; then
```

`--nodeps` 使 RPM 层的依赖/ABI 校验失效，符号不匹配的包**会装成功**，仅在运行期暴露。而安装后校验只做三项弱检查：

```52:66:<repo>\installer\src\main\resources\installables\Unix\postgresql\install-postgresql.sh
validate_pg_install() {
    initdb_path="$1"
    problems=""
    if command -v ldconfig >/dev/null 2>&1; then
        ldconfig -p 2>/dev/null | grep -q 'libpq\.so\.5' || problems="$problems libpq.so.5(-libs)"
    fi
    [ -x "$initdb_path" ] || command -v initdb >/dev/null 2>&1 || problems="$problems initdb(-server)"
    id postgres >/dev/null 2>&1 || problems="$problems postgres-user(-server)"
```

`[ -x ]` 只判断文件可执行位，**不验证符号可解析**。故三项在 ABI 不匹配时均会通过 → 必须靠实际执行 `initdb` 来暴露（**`01` 最小验证集第 4 项**）。

### C-8 · systemd

单元文件在安装时由 heredoc 现场生成，仅使用 `[Unit]`、`ExecStart` 等基础指令；**未使用**任何版本敏感的加固指令。故 RHEL 8.10 的 systemd 239 同样满足，此项风险低。最小权限运行是靠服务账户实现的，与 systemd 版本无关：

```140:145:<repo>\installer\src\main\resources\installables\Unix\postgresql\pi-linux-install.sh
    useradd --system --no-create-home --shell /sbin/nologin -g "$SVC_GROUP" "$SVC_USER" \
        || log "[WARN] useradd $SVC_USER failed"
```

### C-9 · SELinux

安装脚本中**完全没有** SELinux 适配代码（无 `semanage` / `chcon` / `restorecon` / `getenforce`）。自定义单元运行 Java 通常落在 `unconfined_service_t`，多数情况可用；但 `selinux-policy` 包版本在每个小版本都会更新，且 PI 需绑定 8443 与可自定义的 PG 端口 → 这是层 3 中最需要逐版本实测的一项。

### C-11 · crypto-policy 不适用（关键解耦点）

自带 JRE 为 **Azul Zulu**，非 Red Hat OpenJDK：

```442:448:<repo>\installer\pom.xml
        <dependency>
            <groupId>com.zulu</groupId>
            <artifactId>zulu-jre</artifactId>
            <version>${jre.version}</version>
            <classifier>linux64</classifier>
            <type>vm</type>
        </dependency>
```

`<jre.version>` 为 `21`。Red Hat 通过 `/etc/crypto-policies/back-ends/java.config` 让其 OpenJDK 读取系统策略，这是 Red Hat 的下游补丁，Zulu 不含。故系统 crypto-policy 在小版本间的收紧**不影响** PI 的 Java 侧 TLS 行为。

> 采集时仍建议记录 crypto-policy 现值：系统侧 OpenSSH 与自带 PG（若用系统 OpenSSL）仍受其约束，且它是排查 TLS 问题时的必要背景信息。

---

### C-12a · 端口占用检测（已实现，此前记录有误）

检测链路由三部分组成：

**1）IA 探测动作采集监听端口快照** —— 按平台分别执行，结果落入 `$EXECUTE_STDOUT$`：

| 平台 | 命令 |
|------|------|
| Linux（`ISLINUX`） | `/bin/bash -c "ss -lntu 2>/dev/null \|\| netstat -antu 2>/dev/null"` |
| Windows（`ISWINDOWS`） | `netstat -an` |

Linux 侧**优先 `ss`、netstat 仅作兜底**，这个顺序很关键：`netstat` 属于已弃用的 `net-tools`，在 RHEL 8/9/10 与 Ubuntu 上默认都不安装；而 `ss` 来自 `iproute2`，全部目标版本均自带。故此项**不构成版本敏感风险**。该探测动作在 `TAFCore.iap_xml` 中出现多处（端口勘察会被多次调用）。

**2）`InstallerPreflightChecks` 勘察插件声明的端口** —— IA CustomCode 动作（原名 `CheckPortsNeededInUse`），运行在选目录与建账户/服务**之前**：

- 从 `Resource1.zip` 与 `$CUSTOM_APPLICATIONS_DIR$` 下的 `*app.zip` / `plugin.zip` 中读取 `plugin.json` 的 `listenPortsRequired`，汇总各插件/应用需要的端口；
- 用 `$EXECUTE_STDOUT$` 逐个比对，**精确匹配** `:<port>`（要求端口号前后不是数字，避免 `:162` 误命中 `:1620`）；
- 输出 IA 变量：`$PORTS_NEEDED_IN_USE$`（有可改端口冲突 → 提示改端口）、`$FIXED_PORT_IN_USE$`（固定端口冲突 → 报错，需用户自行释放）、`$PORT_INFO$`（端口配置表，供后续面板使用）；
- 改端口的交互由 `PromptAlternatePortsPanel`（GUI）与 `PromptAlternatePortsConsole`（console）承担。
- 其中 Windows 专属的两项检查（有效管理员提权、SNMP trap 端口 162）是 **non-fatal 仅记日志**；Linux 侧对应的是独立的 "Check for Root" 关卡。

**3）DB 端口单独校验** —— `$TAFDB_PORT$`（默认 `5432`），规则表达式 `INSTALL_DB && (WCHECKPORT || LCHECKPORT)`，命中即弹「DB Port … already in use / Select a different port or exit and release the port」：

| 规则 | 判定方式 | 实际效果 |
|------|---------|---------|
| `WCHECKPORT` | `$EXECUTE_STDOUT$` **contains** `:<port>` + 尾随空格 | ✅ 在 netstat 与 `ss` 输出上**都成立**（两者的本地地址均为 `0.0.0.0:5432` 形式，端口后接空白） |
| `LCHECKPORT` | `$EXECUTE_STDOUT$` **ends with** ` <port> ` | ❌ 要求整份 stdout **以** ` 5432 ` **结尾**，实际几乎永不成立 |

**结论：DB 端口占用检测在 Linux 上功能正常，但生效的是名字带 `W` 的那条规则；名义上的 Linux 规则 `LCHECKPORT` 因用了 `ends with` 而形同虚设。** 属命名与实现不符的清晰度问题，不影响功能。详见 **`03-os-risk-and-open-items.md`** R-6。

`$TAFSVC_PORT$`（服务端口）与 `$TAFDB_PORT$` 一同传入 `pi-linux-install.sh` / `pi-linux-uninstall.sh`。

### C-14 · GUI 库不适用

**Linux 上默认走 console 模式安装**，不使用 IA 图形模式，故 X11 / GUI 库不构成依赖。`PromptAlternatePortsConsole` 等 console 面板即为此路径服务。此项从版本差异分析中剔除。

---

## 三、环境指纹采集项与判读标准

**采集目的不是了解环境，而是产出可引用的证据**，证明「非基线小版本与同大版本基线在 PI 依赖的每一项上相同或仅补丁级差异」。

判读列的含义：**必须一致** = 与同大版本基线不一致即需追加验证；**记录即可** = 仅作排查背景。

### A 组 · 决定装不装得上

| 采集项 | 命令 | 为什么 | 判读 |
|--------|------|--------|------|
| `ID` / `VERSION_ID` / `ID_LIKE` / `PRETTY_NAME` 原始值 | `cat /etc/os-release` | 白名单的直接输入（C-1） | 必须能被白名单正则命中 |
| `/tmp` 挂载选项 | `findmnt -no OPTIONS /tmp` | `noexec` 会让 IA LaunchAnywhere 无法解包执行（C-13） | 不得含 `noexec` |
| 磁盘可用空间 | `df -h /opt /var /tmp` | 基础前置 | 记录即可 |
| `ss` 可用性 | `command -v ss` | 端口占用检测的前置（C-12a）；`netstat` 仅兜底且默认不装 | 必须存在 |
| **`fapolicyd` 是否启用** | `systemctl is-active fapolicyd` | 执行白名单会拦截 IA 在 `/tmp` 解包执行的临时文件（C-13，见 **`03`** R-10） | **应为 inactive**；active 时需单独评估 |

> **X11 / GUI 库不采集**：Linux 默认 console 模式安装，GUI 库不构成依赖（C-14）。

### B 组 · 决定跑不跑得起来（差异影响最大）

| 采集项 | 命令 | 为什么 | 判读 |
|--------|------|--------|------|
| **glibc 版本** | `ldd --version` | 自带 JRE 与 PG 的运行底线（C-5） | **必须一致**。实测 RHEL 9 三个小版本全为 2.34、RHEL 10 为 2.39；⚠️ 9.8 release notes 写的 2.39 是**误记**，采到 2.34 才是对的（[附录 A.2](#a2-已推翻的论据rhel-9-内部-glibc-并未-rebase)） |
| **libstdc++ / GCC 运行时** | `ldconfig -p \| grep libstdc++` | 原生件依赖（C-5） | **必须一致** |
| **OpenSSL 版本与 soname** | `openssl version -a`；`ldconfig -p \| grep -E 'libssl\|libcrypto'` | 自带 PG 的 ABI 依赖（C-3） | **必须一致**；soname 变化即为硬边界 |
| **libicu 版本与 soname** | `ldconfig -p \| grep libicu` | PG collation 依赖（C-4） | **必须一致** |
| **systemd 版本** | `systemctl --version` | 单元指令可用性（C-8） | 记录即可（仅用基础指令） |
| 系统已装 Java | `which -a java; java -version` | 与自带 JRE 冲突（C-12b，无显式检测） | 记录即可；若存在需确认未抢占 |
| 系统已装 PG | `rpm -qa \| grep -i postgres`（或 `dpkg -l \| grep postgres`） | 与自带 PG 冲突（C-12b，无显式检测） | 应为空 |
| 关键端口占用 | `ss -lntup \| grep -E ':(5432\|8443)\b'` | 安装器自身会检测（C-12a），此处采集用于交叉核对 | 应为空 |
| cgroup 版本 | `stat -fc %T /sys/fs/cgroup` | 资源限制行为 | 记录即可 |

> B 组里 **glibc、libstdc++、OpenSSL、libicu** 四项是核心。四项与同大版本基线一致，即可判定该小版本无需层 1 的重复回归。
>
> ⚠️ **不要预设这四项在同大版本内一致，但也不要预设它们不一致。** 这里曾两度判断错误：先是假定「同大版本内 glibc 不变」，后据 9.8 release notes 反过来断言「RHEL 9 内部 rebase 过」，而实测表明**前者恰好是对的、后者是 Red Hat 文档的笔误**（见 [A.2](#a2-已推翻的论据rhel-9-内部-glibc-并未-rebase)）。教训是：**这四项的值只能靠采集脚本逐台核实，任何方向的预设都可能翻车。** 附录给出**预期值**，采集脚本给出**实际值**，两者不符即为需追查的信号——而追查时 release notes 也可能是错的那一方。

### C 组 · 决定通不通信

| 采集项 | 命令 | 为什么 | 判读 |
|--------|------|--------|------|
| SELinux 状态 | `getenforce` | enforcing 下服务与端口绑定（C-9） | 记录；enforcing 时必须实测 |
| **java 进程的 SELinux 运行域** | `ps -eZ \| grep java` | 决定 PI 是否被 SELinux 约束（C-9 / **`03`** R-4） | **应为 `unconfined_service_t`**（9.7 已确认）；不同即需抓 AVC 复测第 5、7 项 |
| `selinux-policy` 包版本 | `rpm -q selinux-policy selinux-policy-targeted` | 小版本间会变，且代码零适配（C-9） | 记录，供跨版本比对 |
| 端口标签 | `semanage port -l \| grep -E '8443\|5432'` | 自定义端口能否绑定 | 记录即可 |
| firewalld 状态与规则 | `firewall-cmd --state; firewall-cmd --list-ports` | 端口放行（C-10） | 记录即可 |
| crypto-policy 现值 | `update-crypto-policies --show` | 排查背景（C-11，对 Java 侧不适用） | 记录即可 |

### D 组 · 运行期基线（不用于范围决策）

内核与架构（`uname -a`）、locale 与字符集（`locale`）、时区（`timedatectl`）、内存与 CPU（`free -h`、`lscpu`）、磁盘型号与 I/O 特征（`lsblk -o NAME,ROTA,MODEL`）、`ulimit -a`、关键 sysctl。

其中**磁盘 `ROTA`（是否机械盘）与 I/O 特征**建议必采：`ze.log` 重复 `registers to me` 的已知 bug 与 HDD I/O 饱和直接相关，见 **`bugs/ze-duplicate-register-db-io-stall.md`**（内部真源，不随本目录）。
