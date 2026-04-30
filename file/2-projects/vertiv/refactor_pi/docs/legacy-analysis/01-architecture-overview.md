# Vertiv Power Insight (PI) — 数据中心监控系统源码分析

> 来源：基于 `D:\cursor_workspace\pi_origin` 全量代码（mtp-core 内含 .json，其余目录按规则忽略 .json）的总结。
> 用途：作为重构工作的基线参考，记录当前 PI 系统的架构与代码组织方式。

---

## 1. 项目总览

这是 **Vertiv（艾默生网络能源）** 的数据中心监控产品 **Power Insight（PI）**，本地部署运行。它构建在通用的 **TAF（Trellis Application Framework）/ MTP** 平台之上，采用「**核心运行时 + 元数据驱动插件 + Angular 前端壳 + 库式微前端**」架构：

- **后端核心**：`mtp-core` —— Spring Boot 2.6.15（Java 8）+ MongoDB + Hazelcast 集群（基于 com.avocent.mtp.core 命名空间，由 Vertiv/Avocent 维护，版本 `1.31.11-pi`）
- **后端业务**：约 25 个 `taf-plugin-*` 服务插件 + 14 个 `taf-data-*` 设备型号数据包，由 mtp-core 在运行时按 JSON Schema 装配
- **前端核心**：`meta-ui` —— Angular 14 单页应用，hash 路由 + APP_INITIALIZER + ngx-translate 中英双语
- **前端业务**：约 18 个 `taf-*` Angular 库通过 ng-packagr 打包，被 meta-ui **懒加载**为微前端模块
- **辅助服务**：vCenter 插件（Spring Boot + PostgreSQL）、Trellis Automation Agent（远程 OS 命令执行）、InstallAnywhere 安装器、SVG 图标库等

整套系统通过 HTTPS 8443 + WebSocket `/ws` 提供 UI 与设备数据访问能力，所有 REST API 统一在 `/api/rest/v1/**` 之下。

---

## 2. 总体架构

```
                               ┌──────────────────────────────────────────┐
                               │         浏览器 (Angular 14, hash)        │
                               │   meta-ui  +  taf-* lib (lazy modules)   │
                               └──────────────┬───────────────────────────┘
                                              │ HTTPS 8443
                                              │ /api/rest/v1/**   /ws
                                              ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│  mtp-core / webapp  (Spring Boot 2.6.15, Java 8, war: mtp-core.war)               │
│                                                                                   │
│  ┌──────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ Filters  │->│  REST 层     │->│  通用域服务 │->│  Schema 引擎 │->│  Mongo 层 │  │
│  │CORS/CGA/ │  │GenericModel  │  │DomainService│  │ JSON Schema  │  │ JsonNode  │  │
│  │ApiKey/   │  │ Controller   │  │  + Factory  │  │  v4 + 自定义 │  │ MongoTpl  │  │
│  │SystemAct.│  │ + 命名控制器 │  │  Async/Mem  │  │  关键字       │  │ 动态集合  │  │
│  └──────────┘  └──────────────┘  └────────────┘  └──────────────┘  └───────────┘  │
│                                                                                   │
│  ┌──────────────────────────────────────────────────────────────────────────────┐ │
│  │  Plugin 引擎 (PluginLoader / PluginContext / PluginOperationManager)         │ │
│  │  ─ 加载 taf-plugin-*.jar，独立 Spring Context + ClassLoader                  │ │
│  │  ─ 生命周期 OnPluginInit / OnPluginStart / OnPluginStop                      │ │
│  │  ─ 合并 schema、注册 REST、注册 handlers/actions                              │ │
│  └──────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌─── 集群 / 异步 ─────────────────────────────────────────────────────────────┐  │
│  │  Hazelcast 3.12: 会话复制、ITopic、IQueue、分布式锁、Quartz 主从、JobMgr    │  │
│  │  WebSocket Handler: 浏览器订阅 ITopic（实时设备/告警推送）                   │  │
│  │  TaskQueue / BlockQueueWorker / ThreadPool                                   │  │
│  └──────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌─── 横向能力 ─────────────────────────────────────────────────────────────────┐ │
│  │  Security (CGA Roles/Perms, BCrypt, EncryptDecrypt, Captcha, ApiKey HMAC)   │ │
│  │  Upgrader / DataUpgraderX_Y_Z (启动期数据迁移) + module.upgrade(运行期升级)  │ │
│  │  Notification / EventLog / Licensing / TrustManager / I18n / FileMgr / SMS  │ │
│  └──────────────────────────────────────────────────────────────────────────────┘ │
└──────┬────────────────────────────────────────┬───────────────────────────────────┘
       │ Mongo (mtp 库, 27017)                  │ Plugin classloaders 装配
       ▼                                        ▼
   ┌──────────┐                  ┌─────────────────────────────────────┐
   │ MongoDB  │                  │  taf-plugin-* JAR  (告警/监控/采集) │
   │  mtp     │                  │  taf-data-*   JAR  (UPS/PDU 型号)   │
   └──────────┘                  └─────────────────────────────────────┘

  外围进程 (本地或远端):
  ─ trellis-automation-agent (Spring Boot fat jar, REST 远程执行 shutdown/restart 等)
  ─ pi-vcenter-plugin (独立 Spring Boot + PostgreSQL + Angular UI, 通过 OVA/Docker 部署到 vSphere)
```

---

## 3. 后端详解

### 3.1 mtp-core —— 平台基座

**定位**：一个 **Schema 驱动、多租户、可插件化** 的数据平台。所有"模型/资源"由 JSON Schema 定义；通用 REST 控制器把任意路径的 CRUD/查询/动作映射到 MongoDB 文档；插件通过 schema 扩展 + Java handler 注入业务能力。

| 子系统 | 关键类 / 包 | 职责 |
|---|---|---|
| 应用入口 | `com.avocent.mtp.core.Application` | Spring Boot 启动；默认排除 Hazelcast 自动配置；`Initializer` + `ApplicationInit` 控制启动顺序；TLS 系统属性硬化 |
| 通用 REST | `generic.rest.GenericModelController`、`GenericRootController` | 任意 model path 的 CRUD/聚合/distinct/批量/动作；HATEOAS 风格根目录 |
| 通用域服务 | api `generic.service.DomainService` + webapp `BasicDomainService`、`DomainServiceFactory` | 按 schema path 取得绑定服务，承担过滤、租户、动作执行 |
| 持久化 | `generic.data.repository.support.mongo.MongoDataAccessor`、`CustomMongoTemplate` | 直接对 `JsonNode` 文档读写，集合名由 schema 决定 |
| Schema 引擎 | `schema.SchemaManager`、`metadatadefinition.*` | JSON Schema Draft v4 + `read-only`/`merge`/`encryptable` 等自定义关键字，缓存于 Hazelcast IMap |
| 插件引擎 | `module.plugin.support.loader.PluginLoader`、`PluginContextCache`、`PluginOperationManager` | 隔离 ClassLoader / Spring Context；按 `OnPluginInit → Start → Stop` 顺序驱动 |
| 升级器 | `upgrader.LoadAndUpgradeProcessor`、`upgradehandler.DataUpgrader1_7_0/1_12_0` + `autoload/loadAndUpgradeConfiguration.json` | 启动时按 semver 链路执行 schema 替换 + 数据迁移 |
| 运行期产品升级 | `module.upgrade.*`、`util.RestartTafService` | 上传 ZIP 升级包、校验、链式应用、必要时重启 |
| 集群 | `util.HazelcastUtils`、`servlet.filter.HazelcastFilter/HazelcastWebFilter`、map `clustered-http-sessions` | HTTP 会话复制、ITopic/IQueue/分布式锁、K8s 发现支持 |
| 调度/作业 | `module.scheduler.SchedulerManager`（Quartz + Hazelcast 主锁）、`module.job.JobManager`、`DistributedJobExecutor`、`SmartMemberSelector` | 跨节点任务派发与故障转移 |
| 任务队列 | api `taskqueue.AbstractTaskQueueService` + `taskqueue.queue.BlockQueueTaskServiceImpl` + worker | 插件订阅推送 |
| 实时通道 | `websocket.handler.TafWebSocketHandler`、`config.WebSocketConfig` | 浏览器以 JSON 命令信封订阅 Hazelcast ITopic |
| 安全 | `security.WebSecurityConfig`、`security.authorization.*`（CGA = Coarse Grained Authorization：`Role`/`Permission`/`CgaFilter`）、`InternalAuthenticationProvider`、`ApiKeyAuthFilter`、`CertFilter`、`security.crypto.EncryptDecryptService`、`SystemActivationFilter`、`CaptchaUtil` | 多重认证（Session/HTTP Basic/API Key HMAC/x509）+ 角色权限 + 密码策略（Passay）+ `{cipher}` 加密 + 系统激活流程 |
| 通知/事件 | api `notification.NotificationService`、api `module.eventlog.services.EventLogService` | 邮件/SMS 通知；事件日志写入 |
| 许可 | `module.licensing.*` + api `licensing.*` | 产品激活、特性使能、与 `SystemActivationFilter` 联动 |
| 信任管理 | api `trustmanager.service.ReloadableTrustManagerFactory` + webapp 分布式重载任务 | 运行时热更新信任库 |
| i18n | api `i18n.TafI18n`、`messages*.properties`（en + zh + pseudo） | 中英双语 + Hazelcast 本地化字符串缓存 |

**REST 入口（统一 base `/api/rest/v1`，actuator base `/manage`）**：

- `GenericModelController` —— `/{modelPath}` 全量 CRUD/动作/聚合
- `/plugins`、`/applications`、`/registry`、`/import`、`/features/{model}`、`/passwords`（找回密码）、证书 `/certs`、文件 `/files`、产品升级路径
- `/api/rest/v1/portal/**` —— **API Key + HMAC（sign + timestamp）**，无状态会话（用于第三方门户接入）
- `/api/rest/v1/ie/iedatapoints`、`/ieevents` —— **x509 客户端证书认证**，用于 Vertiv Intelligent Engine 大批量数据写入
- `/manage/logs`、`/manage/health` 等 actuator 端点（仅 `trellis.administrator` 角色）

**配置/运行**：

- 默认 profile `prod`，端口 `8443`（TLS，TLSv1.2/1.3，`server.ssl.client-auth: want`），HTTP `8080`（dev）
- MongoDB：库 `mtp`，默认 `localhost:27017`，连接池 5/100，密码以 `{cipher}` 形式加密
- Spring profile：`prod` / `dev` / `cluster`（集群名 `mtp-cluster`，端口 5701）
- Docker：`Ubuntu 16.04 + Zulu JDK 8`，启动 `runimage.sh → java -Xmx512m -jar mtp-core.war`
- 外置覆盖：`loader.path=./config`，外部 `application.properties`
- `autoload/latest/schemas/*.json`（数百个）—— 平台自带的 schema：用户、角色、会话、主题、队列、许可、SMS、系统配置等

### 3.2 业务插件（按领域分组）

**告警与事件**
- `taf-plugin-alarm` —— 告警生成、规则、动作、`alarms/topic` 推送（`AlarmService`、`AlarmActionService`、`AlarmNotificationService`）
- `taf-plugin-eventalarmdefinitions` —— 事件严重级别、告警类型的 GDD 定义
- `taf-plugin-asset-status` —— 资产生命周期状态联动告警

**监控、采集与时序**
- `taf-plugin-monitoring` —— 监控核心 schema/服务（Quartz 调度）
- `taf-plugin-datapoint` —— 数据点存储与缓存（Hazelcast）
- `taf-plugin-datapointdefinitions` —— GDD 数据点定义
- `taf-plugin-snmp` —— SNMP 数据点采集（snmp4j）
- `taf-plugin-tsd` —— 时序数据 TSD 支持
- `taf-plugin-ieadapter` —— 接入 Vertiv Intelligent Engine 监控后端

**发现**
- `taf-plugin-discovery` —— 发现请求编排
- `taf-plugin-discovery-detection` —— 网络资产探测（commons-net、java-ipv6）

**设备拓扑/库存**
- `taf-plugin-device` —— 设备域服务、设备数据点
- `taf-plugin-connections` —— 设备间连接管理
- `taf-plugin-commonmodel` —— 跨插件共享模型（容器、资产、镜像等，taf-model-codegen 生成）
- `taf-plugin-template` —— 模板引擎（FreeMarker），驱动 DomainService 上的动作
- `taf-plugin-producttemplate` —— 产品模板目录，新设备从模板供给

**主数据/词典**
- `taf-plugin-datadictionary` —— 系统类目、编程名称、基础元数据
- `taf-gdd-categories` —— GDD 类别定义
- `taf-gdd-data` —— 完整 GDD/TGDD 资源汇总（带版本管理转换工具链）

**Power Insight 产品层**
- `taf-application-power-insight-ng` —— PI 业务"应用层"（产品包装层）
- `taf-plugin-pi-acm` —— PI 的 ACM 集成
- `taf-plugin-pi-portal` —— PI 门户 API（Apache POI 报表）
- `taf-plugin-portalprovider` —— 通用门户提供者集成（HTTP 客户端密集）

**虚拟化/VMware**
- `taf-plugin-vmware` —— VMware VI API 集成（yavijava）
- `pi-vcenter-plugin` —— **独立服务**：vSphere/vCenter 插件，Spring Boot + Gradle + PostgreSQL + Angular UI，OVA/Docker 部署，含 `VsphereRegistrationService`、`VimConnectionService`、`MetricsService`、告警桥接、VxRail 服务

**通知/导出/外联**
- `taf-plugin-exports` —— 报表导出（CSV/Excel/PDF）
- `taf-plugin-sms-modem` —— 串口短信猫（jSerialComm/jSSC）
- `taf-plugin-trellisagent` —— 调用 Trellis Agent 远端执行
- `trellis-automation-agent` —— **独立 Spring Boot fat-jar**：装在被监控/被管 OS 上，提供 REST `/api/commands/*`（shutdown/restart/telnet/自定义），HTTPS + Basic Auth，可通过属性文件按操作系统注册新命令
- `trellis-automation-agent-installer` —— InstallAnywhere 打包 Agent

**备份/恢复/升级**
- `taf-plugin-backuprecovery` —— 备份/恢复工作流（与 PostgreSQL 协作）

**许可**
- `taf-data-licensing` —— 许可配置数据包

**设备型号数据包（`taf-data-*`，主要是 Java 极少 + 资源）**
- 不间断电源/PDU 型号数据：APM、APS、EXM、EXS、GXE、GXT3 / GXT4 / GXT5 / GXTMT、ITA、PSI、Geist PDU、generic-server —— 每个就是一组产品模板 + 元数据，由 `PluginConfiguration` 注册到 mtp-core 的产品模板/数据点定义体系

### 3.3 平台公共库 / 安装

- `TAF-Commons`（多模块）—— `utilities`、`api-utilities`、`appmanager`、`monitoring`、`insight`：被几乎所有插件依赖
- `taf-core-installer` —— 整个 Trellis 服务（包括 mtp-core + 嵌入式 Mongo + Zulu JRE）的 InstallAnywhere 安装器，输出 Windows/Linux 安装包
- `TAF-InstallerCustomCode` —— 安装期注入的自定义 Java 钩子代码

---

## 4. 前端详解

### 4.1 meta-ui —— Angular 14 壳应用

**核心模块**（`src/app/app.module.ts`）：`FrameModule`、`InitPageModule`、`MetaStoreModule`(NgRx)、`WebsocketServiceModule`、`CommonServicesModule.forRoot()`（均来自 `taf-utils`）+ `TranslateModule`（ngx-translate，从 `./assets/i18n/` 加载 en/zh JSON）+ `MatIconModule` + 全局 `AuthInterceptor`。

**启动序列**（`APP_INITIALIZER → initializeApp`）：
1. 注册 SVG 图标（`SvgIconService` ← `taf-svg-icon`）
2. `PublicService.pageInit()`（`taf-login`）
3. `InitPageService.initRouterNavigate()`（`taf-project-configuration-managerment`）—— 这才是真正决定"去登录 / 去初始化向导 / 去主界面"的地方
4. 设置默认语言 en，浏览器是 zh 时切到 zh，并给 body 加 `chinese-content` / `default-content` class（中英字体不同：思源黑体 / Roboto）

**响应式 REM**：`AppComponent` 监听 `window:resize`，按 `(window.innerWidth - 308) / (1920-308)` 比例动态设置 `<html>` 的 `font-size`（设计稿宽 1920、根字号 10px、保证 ≥1600×900 可用、最佳 1920×1080+）。

**hash 路由树**（`useHash: true`，进入需 `AuthGuard`）：

```
/                                  → InitPageComponent (壳)
├─ taf-monitor/
│  ├─ home-page                    → 首页仪表盘
│  ├─ device                       → UPS/PDU 设备列表与详情
│  └─ server                       → 服务器监控
├─ taf-alarm/
│  ├─ taf-active-alarm             → 实时告警
│  ├─ taf-alarm-history            → 历史告警
│  ├─ taf-notification-settings    → 告警通知策略
│  └─ taf-automation-settings      → 告警联动自动化（向导：选告警→选动作→确认）
├─ taf-electricity-management/
│  ├─ taf-energy-and-cost-statistics
│  └─ taf-electricity-cost-calculation (电费计费方案)
├─ taf-system-config/
│  ├─ taf-event-log
│  ├─ taf-notification-config      → 通讯录 / 邮件服务器 / SMS 猫 / 通知语言
│  ├─ taf-security-config
│  ├─ taf-integrated-management
│  ├─ taf-user-management
│  └─ taf-backup-and-upgrade       → 备份 / 恢复 / 升级 三个 tab
└─ profile                         → 用户个人资料
/initialize                        → 首次部署初始化向导 (taf-login)
/login, /error                     → (taf-login)
/restoring, /upgrading             → 全屏操作页 (taf-backup-restore-and-upgrade · OperateModule)
```

**AuthGuard**：等 store 里非空的权限串就绪 → 检查 `localStorage.isLogin` → 把目标 URL 与按权限过滤后的菜单做匹配 → `/` 时跳到第一个有权限的路由。

### 4.2 业务 Angular 库（懒加载，ng-packagr 打包）

| 库 | 用途 |
|---|---|
| `taf-monitor` | 监控中心：首页仪表盘、UPS / PDU 设备的列表/详情/新增、服务器监控 |
| `taf-alarm` | 实时告警表、历史告警、备注与告警详情等共享组件 |
| `taf-automation-settings` | 告警联动自动化规则的列表 + 三步配置向导 |
| `taf-notification-settings` | 通知策略（按告警维度）：列表 + 规则页 |
| `taf-notification-config` | 通讯录、邮件服务器、SMS 调制解调器、通知语言（默认重定向 address-book） |
| `taf-event-log` | 系统事件日志浏览（单页） |
| `taf-energy-and-cost-statistics` | 能耗与费用统计 + 钻取详情 |
| `taf-electricity-cost-calculation` | 电费计费方案的列表与配置 |
| `taf-backup-restore-and-upgrade` | 系统备份/恢复/升级三 tab + 全屏 `OperateModule` |
| `taf-security-config` | 安全配置（密码策略、会话策略等） |
| `taf-integrated-management` | 综合管理设置 |
| `taf-user-management` | 用户管理后台 + `ProfileModule`（个人资料） |
| `taf-login` | 首次初始化、登录、错误页、`PublicService`（登录态/页面生命周期） |
| `taf-project-configuration-managerment` | 整个壳骨架：`InitPageComponent`（外框） + `InitPageService`（启动、权限、菜单、引导） |

### 4.3 横向库

- **`taf-utils`** —— 平台基建总集
  - `FrameModule`/`FrameService`：菜单、搜索框、面包屑、布局
  - `WebsocketModule`/`WebsocketService`：基于 RxJS `webSocket` 的客户端，自动重连 + 主题订阅
  - `RouteConfigModule` + 常量 `ROUTE_CONFIG`：菜单树 / i18n 键 / 权限键的统一来源
  - `MetaStoreModule`：NgRx 根 store（认证态、权限、告警计数等）
  - `CommonServicesModule`：`RouteService`、`TimeService`、`PermissionService`、`ScreenService`、`ExportService`、各种校验器
  - `init-page` HTTP 服务：直接打 `/api/rest/v1/...` 完成会话/权限初始化
- **`taf-lumos`** —— 通用 UI 组件库（Angular Material + CDK + ECharts + dayjs + ngx-markdown）；meta-ui 的全局 `styles.scss` 也来自这里；分 `common-com` 与 `composite-com` 两套 API
- **`taf-shared-widgets`** —— 可视化组件库：bar/line/pie/gauge/table/text/image/status/single-value 等 widget + 可视化编辑器/预览/配置面板（用于自定义看板/报表）
- **`quietus`（taf-svg-icon）** —— 前端 SVG 图标库
- **`taf-utils`（前端版）** —— 同名前端工具库（与后端没关系）

### 4.4 通信约定

- API 全部走 **相对路径** `/api/rest/v1/**`（`environment.ts` 不带主机）
- `ng serve` 用 `proxy.conf.json` 代理到后端 8443
- WebSocket 默认 `wss://{hostname}:{port}/ws`
- `AuthInterceptor`：捕获 401 → 清 `localStorage`、关闭 WS、写 `updateLoginStateData` → 跳 `/login`

---

## 5. 关键技术栈速查

| 层 | 技术 |
|---|---|
| 后端语言/运行时 | Java 8（Zulu JDK），Spring Boot 2.6.15 |
| Web | Spring MVC + Undertow,server 端口 HTTPS 8443 / HTTP 8080 |
| 持久化 | MongoDB（库 `mtp`），Mongo Java Driver 4.4.2 |
| 集群/缓存 | Hazelcast 3.12.13（K8s discovery 可选），HTTP Session 复制 |
| 调度 | Quartz 2.3.2（Hazelcast 主锁协调） |
| 校验/脚本 | json-schema-validator、Rhino、Groovy、BeanShell、Janino、FreeMarker |
| 安全 | Spring Security + 自研 CGA + Passay 密码策略 + PKCS#12 签名 + `{cipher}` 字段加密 + Captcha + API Key HMAC + x509 客户端证书 |
| 监控 | Dropwizard Metrics + metrics-spring + Spring Actuator (`/manage`) |
| SNMP / Modem / 串口 | snmp4j、jSerialComm/jSSC、commons-net、java-ipv6 |
| 报表 | Apache POI、CSV、PDF 工具链 |
| 前端 | Angular **14.2**、TypeScript 4.7、RxJS 7.5、NgRx 14、ngx-translate 14、Angular Material/CDK 14、ECharts、lodash、zone.js、ng-packagr（库打包） |
| 国际化 | 中英双语，前端 `assets/i18n/{en,zh}.json`，后端 `messages*.properties` |
| 部署/打包 | InstallAnywhere（`taf-core-installer`、`trellis-automation-agent-installer`）；Docker（mtp-core、pi-vcenter-plugin）；OVA（pi-vcenter-plugin） |
| 子系统/独立服务 | `pi-vcenter-plugin`（Spring Boot + Gradle + PostgreSQL）、`trellis-automation-agent`（Spring Boot fat-jar） |

---

## 6. 本地部署运行链路（按官方 Readme 还原）

1. **前置**：本地 MongoDB 实例（端口 27017，库 `mtp`，用户 `mtpuser`），证书 `certs/keystore.p12` + `core-trust.jks`
2. **构建**：`mvn clean install`（mtp-core），各 `taf-plugin-*` / `taf-data-*` 也要安装到本地仓库或 artifactory
3. **运行**：`java -jar target/mtp-core-1.31.11-pi.war`，默认 profile `prod`，监听 `8443`
4. **插件加载**：`mtp-core` 启动时扫描插件目录，独立 ClassLoader 加载，按 `OnPluginInit → OnPluginStart` 完成 schema 合并、REST 注册、handler 注册
5. **升级链**：首次/小版本启动时按 `autoload/loadAndUpgradeConfiguration.json` 顺序执行 `DataUpgrader1_7_0` → `DataUpgrader1_12_0` → ... 把 Mongo 数据迁移到当前版本
6. **前端**：`meta-ui` 由 `mvn` 调用 `ng build`，产物以静态资源（`webapp/src/main/resources/static`）随 war 一起对外服务
7. **远程 OS 操作**：在被管服务器上单独运行 `trellis-automation-agent` jar（HTTPS + Basic Auth），由 `taf-plugin-trellisagent` 调用
8. **可选**：`pi-vcenter-plugin` 独立部署到 vSphere 集群（OVA 或 docker-compose），后端独立 PostgreSQL，注册为 vCenter 扩展
9. **InstallAnywhere**：以上步骤可由 `taf-core-installer` 一站式打包成 Windows/Linux 安装器，内置 Zulu JRE + 嵌入式 MongoDB

---

## 7. 推荐切入阅读的文件清单

**后端 mtp-core**
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\Application.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\config\WebSecurityConfig.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\config\PublicAPIRegistry.java`
- `mtp-core\api\src\main\java\com\avocent\mtp\core\generic\service\DomainService.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\generic\rest\GenericModelController.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\schema\SchemaManager.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\module\plugin\support\PluginOperationManager.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\module\plugin\support\loader\PluginLoader.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\upgrader\LoadAndUpgradeProcessor.java`
- `mtp-core\webapp\src\main\resources\autoload\loadAndUpgradeConfiguration.json`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\websocket\handler\TafWebSocketHandler.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\module\scheduler\SchedulerManager.java`
- `mtp-core\webapp\src\main\java\com\avocent\mtp\core\servlet\filter\SystemActivationFilter.java`
- `mtp-core\webapp\src\main\resources\application.properties`

**前端 meta-ui + 库**
- `meta-ui\src\app\app-routing.module.ts`
- `meta-ui\src\app\app.module.ts`
- `meta-ui\src\app\guards\auth.guard.ts`
- `meta-ui\src\app\interceptor\auth.interceptor.ts`
- `taf-utils\src\app\public-api.ts`（基建 barrel）
- `taf-utils\src\app\modules\route-config\route-config.constant.ts`（菜单 + 权限源头）
- `taf-project-configuration-managerment\src\app\modules\init-page\service\init-page.service.ts`（启动决策）
- `taf-login\src\app\modules\common\public.service.ts`（登录态）
- `taf-monitor\src\app\taf-monitor-home\monitor-home\monitor-home.component.ts`（典型业务页）

---

## 一句话总结

`pi_origin` 是 **Vertiv Power Insight** 的完整源码：以 **mtp-core（Spring Boot + MongoDB + Hazelcast 的 schema-driven 插件平台）** 为底座，通过约 25 个 `taf-plugin-*` 服务插件 + 14 个 `taf-data-*` 设备型号数据包构成完整的数据中心 UPS/PDU/服务器监控、告警、能效、电费、报表、备份升级业务能力，前端用 **Angular 14 的 `meta-ui` 壳 + 18 个 `taf-*` 懒加载库** 形成微前端式 UI，并通过 **trellis-automation-agent** 与 **pi-vcenter-plugin** 扩展到被管 OS 与 VMware vSphere，整体由 InstallAnywhere 打包为本地 Windows/Linux 安装器。
