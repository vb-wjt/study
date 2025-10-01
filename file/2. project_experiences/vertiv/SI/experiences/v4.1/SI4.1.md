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


todo