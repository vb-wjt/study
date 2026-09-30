# 05 · Linux 部署与运行时陷阱速查

> **本文件的作用**：[`04-linux-dependency-glossary.md`](linux-dependency-glossary.md) 讲清了 `02`/`03` 出现过的名词；本文件是它的**同域延伸**——把「编译好的原生二进制丢到各种 Linux 上还要能起来」这门学问里，**PI 尚未展开、但迟早会撞上的机制与经典陷阱**收成一份速查表。
> 视角是**打包方 / 部署方**（不是写业务逻辑）。每条给「是什么 → PI 为什么关心 → 怎么查 / 怎么防」。
> ⭐ = 与 PI 现状（Windows 上改脚本、IA 解包到 `/tmp` 执行、服务降权、PG 的 fsync/OOM、短信猫 `dlopen`、9 个内核各异）**直接挂钩**、优先级最高。
>
> 除 [§七](#七pi-的-linux-postgresql-为什么落在-varlib由包管理演进背景与取舍)（背景与成因解释，非新决策）外为**纯参考资料**；PG 部署的决策真源见 **`06`** 与 **`plans/linux-ze-fix-plan.md`**（内部真源，不随本目录）。 **最后更新**：2026-09-29（新增 §八 自定义安装目录 DAC 穿越权）

---

## 目录

- [一、动态链接器的其余半壁](#一动态链接器的其余半壁)
- [二、glibc 生态的边界](#二glibc-生态的边界)
- [三、文件系统布局差异](#三文件系统布局差异)
- [四、进程 / 服务运行期（systemd 深水区）](#四进程--服务运行期systemd-深水区)
- [五、打包系统内部](#五打包系统内部)
- [六、经典陷阱（偏门但业界共识）](#六经典陷阱偏门但业界共识)
- [七、PI 的 Linux PostgreSQL 为什么落在 `/var/lib`、由包管理（演进背景与取舍）](#七pi-的-linux-postgresql-为什么落在-varlib由包管理演进背景与取舍)
- [八、自定义安装目录：为什么装 `/home` 下会崩、装 `/opt` 就行（DAC 穿越权，非 SELinux）](#八自定义安装目录为什么装-home-下会崩装-opt-就行dac-穿越权非-selinux)
- [附录：一条命令看部署相关基线](#附录一条命令看部署相关基线)

---

## 一、动态链接器的其余半壁

`04` 第三节讲了 `ld.so`/`ldconfig`/`ldd`，但只覆盖了"找库、加载、查依赖"。下面是加载器行为的其余关键面。

### ⭐ 库搜索顺序：RPATH / RUNPATH / LD_LIBRARY_PATH / `$ORIGIN`

- **是什么**：`ld.so` 找一个 `.so` 的顺序（简化）：① 可执行文件里的 `DT_RPATH`（已弃用、优先级最高）→ ② `LD_LIBRARY_PATH` 环境变量 → ③ 可执行文件里的 `DT_RUNPATH` → ④ `/etc/ld.so.cache`（由 `ldconfig` 维护）→ ⑤ 默认 `/lib`、`/usr/lib` 等。**注意 RPATH 在 LD_LIBRARY_PATH 之前、RUNPATH 在之后**，这个顺序差异是经典困惑点。`$ORIGIN` 是特殊记号，表示"可执行文件所在目录"，用于**可重定位的自带库**。
- **PI 为什么关心**：自带 Zulu JRE 那一大堆 `.so`（`libjvm.so` 等）就是靠 JRE 内部的 RUNPATH/`$ORIGIN` 互相找到的，不依赖系统装了什么。任何"自带私有库"的分发都走这套。
- **怎么查**：`readelf -d <文件> | grep -E 'RPATH|RUNPATH'`；`LD_DEBUG=libs <程序>` 打印完整搜索过程。

### ⭐ `LD_PRELOAD`

- **是什么**：环境变量，让指定的 `.so` **在所有库之前加载**，从而**抢先覆盖同名符号**。常用于打热补丁、性能剖析、故障注入。
- **PI 为什么关心**：既是调试利器（临时替换某函数验证假设），也是**攻击面**——若攻击者能设它，就能劫持进程。加固时值得知道它的存在。
- **怎么查 / 怎么防**：`LD_PRELOAD=/path/hook.so <程序>` 使用；setuid 程序会忽略它（安全设计）。

### `dlopen` / `dlsym` 与运行期插件

- **是什么**：程序**运行中**再去加载一个 `.so`（而非启动时链好）。`RTLD_LAZY`（用到才解析符号）vs `RTLD_NOW`（立即全解析）。
- **PI 为什么关心**：短信猫 `jSerialComm` 就是运行期把原生 `.so` 解压到临时目录再 `dlopen`——这让两个问题**在运行期又出现一次**：[`04` 第一节](linux-dependency-glossary.md#一最基础的一组abi共享库soname符号版本) 的符号版本，以及「解压到 `/tmp` 再执行」（[`02` C-13](os-dependency-contract-surfaces.md#一契约面总表按层) 与 **`03`** R-10，原先只覆盖了安装期的 InstallAnywhere）。**安装期测试抓不到。**
- **怎么查**：`strace -e trace=openat,mmap <程序>` 看运行中加载了哪些 `.so`。

### 符号可见性与 version script

- **是什么**：库作者用 `-fvisibility=hidden` + 版本脚本控制"到底导出哪些符号、打什么版本节点"。决定了 `04` 那套符号版本表长什么样。
- **PI 为什么关心**：解释了"为什么有的库升级不破坏 ABI、有的破坏"——取决于作者有没有守住导出面。
- **怎么查**：`nm -D --defined-only <so>`；`objdump -T <so>`。

### PIE / PIC / ASLR / 重定位

- **是什么**：`.so` 必须是 **PIC**（位置无关代码）才能被加载到任意地址；现代可执行文件默认 **PIE**，配合 **ASLR**（地址随机化）做安全加固。代价是启动时多一步重定位。
- **PI 为什么关心**：属运行期基线常识；排查"启动慢/内存布局"时会用到。
- **怎么查**：`file <文件>`（显示 `pie executable` / `shared object`）；`cat /proc/sys/kernel/randomize_va_space`（ASLR 开关）。

---

## 二、glibc 生态的边界

### ⭐ glibc vs musl

- **是什么**：两套不同的 C 运行时实现。主流发行版（RHEL/Ubuntu/Debian）用 **glibc**；**Alpine** 用 **musl**。二者 ABI 不兼容——glibc 编译的二进制在 Alpine 上**直接跑不了**（反之亦然）。
- **PI 为什么关心**：容器化时代第一大坑。若将来 PI 相关组件被塞进 Alpine 基础镜像（很多"瘦镜像"默认 Alpine），自带的 glibc 二进制/JRE 会静默失败。**PI 官方支持面是 RHEL/Ubuntu（glibc），这条是"别踩"的边界。**
- **怎么查**：`ldd --version`（glibc 会打印版本；musl 会提示 musl）；`cat /etc/os-release`（Alpine 的 `ID=alpine`）。

### ⭐ 静态链接 vs 动态链接的取舍

- **是什么**：静态把库焊进二进制（自包含、可移植，但**享受不到系统的安全修复**，见 `04` 第一节「标签 vs 实现」）；动态链接体积小、能吃系统修复，但依赖目标机有对应库。
- **PI 为什么关心**：正是 PI 分发策略的理论底座——`04`「两种分发策略」的延续。全静态 glibc 还有个坑：**NSS/DNS 会失效**（见下条）。
- **怎么查**：`file <文件>`（`statically linked` / `dynamically linked`）；`ldd <文件>`（`not a dynamic executable` 即全静态）。

### ⭐ "kernel too old"

- **是什么**：glibc 编译时带一个**最低内核版本要求**。把二进制拿到更老内核上运行，会直接 `FATAL: kernel too old` 拒绝启动。
- **PI 为什么关心**：PI 的 9 个目标**内核各不相同**（8.10 的 4.18 ~ Ubuntu 26.04 的 7.0）。虽然"在老系统构建、新系统跑"是安全方向，但要警惕反向；短信猫等硬件功能对内核版本更敏感（见 **`03`** R-11）。
- **怎么查**：`file <二进制>` 会显示 `for GNU/Linux 3.2.0`（即最低内核）；`uname -r` 看目标机内核。

### NSS（Name Service Switch）

- **是什么**：`getpwnam`（查用户）、`getaddrinfo`（查主机名）等**运行时按 `/etc/nsswitch.conf` 动态加载** NSS 模块完成。这也是"全静态 glibc 二进制会瘸"的根因——它无法在运行时加载这些模块。
- **PI 为什么关心**：任何创建/查询系统用户、做主机名解析的逻辑都走它；解释了为什么 glibc 官方不推荐全静态。
- **怎么查**：`cat /etc/nsswitch.conf`；`getent passwd <user>` / `getent hosts <name>`。

---

## 三、文件系统布局差异

### ⭐ RHEL `/usr/lib64` vs Ubuntu multiarch `/usr/lib/x86_64-linux-gnu`

- **是什么**：库的安放路径两家不同。RHEL 系：64 位库放 `/usr/lib64`。Debian/Ubuntu 系：走 **multiarch**，放 `/usr/lib/x86_64-linux-gnu`（为多架构共存设计）。
- **PI 为什么关心**：这正是 `04` 第七节 PG 两家族「程序目录 / 数据目录」路径不同的底层原因；脚本里任何硬编码库路径都要区分家族。
- **怎么查**：`gcc -print-multiarch`（Ubuntu 打印 `x86_64-linux-gnu`，RHEL 为空）；`ldconfig -p | grep libpq`。

### FHS 与 `/usr` merge

- **是什么**：**FHS**（Filesystem Hierarchy Standard）规定了 `/bin`、`/usr`、`/etc`、`/var` 各放什么。现代发行版做了 **`/usr` merge**：`/bin` → `/usr/bin` 的符号链接。
- **PI 为什么关心**：决定安装器往哪写、systemd 单元、配置、数据目录该落哪；避免写进"重启即清空"的目录。
- **怎么查**：`ls -l /bin`（是否指向 `/usr/bin`）；`stat -fc %T /tmp`。

---

## 四、进程 / 服务运行期（systemd 深水区）

`04` 第五节讲了 systemd 基础与"没用加固指令"。下面是运行期真正会咬人的几处。

### ⭐ `Type=simple/forking/notify` 与 `sd_notify`

- **是什么**：服务类型决定 systemd **怎么判定"启动成功"**。`simple`：`ExecStart` 一 fork 就算起（哪怕进程 1 秒后就崩）；`forking`：等父进程退出；`notify`：等程序主动 `sd_notify(READY=1)` 才算就绪。
- **PI 为什么关心**：**和 **`03`** R-1「软失败仍报成功」同源**——`Type=simple` 下 systemd 报 active，不代表应用真的能干活。这正是 **`01` 最小验证集** 第 5 项要求「服务真 active」还不够、第 6 项要求「能连上建库」的原因。要"起来即可用"得用 `notify` 或加 readiness 探测。
- **怎么查**：`systemctl show <svc> -p Type`；`systemctl status <svc>` 看是否秒起秒退（`active (running)` vs 反复 restart）。

### ⭐ 能力位 capabilities（`CAP_NET_BIND_SERVICE` 等）

- **是什么**：把 root 的"全能"拆成细粒度能力。经典用途：给一个非 root 进程授 `CAP_NET_BIND_SERVICE`，**不当 root 也能绑 <1024 端口**。
- **PI 为什么关心**：**直接服务于服务降权整改**——`tafsvc` 改 `User=pi_app` 后若需绑低端口，capabilities 是不用 root 的正解（比 setuid 干净）。降权的连带影响见 **`03`** R-11：短信猫串口访问就是被同一次降权切断的，那一处的正解是补 `dialout` 附加组而非 capabilities。
- **怎么查**：`getcap <文件>`；`setcap 'cap_net_bind_service=+ep' <文件>`；systemd 单元里 `AmbientCapabilities=`。

### `tmpfiles.d` / `sysusers.d`

- **是什么**：声明式地建目录/临时文件（`tmpfiles.d`）、建系统用户（`sysusers.d`），由 systemd 在启动/装包时执行——替代脚本里手搓 `mkdir`/`useradd`。
- **PI 为什么关心**：比安装脚本命令式建目录/建用户更健壮（幂等、权限一致）；是"声明式"的现代做法，值得知道存在。
- **怎么查**：`/usr/lib/tmpfiles.d/*.conf`、`/usr/lib/sysusers.d/*.conf`；`systemd-tmpfiles --create`。

### ⭐ OOM killer / `oom_score_adj` 与 THP（透明大页）

- **是什么**：内存耗尽时内核**杀进程**（OOM killer），按 `oom_score` 挑目标。**THP**（Transparent Huge Pages）是自动大页机制，对数据库常是**负优化**（延迟毛刺）。
- **PI 为什么关心**：**命中 `ze.log` 内存耗尽 bug**（**`bugs/ze-duplicate-register-db-io-stall.md`**（内部真源，不随本目录））与 PG 在 Linux 7.0 上的吞吐回归（**`03`** R-8 已把「现场慢先查 huge pages」定为 26.04 的残余风险处置）。进程"莫名消失"多半是被 OOM 杀了。
- **怎么查**：`dmesg | grep -i 'killed process'`（看谁被 OOM 杀）；`cat /sys/kernel/mm/transparent_hugepage/enabled`；PG 建议 `never` 或改 huge pages。

### ⭐ fsync/fdatasync 持久化、page cache、dirty ratio、I/O 调度

- **是什么**：写文件默认先进 **page cache**，`fsync`/`fdatasync` 才真正落盘。`vm.dirty_ratio` 控制脏页比例；I/O 调度器（`mq-deadline`/`bfq`/`none`）影响延迟。
- **PI 为什么关心**：**命中 tafdb checkpoint fsync 卡死 + HDD I/O 饱和那个 bug**（**`bugs/ze-duplicate-register-db-io-stall.md`**（内部真源，不随本目录））。数据库的持久化和这套内核参数强相关，这也是 [`02` D 组](os-dependency-contract-surfaces.md#d-组--运行期基线不用于范围决策) 把磁盘 `ROTA` 列为必采的原因。
- **怎么查**：`cat /proc/sys/vm/dirty_ratio`；`cat /sys/block/<dev>/queue/scheduler`；`iostat -x 1`（看 `%util` 饱和）。

---

## 五、打包系统内部

### rpm scriptlets vs dpkg maintainer scripts

- **是什么**：装/卸包时会跑的钩子脚本。RPM：`%pre`/`%post`/`%preun`/`%postun`。DEB：`preinst`/`postinst`/`prerm`/`postrm`。建用户、建目录、注册 systemd 单元多在这里发生。
- **PI 为什么关心**：解释了"装个 `postgresql-server` 包，为什么就自动有了 `postgres` 用户和服务单元"——就是 scriptlet 干的（对比 `04` 第七节 Ubuntu 的 `pg_createcluster` 自动建库）。
- **怎么查**：`rpm -q --scripts <pkg>`；`dpkg-deb -e <deb> && cat DEBIAN/postinst`。

### `update-alternatives`

- **是什么**：Debian/Ubuntu 的**多版本共存与默认选择**机制（如同机多个 `java`/`postgresql`，用符号链接切换默认）。
- **PI 为什么关心**：与 `postgresql-common` 的多版本框架一脉；理解 Ubuntu 侧"哪个 PG 是默认"时会用到。
- **怎么查**：`update-alternatives --list java`；`update-alternatives --display <name>`。

---

## 六、经典陷阱（偏门但业界共识）

> 这些是"看起来不可能、老手都栽过"的坑，与 Windows 上的 `cmd` 延迟展开同一档。

### 跨 Windows → Linux 编辑（你们正是在 Windows 上改脚本）

- ⭐ **CRLF 行尾 + shebang** → `bad interpreter: No such file or directory`：文件明明存在却报找不到解释器，真因是 `#!/bin/bash\r` 结尾那个隐藏的 `\r`。**头号阴间坑。**
  - **怎么查 / 怎么防**：`file <脚本>` 显示 `CRLF line terminators`；`cat -A <脚本>` 看行尾 `^M$`；`dos2unix <脚本>` 修复；`.gitattributes` 里给 `*.sh` 设 `text eol=lf`。
- ⭐ **`/bin/sh` 在 Ubuntu 是 dash、在 RHEL 是 bash**：脚本写了 bashism（`[[ ]]`、`arrays`、`source`）却用 `#!/bin/sh`，在 Ubuntu 上静默跑挂。
  - **怎么防**：需要 bash 特性就明写 `#!/bin/bash`；或用 `checkbashisms` 扫描；`ls -l /bin/sh` 看它指向谁。
- **大小写敏感文件系统**：Windows 不敏感、Linux 敏感。`Config.xml` vs `config.xml` 在移植时即炸。
  - **怎么防**：统一命名规范；git 里注意 `core.ignorecase`。

### Shell 语义坑

- ⭐ **`set -e` 不按你想的来**：在 `if 条件`、`||`/`&&` 短路、**管道中间段**（无 `set -o pipefail`）、命令替换里**都不触发**。
  - **PI 相关**：正是 **`03`** R-1「`|| log [WARN]` 吞掉真实失败」的语言级根因——`set -e` 救不了 `cmd || log`，因为 `||` 短路本就不触发它。
  - **怎么防**：`set -euo pipefail` 三连；关键命令显式检查返回码。
- ⭐ **未设变量 → `rm -rf "$FOO/"` 变 `rm -rf /`**：`$FOO` 为空时灾难（著名的 Steam 删库事件）。
  - **怎么防**：`set -u`；删除前 `[ -n "$FOO" ] || exit 1`；用 `${FOO:?未设置}`。
- **locale 影响 `sort` / `[a-z]` / `printf` 小数点**：客户机 `LANG` 不同 → 排序结果、字符范围、数字解析（逗号 vs 句点小数）全变，典型"我机器上是对的"。
  - **怎么防**：脚本里对确定性操作显式 `export LC_ALL=C`。

### 加载 / 运行期偏门

- ⭐ **`/tmp` 挂 `noexec` 或为 tmpfs** → 解包到 `/tmp` 再执行的安装器直接失败（`Permission denied`）。
  - **PI 相关**：命中 IA 解包执行；对应 [`02` A 组](os-dependency-contract-surfaces.md#a-组--决定装不装得上) 的 `/tmp` 挂载选项与 `fapolicyd` 两项采集，风险记于 **`03`** R-10。
  - **怎么查**：`mount | grep /tmp`（看 `noexec`）；必要时用 `TMPDIR` 指向可执行目录。
- **`cannot allocate memory in static TLS block`**：启动后 `dlopen` 一个用了静态 TLS 的 `.so` 才炸——极偏门。
  - **PI 相关**：短信猫这类运行期 `dlopen` 原生库的场景可能撞上。
  - **怎么防**：`LD_PRELOAD` 提前加载该库，或库改用动态 TLS 模型。
- ⭐ **`Text file busy`（ETXTBSY）**：覆盖一个**正在运行**的可执行文件时报错。
  - **PI 相关**：升级/重装安装器、替换运行中的 JRE/PG 二进制的经典坑。
  - **怎么防**：先停服务再替换；或先 `mv` 旧文件（unlink）再写新文件。
- **`ldd` 会实际触发加载器**：对不可信二进制跑 `ldd` 有执行风险；且它**只查库在不在、不查符号版本够不够**（见 `04` 第三节）。
  - **怎么防**：查依赖用更安全的 `objdump -p <文件> | grep NEEDED`。

### "看起来不可能"的系统坑

- ⭐ **磁盘还有空间却 `No space left on device`** → **inode 耗尽**（海量小文件把 inode 用光）。
  - **怎么查**：`df -i`（看 IUse%），不是 `df -h`。
- **`Argument list too long`（E2BIG）**：参数 + 环境变量总长超内核上限。
  - **怎么防**：`find ... | xargs`；`getconf ARG_MAX` 看上限。
- **`Too many open files`**：进程打开的 fd 数超 `ulimit -n`。
  - **怎么查 / 防**：`ulimit -n`；systemd 单元里 `LimitNOFILE=`。
- **32 位 `off_t` / 大文件支持（LFS，>2GB）**、**Y2038**（见 `04` 第九节）：老 ABI 遗留坑一族——处理 >2GB 文件的老 32 位程序可能 `EFBIG`/溢出。
  - **PI 相关**：PI 仅 x86_64，`off_t`/`time_t` 本就是 64 位，基本免疫；知道这族坑的存在即可。

---

## 七、PI 的 Linux PostgreSQL 为什么落在 `/var/lib`、由包管理（演进背景与取舍）

> 本节是**成因解释**（不是新决策）：为什么 Linux 上 PG 数据在 `/var/lib`、数据目录与服务名交给 rpm/deb，而 Windows 是嵌入式。决策真源仍在 **`06`**、**`plans/linux-ze-fix-plan.md`**（内部真源，不随本目录）、**`migration-tasks/10-mongodb-to-postgresql-plan.md`**（内部真源，不随本目录）；这里把散落各处的来龙去脉收成一处，供再被追问（含 PRR/Mark）时引用。

### 7.1 版本演进：PG 的「角色」从单 OS 引擎库 → 多 OS 产品主库

| 阶段 | 产品主库 | 引擎 | 引擎自带库 | PG 的部署面 |
|------|---------|------|-----------|-------------|
| **PI3.0** | MongoDB | IE Engine | **PG（单 OS）** | 只跑在 **CentOS 6.7** 一个环境 → **不存在 ABI 矩阵** |
| **PI4.0** | **PostgreSQL 18** | Zero Engine | **SQLite**（几乎无环境要求） | **横跨 RHEL 8/9/10 + Ubuntu Desktop** → ABI 矩阵首次出现 |

**最容易理解错的一点 —— 不是「环境变多让老问题恶化」，而是 PG 的角色整个换了：**

- PI3.0 里 PG 是 **IE 引擎的私有库**，只需在**一个** OS（CentOS 6.7）上跑起来——「一份二进制」天然够用。**不是当年解决了 ABI，而是根本没有矩阵。**
- PI4.0 做了两件事：① 产品主库 MongoDB → PG18；② 原来「需要 PG」的 IE 换成了 ZE，引擎库 PG → SQLite（无环境要求）。
- **净效果 = PG 从「单 OS 引擎私有库」膨胀成「必须横跨整个 RHEL/Ubuntu 矩阵的产品主库」** —— ABI 矩阵问题就是在这一刻第一次出现的。

> 版本细节：旧引擎那套 PG，迁移 CI 里删掉的是「旧 PG10 staging」（见 **`migration-tasks/10`**（内部真源，不随本目录） Phase 1）。与本节结论无关，仅备查。

### 7.2 根因：为什么 Linux 一包不能通用，而 Windows 可以

**ABI 硬边界在大版本之间**（实测数据见 [`02` 附录 A.5](os-dependency-contract-surfaces.md#a5-实测基线2026-09-11-正式跑验回填)，机制见 [`04` 第一节](linux-dependency-glossary.md#一最基础的一组abi共享库soname符号版本)）：

| 边界 | glibc | libicu soname | OpenSSL soname |
|------|-------|---------------|----------------|
| RHEL 8 ↔ 9 | `2.27 → 2.34` | `so.60 → so.67` | `1.1 → 3` |
| RHEL 9 ↔ 10 | `2.34 → 2.38` | `so.67 → so.74` | 同为 `.so.3` |

一份预编译的 `postgres` 二进制**无法横跨这些边界**（缺符号 / 缺 soname，且兼容是单向的：老系统构建的能跑新系统，反之必然缺符号）。而 **Windows 只有一个 x64 ABI**，EDB 的可重定位 zip 一份跑遍所有支持的 Windows 版本 —— 这是 Windows 的特权，Linux 没有。

**最硬的实证**：即便已经靠 OS 包管理器，仅一个**间接依赖** `liburing` 就在 el9 各小版本间造成「装成功却跑不起来」（见 **T-1/T-2** / [`02` 附录 A.6](os-dependency-contract-surfaces.md#a6-pg-18-的-liburing-硬依赖2026-09-11-实证)）。若改成自打包嵌入式，要**自己**背 liburing、libicu、openssl、krb5、ldap… 十几个 `.so` 跨整个矩阵 —— 不可维护。这条正是「包管理 vs 嵌入式」取舍的经验底座。

### 7.3 为什么选「包管理」：数据目录 / 服务名交给 rpm/deb

选择的实质：**把 OS 特异性甩给该 OS 的包**。数据目录、服务单元、`postgres` 用户、依赖闭包全由对应版本的 rpm/deb 负责，安装器不再手动把 PG 数据重定向到用户输入目录。

一个常被忽略的事实：**Linux 上原本残留过一套「绑应用目录」的类嵌入式布局**（用户 `tafusr`、数据 `/var/opt/trellisappmgr/db`、SysV `init.d-tafdb`），但它**早已是个「根本没在驱动真实库的坏壳」**（**`plans/linux-ze-fix-plan.md` §四之五-N**（内部真源，不随本目录））。所以「改用包管理」同时也是**替换掉一个已经坏掉的旧做法**，不是推翻一个能用的方案。

**`/var/lib` 是副产品，不是自由选的位置** —— 它是包管理方式的默认归宿：

- **RHEL**：`postgresql-18-setup initdb` 默认 `PGDATA=/var/lib/pgsql/18/data`；
- **Ubuntu**：`postgresql-common` 在**装包 postinst** 阶段就自动把簇建在 `/var/lib/postgresql/18/main`（**在安装脚本运行之前**）。

### 7.4 为什么「重定向回用户目录」技术难、收益小（详细）

> 这是之前反复疑惑的点，展开讲。核心一句：**包管理的 PG，数据位置的所有权在「包 + OS 惯例」手里；OS 的安全策略与工具链都围绕默认路径接线。你要挪它，就是逐 OS 跟整个生态对着干。**

只有两条路，都不划算：

**路 A：回到嵌入式（数据进用户目录，像 Windows）**
→ 等于把 **7.2** 的 ABI 噩梦原样招回，且离线下要自己扛全部间接依赖。对「多 RHEL + Ubuntu + 离线」基本不可行，直接否掉。

**路 B：仍用包二进制，但把 PGDATA 重定位到用户目录** —— 技术可行，但要逐 OS 打仗：

RHEL 三处：
1. **PGDATA 位置**由 `postgresql-18.service` 的 `Environment=PGDATA=/var/lib/pgsql/18/data` 决定 → 要写 systemd drop-in 覆盖，并在新路径手动 `initdb`。
2. **SELinux（最硬的一处）**：`/var/lib/pgsql` 带着 `postgresql_db_t` 文件上下文，`postgresql-18` 服务是**受限运行**的。把数据放到用户目录（`/opt/...`、`/home/...`）是别的标签 → 服务被 SELinux **拒绝读写、起不来**。得对每个自定义路径 `semanage fcontext -a -t postgresql_db_t "<dir>(/.*)?"` + `restorecon`，依赖 `policycoreutils-python-utils`，在 enforcing 下极易翻车。
3. 备份 / 升级 / 运维工具都假设默认路径，一挪全要重测。

Ubuntu：
- 簇是 `postgresql-common` 在 postinst **自动建**在 `/var/lib/postgresql/18/main` 的（**脚本跑之前就建好**），整套框架（`pg_ctlcluster` / `pg_lsclusters` / `pg_createcluster`、`postgresql@18-main` 单元、`/etc/postgresql/18/main` 配置）都硬接线到该布局 → 要 `pg_dropcluster 18 main` 再 `pg_createcluster -d <userdir> 18 main`，元数据仍留在 `/etc/postgresql`，从此偏离所有发行版假设与 apt 升级钩子。

**收益几乎为零**：「数据进用户目录」只换来 (a) 与 Windows 的 UI 对称、(b)「删数据目录」提示顺带删库。两者都不是真实需求 —— keep-data 重装靠 **nonce 复用**（`PiSetupAction.resolveOrCreateNonce` + `/var/lib/vertiv/machine-secrets` 保险库）已经能工作，而 PG 数据落在 OS 标准路径反而是 Linux 管理员**更预期**的样子。

**净账**：为一个**装饰性**收益，付出**逐 OS 的 SELinux 重打标 + 单元覆盖 + 对抗 postgresql-common** 的长期成本 —— 方向正好与「选包管理是为了甩掉 OS 特异性」相反。

### 7.5 用包管理统管多环境 PG 的收益

> **这些「收益」都是相对「我们自己打一份嵌入式 PG」而言的。** 先厘清「嵌入式」到底指什么：**嵌入式 = 由我们自己打包、自带、解压到安装目录运行的 PG 二进制**（就像 Windows 那个 zip）。**它不等于「一份通用包」**——因为 ABI 跨 Linux 版本不通用（见 **7.2**），嵌入式在 Linux 上要么幻想「一份跑遍所有」（做不到），要么**为每个 OS 各打一份、由我们维护**。而包管理是把二进制及其依赖、摆放、安全策略、服务框架**全交给 OS 的官方包**。下面每条都点明「对比嵌入式省了什么」。

1. **ABI 由 OS 背**：每个 OS 的包用**该 OS 自己的工具链**编译，glibc/libicu/openssl 天然匹配。→ 对比嵌入式：否则「这份二进制能不能在这个 OS 上跑」的 ABI 匹配责任全落在**我们**头上，得为每个环境各编译 / 各维护一份可重定位二进制。
2. **依赖闭包由包声明（= 不用手追 `.so`）**：一个 PG 程序运行时要依赖 libicu / openssl / liburing / krb5 / ldap… 十几个 `.so`，而这些库自己还依赖别的库（是一棵**依赖树**）。包管理下 `rpm`/`dpkg` 按包声明**自动拉齐并校验**这棵树；嵌入式下这棵树**全得我们自己盯**，漏一个或版本错一个，就是客户现场「装上了却起不来」。→ **具体场景就是 liburing 事件**：我们已经在用 OS 包了，仅一个**间接依赖** `liburing` 在某些 el9 机上缺失就让 PG 起不来（**T-1/T-2**）；若自己整嵌入式，这种「手追 .so」要对十几个库、跨整个 OS 矩阵重复做。
3. **安全补丁路径**：客户可走 OS 渠道给 PG 打 CVE 补丁；嵌入式则每次都要**我们**重新发版。
4. **MAC 策略现成**：MAC = **强制访问控制**（Mandatory Access Control），即 RHEL 的 **SELinux** / Ubuntu 的 **AppArmor**，它们限制「某个服务只能读写哪些路径」。因为 PG 装在**系统默认路径**，**OS 早已为该路径写好放行策略**，PG 一装即能正常读写、启动，**我们不用自写安全策略**。（反之把数据挪到用户目录，SELinux 未放行 → PG 被拦得起不来，正是 [7.4](#74-为什么重定向回用户目录技术难收益小详细) 说重定向难的原因之一。）
5. **systemd / journald / 开机自启**：PG 作为标准系统包**自带 systemd 服务单元**，于是「开机自启 / 崩溃自动重启 / 日志进 journald」都是现成的，我们只需一句 `systemctl enable` 就有，**不用自写 init 脚本 / 服务框架**。
6. **运维认知一致**：管理员预期 PG 在 `/var/lib`、用 `systemctl` 管，符合直觉。

### 7.6 RHEL vs Ubuntu：除数据目录 / 服务名外的其它区别

| 维度 | RHEL（PGDG rpm） | Ubuntu（PGDG deb） |
|------|------------------|--------------------|
| 数据目录 | `/var/lib/pgsql/18/data` | `/var/lib/postgresql/18/main` |
| 主服务单元 | `postgresql-18`（真单元） | `postgresql`（伞状 meta）+ `postgresql@18-main`（真实例） |
| 簇初始化 | **手动** `postgresql-18-setup initdb` | 装包 postinst **自动** `pg_createcluster` |
| 装完是否自动起 | 否（需显式 initdb + start） | **是**（postinst 已在 5432 起） |
| 配置文件位置 | 数据目录内 `/var/lib/pgsql/18/data/postgresql.conf` | **与数据分离** `/etc/postgresql/18/main/` |
| bin 路径 | `/usr/pgsql-18/bin` | `/usr/lib/postgresql/18/bin` |
| 改端口后重启谁 | `systemctl restart postgresql-18` | `systemctl restart postgresql@18-main`（重启伞状 meta **不**重启实例） |
| 多簇管理框架 | 无（单实例） | **postgresql-common**（pg_lsclusters / pg_ctlcluster / pg_createcluster / pg_dropcluster） |
| 保留数据卸载 | `rpm -e` 只删二进制、留 `/var/lib/pgsql` | **必须 `dpkg --remove`（非 purge）** —— purge 的 debconf 默认会连数据一起删 |
| 包按什么分 | 按 OS **小版本**（rhel9.6/9.7/9.8/10.0/10.1/10.2） | 按 **LTS**（pgdg24.04 / pgdg26.04） |
| 强制访问控制 | **SELinux**（`postgresql_db_t` 绑在 /var/lib/pgsql） | **AppArmor**（较宽松） |
| 缺库事件 | `liburing` 硬依赖（el9，见 **T-1/T-2**） | Desktop 依赖闭包一般已带 |

> **「簇」（cluster）是什么**：PG 的术语，**不是**多机/高可用集群，而是「**一份 `initdb` 初始化出的数据目录 + 住在里面的一组数据库 + 管它的一个 PG 进程**」。RHEL 上其实也有簇（`/var/lib/pgsql/18/data` 就是），只是 **Ubuntu 把「簇」做成了显式、有工具管理的概念**——`postgresql-common` 支持同机并存多个「版本+名字」的簇（如 `18/main`），并配 `pg_createcluster`/`pg_dropcluster`/`pg_lsclusters`/`pg_ctlcluster` 与 `postgresql@18-main` 模板单元；RHEL 无这套多簇框架，就是单实例。

> **`tafdb` ≠ 开机自启的来源**：PG 的开机自启来自 **PG 自带的 systemd 单元 + 安装器显式 `systemctl enable postgresql-18`/`postgresql`**（`pi-linux-install.sh` §4）。`tafdb` 是另加的一层**瘦别名**（空壳 `ExecStart=/bin/true`，仅 `Requires=`/`After=` 真 PG 单元），目的只是**运维命名一致**——让 `systemctl status/start tafdb` 在 RHEL 和 Ubuntu 上都能用、都指向真库（历史上 RHEL 有遗留 SysV `tafdb` 可见、Ubuntu 无）。`start tafdb` 会经 `Requires=` 顺带把真 PG 拉起，但它**不是自启来源**。详见 **`plans/linux-ze-fix-plan.md` §四之五-N**（内部真源，不随本目录）。

---

## 八、自定义安装目录：为什么装 `/home` 下会崩、装 `/opt` 就行（DAC 穿越权，非 SELinux）

> 本节回答一个反复被问的现场问题：**PI4.0 在 Linux 上自定义安装为什么装到 `/opt` 才行、装到用户家目录（`/home/<user>/...`）就起不来。** 结论真源见 **`security-fix/02-implementation-roadmap.md` N-32「现场①/②」**（内部真源，不随本目录） 与 N-22（CHDIR 修复）。

### 8.1 现象与根因（一句话）

装到 `/home/vertiv/wjt/main` → `tafsvc` 反复 `status=200/CHDIR`、重启风暴、PI 不可用。**根因是纯 POSIX 权限（DAC），不是 SELinux**：

- `tafsvc.service` 以 `User=pi_app / Group=pi` 运行，`WorkingDirectory` 与 `ExecStart`（`jre/bin/java`）都在安装根下。
- 家目录 `/home/<user>` 默认 **`700`（RHEL）/ `750`（Ubuntu 21.04+）**、**属主是登录用户本人**。`pi_app` 既非属主也不在其组 → 落 `other`、**连穿越（`x`）位都没有** → systemd 切 `WorkingDirectory` 失败、`java` 也 exec 不了 → `200/CHDIR`。
- **安装器不能也不该去改用户家目录的权限**，所以家目录下无解；`/opt` 下则能靠 chown/chmod 自救（见 8.4）。

### 8.2 「纯 POSIX / DAC」是什么，与 SELinux 有何区别

Linux 文件访问是**两层叠加**、缺一不可：

| 层 | 名称 | 机制 | 谁定 |
|---|---|---|---|
| 第一层 | **DAC**（自主访问控制）= 传统 **POSIX 权限** | `owner/group/other` × `rwx`（即 `ls -l` 的 `rwxr-xr-x`、`chmod 755`） | 文件属主 |
| 第二层 | **MAC**（强制访问控制）= **SELinux**（RHEL）/ AppArmor（Ubuntu） | 给进程/文件打「标签·上下文」，按策略放行，属主也改不了 | 系统安全策略 |

「**纯 POSIX 问题**」= 访问在**第一层 DAC 就被拒**，根本轮不到 SELinux 出场。对**目录**而言，关键是 `x` 位——在目录上它不表示「执行」，而是**「穿越 / 进入」（traverse）**：没有某级目录的 `x`，就进不去它、也访问不到它里面的任何路径（哪怕里面文件是 `777`）；访问深路径**要求从 `/` 到目标的每一级父目录都对该账户有 `x`**。

**本例已实证不是 SELinux**：`tafsvc` 运行域是 `unconfined_service_t`（RHEL 9.7 + Enforcing 实测，见 **`03` R-4**），即 SELinux 对它基本不设限；拦它的是家目录的 `700/750` 模式位。SELinux 在 PI 里确实是「最硬的一处」，但管的是**另一件事**——PG 数据目录不能挪出 `/var/lib/pgsql`（`postgresql_db_t` 上下文，见 [7.4](#74-为什么重定向回用户目录技术难收益小详细)），与本节的安装目录问题无关。

#### 8.2.1 关键机制：路径逐级解析 → 为什么「装得上却起不来」，且子目录再宽松也没用

理解本节所有现象，只需一条内核事实：**解析一个路径是从 `/` 起逐级向下检查目录 `x`（穿越）位的**。要访问 `/a/b/data/jre/bin/java`，内核先要能进 `/a`、再进 `/a/b`、再进 `/a/b/data`……**任何一级缺 `x`，当场 `EACCES`，根本不会往下走。**

**推论一：宽松的子目录救不了受限的父目录。** 设想「父目录 `750`、数据目录 `755`」——这个 `755` 完全没用，因为要「用上」它，得先穿过它 `750` 的父目录，而这一步就被挡死。**一个宽松的叶子，补偿不了一个受限的祖先。**

**推论二：区分「安装期」与「运行期」两个时点，才解释得了「装得上却起不来」。**

| 时点 | 以谁的身份跑 | 结果 |
|---|---|---|
| **安装期** | **root**（有 `CAP_DAC_OVERRIDE`，绕过所有 DAC 检查） | **装得上**——不管父目录是不是 `750`，root 都能穿进去铺文件、做 chown/chmod。文件安装本身不会失败（唯一例外：安装末尾 `systemctl start tafsvc` 那步会失败） |
| **运行期** | **pi_app**（低权服务账户） | **起不来**——systemd 启 `tafsvc` 的顺序是「fork → 降权成 pi_app → chdir 到 `WorkingDirectory` → exec `jre/bin/java`」，**chdir 与 exec 都在降权之后**；pi_app 穿不过 `750` 父目录 → chdir 失败 → `status=200/CHDIR` |

这正是 **N-32「现场①」**（内部真源，不随本目录） 装 `/home` 的表现：**装完了**，然后服务反复 `200/CHDIR`，而不是装的时候就报错。

**推论三：`java` 自身是不是 `755` 完全不相关。** 内核在解析 `.../jre/bin/java` 时，会先逐级查每个父目录的 `x`，在那个 `750` 父目录处就 `EACCES` 了——**压根走不到检查 `java` 自己权限那一步**。够不着它，它的权限再对也没用。

**除「祖先缺 x」外，即使路径全可穿越，仍有几类会起不来**（都在工程里踩过）：

| 原因 | 机制 | 出处 |
|---|---|---|
| **目标目录本体对 pi_app 缺 `x`** | `/opt/trellisappmgr`（含 `jre/`、`WorkingDirectory`）出厂 `root:root 764` → pi_app 落 other 仅 `r--`（**无 x**）→ 同样 `200/CHDIR`。这不是祖先问题，是**目标自己**缺 x | **N-22**（内部真源，不随本目录），修法 `chgrp -R pi + chmod -R g+rX "$INSTALL_DIR"` |
| **数据目录没 chown 给 pi_app** | 写不进 `data/certs`（`core-trust.jks` `Permission denied`）、进不去 `data/system` → 主线程崩、登录卡 0% | **N-32「现场②」**（内部真源，不随本目录） |
| **读不到 jar / 执行不了 java** | exec 需 java 有 `x`、读 jar 需 `r`；`g+rX` 里的 `X` 就是「只给目录与已有可执行文件加 x」 | N-22 同处 |
| ~~SELinux~~ | tafsvc 运行域 `unconfined_service_t`，**已实测排除** | **`03` R-4** |

> 这也再次印证「待在 `/opt` 下」这条简化规则为什么安全——祖先链（`/` → `/opt`）天然全是 `755`，把「父目录缺 x」这一整类问题从根上避免了。

### 8.3 那 `/var` 或其他目录呢？判定只有一条规则

**从 `/` 到安装目标的每一级父目录，`pi_app` 是否都有 `x`（穿越）位。** 缺任何一级即崩，与目标目录本身权限无关。

| 安装位置 | 关键父目录默认权限 | `pi_app` 能否穿越 | 结论 |
|---|---|---|---|
| `/opt/<...>` | `/opt` = `755` | ✅ `other` 有 `x` | **可用**（实测） |
| `/var/<...>`、`/usr/local/<...>`、`/srv/<...>` | 均 `755` | ✅ | **可用**（同理推导，见下方置信度） |
| `/home/<user>/<...>` | `/home/<user>` = `700`/`750`、属主为用户 | ❌ `pi_app` 落 `other`、无 `x` | **崩**（实测 `200/CHDIR`） |
| `/root/<...>` | `/root` = `700` | ❌ | **崩**（同类） |

**所以准确说法不是「只能装 `/opt`」，而是：装在任意「世界可穿越」的路径（`/opt`、`/var`、`/usr/local`…）都行；只有装进家目录、`/root` 这类受限私有目录才会因 `pi_app` 穿越不进去而崩。** 文档把它定性为「使用姿势问题（装 `/opt` 即免）」。

> **置信度**：`/home` 与 `/opt` 是工程**实测**过的；`/var` 等属于按同一套 DAC 穿越原理**推导**的高概率结论（记录里未逐一实测）。原理确定，唯一变数是某台机上某级父目录被管理员改成了非默认的受限权限。

### 8.4 能穿越 ≠ 该装：`/opt` 是 FHS 规范首选

8.3 讲的是**技术闸门**（能不能起来）；这里补上**规范层面**（该不该装）——两者结论不同：**可穿越的目录不止一个，但符合 Linux 目录规范（FHS，Filesystem Hierarchy Standard）的首选只有 `/opt`。**

| 位置 | 技术（能穿越？） | 规范（该不该装？） |
|---|---|---|
| `/opt/<...>` | ✅ | ✅ **首选、最符合规范** |
| `/usr/local/<...>` | ✅ | 🟡 勉强次选，语义偏（见下） |
| `/srv`、`/var/<...>` 等其他 `755` 目录 | ✅ | 🔸 能跑但**不推荐**、不合惯例 |
| `/home/<user>`、`/root` | ❌ | ❌ 既不能也不该 |

**为什么 `/opt` 是规范答案**：FHS 对 `/opt` 的定义就是「安装**附加的、自成一体的第三方应用软件包**」。PI4.0 正是这种形态——自带 JRE、自带 PG 二进制、自成一棵目录树、不靠发行版包管理器铺进 `/usr` → 放 `/opt` 是按定义对号入座。

对比另外两个也能穿越、但语义不对的位置：

- **`/usr/local`**：FHS 定义是「本机管理员**从源码编译安装**、按 `bin`/`lib`/`share` **散开铺放**的软件」，假设文件拆进 `/usr/local/bin`、`/usr/local/lib`…，而非整棵自包含子树。PI 这种「一整包」放这里语义偏了，虽能跑。
- **`/var`**：FHS 定义是「**可变数据**」（日志、数据库数据、缓存、spool）。放**程序本体**进 `/var` 是语义错位——PI 的**可变数据**本就该在 `/var`（实际 PI 数据目录 = `/var/opt/pi`、PG 数据 = `/var/lib/pgsql`），但**程序**不该在这。

**这正好解释了 PI 现在的布局**：**程序**在 `/opt/trellisappmgr`、**可变数据**在 `/var/opt/pi` 与 `/var/lib/pgsql`——就是按 FHS「程序归 `/opt`、数据归 `/var`」分开摆的。

### 8.5 安装目录 / 数据目录的组合怎么选（两目录约束 + 常见误区）

Linux 上是**双主目录**（[runtime-permission §1.3](../2-design/runtime-permission-solution.md)）：

| 目录 | IA 变量 | Linux 默认值 | 放什么 |
|---|---|---|---|
| 安装目录 `INSTALL_DIR` | `$USER_INSTALL_DIR$` | **`/opt/trellisappmgr`** | 程序、JRE、DB 二进制、ZE 子树 |
| 数据目录 `DATA_DIR` | `$USER_MAGIC_FOLDER_2$` | **`/var/opt/pi`** | 应用数据、日志、插件 |

两条硬前提，决定所有组合的成败：

1. **安装器强制「两目录不能相同」**（面板硬校验）——填成同一路径会被拦、走不下去，所以不存在「相互覆盖到用不了」的结局。
2. **Linux 上「数据目录」里没有数据库** —— PostgreSQL 数据恒落在包管理默认路径 `/var/lib/pgsql/18/data`（RHEL）/ `/var/lib/postgresql/18/main`（Ubuntu），**与数据目录选择无关、也挪不动**（原因见 [7.4](#74-为什么重定向回用户目录技术难收益小详细)）。你选的数据目录只管应用数据/日志/插件，量小、重要性次一级。

**组合判定：**

| 方案 | 能跑？ | 规范？ | 说明 |
|---|---|---|---|
| 安装目录填**字面量 `/opt` 根** | ⚠️ 能穿越但**别这么做** | ❌ | 程序树平铺进 `/opt` 根，`chown -R`/卸载会波及 `/opt` 下无关内容，且与其他第三方软件混在一起 |
| 安装 + 数据填**同一路径** | ❌ 装不了 | ❌ | 触发「两目录不能相同」校验 |
| 安装 `/opt/<子目录>`，数据选**其他可穿越目录** | ✅ | 🟡 取决于数据放哪 | 数据放 `/var` 系才规范 |
| 在 `/opt` 下建专属父目录，安装/数据各建**兄弟子目录**（`/opt/pi/app` + `/opt/pi/data`） | ✅ | 🔸 可接受的软违规 | 见下方「两个常被问到的点」 |

**⭐ 首选（强烈建议）——直接用默认值：** `安装 /opt/trellisappmgr` + `数据 /var/opt/pi`。这是教科书级 FHS 布局（程序→`/opt`、可变数据→`/var/opt`），也是**唯一在 9 个目标 OS 上全部实测通过**的组合。

**若要自定义，守三条：** ① 安装目录用 **`/opt/<命名子目录>`**（别用 `/opt` 根、别用家目录）；② 数据目录用 **`/var/opt/<名字>` 或 `/var/<名字>`**（数据归 `/var`）；③ 两者**独立、不嵌套**（一个套在另一个里，会让 `chown -R`/卸载递归相互干扰——ZE 子树冲突就是这类问题，见 [runtime-permission §2.5 要点2](../2-design/runtime-permission-solution.md)）。

**两个常被问到的点：**

- **为什么安装目录必须是「命名子目录」、不能是 `/opt` 本身**：FHS 对 `/opt` 的约定就是每个应用住自己的 `/opt/<包名>`/`/opt/<厂商名>`。这样多个第三方软件在 `/opt` 下的正确共存形态是 `/opt/trellisappmgr`、`/opt/vendorX`、`/opt/vendorY` 各占一格、互不干扰。把内容平铺进 `/opt` 根会破坏这个隔离，也让 PI 的递归 chown/卸载误伤邻居。PI 默认值 `/opt/trellisappmgr` 本身就是对的做法。
- **数据目录放 `/opt/pi/data` 到底行不行**：是**可接受的软违规**。理由链成立——Linux 上真正的大头/关键数据是 PG，而 PG 恒在 `/var/lib`（不受此选择影响）；数据目录只装量小、次要的应用数据/日志/插件，放 `/opt` 下技术能跑、不至于出乱子，「说得过去」。残留代价只有两条：① 备份/监控/logrotate/配额等运维机制常按惯例只盯 `/var`，数据长在 `/opt` 下可能被漏掉；② 相比放 `/var` 没有任何正收益。所以能接受，但**若不嫌多敲一个路径，`数据 → /var` 仍是最无争议的写法**。

> **📖 面向最终用户的简化口径（用户手册采用此说法）**：不要求用户理解上面的「穿越权 / FHS」原理，只给一条保守且绝对安全的规则——
> **「PI 自定义安装时，安装目录与数据目录都放在 `/opt` 下自建目录里的两个平级子目录，例如安装目录 `/opt/wjt/main`、数据目录 `/opt/wjt/data`。」**
> 这条规则一次性替用户满足了 8.5 的全部硬性条件（都在 `/opt` → 每级父目录天然可穿越、自动绕开家目录 `700/750` 那个唯一会崩的坑；`main`/`data` 两目录不同且互不嵌套）。代价是「数据落 `/opt`」这一可接受软违规（因 PG 主数据在 `/var/lib` 兜底），换来的是**用户零理解成本、零出错空间**——对用户手册而言，可操作性 > FHS 洁癖，此取舍成立。（本节 8.1–8.5 讲的是**开发视角的原理**；用户手册只需给上面这条**可照抄的规则**。）

### 8.6 为什么 `/opt` 能用，不是白来的

即便在世界可穿越的路径下，也需要安装器把**自己铺下的那棵子树**授权给 `pi_app`，历史上两处都补过：

- **CHDIR（N-22）**：`/opt/trellisappmgr`（含 `jre/`、`WorkingDirectory`）出厂 `root:root 764` → `pi_app` 落 `other` 仅 `r--`（无 `x`）→ 同样 `200/CHDIR`。修法是安装期补 `chgrp -R pi "$INSTALL_DIR"` + `chmod -R g+rX "$INSTALL_DIR"`（组 `pi` 可读+遍历，不给写）。
- **自定义数据目录未 chown（N-32「现场②」）**：装 `/opt/wjt` 后登录卡 0%，因自定义数据目录整棵 `root:root` 未 chown 给 `pi_app`，写不进 `data/certs`（`core-trust.jks` `Permission denied`）→ 主线程崩。已在 N-32 #4 修复。

区别在于：**这些子树的属主是 `root`、安装器有权改**；而 `/home/<user>` 的属主是用户、安装器无权也不应改 → 这才是 `/opt` 能自救、家目录不能的根本差异。

### 8.7 现状：未加护栏

工程把「装 `/home` 崩」定性为使用姿势问题，提出过**装器护栏**（脚本内逐级父目录真穿越校验 + `setfacl -m u:$SVC_USER:--x`，或 UI 软告警），但**明确「本轮不做、留待定」**（见 N-32 六）。即：目前既不阻止也不告警，靠使用规范（装 `/opt` 等标准路径）规避。

---

## 附录：一条命令看部署相关基线

```bash
# 加载与库
file $(command -v java)                       # PIE? 最低内核? 静态/动态?
readelf -d $(command -v java) | grep RUNPATH  # 自带库怎么找
LD_DEBUG=libs java -version 2>&1 | head        # 完整库搜索过程

# 文件系统与限制
mount | grep -E '/tmp|/var'                    # noexec? tmpfs?
df -i /                                         # inode 是否将尽
ulimit -n                                       # 打开文件数上限

# 内核与内存
uname -r                                        # 内核版本
dmesg | grep -i 'killed process' | tail         # 近期 OOM
cat /sys/kernel/mm/transparent_hugepage/enabled # THP 状态

# 脚本行尾（在 Linux 上验收 Windows 编辑的脚本）
file install-*.sh | grep -i crlf && echo "⚠ CRLF 行尾，需 dos2unix"
```
