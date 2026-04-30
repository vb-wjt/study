# Vertiv Power Insight 3.0 业务/功能总结（核心 → 边缘）

> 来源：基于 `Power_Insight_3.0_帮助手册.pdf`（V3.0，2024-12-13 归档）与 `pi_origin` 源码的对齐分析。
> 用途：作为重构工作的需求基线，明确 PI 3.0 实际对外暴露的业务功能边界，以及每项功能在现有代码库的承载位置。

下面把用户手册定义的产品边界与 `pi_origin` 仓库实际承载该能力的代码模块对齐，按"对产品价值的核心程度"从高到低排序。**最多支持 100 台 UPS+PDU 接入**是产品级硬约束（手册第 4.3.2/4.3.6 节多次出现 `加入监控失败，监控的 UPS 和 PDU 设备数不能超过 100`）。

---

## L1 · 立身之本：UPS / PDU 电源设备监控

PI 的**唯一产品定义**：「基于网页浏览器的监控软件，专门服务于 UPS、PDU 设施设备，是查看电源状态、告警和趋势的平台」（手册 §1.1）。

| 业务能力（手册）| 代码实现位置 |
|---|---|
| **设备接入**：手动添加 / 范围搜索（IP 段扫描）；型号选择；SNMP v2c / v3（端口、超时 1-5、重试 0-3、读/写通讯字、v3 鉴权与加密算法等） | 后端 `taf-plugin-snmp`（snmp4j）+ `taf-plugin-discovery` + `taf-plugin-discovery-detection`（commons-net、java-ipv6 段扫描）+ `taf-plugin-device`；前端 `taf-monitor / device/{ups,pdu}` |
| **设备清单与卡片群**：监控主页汇总 UPS/PDU 总数、输出功率、电费汇总；UPS 卡片显示负载率，PDU 卡片显示三相电路使用率，告警角标 | `taf-monitor/home-page`（`monitor-home.component`）+ 后端 `GenericModelController` 按 schema path CRUD |
| **设备详情·关键信号 / 资产信息 / 当前告警** | `taf-plugin-monitoring`、`taf-plugin-datapointdefinitions`、`taf-plugin-commonmodel` 提供模型；UI 在 `taf-monitor/device` |
| **实时信号刷新（30s 一次）+ 8h 折线图**：UPS 输入/输出/电池/旁路/系统；PDU 整机+三相 | 后端 `taf-plugin-datapoint`（数据点缓存）+ `taf-plugin-tsd`（时序）+ Hazelcast `ITopic` 推送；前端通过 `WebsocketService`（`taf-utils`）走 `/ws` 实时订阅 |
| **远程控制下发** + **控制操作记录** | `taf-plugin-template`（FreeMarker 模板执行 schema 动作）+ mtp-core `OnExecuteAction` / `ActionExecutor`；前端在 UPS 详情"控制"Tab |
| **支持的 UPS / PDU 设备型号** | `taf-data-*` 14 个产品数据包：APM、APS、EXM、EXS、GXE、GXT3/GXT4/GXT5/GXTMT、ITA、PSI、generic-server，以及 **Geist firmware v5.0 rackPDU**（手册 §4.3.6 明确） → `taf-data-geist-pdu` |

---

## L2 · 监控的直接产出：告警管理

| 业务能力（手册 §6） | 代码实现 |
|---|---|
| **当前告警**：列表 + 时间筛选（1/7/30/自定义/全部）+ 等级筛选（紧急/重要/一般/全部）+ 单选/多选**确认**与**结束** | `taf-plugin-alarm`（`AlarmService`、`AlarmActionService`）+ `taf-plugin-eventalarmdefinitions`（告警等级/类型 GDD 定义）；UI `taf-alarm/taf-active-alarm` |
| **历史告警**：同上 + 备注编辑 | UI `taf-alarm/taf-alarm-history` |
| **告警详情四板块**：基本信息 / 通知记录 / 联动记录 / 状态变更 | 由 mtp-core `EventLogService` + 告警 schema 关联 |
| **导出告警**为 .xlsx / .csv（等级、名称、设备、源地址、开始/确认时间、确认人）+ 导出记录中心（loading + 失败提示） | `taf-plugin-exports`（Apache POI / CSV） |

---

## L3 · 与同类 NMS 最大差异点：服务器关机保护

手册 §1.2 把这一项放在产品功能表的最显著位置：「**保护服务器**，在意外情况下会提前通知服务器关机；支持**关机脚本**；**冗余关机**——所有联供 UPS 都触发时才关闭」。

| 业务能力（手册 §5、§7） | 代码实现 |
|---|---|
| **服务器接入**：手动 + 批量 Excel 模板（一次 ≤500 台、文件 ≤5 MB） | UI `taf-monitor/server`；后端走通用 `GenericModelController` + `taf-plugin-exports` |
| **被管系统类型**：Windows / Linux / HyperV / **ESXi**；前三类需装 Automation Agent（默认端口 3029），ESXi 直连 vSphere（默认 443，端口锁定） | **`trellis-automation-agent`**（独立 Spring Boot fat-jar，HTTPS + Basic Auth，REST `/api/configuration`、`/api/manage`、`/api/commands/{shutdown,restart,…}`，可按 `trellis.agent.commands.<name>.<OS>` 动态注册命令）；服务端集成由 **`taf-plugin-trellisagent`**；ESXi 走 **`taf-plugin-vmware`**（yavijava → VI API） |
| **通讯安全**：导入 Agent 信任证书到 PI；可选"忽略 SSL 验证" | mtp-core `ReloadableTrustManagerFactory`（运行时热加载） |
| **关机脚本**：上传 `.cmd/.bat/.sh`（≤5 MB），关机前由 Agent 执行；ESXi 不允许脚本 | UI 联动配置中"上传/重选/清空脚本"；Agent 端用表达式参数（`@{delay}`、`@{delay:0}`、`@{host + ' ' + port}`）执行 |
| **关机记录**：服务器详情 → 关机记录 Tab（不分页倒序表） | mtp-core `EventLogService` + 服务器 schema |
| **联动测试连接**：UI"测试连接" → 后台尝试与 Agent / ESXi 建链，10s 超时显示"通讯异常" | `taf-plugin-trellisagent` + `taf-plugin-vmware` 测连 API |

---

## L4 · 自动化响应：告警联动

| 业务能力（手册 §7） | 代码实现 |
|---|---|
| **三步向导**：选告警（按型号 / 按设备）→ 选联动动作 → 确认信息 | UI `taf-automation-settings`（路由 `detail/select-alarm → select-action → confirm`） |
| **触发条件**：出现任一已选告警 / 所有已选告警都出现；同事件 10s 内只触发一次（手册 §7.3.6 注意） | 后端 `taf-plugin-alarm` 规则引擎 |
| **动作类型**：① 下发**控制命令**（向 UPS/PDU 写设置值，True/False 等枚举）；② **服务器关机**（执行脚本） | 控制命令 → mtp-core `ActionExecutor` + `taf-plugin-template`；关机 → `taf-plugin-trellisagent` |
| **执行编排**：顺序执行（鼠标拖拽排序，间隔 0–30m59s） / 同时执行；联动延时 0m0s–30m59s | `taf-plugin-alarm` action plan |

---

## L5 · 通知机制：邮件 + 短信

| 业务能力（手册 §7 + §9.3.2） | 代码实现 |
|---|---|
| **通知设置**（按告警→选接收人→确认）；通知延时 ≤30m59s；**重复发送**（1–5 次、间隔 10–480 min）；**告警升级延时**（1–1440 min）；**结束通知**；告警 >15 天不再发结束通知 | UI `taf-notification-settings`；后端 `taf-plugin-alarm` 通知模块 + mtp-core `NotificationService` |
| **通讯录**：姓名、邮箱、手机号（含国家区号） | UI `taf-notification-config/address-book`；后端 mtp-core `module.tenant`/通讯录 schema |
| **邮件服务器配置**：SMTP 主机+端口、发件人、TLS、身份认证、测试发送 | mtp-core JavaMail（Spring Boot mail starter）；`forgot-password` 验证码也走这里 |
| **短信调制解调器**：操作系统自动识别；端口、波特率、数据位、奇偶校验、停止位、测试号码；硬性约束**仅支持 TD8411 3G 制式**（手册 §10 FAQ 7） | **`taf-plugin-sms-modem`**（jSerialComm / jSSC 串口） |
| **通知语言**：中文 / English | mtp-core `i18n.TafI18n` + `messages_zh.properties` / `messages.properties` |

---

## L6 · 经营视角：电能与电费管理

| 业务能力（手册 §8） | 代码实现 |
|---|---|
| **电能与电费统计报表**：统计内容（电能/电费）× 时间维度（按月/按天）× 时间范围（按月最长 24 个月、按天最长 90 天）× 设备勾选；柱状图钻取详情；用电量保留 3 位小数、电费保留 4 位小数 | UI `taf-energy-and-cost-statistics`（含 `detail` 钻取页）；后端聚合靠 `taf-application-power-insight-ng` + `GenericModelController` 的聚合接口 |
| **电费计算配置**：① 全年统一 / ② 区分夏冬季（默认夏 4–9 月）；基础电价 + 固定月费 + **分时电价 1–10 段**（不可重叠）；结算单位 RMB/USD/EUR/GBP；至少关联 1 台设备 | UI `taf-electricity-cost-calculation`（含 `electricity-bill-plan-config`）；后端在 `taf-application-power-insight-ng` 中实现计费方案模型 |
| **数据来源**：PDU 历史输出 + UPS 输出能耗 | `taf-plugin-datapoint` + `taf-plugin-tsd` 时序持久化 |

---

## L7 · 平台运维：系统设置

### L7.1 事件日志（仅超级管理员可见）
- 维度：用户操作 / 身份验证 / **告警通知** / **告警联动** / 其他；日期 1/3/7/30/全部/自定义
- 代码：mtp-core api `module.eventlog.services.EventLogService`；UI `taf-event-log`

### L7.2 安全配置
| 子能力（手册 §9.3.3） | 代码实现 |
|---|---|
| **信任证书**：导入 .der/.crt/.cer/.pem（≤5 MB），用于 Agent / 邮件服务器 / 集成 | mtp-core `module.certmanager` + `ReloadableTrustManagerFactory` |
| **SSL 证书**：替换 .p12/.pfx；密码校验；必须是单一 RSA-2048；替换后**自动重启**；新生成证书有效期 10 年；指纹 SHA-256 | mtp-core `CertManagerController` + `RestartTafService` |
| **会话超时**：1–60 min（默认 30），更改下次登录生效 | mtp-core `SessionController` + `application.properties` |

### L7.3 用户管理（仅超级管理员）
- 用户名、邮箱、手机号、**用户权限**（普通 / 高级 / 超级管理员）
- 权限边界（手册 §4.3.8 注）：**只有超级管理员和高级用户可修改设备资产信息、下发控制、确认/结束告警**
- **密码策略**：复杂度（最小 10–108、大小写+数字）、有效期（永远有效 / 1–9999 天，过期前 3 天提示）
- 代码：mtp-core `security.authorization`（CGA：`Role`、`Permission`、`CGAConstants` 含 `trellis.administrator` 等）+ Passay 密码校验；UI `taf-user-management`（含 `ProfileModule` 个人档案）

### L7.4 备份还原与升级
| 子能力（手册 §9.3.6） | 代码实现 |
|---|---|
| **备份**：自动获取路径（Linux `/var/opt/VertivBackup`、Windows `C:\Users\Default\AppData\Local\VertivBackup`）；硬盘空间预检；备份/还原/升级三态互斥 | `taf-plugin-backuprecovery`（依赖 PostgreSQL 工具链） |
| **还原**：快速还原（点列表项）/ 自定义还原（指定路径+超管密码）；**不支持跨 OS 恢复**（Win 备份不能在 Linux 还原） | `taf-plugin-backuprecovery` |
| **升级**：上传 ≤500 MB 升级包→校验→流程化→重启；保留升级记录（前/后版本、状态、详细日志） | mtp-core `module.upgrade.*`（链式步骤）+ `RestartTafService`；UI `taf-backup-restore-and-upgrade`（含全屏 `OperateModule` for `/restoring`、`/upgrading`） |

---

## L8 · 外围扩展：集成管理（与 vCenter 互通）

- 唯一可选接入主机类型：**VMware Plugin**（手册 §9.3.4 明确：「接入主机类型不可选择，默认为 VMware Plugin」）
- 配置后生成 **API Key + API Secret**（HMAC 签名鉴权），由 **`pi-vcenter-plugin`**（独立 Gradle Spring Boot 服务 + PostgreSQL + OVA/Docker 部署到 vSphere）调用 PI 的 `/api/rest/v1/portal/**`
- 代码：mtp-core `ApiKeyAuthFilter` / `ApiKeyAuthManager` / `ApiKeySecurityConfigurationAdapter`（HMAC + timestamp 防重放）+ UI `taf-integrated-management`

---

## L9 · 用户接入与本地化（"开门"层）

| 能力 | 代码 |
|---|---|
| **首次部署初始化向导** → 设管理员账号 → 进监控主页 | UI `taf-login/initialize` + `taf-project-configuration-managerment/InitPageService` 协调 onboarding |
| **登录 / 多用户互踢 / 同浏览器多用户提示** | UI `taf-login/login`；后端 mtp-core 会话过期 + Hazelcast 会话复制（`clustered-http-sessions`） |
| **图形验证码**：5 次错锁定 30 min；1 次错后 30 min 内需验证码 | mtp-core `CaptchaUtil` + `LoginExpiredCacheService` + `GetLoginCaptchaAction` |
| **忘记密码**：邮箱验证码（60s 间隔、10 min 有效、30 min 改密窗口） | mtp-core `PasswordRecoveryService`（`/api/rest/v1/passwords`）+ `CaptchaService` |
| **浏览器中英自适应、REM 响应式（≥1600×900）** | meta-ui `app.module`（ngx-translate）+ `app.component`（REM 缩放） |
| **404 兜底跳"返回主页"** | meta-ui `AuthGuard` + `ROUTE_CONFIG` |

---

## L10 · 安装/部署侧（产品边界以外的工程能力）

| 能力 | 代码 |
|---|---|
| **PI 主程序安装器**（Windows/Linux，含嵌入式 MongoDB + Zulu JRE，典型/自定义安装、端口冲突重选、参数：DB 端口 27017、mtpadmin、mtpuser、应用 8443） | `taf-core-installer`（InstallAnywhere）+ `TAF-InstallerCustomCode`（安装期 Java 钩子） |
| **Automation Agent 安装器**（Windows 32/64、Linux；密码 8–32 字符；导出 trellis-agent.crt） | `trellis-automation-agent-installer`（InstallAnywhere）+ `trellis-automation-agent` |
| **PI 卸载**（Windows / Linux；保留 vs 删除数据二选一） | 同安装器 |
| **平台底座**（Schema-driven、插件化、Hazelcast 集群、Quartz 调度、CGA 权限） | `mtp-core`（参见 `01-architecture-overview.md`） |

---

## 一句话归纳

**Vertiv Power Insight 3.0 = 一个 Web 化的电源设备小型监控平台**，把"**UPS/PDU 电气信号实时监控 → 告警 → 通过 Automation Agent 触发服务器优雅关机/UPS 控制 → 邮件/短信通知 → 电能电费经营报表**"这条护链做闭环，再外加日志/安全/用户/备份/升级/vCenter 集成等运维能力；上限 100 台电源设备 + 单机部署 + 嵌入式 MongoDB，定位中小机房自用，非通用 DCIM。

> 与架构分析对照：手册讲到的 100% 业务点都能在 `pi_origin` 找到对应代码模块；反之代码里 mtp-core 的"租户、licensing 高级功能、Intelligent Engine 适配 (`taf-plugin-ieadapter`)、Trellis Portal Provider、`taf-plugin-pi-acm`、`taf-plugin-pi-portal`、`taf-shared-widgets` 自定义看板"等能力**没有出现在 PI 3.0 用户手册**——它们要么是 TAF 平台底座的通用能力，要么是同代码库面向其他 Vertiv 产品（如 Trellis Application Manager）保留的扩展点，**在 PI 3.0 这个产品形态里被禁用或不暴露给最终用户**。
