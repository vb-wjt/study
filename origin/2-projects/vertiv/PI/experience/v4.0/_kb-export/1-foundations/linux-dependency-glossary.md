# 04 · Linux 依赖术语详解

> **本文件的作用**：把 [`02-os-dependency-contract.md`](os-dependency-contract-surfaces.md) 与 **`03-os-risk-and-open-items.md`** 里出现的 Linux 专有名词讲清楚——**每个术语说明它是什么、PI 为什么关心它、怎么在机器上查**。
> 面向不需要深入 Linux 内部机制、但要读懂版本差异结论的人。**纯参考资料，不含决策与结论。**
> 📎 想扩展到"部署/运行时的更多机制与经典陷阱"（`LD_PRELOAD`、glibc vs musl、`set -e` 坑、CRLF shebang、`/tmp noexec`…）→ 见 [`05-linux-deployment-gotchas.md`](linux-deployment-gotchas.md)。
>
> **最后更新**：2026-09-10

---

## 目录

- [一、最基础的一组：ABI、共享库、soname、符号版本](#一最基础的一组abi共享库soname符号版本)
- [二、运行时库：glibc、libstdc++、OpenSSL、libicu](#二运行时库glibclibstdcopenssllibicu)
- [三、查库的工具：ld.so、ldconfig、ldd](#三查库的工具ldsoldconfigldd)
- [四、包管理：RPM、DEB、NVR、--nodeps、releasever](#四包管理rpmdebnvr--nodepsreleasever)
- [五、系统服务与安全：systemd、SELinux、crypto-policies、cgroup、firewalld](#五系统服务与安全systemdselinuxcrypto-policiescgroupfirewalld)
- [六、网络工具：iproute2 / ss 与 net-tools / netstat](#六网络工具iproute2--ss-与-net-tools--netstat)
- [七、PostgreSQL 相关：PGDG、initdb、cluster、collation](#七postgresql-相关pgdginitdbclustercollation)
- [八、发行版生命周期：LTS、EUS、minor release](#八发行版生命周期ltseusminor-release)
- [九、Ubuntu 专属：t64 / time_t 迁移、`_all.deb`](#九ubuntu-专属t64--time_t-迁移_alldeb)
- [附录：一条命令看全貌](#附录一条命令看全貌)

---

## 一、最基础的一组：ABI、共享库、soname、符号版本

这四个概念是理解「为什么 RHEL 9.6 和 9.8 要用不同的 PostgreSQL 包」的全部基础。

### API 与 ABI

- **API**（Application Programming Interface）是**源码级**约定：函数叫什么名、收几个参数。API 兼容意味着**同一份源码能重新编译通过**。
- **ABI**（Application Binary Interface）是**二进制级**约定：函数参数怎么摆进寄存器、结构体各字段偏移多少字节、符号名怎么编码。ABI 兼容意味着**已经编译好的二进制不用重编就能继续跑**。

**PI 关心的是 ABI**，因为 PI 分发的是编译好的二进制（PostgreSQL 的 rpm/deb、自带的 JRE），不是在客户机器上现编译。

### 共享库（shared library）

`.so` 文件（Windows 上对应 `.dll`）。多个程序共用同一份库代码，程序启动时由动态链接器把库加载进来并把函数地址填好。

好处是省空间、库修 bug 后所有程序一起受益；代价是**程序对库的版本有依赖**——库变了程序可能就跑不了了。这个代价正是本目录一系列文档要处理的问题。

### soname

共享库的「**兼容性身份证**」。一个库文件通常有三个名字：

```
/usr/lib64/libssl.so.3.0.7     ← 真实文件（完整版本）
/usr/lib64/libssl.so.3         ← soname（符号链接）  ← 程序记住的是这个
/usr/lib64/libssl.so           ← 开发链接（编译时用）
```

编译程序时，链接器把 **soname**（`libssl.so.3`）写进可执行文件里；运行时动态链接器就去找这个名字。

**规则**：库作者做了破坏兼容的改动，就必须提升 soname（`libssl.so.1.1` → `libssl.so.3`）；只是修 bug 则保持 soname 不变。

**所以 soname 变化 = 硬边界**。一个链接了 `libssl.so.1.1` 的程序放到只有 `libssl.so.3` 的系统上，会直接因「找不到库」而启动失败。这就是 RHEL 8（OpenSSL 1.1.1，soname `.so.1.1`）与 RHEL 9/10（OpenSSL 3.x，soname `.so.3`）之间**必须用不同 PostgreSQL 包**的原因。

### 符号版本（symbol versioning）

比 soname 更细的一层机制。同一个 soname 内部，库还可以给每个函数打上「从哪个版本开始提供」的标记，形如 `OPENSSL_3.0.0`、`OPENSSL_3.4.0`、`GLIBC_2.34`。

编译程序时，链接器会把「我用到了 `OPENSSL_3.4.0` 这一版的某函数」记进二进制。运行时如果系统上的库**没有**这个版本标记，就报：

```
symbol lookup error: /usr/pgsql-18/bin/postgres: undefined symbol: ..., version OPENSSL_3.4.0
```

**这是理解本项目最关键的一点**：符号版本只会**新增**，不会删除。于是兼容关系是**单向的**——

| 构建环境 | 运行环境 | 结果 |
|---------|---------|------|
| 老版本（符号少） | 新版本（符号多） | ✅ 能跑（新系统包含老符号） |
| 新版本（符号多） | 老版本（符号少） | ❌ 缺符号，跑不起来 |

Red Hat 承诺「同一大版本内 ABI 兼容」，指的是**不提升 soname**；但 OpenSSL 在 RHEL 9/10 的小版本更新中**确实会新增符号版本**。所以在 9.8 上编译的 PostgreSQL 放到 9.6 上会缺符号——这正是 PGDG 要按小版本分别编译、PI 要按 `rhel9.6` / `rhel9.7` / `rhel9.8` 分目录打包的根本原因。

> ⚠️ 上表 ❌ 行严格说是**条件性的**，不是"一定"：见下面「运行时机制」的第 3 点。表里写"跑不起来"是把工程结论说绝对了，成立前提是"确实引用了老系统没有的那个符号版本节点"。

### 符号版本的运行时机制（严格版）

上面的"单向兼容"是结论，机制细节如下——理解它才能分清"什么会崩、什么不会崩、什么改进能自动吃到"。

**先分清两层**（别混在一起）：

- **soname**（`libc.so.6`）：库文件的"身份证"，只决定**加载哪个文件**；与符号版本是两码事。
- **符号版本节点**（`GLIBC_2.2.5`、`OPENSSL_3.4.0`）：soname 内部，给**每个函数**打的"从哪版起提供"标记。

**1. 构建时：记的是"精确字符串"，不是"范围"。** 链接器对你实际引用的每个函数，去**构建机**的库里查它当前的**默认**版本节点，把那个精确字符串焊死进二进制，例如 `memcpy@GLIBC_2.2.5`。它记的不是"≥2.2.5 都行"，而是"我要 `GLIBC_2.2.5` 这个具体节点"。

**2. 运行时：精确匹配，命中的正是那个老节点。** `ld.so` 按 soname 加载**现役**库，然后对 `memcpy@GLIBC_2.2.5` 这条要求，找库里**恰好**叫 `memcpy`、版本恰好 `GLIBC_2.2.5` 的符号。**它从不"看到有更新的就自动升级用新的"，也不会降级。** 老→新能跑，是因为**符号只增不删，老节点在新库里原封不动地留着**；新→老跑不了，是因为老库没有未来才出现的新节点（报 `version 'GLIBC_2.14' not found`）。

**3. 失败是条件性的（回答"是不是一定崩"）。** 是逐符号判定：只有当二进制引用了**至少一个**老系统缺的版本节点才崩。若你用到的函数及其所需节点在老系统上都在，就正常跑。工程上之所以按"高概率会崩"来防，是因为你无法预知自己（及第三方依赖）到底触到了哪些被升过版本的符号——只要几百个引用里有一个是新节点就炸。

**4. 标签 vs 实现：为什么老二进制能自动吃到新库的修复。** 符号版本节点只是个"门牌号/契约"，**门后挂的机器码是现役库里那份新代码**。所以你钉在 `malloc@GLIBC_2.2.5`，跑的却是新 glibc 里那份修过漏洞、加过硬化、或更快的 `malloc` 实现。动态链接的程序因此**自动获得系统库的安全/性能修复而无需重编**：

| 例子 | 你是否自动获得 | 为什么 |
|---|---|---|
| glibc CVE 修复（如 `getaddrinfo` CVE-2015-7547） | ✅ | 同名节点仍在，背后已是打过补丁的新代码 |
| `malloc` 堆加固 / bug 修复 | ✅ | 实现不在你二进制里，在现役库 |
| `memcpy`/`strlen` 按 CPU 选优（IFUNC） | ✅ | 加载时 resolver 现场挑最优实现 |
| 时区 / locale / iconv 数据更新 | ✅ | 运行时从系统加载 |
| **新增的 API**（老库没有的函数） | ❌ | 老库没这个符号，根本调不到 |
| **被显式版本化的行为分叉**（`memcpy@GLIBC_2.2.5` vs `@@GLIBC_2.14`） | ❌（保留老行为） | glibc **刻意**为兼容留了两份实现，钉老节点就拿老行为 |

> 对照：若程序**静态链接**了库，有漏洞的代码被焊进它自己，系统打补丁与它无关——必须重编。这正是"动态链接享受系统修复"的分水岭。

### 两种分发策略与两条铁律

"在最老目标构建"**不是普适真理，它只在"一份二进制覆盖多个版本"这个前提下成立。** 完整的图景是两种策略、两条规范：

| 策略 | 铁律 | 代价 / 收益 | PI 里的实例 |
|---|---|---|---|
| **A. 一份二进制覆盖全部版本** | **在最老目标上构建** | 兼容性满分；放弃新版本的**新 API** 与**编译期烤进去的优化**（但**不放弃**动态库的运行期修复，见上表） | **Zulu JRE**：一份 `linux64` 覆盖全部 9 个目标 |
| **B. 每个"兼容段"各一份** | **跑哪个版本就用在该版本（段）上构建的包** | 能吃到各版本的新特性/优化；代价是 N 套构建 + 测试 + 更大安装包 | **PostgreSQL**：PGDG 按 `rhel9.6/9.7/9.8` 分别编译 |

**判据**：这份二进制**是否被迫跨越有硬边界的多个版本**。JRE 自包含、不吃系统 OpenSSL/libicu，一份就够 → 走 A；PostgreSQL 动态链接系统 OpenSSL/libicu，小版本间有 soname/符号硬边界，一份跨不过去 → 被迫走 B。

**策略 B 的一个优化**：利用"符号只增不删 ⇒ 向后兼容"，**在版本 X 上构建 → 能跑在 X 及所有更新版本**。所以不必"每个版本都建"，只需在**每个兼容段的最老版本**上建一次。

> ⚠️ **本项目对 PGDG 为何细到每个小版本的解释，曾经是错的。** 原写「9.6/9.7/9.8 两两之间都至少有一条硬边界（OpenSSL 符号 / glibc rebase），每个小版本自成一段」——**实测表明这三版的 glibc、libicu、libstdc++、OpenSSL soname 四项完全相同**，RHEL 9 内部并不存在这样的硬边界（见 [`02` 附录 A.2](os-dependency-contract-surfaces.md#a2-已推翻的论据rhel-9-内部-glibc-并未-rebase)）。按实测，**兼容段的边界在大版本之间**（RHEL 8 / 9 / 10 各一段）。PGDG 仍按小版本发包是它自己的构建策略，我们照此分目录打包是对的做法，但**不要拿「小版本间有 ABI 硬边界」去解释它**。

---

## 二、运行时库：glibc、libstdc++、OpenSSL、libicu

### glibc（GNU C Library）

Linux 上**最底层、最核心**的 C 运行时库，提供 `malloc`、`printf`、`open`、`pthread_create` 等等。几乎每一个 Linux 程序都链接它，包括 Java 虚拟机本身。

它是**整个系统的兼容性地板**：一个二进制能否在某台机器上跑，首先看这台机器的 glibc 是否满足它要求的符号版本（`GLIBC_2.28`、`GLIBC_2.34` 之类）。

各目标版本的对应关系（出处见 [`02` 附录 A.1](os-dependency-contract-surfaces.md#a1-组件版本对照表release-notes-硬数据)；**实测值以指纹采集为准**）：

| OS | glibc | 说明 |
|----|-------|------|
| RHEL 8.10 | 2.28 | 全部目标里最老的底线（实测） |
| RHEL 9.6 | 2.34 | 实测 |
| RHEL 9.7 | 2.34 | 9.7 p6，实测一致 |
| **RHEL 9.8** | **2.34** | **实测。⚠️ 9.8 release notes p10 写的是 2.39，那是误记** |
| RHEL 10.0 / 10.1 | 2.39 | 10.0 p12、p80，实测一致 |
| RHEL 10.2 | 2.39 | 沿用（未实测） |
| Ubuntu 24.04 | 2.39 | 24.04 p330，实测一致 |
| Ubuntu 26.04 | 2.43 | 26.04 p27、p60（未实测） |

> ⚠️ **这张表被来回改过两次，值得记住这个教训。** 最初写「RHEL 9.x 全部 2.34」；后来据 9.8 release notes 改成「9.8 = 2.39，小版本内发生 rebase」；2026-09-11 实测又改回 2.34 —— **最初的写法才是对的，中间那次是被 Red Hat 自己的文档笔误带偏**（论证见 [`02` 附录 A.2](os-dependency-contract-surfaces.md#a2-已推翻的论据rhel-9-内部-glibc-并未-rebase)）。**结论：这类版本号以实测为准，release notes 只作线索。**

**PI 为什么关心**：自带的 Zulu JRE 是**一份 `linux64` 二进制覆盖全部 9 个目标**，因此它必须满足最老目标（RHEL 8.10，glibc 2.28）的底线。

**这条底线一次验证即覆盖全部版本，靠的是「单一二进制 + 钉在最老底线」，而不是「各版本 glibc 相同」** —— 后者不成立。两种说法结论相同但强度差很远：前者只要求 glibc 向后兼容（符号只增不删，见上一节），这是 glibc 的长期承诺；后者要求各版本版本号一致，一条 rebase 就能推翻。**引用「小版本可免层 1 全量回归」这个结论时，依据必须是前者。**

反过来，**PostgreSQL 层拿不到这个豁免**：它不是单一二进制，而是按小版本分别编译的包（走上一节的策略 B）。**真实的硬边界在大版本之间**——RHEL 10 的 `postgres` 实测要求 `GLIBC_2.38`，而 RHEL 9 只有 2.34，中间跨了 `GLIBC_2.35` 到 `GLIBC_2.38` 四个符号版本集，新包装老机必断（反向可以）。RHEL 9 三个小版本内部则实测同为 2.34，不构成边界。

**怎么查**：`ldd --version`

### libstdc++ / GCC 运行时

glibc 管 C，`libstdc++` 管 **C++**（`std::string`、`std::vector`、异常处理等）。同样使用符号版本（`GLIBCXX_3.4.29`、`CXXABI_1.3.13`）。

**PI 为什么关心**：任何 C++ 写的原生组件都依赖它。判断逻辑与 glibc 完全一样——新版本编译、老版本运行会缺符号。

**关键：依赖的是"这个 `.so` 用没用 C++ 写"，和"业务代码用什么语言"无关。** PI 场景里具体谁在依赖它（按确信度）：

| 组件 | 是否依赖 libstdc++ | 说明 |
|---|---|---|
| **libicu → PostgreSQL**（确定） | ✅ | ICU 是 C++ 写的，`postgres` 动态链接 libicu 做排序规则，链路 `postgres(C) → libicu(C++) → libstdc++`。这是 PI 里最实打实的一条 |
| **JVM 本体 `libjvm.so`**（需实测） | ❓ | HotSpot 是 C++ 写的，可能链接 libstdc++；但很多 JRE（含 Zulu）会**静态链接**它以求自包含。用 `ldd .../lib/server/libjvm.so \| grep stdc++` 在实机确认 —— 已登记为 **`03`** **O-9**，并入 O-5 采集脚本一起测 |
| **JNI 原生库**（看各库） | 视情况 | 谁碰硬件/系统就看那个 `.so` 用什么写的。如短信猫 `jSerialComm` 的原生库主要是 **C**，走 glibc、不一定碰 libstdc++ |

**Java 应用代码本身不直接依赖 libstdc++**——`.war`/`.jar` 是字节码，跑在 JVM 里，对 native 层的依赖全部"透过 JVM"。所以：Java 业务层只要 JVM 能起来就行；JVM 能否起来看它自己的 native 依赖（glibc 必需，libstdc++ 视打包方式）。正因 Zulu 是自包含二进制，**PI 的 Java 层对系统 C++/OpenSSL/crypto-policy 基本免疫**；真正吃系统 libstdc++/libicu 的是 **PostgreSQL 原生层**（也正是唯一随小版本分包的那层）。

**怎么查**：`ldconfig -p | grep libstdc++`，或 `strings /usr/lib64/libstdc++.so.6 | grep GLIBCXX` 看支持到哪一版。

### 补充：Linux 上谁用 C、谁用 C++（以及为什么系统地板是 C）

一句话：**C 撑起"系统地板"，C++ 用在"大型复杂上层应用"。**

- **C 提供的（系统基础设施，几乎全是 C）**：内核与系统调用接口、glibc 本身、动态链接器 `ld.so`、systemd、coreutils、OpenSSL / zlib、PostgreSQL 服务端主体、Python/Ruby 解释器、nginx、redis。
- **C++ 提供的（需要复杂抽象的大工程）**：libicu、HotSpot JVM、V8、Chromium、LLVM/Clang、MongoDB、Qt/KDE 桌面栈。

**为什么底层坚持用 C**（而不是"哪个顺手用哪个"）——核心是 **ABI 的稳定性**：

- C 的 ABI 极简且稳定：**没有 name mangling**（函数名就是 `open`，不是 `_Z4openv`）、**没有语言运行时**、结构体布局规则简单。于是 C 天然成了跨语言、跨编译器的"通用二进制契约"——内核 syscall、几乎所有 `.so` 的对外接口都用 C 暴露，Rust/Go/Java JNI/Python 也都通过 C ABI 互操作。
- C++ 的 ABI **脆弱**：name mangling 随编译器变、异常/RTTI/模板带来 libstdc++ 运行时依赖，还要多管一层 `GLIBCXX_x.x.x` 符号版本（就是本章第一节那套麻烦）。把系统地板建在会漂的地基上维护成本太高。

所以不是"C++ 不好"，而是：**越底层、越要被所有人链接、越要长期二进制兼容的东西越用 C；越是自成一体的大型应用越适合用 C++**。libicu 是个典型——它对外其实也提供 C 封装接口（`ucol_*`），正是为了让 C 写的 PostgreSQL 能干净地调用一个 C++ 库。

### OpenSSL（libssl / libcrypto）

Linux 上事实标准的加密库，提供 TLS 协议实现、证书解析、哈希与对称/非对称加密。两个文件分工：`libcrypto` 是底层算法，`libssl` 是 TLS 协议层。

版本演进对本项目的意义：

| OS | OpenSSL | soname | 出处 |
|----|---------|--------|------|
| RHEL 8.10 | 1.1.1 | `libssl.so.1.1` | 已知为 1.1.x 系 |
| RHEL 9.6 | **3.2.2** | `libssl.so.3` | 9.6 p10 |
| RHEL 9.7 | **3.5** | `libssl.so.3` | 9.7 p19 |
| RHEL 9.8 | 3.5 | `libssl.so.3` | 间接要求 3.5+（9.8 p27） |
| RHEL 10.1 | **3.5** | `libssl.so.3` | 10.1 p29 |
| Ubuntu 26.04 | **3.5.6** | `libssl.so.3` | 26.04 p66 |

> 空缺的格子是 release notes 未记载，**不等于没变**，须实测。完整对照见 [`02` 附录 A.1](os-dependency-contract-surfaces.md#a1-组件版本对照表release-notes-硬数据)。

**PI 为什么关心**：自带的 PostgreSQL **动态链接系统的 OpenSSL**（PG 用它做 TLS 连接与密码哈希）。所以：

1. RHEL 8 与 RHEL 9/10 之间 soname 不同 → **同一份 PG 二进制不可能同时跑在两边**，必须分包；
2. RHEL 9/10 各小版本之间 soname 相同但**符号版本会新增** → 新小版本构建的包在老小版本上缺符号，仍需分包。

**上表把第 2 条从「原理上会」变成了「确实发生了」**：9.6 的 3.2.2 到 9.7 的 3.5 **跨了 upstream minor**（不是补丁级），这是 RHEL 9 内部最危险的一条 ABI 边界。注意 soname 全程是 `libssl.so.3` 没变 —— **这正是本章第一节讲的「soname 不变 ≠ 可以互换」**，破坏发生在符号版本这一层，`ldd` 查不出来。

而自带的 Zulu JRE **不用**系统 OpenSSL——Java 的 TLS 由 JDK 内部的 SunJSSE 实现，所以 PI 的 Java 侧 TLS 与系统 OpenSSL 版本无关。

**怎么查**：`openssl version -a`；`ldconfig -p | grep -E 'libssl|libcrypto'`

### libicu（International Components for Unicode）

Unicode 处理库，负责字符串的**排序规则（collation）**、大小写转换、区域格式化。它的版本号很激进，soname 形如 `libicuuc.so.67`、`libicuuc.so.71`，**几乎每个发行版大版本都不同**。

**PI 为什么关心**：PostgreSQL 用 libicu 决定「字符串怎么排序」。这带来两类问题：

1. **启动失败**：PG 二进制链接的 `libicuuc.so.67` 在新系统上不存在（只有 `.so.71`）→ 起不来；
2. **数据一致性告警**：PG 会把建库时的 collation 版本记在数据库里，之后如果 libicu 变了，PG 会警告 collation 版本不匹配，并提示索引可能需要重建——因为「排序规则变了」意味着已建索引的顺序可能不再正确。

**怎么查**：`ldconfig -p | grep libicu`；`rpm -q libicu` 或 `dpkg -l | grep libicu`

---

## 三、查库的工具：ld.so、ldconfig、ldd

- **`ld.so`（动态链接器）**：程序启动时真正干活的那个组件，负责按 soname 找到库、加载、解析符号。找不到或符号缺失就在这一步报错。
- **`ldconfig`**：维护共享库的索引缓存（`/etc/ld.so.cache`）。安装完新库后需要它（或它的自动触发）来更新缓存，否则 `ld.so` 可能找不到。
  - `ldconfig -p` 列出缓存里所有已知库 —— 这是查「系统上有没有某个库、什么版本」最快的方式，也是 `install-postgresql.sh` 用来验证 `libpq.so.5` 是否就位的手段。
- **`ldd <文件>`**：列出某个可执行文件/库依赖了哪些共享库，以及每个依赖当前解析到了哪个文件。缺失的会显示 `not found`。
  - 注意：`ldd` 检查的是**库文件在不在**，**不检查符号版本够不够**。所以它能通过、程序仍可能因缺符号而跑不起来——这正是 [`02`](os-dependency-contract-surfaces.md) 里指出「`[ -x initdb ]` 与 `ldconfig -p | grep libpq` 都不足以判定 PG 可用」的原因。要真正确认，只能**实际运行**。

---

## 四、包管理：RPM、DEB、NVR、--nodeps、releasever

### RPM 与 DEB

两大发行版家族的软件包格式：**RPM** 用于 RHEL / Rocky / Alma / Oracle，**DEB** 用于 Debian / Ubuntu。

包里除了文件本身，还带**元数据**：提供什么、依赖什么、安装前后要跑什么脚本。命令层面 `rpm` / `dpkg` 处理单个包文件（离线），`dnf`/`yum` / `apt` 处理仓库与依赖解析（通常需要网络）。**PI 是离线安装，所以用的是 `rpm` / `dpkg`。**

### NVR（Name-Version-Release）

RPM 的完整标识，例如：

```
postgresql18-18.4-2PGDG.rhel9.8.x86_64.rpm
│            │    │      │       └─ 架构
│            │    │      └───────── 构建环境标签（PGDG 自定义，标明为哪个 OS 小版本编译）
│            │    └──────────────── Release：同一上游版本的第几次打包
│            └───────────────────── Version：上游软件版本
└────────────────────────────────── Name
```

**Release 号（`-1PGDG` / `-2PGDG`）只是「第几次打包」，与功能无关**，但同一组包（libs + 基础 + server）必须取**同一个** Release 号，否则可能内部不一致。

### `--nodeps` 与 `--force`

`rpm` 的两个「强制」开关：

- **`--nodeps`**：跳过依赖检查。正常情况下 RPM 会拒绝安装依赖不满足的包，加了这个就照装。
- **`--force`**：允许覆盖已存在的文件、重装同版本。

`install-postgresql.sh` 用的是 `rpm -Uvh --force --nodeps`。这么做的动机是**离线安装**：系统上的 OpenSSL、libicu 等基础库明明存在，但离线环境下 RPM 有时无法确认，`--nodeps` 可以避免误拒。

**代价**：RPM 层面的 ABI 保护被一并关掉了。符号版本不匹配的包会「安装成功」，只在运行时才炸。所以本项目把验证重心放在**实际运行 `initdb`** 上，而不是安装是否返回成功。

### `releasever`

RHEL 生态里表示「OS 版本」的变量，值形如 `9`、`9.6`、`10.2`。`dnf` 用它拼仓库地址。

PI 的脚本从 `/etc/os-release` 的 `VERSION_ID` 解析出大版本号与小版本号，据此选择 `rpm/x86_64/rhel9.6/` 这样的离线包目录——这就是文档里说的「`releasever` 映射」。

### `/etc/os-release`

标准化的系统身份文件，所有现代 Linux 都有。关键字段：

```sh
ID="rhel"              # 发行版标识：rhel / ubuntu / rocky / debian ...
VERSION_ID="9.8"       # 版本号（RHEL 含小版本；某些发行版只有大版本）
ID_LIKE="fedora"       # 「类似于哪个发行版」，衍生版用它声明血统
PRETTY_NAME="..."      # 给人看的完整名称
```

PI 的 OS 白名单校验就是读这个文件的 `ID` 与 `VERSION_ID`。**注意 Ubuntu Desktop 与 Server 的这个文件完全相同**，所以靠它无法区分二者。

---

## 五、系统服务与安全：systemd、SELinux、crypto-policies、cgroup、firewalld

### systemd

现代 Linux 的**初始化系统与服务管理器**，PID 1 进程，负责开机启动、服务的启停与依赖、日志收集。

服务定义写在**单元文件（unit file）**里，例如 `/etc/systemd/system/tafsvc.service`：

```ini
[Unit]
Description=...

[Service]
ExecStart=/path/to/java -jar app.war

[Install]
WantedBy=multi-user.target
```

常用命令：`systemctl start/stop/enable/status <名字>`、`systemctl daemon-reload`（改了单元文件后重载）、`systemctl is-active <名字>`。

**版本敏感在哪**：systemd 的**指令是逐版本新增的**。像 `ProtectSystem=`、`StateDirectory=`、`DynamicUser=`、`NoNewPrivileges=` 这些用于进程加固的指令，老版本 systemd 不认识（会忽略或报错）。各目标版本跨度很大：

| OS | systemd | 出处 |
|----|---------|------|
| RHEL 8.10 | 239 | 常识值，release notes 未记载 |
| RHEL 9.x | 252 | 常识值，release notes 未记载 |
| RHEL 10.0+ | **257** | 10.0 p51 |
| Ubuntu 24.04 | **255.4** | 24.04 p329 |
| Ubuntu 26.04 | **259** | 26.04 p42、p64 |

**PI 的实际情况**：单元文件由安装脚本运行时生成，只用了 `[Unit]` / `ExecStart` 等最基础的指令，**没有**用上述加固指令。且 release notes 检索确认**单元文件解析规则、`systemctl` 输出与退出码均无变更记载**，所以这 239→259 的跨度对 PI 影响很小 —— 这个「影响小」是靠**不用新指令**换来的，一旦将来为加固引入 `ProtectSystem` 之类，8.10 的 239 会立刻变成约束。

### SELinux（Security-Enhanced Linux）

Linux 内核里的**强制访问控制**机制。它和传统的文件权限（`rwx`）是两套独立的检查，**两者都要通过**才能操作成功。

工作方式是给系统里每个东西打上**标签（context）**——进程有标签、文件有标签、网络端口也有标签——然后由**策略（policy）**规定「哪个标签的进程可以访问哪个标签的资源」。

三种模式：

| 模式 | 行为 |
|------|------|
| `enforcing` | 违反策略的操作被**拦截** |
| `permissive` | 不拦截，只**记日志**（排查时常用） |
| `disabled` | 完全关闭 |

RHEL 默认 `enforcing`，Ubuntu 默认不用 SELinux（用 AppArmor）。

**PI 为什么关心**：

- 自定义服务要**绑定端口**（8443、PG 端口）。SELinux 对端口有标签管理，绑一个没被授权的端口可能被拒；
- 服务要**读写非标准目录**，也可能被策略拦；
- 策略由 `selinux-policy` 软件包提供，而**这个包在每个 RHEL 小版本都会更新**——是少数在小版本之间会实质变化的组件；
- PI 的安装脚本里**完全没有** SELinux 适配代码（没有 `semanage` / `chcon` / `restorecon`）。

**PI 的实测结论（RHEL 9.7 + Enforcing + `selinux-policy-38.1.65-1.el9`）**：三个 java 进程全部落在 **`unconfined_service_t`** 域。这个域权限很宽，**所以 SELinux 大概率不是 PI 服务启动与端口绑定的障碍**。原因是 SELinux 只 confine 有专门策略的服务，而各 RHEL 版本新增的 confined domain 全是具名系统服务，没有一条针对安装器生成的通用 systemd 单元或 JVM。详见 **`03`** R-4。

两点限定：① 该结论目前只有 **9.7 一个数据点**，其余 6 个版本仍应各自跑一条 `ps -eZ | grep java` 确认；② **`unconfined_service_t` 宽，不等于 POSIX 权限也宽** —— 短信猫串口打不开就是纯粹的组权限问题（`dialout` 组为空），把 SELinux 设成 permissive 也不会恢复（**`03`** R-11）。两套检查独立，别把任何权限问题都归给 SELinux。

**怎么查**：`getenforce`（当前模式）、`rpm -q selinux-policy`（策略版本）、`ps -eZ | grep java`（进程实际落在哪个域）、`semanage port -l | grep 8443`（端口标签）、`ausearch -m avc -ts recent`（看最近被拦了什么）。

### crypto-policies（系统级密码学策略）

RHEL 8 引入的机制：**用一个开关统一约束系统上所有加密组件**允许的 TLS 协议版本、密钥长度、签名算法与密码套件。

四档预设：`DEFAULT`（默认）、`LEGACY`（放宽，兼容老系统）、`FUTURE`（更严）、`FIPS`（合规模式）。

实现方式是把策略展开成各组件各自的配置片段，放在 `/etc/crypto-policies/back-ends/` 下，由 OpenSSL、GnuTLS、NSS、OpenSSH 等读取。

**为什么它是 RHEL 版本间的经典破坏源**：`DEFAULT` 档的内容会随小版本**收紧**——比如弃用 SHA-1 签名、把 RSA 最小长度提到 2048、移除 TLS 1.0/1.1。结果是同一个应用在 8.10 和 9.8 上握手能力不同，而应用本身一行代码都没改。

**PI 的实际情况**：Red Hat 通过 `/etc/crypto-policies/back-ends/java.config` 让**它自己构建的 OpenJDK** 读取系统策略——但这是 Red Hat 的下游补丁。PI 自带的是 **Azul Zulu JRE**，不含这个补丁，**因此不读系统策略**。所以 PI 的 Java 侧 TLS 行为与系统 crypto-policy 无关，这是本项目一个很重要的解耦点。

**怎么查**：`update-crypto-policies --show`

### cgroup（control group）

内核功能，用来给一组进程**限制和统计资源**（CPU、内存、IO、进程数）。systemd 用它管理每个服务的资源，容器技术也建立在它之上。

有两代：**v1**（多个独立层级）与 **v2**（统一层级）。RHEL 8 默认 v1，RHEL 9 及以后默认 v2。写法与可用的限制项不同，所以如果有针对服务的资源限制配置，跨版本时要注意。

**PI 为什么关心**：目前只作为运行期基线记录，没有依赖具体资源限制配置。

**怎么查**：`stat -fc %T /sys/fs/cgroup`（`cgroup2fs` 表示 v2）

### firewalld

RHEL 系的防火墙管理前端（底层是 nftables/iptables）。概念上把网络接口分到不同的 **zone**，每个 zone 有各自的放行规则。

命令：`firewall-cmd --state`、`--list-ports`、`--permanent --add-port=8443/tcp`（`--permanent` 表示写入持久配置，之后要 `--reload` 生效）。

**PI 的实际情况**：安装脚本会**在 firewalld 正在运行时**才去加端口规则，否则跳过。Ubuntu 默认用 `ufw` 且通常未启用。

---

## 六、网络工具：iproute2 / ss 与 net-tools / netstat

这两套工具做同一件事——查看网络连接与监听端口——但新旧有别：

| | `netstat` | `ss` |
|---|-----------|------|
| 所属包 | `net-tools` | `iproute2` |
| 状态 | **已弃用** | 现行标准 |
| 默认是否安装 | RHEL 8/9/10 与 Ubuntu 默认**不装** | **全部默认自带** |
| 数据来源 | 解析 `/proc/net/*` 文本 | 内核 netlink 接口（更快更准） |

常用参数（`ss`）：`-l` 只看监听、`-n` 不做名字解析、`-t` TCP、`-u` UDP、`-p` 显示占用进程。所以 `ss -lntu` = 列出所有 TCP/UDP 监听端口。

**PI 为什么关心**：安装器的端口占用检测依赖这个命令的输出。IA 的探测动作写成 `ss -lntu 2>/dev/null || netstat -antu 2>/dev/null`——**优先 `ss`、netstat 只作兜底**。这个顺序很重要：如果反过来先用 netstat，在默认不装 `net-tools` 的系统上就会拿到空输出，导致「所有端口都判为未占用」的静默漏检。

两者的输出格式都把本地地址写成 `0.0.0.0:5432` 的形式（**端口号前面是冒号，不是空格**），这个细节决定了端口匹配规则该怎么写。

---

## 七、PostgreSQL 相关：PGDG、initdb、cluster、collation

### PGDG（PostgreSQL Global Development Group）

PostgreSQL 官方组织，同时也指它维护的**官方软件仓库**（`yum.postgresql.org` / `apt.postgresql.org`）。它提供的版本比发行版自带的新，且支持多版本并存。

包名里的 `.rhel9.8` 是**构建环境标签**，表明这个包是在 RHEL 9.8 上编译的。自 2025 年底起 PGDG 对 RHEL 9/10 按小版本分别构建，原因就是第一节讲的符号版本问题。

PGDG 把 PostgreSQL 拆成多个包，其中三个是最小可运行集合（文档里称「三件套」）：

| 包 | 提供什么 | 缺了会怎样 |
|---|---------|-----------|
| `postgresql18-libs` | `libpq.so.5` 等运行库 | 所有 PG 程序都加载失败 |
| `postgresql18` | 客户端：`psql`、`pg_dump`、`pg_isready` | 没有客户端工具 |
| `postgresql18-server` | `initdb`、`postgres` 主程序、systemd 单元、`postgres` 系统用户 | 无法初始化、没有服务 |

**为什么 RHEL 一版 3 个 rpm，Ubuntu 一版却 6 个 deb**（实际包清单取证于打包工程 `installables/Unix/postgresql/`）：

| RHEL（3 个 rpm） | Ubuntu 对应（前 3 个 deb） |
|---|---|
| `postgresql18-libs` | `libpq5_18.4-..._amd64.deb` |
| `postgresql18` | `postgresql-client-18_...` |
| `postgresql18-server` | `postgresql-18_...` |

前 3 个一一对应（运行库 / 客户端 / 服务端），是同一批东西换个包名。**Ubuntu 多出来的 3 个全部来自 Debian/Ubuntu 特有的「多版本集簇管理框架」**（都是架构无关的 `_all.deb`）：

- `postgresql-common`：提供 `pg_createcluster` / `pg_ctlcluster` / `pg_lsclusters`、systemd 模板单元 `postgresql@.service`、创建 `postgres` 系统用户，以及"同机多 PG 大版本并存"的整套机制——**这就是本章下面「Ubuntu 装包时由 `pg_createcluster` 自动建 cluster」的来源**；
- `postgresql-client-common`：客户端侧的公共封装脚本；
- `libjson-perl`：`postgresql-common` 是 Perl 写的、要解析 JSON，拖出的依赖。

**根因是两家打包哲学不同，不是谁多打了包**：RHEL 把初始化工具（`postgresql-18-setup`）直接塞进 `-server` 包、initdb 需**手动**跑，没有独立公共框架包，所以 3 个就齐；Debian/Ubuntu 坚持"一台机可同时装多个 PG 大版本并各自管理"，为此抽出一层与版本无关的 `postgresql-common` 框架（装包即自动 `pg_createcluster`），这层框架 + 它的 Perl 依赖就是多出来的 3 个 `_all.deb`。

### initdb 与 cluster

- **cluster（数据库集簇）**：PostgreSQL 里一个**运行实例 + 它的数据目录**。一个 cluster 里可以有多个数据库。注意这个词和「服务器集群」没关系。
- **`initdb`**：创建 cluster 的命令——建数据目录、写配置文件、建系统表、创建初始超级用户。**装完包必须跑一次 initdb，数据库才存在。**

两个家族的路径与服务名不同：

| | RHEL（PGDG） | Ubuntu（PGDG） |
|---|-------------|---------------|
| 程序目录 | `/usr/pgsql-18/bin` | `/usr/lib/postgresql/18/bin` |
| 数据目录 | `/var/lib/pgsql/18/data` | `/var/lib/postgresql/18/main` |
| 服务名 | `postgresql-18` | `postgresql`（实际单元 `postgresql@18-main`） |
| initdb 方式 | 手动跑 `postgresql-18-setup initdb` | 装包时由 `pg_createcluster` 自动建 |

**`PG_VERSION` 文件**：数据目录下的一个小文件，内容就是主版本号。**它存在即说明 initdb 成功过**，所以是验证 initdb 是否真正跑通最直接的证据。

### collation（排序规则）

决定字符串怎么比较和排序的规则集，与语言/区域相关（比如某些语言里带音标的字母排序位置不同）。PostgreSQL 通过 libicu 或系统 locale 实现。

**为什么重要**：索引是按 collation 顺序建的。如果底层 collation 实现变了（libicu 升级），已有索引的顺序可能不再正确，PG 会发出版本不匹配警告并建议重建索引。这就是 libicu 被列为硬依赖的原因。

---

## 八、发行版生命周期：LTS、EUS、minor release

### minor release（小版本）

RHEL 的版本号形如 `9.6`，`9` 是大版本、`6` 是小版本。大约每半年发一个小版本，包含累积的修复与有限的新功能。

关键点：**标准订阅的客户会被更新推到最新小版本**。装了 9.7 的机器跑 `dnf update` 就变成 9.8。

### EUS（Extended Update Support，扩展更新支持）

Red Hat 提供的**延长支持通道**：客户可以把系统锁在某个小版本上，继续接收安全补丁约两年，而不必升到最新小版本。

**只有部分小版本提供 EUS**——RHEL 9 是**偶数**小版本（9.0 / 9.2 / 9.4 / 9.6）。

**实际影响**：EUS 小版本（如 9.6）在客户现场可以合法存在两年；非 EUS 小版本（如 9.7）的机器很快就会被更新推走。所以两者的现场存量不是一个量级。

> 注：本项目对外**逐个小版本**声明支持，所以不能用 EUS 来削减支持范围；它只用于在小版本之间**排优先级**。RHEL 10 的 EUS 节奏尚未核实 —— 已登记为 **`03`** **O-10**。

### LTS（Long Term Support，长期支持）

Ubuntu 的对应概念。Ubuntu 每两年发一个 LTS 版本（版本号为偶数年的 4 月，如 24.04、26.04），提供 5 年标准支持；非 LTS 版本只支持 9 个月。**企业软件通常只支持 LTS。**

---

## 九、Ubuntu 专属：t64 / time_t 迁移、`_all.deb`

### time_t 64 位迁移（t64）

`time_t` 是 C 语言里表示时间的类型。在 32 位平台上它历史上是 32 位整数，会在 **2038 年溢出**（著名的 Y2038 问题）。**注意 x86_64（amd64）上的 `time_t` 从一开始就是 64 位的，压根没有这个坑**——所以 Y2038 与 t64 迁移都只针对历史上 `time_t` 为 32 位的 **32 位架构**（Ubuntu 官方 release notes 明确限定为 armhf）。

Ubuntu 24.04 开始把 32 位架构上的 `time_t` 改成 64 位。这是**破坏 ABI** 的改动——任何在接口里传递时间值的库都得重新编译，包名上会带 `t64` 标记。

**"Ubuntu 专属"指的是这个"打包层面的 ABI 大迁移事件 + `t64` 包名后缀"，不是 `time_t` 类型本身。** 每个 C 程序都通过 glibc 用 `time_t`，RHEL 也一样用；只是：① Debian/Ubuntu 在 24.04 做了一次**全发行版级**的 ABI 转换并给受影响的库改名加 `t64`；② RHEL 早就砍掉 32 位 x86 作为主架构、没搞这种全库改名转换，所以 RHEL 包名里不会出现 `t64`。在 64 位上 `time_t` 本就是 64 位，RHEL 照用不误。

> ⚠️ **对 PI 而言这一项其实不适用。** Ubuntu 官方 release notes 把该迁移**明确限定在 armhf 架构**（专节标题即 "Year 2038 support for the **armhf** architecture"，24.04 p329，Known issue 于 p367 重申），**amd64 没有 t64 迁移或 ABI 破坏的记载**。PI 只支持 x86_64，所以 t64 不构成 PI 的边界。
>
> **PI 跨 LTS 不可混装 deb 的真实原因是运行时库的版本差异**，而非 t64：24.04 是 glibc 2.39，26.04 是 glibc 2.43，另有 systemd 255→259、OpenSSL 3.5.6、内核 6.8→7.0。所以「PI 对 Ubuntu 版本做精确匹配、不做跨 LTS 兜底」这个做法是对的，但依据要换成运行时库差异。详见 [`02` 附录 A.3](os-dependency-contract-surfaces.md#a3-逐项发现按契约面归类)。
>
> 本条保留在术语表中，因为 PGDG 的 Ubuntu 包名里确实会出现 `t64` 字样，读包名时需要知道它指什么。

### `_all.deb` 与架构相关包

DEB 包名结尾的架构标识有两类：

- `_amd64.deb` / `_arm64.deb`：**含编译产物**，只能装在对应架构上；
- `_all.deb`：**架构无关**（纯脚本、配置或数据，如 Perl 模块、文档），任何架构都能装。

**实际意义**：`_all.deb` 虽然架构无关，但**该架构的目录里仍然必须放一份**——离线安装是「装某目录下的全部包」，目录里没有就是缺依赖。这就是 **`03`** 里记录 `deb/arm64` 缺 `libjson-perl_..._all.deb` 的原因（该架构本项目不支持，仅作记录）。

---

## 附录：一条命令看全貌

把本文件涉及的关键项一次性打出来（对应 [`02` 第三节](os-dependency-contract-surfaces.md#三环境指纹采集项与判读标准) 的采集项）：

```bash
# 身份与运行时库（本文件第一、二节）
cat /etc/os-release
ldd --version | head -1
ldconfig -p | grep -E 'libstdc\+\+|libssl|libcrypto|libicuuc'
openssl version -a
systemctl --version | head -1

# 安全与策略（第五节）
getenforce 2>/dev/null; rpm -q selinux-policy 2>/dev/null
ps -eZ | grep java                      # 进程实际落在哪个 SELinux 域（R-4）
update-crypto-policies --show 2>/dev/null
stat -fc %T /sys/fs/cgroup

# 装得上吗（对应 02 的 A 组）
findmnt -no OPTIONS /tmp                # noexec 会让 IA 无法解包执行
systemctl is-active fapolicyd           # 执行白名单，active 时需单独评估（R-10）

# 端口（第六节）
command -v ss || echo "ss MISSING"
ss -lntu | grep -E ':(5432|8443)\b' || echo "ports free"
```

> 这只是**术语核对用的速查版**。完整采集项、每项的判读标准（「必须一致」/「记录即可」）与预期值基线，一律以 [`02` 第三节](os-dependency-contract-surfaces.md#三环境指纹采集项与判读标准) 为准；正式的可 diff 脚本是 **`03`** 的 O-5：**`pi-preflight-check.sh`**（装前）与 **`pi-postinstall-verify.sh`**（装后）。
