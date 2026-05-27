# task-process — 安装器任务进度

**最后更新**：2026-05-27  
**源码根目录**：`D:\cursor_workspace\cursor_out\copy`（升级后）；`pi_origin` 为旧基线

---

## 已完成

- [x] 建立 `pi-installer` 工作空间与文档骨架
- [x] 确认安装器源码路径（`taf-core-installer`、`trellis-automation-agent-installer`、`TAF-InstallerCustomCode`）
- [x] 初版盘点 IE 在安装器中的触点（`pom.xml`、`TAFCore.iap_xml`、`IETemp/`）
- [x] 对照 `cursor_out/copy` 校正文档（JRE 21、customcode 1.12.4、`ieinstaller` module/modwin、IE 端口 4440、Agent customcode JAR 名等）

---

## 进行中 — migration-tasks（安装包改动）

### P0 现状摸清

- [ ] 完整梳理 `TAFCore.iap_xml` 中所有 IE 相关 Action / Panel / 变量
- [ ] 确认 `ieinstaller` zip 解压后的目录结构与安装后文件布局
- [ ] 确认 Agent 安装器是否含 IE 依赖（初步：无直接 `ieinstaller` 依赖）

### P1 移除 IE

- [ ] `pom.xml` 移除 `ieinstaller` 依赖与 unpack 配置
- [ ] `TAFCore.iap_xml` 删除 IE 端口检查、解包、安装动作
- [ ] 删除或归档 `installables/Unix/IETemp/`
- [ ] 装机 / 升级 / 卸载回归（见 `current-state/06-...`）

### P1 打入 ZE

- [x] 初步分析 PI ZE 打包工程 `D:\idea_workspace\zero-engine-pi-installer`，确认 Linux tar.gz、`/opt/zeroengine`、`zesvc`、JRE21、SQLite、端口 8088 等信息
- [x] 设计并持久化 Windows `ZESvc` 最小可用接入计划：`migration-tasks/04-zero-engine-windows-service-plan.md`
- [x] 收窄 `zero-engine-pi-installer`：去掉 MySQL 安装/配置/脚本，新增 `windows-package`
- [x] 初步接入 `taf-core-installer`：解包 ZE Windows payload，IA 安装 `zeroengine` 目录并注册/启动/卸载 `ZESvc`（XML/静态）
- [x] GitLab `build-4.txt` 构建成功，`zeroengine` 已编入安装介质
- [x] **修复 IA 编排**（2026-05-27）：A2 xcopy + B2 TAF CORE 服务组 + A2-U 卸载 rmdir；详见 `migration-tasks/05-ze-ia-install-fix-plan.md`
- [ ] **重装验证**（用户）：`zeroengine\`、`ZESvc`、`8088`
- [x] **Linux ZE 集成**（2026-05-27）：`unpackZeroEngineLinux` + IA 安装/卸载（`/opt/zeroengine`、`zesvc`）；详见 `migration-tasks/07-linux-ze-integration.md`
- [ ] **Linux 装机验证**（用户）：`/opt/zeroengine`、`zesvc` active、8088；卸载后 remove-all

### P1 安装后配置

- [ ] 默认 `zero.engine.service.address`（与 ZE Adapter `InstallerRegistrationHandler` 对齐）
- [ ] 评估 `TAF-InstallerCustomCode` 是否需新增/修改钩子

### P1 PI-only 收敛（移除 SI）

- [x] **执行 Tier B SI 移除**（2026-05-27）：`TAFCore.iap_xml` 删除 SI build config / bundle / 组件链，`SI_LICENSE` → `PI_LICENSE`
- [x] 删除 SI 资源与装配：`resources/si_script`、`variables/si.properties`、`TAFCorelocales_si`、`assembly/si*.xml`
- [ ] **回归验证**（用户）：`pi_license.properties` 分级生效 + PI 安装/升级/卸载 smoke

---

## 未开始 — replace-installanywhere（远期）

- [ ] 候选工具选型记录（jpackage 等已登记，不做 POC）
- [ ] 替换决策与迁移计划（待 P1 安装包改动稳定后）

---

## 参考链接

- 运行时 ZE 迁移进度：`../refactor_pi/docs/task-process.md`
- 交叉文档索引：`links/refactor-pi-crossrefs.md`
