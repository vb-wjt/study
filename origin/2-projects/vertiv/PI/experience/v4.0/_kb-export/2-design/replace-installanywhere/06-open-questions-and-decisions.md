# 待决问题与决策记录

> **最后更新**：2026-05-28  
> **用途**：预研阶段需要产品/交付/构建负责人拍板的事项；已确认规则记录在 §1。

---

## 1. 已确认决策（本次预研约束）

| ID | 决策 | 日期 |
|----|------|------|
| D-01 | 本次仅为预研，**不做 POC** | 2026-05-28 |
| D-02 | **不修改** `cursor_out/copy` 工程代码 | 2026-05-28 |
| D-03 | As-Is 基线 = **`cursor_out/copy`**，不考虑 PI 4.0 | 2026-05-28 |
| D-04 | 范围仅 **安装 / 静默安装 / 卸载**，**不含 upgrade** | 2026-05-28 |
| D-05 | 产出 5 份文档（02–06）于 `docs/replace-installanywhere/` | 2026-05-28 |

---

## 2. 待决问题（Open）

### 2.1 战略与范围

| ID | 问题 | 影响 | 建议选项 |
|----|------|------|----------|
| Q-01 | 替换 IA 的 **目标时间窗** 是什么？（维持 3.x 全周期 vs 6–12 个月内） | 决定是否启动 S1 绞杀或选项 4 | 待产品 |
| Q-02 | 是否 **必须与 PI 4.0 解耦**？（当前预研已排除 4.0，但路线图可能合并） | 避免重复投资 | 待架构 |
| Q-03 | **Agent 安装器** 是否与 PI **绑定同一替代技术**？ | 矩阵与工作量翻倍或减半 | 独立试点 vs 统一 |
| Q-04 | 替换的 **首要驱动力** 排序：license 成本 / XML 维护 / CI 无头构建 / 其他？ | 候选权重调整 | 待管理 |

### 2.2 交付与兼容

| ID | 问题 | 影响 | 备注 |
|----|------|------|------|
| Q-05 | 静默安装是否必须 **100% 兼容** 现有 `installer.properties` 键名？ | 客户自动化脚本 | 见 `silentsample.txt` |
| Q-06 | 卸载时「保留数据」是否仍为 **硬性需求**？默认行为？ | 卸载器 UI/静默参数 | 业务文档有二选一描述 |
| Q-07 | 安装介质命名与路径（`taf-installer.exe` / `.bin`）是否 **不可变**？ | 交付文档与脚本 | 待交付确认 |
| Q-08 | **PostgreSQL** 二进制仍在 CI 预置但 PI 链用途不明 — 是否属于安装范围？ | 范围膨胀 | 需读 IA 动作或标为遗留 |

### 2.3 技术

| ID | 问题 | 影响 | 备注 |
|----|------|------|------|
| Q-09 | CustomCode **Java 21** 与安装器 **bundled JRE** 不一致时，以何为准？ | 安装失败类 `UnsupportedClassVersionError` | 已发生；替换或修 VM |
| Q-10 | Windows **代码签名** 证书由谁提供、是否覆盖 ZESvc/TAFsvc？ | SmartScreen、UAC | Agent README 有 UAC 提示 |
| Q-11 | GitLab **仅 checksum artifact** 策略是否长期有效？替换工具后安装包如何分发？ | CI 设计 | `.gitlab-ci.yml` |
| Q-12 | 多语言是否必须保留 **Installer Localization.md** 同级能力（图片+许可+字符串）？ | D7 权重 | 可降级为仅字符串 |
| Q-16 | 若采用 **Go 交叉编译安装器**，`TAF-InstallerCustomCode` 是保留为外部 Java hook 还是重写为 Go？ | 技术路线与人力评估 | 需架构拍板 |

### 2.4 组织与 POC 门槛

| ID | 问题 | 影响 | 备注 |
|----|------|------|------|
| Q-13 | 谁拥有 **安装器** 的长期维护（平台组 vs PI 特性组）？ | 选项 2/3 人力 | 待组织 |
| Q-14 | P1（ZE 装机、SI 移除）** smoke 通过** 的定义与责任人？ | [03](03-research-constraints-and-criteria.md) POC 门槛 | 见 `task-process.md` |
| Q-15 | 若进入 POC，**先 PI 还是先 Agent**？ | 选项 4 vs 2 | 预研倾向 Agent 先行 |

---

## 3. 预研阶段性结论（待评审转正）

| ID | 结论 | 置信度 | 依据 |
|----|------|--------|------|
| C-01 | 当前 **不宜** 立即替换 IA | 高 | P1 未稳；矩阵 A 短期最优 |
| C-02 | 若替换，**优先绞杀编排（选项 2）** 而非一次重写 | 中 | ZE 脚本化先例；降 XML 风险 |
| C-03 | **jpackage 不适合** 作为 PI 全量安装器主方案 | 中 | 多组件+CustomCode+Mongo |
| C-04 | **Install4j** 是弃 IA 时纸面最均衡的商业候选 | 中 | [04](04-candidate-fit-matrix.md) |
| C-05 | **升级不在范围**；替换方案不得假设 IA upgrade 语义可继承 | 高 | 用户约束 |

---

## 4. 决策记录模板（评审后填写）

| 日期 | 决策 ID | 决议 | 决策人 | 备注 |
|------|---------|------|--------|------|
| | | | | |

---

## 5. 与任务进度的联动

| pi-installer 任务 | 与替换的关系 |
|-------------------|--------------|
| P1 ZE 装机验证 | 阻塞 POC；通过前维持选项 1 |
| P1 SI 移除 | 降低 IA 复杂度，利于未来 S1 |
| P1 去 IE | 减少一条 IA 链（copy 基线 pom 已无 ieinstaller） |
| replace-installanywhere | 本文档集；**等待 Q-01/Q-14 后** 决定是否 POC |

---

## 6. 文档索引

| 文档 | 路径 |
|------|------|
| As-Is 能力 | [02-as-is-capability-inventory.md](02-as-is-capability-inventory.md) |
| 约束与标准 | [03-research-constraints-and-criteria.md](03-research-constraints-and-criteria.md) |
| 候选矩阵 | [04-candidate-fit-matrix.md](04-candidate-fit-matrix.md) |
| 迁移路径 | [05-migration-path-options.md](05-migration-path-options.md) |
| 目录说明 | [README.md](README.md) |
