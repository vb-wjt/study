<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

# dependency upgrade design

## audit record

| version | timestamp | author        | notes       |
|---------|-----------|---------------|-------------|
| 1.0.0   | 2025.9.11 | juntao, James | since SI4.1 |

## business background
由于安全问题和 offering 需求等, SI 和 zero engine(下面统称 ZE) 需要升级相关依赖的版本; <br>
具体升级内容如下:
- SI: Java, SpringBoot, Hazelcast
- ZE: Java, SpringBoot, 数据库由 Mysql 改为 MariaDB
- 使用到的所有依赖都需要升级到最新版本

## requirement description
### business requirement
#### user story

[US965-Upgrade Hazelcast](https://rally1.rallydev.com/#/329266204304d/backlog?detail=%2Fuserstory%2F810610613685%2Fdetails&view=3a7ee8c9-bc30-4d60-96cd-3b5238c07f16)

[US966-Upgrade SpringBoot](https://rally1.rallydev.com/#/329266204304d/backlog?detail=%2Fuserstory%2F810611168449%2Fdetails&view=3a7ee8c9-bc30-4d60-96cd-3b5238c07f16)

[US981-Upgrade java & all maven dependencies version to the latest.](https://rally1.rallydev.com/#/329266204304d/backlog?detail=%2Fuserstory%2F812229070441%2Fdetails&view=3a7ee8c9-bc30-4d60-96cd-3b5238c07f16)

[US1054-ZeroEngine - Upgrade Java8 to Java17 at least](https://rally1.rallydev.com/#/329266204304d/backlog?detail=%2Fuserstory%2F818970767335%2Fdetails&view=3a7ee8c9-bc30-4d60-96cd-3b5238c07f16)

[US1055-ZeroEngine - Change MySQL DB with MariaDB](https://rally1.rallydev.com/#/329266204304d/backlog?detail=%2Fuserstory%2F818971178459%2Fdetails&view=3a7ee8c9-bc30-4d60-96cd-3b5238c07f16)

#### figma
无

### security requirement
包含在以下详细设计模块里面: detailed design

### performance requirement
预期: 升级完之后, SI 的所有功能正常, 性能正常

## function description
预期: SI 和 ZE 涉及的依赖, 都升级到最新, 稳定, 比较安全的版本

## dependency upgrade conclusion

| 依赖         | 所属模块 | 当前版本             | 目标升级版本        | 备注 |
|------------|------|------------------|---------------|----|
| Java       | SI   | zulu-8.58.0.13   | zulu-21.44.17 |    |
| Java       | ZE   | zulu-17.0.13     | zulu-21.44.17 |    |
| SpringBoot | SI   | 2.7.18           | 3.5.6         |    |
| SpringBoot | ZE   | 3.3.5            | 3.5.6         |    |
| Hazelcast  | SI   | 3.12.13          | 5.6.0         |    |
| Mysql      | ZE   | community-8.0.39 | 改用 Sqlite 数据库 |    |

## detailed design
### Mysql(to MariaDB): US1055

| Name           | Version                              | License | Risk ? | Description    | Solution                 |
|----------------|--------------------------------------|---------|--------|----------------|--------------------------|
| Mysql server   | community-server-8.0.39-1.el9.x86_64 | GPLv2   | N      | 独立进程, 网络通信      | No-change                |
| Mysql client   | com.mysql.cj.jdbc.Driver             | GPLv2   | Y      | 嵌入代码, 衍生作品      | Change to mariadb driver |
| MariaDB client | org.mariadb.jdbc.Driver              | LGPL    | N      | 嵌入代码, 附加了允许闭源条款 |                          |

#### 现状 && 分析
1. user story 内容很简单, 为 "For MySql DB we need license. The unpayable version is MariaDB."
2. ZE 里面使用是 Mysql community, 具体是 mysql-community-X-8.0.39-1.el9.x86_64.rpm
3. Mysql Community 遵循 GPLv2 开源协议;
    1. GPLv2 有传染性的特性, 即如果软件里面使用了带 GPLv2 协议的开源库, 并且是强耦合使用, 属于"衍生作品", 软件闭源并分发到客户手里,
       则需要把软件开源; (相关知识参考 ##notes GPLv2)
    2. 结合到 ZE 现状, ZE 和 Mysql 都有自己的服务, 属于独立的两个进程, 通过 sql 协议请求数据, 在架构上属于是 "聚合体"(不违反 GPLv2协议);
    3. 但 ZE 内部使用 mysql-connector-java.jar(也是 GPLv2 协议的) 作为依赖 jar包, 来连接到 Mysql Server服务, 强耦合, 属于"衍生作品", 会违反 GPLv2 协议, 会有法律风险(需开源代码, 被起诉侵权等);
4. 这时候不想受 GPL 约束, 不想发布其专有应用程序的源代码, 则需要向 Oracle 购买 license. ([mysql license](https://www.mysql.com/about/legal/licensing/oem/))

#### MariaDB
1. 由于担心 Oracle 收购 MySQL, MySQL 的原始开发人员创建了 MariaDB 作为 MySQL 的一个分支。
2. MariaDB 旨在成为 MySQL 的直接替代品, 同时保持与 MySQL 的协议、连接器和数据文件的兼容性。
3. MySQL 迁移到 MariaDB 相对简单。MariaDB 非常适合那些优先考虑开源解决方案、需要高级性能特性且不受商业许可限制的用户
4. MariaDB: 也遵循 GPLv2 开源协议;
    1. 但 MariaDB 客户端库(用于连接等) 遵循 LGPL 许可证, 允许将 MariaDB 客户端库自由分发到任何应用程序中. ([MariaDB 使用](https://mariadb.com/docs/general-resources/community/community/faq/licensing-questions/licensing-faq))

#### 解决方案
三种方案如下: <br>
1. 更改数据库驱动类型, 由 mysql-connector-java.jar 换为 mariadb-java-client.jar, 更改后需验证功能是否正常; 是最小改动;
2. 把数据库 Mysql 完全换成 MariaDB, Mysql 的服务端也不使用了
    1. 更改后需对比两者数据库的区别(因为 MariaDB 是 Mysql 的一个分支, 区别应该不会很大), 以及验证功能是否正常;
3. 考虑到 ZE 中并不存储历史数据等大量数据, 同时 ZE 后续可能需要支持分布式, 直接把数据库 Mysql 换为 嵌入式轻量级数据库 Sqlite(使用途径没有任何限制) 或者 Postgresql
    1. 更改后需对比两者数据库的区别, 研究代码是否需要变动, 以及验证功能是否正常

由于 Mysql 和 MariaDB 本身都是 GPLv2 协议, 本次依赖升级不再考虑这两个数据库;<br>

#### SQLite && Postgresql
##### SQLite
   1. [官网](https://sqlite.org/)
   2. C 语言库, 实现了一个小型, 快速, 独立, 高可靠性且功能齐全的 SQL 数据库引擎;
   3. 广泛被使用于 Android, iOS设备, Chrome等浏览器, Python, 大多数电视机和机顶盒, 数以百万计的其他应用程序等等 [source link](https://sqlite.org/mostdeployed.html);
   4. SQLite 源代码属于公共领域, 任何人都可以免费用于任何目的;

##### Postgresql
   1. [官网](https://www.postgresql.org/)
   2. C 语言库, 功能强大的开源对象关系数据库系统, 使用和扩展了 SQL 语言, 能够安全地存储和扩展最复杂的数据工作负载
   3. license, 类似于 BSD 和 MIT license
      1. 在添加完版本声明等内容后, postgresql 特此授予出于任何目的, 免费且无需书面协议使用, 复制, 修改和分发软件及文档的许可 [source link](https://www.postgresql.org/about/licence/)

##### 对比

| 评估维度     | Postgresql                                       | SQLite                                                   |
|----------|--------------------------------------------------|----------------------------------------------------------|
| 核心定位     | 功能强大的开源对象-关系型数据库, 适用于复杂、高并发的企业级应用                | 轻量级、嵌入式数据库, 适用于嵌入式设备、移动端、桌面应用及小型单机工具                     |
| 开源协议     | Postgresql许可证, 非常自由宽松的类BSD/MIT许可证, 没有版权约束        | 公有领域, 允许任何目的的任何使用, 是最宽松的方式                               |
| 架构模式     | 客户端/服务器架构, 有独立的守护进程, 需要安装, 配置和守护进程               | 无服务器架构, 数据库引擎(jar包)直接嵌入应用程序中, 只有一个文件, 零部署                |
| 并发与读写能力  | 强大。采用MVCC, 读写互不阻塞, 轻松支持高并发读写                     | 非常有限。写操作会锁定整个数据库文件, 本质上不支持并发写入, 高并发读也会受写操作阻塞             |
| 事务支持     | 完全支持ACID, 提供完善的事务隔离级别                            | 支持ACID, 但在高并发下, 由于锁机制, 事务实际成功率可能受影响                      |
| 功能与SQL标准 | 高度兼容SQL标准, 功能全面, 支持窗口函数、CTE、JSONB、GIS扩展等, 可扩展性极强 | 支持大部分SQL, 但缺少外键约束（可解析但不强制）、部分连接操作等高级功能                   |
| 性能特点     | 擅长处理复杂查询、大数据量和高并发场景, 但简单读取操作可能比MySQL稍慢           | 在本地、单线程访问时, 因无网络开销, 速度极快。 适用于单用户或低并发访问。<br/> 但并发性能是其主要瓶颈 |
| 资源开销     | 较高, 有独立的服务进程, 会消耗更多内存和 CPU                       | 极低, 仅作为一个库链接, 资源占用极小                                     |
| 数据存储方式   | 通常是一个复杂的文件目录结构                                   | 单个磁盘文件                                                   |
| 适用场景     | 中大型 Web 应用, 企业级应用                                | 嵌入式设备, 移动应用, 桌面应用, 小型网站                                  |

##### Sqlite 锁与机制
1. 读操作需要共享锁(SHARED Lock): 当一个连接操作执行读操作(如 Select) 时, 首先需要获取数据库的共享锁。多个连接可以同时持有共享锁
2. 但共享锁(读)与排他锁(写)不能同时存在, 会被对方阻塞, 影响性能和并发
3. 当可以通过设置日志模式来优化性能
   1. 默认模式为 回滚日志模式
      1. 读并发: 多个读连接可以同时进行
      2. 写阻塞读: 是。当有写事务提交时(获取排他锁期间), 所有新的和正在进行的读操作会被阻塞, 直到写完成
      3. 读阻塞写: 是。只要还有一个读事务未结束, 写事务就无法完成提交(无法获得排他锁)
      4. 适用于并发要求不高的简单应用
   2. 预写日志模式(WAL 模式):
      1. 多个读操作可以同时进行, 且读操作不阻塞写操作(写操作也不阻塞读操作), 并发性更高
      2. 写阻塞读 && 读阻塞写: 否. 读写互不阻塞
      3. 推荐用于绝大多数场景
      4. PRAGMA journal_mode=WAL 配置启动

##### 分析
1. ZE 目前存储的数据大部分是配置类数据, 不会存储比如历史信号这些大量的实时值
2. ZE 目前的与外界的交互都是 SI, 大多数时间下不会有很多用户同时操作, 并发度低
3. Sqlite 对于我们这种场景下足够使用了
4. 在 SI 进行容器化的场景下, 使用 Sqlite 可以少使用一个镜像(原Mysql), 减少最终整包镜像体积
   1. 使用 Postgresql 的话, 也还是需要找到镜像, 进行初始化, 配置等等, 整合进 SI 里面
5. 选择 Sqlite
6. 另: 
   1. Sqlite 不用账号和密码来登录, 需要考虑安全问题 [todo]. FleetManagement 也是用这个数据库, 那边已经在和安全团队沟通了 


#### 变动 && 影响 && 测试范围
1. 去除整包里面, Mysql 的安装包, 安装指令, 配置等
2. 去除 ZE 里面关于 Mysql 的依赖
3. ZE 新增 Sqlite 的依赖
4. 修改初始化数据库的 sql 文件(包括转化表字段类型, 索引等)
5. 需要验证
   1. 初始化数据库之后, 数据是否正常
   2. 验证读写是否还有相互阻塞
   3. ZE 数据库性能是否还正常, 比如 SI进行批量添加设备, 处理设备批量离线的告警等
   4. ？


### ZE: Java + SpringBoot upgrade: US1054, US966
#### Java

| Name         | Latest Version   | CPU       | Description                |
|--------------|------------------|-----------|----------------------------|
| Java 17(LTS) | 17.0.16+8 kernel | 2023.10   | zulu17.60.17-ca-jre17.0.16 |
| Java 21(LTS) | 21.0.8+9 kernel  | 2024.4.16 | zulu21.44.17-ca-jre21.0.8  |

*CPU (Critical Patch Update):
Oracle定期在每季度的一月、四月、七月和十月发布安全更新。这些更新会修复自上一个CPU以来发现的安全漏洞。*
*Refers to https://www.oracle.com/security-alerts/cpujul2025.html#AppendixJAVA for Risk Matrix*

1. ZE 目前的具体版本是 zulu17.54.21-ca-jre17.0.13, 有 35 个漏洞 CVE([公司数据来源](https://gitlab.com/vertiv-co/apac/TAF/si-security-issues/-/issues/91))
2. 目前看来可供选择的版本有
    1. zulu17.60.17-ca-jre17.0.16, 包含截止到 2023/10 的更新和修复, 最终支持结束的时间为 2029/9
    2. zulu21.44.17-ca-jre21.0.8, 包含截止到 2024/4 的更新和修复, 最终支持结束的时间为 2031/9
    3. [支持结束时间来源](https://www.azul.com/products/azul-support-roadmap/)
3. zulu java 的开源协议是 GPLv2 + CE
    1. CE: Classpath Exception, 商业缓冲, 允许与闭源应用动态链接生成可执行文件, 且应用程序可采用任意许可协议分发, 即无需因为使用 zulu java 而开源本身代码, 是 GPLv2 的例外条款
    2. 在不修改 zulu jdk 源码情况下不需要开源代码, 无法律风险
4. 选择 zulu21.44.17-ca-jre21.0.8

#### SpringBoot
1. 当前版本为 3.3.5, 1个本身漏洞, 2个传递性依赖漏洞
2. 结合上述选择的 Java21, 需要的 SpringBoot 版本需要为 3.X
3. 目前看来可选择的版本为 (排除预览版本(Preview, 比如 v4.0.0-M3), 快照版本(Snapshot, 比如 v3.5.7-SNAPSHOT))
    1. 3.5.6, 最新的稳定版本, 0 个本身漏洞, 0个传递性依赖漏洞, 2025/9/18发布
    2. 3.5.5, 0个本身漏洞, 1个传递性依赖漏洞, 2025/8/1发布
    3. [SpringBoot 3.5.6 官方文档](https://docs.spring.io/spring-boot/index.html), [SpringBoot 3.5.6 release note](https://github.com/spring-projects/spring-boot/releases/tag/v3.5.6)
4. 选择 SpringBoot 3.5.6

#### 变动 && 影响 && 测试范围
zulu java21 + SpringBoot 3.5.6 <br>
1. 对于 ZE 来说属于底层依赖升级
2. 目前预研阶段, 只改了依赖版本, 无任何代码级修改即可编译成功, 也能成功运行, 出现问题概率小
3. 需要测试 ZE 的功能是否正常, 性能是否正常, 比如采集信号, 处理告警等等

### SI: Hazelcast Upgrade: US965
#### 概况和升级方向

| 相关依赖                           | hazelcast        | hazelcast-spring | hazelcast-wm                                          | hazelcast-kubernetes  |
|--------------------------------|------------------|------------------|-------------------------------------------------------|-----------------------|
| 作用                             | hazelcast 核心库    | spring配置支持       | 分布式会话存储, 集群全局访问, 故障转移                                 | 在 k8s 中操作 hazelcast集群 |
| 当前版本                           | 3.12.13          | 3.12.13          | 3.7.1(工程根 pom.xml 为 3.12.13, 但是在 webapp 里面被重写为 3.7.1) | 2.2.3                 |
| 漏洞(发布时间, 本身漏洞数量, 传递性依赖漏洞数量)    | 2022/8/25, 2, 20 | 2022/8/25, 0, 10 | 2016/9/19, 0, 67                                      | 2021/6/18, 0, 11      |
| 升级版本                           | 5.5.0            | 5.5.0            | 5.1.0                                                 |                       |
| 新版本漏洞(发布时间, 本身漏洞数量, 传递性依赖漏洞数量) | 2024/7/25, 0, 10 | 2024/7/25, 0, 2  | 2025/5/9, 0, 11                                       |                       |

1. user story 明确提出需要升级到 hazelcast 5.4.0+ 以上 ("After the upgrade of JRE (min ver.17), please upgrade Hazelcast to v.5.4.0 at least")
2. hazelcast v5.5.0 是长期支持版本(2年), [hazelcast v5.5.0 doc](https://docs.hazelcast.com/hazelcast/5.5/migrate/upgrading-from-imdg-3#jaas-authentication-cleanups), [hazelcast upgrade doc(from 3.12.X)]()
3. hazelcast 在 2025/10/15 推出了新的 release 版本 5.6.0, [release note](https://docs.hazelcast.com/hazelcast/5.6/release-notes/community)
4. 尽管 hazelcast v5.5.0 不是最新版本, 存在 10 个传递性依赖漏洞都是来自 Apache Tomcat, 并且 mtp-core 里面明确排除了 Tomcat 依赖, 改用 undertow 服务器, 目前看起来该版本无漏洞风险
5. hazelcast v5.6.0 刚刚发布几天, 不排除是否存在隐藏, 未暴露的漏洞等问题; 更新的新功能不是必须的, 不会用到比如集群等高级功能;
6. 有最新稳定版本就选择最新版本, 所以选择 hazelcast v5.6.0

#### hazelcast 相关功能组件
##### hazelcast(核心库) && hazelcast-spring(spring配置支持等)

##### hazelcast-wm(会话分布式存储, 集群全局访问, 故障转移)
[具体功能描述](https://hazelcast.com/use-cases/web-session-clustering/), [version upgrade link](https://github.com/hazelcast/hazelcast-wm/blob/master/upgrade-guides/v4.0-v5.0.md)
```text
- 用于 hazelcast 的会话集群(会话复制)功能, 将用户会话维护在集群内存中(IMDG), 并创建副本保证可靠性
- 每个应用服务器都设置为访问 Hazelcast 平台, 以便所有应用服务器都能访问所有用户会话. 会话均匀分布在 Hazelcast 集群中.
- 如果应用服务器发生故障, 负载均衡器会将会话重定向到另一台应用服务器。您甚至可以关闭单个应用服务器进行维护, 而不会丢失会话数据。用户可以无缝切换至新的应用服务器, 从而获得最高级别的客户体验.
```

#### hazelcast-kubernetes(在 k8s 中操作 hazelcast集群)
- 目前该依赖没有版本可以升级了
- 仍然保留, 后续确实需要这个能力再重构

#### 变动 && 影响 && 测试范围
hazelcast v5.5.0 <br>
mtp-core 已识别出来和尝试的变动如下:
##### 包路径变动

| 类                                                             | 原路径                | 新路径                      |
|---------------------------------------------------------------|--------------------|--------------------------|
| IMap, <br/>MapStore, <br/>MapEvent                            | com.hazelcast.core | com.hazelcast.map        |
| ItemListener, <br/> ItemEvent, <br/> IQueue, <br/> QueueStore | com.hazelcast.core | com.hazelcast.collection |
| IAtomicLong                                                   | com.hazelcast.core | com.hazelcast.cp         |
| ...                                                           | ...                | ...                      |


##### 升级后被官方移除的类
1. MemberAttributeEvent: 原接口逻辑为空, 注释备注到 "This method does nothing as we do not use it.", 应该没用到

##### 升级后配置/设置相关类
1. InMemoryRepository: 设置 IMap 最大容量的配置从 MaxSizeConfig 迁移到了 EvictionConfig
2. CacheConfiguration: 在 dev 配置文件下生效, 用于连接 hazelcast 管理中心, 属性 enabled, url 被去掉
3. HazelcastSessionsEntryListener: 基础的类 com.hazelcast.map.listener.EntryExpiredListener 新增了方法 public void entryExpired(EntryEvent<String, Object> entryEvent)
   - 重写, 实现逻辑为 空
4. MetaDataDefinitionServiceImpl: 为 IMap 创建索引的方式变了; 原 PredicateBuilder 由类抽象成了接口, 改为实现其实现类 PredicateBuilderImpl
5. 等等

##### 升级后的难解决的类
1. HazelcastWebFilter:
   - 该类用于 分布式会话管理, 存储, 同步, 支持会话复制和故障转移等
   - HttpSessionContext 类被去掉了
   - getValue(String name), getValueNames(), putValue(String name, Object value), removeValue(String name) 等方法在父类定义中被去掉, 并且标记为废弃
   - createNewSession 新增了 boolean 类型的形参 create, 不清楚在这个过程中具体起到什么作用
   - getParam(String name), 原方法内部引用父类的 filterConfig, 但 hazelcast-wm 升级后被去掉了
   - 
   - 该类的实例作为 HazelcastFilter 的成员变量;
   - 分析其初始化过程, 需要配置 mtp.cluster.enabled(存在于 application-cluster.properties, 不存在目前在用的 application-prod.properties) 为 true 时才会初始化;
   - 这个情况下, 过滤器链走到 hazelcastFilter 时, 发现 hazelcastWebFilter 为空则直接返回, 空转;
   - 基于上面分析, 解决方案为: 修正编译错误, 没条件验证, 也不保证逻辑正确, 添加注释等后续需要使用的时候再研究、重构等


### SI: Java + SpringBoot upgrade: US981, US966
#### Java
1. SI 目前的具体版本是 zulu-jre-8.58.0.13-linux64.zip, 有 56 个漏洞CVE([公司数据来源](https://gitlab.com/vertiv-co/apac/TAF/si-security-issues/-/issues/80))
2. 可选的长期支持版本有 Java11, Java17, Java21
3. 就算升级到 Java17(和 SI4.0 中的 ZE 一样, 也是还有 35 个漏洞CVE)
4. 所以这次, 建议直接升级到 Java21, 即 zulu21.44.17-ca-jre21.0.8, 保持与 SI4.1 中的 ZE 一样

#### SpringBoot
1. mtp-core 内当前版本为 2.7.18, 1个本身漏洞, 3个传递性依赖漏洞, [漏洞链接, 可点击具体 CVE 进去](https://mvnrepository.com/artifact/org.springframework.boot/spring-boot/2.7.18)
2. taf-commons 内当前版本为 2.6.15, 1个本身漏洞, 3个传递性依赖漏洞, [漏洞链接, 可点击具体 CVE 进去](https://mvnrepository.com/artifact/org.springframework.boot/spring-boot/2.6.15)
3. 结合上述选择的 Java21, 需要的 SpringBoot 版本需要为 3.X
4. 目前看来可选择的版本为 (排除预览版本(Preview, 比如 v4.0.0-M3), 快照版本(Snapshot, 比如 v3.5.7-SNAPSHOT))
   1. 3.5.6, 最新的稳定版本, 0个本身漏洞, 0个传递性依赖漏洞, 2025/9/18发布
   2. 3.5.5, 0个本身漏洞, 1个传递性依赖漏洞, 2025/8/1发布
   3. [SpringBoot 3.5.6 官方文档](https://docs.spring.io/spring-boot/index.html), [SpringBoot 3.5.6 release note](https://github.com/spring-projects/spring-boot/releases/tag/v3.5.6)
5. 保持与 ZE 一致, 选择 SpringBoot 3.5.6

#### 变动 && 影响 && 测试范围
zulu java21 + SpringBoot 3.5.6 <br>
mtp-core: <br>
1. 依赖变动
   1. org.mongodb:mongodb-driver-legacy: 4.4.2(来自于定义的属性 mongodb.version), 导入失败(mongodb-driver-bom 不存在); 
      1. 解决方案: 去除属性定义, 使用 SpringBoot 本身依赖的属性(5.5.1)
   2. io.dropwizard.metrics:
      1. 用途: 用于收集应用的各种指标(如计数器, 计时器, 仪表等), 并通过 JMX, HTTP 等多种方式上报
      2. 升级前使用 SpringBoot 定义的版本 4.2.22, 但是在升级后, 官方去掉了这个依赖的版本依赖
      3. 不可用了, 见以下 ../2.2.5
   3. 工程属性定义:
      1. pom.xml(mtp-core-parent): 
         1. java.version 由 1.8 改为 21
      2. pom.xml(webapp):
         1. plugins: maven-compiler-plugin 里面的 source && target 由 1.8 改为 21
2. 代码级变动
   1. 包路径:
      1. SpringBoot 3.X 基于 Spring Framework6. 将 JavaEE 的 javax 包全面迁移到了 JakartaEE 的 jakarta 包下
         1. 解决方案: 全局替换 javax 为 jakarta
         2. 不需要替换的为 [TrustManager , ImageIO, DataSource, TrustManagerFactory, X509TrustManager, DatatypeConverter, Cipher, GCMParameterSpec, SecretKeySpec]
         3. 同时, hazelcast v3.12.13 里面的 WebFilter 继承了来自 SpringBoot 2.X 的 javax.servlet.Filter, 升级完 SpringBoot 后也需要连带着 hazelcast 一起升级, 不然编译也不过
      2. MongoHealthIndicator: 从 org.springframework.boot.actuate.mongo  迁移到了 org.springframework.boot.actuate.data.mongo 下
      3. MailSSLSocketFactory: 从  com.sun.mail.util.MailSSLSocketFactory  迁移到了 org.eclipse.angus.mail.util.MailSSLSocketFactory 下
   2. 代码变动
      1. MongoDataAccessor && GenericMapStore: 构造器变成内部私有, 需要用工厂方法初始化
      2. buildFindAllComparator(...): 原排序方法 org.springframework.util.comparator.CompoundComparator 在 spring-core.jar 中被移除了
         1. 解决方案: 用 java.util.Comparator 重构
      3. RequestContext 处于 taf-common 工程下, 使用的是 SpringBoot 2.6.15, 也需要升级
         1. taf-common 只需要把 javax 改为 jakarta 等少量操作即可编译成功
      4. [重要] WebSecurityConfig: 
         1. 用途: 配置 认证和授权规则 && 安全过滤器链 && 会话管理策略 && CSRF保护
         2. SpringSecurity 从 5.7.11 变动为了 6.5.5, 继承的 WebSecurityConfigurerAdapter 等被移除或重构了, 需要基于新的框架写法重构逻辑
      5. [重要] WebConfigurer:
         1. initMetrics() 使用了 metrics-servlet 和 metrics-servlets 里面的 InstrumentedFilter 和 MetricsServlet
         2. InstrumentedFilter 和 MetricsServlet 这两个类各自继承了 SpringBoot 2.X 的 Filter 和 HttpServlet
         3. 并且在 metrics 最新版本 4.2.37(2025/9/16), 还是使用的 SpringBoot 2.X, 需要完全重构
      6. 等等
3. 单元测试类, 目前还有 100+ 错误未修改
   1. 只作为开发内部单元测试, 目前也不会打进整包里面, 业务中不会用到
   2. 是否可以不去管这里面的错误？不打进整包, 不编译也不执行？
      1. 在本地编译时可以跳过 /test 目录下文件, 指令比如 "mvn clean package -Dmaven.test.skip=true"
      2. Gitlab 打包的话, 可以在 pipeline 中跳过, 指令比如 "mvn $MAVEN_CLI_SNAPSHOT_OPTS clean deploy -U -Passembly-snapshot -X [-Dmaven.test.skip=true]"

55个后端插件: <br>
   - 除开涉及到 SpringSecurity 的(需要看是否需要重构), 大部分后端插件应该改动量不大, 改动难度小
   - 按照平均一天改 5个插件, 需要的工作量为 11人/天

13个数据插件(模板): <br>
   - 数据插件主要是需要改动 mtp-core-api 或 taf-commons 工程下的依赖(如果有的话)版本
   - 需要在 mtp-core 和 taf-commons 改造完后再改
   - 需要的工作量大概为 2人/天


### SI Dependency Upgrade Test Scope
Java21 + SpringBoot v3.5.6 + hazelcast v5.6.0 <br>
1. 测试的环境:
   1. 基于 SI4.0.1, 升级完上述三个依赖版本后, 用安装整包的方式进行测试
   2. ZE 升级跨度小, 代码变动少且功能没变动, 可以与 ZE 依赖升级(Java, SpringBoot)分开, 分别测试, 这样也能在出现问题的时候, 初步定位是哪块出了问题
   3. 最终测试环境: 升级完依赖后的 SI 部分 + SI4.0.1 原ZE
2. 测试范围
   1. 在 SI 中基本没有用 Java 的高级功能, 所以 Java 升级带来的问题应该很少
   2. SpringBoot 升级带来的影响, 主要来源于包路径的变动, 还有 SpringBoot 本身依赖的组件版本变化所带来的;
      1. 比如 SpringSecurity 从 5.7.11 升级到了 6.5.5, 这过程中 SpringSecurity 本身的代码和优化带来的变动
      2. 主要集中在鉴权认证, 过滤等方面;
      3. 还有 metrics 这个随着 SpringBoot 版本升级被放弃使用, 转而使用更优的解决方案
   3. Hazelcast 升级带来的主要变动是 集合类型数据的变化(索引配置, 最大容器, 取值等)
      1. 会涉及到 定时任务, 分布式任务
      2. 还有从 IMap 等集合中取值的业务等
      3. SI 使用的是本机的 Hazelcast, 没有用到比如集群, 成员, 分布式会话等的能力
   4. 主要测试范围为: 缓存, 实现信号流, 告警流, 通知流, 鉴权
 
## data model
无

## interface doc
无

## upgrade
不考虑从 SI4.1 之前的版本升级到 SI4.1

## affection
1. 对于 ZE 的影响不大, 可控
2. 对于 SI 可能影响到鉴权和其他的基础业务

## risk
SI:
1. 后端插件多, 55个业务插件 + 13个数据插件
2. si-portal, rduaengine 相关等插件逻辑复杂, 不排除遇到新的依赖升级问题, 也不能完全排除复杂逻辑需要重构的场景
3. 依赖升级后, 不能完全保证业务效果和之前一模一样, 因为不能够完全列举出变动了哪些依赖, 某个依赖的内部逻辑是否已经大改. (但一般情况下是应该要兼容之前版本代码的)
4. ？


## notes

### 漏洞网站参考选择

| 特性     | Maven Central (由 Sonatype 运营)                              | Maven Repository                                      |
|--------|------------------------------------------------------------|-------------------------------------------------------|
| 性质     | 官方仓库(The Official Repository)                              | 第三方索引网站(Third-party Indexing Site)                    |
| 运营商    | Sonatype (Maven Central 的创始者和维护者)                          | 独立开发者/团队 (由 @frodriguez 开发)                           |
| 核心功能   | 存储、发布和分发Java/Java生态组件（jar包）。是构建工具（如Maven、Gradle）实际下载依赖的地方。 | 搜索、浏览和探索存储在 Maven Central 和其他仓库中的组件。它本身不存储任何构件（jar包）。 |
| 页面内容重点 | 强调其官方身份、安全服务（如漏洞修复）、企业级解决方案（Nexus Repository Cloud） 和行业报告。 | 提供丰富的元数据统计, 如使用量、分类、流行度排名、新版本发布追踪等, 便于开发者发现和比较库。        |
| 用户体验   | 搜索和浏览功能相对基础, 更偏向于一个功能性的后端服务接口。                              | 搜索和浏览功能非常强大, 界面更友好, 提供了多种维度（分类、标签、流行度）来探索库。             |
| 网址     | https://search.maven.org/                                  | https://mvnrepository.com/                            |
| 漏洞数据来源 | 自有漏洞数据库 + NVD + 0-day漏洞(Sonatype 独家情报)                     | 公开漏洞库(如 NVD)                                          |
| 漏洞覆盖范围 | 公开漏洞 + 未公开漏洞 + 传递性依赖漏洞(但界面看不到)                             | 公开漏洞 + 传递性依赖漏洞(页面有展示)                                 | 

结论:
```text
- Maven Central 对于库本身是否存在漏洞的判断比 Maven Repository 更准确; Maven Repository 有展示传递性依赖漏洞; 这两个平台可以配合使用
- 从 Maven Central 获取库本身代码是否存在漏洞, 再从 Maven Repository 获取库是否存在依赖漏洞, 最后基于这两个平台选择时候的新版本库 
```

例如: <br>
hazelcast 3.12.13 版本 <br>
Maven Central 显示 hazelcast 3.12.13 版本有 2 个高等级的漏洞; [link](https://ossindex.sonatype.org/component/pkg:maven/com.hazelcast/hazelcast@3.12.13) <br>
![](./image/hazelcast-mavencentral.png) <br>

而 MVN Repository 显示有 hazelcast 本身有 4 个漏洞, 有 20 个传递性依赖漏洞; [link](https://mvnrepository.com/artifact/com.hazelcast/hazelcast/3.12.13) <br>
注: 如果我们没有使用到 hazelcast 有传递性依赖漏洞的功能, 应该是不会有问题的 <br>
![](./image/hazelcast-mvnrepository.png) <br>

上面的统计基于这个方法<br>

### GPLv2

GPLv2(GNU General Public License version 2): 通过版权法来确保软件的自由使用, 修改, 和分发的权利能够得以延续.

| 核心业务   | 具体要求                                                            |
|--------|-----------------------------------------------------------------|
| 开源要求   | 如果分发基于 GPLv2 代码的衍生作品, 必须将整个衍生作品的源代码以 GPLv2 或兼容许可证开源              |
| 代码提供   | 分发二进制可执行文件时, 必须同时提供完整的对应源代码, 或提供为期至少三年的书面要约, 以不高于成本的费用提供源代码        |
| 版权声明保留 | 必须保留原始代码中的所有版权声明、许可证信息及免责声明                                     |
| 修改声明   | 如果修改了代码, 必须在修改的文件中显著标注修改内容和日期                                    |
| 备注     | 仅内部使用GPLv2 软件而不分发（例如, 仅在公司内部服务器上运行）, 通常不触发开源义务。义务在分发（发布、交付给外部）时产生 |

#### 聚合体 && 衍生作品

| 特征       | 聚合体 (Aggregate)                                                  | 衍生作品/联合作品 (Derivative Work/Combined Work)                                 |
|----------|------------------------------------------------------------------|---------------------------------------------------------------------------|
| 结合方式     | 多个独立程序通过存储或分发介质（如同一个安装包、CD-ROM）集合在一起, 但彼此没有功能上的依赖关系               | 程序之间通过共享内存、函数调用、紧密的进程间通信（如RPC） 等方式深度结合, 形成一个功能上相互依赖的整体                     |
| 紧密性      | 交互松散, 各自是独立的进程, 一个程序的运行不依赖于另一个程序的功能或内部实现。                          | 高度依赖, 像一个单一程序那样协同工作, 程序A需要调用程序B的内部功能或数据结构才能实现其核心功能                          |
| 认定       | 被视为多个独立作品的简单集合。GPLv2的“传染性”在此中断, GPL程序之外的独立作品不受GPL条款约束             | 被视为基于GPL代码创建的单一衍生作品或联合作品。整个作品都被视为“基于GPL程序”, 因此必须全部遵循GPL协议                  |
| GPLv2传染性 | 无传染性。聚合体中的其他独立程序可以保持自己原有的许可证（包括闭源）                               | 具有强传染性。整个衍生作品/联合作品必须整体以GPLv2（或兼容）许可证发布                                    |
| 举例       | 将一个GPLv2授权的文本编辑器和一个闭源的词典软件打包在同一张光盘上出售。用户可以选择只使用编辑器或只使用词典, 两者功能无关。 | 一个闭源的图形界面程序（GUI）静态链接了一个GPLv2的图形库。GUI程序无法脱离该图形库运行, 它们共同编译成一个可执行文件, 形成一个功能整体。 |

自由软件基金会（FSF）对此有明确的官方立场：如果两个程序只是通过“执行和通信”进行交互, 那么它们构成一个聚合体。一个程序仅仅是“与”另一个 GPL 程序通信, 并不会因此使自己成为衍生作品并需要遵守 GPL. <br>
