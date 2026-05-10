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


### SCID-Fath
1. 流程: 需求梳理 -> 需求确定/评审 -> UI交互设计 -> UI交互组内评审 -> UI交互正式评审 -> 后端实现设计文档评审 -> 评估工作量 && 指定计划 -> 开发, 调试 -> 联调 -> 转测 -> 修复 bug
2. 推动国外采购
3. 跨团队合作, 联调
4. 硬件搭建, 阅读文档
5. 开发调试
6.
