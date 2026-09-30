# MANIFEST · 来源与快照记录

> **快照日期**：2026-09-30（项目结项当日）
> **为什么有这份文件**：这个目录里的内容原本散落在一个项目仓库的六个不同位置。搬走之后，如果没有这份记录，就无法回答「这份是我写的还是从哪里 copy 的、对应工程哪个状态」。
> **为什么源文档没有加任何说明**：源目录在搬走后即从工程中删除，若在源文档上写「已复制到某处」，那句话搬完之后就指向一个不存在的位置，反而制造悬空引用。**元数据跟着资产走，工程侧零污染。**

---

## 一、内容清单（29 份 md，8,404 行 / 约 768 KB）

按目录：`1-foundations` 7 份 2,165 行 · `2-design` 10 份 2,025 行 · `3-postmortems` 4 份 1,639 行 · `4-methodology` 3 份 1,428 行 · `5-delivery` 1 份 294 行 · `6-career` 2 份 611 行 · 根目录 2 份 242 行。

标记含义：**copy** = 原件仍在工程中；**move** = 已从工程删除，本目录是唯一副本；**excerpt** = 节选，非全文；**new** = 本次新写。

### `1-foundations/` · 背景知识与术语（7 份，2,165 行）

| 本目录文件 | 行数 | 方式 | 原始位置 |
| :--- | ---: | :--- | :--- |
| `crypto-primer.md` | 269 | copy | `docs/security-fix/design/background/crypto-primer.md` |
| `tls-and-certificate-primer.md` | 171 | copy | `docs/security-fix/design/background/tls-and-certificate-primer.md` |
| `windows-account-and-isolation-primer.md` | 317 | copy | `docs/security-fix/design/background/windows-account-and-isolation-primer.md` |
| `linux-dependency-glossary.md` | 543 | copy · 改名 | `docs/os-support/04-linux-dependency-glossary.md` |
| `linux-deployment-gotchas.md` | 466 | copy · 改名 | `docs/os-support/05-linux-deployment-gotchas.md` |
| `cmd-delayed-expansion.md` | 191 | copy | `docs/links/cmd-delayed-expansion.md` |
| `os-dependency-contract-surfaces.md` | 208 | **excerpt** · new header | `docs/os-support/02-os-dependency-contract.md` **第 26–221 行**（一/二/三节） |

⚠️ **`os-dependency-contract-surfaces.md` 是节选**：只取了契约面总表、16 项逐项说明、环境指纹采集项与判读标准，**未取**第四节（采集脚本规格）、第五节（与选包文档的边界）、附录 A（release notes 预期值基线）、附录 B（实测指纹）。未取的原因是项目特定或过期即废。头部说明由本次新写。
⚠️ 因此其它文档里指向「附录 A / A.5 / A.6」的链接虽然被重指到了这份文件，**但那些附录的内容不在这里**——标签保留是为了说明原文有这部分，不是说这里能查到。

### `2-design/` · 设计方案（3 份 + 1 组预研 7 份，2,025 行）

| 本目录文件 | 行数 | 方式 | 原始位置 |
| :--- | ---: | :--- | :--- |
| `crypto-key-management-solution.md` | 452 | copy | `docs/security-fix/design/crypto-key-management-solution.md` |
| `runtime-permission-solution.md` | 365 | copy | `docs/security-fix/design/runtime-permission-solution.md` |
| `tls-certificate-solution.md` | 280 | copy | `docs/security-fix/design/tls-certificate-solution.md` |
| `replace-installanywhere/`（7 份） | 928 | copy | `docs/replace-installanywhere/`（README + 01–06） |

### `3-postmortems/` · 机理复盘（4 份，1,639 行）

| 本目录文件 | 行数 | 方式 | 原始位置 |
| :--- | ---: | :--- | :--- |
| `migration-and-platform.md` | 404 | copy · 改名 | `docs/migration-remediation-archive/02-hardcore-technical-postmortems.md` |
| `security-hardening.md` | 355 | copy · 改名 | `docs/migration-remediation-archive/06-security-hardening-postmortems.md` |
| `os-support-and-installer-defects.md` | 679 | copy · 改名 | `docs/migration-remediation-archive/07-os-support-and-installer-defects-postmortems.md`（**该文件本身是 2026-09-30 新写**） |
| `cmd-delayed-expansion-cdrive-deletion.md` | 201 | copy | `docs/postmortems/cmd-delayed-expansion-cdrive-deletion.md` |

### `4-methodology/` · 方法论（3 份，1,428 行）

| 本目录文件 | 行数 | 方式 | 原始位置 |
| :--- | ---: | :--- | :--- |
| `ai-assisted-reengineering.md` | 230 | **move** · 改名 | `docs/migration-remediation-archive/03-ai-assisted-reengineering-methodology.md` |
| `ai-collaboration-retrospective.md` | 581 | copy · 改名 | `docs/retrospectives/ai-installanywhere-collaboration.md` |
| `real-prompts-and-decisions.md` | 617 | copy · 改名 | `docs/presentations/cursor-team-share-cases-what-i-did.md` |

### `5-delivery/` · 交付参考（1 份，294 行）

| 本目录文件 | 行数 | 方式 | 原始位置 |
| :--- | ---: | :--- | :--- |
| `linux-delivery-and-qa.md` | 294 | copy · 改名 | `docs/migration-remediation-archive/05-linux-delivery-and-qa-guide.md`（原件已移至 `docs/delivery-qa/`） |

### `6-career/` · 职业素材（2 份，611 行）

| 本目录文件 | 行数 | 方式 | 原始位置 |
| :--- | ---: | :--- | :--- |
| `portfolio-and-mock-interviews.md` | 496 | **move** · 改名 · **已重写** | `docs/migration-remediation-archive/04-career-portfolio-and-mock-interviews.md` |
| `resume-ready-project-blocks.md` | 115 | **new** | — |

### 根目录

| 文件 | 行数 | 方式 |
| :--- | ---: | :--- |
| `00-README.md` | 83 | new |
| `MANIFEST.md` | — | new |

---

## 二、对原文做过的加工

### 2.1 脱敏（共 215 处替换）

**公司与产品名**：公司名 → `该公司`；产品全名 → 保留两字母缩写（缩写本身不指向任何具体产品）。

**开发机与安装路径**（8 类，逐类映射）。

⚠️ **注意：下面这张映射表本身保留了替换前的原始字符串** —— 这是有意的，它是唯一能反查「某个 `<repo>\installer` 原本指向哪里」的审计记录。**除本文件之外的所有文档都已清洗干净（复核命中 0 处）。** 如果日后要把这个目录分享给他人，删掉本小节即可，其余部分不含任何原始路径。

映射表：

```text
D:\cursor_workspace\cursor_out\copy\taf-core-installer  →  <repo>\installer
D:\cursor_workspace\cursor_out\copy                     →  <repo-root>
D:\idea_workspace\zero-engine-pi-installer              →  <repo>\engine-packaging
D:\idea_workspace\taf-plugin-pi-backuprecovery          →  <repo>\backup-plugin
d:\cursor_workspace\pi-installer\scripts                →  <docs-repo>\scripts
E:\software\PI3.0.1\main                                →  E:\...\<install-root>
E:\software\PI4.0\main                                  →  E:\...\<install-root>
E:\software\PI4.0                                       →  E:\...\<install-root>
```

按要求**清洗而非打码**——保留能代表语义的结构（盘符 + 省略 + 角色名），去掉机器特定的中间路径。

**内部编号 → 稳定别名**（保留交叉引用能力，去掉真实 ID）：

```text
内部工单号  #260 / #36 / #51        →  ISS-CRED / ISS-CRED-2 / ISS-CRED-3
            #58                     →  ISS-CERT
            #72 / #122 / #76        →  ISS-AGENT-1 / -2 / -3
需求编号    AS-01-00 / AR-00-06     →  REQ-CRED / REQ-CERT
            IA-02-03 / IA-01-02     →  REQ-PRIV / REQ-PARAM
需求单号    SR0292                  →  SEC-REQ
用户故事号  US1259                  →  US-LOGIN
CVSS 具体值 CVSS 8.4 / 7.5 / 3.7    →  CVSS 高危 / 高危 / 低危（只留严重级别）
```

**保留未动**（这些不是敏感信息，删掉会让叙述变成空话）：技术机理、开源组件真实版本号（PostgreSQL 18、liburing 2.5、glibc 2.34 等）、方案对比与否决理由、判据与验证方法、成果量级、操作系统标准路径（`C:\ProgramData\`、`C:\Windows\System32\`）、以及文中作为示例出现的 IP（如 `10.1.2.3`，非真实主机）。

**经核实不存在的**：内网主机 IP。那些只出现在项目的实机结果文件里（`docs/os-support/results/`），不在本目录范围内。

### 2.2 脱敏深度分两档（有意如此）

- **`6-career/` 两份 = 完全脱敏**：公司名、产品名、**以及所有内部服务与文件标识**（服务名、WAR 名、配置文件名）全部换成中性描述。这两份是会给外部看的。
- **其余各份 = 只脱公司名与产品名，保留内部技术标识**。原因：这些标识（服务名、配置文件名等）不指向任何公司或产品，但它们是技术叙述的骨架——抽掉之后复盘就读不懂了。这批是自用参考。

### 2.3 链接处理（共 406 条）

搬出工程后，原先指回项目真源的链接全部会失效。处理规则三档：

- **保留 158 条** —— 外部 URL、文档内锚点、以及本目录内可解析的相对路径。
- **重指 80 条** —— 指向那些**也被带进本目录但改了名**的文件，按新路径重写（例如原 `02-hardcore-technical-postmortems.md` → `../3-postmortems/migration-and-platform.md`）。
- **转纯文本 168 条** —— 指向只存在于工程中的文档（进度真源、任务清单、实机结果、执行计划等）。改为**加粗标签 + 「（内部真源，不随本目录）」**，保留「原文在这里引用了什么」的信息，但不留死链。

**审计结果：本目录内 158 条内链全部可解析，0 条死链、0 条路径解析失败。**

### 2.4 `6-career/portfolio-and-mock-interviews.md` 的实质性修订

这一份不只是 copy，做了四类修改（逐条理由写在该文档开头的「口径说明」里）：

1. **级别口径重校** —— 早期版本按 Staff / Principal 口径撰写，用了「主导 / 推行 / 作为技术攻坚负责人」；已改为可核验的动词。内容一条没减。
2. **删改三处无法辩护的断言** —— 「零漏报」、「将风险降低至绝对零值」、「构建成功率提升至 100%」。
3. **重写 SQLite 那一段** —— 原文写「团队有人提出共享主库、我坚决否决」，**与事实不符**（真实情况是与架构讨论过选型，没有否决谁）；已改写为后来真正发现的那件事：存储生命周期边界划错导致的不对称。
4. **新增内容** —— 2026-09 维度的简历要点与第 4 段 STAR 叙事、模拟面试 Q12~Q17（六道，按通用价值排序）、术语翻译层、三个可重述为系统设计题的题材、以及「怎么讲 AI 协作」一节。

---

## 三、工程侧的对应变化（供追溯）

搬走本目录后，原项目里发生的变化：

- `docs/migration-remediation-archive/` **保留原名**，内容变为 `00-README` + `02` + `06` + `07`（新写的 Sept 复盘）。`02` 必须留在工程里——它被两份安全交付文档当作权威出处引用（讲「文本新增的对象 ID 会在保存阶段被剥离」这个坑）。
- `01` 与 `05` 两份交付 QA 指南**移至 `docs/delivery-qa/`**——它们是公司交付物，不属于知识资产。
- `03` 与 `04` **已从工程删除**，本目录是唯一副本。
- 背景知识、设计方案、预研、方法论、事故复盘的**原件全部留在工程中**，本目录持有的是快照副本。

---

## 四、后续维护说明

本目录搬进个人知识库后**与工程脱钩，不再自动同步**。工程侧若有修订，需手动同步；反之亦然。

标 **copy** 的那些，若日后想核对是否有更新，可回到上面的「原始位置」列对照。标 **move** 与 **new** 的三份（`ai-assisted-reengineering.md`、`portfolio-and-mock-interviews.md`、`resume-ready-project-blocks.md`）**本目录是唯一副本，没有上游可对照**。
