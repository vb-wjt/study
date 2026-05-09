# 中国移动 全业务支撑平台 (CHBN/ASP) 提炼 ⭐⭐

> **来源**:
> - `file/2-projects/asp/project.md` (87 行,项目背景 + 5 大模块 + 校内搜搜 / 中移基线)
> - `file/2-projects/asp/knowledge.md` (570 行,极密集技术总结)
>
> **时间线**:**2022.07 - 2024.03**(约 1 年 8 个月)
> **公司**:中国移动(广州)
> **角色**:Java 后端开发(看 knowledge.md 涉及的覆盖度,**实际承担了相当多的"骨干"工作**)

标签:`[就绪]` `[简历亮点]`⭐⭐ `[面试高频]`🎯 `[源文]`

---

## 0. 一眼总结(简历可用一句话)

> **整合中国移动 CRM/BRM 两大核心系统的"全业务支撑平台",涉及多业务中心拆库、SQL 路由代理(dbproxy)、订单中心微服务化、产品配置迁移、外围平台对接等全栈工作。技术栈:Spring Cloud(Eureka/Zuul/Feign)+ Spring Boot + MyBatis + Oracle + Redis + Kafka + Activiti + 联创磐基 K8s。**

---

## 1. 项目背景

### 1.1 业务起因
- **CRM**(客户关系管理)和 **BRM**(计费业务管理)是两个独立系统
- 业务办理需要**跨系统协作**,流程繁琐、费时、客户体验差
- 同时需要**维护两套**客户/订单/业务数据 → 运营成本高

### 1.2 解决方案
> 整合数据和业务,**融合个人/家庭/政府/企业业务**,构建面向多角色的**一站式业务处理 + 融合销售统一门户**。

### 1.3 业务范围(融合后)
- **个人** + **家庭** + **政府** + **企业** 四大角色
- 销售端 + 服务端 + 运营端
- 与外围对接:能运、DICT、集客大厅、电渠、BBOSS 省公司等

---

## 2. 五大工作模块(按时间顺序)

### 2.1 ⭐ 模块一:CRM/BRM 数据整合(拆库 + 模型重建)

**做了什么**:
- 对比两套系统数据库表 → 同表字段差异化融合
- 按业务**划分中心**(订单中心 / 客户中心 / 产商品中心 / 公共能力中心 等)
- 旧数据**下沉**到新数据库 + 旧系统新增数据用**定时任务同步**(原计划用 DataX/Canal,**因数据量过大未完整实施 [⚠️ 用户标了"存疑?"]**)

**关键技术决策(简历可写)**:
> ⚠️ "**为什么不用 ShardingSphere?**" 这是面试高频题,knowledge 已经给了 4 条理由:
> 1. 全业务是**先整合再分库**,不是纯垂直/水平拆分
> 2. 表多(两个系统合计**上千张表**),配置工作量爆炸
> 3. 存量应用每个都要单独配置,变更难统一
> 4. 大量**多表关联 / 分页 / 跨库 join**,ShardingSphere 不能完美支持

### 2.2 ⭐⭐ 模块二:SQL 解耦 (dbproxy)

> 这是 **simple 但是体现"工程师 vs 框架使用者"** 的高价值素材。

**问题**:
- 数据按"中心"拆到不同数据库后,存量 Spring 应用里大量 SQL 是**跨中心**的(原本同库,现在跨库不可执行)
- 存量应用大多**老旧**,不适合直接配多个数据源连接

**方案 - dbproxy**:
- 在 **Druid 处做代理**,自定义数据源代替原生 DataSource
- **流程**:获取 SQL → 解析表名 → 字典查表所属"中心" → 配置查中心地址 → 远程发 SQL → 拿结果返回
- **集成在存量应用内**(不是单独中间件),无需高可用考虑

**简历价值**(L4 反思级别):
> "面对'1000+ 张表跨中心 SQL'的工程问题,选择**轻量代理 + 业务字典**而非 ShardingSphere/Mycat 等重型中间件,是基于:存量应用形态、变更成本、查询模式复杂度的综合权衡。"

### 2.3 ⭐ 模块三:订单可视化 / 订单中心微服务化

**业务**:BRM 产品的订购全流程支持 + 各环节(时间/结果)可视化。

**5 个微服务(简历可写架构)**:

| 服务 | 职责 |
|---|---|
| `orderentry` | 订单处理(下单 / 审批 / 签章 / 合同打印 / 补录 / 商务验收) |
| `orderquery` | 订单查询 |
| `ordermanage` | 订单管理 |
| `shopmgr` | 购物车 |
| `orderProv` | 省订单中心(对接省公司) |

**架构亮点**(可在面试讲):
- 微服务化 + 各服务独立可发布
- BPMX(基于 Activiti)做流程编排
- 不同产品有不同订购流程 / 特殊化适配

### 2.4 模块四:产品迁移(BRM/CRM → 新平台)

**做了什么**:
- 迁移产品的**属性配置**(页面属性 / 订购关系 / 定价)
- **联动脚本重写**:从 `uee` 迁移到 `formily`(表单引擎)
- 不同产品订购流程 → BPMX(基于 Activiti)
- 适配特殊化接口

### 2.5 模块五:追平需求(平台演进期间)

**业务背景**:新平台搭建期间,**旧系统也在持续开发**——需要在新平台**追平**旧系统的需求/特性。

**主要工作**:
- 完成 BRM 堆积的日常需求
- **大量与外围平台交互**:能运 / DICT / 集客大厅 / 电渠 / BBOSS 省公司 等

> ⭐ 这一段在简历上可以体现**"在演进期承担追平 + 协作"** 的可靠性 —— 这正是 Vertiv L 第二年说你"扎实有耐心、项目结果有针对性改进"的延续证据。

---

## 3. 技术栈全景图(从 knowledge.md 重建)

### 3.1 应用层

| 类别 | 选型 |
|---|---|
| **前端** | React + Ant Design + ECharts |
| **后端** | Spring / Spring Boot + MyBatis + Swagger,**Java 8** |
| **Web 容器** | **宝兰德 BES**(国产化) |
| **微服务框架** | Spring Cloud:Eureka(后改 ZK) / Zuul / Feign(自定义封装 RestTemplate)/ ❌ Hystrix / ❌ Ribbon |
| **流程引擎** | Activiti(BPMX) |
| **规则引擎** | Drools |

### 3.2 数据层

| 类别 | 选型 |
|---|---|
| **主库** | **Oracle** |
| **缓存** | Redis(远程) + Caffeine(本地)→ 两级缓存 |
| **MQ** | Kafka(配合日志) |

### 3.3 部署 / 运维

| 类别 | 选型 |
|---|---|
| **CI/CD** | Jenkins + Maven 编译 |
| **容器化** | Dockerfile + 镜像仓库 |
| **编排** | K8s(联创磐基平台) |
| **配置** | 外挂配置文件(java -jar) |
| **日志** | NFS 共享文件夹 + ELK(ElasticSearch + Logstash + Kibana) |
| **监控** | Prometheus |
| **告警** | DV |
| **自动化运维** | Ansible |
| **负载均衡** | nginx-ingress-controller(含 nginx + lua-resty-waf + default-backend) |

### 3.4 弹性计算层

> "**联创磐基** + 租户管理 + 软件仓库 + K8s + Docker" —— **这是国企特色的国产化栈**,可以在面试时作为"接触过国产化云原生方案"的差异化谈点。

---

## 4. 核心技术亮点(面试可讲) ⭐⭐⭐

### 4.1 ⭐ JVM 启动参数(实战级)

knowledge.md 里有完整的生产环境启动参数清单:

```bash
java
  -Xss512k                                       # 线程栈 512KB
  -XX:MaxRAMPercentage=70.0                      # 最大内存 70% (容器友好)
  -XX:MaxMetaspaceSize=256M                      # 元空间 256MB
  -XX:MaxDirectMemorySize=256M                   # 直接内存 256MB
  -XX:+HeapDumpOnOutOfMemoryError                # OOM 自动 dump
  -XX:HeapDumpPath=/hwlog/chbn-service/orderentry  # dump 路径
  -XX:-OmitStackTraceInFastThrow                 # 禁用快速异常优化(便于排查)
  -Dspring.profiles.active=365omxq               # 多环境配置
  -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=0.0.0.0:9009  # 远程 debug
```

> 🎯 **面试可讲点**:**为什么用 `MaxRAMPercentage` 而不是 `-Xmx`** —— 容器化部署时,RAM 是动态的,百分比更友好。这是**实战经验**,书本上很少明确教。

### 4.2 ⭐⭐ 缓存方案(三层架构)

```
应用 → Caffeine (本地) → Redis (分布式) → Oracle (持久化)
```

**Caffeine 用途**:微服务里"系统参数 / 字典"等高频访问数据,**TTL = 1 分钟**。

**Redis 用途**:产商品的"常用配置表",支持**手动刷新 + 定时自动刷新**。

**一致性策略**:**先写 DB 再删缓存**(已经在 PDF 也有详细分析)。

#### 4.2.1 ⭐ cache-cli + cache-server (内部刷新机制)

knowledge.md 里描述了一个**精巧的设计**:

```
cache-cli (@ShellComponent)  →  HTTP/Shell  →  cache-server  →  Redis 刷新
                                                  │
                                                  ├─ 加分布式锁 (DistributedLock)
                                                  ├─ 大表外排序 (OuterSort + 败者树)
                                                  ├─ 入 Redis (opsForHash putAll)
                                                  └─ 发布刷新通知 (convertAndSend UPDATE_INFO_CHANNEL)
```

> 🎯 **面试 L4 加分**:这里可以讲"**为什么用败者树外排序?**" —— 数据量过大不能全内存排序,**外排序 + 败者树是教科书级的工程实践**。这是大学算法课内容真的用上的少见场景。

### 4.3 ⭐⭐ 网关(portal-gateway)

#### 4.3.1 同一工号在线人数控制

```java
List<sessionId> = redisTemplate.boundHashOps(operatorKey)
if (size > 字典阈值):
    按过期时间排序去掉最早的
    redisTemplate.opsForList().remove(key, oldestSessionId)
    redisTemplate.opsForList().rightPush(key, newSessionId)
```

#### 4.3.2 ⭐ Token 鉴权 4 个 Filter 链(责任链模式)

| Filter | 职责 |
|---|---|
| `AuthFilter` | 从请求头 / Cookie 取 token,校验 Redis 是否存在 |
| `OperatorAuthFilter` | 取操作员信息,初始化 PortalReqContext (ThreadLocal) |
| `FrequentAccessFilter` | 按天/时/分钟限流;超限删 Redis token |
| `ApiAuthZuulFilter` | Zuul 转发时加 ak/sk(校验 appId + timestamp + sign) |

> 🎯 **面试可讲**:这是**经典的责任链 + ThreadLocal 上下文**模式,在大型应用网关里普遍存在。可以对比 Spring Cloud Gateway / Zuul 的 GlobalFilter 来讲。

### 4.4 ⭐⭐⭐ 自定义注解 + AOP 实现 Redis 分布式锁

> 这是 **knowledge.md 里最完整的代码,~150 行,直接可写进简历**。

**核心设计**:

```java
@Retention(RUNTIME) @Target(METHOD)
public @interface RedisLock {
    String prefixKey() default "";       // 默认方法全限定名
    String key();                        // SpringEL 表达式
    long waitTime() default 1L;
    TimeUnit unit() default TimeUnit.SECONDS;
    boolean throwException() default true;
}

@Aspect
@Order(Ordered.HIGHEST_PRECEDENCE)        // ⭐ 关键:锁切面 > 事务切面
public class RedisLockAspect {
    @Around("@annotation(...RedisLock)")
    public Object around(ProceedingJoinPoint pjp) {
        // 1. 解析 SpringEL 表达式得到锁 key
        // 2. tryLock(waitTime, unit)
        // 3. 失败则抛业务异常 / 返 null
        // 4. 成功则 proceed,finally 解锁
    }
}
```

**Spring Boot 自动装配**:
- 通过 `RedisLockAutoConfiguration @Configuration`
- 在 `META-INF/spring.factories` 声明 → **作为公共 slib 给所有微服务用**

#### 4.4.1 ⭐⭐ 为什么 `@Order(HIGHEST_PRECEDENCE)`(锁在事务外)

> 🎯 **这是 P7+ 级面试题的核心理解**。knowledge.md 给了 4 条理由:
>
> 1. **锁在事务外**:分布式锁保证多实例并发,事务保证单实例原子性 → **职责不同**
> 2. **先加锁后开事务**:事务执行期间锁始终持有,直到事务完成才释放 —— **避免事务回滚后锁还没释放导致死锁**
> 3. **确保锁正确释放**:无论事务提交/回滚,锁都在事务结束后释放
> 4. **AOP 顺序**:Spring AOP 不指定 Order 时执行顺序不确定 → 必须显式 `@Order`

### 4.5 ⭐ 多数据源切换(RegionRouteDataSource)

```java
public class RegionRouteDataSource extends AbstractRoutingDataSource {
    // 通过 ThreadLocal 切换数据源
    @Override protected Object determineCurrentLookupKey() {
        return DataSourceContextHolder.get();
    }
}
```

**用法**:`DataSourceContextHolder.set("某中心")` → 之后所有 SQL 走那个数据源。

> 🎯 **面试可讲**:这是 Spring 提供的标准能力 + 业务场景应用,**比第三方分库分表中间件轻量 100 倍**。

### 4.6 ⭐⭐ 二次登录(数据库密码不明文)

> knowledge.md 描述的方案非常**有特色**(国企/金融特色):

```
1. 配置文件里只有 "logon 用户/密码" (一个仅有"读取存储过程权限"的账号)
2. Druid 在 getConnection 时拦截
3. 用 logon 账号连库,执行存储过程 AP_GETDBUSERANDPASS
4. 解密得到"真正的 dbuser/dbpass" → 真实连接业务数据库
5. 配置文件中永远没有真实密码
```

> 🎯 **面试 L4 加分**:这是**国企/金融行业**特有的安全合规模式 —— 在外企面试可以作为"我做过严格安全合规场景"的差异化亮点。

### 4.7 ⭐ 文件接口模式

> "把配置配到数据库中,**输入和输出都是文件**" —— 避免接口出入参过大。

> 🎯 **面试可讲**:这是大型企业系统对接外围(BBOSS / 省公司)的**通用模式**,属于"**业务知识深度**" 的体现 —— 互联网厂出身的开发者很少接触。

### 4.8 ⭐ Arthas 实战(神器)

knowledge.md 给的命令:

```bash
# 查看类的加载器
sc -d com.alibaba.druid.filter.stat.StatFilter

# 修改运行时 bean 字段值(动态调优!)
ognl -c <classloader_hashcode> '@com.huawei.gd.baselib.util.SpringUtil@getBean("statFilter").slowSqlMills=0'
```

> 🎯 **面试 L4 加分**:**线上动态修改 bean 字段值** 这种操作,只有真在生产环境救火过的人才会熟练。可以讲一个"线上 X 接口慢,通过 Arthas ognl 修改阈值动态观察"的具体故事。

### 4.9 ⭐ HttpServletRequest body 重读问题(经典坑)

knowledge.md 给了**完整解决方案** (~50 行):

**问题**:
- `applicationFilterChain` → DispatcherServlet → `@RequestBody`
- **InputStream 只能读一次** — 前面 Filter 读了,Controller 读不到 → "required request body is missing"

**解决**:`CachedBodyHttpServletRequestWrapper extends HttpServletRequestWrapper`
- 构造时缓存 body byte[]
- 重写 `getInputStream()` / `getReader()` 返回缓存

> 🎯 **面试 L3-L4**:这是几乎每个**做过网关 / 拦截器的 Java 后端**都会踩的经典坑,但很多人**只知道现象不知道根因**。

### 4.10 K8s 实战指令

```bash
kubectl get pod -n 365omxq                          # 查看 pod
kubectl -n 365omxq exec -it gz-orderentry-XXX -- sh # 进 pod
kubectl delete pod -n 365omxq gz-orderentry-XXX     # 删 pod (会被 deployment 自动重建)
kubectl rollout restart deployment -n 365omxq gz-orderentry  # 滚动重启
kubectl get p,svc -n 365omxq                        # 查看节点 + service
```

### 4.11 设计模式实战清单(可面试用)

| 模式 | 在 ASP 中的应用 |
|---|---|
| **责任链** | applicationFilterChain(Auth → Operator → Frequent → ApiAuthZuul) |
| **策略** | 各种 handler 处理不同业务类型 |
| **代理** | dbproxy (Druid 代理 + SQL 改写) |
| **模板方法** | DAM XA 事务的标准化骨架(隐式) |
| **单例** | Spring Bean(默认) |
| **观察者** | Redis pub/sub 缓存刷新通知 |

---

## 5. 复杂业务场景(简历可讲)

### 5.1 ⭐⭐ 成员下发的全流程(跨平台 + 异步 + 文件交换)

> knowledge.md 描述的极其完整的真实业务流程:

```
省公司 → 网关 → 公共能力 jbusiness
  ↓ (jb 判断是否需要订单中心)
订单中心 (orderentry) → 入任务表
  ↓ (后台进程任务扫描)
后台进程 → 通过 jb 处理 → 生成订单 → 更新任务表状态
  ↓ (定时任务)
存量 BRM 定时任务 → 扫到任务 → 生成文件
  ↓ (SFTP)
外围平台 → 处理文件 → 反馈文件
  ↓ (另一个定时任务)
扫描反馈文件 → 处理逻辑 → 更新任务状态
  ↓ (后台进程恢复)
更新订单 → 同步到省库 → 走完流程 → 迁数据到历史表
```

> 🎯 **面试可讲**:这是**典型的国企/电信级复杂业务流** —— 涉及实时接口 / 定时任务 / 后台进程 / 文件接口 / 外围平台联动 5 类技术。互联网厂的"消息驱动"思维一般遇不到这种**异步 + 文件 + 多次状态机**的复杂度。

---

## 6. 遇到的难点(简历"挑战 + 解决"段落用)

### 6.1 业务规则校验 / SQL 解耦
- 校验逻辑分散(数据库表 + jb 函数)
- 重构为 **Groovy 规则引擎** → 统一校验

### 6.2 大数据量 SQL
- `IN > 1000`
- `JOIN / LEFT JOIN / RIGHT JOIN` 跨大表
- 分页 / 排序优化
- 三户模型(主体+用户+客户)校验慢 → 重构

### 6.3 接口性能优化
- 不走索引问题排查
- 校验失败也继续校验的浪费 → 短路优化

### 6.4 产品迁移的特殊化适配

### 6.5 追平需求中的复杂业务
- SFTP 算法协商失败问题
- 成员下发的复杂流程(见 §5.1)
- 涉及工程多 / 调试困难 / 逻辑深 / 跨外围

### 6.6 ⚠️ 云原生订单中心的两个坑

knowledge.md 明确记录:
1. `@RequestBody` 为空(见 §4.9)
2. `@ComponentScan slib` 后启动报"已存在实例 XXX"

---

## 7. 简历可写的 STAR 段(直接可复制)

```
【项目名称】中国移动 · 全业务支撑平台 (CHBN/ASP) —— 融合 CRM + BRM 业务
【在职时间】2022.07 - 2024.03 (1 年 8 个月)
【项目角色】Java 后端开发 (后期承担骨干 / 子模块负责)
【项目规模】[TODO: 团队人数] / 服务于中国移动广东省 [TODO: 用户数]
【项目背景】
中国移动 CRM(客户)和 BRM(计费)两套系统跨系统办理流程繁琐、数据双维护成本高。
项目目标:整合数据 + 业务,构建面向"个人/家庭/政府/企业"的一站式融合销售统一门户。

【主要工作】
- 数据整合(拆库):对比两套系统的"上千张表",按业务划分到 4 大中心(订单/客户/产商品/公共能力),
  完成模型重建;考虑数据规模,放弃 ShardingSphere 等重型中间件方案
- ⭐ SQL 解耦(dbproxy):自研 Druid 代理层,实现"获取 SQL → 解析表名 → 字典查中心 → 远程执行"
  路由,单应用集成无独立中间件,解决 1000+ 张表跨库 SQL 兼容问题
- ⭐ 订单中心微服务化:5 个微服务(orderentry / orderquery / ordermanage / shopmgr / orderProv),
  支持下单 / 审批 / 签章 / 合同打印 / 补录 / 商务验收等订购全流程
- 产品迁移:从 BRM/CRM 迁移产品配置;联动脚本由 uee 重构为 formily;流程引擎用 Activiti BPMX
- 公共能力建设:基于 Spring Boot Auto-Configuration + spring.factories 形式封装公司级 slib
  (如 @RedisLock 注解 + AOP + Auto Configuration 一体化)

【技术栈】
- 后端:Spring Cloud (Eureka→ZK / Zuul / Feign 自封装) + Spring Boot + MyBatis + Java 8
- 数据库:Oracle + Redis + Caffeine 两级缓存 + Kafka
- 部署:Jenkins + Docker + K8s (联创磐基) + ELK + Prometheus + Ansible
- 引擎:Activiti BPM + Drools 规则引擎 + Groovy
- 国产化:宝兰德 BES Web 容器

【关键成果】
- 完成融合平台的核心订单中心微服务上线,支撑 [TODO: 量化业务数据]
- ⭐ 自研 dbproxy 方案被作为 [TODO: 部门/项目群] 内的标准 SQL 解耦实现
- ⭐ @RedisLock 等 slib 公共组件被 [TODO: N 个微服务] 复用
- 解决经典工程问题:HttpServletRequest body 重读、@ComponentScan slib bean 重复等

【对我的成长】
- 接触了"先整合再分库"这类**非主流分库场景**的工程权衡
- 理解了**国企级 / 电信级业务流**的复杂度(实时接口 + 定时任务 + 后台进程 + 文件接口 + 外围平台联动)
- 在 Spring Boot Auto-Configuration、Druid 代理、AOP 编排、ThreadLocal 上下文等基础能力上有深度实战
```

---

## 8. 面试可讲的 Top-10 高频题(基于这个项目)

| # | 题目 | 难度 | 答题要点 |
|---|---|---|---|
| 1 | 为什么不用 ShardingSphere? | L3 | §2.1 4 条理由 |
| 2 | dbproxy 怎么实现的?为什么放在 Druid 层? | L3 | §2.2 + §4.5 |
| 3 | 缓存一致性怎么解决? | L3 | §4.2.1 cache-cli/cache-server + 先写 DB 再删缓存 |
| 4 | @RedisLock 切面为什么要 HIGHEST_PRECEDENCE? | **L4** | §4.4.1 4 条理由 |
| 5 | HttpServletRequest body 为什么读不到? | L3 | §4.9 |
| 6 | ThreadLocal 在网关上下文怎么用? | L3 | §4.3.2 PortalReqContext |
| 7 | 多数据源怎么动态切换? | L2-L3 | §4.5 RegionRouteDataSource |
| 8 | 二次登录的密码安全方案 | L4 | §4.7 |
| 9 | 大表外排序为什么用败者树? | **L4** | §4.2.1 |
| 10 | 复杂业务流(成员下发)怎么设计? | **L4** | §5.1 |

> ⭐ **L4 题**(4/8/9/10)是**和"普通后端 vs 资深后端"的分水岭** —— 优先准备这几个。

---

## 9. 待用户确认 / 补充的(标 [TODO])

| # | 待补内容 | 影响哪份文档 |
|---|---|---|
| 1 | 团队规模 / 你具体子模块负责度 | resume STAR 段 |
| 2 | 服务用户数(广东省 / 全国?) | resume |
| 3 | dbproxy 实际处理过的 QPS / 表数 | resume + interview |
| 4 | "存量数据没整成"的确认 | knowledge.md 你自己标了"存疑?" |
| 5 | "救火员"具体案例(L 第二年聚餐反馈) | resume 软实力 |

---

> 📌 **下一步**:
> - 简历段落 → 复制到 [`../career/resume-projects.md` §2](../career/resume-projects.md#2-中国移动--全业务支持平台-需补充)
> - 面试可讲点 → 整合到 [`../career/interview-talking-points.md`](../career/interview-talking-points.md)
> - **校内搜搜 + 中移基线**(`project.md` 末尾提到)→ 由你自己决定是否值得展开
