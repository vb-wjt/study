# InstallAnywhere 替代 — 候选工具登记

> **说明**：仅记录候选名称与一句话定位，**不进行选型分析或 POC**。  
> 深度调研在任务启动后于本目录新增独立文档。

---

## 候选列表

| 工具/方案 | 类型 | 备注 |
|------|------|------|
| **保留 InstallAnywhere** | 商业（现状） | 基线对照项，用于评估替换收益与风险 |
| **Install4j** | 商业 | Java 安装器；可评估对 CustomCode 的迁移成本 |
| **Advanced Installer** | 商业 | MSI/EXE 能力完整，适合 Windows 企业交付 |
| **WiX/MSI + Linux 脚本** | 开源 + 脚本 | Windows 标准 MSI；Linux 需并行维护 |
| **NSIS + Linux 脚本** | 开源 + 脚本 | 轻量 EXE；复杂编排依赖脚本 |
| **Inno Setup + Linux 脚本** | 开源 + 脚本 | 与 NSIS 同类，偏 Windows 安装器体验 |
| **jpackage (+脚本)** | OpenJDK 自带 | 适合单 Java 应用；PI 全量安装器匹配度待验证 |
| **Go 交叉编译安装器（自研）** | 自研方案 | 用 Go 生成跨平台安装器二进制；安装 UI/变量/卸载需自行实现或组合第三方库 |
| **纯脚本/归档** | 自研方案 | PowerShell + bash + tar/zip，最灵活但维护责任最大 |
| **Electron/Tauri/NW.js（安装 UI 壳）** | 框架（非安装器） | 非主安装器工具，通常作为自研方案 UI 层，不单独推荐主评估 |

---

## 待记录（选型阶段再填）

- 决策日期与结论
- POC 产物路径
- 对 `TAF-InstallerCustomCode` 的迁移策略
