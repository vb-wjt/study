<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

## 背景

1. SI
    - Smart InfraSight 是针对边缘计算，中小机房以及分布式机房场景的新一代数据机房基础设施融合管理方案，可满足 IT 基础设施，能源设施以及环境量的融合管理需求
    - 最适用于 银行、金融及保险，广电和娱乐，化工/石油化工（不含石油和天然气），建筑工程，数据中心/主机托管/托管，教育，政府，医疗，制造，零售和批发，电信，运输
    - [详细介绍](https://www.vertiv.cn/zh-CN/products-catalog/monitoring-control-and-management/monitoring/smart-infrasight/#/support)
    - SI4.0 之前的产品只能支持监控 RDU 类型的设备，而对于目前主流的 SNMP 设备并不支持，所以在 4.0 的版本中添加 SNMP 设备等的相关支持，推广到全球产品，随着逐渐接入、集成和新功能的开发，逐渐成为一个平台级别的产品
2. Zero engine
    - Zero engine 是作为一个采集层的服务，采集从 SNMP 设备的信号和处理告警，支持分布式部署，未来逐渐扩展多个协议(比如 Modbus 等)
    - 公司内已经有类似功能的采集层服务 Ie engine，但是该服务基于 C++ 编写，并且是否另外团队负责和维护的，SI 这边需要一个完全可控，快速维护和定制化的采集层服务
    - 作为 SI4.0 中的采集层服务

## 架构组成
1. 前端: Angular，Lumons私有组建库
2. 后端:
   - 
```text
- 前端: Angular + Lumos(私有组件库)
- 后端:
    - SI: Taf + SpringBoot + SpringSecurity + Hazelcast(分布式缓存)
    - ZE: SpringBoot 3.5.6 + Java 21 + MyBatis-Plus 3.5.5 + Undertow + Caffeine + ActiveMQ + snmp4j 3.8.2
- 数据库: SI 用 MongoDB; ZE 用 SQLite (当前版本, 原 MySQL 已在升级中替换)
```

## 背景/前置 知识

1. SNMP 协议
2. SNMP4J
3. Mongodb

## 信号和告警流

> 详见 [`zero-engine-analysis.md`](./zero-engine-analysis.md) §2-§3
> 信号采集: Device.execute() → 每个 OID 单独 GET → Caffeine 缓存 → 观察者通知 → HTTP 推送
> 告警来源: SNMP Trap (v1/v2c) + 通信丢失检测;无阈值告警
> SNMPv3: GET 完整支持 (USM + Engine ID 发现);Trap 仅 v1/v2c

## 负责的模块

### 设备发现

1. 是什么，有什么(输入和输出)， 怎么实现
2. 性能，异步，线程池？
3. 见 [discovery](discovery.md)

### 驱动管理

> 基于 ie-engine 源码分析,详见 [`zero-engine-analysis.md`](./zero-engine-analysis.md) §4

**"驱动"的组成**(不是 ZIP 包,是 4 张表的组合):
- `monitoring_mapping` — 驱动身份(name, version, protocol)
- `monitoring_definition` — 协议映射(datapoints, events, SNMP 地址, trap 规则)
- `monitoring_specification` — 采集规格(哪些数据点/事件需要采集)
- `product_template` — 产品元数据

**CRUD 行为**(与之前文档描述不同,以下基于代码):
1. **查**: `GET /devicedrivers` 从 `DeviceDriverContext` 内存缓存读取
2. **增/全量更新**: `POST /tafprovider/pushdriver` — 压缩包解析和加密在上游 Center/TAF 端完成,ie-engine 接收结构化 JSON
3. **删**: `DELETE /tafprovider/devicedrivers` — **有设备引用时直接拒绝删除**(返回 usedDriverDevices 列表);批量删除时每个驱动独立事务,单个失败不影响其他
4. **部分更新**: `POST /tafprovider/updatedriver` — 仅更新 definition 和 specification,**直接修改缓存**,设备立即看到新定义(无版本控制/冻结机制)
5. **校验**: `POST /tafprovider/checkdrivers` — 比较 Center 下发列表与本地缓存的差异