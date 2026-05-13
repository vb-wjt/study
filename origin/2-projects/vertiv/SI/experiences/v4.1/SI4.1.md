<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

## 背景
1. 第三方厂商
2. 底层技术版本过低所导致的安全问题

## 架构组成
```text
- 前端: Angular + Lumos(私有组件库)
- 后端:
    - SI: Taf + SpringBoot + SpringSecurity + Hazelcast(分布式缓存)
    - ZE: SpringBoot + Mybatis-Plus + Undertow(服务器) + Caffeine(本地缓存) + ActiveMQ
- 数据库: ferretDB(Docker) + (documentDB + Postgresql)(Docker) + mysql
```

todo


## 负责的内容
### 解析 MIB
1. 技术选型
2. 实现



### 依赖升级
1. Java8 -> Java21
2. SpringBoot 2.7.8 -> SpringBoot 3.5.5
3. hazelcast 3.12.13 -> hazelcast 5.5.0


### SCID-Fath(TanLock 智能锁接入)

> 详细文档见 [`SCID/`](./SCID/)
> - `SCID-DDD.md` — Detailed Design Document(2026.1.23): 授权流程 UML、接口设计、数据模型、TanLock 型号识别
> - `SCID-RDD.md` — Requirement Discussion Document: 需求比对、会议决策、UI 交互方案、批量操作设计

#### 1. 业务背景
- SI4.1 接入 SCID(Smart Cabinet ID Product),需支持德国 Fath 厂商的两款智能锁: **VRA7002** 和 **VRA7003**
- VRA7002: 支持**卡片 + 指纹**(最多 2 个)认证解锁
- VRA7003: 支持**卡片**或**卡片 + PIN 码**认证解锁(PIN 为 4-6 位,每位取值 1-4)
- 两款锁的 deviceTypeId 均为 7020,通过 SNMP 实时信号 OID `1.3.6.1.4.1.13400.3.7.7020.1.1.7` 区分具体型号

#### 2. 端到端流程
需求梳理 → 需求确定/评审 → UI 交互设计 → UI 交互组内评审 → UI 交互正式评审 → 后端详细设计评审 → 评估工作量 && 指定计划 → 开发调试 → 联调 → 转测 → 修复 bug

#### 3. 核心技术决策(会议决策 2026/1/14 + 1/19)

| 决策项 | 结论 |
|---|---|
| PIN 输入 | 复用现有 Password 字段,新增提示信息由用户确保值正确,不新增 PIN 字段 |
| 卡号范围 | TanLock 要求 [1, 4294967293],SI 现有限制为 10 位 → 页面添加提示,不强制限制 |
| VRA7003 切换解锁方式 | **方案三**(新增"Door Method"列):表单新增下拉框,值为 [Card, Card+PIN] |
| 批量授权 | VRA7002 只支持批量授权卡号(不支持批量指纹);VRA7003 只支持批量授权卡号(不支持 Card+PIN) |
| 卡别名/下载日志/清除授权 | 不实现(功能已在 RDU SCID WebUI 提供,SI 不重复) |
| 过期时间 | 硬件支持但 RDU 不支持,SI 不处理 |

#### 4. 接口改动摘要(8 个接口)
- `binddoor` — 新增 TanLock 授权逻辑 + `doorMethod` 入参
- `unbinddoor` — 新增 TanLock 取消授权逻辑
- `getdoors` — 响应新增 `doorMethod`(字符串数组)
- `getsitetree` — 设置 `originalType` 为 VRA7002/VRA7003
- `updatecard` / `cancelcardauth` — 响应新增 `results` 数组,返回每个锁成功/失败明细
- `doorcardprivileges` — 表结构新增 `doorMethod` + `userIdFromDevice`
- 实时信号回写 — 首次获取 DoorLockType 信号后写入 `originalSubType`

#### 5. 跨团队协作
- 推动国外团队采购 Fath 锁硬件
- 与 RDU 团队联调:协商通过 SNMP 实时信号(而非修改 deviceTypeId)区分 VRA7002/VRA7003
- 硬件搭建:将 Fath 锁接入 SCID(RDU 类型设备)
- 阅读 RDU 设计文档和 SCID 需求文档,梳理 SI 需实现的功能边界
- 独立分支开发:基于 SI_4.1.0 拉取 SI_4.1.0_Sustaining,与其他项目组无代码或功能依赖

#### 6. VRA7002 指纹授权特殊流程
与现有 SI 指纹录入不同:VRA7002 需要**两个人现场配合**,一人在 SI 界面发起授权请求,另一人在设备端物理触摸传感器录入指纹(过程约 35 秒)。不支持从应用层下发指纹数据到设备。
