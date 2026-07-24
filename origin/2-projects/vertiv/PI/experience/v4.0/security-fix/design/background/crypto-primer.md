# 密码学：背景知识与选型问答（类别二前置）

> 最后更新：2026-07-23
> 定位：本文是**背景知识 + 讨论/问答（为什么这么设计）**；对应的**现状与决定（做什么）**见 [../crypto-key-management-solution.md](../crypto-key-management-solution.md)。
> 面向：想弄懂"加解密体系/密钥管理"方案背后原理的读者，不需要密码学预备知识。
> 姊妹前置：**TLS/HTTPS/证书原理**（握手、X.509、SAN、mTLS、证书生命周期）见 [tls-and-certificate-primer.md](tls-and-certificate-primer.md)；运行权限的账户/隔离原理见 [windows-account-and-isolation-primer.md](windows-account-and-isolation-primer.md)。

---

# 第一部分 · 背景知识（通用）

## 1. 三个最容易混的操作：编码 vs 加密 vs 哈希

| 操作 | 本质 | 可逆? | 要密钥? | 典型算法 | 在 PI 哪里 |
|------|------|:---:|:---:|----------|-----------|
| **编码 encode** | 换个表示法，**毫无安全性** | 可逆（人人可逆） | 否 | Base64、Hex、ASCII 数组 | `constant.mtp.core.key` 那串 `72,111,…`、`sunrise` 的 `c3VucmlzZQ==` 都只是**编码**，等于明文 |
| **加密 encrypt** | 藏内容，用时能读回 | 可逆（**要密钥**） | 是 | AES-256-GCM | DB 连接口令、SNMP 凭据 |
| **哈希 hash** | 单向指纹，只验不还原 | **不可逆** | 否 | SHA-256、bcrypt | 登录口令(bcrypt)、完整性校验(SHA-256) |

> 最大的坑：**Base64/ASCII 数组不是加密**。issue #260 里一堆"看起来乱码"的值其实是编码，等于明文——这正是安全团队判它明文凭据的原因。
>
> 一句话判断：要"读回明文"的 → 加密；只要"验证对错"的 → 哈希；只为"换个格式传输"的 → 编码（无安全）。

## 2. 熵：高熵 / 低熵

**熵（entropy）= 不确定性的度量，单位 bit**，直白说就是"猜中它得试多少种可能"。

- **高熵** = 可能性极多、每种均等、**猜不出来**。256-bit 随机 nonce = 2²⁵⁶ 种，暴力枚举=不可能。
- **低熵** = 可能性少或有规律、**好猜**。人设口令（`Passw0rd123`、生日、字典词）看着复杂，实际熵很低。

**为什么重要**：熵决定"能否被暴破"，也决定选哪种 KDF——
- 高熵材料（随机 nonce）→ 本就猜不中，用**快** KDF（HKDF）即可；
- 低熵口令（人记的）→ 容易猜，必须用**慢** KDF（bcrypt）把每次尝试拖慢来补偿。

## 3. 对称 vs 非对称加密

| 维度 | 对称加密 | 非对称加密 |
|------|----------|-----------|
| 钥匙 | **一把**，两头共用 | **一对**：公钥(公开)+私钥(自留) |
| 速度 | **快**（适合大数据） | **慢**（适合小数据/一次性） |
| 难题 | **怎么把钥匙安全交给对方**（分发难题） | 天生解决分发：公钥随便发 |
| 能力 | 只加解密 | 加解密 + **数字签名** + **身份认证** |
| 代表 | AES-256-GCM | RSA、ECDH/ECDSA |

**场景**：对称用于加密大量数据/会话流量/静态存储；非对称用于①协商出一把对称密钥 ②签名/验签 ③证书证身份。实战几乎都是**混合(hybrid)**：非对称先安全搞定对称密钥这件"小东西"，再用对称跑"大数据"——TLS 就是这么干（见 [tls-and-certificate-primer.md](tls-and-certificate-primer.md)）。

### "非对称比对称更安全"是误解

不是更安全，是**解决不同问题**：

- **等强度下对称钥匙短得多**：AES-128 ≈ RSA-3072 ≈ ECC-256 的安全水平。一把 256-bit 对称密钥强得离谱；RSA 要 3072 位以上才追平约 128-bit 安全。
- **非对称反而更"脆"**：安全性建立在特定数学难题（大数分解/离散对数）上，量子计算（Shor）先冲击 RSA/ECC；对称对量子只受 Grover 影响（强度减半，AES-256 仍够）。
- 非对称还慢、不适合大数据。

**结论**：用非对称不是因为更安全，而是它能做对称做不到的事（分发密钥 + 身份认证 + 签名）。两者互补。

## 4. 哈希 / 口令存储 / 密钥派生（三者别混）

| 用途 | 该用什么 | 特点 | PI |
|------|----------|------|----|
| 完整性/指纹 | **SHA-256 / SHA-3** | 快、抗碰撞；SHA-1/MD5 已破，禁 | 校验、HMAC 底层 |
| **存用户口令** | **bcrypt / Argon2 / PBKDF2** | **故意慢** + 加盐，抗爆破 | 登录口令(bcrypt) |
| **从高熵材料派生密钥** | **HKDF** | 快，Extract+Expand，按 info 分用途 | 配置密钥派生 |

> 记住：**慢哈希护低熵口令；快 KDF 派高熵密钥**，用反方向都出事（见第二部分 Q1/Q5）。

## 5. HMAC、PRF 与 AEAD

- **HMAC**（Hash-based MAC，RFC 2104）："带密钥的哈希" `HMAC(K,m)=H((K⊕opad)‖H((K⊕ipad)‖m))`。本职是**消息认证**（证明没被篡改、来自知道 K 的人）；也是个好用的**伪随机函数(PRF)**，被 HKDF 当积木。
- **PRF（伪随机函数）**：`F(key,input)` 在 key 保密时，输出对不知 key 者**不可区分于真随机**。"伪"= 其实是确定性算法（同输入同输出），但"装得像"随机。HMAC-SHA256 被认为是好 PRF。
- **MAC / AEAD**：MAC 是完整性校验（HMAC/GMAC/CMAC）。**AEAD**（认证加密）= 加密+认证一步到位，**AES-GCM** 就是；解密时标签对不上直接报错，防"篡改了还蒙混过关"。PI 的 `{cipher}` = `IV‖密文‖GCM-Tag` 正是 AEAD。

## 6. 三种"随机料"：salt / IV·nonce / install_nonce

三个都"随机"，但职责不同、是否保密不同：

| 名称 | 干什么 | 是否保密 | 是否每次变 |
|------|--------|:---:|:---:|
| **salt**（HKDF/口令哈希） | 去相关、防彩虹表 | **否**（按定义非秘密） | 每条/每实例 |
| **IV/nonce**（GCM） | 让相同明文每次密文不同 | 否 | **每次加密必换** |
| **install_nonce**（本方案） | 当作**被保护的秘密**参与派生 | **是**（靠文件权限） | 每实例 |

> 硬红线：**GCM 的 IV 在同一密钥下绝不能重复**，IV 重用会灾难性破坏 GCM 的机密性与完整性。生成密钥/IV/nonce 必须用 **CSPRNG**（Java `SecureRandom`），别用 `Math.random`。

## 7. 批准算法与档位（合规标尺）

- **两档**：**Baseline**（依据 NIST SP 800-131a Rev.2，商用足够）与 **Enhanced**（依据 CNSA/FIPS，政府/国防）。选定一档要满足该档**全部**参数。详见 [requirements §6.1](../../requirements/secure-requirements-definitions.md)。
- **本方案三算法均落 Baseline**：HKDF-SHA256、AES-256-GCM、HMAC-SHA256（无 ECB/CBC-SHA1/MD5）。
- **DES / 3DES 为什么不行**：DES 密钥仅 56 位、秒级爆破；3DES 块长 64 位受 Sweet32、NIST 已弃用。二者**都不在批准集**（3DES 仅"解旧数据"），新代码一律 **AES-256-GCM**。
- **档位影响**：对称是否限 AES-256、证书 RSA-2048 vs RSA-3072/ECDSA-P384、口令 KDF 迭代数——需你/安全团队拍板（P1）。

> **§8 HTTPS/TLS、§9 PKI/X.509 已迁至 [tls-and-certificate-primer.md](tls-and-certificate-primer.md)**（含 TLS1.2/1.3 三张握手图、前向保密、证书字段、keystore/truststore、SAN、mTLS、证书生命周期等）。以下 §10/§11 编号保留不变。

## 10. 知识地图与优先级（速查）

| 块 | 一句话 | 紧要度（对类别二） |
|----|--------|:---:|
| A 编码/加密/哈希三分 | #260 判定的根 | ★★★ |
| B 对称加密(AES/模式) + E AEAD + F 随机料 | 配置密钥加密全在这 | ★★★ |
| D 哈希/口令/KDF | bcrypt vs HKDF | ★★★ |
| C 非对称 + 2 熵 | 理解 TLS 与暴破 | ★★ |
| 7 批准算法/档位 | 合规标尺 | ★★ |

## 11. 术语表

| 缩写 | 全称 | 人话 |
|------|------|------|
| AES | Advanced Encryption Standard | 现代标准对称分组密码（128/192/256 位） |
| GCM | Galois/Counter Mode | AES 的认证加密模式（AEAD），带完整性标签 |
| AEAD | Authenticated Encryption with Associated Data | 加密+认证一体，防篡改 |
| HKDF | HMAC-based KDF (RFC 5869) | 从高熵材料 Extract+Expand 派生密钥 |
| KDF | Key Derivation Function | 密钥派生函数（HKDF/口令 KDF 两类） |
| HMAC | Hash-based MAC | 带密钥的哈希，做完整性/PRF |
| PRF | Pseudo-Random Function | 伪随机函数，输出不可区分于真随机 |
| bcrypt/Argon2/PBKDF2 | — | 故意慢的**口令哈希** KDF，抗爆破 |
| SHA-2/3 | Secure Hash Algorithm | 单向哈希（指纹/完整性）；SHA-1/MD5 已破 |
| RSA | Rivest–Shamir–Adleman | 非对称，靠大数分解；看密钥长度 2048/3072/4096 |
| ECDH/ECDHE | (Ephemeral) Elliptic-Curve Diffie-Hellman | 椭圆曲线密钥协商；E=临时=前向保密 |
| ECDSA/EdDSA | 椭圆曲线签名 | 同强度下比 RSA 更短更快 |
| IV / nonce | Initialization Vector | 每次加密的随机料，GCM 下不可重用 |
| salt | 盐 | 非保密随机料，去相关/防彩虹表 |
| CSPRNG | 密码学安全随机数生成器 | 生成密钥/IV 必须用它（`SecureRandom`） |
| FIPS 140 | 美国密码模块合规 | Enhanced 档常要求验证过的模块 |
| CWE-798 | Use of Hard-coded Credentials | `constant.mtp.core.key` 硬编码即此类 |

---

# 第二部分 · 本方案相关问答（为什么这么设计）

## Q1 · HKDF 是什么、为什么用它、有无替代；`HKDF-SHA256(...)` 与 AES-256-GCM 拆解

**HKDF** = HMAC-based Key Derivation Function（RFC 5869）。职责：把可能不均匀/不定长的**输入密钥材料(IKM)** 变成一把/多把强密钥。两步：

```
① Extract:  PRK = HMAC-SHA256(key=salt, data=IKM)          → 32B 伪随机中间密钥
② Expand:   OKM = HMAC-SHA256(key=PRK,  data=info || 0x01)  → 32B = AES-256 密钥
```

逐项拆解本方案的 `HKDF-SHA256(IKM=machine_id‖install_nonce, salt=32零, info="vertiv-pi-data-key-v1")`：

- **IKM**：`machine_id 字节 ‖ install_nonce 字节`（直接拼接，边界靠各自定长确定）。是"原料"，不要求均匀随机。
- **salt**：32 个零字节。salt **不保密**，作用是给 Extract 一个随机化器；RFC 5869 规定"无外部 salt 时用 HashLen 个零"，SHA-256 的 HashLen=32。
- **info**：用途标签 `"vertiv-pi-data-key-v1"`，把密钥绑到具体用途；换 info 得到完全不同的密钥（见 Q2）。
- **Extract** 把结构不规整的 IKM 浓缩成规整 PRK；**Expand** 里的 `0x01` 是块计数器（只要 32 字节，单轮即可）。

**为什么选 HKDF**：输入是高熵材料（256-bit 随机 nonce），派生密钥的标准工具就是 HKDF（快、标准、批准集内）。对比**低熵口令**要用 PBKDF2/bcrypt/Argon2（故意慢抗爆破）。**替代**：KBKDF(SP 800-108)、Concat-KDF(SP 800-56C) 功能类似；本场景 HKDF 最主流。

**AES-256-GCM 怎么做**：拿 32B 的 OKM 当 AES 密钥；每次加密生成 **12B 随机 IV**，AES 以 CTR 模式产密钥流与明文异或得密文，再用 GHASH 算 **16B 认证标签 Tag**；落盘存 `Base64(IV‖密文‖Tag)`。IV 每次随机 → 相同明文不同密文；解密重算 Tag，对不上抛 `AEADBadTagException`。

## Q2 · "每功能一把独立密钥"怎么做到，背后原理

靠 Expand 的 **info 标签**做**域分离(domain separation)**：

```
数据密钥  = HKDF-Expand(PRK, info="vertiv-pi-data-key-v1")
SNMP 密钥 = HKDF-Expand(PRK, info="vertiv-pi-snmp-key-v1")
备份密钥  = HKDF-Expand(PRK, info="vertiv-pi-backup-key-v1")
```

同一 PRK 喂不同 info → 因 HMAC-SHA256 是 **PRF**，不同消息的输出**不可区分于独立随机值** → 得到互相独立的密钥。且从一把推不出 PRK、也推不出另一把（要反推等于攻破 HMAC/SHA-256）。**info 不同时前面（salt+IKM→PRK）完全相同，只有 Expand 这步因 info 不同而产出不同密钥**。这就是"一根秘密→无数把互不牵连子钥"的数学来源，恰好满足 AR-00-06"每功能独立密钥"。

**应用层难用吗**：不难。原来"取那把固定 key"的地方，改成"向 `MachineKeyService` 要对应 info 的派生 key"；PI 加解密已集中在 `EncryptDecryptService`，改动点很少。

## Q3 · "密钥不落盘"到底啥意思；重启后密钥会变吗

**半对，需读准确**：**派生出的 AES 密钥本身不落盘**（内存重算、缓存、进程结束即消失）；**但输入之一的 `install_nonce` 落盘**（明文，靠文件权限保护）。准确说是"**没有任何单一落盘文件 == 那把密钥**"，而非"所有秘密都不落盘"。

**重启不改变密钥**：machine_id、nonce 都不变，HKDF 是**确定性**函数 → 每次启动**原样重算出同一把**，旧密文照常能解；"进程结束即消失"只是那份内存缓存，下次启动用相同输入再算一遍。

## Q4 · nonce 为何落盘；攻击者拿到什么才算得出密钥；salt 为何固定 0；命门为何在 nonce；为何不用随机 salt

**nonce 为何必须落盘**：HKDF 确定性 → 要每次重启重算出同一密钥，nonce 必须持久化。若只用 machine_id（不存 nonce）：machine_id **不保密**、且无 per-install 随机 → 密钥可预测、不唯一，不安全。所以**存的是"输入"nonce，不是"密钥"**。

**攻击者拿到什么才能算出密钥**：密钥 = `HKDF(machine_id‖nonce, salt=32零, info)`。四个输入里 **salt 公开、info 是写死的公开标签、machine_id 不保密**，**只有 nonce 是被保护的 256-bit 秘密**。所以：拿齐 **machine_id + nonce** 即可重算出密钥（salt/info 不算秘密）。反过来——**读不到 `machine.properties`（拿不到 nonce）就算不出**（256-bit 不可猜）。

**salt 为何固定 32 个 0**：RFC 5869 默认（无外部 salt 用 HashLen 个 0），不影响安全；salt 的职责是"提取均匀随机性"，不是藏秘密。

**为何命门在 nonce / 是不是"全赌 nonce"**：是，且这样**是对的**。把秘密**集中到一个定义清晰、高熵、可保护、可轮换**的值，是好设计，符合 Kerckhoffs 原则（不靠算法/标签隐蔽，只靠密钥保密）。

**machine_id 图啥（既然不保密）**：它不负责保密，负责**"绑机"**——把密钥绑到这台物理机。攻击者就算把"密文+machine.properties"整套拷到别的机器，machine_id 不同 → 密钥不同 → **解不开**；他必须在目标机上/知道目标机 machine_id。门槛从"偷两个文件"抬到"必须在这台机"。

**为何不用随机 salt**：salt **按定义非保密**，随机 salt 也要明文存 → 对攻击者**零保密增益**；而 nonce **已经**提供了 256-bit 每实例随机。再加随机 salt 只是"重复的随机、没有新秘密"，徒增一个要存/备份的值。就算把 salt 也设成保密随机并同样保护——那它其实**就是第二个 nonce**，安全强度不变（攻击者突破"能读保护文件"这道边界就两个都拿到）。

## Q5 · 登录口令 vs 配置密钥：加密还是哈希、bcrypt 用在哪

两条不同的线，别混：

| 数据 | 处理 | 算法 | 要留密钥? | 能还原? |
|------|------|------|:---:|:---:|
| **用户登录口令** | **哈希(单向)** | **bcrypt** | 不要 | 不可还原，只能比对 |
| **配置里的秘密**(DB 连接口令/SNMP 凭据) | **加密(可逆)** | AES-256-GCM + HKDF 派生密钥 | 要(派生密钥) | 可还原(运行时要用明文) |

- **登录口令不用那把派生密钥，也不做加密**，而是 **bcrypt 哈希**入库；登录时把输入口令再 bcrypt 后与库里哈希**比对**。全程无密钥、无人能反推原口令。
- **bcrypt 是"哈希"不是"加密"**（加密可逆、哈希不可逆）。PI 用 `BCryptPasswordEncoder`（Spring Security）。
- **为什么口令哈希、配置口令加密**：登录口令系统**永不需要知道明文**（只验对错）→ 哈希最安全（库泄露/管理员都拿不到明文）；DB 连接口令**运行时真要拿明文去连库** → 只能可逆加密。

## Q6 · DES 能用吗

**不能。** Baseline 分组加密只批 AES-128/192/256；单 DES（56 位密钥，秒破）**根本不在清单**；3DES（64 位块、Sweet32、NIST 已弃）**仅允许解旧数据**、禁止新加密。新代码一律 **AES-256-GCM**（否则违反 AR-00-01）。

> **Q7（HTTPS 原理问答）、Q8（#58 证书问题修哪一步）已迁至 TLS 文档**：原理问答见 [tls-and-certificate-primer.md](tls-and-certificate-primer.md)，#58 现状与修正见 [../tls-certificate-solution.md](../tls-certificate-solution.md)。以下 Q9~Q11 编号保留不变。

## Q9 · bcrypt 是"慢 KDF"吗；为何口令存储要"慢+盐"；盐存哪；SHA-256 能抗爆破吗；AES-256 与 SHA-256 是一回事吗

**AES-256 ≠ SHA-256**，只是都叫"256"：

| | AES-256 | SHA-256 |
|---|---|---|
| 类别 | 对称**加密** | **哈希** |
| 可逆 | 可逆（有密钥能还原） | 不可逆（单向） |
| 要密钥 | 要（256-bit **密钥**长度） | 不要（256-bit **摘要**长度） |
| 干嘛 | 藏数据、用时读回 | 指纹/完整性/口令处理的底层积木 |

**bcrypt 确实是"慢 KDF"（口令哈希函数）**：基于 Blowfish 的密钥编排（Eksblowfish），带 **cost 因子**（PI 默认 strength 10 = 2¹⁰ 轮），算一次几十毫秒。

**PI 实现（代码实锤）**：`@Qualifier("cryptoPasswordEncoder")` 的 `PasswordEncoder` = Spring Security `BCryptPasswordEncoder`；且存库前多一步 `sha256Hex(password)` 再 bcrypt，即库里存 `bcrypt(sha256hex(明文))`（见 `SessionsApplicationEventHandler#isPasswordMatch`）。那个 `sha256Hex` 前置步骤**不是安全控制**（快、无盐），真正抗爆破的是外层 bcrypt。

**为何"慢 + 盐"**：
- **慢**：登录口令是**低熵**（人记得住=好猜）。哈希越快，攻击者离线每秒能试越多。SHA-256 在 GPU 上每秒几十亿次 → 字典/暴破分分钟破；bcrypt 每次几十毫秒 → 每核每秒只能试几十次，且 cost 可随硬件调高。**用变慢补偿口令低熵。**
- **盐**：每条口令一个随机盐 → ① 防彩虹表（预计算失效）；② 相同口令哈希也不同 → 不能"一次破全部"，必须逐个爆破。

**盐存哪**：**嵌在 bcrypt 输出串里**，形如 `2a`（版本）、`10`（cost）、22 位盐、31 位哈希四段用美元符分隔（即 `&#36;2a&#36;10&#36;盐哈希`），与哈希一起躺在 DB。**盐不保密**，作用是去重/防预计算，不是藏秘密。

**SHA-256 能抗爆破吗**：对**高熵**输入（256-bit 随机密钥）可以（原像不可逆）；对**低熵口令**存储**不行**（太快、本身无盐）。所以口令存储必须用 bcrypt/Argon2/PBKDF2（内部虽也用 SHA 类，但**多轮迭代 + 加盐**）。**纪律：口令用慢哈希、完整性/指纹用 SHA-256、配置密钥派生用 HKDF——三条线别混。**

## Q10 · `install_nonce` 落盘怎么保护；OS-seal 是什么；明文+权限是不是业界主流

**"明文 nonce + 文件权限"是软件层的标准做法**（业界主流）：SSH 私钥 `~/.ssh/id_rsa`（明文 `chmod 600`）、PostgreSQL `.pgpass`（`chmod 600`，权限不对直接拒读）、K8s Secret（etcd 里 base64 + RBAC/磁盘加密）都是同一模型——安全边界 = **文件系统权限 + OS 访问控制**，对应 AR-00-02 的"软件档"。

**具体处置**：

| 维度 | 做法 |
|------|------|
| 存储 | `machine.properties` 单行 `install-nonce=<64位Hex>`，256-bit，`SecureRandom` 生成 |
| 权限-Linux | `chown si_app:si` + `chmod 600`（仅 owner 读写，组/其他全无） |
| 权限-Windows | `icacls machine.properties /inheritance:r`（断继承，去掉 `BUILTIN\Users` 读）+ `/grant:r "NT SERVICE\TAFsvc:(R)"`（只授服务 VSA 读） |
| 是否加密 nonce 本身 | **Baseline 不加密**（加密它又要另一把密钥、鸡生蛋）；靠权限护 |

**纵深防御要点**：`machine_id` 绑机意味着**光把 `machine.properties` 拷到别的机器也没用**（machine_id 变→密钥变）。有效防护 = 文件权限（防本机越权读）+ 机器绑定（防拷走/离线）。

**OS-seal = 用操作系统自带的密钥保护设施，把 nonce"封"起来，光读到文件也解不出**：
- **Windows：DPAPI**（`ProtectedData`/`CryptProtectData`，machine scope）——OS 持绑本机主密钥，密文**只能同机解**。
- **Linux：内核 keyring（`keyctl`）或 TPM 封存**——TPM 硬件芯片，数据封入后只能在该硬件解封。
- **跨平台更高档：Vault/KMS**（外部服务持钥）。
- **代价**：更强但平台相关、复杂、有可用性/备份坑（TPM 重置=丢）。→ 定位为**高保障客户的"逃生口"，只登记不做**；Baseline 用"明文 + `chmod 600`/VSA-ACL + 机器绑定纵深"。

## Q11 · 每实例默认登录口令用 `SecureRandom` 还是 HKDF

| 维度 | A：`SecureRandom` 直生 | B：`HKDF` 派生 |
|------|------------------------|----------------|
| 速度 | 一步生随机串 | 多一次 HMAC（可忽略） |
| 安全 | **等价**（都 CSPRNG 高熵） | 等价 |
| 可重算 | 否（只在文件 + DB 哈希） | 是（machine_id+nonce+info 可重推） |
| 语义 | **一次性秘密**，反正要落文件——正合适 | "密钥"当口令用，语义别扭 |
| 域隔离 | 默认口令**不进**密钥派生域，干净 | bootstrap 口令与保护全局的 nonce 耦合 |

**结论：用 A（`SecureRandom`）。** 默认口令**本就要写进文件**给运维，不需要"可重算"；A 还把它排除在密钥派生域外，职责更清。B"文件丢了还能重推"反而是缺点（默认口令成了 nonce 的函数）。

**A 的流程**：安装期 `pwd = Base64URL(SecureRandom 24字节)` → ① 写 root-only 文件（`chmod 600`/VSA-ACL）② DB admin 口令置 `bcrypt(sha256hex(pwd))`；前端 `827.js` 删写死值改普通输入框；首登运维读文件手敲 → 后端校验 == 库值 → 用 `init.password` 覆盖入库；onboarding 完成后删该文件。→ 详见方案文档 2-1-e。

---

# 第三部分 · 与方案文档的关系

- 本文只讲**原理与"为什么"**；**现状、触点全景、决定与改动点落地**见 [../crypto-key-management-solution.md](../crypto-key-management-solution.md)；**TLS/证书原理**见 [tls-and-certificate-primer.md](tls-and-certificate-primer.md)。
- 关联任务：[类别二 · 任务 2-1/2-3-a](../../01-remediation-task-ledger.md)（2-2 TLS 证书见 [tls-certificate-solution.md](../tls-certificate-solution.md)）；需求定义 [secure-requirements §6.1 批准算法](../../requirements/secure-requirements-definitions.md)。
- 关联 issue：[#260 硬编码伞状](../../issues/issue-260-as01-00-hardcoded-secrets-umbrella.md)、[#51 admin 引导口令](../../issues/issue-51-as01-00-admin-user-autoload-password.md)。
