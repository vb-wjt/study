## 背景
1. mongodb
2. ferret + postgresql + documentdb
3. docker

## 架构组成
```text
- 前端: Angular + Lumos(私有组件库)
- 后端:
    - SI: Taf + SpringBoot + SpringSecurity + Hazelcast(分布式缓存)
    - ZE: SpringBoot + Mybatis-Plus + Undertow(服务器) + Caffeine(本地缓存) + ActiveMQ
- 数据库: ferretDB(Docker) + (documentDB + Postgresql)(Docker) + mysql
```


## 负责的内容
### 性能测试
1. 范围
2. 优化方案



### RDU模拟器
1. 用途
2. 实现


todo