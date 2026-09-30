# 替换 InstallAnywhere — 预研文档

> **最后更新**：2026-05-28  
> **阶段**：预研（无 POC、不改 `cursor_out/copy` 工程代码）  
> **基线**：`<repo-root>`（PI 3.x 安装器）  
> **范围**：全新安装、静默安装、卸载 — **不含 upgrade**，**不含 PI 4.0**

---

## 目的

评估是否以及如何用其他打包/安装技术替代 Flexera InstallAnywhere（license、维护性、离线安装、多语言 UI、CustomCode 钩子等）。

---

## 文档目录

| 文件 | 内容 |
|------|------|
| [01-candidate-tools.md](01-candidate-tools.md) | 候选工具名称登记 |
| [02-as-is-capability-inventory.md](02-as-is-capability-inventory.md) | **现状能力清单**（As-Is，copy 基线） |
| [03-research-constraints-and-criteria.md](03-research-constraints-and-criteria.md) | 预研边界、NFR、评估维度 |
| [04-candidate-fit-matrix.md](04-candidate-fit-matrix.md) | 候选方案纸面适配矩阵 |
| [05-migration-path-options.md](05-migration-path-options.md) | 替换路径选项与风险 |
| [06-open-questions-and-decisions.md](06-open-questions-and-decisions.md) | 待决问题与已确认决策 |

---

## 预研硬约束（摘要）

1. 仅文档产出，不做 POC。  
2. 不修改 `cursor_out/copy` 下源码。  
3. 不考虑 PI 4.0 目标态。  
4. 不考虑升级（upgrade）路径。

---

## 影响范围（替换实施时，非本轮）

- `taf-core-installer`
- `trellis-automation-agent-installer`
- `TAF-InstallerCustomCode`

---

## 相关

- 安装器任务进度 → **`../task-process.md`**（内部真源，不随本目录）  
- 当前状态盘点 → **`../current-state/`**（内部真源，不随本目录）  
- P1 迁移任务 → **`../migration-tasks/`**（内部真源，不随本目录）
