## 背景
1. SI
2. zero engine




## 架构组成
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
3. 。。。


### 驱动管理
1. 查
2. 增: 驱动压缩包，加密。。。
3. 删: 失败时，只回滚当前驱动的相关内容。。。
4. 改: 有设备的时候，需要额外处理。。。

todo