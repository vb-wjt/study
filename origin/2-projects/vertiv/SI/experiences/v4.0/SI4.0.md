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
    - ZE: SpringBoot + Mybatis-Plus + Undertow(服务器) + Caffeine(本地缓存) + ActiveMQ
- 数据库: mongodb + mysql
```

## 背景/前置 知识

1. SNMP 协议
2. SNMP4J
3. Mongodb

## 信号和告警流

## 负责的模块

### 设备发现

1. 是什么，有什么(输入和输出)， 怎么实现
2. 性能，异步，线程池？
3. 见 [discovery](discovery.md)

### 驱动管理

1. 查
2. 增: 驱动压缩包，加密。。。
3. 删: 失败时，只回滚当前驱动的相关内容。。。
4. 改: 有设备的时候，需要额外处理。。。
5. 见 zero engine 源码中的相关功能实现