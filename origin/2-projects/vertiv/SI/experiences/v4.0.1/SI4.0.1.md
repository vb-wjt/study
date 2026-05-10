<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

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
2. 优化方案 - 新索引
    1. 见 postgresql.xmind 中的 索引优化 部分



### RDU模拟器
1. 用途
    1. 自身使用 Netty 模拟为服务器，在收到实时信号请求后，返回模拟的实时信号值给客户端
2. 实现

### 备份恢复

todo
[5/11] 补充设计文档