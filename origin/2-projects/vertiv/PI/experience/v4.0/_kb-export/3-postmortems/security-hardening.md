# PI 安全整改硬核复盘：密钥体系、服务降权与 Windows ACL 深水区

> **最后更新**：2026-08-31（补三节 8/14 后新增战果——§一.5 备份归档「信封」密钥、§三.4 信任库/签名库口令收敛(N-34)、§四.5 降权服务自重启窄授权(D-重启)；均沿用本文「问题→破局→教训」体裁，状态仍以 roadmap 真源为准）
> **文档用途**：沉淀 该产品 安装器**安全合规整改（SECURE / SEC-REQ）**过程中遭遇的硬核技术攻坚——机器绑定密钥派生体系、明文/硬编码凭据整改、TLS 证书每实例唯一、以及 Windows/Linux 服务运行权限最小化。本文与 [`02-hardcore-technical-postmortems.md`](migration-and-platform.md)（迁移/重构攻坚）为**同一段经历的不同主题线**：02 讲“把安装器从 MongoDB+IE 迁到 PG+ZE、并扩到 Linux 双平台”，本文讲“**在此基础上把三类安全漏洞收敛掉**”。三大需求：明文/硬编码凭据（**REQ-CRED**，ISS-CRED/ISS-CRED-2/ISS-CRED-3，CVSS 高危）、TLS 证书不唯一（**REQ-CERT**，ISS-CERT）、运行权限最小化（**REQ-PRIV**，PI 本体）。
>
> ⚠️ **真源声明**：安全整改的**进度、提交号、门禁基线、状态**只在 **`security-fix/02-implementation-roadmap.md`**（内部真源，不随本目录）（唯一真源）维护。本文是**冻结的机理复盘**，只讲“现象 → 机理 → 修复 → 教训”，具体状态一律链接指回真源，避免两处漂移。
>
> 🕒 **时间线注（重要）**：本文所述**降权账户模型**（Windows 三服务 `LocalService`+每服务 SID；Linux `pi_app`/`pi`/`pi_db`/`ze_app`）是 **2026-08 降权整改后**才引入的。02 第六章“RHEL 残留机卸载后用户组零残留”描述的是 **2026-07 降权前**的模型（当时 Linux 侧仅 `ze_app`/`postgres`，taf 侧尚未拆出独立降权账户）。降权引入 `pi_app`/`pi`/`pi_db` 后，卸载脚本 `pi-linux-uninstall.sh` 相应补齐这三个账户的清理（见第四节末与 roadmap 5-1/5-2/N-16）——两处描述不冲突，是同一脚本在不同阶段的演进。

---

## 一、 密钥地基：机器绑定 HKDF 派生 + `{cipher:<purpose>}` 分域

### 1. 问题：满地明文/硬编码密钥，且“一次编译、全网同钥”

ISS-CRED（v3.0.1，CVSS 高危）把散落各处的硬编码密钥汇总成伞状问题：`application*.properties` 明文口令、`installvariables.properties` 的 `TAFDB_ADMNPWD`、WAR 内写死的 `constant.mtp.core.key`、备份插件固定 AES 密钥……其中最致命的一类不是“明文”，而是**对称密钥被编译进产物**——所有客户装出来的实例**共享同一把密钥**，一处泄露即全网可解。

### 2. 破局：不引 KMS，用“机器绑定 + HKDF 派生”造出每实例唯一密钥

引入外部 KMS 对一个**离线、私有化部署**的安装器是重武器（要么客户没有、要么运维成本高）。方案是让每台机器在**安装期**生成一个随机 `install_nonce`（落 `config/machine.properties`），再用 **HKDF-SHA256** 从中派生对称密钥：

- **每实例唯一**：nonce 随机 → 派生密钥随机 → 同一份密文换台机器就解不开，根治“全网同钥”。
- **域隔离（purpose 分域）**：用枚举 `MachineKeyPurpose`（`GENERAL`/`DATABASE`/`TLS`/`SNMP`）作 HKDF 的 `info`，**同一 nonce 派生出互不相干的多把子钥**，DB 口令、TLS keystore 口令、SNMP 凭据各用各的域，互不牵连。
- **drop-in 不改密文格式**：`EncryptDecryptUtil.KEY` 换成派生钥，密文格式（`{cipher:...}`）不变，存量解密路径零改造。
- **强制显式标签**：`EnvironmentTextCryptListener` 要求 `{cipher:<purpose>}` 必须写明域，**裸 `{cipher}` 直接抛异常**——杜绝“忘了指定域、悄悄用了默认钥”。

### 3. 工程护栏：负向测试证明“fail-fast 且可诊断”

密钥地基最怕“悄悄用错钥、加密看似成功、解密时才崩”。为此做了负向测试，确认失败时**在启动最早期（`environmentPrepared`）就拒绝、且报错点名文件与后果**：

```text
# 篡改 nonce → 密钥变了 → 解密即拒
AEADBadTagException: Tag mismatch

# 删除 machine.properties → 明确报“nonce 文件缺失”并点名路径
IllegalStateException: install nonce file not found ... machine.properties
```

两侧（mtp-core 运行时 + 安装器 customcode）各自实现同一套派生逻辑，用 **RFC5869 官方测试向量 + 两侧 GENERAL parity 向量 `41c90910…`** 单测钉死一致性（parity 的意义见第二节）。

### 4. 灾备权衡：nonce 丢了怎么办？——不引新的“主密钥单点”

机器绑定的代价是：**nonce 一丢，这台机器的历史密文全部解不开**。这里有个诱人但错误的选项——存一把“主密钥/恢复钥”兜底，但那等于又造了一个“全网同钥”的单点，回到 ISS-CRED 的老问题。最终决策（roadmap N-1）：

- **卸载即删 nonce**（`removeMachineProperties`），不给残留留把柄；
- **灾备不靠额外主密钥**，而是把 nonce 纳入“备份 DB 时一并备份”——nonce 与它保护的数据同生共死、同备份同恢复，既不新增单点，又保证可恢复。

> **教训**：私有化/离线场景造密钥体系，“机器绑定派生”是免 KMS 的高性价比解；但**必须同时回答“nonce 灾备”这道题**，否则把可用性风险埋进了安全设计里。答案是让密钥随数据一起备份，而不是再造一个主密钥。

细节与状态见 **roadmap 阶段1/阶段2 + N-1**（内部真源，不随本目录）、[crypto 方案](../2-design/crypto-key-management-solution.md)。

### 5. 应用一例：备份归档用「信封加密」（DEK + GENERAL）替代硬编码 AES 钥

**当时面对的**：备份插件里有两把「全网同钥」的硬编码 AES 密钥——① 存远端 SMB/CIFS 共享盘口令用固定常量 `victoryAndActive`；② 备份归档 `.vertiv` 本身也用一把固定 AES 钥加密。后者最致命：**一处泄露，所有客户的备份归档全可解**（正是 ISS-CRED 要收敛的「编译进产物的对称钥」）。

**归档密钥（②）的两个方案**：

- ① **直接用机器绑定 GENERAL 钥加密整个归档**；
- ② **信封**：每次备份用 `SecureRandom` 现生一把 32B 数据钥（DEK），归档以 **AES-256-GCM 流式**加密；只把这把 DEK 用 GENERAL 钥封装、写进归档头。

**关键差别**：GENERAL 的 `EncryptDecryptService` 是 core 的**字符串级 `{cipher}` 密码器**（为属性/短文本设计），拿它去怼几百 MB～GB 的归档流**根本不合身**；信封则让大文件走对称流式（`CipherOutputStream`），只有一小段 DEK 过字符串密码器。

**选择 ② 信封，决定性依据**：**大文件流式 vs 字符串级密码器的错配**——这是硬约束、不是偏好。顺带白拿两个好处：每份备份一把随机 DEK（**一档一钥**），且 DEK 由机器绑定 GENERAL 封装（**每机唯一**）。

**值得记住的细节 + 一处权衡**：

- **头部布局** `[4B wrappedDek 长度][wrappedDek][12B IV]` + AES-256-GCM（认证加密，顺带防篡改）；恢复端读头、`unwrapDek` 还原 DEK 再解流（`BackupService`/`RestoreService`）。
- **机器绑定的代价（写进运维预期）**：GENERAL 每机唯一 → 归档**只能在原机恢复**。跨机恢复得靠「nonce 随数据一起备份」的灾备链（呼应本节 4）——用「到处能恢复」换来了「泄露也解不开」。
- **划出没做的那半（做减法）**：密钥①（远端共享盘口令 `victoryAndActive`）本轮**不收敛、留待 U1**——它是「连第三方共享盘」的口令、属另一条线，且改它牵连存量配置数据迁移，先明确边界不硬塞。

> **教训**：机器绑定 HKDF 是「地基」，但**用它加密大对象要分清「加密什么」**——直接拿字符串级密码器加密大流是错配；**信封（随机 DEK 跑大数据、主钥只封 DEK）才是标准解**。同时，收敛硬编码钥也要会**划边界**：一次能确定性拿下的（归档钥）先落地，牵连面大的（远端共享口令）明确留待后续，别为「一次清干净」把风险揽进来。

细节见 **roadmap 备份 2-1-i / K-6**（内部真源，不随本目录）、[crypto 方案 §2.2](../2-design/crypto-key-management-solution.md)。

---

## 二、 两套加解密体系的收敛：PI 与 ZE 统一到同一 HKDF

### 1. 问题：伴生引擎自带一套“更差”的加密

Zero Engine（ie-engine）历史上自研了一套加解密：`CryptoManager` 用 **PBKDF2 + 打包静态 seed**。问题在于 seed 是**编译进包**的——**每台机器装出来同一把 seed**，等价于 PI 侧刚修掉的 `constant.mtp.core.key` 老病，只是换了件外衣。两套体系并存还带来第二个风险：同类逻辑**两处实现、容易走偏**。

### 2. 破局：收敛而非并存，用测试向量保证“字节级一致”

K-10 决策：废掉 ZE 的 PBKDF2-seed，收敛到 PI 的机器绑定 HKDF。落地时的关键取舍是**“复制 parity 副本”而非仓促抽公共库**——把 `MachineKeyProvider`/`MachineKeyPurpose` 复制一份进 ie-engine（跨仓抽库成本高、周期长），但用**共享的测试向量**保证两份实现派生结果**逐字节相同**：

- ZE `CryptoUtils.KEY` 改走 HKDF 派生；
- ZE 有自己独立的 nonce（`zeroengine/config/machine.properties`，与 PI 的分离，天然域隔离）；
- 两侧共用 RFC5869 + GENERAL parity 向量单测——**任何一侧派生偏了，向量立刻红**。

> **教训**：跨产品同类实现，最怕“看起来一样”。**抽公共库不是唯一答案**——当抽库成本高时，“复制副本 + 共享测试向量钉死一致性”是更务实的收敛方式，代价是纪律（改一处必须同步另一处，靠向量兜底）。

细节见 **roadmap 3-5**（内部真源，不随本目录）。

---

## 三、 每实例唯一证书，以及“只修在路径上的东西”

### 1. 问题：ISS-CERT——每装一份、指纹全同的 TLS 证书

Core（8443）与 ZE（8088）的 `keystore.p12` 都是**随包静态自签证书**，所有客户实例**证书指纹一模一样**、私钥口令还写死可开：

```text
ISS-CERT 实证：ZE 证书指纹恒为 72:7B…9D:8B，明文口令 ZeroEngine@7775W 可直接打开 keystore
```

### 2. 破局：安装期为每实例现签唯一证书

`PiSetupAction` 用 `keytool`（JRE 自带、免依赖）在安装期为 Core/ZE **各生成唯一密钥对 + 自签证书**（RSA-3072/SHA256withRSA、随机序列号、复用现状 DN、幂等），删掉随包静态证书。重装即换指纹——三机验证 Core/ZE 证书 thumb+serial 全不同、两 nonce 互异（roadmap N-19）。

### 3. 亮点：追查“证书信任链”，判定一处修复其实是 no-op（N-14）

原计划里有一步“把 ZE 证书导入 Core 的 `core-trust.jks`”建立信任。动手前先追了一遍**真实信任路径**，结果发现这步**双重无效**：

- 运行期 `TrustSynchronizer` 会按 **DB**（`TRUST_CERT_PATH`）**清空重建** truststore，安装期导入的会被冲掉；
- 更关键：PI→ZE 主通道 `taf-plugin-pi-zeadapter` 的 `RestTemplate` 本就是 **trust-all**：

```text
PluginConfiguration.createRestTemplate() → (chain, authType) -> true   // 信任一切
+ 忽略主机名校验，认证只靠固定头 X-API-KEY: zero-engine
```

既然主通道根本不查 truststore，“导入 core-trust”这步就是纯 no-op。于是**判定 3-2 为“保留现状、不做无效修复”**（代码留着无害），只有将来真要收紧 TLS 校验时才成真任务（届时正解是走信任 DB + 改 `PluginConfiguration`，而非改文件）。

> **教训**：修复前先确认“**这个问题真的在关键路径上吗**”。一个“看起来该做”的加固，若不在实际数据流/信任链上，做了只是自我感动、还增加维护面。**克制地不做**，和把该做的做对，同样是工程判断力。

细节见 **roadmap 3-1/3-2/N-14**（内部真源，不随本目录）、[tls 方案](../2-design/tls-certificate-solution.md)。

### 4. 续集（N-34）：从「导入无效」到「口令对不上」——信任库改每机口令、签名库去口令

**当时面对的**：3-1 给 Core/ZE 各签了唯一证书（解 ISS-CERT）后，顺手把 `core-trust.jks` 的口令也从出厂 `HoneyBadger@7775W` 改成机器派生——`PiSetupAction` 把属性 `server.ssl.trust-store-password` 写成 `{cipher:tls}`，并对随包信任库做 `-storepasswd` re-key。RHEL 实机却起不来：`tafsvc` 一加载 SSL trust-store 就崩 `Keystore was tampered with`。诊断日志坐实：磁盘 `core-trust.jks` 是 **32B 空库、`mtime`=构建整秒**（＝随包 payload 铺的），而出厂口令 `HoneyBadger@7775W` 竟能打开它——**运行期属性=派生口令、磁盘文件=出厂口令，对不上**。

**根因**其实本章 3.（N-14）早埋了一半伏笔：随包 `InstallFile`（`mtp-core-trust.jks`→`core-trust.jks`）在 `PiSetupAction` **之后**铺设、覆盖同名文件。N-14 当时只关心「导入的证书 no-op」，没意识到**口令也一起被出厂库盖了回去**——内容 no-op 无害，但**口令是 boot 加载的硬门槛**。

**两个方案**：

- ① 继续让「随包 payload + 安装期 re-key」共存，调装序让 re-key 落在覆盖之后——**治标**：两个生产者仍抢同一个文件，装序脆；
- ② 仿私钥库 `keystore.p12`：**删掉随包 InstallFile，让 `PiSetupAction` 当唯一生产者**、直接新建 JKS（每机派生口令），从构造上根除覆盖。

**选择 ②，决定性依据**：私钥库 `keystore.p12` 本就「无 InstallFile、纯安装期生成」、已三平台验证可行——**现成的成功范式，抄它就消灭了装序竞争**，而不是给一个「两个生产者」的坏结构打时序补丁。

**值得记住的两处细节**：

- **改法**：删 IA 的 `InstallFile 4698fb719a0c` 定义 + refID（`taf-core-installer @ c0009bd`，纯删 45 行）；`importZeCertIntoCoreTrust` 改成写全新 JKS（`.new` 原子 move，镜像 `genKeypair`），口令用每机派生 `trustStorePwd`（`TAF-InstallerCustomCode @ 341021c`）。至此 `keystore.p12` 与 `core-trust.jks` **都是「无 InstallFile、PiSetupAction 独家产、每机唯一材料+口令」**。三平台（Win/RHEL/Ubuntu）实机验证通过。
- **顺带清掉最后一个工厂口令**：追签名库 `sigver` 时发现它三平台启动器都 `--taf.security.signature.validation=false`、**运行期从不加载**（§八「做减法」同款判断），于是把 `sigver.p12`（带出厂口令）直接换成**无口令公钥证书 `sigver.cer`**（sigver 只含公钥、本就不需 keystore 口令）。keystore/truststore 改每机派生、签名库改无口令后，出厂常量 `FACTORY_KEYSTORE_PASSWORD`（`HoneyBadger@7775W`）**从 `PiSetupAction` 彻底移除**——ISS-CERT/ISS-CRED 那把「全网同口令」至此退场。

> **教训**：一次改动踩雷，未必是新代码错，可能是**旧结构的隐藏假设**（「随包文件会被安装期改动盖过」）在换平台后暴露。N-14 看穿了「内容 no-op」却漏了「口令也被盖」——**同一个覆盖点，换个视角（内容 vs 口令）就是另一个 bug**。根治办法不是打时序补丁，而是**消灭「多个生产者」本身**、向已验证的范式对齐。另：`core-trust.jks` 同机重装哈希相同、跨机不同，正是「口令随机、内容恒为空库」的**副产品**——反向印证每机派生生效。

细节见 **roadmap N-34**（内部真源，不随本目录）、[tls 方案 §2.2](../2-design/tls-certificate-solution.md)。

---

## 四、 Windows 服务运行权限最小化的深水区

把三个服务（`TAFdb`/`TAFsvc`/`ZESvc`）从 `LocalSystem` 降到最小权限，是本轮踩坑最密集的一段。四个连环坑，逐个拆。

### 1. 选型翻车：虚拟服务账户（VSA）在域信任断的机器报 1057

首版让服务以**虚拟服务账户**（`sc config obj="NT SERVICE\<svc>"`）作登录身份，本机 PoC 通过；但换到**域信任断**的机器直接：

```text
错误 1057：账户名无效或不存在，或密码无效
```

公司内机器域信任状态参差、客户现场更不可控——这个坑会大面积复现。**改选型**：三服务登录身份统一为内建的 `NT AUTHORITY\LocalService`（免密码、**域无关**），再靠每服务 SID 拿到隔离能力：

```bat
sc config <svc> obj="NT AUTHORITY\LocalService" password="" && sc sidtype <svc> unrestricted
```

`sc sidtype <svc> unrestricted` 让服务令牌带上**唯一的 `NT SERVICE\<svc>` 组 SID**，ACL 授权主体仍是这个服务 SID（授权对象不变，只换了登录账户）。

### 2. 经典坑：`initdb` 用“受限令牌”重跑自己，撞上 ACL 独占

给空的 `data\db` 断继承、只留 `SYSTEM`+`Administrators` 后，装机卡在建库。根因极隐蔽——PostgreSQL 的 `initdb` 在 Windows 上会**用受限令牌（把 Administrators 组置为 deny-only）重新启动自己**来避免以管理员身份初始化数据目录：

```text
initdb: 无法访问目录 "…/data/db": Permission denied   (exit 1)
```

于是 `SYSTEM`+`Administrators` 两条 ACE 都覆盖不到那个“被剥掉 Administrators 的自己”→ `initdb` 失败 → `&&` 链断 → `pg_ctl register` 没跑 → `TAFdb` 服务从未注册 → 后续 `wait-db` 死等一个永不就绪的库、超时回滚。**修复**：断继承时**额外预授“initdb 实际运行的那个交互管理员”**，让受限令牌也落在授权集内：

```bat
icacls data\db /inheritance:r /grant:r "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" ...
```

因为 PI 不支持静默/SYSTEM 安装，`%USERDOMAIN%\%USERNAME%` 就是那个交互管理员；且断继承发生在**空目录**上（无文件、无 AV 抢锁窗口），产物天然只含 `{安装用户, SYSTEM, Administrators, TAFdb}`、TAFsvc 零权限。

### 3. 时序坑：`icacls /inheritance:r` 递归与杀软抢锁，制造“孤儿文件”

另一版把独占加固写成“对**已铺好的** PGDATA 递归 `/inheritance:r`”，实机随机崩溃：递归重写 ACL 时**与 AV（杀毒）抢文件锁**，个别文件（典型是 `postgresql.conf`）ACL 被写坏成**孤儿**——连 `SYSTEM` 都读不了，postgres 起不来。雪上加霜的是当时用了 `&`（而非 `&&`）串命令，`sc config obj` 失败被后续命令**吞掉退出码**，结果“**半落地**”：账户没切成、仍是 LocalSystem，却以为成功了。

**修复两条**：① 把“**降权本体**（切账户 + grant-only 授权）”与“**独占加固**（`/inheritance:r` 递归断继承）”**拆成两阶段**，前者本轮上、后者待干净环境配验证 harness 再上；② 全链 `&&` **fail-fast**，任一步失败即停、绝不半落地。

### 4. 收口：per-service SID 令牌模型 = 最小权限的落点

前三坑理顺后，最终形态是：三服务同以 `LocalService` 登录、各带 `sidtype unrestricted` 令牌里的唯一 `NT SERVICE\<svc>` 组；文件/目录 ACL 断继承、只授对应服务 SID；PGDATA 独占 `TAFdb`（`TAFsvc` 零权限、无 `Users`/`AuthUsers`）。三机（Win11/Server2022/Server2025）验证达标。

### 5. 降权的另一面：服务如何安全地「自我重启」——窄授权而非提权（D-重启）

**当时面对的**：一键升级要求 `TAFsvc` 能**停掉并重启自己**（换 war、迁移后重载）。可前四坑刚把它从 `LocalSystem` 降到 `LocalService`/`pi_app`——**降了权的服务，凭什么还能停/起一个系统服务？** 降权与「自管理」天然打架。

**三个方案**：

- **A｜触发文件 + 特权 watcher**：服务写一个 trigger 文件，另起一个常驻高权限进程盯着、代它重启；
- **B｜窄授权**：不新增进程，只在**现有运行账户**上开一个「针尖大」的口子——精确到「只能对本服务做启停」；
- **C｜干脆别降权/保留高权限**：直接否——等于回退整轮降权成果。

**A vs B 的关键差别**：A **凭空多出一个常驻特权进程**——新的攻击面、新的单点，还要管它自己的生命周期与权限；B 不引入任何新组件，只给既有账户加一条最小授权。

**选择 B，决定性依据**：**「授权 vs 提权」**——要的只是「能重启自己」这一个能力，就只授这一个能力，而不是养一个「什么都能干」的帮手。爆炸半径最小。

**值得记住的落地细节**（跨平台各一处）：

- **Windows**：`sc sdset TAFsvc` 往服务 DACL 里只加 `RP`(start)/`WP`(stop) 两个权限位给运行账户——**精确到「只能启停、不能改配置/删服务/改 ACL」**，不是 full control；
- **Linux**：sudoers drop-in 只放行「对本 unit 的 `systemctl start/stop`」这几条具名命令；配 `KillMode=process` 让 systemd 只收自身进程、不误杀重启链上的子进程。

> **教训**：降权不是「一降了之」——**降权会顺带砍掉一些合理的自管理能力**，这时的正解是把那点能力**以最小粒度精确补回**（授权），而不是为了省事再养一个特权进程（提权）。判断标准始终是爆炸半径：宁可开一个只能启停的针孔，也不引入一个「什么都能干」的新单点。

细节见 **roadmap 5-8 / D-重启**（内部真源，不随本目录）、[runtime 方案 §4.3](../2-design/runtime-permission-solution.md)。

### 附：最小权限的落地准则——“代码归 root、数据归服务账户”（N-24）

降权时反复要回答“**哪些该只读、哪些该可写**”。沉淀出的准则是：**程序/二进制/WAR 归特权属主、运行账户只读；只有数据目录对服务账户可写**。Linux 侧据此把 `mtp-core.war` 收紧为 `root:pi`、`zeengine.war` 为 `root:ze`（运行账户读得到、改不动），数据/日志目录才 `chown` 给服务账户。这样即便运行进程被攻破，也**改不动自己的代码**（防篡改/防持久化）。落地时需同步核对**热加载/自更新**路径是否与“代码只读”冲突（本项目无冲突）。

> **教训**：Windows 服务最小权限的难点不在“会用 `icacls`”，而在**三个隐藏机制**：登录账户与授权主体可以解耦（LocalService + per-service SID）、`initdb` 的受限令牌、以及 ACL 写入与 AV/时序的竞态。**降权与独占加固必须分阶段、必须 fail-fast**，否则“半落地”比不降权更危险。

细节见 **roadmap 5-5/5-6/6-1/6-2 + N-24**（内部真源，不随本目录）、[runtime 附录 C](../2-design/runtime-permission-solution.md)。降权后的卸载/回滚补齐（`pi_app`/`pi`/`pi_db` 清理）见 roadmap 5-1/5-2/N-16。

---

## 五、 Spring 生命周期洞察：让 keystore 口令“永不落盘”

### 1. 问题：随机口令写进配置文件，却被负载覆盖

ZE keystore 口令去明文，第一版是“安装期随机生成口令 → `{cipher}` 加密写进 `application-prod.properties`”。实机发现 ZE 起不来——根因是**执行时序**：`PiSetupAction`（安装期）**早于** ZE 负载铺开执行，它写进去的 `application-prod.properties` 随后被 ZE 负载的同名文件**覆盖**，口令丢了。

### 2. 破局（option-1）：口令不写盘，运行时确定性派生并注入

放弃“写盘”思路，改成**确定性派生 + 运行时注入**：

- keystore 口令由机器绑定的 **TLS 域密钥**（HKDF）**确定派生**（`PiSetupAction.keystorePasswordFromKey`），安装期用它生成 `keystore.p12`；
- ZE 启动时 `MachineKeyEnvironmentPostProcessor` **重新派生同一个字符串**，作为**最高优先级 property source** 注入 `server.ssl.key-store-password`；
- **全程不落盘**——口令既不在配置文件、也不在环境变量里持久化，每次要用时从 nonce 现算。

同一轮还顺手解了个装序死锁：`PiSetupAction` 对 ZE 的 `config`/`certs` 改为“**不存在则建目录**、负载后只合并不清空”，让 nonce/keystore 在“安装期早于负载”的情况下也能存活。

> **教训**：密钥卫生的上限，往往由**框架生命周期**决定。看懂“谁先执行、谁会覆盖谁”之后，最干净的解不是“把秘密藏得更好”，而是**让秘密根本不落地**——需要时从机器绑定的种子确定性重算。

细节见 **roadmap 3-3**（内部真源，不随本目录）。

---

## 六、 默认数据路径的“继承只读 ACL”灾难（尤 Server 2025 / C 盘）

### 1. 现象：降权后，默认路径装机在 C 盘必崩

降权前一切正常，降权后**用默认安装路径、装在 C 盘**（尤其 Server 2025）必然失败：`TAFdb` 卡在建库、回滚。

### 2. 机理：数据落进了一个“继承只读”的模板目录

旧默认数据目录落在 `C:\Users\Default\AppData\Local\PI`。`C:\Users\Default` 是**新用户模板 profile**，其 ACL 继承 `Everyone/Users:(RX)` —— **只读**。降权前服务跑 `LocalSystem`（无所不能）看不出问题；降权后 `TAFdb` 以 `LocalService` 运行：

```text
LocalService 建不了 log\tafdb.log（父目录只读继承）
→ postgres 启动即 FATAL 秒退
→ 上层卡在“等待数据库就绪”超时 → 回滚
```

这是一个**只在“降权 × 默认路径 × C 盘模板目录”三者叠加时才暴露**的坑——单独任一条件都不触发，极难在开发机复现。

### 3. 修复：换默认根 + 数据根 ACL 收敛

- 默认数据目录从 `C:\Users\Default\...` 改到 `C:\ProgramData\PI`（`ProgramData` 是**为“机器级服务数据”设计**的位置，不带用户模板的只读继承）；
- 对 26119 数据根 ACL 收敛，显式授 `LocalService`（Modify）；
- C 盘默认路径实测通过：三服务 Running、5432/8443 监听、根/log 目录无 `Users`。

> **教训**：降权会把“**以前靠 LocalSystem 无脑绕过的隐性只读继承**”一次性引爆。测“默认路径 + C 盘 + Server 最新版”这条最保守的组合，比测十个自定义路径更能暴露 ACL 继承问题——因为默认路径往往落在系统预置、带继承 ACL 的目录里。

细节见 **roadmap N-21**（内部真源，不随本目录）、**qa-impact 场景/回归**（内部真源，不随本目录）。

---

## 七、 诊断陷阱：WSL2 的 5432，`netstat` 看不见的“幽灵监听者”

### 1. 现象：把降权改动冤枉了

实机多次出现“`TAFdb` 服务消失 / 卡建库 / 手动 `net start TAFdb` 也失败 / 空日志”。第一反应是把它归咎于刚做的降权：“**6-2 锁死了 PGDATA，LocalService 靠服务组 SID 进不去**”，甚至一度准备回滚降权改动。

### 2. 机理：真凶是 WSL2+Docker 占了 5432，且诊断工具集体“瞎”

真相是开发机的 **WSL2（Ubuntu）+ Docker 里跑着一个 postgres 占了 5432**，WSL2 的 localhost 转发把它暴露到 Windows 的 `127.0.0.1:5432`：

```text
TAFdb 绑 5432 → FATAL: could not create any TCP/IP sockets
```

最坑的是诊断陷阱——**`netstat` / `Get-NetTCPConnection` 都看不到 WSL2 转发的那个监听者**（TCP 直连 5432 却能通），所以“端口没被占”的假象把排查带偏；加上前台验证时误用了 5433 绕开冲突，进一步坐实了误判。

### 3. 收口：先证伪，再定性

用“换端口/换机器”证伪“降权锁死”假设后，`LocalService`/`sidtype`/6-1/6-2 的改动被证明**全部正确、无需回滚**。这与 02/03 里用 `lax_dump` 推翻“Java 21 不兼容”是**同一种纪律**：

> **教训**：当“新改动 + 新故障”同时出现，最容易犯的错是**默认新改动有罪**。**先证伪、再定性**——尤其当标准诊断工具（这里是 `netstat`）本身存在盲区时，“工具说没占用”不等于“真没占用”。装前显式确认 `5432/8443/8088/162` 未被占（尤其 WSL2/Docker）已写进 QA 前置。

细节见 **roadmap N-18**（内部真源，不随本目录）、**qa-impact 端口/WSL 排障**（内部真源，不随本目录）。

---

## 八、 做减法：该不做的，用威胁模型论证到坚决不做

安全整改最反直觉的一课：**“更安全”不等于“该做”**。两个“论证后决定不做”的例子。

### 1. SNMP 专用密钥：域隔离加固，增益≈0（7-1，N-26）

现状 PI/ZE 两侧的 SNMP 凭据**已经**用各自机器绑定 HKDF 的 `GENERAL` 钥（`vertiv-pi-general-v1`，每实例唯一、AES-256-GCM 随机 IV）加密——**已满足 SEC-REQ**（无明文、无硬编码、无全网同钥）。有人提议再换一把专用 `vertiv-pi-snmp-v1` 做域隔离，听起来更“干净”。但用威胁模型算账：

- 专用钥与 GENERAL 钥**同源同 nonce**，`info` 标签代码公开；
- 唯一真实威胁是 **nonce 泄露**——一旦泄露，两把钥**一起沦陷**，专用钥防不住；
- 改造还有路径引入**明文回归风险**。

结论：**安全增益≈0、成本/风险都不低 → 不做**。后续若有硬需求，走“modifier 带 purpose”的低风险路线。

### 2. 空默认口令的“抢注窗口”：接受残余风险 + 兜底（N-11）

去掉硬编码 admin 口令后，改为“**默认登录口令置空 + 首登强制改密**（配合 US-LOGIN）”。这引入一个残余风险：**首次登录前存在一个“抢注窗口”**——理论上有人能在管理员首登前用空口令进去。评估后**接受**这个窗口：部署环境是私有化/受控网络、窗口极短、且首登强制改密即关闭窗口；相比“继续硬编码一个全网已知口令”，这是**更小的风险**。

> **教训**：安全工程既要会“加”，也要会“**有理有据地减/接受**”。判断一个加固值不值得做、一个残余风险能不能接受，靠的是**威胁模型 + 爆炸半径**，而不是“听起来是否更安全”。敢说“不做”并写清论证，是把有限的工程资源花在真正降低风险的地方。

细节见 **roadmap 7-1/N-26、N-11**（内部真源，不随本目录）。

---

## 九、 小坑合集（Tier 3）

| 坑 | 症状 | 根因 | 修复 |
| :--- | :--- | :--- | :--- |
| **`installvariables` 逐文件 ACL 时序失效**（N-25） | 对 `installvariables.properties` 单独设的 ACL 装机后失效 | IA 在**末尾**才写盘该文件，先设的 per-file ACL 被覆盖 | 改为**锁 `_installation` 目录**（组闭合后、`net start` 前 `icacls _installation /inheritance:r /grant:r SYSTEM+Admin(OI)(CI)F /remove:g TAFsvc`）；`(OI)(CI)` 写法避开“组内去引号”坑 |
| **Linux 备份插件 `availableSpaceSize=0`** | 备份预检算出可用空间为 0、误判磁盘满 | `getBackupPath` 以 `pi_app` 对 root 属主的 `/var/opt` `mkdirs` 失败；且 `File.getFreeSpace` 对**不存在的路径返 0** | 安装期**预建 `/var/opt/该公司Backup` 属主 `pi_app:pi`**（`1ffb74f`） |
| **健康检查“假阴性”卡死装机**（N-10） | 装机末尾 `/manage/health` 恒 `503 {"status":"DOWN"}`，`WaitForAPI` 空等超时 | 唯一 DOWN 的是 **LDAP 探针**（连默认 `localhost:389`、环境无 LDAP），与安全改动无关 | 随包 `management.health.ldap.enabled=false`；定位时可临时 `management.endpoint.health.show-details=always` 看明细 |

> **小坑的共同教训**：安装器里的 ACL/权限改动**对“写入时序”极其敏感**（IA 末尾写盘、AV 抢锁、跨用户 `mkdirs`）；而“服务起不来/装机卡死”未必是你的改动引起——**健康检查的假阴性**同样能卡死流程，定位要先分清“我引入的”还是“环境/既有的”。

---

## 十、 给后来者的安全整改建议

1. **免 KMS 也能做“每实例唯一”**：机器绑定 `nonce` + HKDF 派生 + purpose 分域，是私有化/离线场景的高性价比密钥体系；但**必须同时设计 nonce 灾备**（随数据备份，别造新主密钥单点）。
2. **修复前先确认“在不在关键路径上”**：像 N-14 那样追一遍真实数据流/信任链，**该不做的克制地不做**。
3. **Windows 降权是“机制活”不是“命令活”**：吃透 LocalService+per-service SID、`initdb` 受限令牌、ACL 与 AV/时序竞态；**降权与独占加固分阶段、全链 fail-fast**。
4. **降权会引爆隐性只读继承**：优先测“默认路径 + C 盘 + 最新 Server”这条最保守组合（N-21）。
5. **先证伪、再定性**：新改动 + 新故障别默认新改动有罪；警惕诊断工具盲区（如 `netstat` 看不见 WSL 转发，N-18）。
6. **会加也要会减**：用威胁模型 + 爆炸半径论证“不做/接受残余风险”，把资源花在真正降险处（7-1/N-11）。

> 一句话：**安全整改的功力，一半在“把该做的做对”，一半在“把不该做的论证清楚后坚决不做”。**
