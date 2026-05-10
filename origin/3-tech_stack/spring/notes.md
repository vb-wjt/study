<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

# Spring 实战零碎笔记

> 自己工作中遇到、值得回头深究的 Spring 关注点(原 `business/SI/task/待整理知识.md`)。
> 凡是已被深度文档覆盖的,直接给出链接,本文件只保留"我自己关注的角度"。

## 1. 用 `ApplicationEvent` 实现观察者模式

- 自定义事件 → 继承 `ApplicationEvent`
- 发布 → `ApplicationEventPublisher#publishEvent`
- 监听 → `@EventListener` 或 `ApplicationListener<XxxEvent>`
- 异步 → 监听方法上加 `@Async` + 全局 `@EnableAsync`

> 项目里用过吗:见 SI 内 `mtp-core` 的事件总线相关章节(`_curated/projects/mtp-core-framework.md`),那里的 EventBus 实现思路类似。

## 2. Spring 初始化过程中的 Bean 加载顺序

- 单纯按"声明顺序"是错的;真实顺序由依赖关系 + `@DependsOn` + `BeanFactoryPostProcessor` 决定
- 强制顺序:`@DependsOn("xxx")` / 实现 `Ordered` 接口或 `@Order`
- **完整生命周期** → [`_curated/tech-stack/spring-internals.md §1`](../../../_curated/tech-stack/spring-internals.md)

## 3. Servlet 容器因启动顺序拿不到 Spring 容器里的 Bean

- 典型场景:Filter / Listener 在 `web.xml` / Servlet 初始化时,Spring 还没起完
- 解法:
  - 用 `DelegatingFilterProxy` 把 Filter 注册到 Spring 上下文中,真正的 Filter Bean 由 Spring 管理
  - 或在 Filter 里 `WebApplicationContextUtils.getRequiredWebApplicationContext()` 懒加载
  - SpringBoot 时代:用 `FilterRegistrationBean` 注册,顺序由 `setOrder` 控制

## 4. 用 `AntPathMatcher` 自定义请求匹配(权限/公开 API 放行)

```java
AntPathMatcher matcher = new AntPathMatcher();
matcher.match("/api/**", request.getRequestURI());
```

- 父类 `RequestMappingHandlerMapping` 在 `lookupHandlerMethod` 里就是用 `AntPathMatcher` 匹 `@RequestMapping` 路径
- **一次请求到 Controller 的完整链路**:`DispatcherServlet#doDispatch` → `HandlerMapping#getHandler` → `HandlerAdapter#handle` → 反射调用 Controller 方法
- 详细原理 → [`file/3-tech_stack/java-study.md §3-3 Spring MVC 工作原理`](../java-study.md)

---

## 同主题深度材料一览

| 想知道什么 | 看哪 |
|---|---|
| Bean 生命周期 7 步 + AOP 织入时机 | `_curated/tech-stack/spring-internals.md §1` |
| 循环依赖 / 三级缓存 | `_curated/tech-stack/spring-internals.md §2` |
| AOP 实现(JDK/CGLIB)+ 自调用陷阱 | `_curated/tech-stack/spring-internals.md §3` |
| Spring Boot 启动 + 自动装配 | `_curated/tech-stack/spring-internals.md §4` |
| `@Transactional` 7 种传播 + 失效场景 | `_curated/tech-stack/spring-internals.md §5` |
| Spring MVC 工作原理 / 注解 | `file/3-tech_stack/java-study.md §3-3` |
| MyBatis 工作原理 / 分页 | `file/3-tech_stack/java-study.md §3-3` |
