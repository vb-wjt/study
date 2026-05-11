# Spring 进阶(Bean / AOP / 启动流程 / 自动装配)

> **写给**:已经熟练使用 Spring 注解 / 会写 @Service @RestController 的你
> **目的**:从"会用"到"懂原理" → P6+ 必备
> **范围**:Spring Framework + Spring Boot;不展开 Spring Cloud(单独可写)

标签:`[P6基线]`⭐⭐⭐ `[与PDF重叠]`📚(PDF p.14-19 给了注解清单 + 工作原理) `[与你项目]`🔗(ASP 大量用) `[国内大厂]` `[外企友好]`

---

## 0. 你的水位评估

| 概念 | 你的水位 | P6 基线 |
|---|---|---|
| @Service / @Autowired / @RequestMapping | ✅ 熟练 | ✅ |
| Bean 作用域 | ✅ 知道 singleton/prototype | ✅ |
| **Bean 生命周期 7 步** | ⚠️ 模糊 | ❌ |
| **循环依赖三级缓存** | ⚠️ 听过没看过源码 | ❌ |
| **AOP 实现 = JDK 动态代理 + CGLIB** | ⚠️ 知道但说不清 | ❌ |
| **@SpringBootApplication 拆开是什么** | ⚠️ | ❌ |
| **spring.factories / Auto-Configuration** | ✅✅ ASP @RedisLock 用过 | ✅ |
| **@Transactional 失效 9 场景** | ⚠️ PDF 已给清单,但没踩过 | ❌ |

---

## 1. ⭐⭐⭐ Bean 生命周期(7 步)`[P6基线]`

```
1. 实例化(Instantiation)        ← 反射 / 构造器
2. 属性赋值(Populate Properties) ← @Autowired 注入
3. Aware 接口回调               ← BeanNameAware / ApplicationContextAware
4. BeanPostProcessor.before     ← 后置处理器(切入点!)
5. 初始化(Initialization)
   ├─ @PostConstruct
   ├─ InitializingBean.afterPropertiesSet()
   └─ init-method
6. BeanPostProcessor.after      ← AOP 代理在这一步生成!
7. 使用(Bean ready)
   ↓ (容器关闭时)
8. 销毁(Destruction)
   ├─ @PreDestroy
   ├─ DisposableBean.destroy()
   └─ destroy-method
```

### 1.1 关键点

- **BeanPostProcessor.after 是 AOP 代理生成的时机** → 这就是为什么 `this.method()` 调不到代理(对象内部调用拿到的是 raw bean)
- **AbstractAutoProxyCreator** 实现了 BeanPostProcessor,在 after 阶段判断是否需要代理 → 如果需要,**返回的是 ProxyFactoryBean 生成的代理对象**

### 1.2 🎯 面试可讲故事(60 秒)

> "Bean 生命周期分为实例化 → 属性赋值 → Aware → BeanPostProcessor.before → 初始化(@PostConstruct / InitializingBean / init-method)→ BeanPostProcessor.after → 使用 → 销毁。其中 AOP 代理是在 BeanPostProcessor.after 这一步生成的,这也解释了为什么类内 self-invocation 会绕过代理 —— 拿到的是 raw bean 不是 proxy。"

### 1.3 🔗 结合你项目

ASP 的 **@RedisLock 注解 + AOP** 就是用 `BeanPostProcessor` 思路,Spring 在 BPP.after 把 `@RedisLock` 标注的方法包装成代理。

---

## 2. ⭐⭐⭐ 循环依赖 + 三级缓存 `[P6基线]`

### 2.1 什么是循环依赖

```java
@Service class A { @Autowired B b; }
@Service class B { @Autowired A a; }
```

A 依赖 B,B 依赖 A,**Spring 单例怎么解?**

### 2.2 ⭐ 三级缓存

```java
// DefaultSingletonBeanRegistry
private final Map<String, Object> singletonObjects;        // 一级:完整 Bean
private final Map<String, Object> earlySingletonObjects;   // 二级:半成品 Bean(已实例化未填充)
private final Map<String, ObjectFactory<?>> singletonFactories;  // 三级:Bean 工厂(可生成早期引用)
```

### 2.3 ⭐ 解循环依赖的流程

```
1. 创建 A:实例化 A → 把 A 的 ObjectFactory 放入三级缓存
2. 填充 A 属性时发现需要 B → 去创建 B
3. 创建 B:实例化 B → 三级缓存
4. 填充 B 属性需要 A → 去三级缓存找 A 的 ObjectFactory → 提前暴露 A → A 升级到二级缓存
5. B 拿到 A 的早期引用 → 完成 B 的初始化 → B 进入一级缓存
6. A 继续完成填充 + 初始化 → A 进入一级缓存
```

### 2.4 ⭐⭐ 关键问题(高频面试)

#### 2.4.1 为什么要 3 级而不是 2 级?

> 因为 **Bean 可能需要被 AOP 代理**。如果只用二级缓存放半成品 Bean,B 拿到的是**未代理的 raw A**;但 A 最终被代理了 → 缓存不一致。
>
> **三级缓存 ObjectFactory 的作用** = 在需要早期引用时,**触发 AOP 代理生成**(通过 `getEarlyBeanReference`)→ 保证 B 拿到的是**代理后的 A**。

#### 2.4.2 哪些循环依赖 Spring 解不了?

| 场景 | 能否解决 |
|---|---|
| 单例 Setter / @Autowired 字段 | ✅ 能(三级缓存) |
| **构造器循环依赖** | ❌ 不能(实例化都没完成,放不进缓存) |
| Prototype Bean | ❌ 不能(每次新建,无法缓存) |
| @Async 加 AOP | ⚠️ 早期 Spring 版本会异常 |

### 2.5 🎯 面试可讲

> "Spring 通过三级缓存解决单例字段/Setter 的循环依赖。三级缓存放 Bean 工厂,在第二个 Bean 需要早期引用时,通过 ObjectFactory 触发 AOP 代理生成 —— 这样保证早期引用是代理对象而不是 raw bean。构造器循环依赖解决不了,因为实例化都还没完成,无法暴露半成品。"

---

## 3. ⭐⭐⭐ AOP 实现原理 `[P6基线]`

### 3.1 两种代理方式

| 方式 | 适用 | 性能 | 限制 |
|---|---|---|---|
| **JDK 动态代理** | 接口实现类 | 略快(JDK 内置) | **必须有接口** |
| **CGLIB** | 普通类(无接口也行) | 启动慢但运行快 | **不能代理 final 类/方法** |

### 3.2 Spring Boot 默认

- **Spring Boot 2.x+ 默认 CGLIB**(`spring.aop.proxy-target-class=true`)
- 早期版本默认是 JDK 动态代理(有接口时)

### 3.3 ⭐ JDK 动态代理简化代码

```java
public interface UserService { void save(User u); }
public class UserServiceImpl implements UserService { ... }

// 创建代理
UserService proxy = (UserService) Proxy.newProxyInstance(
    UserServiceImpl.class.getClassLoader(),
    new Class[]{UserService.class},
    (proxyObj, method, args) -> {
        // before
        Object result = method.invoke(realObject, args);
        // after
        return result;
    });
```

**底层**:JDK 在运行时**生成一个实现 UserService 接口的 $Proxy0 类**,所有方法都委托给 InvocationHandler。

### 3.4 ⭐ CGLIB 简化代码

```java
Enhancer enhancer = new Enhancer();
enhancer.setSuperclass(UserServiceImpl.class);
enhancer.setCallback((MethodInterceptor) (obj, method, args, methodProxy) -> {
    // before
    Object result = methodProxy.invokeSuper(obj, args);
    // after
    return result;
});
UserServiceImpl proxy = (UserServiceImpl) enhancer.create();
```

**底层**:CGLIB 在运行时**继承目标类**生成子类,通过 ASM 操纵字节码。

### 3.5 ⭐⭐ 经典坑:类内 self-invocation 失效

```java
@Service
public class OrderService {
    @Transactional
    public void create() { ... }
    
    public void biz() {
        this.create();  // ❌ 不走事务!因为调的是 raw bean,不是代理
    }
}
```

**解决**:
1. 注入自己 `@Autowired OrderService self;` 然后 `self.create()`
2. `((OrderService) AopContext.currentProxy()).create()`(需要 `@EnableAspectJAutoProxy(exposeProxy=true)`)
3. 拆分到不同类(最干净)

### 3.6 🔗 结合你项目

- **ASP @RedisLock**:Spring AOP + `@Order(HIGHEST_PRECEDENCE)` 让锁切面在事务切面之前执行
- **PI 重构 / SI**:你写过的 `@Async` / `@Transactional` / `@Cacheable` 都是 AOP

### 3.7 🎯 面试可讲

> "Spring AOP 用两种代理:JDK 动态代理(基于接口)和 CGLIB(基于继承)。Spring Boot 2.x+ 默认 CGLIB。AOP 代理在 BeanPostProcessor.after 阶段生成。最经典的坑是类内 self-invocation 失效 —— 拿到的是 raw bean,绕过了代理。我们项目里 @RedisLock 也是 AOP,关键是 @Order(HIGHEST_PRECEDENCE) 让锁切面在事务前。"

---

## 4. ⭐⭐ Spring Boot 启动流程 `[P6基线]`

### 4.1 @SpringBootApplication 拆开

```java
@SpringBootApplication = 
    @SpringBootConfiguration       // = @Configuration
  + @EnableAutoConfiguration       // 自动装配的入口 ⭐
  + @ComponentScan                 // 扫描 @Component 类
```

### 4.2 启动 6 阶段

```
SpringApplication.run(MainApp.class, args)
  ↓
1. 创建 SpringApplication 实例
   ├─ 推断应用类型(SERVLET / REACTIVE / NONE)
   ├─ 加载 ApplicationContextInitializer(从 spring.factories)
   └─ 加载 ApplicationListener(从 spring.factories)
2. run() 主流程
   ├─ 启动监听器(SpringApplicationRunListeners.starting())
   ├─ 准备 Environment(读 application.yml / 命令行参数)
   ├─ 打印 Banner
   ├─ 创建 ApplicationContext
   ├─ ⭐ 刷新上下文 refreshContext()
   │  ├─ 加载 BeanDefinition
   │  ├─ ⭐ 自动装配(@EnableAutoConfiguration → spring.factories → AutoConfiguration 类)
   │  ├─ Bean 实例化 + 属性注入 + 初始化
   │  └─ 启动内嵌 Tomcat / Undertow
   ├─ 调用 CommandLineRunner / ApplicationRunner
   └─ 启动完成
```

### 4.3 ⭐⭐ 自动装配原理

#### Spring Boot 2.7-

```
@EnableAutoConfiguration
  ↓
AutoConfigurationImportSelector
  ↓
读 META-INF/spring.factories
  ↓
key = org.springframework.boot.autoconfigure.EnableAutoConfiguration
value = 各种 XxxAutoConfiguration 类全限定名(逗号分隔)
  ↓
按 @ConditionalOnXxx 决定哪些 AutoConfiguration 生效
```

#### Spring Boot 3.0+

`META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`(每行一个类名,**取代了 spring.factories**)

### 4.4 ⭐⭐ @ConditionalOnXxx 条件注解

| 注解 | 含义 |
|---|---|
| `@ConditionalOnClass` | classpath 有这个类才生效 |
| `@ConditionalOnMissingBean` | 容器没这个 Bean 才生效(给用户覆盖空间) |
| `@ConditionalOnProperty` | 配置项满足才生效 |
| `@ConditionalOnWebApplication` | 是 Web 应用才生效 |

### 4.5 🔗 结合你项目

ASP **@RedisLock 公共组件**就是用这套机制:
1. `RedisLockAutoConfiguration` 标 `@Configuration` + `@ConditionalOnClass(RedisTemplate.class)`
2. `META-INF/spring.factories` 注册它
3. 微服务**加依赖即可用**,不用任何配置

### 4.6 🎯 面试可讲

> "Spring Boot 启动核心是 @SpringBootApplication = @SpringBootConfiguration + @EnableAutoConfiguration + @ComponentScan。自动装配的核心是读 spring.factories(2.7-)或 AutoConfiguration.imports(3.0+),拿到一堆 AutoConfiguration 类,通过 @ConditionalOnClass / @ConditionalOnMissingBean 等条件注解决定生效与否。我们 ASP 的 @RedisLock 公共组件就用这套 —— 加依赖即可用。"

---

## 5. ⭐⭐ @Transactional 进阶 `[P6基线]` `[与PDF重叠]`📚

> PDF p.88-91 已经讲了 7 种传播 + 失效 9 场景,这里只补**底层 + 高级用法**:

### 5.1 底层 = AOP + TransactionInterceptor

```
@Transactional method() 调用
  ↓
TransactionInterceptor.invoke()
  ↓
1. PlatformTransactionManager.getTransaction()  ← 开启事务(获取 Connection,setAutoCommit(false))
2. method.invoke()                              ← 执行业务
3a. 成功 → commit
3b. RuntimeException → rollback
3c. checked Exception → 默认 commit(⚠️ 坑)
```

### 5.2 ⭐ 7 种传播级别(快速记忆)

| 级别 | 父无事务 | 父有事务 |
|---|---|---|
| **REQUIRED** (默认) | 新建 | 加入 |
| **REQUIRES_NEW** | 新建 | **挂起父 + 新建** |
| **NESTED** | 新建 | **嵌套 savepoint** |
| **SUPPORTS** | 不开 | 加入 |
| **NOT_SUPPORTED** | 不开 | **挂起父 + 不开** |
| **MANDATORY** | 抛异常 | 加入 |
| **NEVER** | 不开 | 抛异常 |

### 5.3 ⭐⭐ NESTED vs REQUIRES_NEW

| 维度 | NESTED | REQUIRES_NEW |
|---|---|---|
| 父子关系 | **子是父的 savepoint** | **完全独立** |
| 子失败 | 回滚到 savepoint(父继续) | 不影响父 |
| 父失败 | **子也回滚** | **子不回滚**(已提交) |
| 实现 | 单 Connection + savepoint | 多 Connection |

### 5.4 ⭐ 失效场景(背 6 个就够)

1. **方法非 public**(AOP 限制)
2. **类内 self-invocation**(走的是 raw bean)
3. **方法 final / static**(CGLIB 不能代理)
4. **抛 checked Exception 默认不回滚**(要 `rollbackFor = Exception.class`)
5. **try-catch 吞掉异常**(没异常 → 提交)
6. **多线程**(子线程没事务上下文)

### 5.5 🔗 结合你项目

ASP 的 @RedisLock + @Transactional 协作设计 → 锁在事务外(`@Order(HIGHEST_PRECEDENCE)`),详见 [`projects/asp-platform.md` §4.4.1](../../_curated/projects/asp-platform.md#441--为什么-orderhighest_precedence锁在事务外)

---

## 6. ⭐ Spring 中其他常考点(快速过)`[P7加分]`

### 6.1 `@Value` 注入时机
- 普通 @Value:Bean 实例化时注入
- `@Value("${...:default}")` 支持默认值
- 配置中心动态刷新需要 `@RefreshScope`(Spring Cloud Config / Nacos)

### 6.2 `@PostConstruct` vs `InitializingBean.afterPropertiesSet()` vs `init-method`

执行顺序:`@PostConstruct` → `afterPropertiesSet()` → `init-method`

### 6.3 `@Order` / `Ordered`

- 控制 Bean / 切面 / Filter 的执行顺序
- 数字越**小**越**先**(HIGHEST_PRECEDENCE = Integer.MIN_VALUE)
- 🔗 你 ASP @RedisLock 用 `@Order(HIGHEST_PRECEDENCE)`

### 6.4 ApplicationContext 相关接口家族

| 接口 | 作用 |
|---|---|
| `BeanFactory` | IOC 最基础 |
| `ApplicationContext` | 加上事件发布 / 国际化 / 资源加载 |
| `ConfigurableApplicationContext` | 加上配置 / 关闭能力 |
| `WebApplicationContext` | Web 环境 |

### 6.5 Spring 事件机制 `[ROI高]`💎

```java
// 发布
applicationEventPublisher.publishEvent(new MyEvent(this, data));

// 订阅
@EventListener
public void onMyEvent(MyEvent event) { ... }

// 异步订阅(需要 @EnableAsync)
@Async @EventListener
public void onMyEventAsync(MyEvent event) { ... }
```

🔗 **结合你项目**:**SI Zero Engine 的"信号变化通知 → 多观察者"** = 典型的 ApplicationEvent 用法;**PI 4.0 重构里你也提到用 Spring Event 替换 Hazelcast ITopic**

---

## 7. 🎯 面试题清单(本文覆盖)

| # | 题 | 答案位置 |
|---|---|---|
| 1 | Bean 生命周期 7 步 | §1 |
| 2 | 循环依赖三级缓存 + 为什么 3 级 | §2.4.1 |
| 3 | 哪些循环依赖解不了 | §2.4.2 |
| 4 | JDK 动态代理 vs CGLIB | §3.1 |
| 5 | self-invocation 为什么失效 | §3.5 |
| 6 | @SpringBootApplication 拆开 | §4.1 |
| 7 | 自动装配原理 spring.factories | §4.3 |
| 8 | @ConditionalOnXxx | §4.4 |
| 9 | 7 种传播级别 / NESTED vs REQUIRES_NEW | §5.2 / §5.3 |
| 10 | @Transactional 失效 6 场景 | §5.4 |

---

## 8. 推荐资源

| 资源 | 备注 |
|---|---|
| **Spring 官方文档** | https://docs.spring.io/spring-framework/docs/current/reference/html/ |
| **小马哥的 Spring 视频(B 站)** | 国内讲得最深的之一 |
| **《Spring 揭秘》** 王福强 | 老书但经典,讲底层 |
| **Spring Framework 源码** | 直接读 `AbstractApplicationContext.refresh()` |

---

---

## 附录 A. 实战零碎笔记(原 `origin/spring/notes.md`)

> 以下内容来自用户在 SI 项目中的实战笔记,2026-05-11 合并。

### A.1 用 `ApplicationEvent` 实现观察者模式

- 自定义事件 → 继承 `ApplicationEvent`
- 发布 → `ApplicationEventPublisher#publishEvent`
- 监听 → `@EventListener` 或 `ApplicationListener<XxxEvent>`
- 异步 → 监听方法上加 `@Async` + 全局 `@EnableAsync`

> 项目里用过:见 SI 内 mtp-core 的事件总线相关章节。

### A.2 Bean 加载顺序

- 单纯按"声明顺序"是错的;真实顺序由依赖关系 + `@DependsOn` + `BeanFactoryPostProcessor` 决定
- 强制顺序:`@DependsOn("xxx")` / 实现 `Ordered` 接口或 `@Order`
- 完整生命周期 → 本文 §1

### A.3 Servlet 容器因启动顺序拿不到 Spring Bean

- 典型场景:Filter / Listener 在 `web.xml` / Servlet 初始化时,Spring 还没起完
- 解法:
  - 用 `DelegatingFilterProxy` 把 Filter 注册到 Spring 上下文中
  - 或在 Filter 里 `WebApplicationContextUtils.getRequiredWebApplicationContext()` 懒加载
  - SpringBoot:用 `FilterRegistrationBean`,顺序由 `setOrder` 控制

### A.4 用 `AntPathMatcher` 自定义请求匹配

```java
AntPathMatcher matcher = new AntPathMatcher();
matcher.match("/api/**", request.getRequestURI());
```

- 一次请求到 Controller 的完整链路:`DispatcherServlet#doDispatch` → `HandlerMapping#getHandler` → `HandlerAdapter#handle` → 反射调用 Controller 方法

---

> 📌 **下一步**:[`mysql-deep-dive.md`](../database/mysql-deep-dive.md) → InnoDB 锁 / MVCC / 主从
