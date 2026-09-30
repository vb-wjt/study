# 预研约束与评估标准

> **最后更新**：2026-05-28  
> **用途**：锁定本次「替换 InstallAnywhere」预研的边界、方法与打分维度，避免后续讨论偏离范围。

---

## 1. 硬性约束（已确认）

| # | 约束 | 含义 |
|---|------|------|
| C1 | **仅预研** | 不做 POC、不产出可安装替代包 |
| C2 | **不改工程代码** | 不修改 `<repo-root>` 下任何源码、XML、pom、脚本 |
| C3 | **基线固定** | 仅以 `cursor_out\copy` 三工程为 As-Is 事实来源 |
| C4 | **不考虑 PI 4.0** | 不引用 PostgreSQL/Flyway/新 jar 布局等 4.0 目标态作为需求输入 |
| C5 | **不考虑升级** | 不评估覆盖安装、版本检测、`Upgrading` 分支、升级备份等 |
| C6 | **文档-only 产出** | 结论写入 `pi-installer/docs/replace-installanywhere/` |
| C7 | **范围场景** | 仅 **全新安装**、**静默安装**、**卸载** |

---

## 2. 研究范围

### 2.1 In scope

- `taf-core-installer`（PI 主安装器）全链路能力
- `TAF-InstallerCustomCode` 与 IA 的耦合方式
- `trellis-automation-agent-installer` 是否纳入同一替换决策（评估层，不实施）
- Maven 组装期与 IA 装机期的职责划分
- 候选工具纸面适配（见 [04-candidate-fit-matrix.md](04-candidate-fit-matrix.md)）

### 2.2 Out of scope

- 任何源码/PoC/CI 改造
- Upgrade / 就地升级 / 同版本修复安装
- PI 4.0 架构与打包目标
- 运行时 ZE/IE 业务迁移（属 `refactor_pi`）
- InstallAnywhere license 具体金额（可记为待补充，不作财务结论）

---

## 3. 非功能需求（NFR）

基于现网交付与客户约束（来自 PI 3.x 安装器实践与业务文档），作为评估 **Must / Should** 的依据。

| ID | NFR | 说明 | 优先级 |
|----|-----|------|--------|
| NFR-01 | 离线自包含 | 机房常无外网；单介质含 JRE、Mongo、war/插件、ZE | Must |
| NFR-02 | 双平台 | Windows（主）+ Linux（辅） | Must |
| NFR-03 | 静默安装 | `installer.properties` 或等价机制 | Must |
| NFR-04 | 可卸载 | 服务停止/删除 + 文件清理；Linux ZE 有 uninstall 脚本 | Must |
| NFR-05 | 服务可靠性 | Windows JSL 三服务 + Linux systemd/init | Must |
| NFR-06 | 配置可定制 | 端口、路径、DB 账号、HTTPS 8443 约定 | Must |
| NFR-07 | 许可证分级 | `pi_license.properties` / `PI_LICENSE` | Should |
| NFR-08 | 安装 UI 多语言 | 至少 en + zh_CN | Should |
| NFR-09 | 安装期 Java 逻辑 | CustomCode：端口检查、DB 连通、密码加密等 | Should |
| NFR-10 | CI 可构建 | 当前 GitLab + `IA_HOME`；替代方案需可进 pipeline | Should |
| NFR-11 | 代码签名 | Windows SmartScreen；现网有 UAC/签名相关经验（Agent README） | Should |
| NFR-12 | 包体与介质 | 现安装包数百 MB 级；替代不得无理由暴增 | Could |
| NFR-13 | 运维可诊断 | 安装/卸载日志路径可预期 | Could |

---

## 4. 评估维度与权重（纸面选型用）

用于 [04-candidate-fit-matrix.md](04-candidate-fit-matrix.md) 打分，**1–5 分**（5=完全满足或易满足，1=很难或需大量自研）。

| 维度 | 权重 | 评分关注 |
|------|------|----------|
| D1 离线全量打包 | 15% | 能否把 JRE/Mongo/war/ZE 打入单一安装物 |
| D2 Win/Linux 双端 | 15% | 官方支持 vs 脚本拼凑 |
| D3 静默/无人值守 | 12% | 配置文件、命令行参数、响应文件 |
| D4 卸载对称性 | 12% | 服务与目录清理是否一等公民 |
| D5 服务注册 | 12% | JSL/systemd/Windows SCM 集成难度 |
| D6 CustomCode 迁移 | 10% | Java 21 钩子、Swing UI、IA API 依赖 |
| D7 多语言安装 UI | 8% | 与 IA 级本地化差距 |
| D8 构建/CI 集成 | 8% | 是否依赖商用 IDE、headless 构建 |
| D9 许可与签名成本 | 5% | 工具 license + 代码签名证书 |
| D10 团队学习曲线 | 3% | 技能栈匹配度（主观，需团队校准） |

**说明**：D1–D5 合计 66%，与「装机交付」直接相关；本次因 **排除升级**，不设「升级检测/迁移」维度。

---

## 5. 能力适配标注约定

在矩阵中使用下列标记（非 POC 验证，基于文档与公开能力）：

| 标记 | 含义 |
|------|------|
| **原生** | 工具典型能力即可覆盖，预计少量配置 |
| **二开** | 需额外脚本/自研模块/包装层 |
| **高风险** | 已知短板或 PI 强依赖 IA 特性 |
| **待确认** | 需后续 POC 或厂商文档核实（本轮不执行 POC） |

---

## 6. 预研完成定义（Definition of Done）

满足以下条件可视为预研阶段完成：

1. [x] As-Is 能力清单（[02-as-is-capability-inventory.md](02-as-is-capability-inventory.md)）
2. [x] 约束与 NFR（本文档）
3. [x] 候选矩阵（[04-candidate-fit-matrix.md](04-candidate-fit-matrix.md)）
4. [x] 迁移路径选项（[05-migration-path-options.md](05-migration-path-options.md)）
5. [x] 待决项清单（[06-open-questions-and-decisions.md](06-open-questions-and-decisions.md)）
6. [ ] **评审会**：产品/交付/构建负责人对「是否进入 POC」签字（人工步骤）

**进入 POC 的推荐门槛**（本轮仅记录，不执行）：

- P1 安装包改动（ZE 装机、SI 移除等）已在目标环境 **安装+卸载 smoke 通过**
- 矩阵中至少有 **1 个候选** 在 D1–D5 无「高风险」项，或高风险均有明确缓解方案
- 待决项 [06](06-open-questions-and-decisions.md) 中 **阻塞项 ≤ 2** 且已有责任人

---

## 7. 与 pi-installer 其他文档的关系

| 文档 | 关系 |
|------|------|
| `docs/task-process.md` | P1 migration 进度；预研不阻塞 P1，但 POC 门槛依赖 P1 稳定 |
| `docs/current-state/*` | 历史盘点；以本文 **copy 基线** 为准，冲突时以 02 为准 |
| `docs/replace-installanywhere/01-candidate-tools.md` | 候选名称登记；矩阵在 04 展开 |
