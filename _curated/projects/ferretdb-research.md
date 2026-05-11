# FerretDB Windows 调研 · 归档与简历版

标签:`[就绪]` `[简历亮点]`⭐⭐ `[面试高频]`🎯 `[源文]`

> 这份文档把你 `ferretdb-no-docker.md` (241 行) + `resume-snippet.md` (原 `unclassified/archived_chats.md`,2026-05-08 归位到 `ferretdb/`)
> **整合归档**,并补充我视角的提炼。
>
> 这是你**最完整、最自包含**的简历素材之一(有问题、有方案、有失败、有结论、有决策影响)。

---

## 0. 一句话总结

> 在 Windows 原生环境(无 Docker)下调研 MongoDB 的开源替代方案 FerretDB 的可行性,
> 通过深度技术验证否定了 Windows 原生路线,**直接影响了 PI 4.0 重构的技术路线决策**(放弃 FerretDB,直接迁 PG)。

---

## 1. 项目背景

### 1.1 触发因素 (为什么要做这个调研)

- **MongoDB 的 SSPL 协议**: 自 2018 起,MongoDB 改用 SSPL,2024 年进一步收紧,**已不被 OSI 认证为开源协议**
- 作为商业软件分发的 Vertiv 产品(SI / PI),继续用 MongoDB 存在合规风险
- 需要找一个**真开源**的替代方案
- 候选方案 **FerretDB**: 一个用 PostgreSQL + Microsoft DocumentDB 扩展实现的 MongoDB wire protocol 兼容层

### 1.2 任务约束

- **不使用 Docker**: 受公司 offering 政策限制,所有依赖必须直接打入安装包
- **支持 Windows 主流环境** (Win 10/11) + Linux 辅
- **保持业务零中断**: 现网客户已经用 MongoDB,切换不能停服

---

## 2. 技术方案与验证

### 2.1 FerretDB 的组成

```
┌────────────────────────────────────────────────────────────┐
│  Application (Java / SI / PI)                              │
│  通过 MongoDB Driver(标准协议)                              │
└──────────────┬─────────────────────────────────────────────┘
               │ MongoDB Wire Protocol (TCP 27017)
               ▼
┌────────────────────────────────────────────────────────────┐
│  FerretDB (Go,协议层)                                      │
│  把 MongoDB 协议命令翻译为 PostgreSQL SQL                   │
└──────────────┬─────────────────────────────────────────────┘
               │ PostgreSQL Protocol (TCP 5432)
               ▼
┌────────────────────────────────────────────────────────────┐
│  PostgreSQL + DocumentDB Extension (C 扩展,JSON 增强)      │
│  实际数据存储                                               │
└────────────────────────────────────────────────────────────┘
```

### 2.2 三个验证 Test 与结果

#### Test 1: FerretDB v2.7 + 远程 PG (无 DocumentDB) ✅ 部分成功

- 编译 FerretDB.exe (Go 源码,需 IDEA / Goland 付费工具)
- 连接公司远程 PG 数据库 `10.243.192.44`
- **结果**: 成功启动,基础接入跑通
- **意义**: **理论上可行**

#### Test 2: 编译 Microsoft DocumentDB (C 扩展) ❌ 失败

- 配置 Visual Studio 17 + CMake 工具链
- `cmake .. -G "Visual Studio 17 2022" -A x64`
- 多次失败,缺少依赖、CMake 找不到 config 等问题
- **根因深度分析**(你的报告里给出了 3 层根因):
  1. **DLL 地狱**: VS 编译的 DLL 强依赖 MSVC 运行时,**不向前兼容**;一台机器编译,另一台机器跑不起来
  2. **工具链与 SDK 割裂**: 不同 VS 版本的 C++ 编译器对标准支持不同;新版 Windows SDK 的 API 在老版跑不动
  3. **Windows 内核与 Unix POSIX 的根本差异**: Windows 7/8/10/11 内核细节有差异,涉及内存管理 / 网络栈的代码行为不一致

#### Test 3: 高版本 FerretDB(强校验 DocumentDB) ❌ 失败

- 不带 DocumentDB 扩展的 PG → FerretDB v2.7 启动后立即报错:
  ```
  错误: 模式 "documentdb_api" 不存在 (SQLSTATE 3F000)
  ```
- **结论**: 高版本 FerretDB 与 DocumentDB **强耦合**,无法解耦使用

#### Test 4: 低版本 FerretDB v1.24(不依赖 DocumentDB) ❌ 失败

- 用低版本 FerretDB,直连 PG(无扩展)
- **失败 1**: MongoDB 索引能力不全
  ```
  Index option "partialFilterExpression" is not implemented yet (code 238)
  ```
- **失败 2**: 协议消息体大小超限
  ```
  reply message length 50912595 is greater than the maximum message length 48000000
  ```
  - 原因: 插件包过大 (taf-ui-core 51MB > 48MB MongoDB 协议上限)
- **结论**: 低版本能力不全 + 官方维护投入有限,**不推荐**

---

## 3. Discussion Conclusion (你和团队 4/15 讨论的产出)

> 三个备选方案:

| Plan | 路线 | 评估 |
|---|---|---|
| **A** | 北向 + 南向都改 (mongodb 语法也改, 表换关系型) | 工作量最大但根治 |
| **B** | 北向不改, 南向改 (mongodb 语法不改, 表换关系型) | 看似省事但底层与上层不匹配,容易出 bug |
| **C** | 用 AI 工具评估和分析,**局部 / 全部推倒和重构** PI 的架构和业务代码 | 决策选择,演化为 PI 4.0 重构 |

> **最终选 Plan C**,即后续的 PI 4.0 重构。

---

## 4. 项目价值 (为什么这是简历亮点)

### 4.1 你做了**别人没做的事**

- Windows 下编译 Go + C 双语言项目(大多数 Java 后端没碰过)
- 用源码编译 + 错误根因分析的方式做技术调研(大多数后端只用现成的 Docker)
- 把"编译失败"挖到"DLL 地狱 + POSIX 差异 + 工具链碎片"的**架构级根因**

### 4.2 你**否定**了一条路 (这才是高级)

- 大多数工程师调研技术 → 给出"可以用"的结论
- **你给出了"不可用 + 完整根因 + 替代建议"的报告** → 帮团队节省了大量后续踩坑成本

### 4.3 你的结论**直接影响**重大决策

- 这次调研让团队放弃了 "FerretDB 兼容层" 路线
- 直接催生了 PI 4.0 重构 (推倒 + PG 关系型重写)
- 从 SI 局部技术调研 → 跨产品架构决策的传导链路

---

## 5. 简历版 (你已写,我整合至此)

> 你的 `resume-snippet.md`(原 `archived_chats.md`)里已经有简历版(2026.04 内容)。我做最小调整,统一标点和措辞:

```
【项目经历】开源文档数据库 FerretDB 环境搭建与可行性研究
【时间】[TODO: 起止时间]
【技术栈】Go, C/C++, PostgreSQL, CMake, Visual Studio, Docker, WSL2, Linux Kernel

【项目描述】
在 Windows 原生环境下调研 MongoDB 的开源替代方案 FerretDB,尝试在不依赖 Docker 的前提下
构建基于 PostgreSQL + Microsoft DocumentDB 扩展的数据库服务,并评估其在 Windows 原生
环境下的落地可行性。

【主要职责与产出】
- 跨平台编译实践:成功在 Windows 环境下从源码编译 FerretDB 核心程序;针对 DocumentDB
  (C++ 扩展)进行本地编译尝试,配置了 Visual Studio 与 CMake 工具链,并深入排查了依赖
  库缺失及环境变量冲突问题
- 技术难点根因分析:针对 Windows 下 C/C++ 编译失败的根因进行深度分析,对比了 Windows NT
  内核与 Unix/Darwin 的底层差异。深入研究了 POSIX 标准、DLL 依赖管理以及不同操作系统的
  编译器兼容性,明确了 Windows 原生环境在构建此类系统级组件时的局限性
- 方案验证与决策:通过连接远程 PostgreSQL 数据库,验证了 FerretDB 在 Windows 上的基础
  功能可用性。基于"DLL 地狱"及高昂的维护成本分析,输出了一份详尽的技术调研报告,否定
  了 Windows 原生编译路线,确立了采用 Linux/Docker/WSL2 作为统一开发和运行环境的技术
  路线
- 后续影响:本次调研结论直接影响 PI 产品的技术路线决策——团队放弃 FerretDB 兼容层方案,
  确立了 PI 4.0 推倒重写迁移至 PostgreSQL 关系型 schema 的方向

【成果与价值】
- 排除了不稳定的 Windows 原生部署方案,为团队规避了潜在的运行时兼容性风险与高昂的长期
  维护成本
- 推动了容器化标准化部署策略的落地
- 调研报告作为 PI 4.0 重构方案 §1.1 触发因素的关键论据
```

---

## 6. STAR 法则讲述 (面试时用)

> 你 `resume-snippet.md` 已经给出 STAR 框架,我把它**口语化**,方便你面试当场说:

### S (Situation 情境)
> "公司项目组要评估 MongoDB 的开源替代品 FerretDB,最初的需求是在 Windows 服务器上**不用 Docker** 部署。我负责搭建环境,特别是搞定 Microsoft DocumentDB 扩展(C++ 编写)在 Windows 上的编译和集成。"

### T (Task 任务)
> "在不依赖 Docker 的前提下,跑通 FerretDB + PG + DocumentDB 三件套,验证它能否成为 PI 产品的 MongoDB 替代方案。"

### A (Action 行动)
> "我先尝试源码编译,Go 部分(FerretDB 主程序)很顺利;但 C++ 部分(DocumentDB 扩展)遇到很多依赖和兼容性问题。我**没有死磕表面错误**,而是去研究**根本原因**——发现是 Windows 缺乏 POSIX 支持、DLL 没有统一管理机制、不同 VS 版本工具链碎片化导致的。最后我做了完整的测试验证,**也试过低版本 FerretDB 不依赖 DocumentDB 的方案,但发现 MongoDB 协议层的索引功能不全 + 协议消息体大小限制(48MB)等问题让它在 PI 上跑不起来**。"

### R (Result 结果)
> "我提交了一份完整的技术调研报告,**否定了 Windows 原生 + FerretDB 方案,推动 PI 4.0 改用 Docker/WSL2 标准环境 + 直接迁移到 PostgreSQL 关系型 schema 的路线**。这个结论直接成为 PI 4.0 重构方案的核心决策依据,帮团队避免了后续两条死胡同的踩坑成本。"

---

## 7. 这段经历的"软实力面" (小贴士)

> 你 `resume-snippet.md` 末尾的提醒,我完全同意:
>
> > "你证明了你不仅仅是一个'写代码的人',更是一个'**懂架构、懂取舍、能从底层原理出发解决问题**' 的工程师。这对于后端 / 运维 / DevOps 岗位是非常加分的。"

**几个面试可发挥的点**:

1. **不死磕** —— 面试官最怕"花了 3 个月还在死磕一个失败方案"的工程师。你能讲"我没死磕,我抓到根因后就推动改方向"
2. **报告思维** —— 不只是做出来,还**输出文档供团队复用**。这是 senior 工程师的标志
3. **影响决策** —— 你的调研改变了**整个产品**的技术路线,不只是你自己的代码

---

## 8. 与你 `origin/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| 调研全过程 + 截图 + 错误日志 | §1-3 | `tech-stack/database/ferretdb/ferretdb-no-docker.md` (241 行 + 6 张图) |
| 简历语言版 | §5 | `tech-stack/database/ferretdb/resume-snippet.md` (2026-05-08 已归位到 `ferretdb/`) |
| FerretDB → PI 4.0 决策传导 | §3, §4.3 | (PI 重构文档暂不记载) |
| 替代选 PG 的方案 | §3 Plan C | [`./postgresql-knowledge.md`](./postgresql-knowledge.md) |

---

> **下一步**:看 [`snmp-zero-engine.md`](./snmp-zero-engine.md) (SI 4.0 信号采集主线) 或
> [`dependency-upgrade.md`](./dependency-upgrade.md) (依赖升级方法论)
