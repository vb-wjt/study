# 工程知识库 · 安装部署与交付工程专项

> **这是什么**：一段约四个半月的安装部署链路改造经历的知识沉淀。覆盖数据底座替换、伴生引擎替换、跨平台扩展、安全合规整改、操作系统支持范围论证、以及发布前缺陷收口六个阶段。
>
> **这个目录是自包含的** —— 它原本散落在一个项目仓库的六个不同位置，按「性质」而非「来源」重新组织过。每份文件的原始位置与快照日期见 **`MANIFEST.md`**。
>
> **已脱敏**：公司名、产品名、内部工单号与 CVSS 具体值、内部主机与路径已移除或改为类别描述。**技术机理、开源组件真实版本号、方案对比与否决理由、判据与验证方法全部保留** —— 删掉这些，叙述就只剩空话。

---

## 一、目录结构与取用建议

```
1-foundations/     背景知识与术语（不管做哪个项目都要知道的）
2-design/          设计方案（含被否决的方案与理由）
3-postmortems/     机理复盘（这个项目具体怎么踩的）
4-methodology/     方法论（AI 协同、提问模板、真实决策原话）
5-delivery/        交付与 QA 参考
6-career/          简历与面试素材
```

**分层纪律**：`1-foundations/` 与 `3-postmortems/` **刻意不合并**。前者是通用知识、脱离这个项目同样成立；后者是特定事故。混在一起会让读的人分不清哪段可以直接复用、哪段只是某个工具的怪癖 —— 而这个区分正是这批材料的核心价值。

**想快速回忆整个项目干了什么** → 读 `3-postmortems/` 三份复盘的章节标题。
**准备面试** → `6-career/resume-ready-project-blocks.md`（按岗位取一版）→ `portfolio-and-mock-interviews.md`（17 道模拟题）。
**下次遇到同类问题** → 先查 `1-foundations/`，那里是知识；再查 `3-postmortems/`，那里是坑。

---

## 二、`1-foundations/` —— 七份背景知识（约 1,965 行）

| 文件 | 内容 | 为什么值得留 |
| :--- | :--- | :--- |
| `windows-account-and-isolation-primer.md` | Windows 服务账户与隔离：per-service SID、虚拟服务账户与域信任、ACL 继承与属主、授权 vs 权限 | **最推荐的一份。** 中文资料极度碎片化，且大量博客把虚拟服务账户与内建账户混为一谈、不知道服务 SID 能把「登录身份」与「授权主体」解耦。含 Q1~Q6 自问自答，本身就是面试预演 |
| `linux-dependency-glossary.md` | ABI / soname / 符号版本 / glibc / libstdc++ / OpenSSL / libicu / RPM / systemd / SELinux / 上游分包 | 容器化把这些问题藏起来了，所以普遍不懂；但它们在镜像基底升级、多架构、静态链接与否的场景里反复出现 |
| `linux-deployment-gotchas.md` | 部署运行期陷阱速查：`RPATH` / `LD_PRELOAD`、glibc vs musl、`Type=notify`、capabilities、OOM / THP、`set -e` 的坑、CRLF shebang、`/tmp noexec` | **性质不同 —— 这是陷阱清单，价值在「不会再踩」。** 这类清单最难重建，因为它是经验结晶而不是知识整理 |
| `crypto-primer.md` | 对称 / 非对称、KDF 与 HKDF、AEAD 与 GCM、随机数、信封加密 | 原理网上都有，但**这份是按「要设计一套密钥体系时需要知道什么」组织的**，不是按教科书章节 |
| `tls-and-certificate-primer.md` | 证书链、自签与信任库、keystore / truststore、握手与套件 | 同上。它和上一份是能回答密钥体系那道面试题的底座 |
| `cmd-delayed-expansion.md` | CMD 两阶段解析机制、延迟展开的正确用法、`setlocal` 作用域、`%var%` 与 `!var!` 混用、`CALL` 二次延迟，含三个代码示例 | 通用机制（任何用 Windows 批处理的人都会踩）。对应的事故复盘在 `3-postmortems/`，**两者刻意分开** |
| `os-dependency-contract-surfaces.md` | 16 项 OS 依赖契约面 + 逐项说明 + 环境指纹采集项与五档判读 | **可迁移的是方法**：把隐式依赖显式化成一张可逐项判定的表。原文的脚本规格与具体版本值未纳入（过期即废） |

---

## 三、`2-design/` —— 设计方案

三份方案文档（密钥管理、运行权限、TLS 证书）与一组工具链替换预研。

**读这三份的重点是「被否决的方案与理由」**，不是最终实现 —— 那部分在面试里最值钱，也最容易在改写时被删掉，所以这里保留了原文。典型例子：密钥灾备为什么拒绝「存一把主密钥兜底」；服务降权为什么从虚拟服务账户返工到内建账户 + 服务 SID；TLS 为什么有一处导入步骤被判定「克制不做」。

`replace-installanywhere/` 是一份完整的**技术选型与迁移路径预研**（As-Is 能力矩阵、约束与准则、候选适配矩阵、迁移路径选项、待决项）。它是这批材料里最接近「系统设计文档」的东西，而且方法完全通用。

---

## 四、`3-postmortems/` —— 四份机理复盘

体例统一为「现象 → 机理 → 修复 → 教训」。

- `migration-and-platform.md` —— 迁移与跨平台线：CMD 延迟展开导致递归删除、打包器静默剥离文本新增节点、编译器堆损坏、服务链编排失效、跨平台攻坚。
- `security-hardening.md` —— 安全线：机器绑定密钥体系、加解密收敛、每实例唯一证书、服务降权与 Windows ACL 深水区、做减法的决策。
- `os-support-and-installer-defects.md` —— 支持范围与缺陷收口线。**其中第八～十三章是通用部分**，与具体工具无关：判据纪律（哪些证据会骗人）、证伪与自我订正、单变量对照实验的设计、工程纪律、决策留痕、方法论边界。**如果只读一部分，读这四章。**
- `cmd-delayed-expansion-cdrive-deletion.md` —— 那次事故本身的复盘（机制说明在 `1-foundations/`）。

---

## 五、`4-methodology/` · `5-delivery/` · `6-career/`

`4-methodology/` 三份：在闭源、小众、缺乏公开训练数据的技术栈上如何与 AI 协同（证据驱动、安全沙箱、上下文快照、证伪式检验）、协作方式回望与可复用提问模板、以及**真实决策原话摘录**（中英对照）。最后那份是「我怎么提问、怎么拍板」的一手证据，比任何事后总结都可信。

`5-delivery/` 一份：Linux 侧的交付与 QA 参考（平台支持矩阵、systemd 服务生命周期契约、离线打包契约、卸载架构决策）。留它是因为前半部分是架构说明而非测试用例。

`6-career/` 两份：`resume-ready-project-blocks.md`（按岗位分三个可直接粘贴的版本 + 带口径的可量化事实清单）与 `portfolio-and-mock-interviews.md`（17 道模拟面试题、术语翻译层、三个可重述为系统设计题的题材）。

⚠️ **`6-career/` 两份都做过一次级别口径重校**：早期版本按 Staff / Principal 口径撰写、用了「主导 / 推行」这类措辞，已按真实身份改为可核验的动词，并删掉了三处无法辩护的绝对化断言。理由与逐条清单写在两份文档的开头。

---

## 六、如果只带走三份

按「脱离原项目还成立 × 自己再学一遍要多久 × 网上查不到或查到的是错的」三条判据：

1. `1-foundations/windows-account-and-isolation-primer.md`
2. `1-foundations/linux-deployment-gotchas.md`
3. `3-postmortems/os-support-and-installer-defects.md` 的第八～十三章
