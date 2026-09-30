# 候选方案适配矩阵（纸面评估）

> **最后更新**：2026-05-28  
> **方法**：基于公开能力与 As-Is 清单（[02](02-as-is-capability-inventory.md)）做 **文档级** 映射，**无 POC**。  
> **标记**：原生 / 二开 / 高风险 / 待确认 — 见 [03](03-research-constraints-and-criteria.md) §5。

---

## 1. 候选列表

| ID | 候选 | 类型 | 一句话 |
|----|------|------|--------|
| A | **保留 InstallAnywhere** | 商业 | 现状基线；license 与 XML 维护成本持续 |
| B | **jpackage** (+ 辅助脚本) | OpenJDK | 应用+JRE 打包；安装 UI 简朴 |
| C | **Install4j** | 商业 | Java 安装器老牌；CustomCode 迁移路径相对清晰 |
| D | **WiX Toolset** (MSI) + **Linux 脚本/tar** | 开源+脚本 | Windows 标准化 MSI；Linux 需单独管线 |
| E | **NSIS** (Win) + **Linux 脚本/tar** | 开源 | 轻量 exe；复杂编排靠脚本 |
| F | **纯脚本/归档** (PowerShell + bash + tar/zip) | 自研 | 最大灵活度；UI/本地化需自建 |
| G | **Go 交叉编译安装器** | 自研 | 用 Go 产出跨平台安装器二进制，安装编排需自行实现 |

---

## 2. 能力 × 候选矩阵

行为与 [02](02-as-is-capability-inventory.md) §8 能力 ID 对齐。

| 能力 ID | 说明 | A IA | B jpackage | C Install4j | D WiX+Linux | E NSIS+Linux | F 脚本 | G Go 交叉编译 |
|---------|------|------|------------|-------------|-------------|--------------|--------|----------------|
| OFFLINE_PAYLOAD | 离线全量介质 | **原生** | **二开**（Mongo/插件需 `--resource-dir` 或前置 tar） | **原生** | **二开**（两套打包） | **二开** | **原生**（完全自控） | **原生**（完全自控） |
| WIN_LINUX | 双平台 | **原生** | **原生**（msi/exe/deb/rpm） | **原生** | **二开**（Win 原生，Linux 另做） | **二开** | **二开** | **原生**（Go 交叉编译） |
| SILENT | 静默安装 | **原生** | **原生**（CLI 参数） | **原生** | **原生**（msiexec / 脚本） | **原生** | **原生** | **原生** |
| SVC_WIN | TAFsvc/TAFdb/ZESvc | **原生**（现网 JSL+IA） | **二开**（需保留 JSL 或改 WinSW/自定义） | **二开** | **二开**（CustomAction/脚本） | **二开** | **二开** | **二开**（调用 `sc.exe` / JSL） |
| SVC_LINUX | TAFsvc.sh/zesvc | **原生** | **二开**（systemd unit 外挂） | **二开** | **二开** | **二开** | **原生** | **二开**（调用 systemd 脚本） |
| CONFIG_SUBST | 变量替换写配置 | **原生** | **二开** | **原生** | **二开** | **二开** | **原生** | **原生** |
| UNINSTALL | 卸载对称 | **原生** | **原生**（卸载器）但 **二开**（Mongo/ZE 清理顺序） | **原生** | **原生**（MSI）/ **二开**（Linux） | **二开** | **二开** | **二开**（需自建卸载状态） |
| I18N_UI | en/zh 安装 UI | **原生** | **高风险** | **原生** | **高风险**（WiX 可做，工作量大） | **高风险** | **高风险** | **高风险**（需自建 UI 或 CLI） |
| CUSTOM_JAVA | CustomCode JAR | **原生** | **高风险**（无 IA API） | **二开**（Install4j Java API） | **高风险** | **高风险** | **二开**（独立 java -jar hook） | **二开**（外部 Java hook 进程） |
| LICENSE_TIER | pi_license | **原生** | **二开** | **二开** | **二开** | **二开** | **二开** | **二开** |
| INSTALL_LOGS | 日志路径约定 | **原生** | **待确认** | **二开** | **二开** | **二开** | **原生** | **原生** |

---

## 3. 维度加权粗评（1–5，纸面）

| 维度 | 权重 | A | B | C | D | E | F | G |
|------|------|---|---|---|---|---|---|---|
| D1 离线全量 | 15% | 5 | 3 | 5 | 3 | 3 | 5 | 5 |
| D2 双平台 | 15% | 5 | 4 | 5 | 3 | 3 | 3 | 5 |
| D3 静默 | 12% | 5 | 4 | 5 | 4 | 4 | 4 | 4 |
| D4 卸载 | 12% | 4 | 3 | 4 | 4 | 3 | 3 | 3 |
| D5 服务注册 | 12% | 5 | 2 | 3 | 3 | 3 | 4 | 3 |
| D6 CustomCode | 10% | 5 | 1 | 4 | 2 | 2 | 3 | 2 |
| D7 多语言 UI | 8% | 5 | 2 | 4 | 2 | 2 | 2 | 1 |
| D8 CI 构建 | 8% | 3 | 4 | 3 | 4 | 4 | 5 | 5 |
| D9 许可/签名 | 5% | 2 | 5 | 3 | 4 | 5 | 5 | 5 |
| D10 学习曲线 | 3% | 4 | 3 | 3 | 2 | 3 | 2 | 2 |
| **加权约算** | 100% | **4.5** | **2.9** | **4.1** | **3.0** | **3.0** | **3.5** | **3.8** |

> 约算仅供排序讨论，**非决策结论**；D9 中 IA 分数低反映 license 成本，非技术能力。

---

## 4. 分候选摘要

### A — 保留 InstallAnywhere

- **优势**：零迁移；CustomCode、多语言、服务编排已验证。  
- **劣势**：`TAFCore.iap_xml` 体积大、可视化编排易静默失败（ZE 挂接教训）；IA license；构建依赖 `IA_HOME` 与专用 runner。  
- **结论倾向**：短期继续；替换动力主要来自维护性与 license，而非功能缺口。

### B — jpackage

- **优势**：无额外工具 license；与 JRE 21 路线一致；适合「单应用」打包。  
- **劣势**：PI 安装器是 **多组件平台交付**（Mongo + 多 zip 插件 + 双服务 + ZE），远超典型 jpackage 场景；CustomCode/Swing 无直接等价；中英安装 UI 弱。  
- **结论倾向**：单独 jpackage **难以覆盖 PI 主安装器**；若使用，更适合 **Agent 单 jar** 或未来「单 jar PI」形态（非当前 copy 基线）。

### C — Install4j

- **优势**：Java 安装器生态；可嵌入 Java 类作 action；双平台与静默成熟。  
- **劣势**：商业 license；仍需编排 Mongo/ZE/JSL；迁移 IA 工程工作量中等偏大。  
- **结论倾向**：若必须换商业方案，**与现 CustomCode 栈最接近** 的候选。

### D — WiX + Linux 脚本

- **优势**：Windows 企业客户熟悉 MSI；签名链成熟。  
- **劣势**：**双管线**；Linux 与 Windows 行为难一致；Java 钩子需 CustomAction 调 JVM。  
- **结论倾向**：适合 Windows 为主、愿接受 Linux 脚本维护的团队。

### E — NSIS + Linux 脚本

- **优势**：免费、exe 体积小、静默成熟。  
- **劣势**：复杂逻辑全在脚本；与 IA  declarative 模型差异大；多语言 UI 需插件。  
- **结论倾向**：成本敏感时的 Win 方案，**PI 复杂度偏高**。

### F — 纯脚本/归档

- **优势**：Maven 解包逻辑可复用；服务脚本（ZE `ze-install.sh`）已存在可抽取模式。  
- **劣势**：安装 GUI、许可协议、CustomCode 全要重建；长期维护责任在团队。  
- **结论倾向**：可作为 **绞杀 IA 编排** 的底层，但仍需上层 UI 框架（或接受纯静默）。

### G — Go 交叉编译安装器

- **优势**：单文件二进制、跨平台产物统一、CI 无 `IA_HOME` 依赖；离线 payload 与配置替换可完全自控。  
- **劣势**：不是现成安装器产品，需自建安装 UI/卸载登记/服务编排；`TAF-InstallerCustomCode` 需改为外部 Java hook 或重写。  
- **结论倾向**：可作为长期自主可控方案，但工程量接近「自研安装框架」，更适合在选项 2（先脚本化）后推进。

---

## 5. Agent 安装器单独一行

| 能力 | 建议 |
|------|------|
| 体量 | 单 jar + JSL + 少量配置，远小于 PI |
| 候选 | B jpackage、C Install4j、E NSIS 均 **比 PI 更匹配** |
| 决策 | 可与 PI **解耦**：PI 继续 IA，Agent 先行试点替代（若进入 POC 阶段） |

---

## 6. 初步结论（预研级，待评审）

| 排序 | 候选 | 说明 |
|------|------|------|
| 1 | **A 保留 IA** | 迁移成本最高；在 P1 未稳定前替换风险最大 |
| 2 | **C Install4j** | 若战略上必须弃 IA，纸面最平衡 |
| 3 | **G Go 交叉编译** | 自主可控与 CI 友好，但需自建安装框架能力 |
| 4 | **F 脚本 + 薄 UI** | 长期可控，短期投入大 |
| 5 | **D/E 分拆平台** | 运维双轨，适合明确 Win-first |
| 6 | **B jpackage** | 对 **当前 PI 全量安装器** 匹配度最低 |

**不推荐本轮直接进入 POC 的候选**：在无 P1 smoke 通过前，对任何非 A 方案启动 POC 均易重复 ZE/VM 类问题。

---

## 7. 文档关系

- 能力来源 → [02-as-is-capability-inventory.md](02-as-is-capability-inventory.md)  
- 评分权重 → [03-research-constraints-and-criteria.md](03-research-constraints-and-criteria.md)  
- 路径选项 → [05-migration-path-options.md](05-migration-path-options.md)
