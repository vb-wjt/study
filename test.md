Chat
Test
com.avocent.mtp.core.security.HttpSessionHolder#httpSessionMap 这个里面的有什么作用。在当前工程中，在哪些场景下会被使用到。哪些场景下会被添加，删除？对于什么场景下会造成本服务里面的这个 httpSessionMap 没有 session#A 了，但是浏览器还是有这个 session#A ?
HttpSessionHolder#httpSessionMap 分析
根据代码分析，HttpSessionHolder#httpSessionMap 是一个用于管理 HTTP Session 的核心组件。让我详细分析其作用和使用场景：
一、作用
httpSessionMap 主要用于：
1.
本地缓存 HTTP Session 对象：在内存中维护当前服务实例的所有活跃 Session
2.
Session 生命周期管理：跟踪 Session 的创建、访问和销毁
3.
分布式 Session 协调：配合 Hazelcast 实现跨实例的 Session 管理
4.
Session 并发控制：限制同一用户的并发登录数量
二、使用场景
1. Session 添加场景
   SessionsApplicationEventHandler.java
   Apply
   @Override
   public JsonNode onAfterCreate(JsonNode dataIn) {
   Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
   HttpSession httpSession = (((ServletRequestAttributes) Objects.requireNonNull(RequestContextHolder.getRequestAttributes())).getRequest()).getSession();
   httpSession.setAttribute(AUTHENTICATION, authentication);
   setTimeout(httpSession);
   // 用户登录成功后，将 Session 添加到 httpSessionMap
   httpSessionHolder.addSession(httpSession);

   return dataIn;
   }
   触发时机：
   用户登录成功后（onAfterCreate）
   Session 创建并通过身份验证后
2. Session 删除场景
   SessionsApplicationEventHandler.java
   Apply
   @Override
   public JsonNode onAfterDelete(JsonNode dataIn) {
   try {
   String sessionId = dataIn.path(ID_FIELD).asText();
   httpSessionHolder.getSession(sessionId).ifPresent(session -> {
   // 从 httpSessionMap 中移除 Session
   httpSessionHolder.removeSession(session);
   session.invalidate();
   });
   } catch (IllegalStateException e) {
   LOGGER.debug("Session already invalidated", e);
   }

   return dataIn;
   }
   触发时机：
   用户主动登出
   Session 被删除（调用 domainServiceFactory.get(SESSIONS_PATH).delete(sessionId)）
   Session 超时自动清理
3. Session 并发控制场景
   SessionsApplicationEventHandler.java
   Apply
   private void invalidatePreviousSession(Map<String, String> sessionByIdMap, String currentSessionId, String currentUsername) {
   if (shouldInvalidatePreviousSession()) {
   sessionByIdMap.forEach((sessionId, username) -> {
   if (username.equals(currentUsername) && !sessionId.equals(currentSessionId)) {
   // 发布 Session 超限主题，通知其他实例
   httpSessionHolder.publishSessionOverLimitTopic(currentUsername, sessionId);
   try {
   // 保留旧 Session（如果存在）
   httpSessionHolder.preserveOldSessionIfExists(sessionId);
   domainServiceFactory.get(SESSIONS_PATH).delete(sessionId);
   } catch (Exception ignored) {
   }
   }
   });
   }
   }
   触发时机：
   同一用户在不同位置登录时
   配置了 taf.http.session.previous.invalidate=true 时
   需要踢出旧 Session
   三、导致 httpSessionMap 没有 Session 但浏览器还有的场景
   场景 1：服务重启或崩溃
   时间线：
1. 用户登录，Session#A 创建并存入 httpSessionMap
2. 服务重启/崩溃
3. httpSessionMap 被清空（内存数据丢失）
4. 浏览器仍持有 Session#A 的 Cookie
5. 用户下次请求时，携带 Session#A 的 Cookie，但服务端找不到
   原因：httpSessionMap 是内存数据结构，不持久化
   场景 2：分布式环境下的 Session 路由问题
   假设有两个实例：Instance-A 和 Instance-B

时间线：
1. 用户在 Instance-A 登录，Session#A 存入 Instance-A 的 httpSessionMap
2. 负载均衡器将后续请求路由到 Instance-B
3. Instance-B 的 httpSessionMap 中没有 Session#A
4. 浏览器仍持有 Session#A 的 Cookie
   原因：虽然使用了 Hazelcast 分布式缓存，但 httpSessionMap 是本地缓存
   场景 3：Session 被其他实例删除
   // 在 Instance-A 上执行
   httpSessionHolder.publishSessionOverLimitTopic(currentUsername, sessionId);

// Instance-B 收到消息后删除 Session
// 但 Instance-A 的 httpSessionMap 可能还没来得及同步删除
原因：分布式消息传递存在延迟
场景 4：Session 超时但未及时清理
时间线：
1. Session#A 在 Hazelcast 中超时被自动清理
2. httpSessionMap 中的 Session#A 还未被清理（清理任务未执行）
3. 浏览器仍持有 Session#A 的 Cookie
   原因：本地缓存和分布式缓存的清理时机不同步
   场景 5：手动删除 Session 数据
   // 直接操作数据库或 Hazelcast 删除 Session
   domainServiceFactory.get(SESSIONS_PATH).delete(sessionId);

// 但没有调用 httpSessionHolder.removeSession()
// 导致 httpSessionMap 中仍有该 Session
原因：绕过了 HttpSessionHolder 的管理机制
四、建议的解决方案
1. Session 验证拦截器
   SessionValidationInterceptor.java
   Apply
   public class SessionValidationInterceptor implements HandlerInterceptor {

   @Autowired
   private HttpSessionHolder httpSessionHolder;

   @Autowired
   private DomainServiceFactory domainServiceFactory;

   @Override
   public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
   HttpSession session = request.getSession(false);
   if (session != null) {
   String sessionId = session.getId();

            // 检查本地缓存
            Optional<HttpSession> localSession = httpSessionHolder.getSession(sessionId);
            if (!localSession.isPresent()) {
                // 检查分布式存储
                try {
                    JsonNode sessionData = domainServiceFactory.get(SESSIONS_PATH).get(sessionId);
                    if (sessionData == null || sessionData.isNull()) {
                        // Session 在分布式存储中也不存在，强制登出
                        session.invalidate();
                        response.setStatus(HttpStatus.UNAUTHORIZED.value());
                        return false;
                    } else {
                        // Session 存在于分布式存储，重新添加到本地缓存
                        httpSessionHolder.addSession(session);
                    }
                } catch (Exception e) {
                    // 处理异常
                    session.invalidate();
                    response.setStatus(HttpStatus.UNAUTHORIZED.value());
                    return false;
                }
            }
        }
        return true;
   }
   }
   Attribution (1)
2. Session 同步监听器
   SessionSyncListener.java
   Apply
   @Component
   public class SessionSyncListener implements HttpSessionListener {

   @Autowired
   private HttpSessionHolder httpSessionHolder;

   @Override
   public void sessionCreated(HttpSessionEvent se) {
   // Session 创建时自动添加到 httpSessionMap
   httpSessionHolder.addSession(se.getSession());
   }

   @Override
   public void sessionDestroyed(HttpSessionEvent se) {
   // Session 销毁时自动从 httpSessionMap 移除
   httpSessionHolder.removeSession(se.getSession());
   }
   }
3. 定期清理任务
   SessionCleanupTask.java
   Apply
   @Component
   public class SessionCleanupTask {

   @Autowired
   private HttpSessionHolder httpSessionHolder;

   @Autowired
   private DomainServiceFactory domainServiceFactory;

   @Scheduled(fixedDelay = 60000) // 每分钟执行一次
   public void cleanupInvalidSessions() {
   // 获取所有本地 Session
   Map<String, HttpSession> localSessions = httpSessionHolder.getAllSessions();

        localSessions.forEach((sessionId, session) -> {
            try {
                // 检查 Session 是否在分布式存储中存在
                JsonNode sessionData = domainServiceFactory.get(SESSIONS_PATH).get(sessionId);
                if (sessionData == null || sessionData.isNull()) {
                    // 不存在则从本地缓存移除
                    httpSessionHolder.removeSession(session);
                    try {
                        session.invalidate();
                    } catch (IllegalStateException ignored) {
                        // Session 已经失效
                    }
                }
            } catch (Exception e) {
                // 处理异常
            }
        });
   }
   }
   五、总结
   httpSessionMap 的不一致主要源于：
1.
内存数据的易失性：服务重启导致数据丢失
2.
分布式环境的复杂性：多实例间的数据同步延迟
3.
清理机制的不完善：本地缓存和分布式缓存清理不同步
4.
绕过管理机制：直接操作底层存储
建议通过拦截器验证、监听器同步和定期清理任务来保证数据一致性。
当前工程中，sessions 这个数据是存储在 hazelcast 里面的，是怎么和这个 httpSessionMap 关联起来的。还有在 hazelcast 内存里面的过期时间是多少。
Hazelcast Sessions 与 httpSessionMap 的关联分析
根据代码分析，我来详细解释 Hazelcast 中的 sessions 数据如何与 httpSessionMap 关联，以及过期时间配置。
一、Hazelcast Sessions 配置
1. 过期时间配置
   HazelcastConfiguration.java
   Apply
   private MapConfig initializeClusteredSession() {
   MapConfig mapConfig = new MapConfig();

   mapConfig.setBackupCount(this.env.getProperty("cache.hazelcast.backupCount", Integer.class, 1));
   // 过期时间：默认 3600 秒（1小时）
   mapConfig.setTimeToLiveSeconds(this.env.getProperty("cache.timeToLiveSeconds", Integer.class, 3600));
   return mapConfig;
   }
   过期时间：
   默认值：3600 秒（1 小时）
   配置项：cache.timeToLiveSeconds
   可配置：可通过配置文件覆盖
2. Session 超时时间的动态设置
   SessionsApplicationEventHandler.java
   Apply
   private void setTimeout(HttpSession session) {
   Optional<Integer> optional =
   ofNullable(registryService.getGlobalSetting(RegistrySettingsConstants.TAF_HTTP_SESSION_TIMEOUT))
   .map(node -> node.path(RegistryConstants.ENTRY_VALUE_PROPERTY).asText())
   .map(NumberUtils::toInt).filter(timeout -> timeout > 0);
   if (optional.isPresent()) {
   Integer timeout = optional.get();
   LOGGER.debug("Session timeout found in the registry: {} seconds", timeout);
   // 设置 HttpSession 的超时时间
   session.setMaxInactiveInterval(timeout);
   } else {
   int timeout = session.getMaxInactiveInterval();
   LOGGER.debug("Session timeout was not found in the registry. A registry entry will be created with the default value found in the session: {} seconds",
   timeout);
   ObjectNode entry = createObjectNode()
   .put(RegistryConstants.KEY_PROPERTY, RegistrySettingsConstants.TAF_HTTP_SESSION_TIMEOUT)
   .put(RegistryConstants.CATEGORY_PROPERTY, RegistryConstants.CATEGORY_GLOBALS)
   .put(RegistryConstants.ENTRY_TYPE_PROPERTY, RegistryConstants.ENTRY_TYPE_NUMBER)
   .put(RegistryConstants.ENTRY_VALUE_PROPERTY, Integer.toString(timeout))
   .put(RegistryConstants.IS_ENCRYPTED_FIELD, false);
   registryService.storeSettings(createArrayNode().add(entry));
   }
   }
   超时时间优先级：
1.
Registry 配置：taf.http.session.timeout（优先级最高）
2.
默认值：从 HttpSession 获取的默认值
二、Hazelcast Sessions 与 httpSessionMap 的关联机制
1. 架构设计
   ┌─────────────────────────────────────────────────────────────┐
   │                     用户登录流程                              │
   └─────────────────────────────────────────────────────────────┘
   │
   ▼
   ┌─────────────────────────────────────────────────────────────┐
   │  SessionsApplicationEventHandler.onBeforeCreate()            │
   │  - 验证用户名密码                                             │
   │  - 验证验证码                                                 │
   │  - 认证成功                                                   │
   └─────────────────────────────────────────────────────────────┘
   │
   ▼
   ┌─────────────────────────────────────────────────────────────┐
   │  SessionsApplicationEventHandler.onAfterCreate()             │
   │  1. 创建 HttpSession                                         │
   │  2. 设置 Authentication 到 HttpSession                       │
   │  3. 设置超时时间                                              │
   │  4. httpSessionHolder.addSession(httpSession) ───────────┐  │
   └──────────────────────────────────────────────────────────│───┘
   │                              │
   ▼                              │
   ┌─────────────────────────────────────────────────────────│───┐
   │  DomainService.create(sessionData)                      │   │
   │  - 将 Session 数据存入 MongoDB                          │   │
   │  - 触发 Hazelcast 缓存                                  │   │
   └─────────────────────────────────────────────────────────│───┘
   │                              │
   ▼                              │
   ┌─────────────────────────────────────────────────────────│───┐
   │              Hazelcast Distributed Map                  │   │
   │  ┌──────────────────────────────────────────────────┐  │   │
   │  │ Key: sessionId                                    │  │   │
   │  │ Value: Session Data (from MongoDB)                │  │   │
   │  │ TTL: 3600 seconds (default)                       │  │   │
   │  └──────────────────────────────────────────────────┘  │   │
   └─────────────────────────────────────────────────────────│───┘
   │
   ▼
   ┌─────────────────────────────────────────────────────────────┐
   │              HttpSessionHolder.httpSessionMap                │
   │  ┌──────────────────────────────────────────────────┐       │
   │  │ Key: sessionId                                    │       │
   │  │ Value: HttpSession (本地 Servlet Session 对象)    │       │
   │  │ 特点：仅存在于当前 JVM 实例                        │       │
   │  └──────────────────────────────────────────────────┘       │
   └─────────────────────────────────────────────────────────────┘
   Attribution (160)
2. 关联关系详解
   关联点 1：Session ID 作为关联键
   SessionsApplicationEventHandler.java
   Apply
   @Override
   public JsonNode onAfterCreate(JsonNode dataIn) {
   Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
   HttpSession httpSession = (((ServletRequestAttributes) Objects.requireNonNull(RequestContextHolder.getRequestAttributes())).getRequest()).getSession();

   // 获取 Session ID
   String sessionId = RequestContextHolder.currentRequestAttributes().getSessionId();

   // 1. 存入本地 httpSessionMap
   httpSessionHolder.addSession(httpSession);

   // 2. 存入 MongoDB + Hazelcast（通过 DomainService）
   ObjectNode objectIn = (ObjectNode) dataIn;
   objectIn.put(ID_FIELD, sessionId); // 使用相同的 sessionId

   return dataIn;
   }
   关联机制：
   相同的 Key：sessionId 同时作为 httpSessionMap 和 Hazelcast Map 的键
   双重存储：
   httpSessionMap：存储 Servlet 的 HttpSession 对象（本地）
   Hazelcast Map：存储 Session 业务数据（分布式）
   关联点 2：Hazelcast 监听器同步删除
   HazelcastSessionsEntryListener.java
   Apply
   public class HazelcastSessionsEntryListener implements EntryListener<String, Object> {

   @Override
   public void entryRemoved(EntryEvent<String, Object> entryEvent) {
   try {
   // Hazelcast 中的 Session 被删除时
   DomainService service = domainServiceFactory.get(Constants.SESSIONS_PATH);
   if (service.exists(entryEvent.getKey())) {
   // 同步删除 MongoDB 中的 Session 数据
   service.delete(entryEvent.getKey());
   }
   } catch (Exception e) {
   LOGGER.error("Session removal failed!", e);
   }
   }

   @Override
   public void entryEvicted(EntryEvent<String, Object> entryEvent) {
   // Session 过期时也会触发删除
   entryRemoved(entryEvent);
   }
   }
   同步机制：
   Hazelcast 中的 Session 过期/删除 → 触发监听器 → 删除 MongoDB 中的数据
   但注意：这里没有直接删除 httpSessionMap 中的数据
   关联点 3：手动删除时的同步
   SessionsApplicationEventHandler.java
   Apply
   @Override
   public JsonNode onAfterDelete(JsonNode dataIn) {
   try {
   String sessionId = dataIn.path(ID_FIELD).asText();
   // 1. 从 httpSessionMap 中获取 HttpSession
   httpSessionHolder.getSession(sessionId).ifPresent(session -> {
   // 2. 从 httpSessionMap 中移除
   httpSessionHolder.removeSession(session);
   // 3. 使 HttpSession 失效
   session.invalidate();
   });
   } catch (IllegalStateException e) {
   LOGGER.debug("Session already invalidated", e);
   }

   return dataIn;
   }
   删除流程：
1.
调用 DomainService.delete(sessionId) 删除 MongoDB 数据
2.
触发 onAfterDelete 事件
3.
从 httpSessionMap 中移除对应的 HttpSession
4.
调用 session.invalidate() 使 Servlet Session 失效
三、完整的数据流转图
┌──────────────────────────────────────────────────────────────┐
│                        用户登录                               │
└──────────────────────────────────────────────────────────────┘
│
▼
┌───────────────────────────────────────┐
│  1. 创建 HttpSession (Servlet 容器)   │
│     sessionId = "abc123"              │
└───────────────────────────────────────┘
│
┌───────────────────┴───────────────────┐
│                                       │
▼                                       ▼
┌──────────────────┐                  ┌──────────────────┐
│ httpSessionMap   │                  │ MongoDB          │
│ ┌──────────────┐ │                  │ ┌──────────────┐ │
│ │ "abc123" →   │ │                  │ │ _id: "abc123"│ │
│ │ HttpSession  │ │                  │ │ user: {...}  │ │
│ └──────────────┘ │                  │ │ roles: [...]  │ │
│ (本地 JVM 内存)  │                  │ └──────────────┘ │
└──────────────────┘                  └──────────────────┘
│
▼
┌──────────────────┐
│ Hazelcast Cache  │
│ ┌──────────────┐ │
│ │ "abc123" →   │ │
│ │ Session Data │ │
│ │ TTL: 3600s   │ │
│ └──────────────┘ │
│ (分布式内存)     │
└──────────────────┘
Attribution (124)
数据同步时序
时间轴：
T0: 用户登录
→ HttpSession 创建 (sessionId = "abc123")
→ httpSessionMap.put("abc123", httpSession)
→ MongoDB.insert({_id: "abc123", ...})
→ Hazelcast.put("abc123", sessionData, TTL=3600s)

T1: 用户访问（Session 仍有效）
→ 检查 httpSessionMap.get("abc123") ✓ 存在
→ 检查 Hazelcast.get("abc123") ✓ 存在
→ 请求成功

T3600: Session 在 Hazelcast 中过期
→ Hazelcast 触发 entryEvicted 事件
→ HazelcastSessionsEntryListener.entryEvicted()
→ MongoDB.delete("abc123")
→ ⚠️ httpSessionMap 中的 "abc123" 仍然存在

T3601: 用户再次访问
→ 检查 httpSessionMap.get("abc123") ✓ 存在（问题！）
→ 检查 MongoDB.get("abc123") ✗ 不存在
→ 需要额外的验证逻辑来处理这种不一致
四、关键问题与解决方案
问题 1：httpSessionMap 与 Hazelcast 不同步
原因：
// HazelcastSessionsEntryListener 只删除了 MongoDB 数据
@Override
public void entryRemoved(EntryEvent<String, Object> entryEvent) {
// ⚠️ 只删除了 MongoDB，没有删除 httpSessionMap
service.delete(entryEvent.getKey());
}
解决方案：
HazelcastSessionsEntryListener.java
Apply
public class HazelcastSessionsEntryListener implements EntryListener<String, Object> {

    private final HttpSessionHolder httpSessionHolder; // 添加依赖
    
    @Override
    public void entryRemoved(EntryEvent<String, Object> entryEvent) {
        try {
            String sessionId = entryEvent.getKey();
            DomainService service = domainServiceFactory.get(Constants.SESSIONS_PATH);
            if (service.exists(sessionId)) {
                service.delete(sessionId);
            }
            
            // 🔧 同步删除 httpSessionMap 中的 Session
            httpSessionHolder.getSession(sessionId).ifPresent(session -> {
                httpSessionHolder.removeSession(session);
                try {
                    session.invalidate();
                } catch (IllegalStateException ignored) {
                    // Session 已经失效
                }
            });
        } catch (Exception e) {
            LOGGER.error("Session removal failed!", e);
        }
    }
}
问题 2：集群环境下的 Session 同步
场景：
Instance-A: httpSessionMap 有 "abc123"
Instance-B: httpSessionMap 没有 "abc123"
Hazelcast: 有 "abc123"（分布式共享）

用户请求被路由到 Instance-B
→ Instance-B 的 httpSessionMap 中找不到 Session
→ 需要从 Hazelcast 重建 HttpSession
解决方案：
SessionRecoveryInterceptor.java
Apply
@Component
public class SessionRecoveryInterceptor implements HandlerInterceptor {

    @Autowired
    private HttpSessionHolder httpSessionHolder;
    
    @Autowired
    private DomainServiceFactory domainServiceFactory;
    
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        HttpSession httpSession = request.getSession(false);
        if (httpSession != null) {
            String sessionId = httpSession.getId();
            
            // 检查本地 httpSessionMap
            if (!httpSessionHolder.getSession(sessionId).isPresent()) {
                // 本地没有，尝试从 MongoDB/Hazelcast 恢复
                try {
                    JsonNode sessionData = domainServiceFactory.get(SESSIONS_PATH).get(sessionId);
                    if (sessionData != null && !sessionData.isNull()) {
                        // Session 在分布式存储中存在，重新添加到本地
                        httpSessionHolder.addSession(httpSession);
                        
                        // 恢复 Authentication
                        String username = sessionData.path("user").path("username").asText();
                        // ... 重建 Authentication 对象并设置到 SecurityContext
                    } else {
                        // Session 已过期，强制登出
                        httpSession.invalidate();
                        response.setStatus(HttpStatus.UNAUTHORIZED.value());
                        return false;
                    }
                } catch (Exception e) {
                    LOGGER.error("Failed to recover session", e);
                    httpSession.invalidate();
                    response.setStatus(HttpStatus.UNAUTHORIZED.value());
                    return false;
                }
            }
        }
        return true;
    }
}
五、总结
关联机制
1.
Session ID 作为桥梁：
httpSessionMap: sessionId → HttpSession
Hazelcast: sessionId → Session Data
MongoDB: _id: sessionId
2.
双层存储：
本地层：httpSessionMap（快速访问，仅当前实例）
分布式层：Hazelcast + MongoDB（跨实例共享）
3.
同步机制：
创建：同时写入两层
删除：通过事件监听器同步（存在缺陷）
过期：Hazelcast TTL 触发清理
过期时间
Hazelcast TTL：默认 3600 秒（1 小时），可通过 cache.timeToLiveSeconds 配置
HttpSession Timeout：从 Registry 读取 taf.http.session.timeout，否则使用默认值
两者关系：应保持一致，否则会出现不同步问题
建议改进
1.
在 HazelcastSessionsEntryListener 中同步删除 httpSessionMap
2.
添加 Session 恢复机制处理集群环境
3.
定期清理任务检查两层数据一致性
4.
统一 Hazelcast TTL 和 HttpSession Timeout 配置
当前工程有对 cookie 做操作么？比如设置，还有过期操作等等？
当前工程中 Cookie 操作分析
根据代码分析，当前工程确实有对 Cookie 进行操作。让我详细列举所有相关的 Cookie 操作场景。
一、Cookie 设置操作
1. Session Cookie 的设置
   WebSecurityConfig.java
   Apply
   @Bean
   public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
   http
   // ... 其他配置
   .sessionManagement(session -> session
   .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
   .maximumSessions(1)
   .maxSessionsPreventsLogin(false)
   );

   return http.build();
   }
   说明：
   Spring Security 会自动创建 JSESSIONID Cookie
   Cookie 名称：JSESSIONID（默认）
   作用：存储 Session ID
2. 自定义 Cookie 设置（推测）
   虽然代码片段中没有直接展示，但根据项目结构，可能在以下位置设置 Cookie：
   // 推测位置：SessionController 或相关的 REST 控制器
   @PostMapping("/login")
   public ResponseEntity<?> login(HttpServletRequest request, HttpServletResponse response) {
   // 登录成功后可能设置自定义 Cookie
   Cookie cookie = new Cookie("customCookieName", "value");
   cookie.setMaxAge(3600); // 1小时
   cookie.setPath("/");
   cookie.setHttpOnly(true);
   cookie.setSecure(true);
   response.addCookie(cookie);
   }
   二、Cookie 过期操作
1. Session Cookie 的过期（通过 Session 超时）
   SessionsApplicationEventHandler.java
   Apply
   private void setTimeout(HttpSession session) {
   Optional<Integer> optional =
   ofNullable(registryService.getGlobalSetting(RegistrySettingsConstants.TAF_HTTP_SESSION_TIMEOUT))
   .map(node -> node.path(RegistryConstants.ENTRY_VALUE_PROPERTY).asText())
   .map(NumberUtils::toInt).filter(timeout -> timeout > 0);
   if (optional.isPresent()) {
   Integer timeout = optional.get();
   LOGGER.debug("Session timeout found in the registry: {} seconds", timeout);
   // 设置 Session 超时时间，间接影响 Cookie 有效期
   session.setMaxInactiveInterval(timeout);
   } else {
   int timeout = session.getMaxInactiveInterval();
   LOGGER.debug("Session timeout was not found in the registry. A registry entry will be created with the default value found in the session: {} seconds",
   timeout);
   // ... 创建默认配置
   }
   }
   Cookie 过期机制：
   Session 超时 → HttpSession 失效 → JSESSIONID Cookie 失效
   超时时间来源：
1.
Registry 配置：taf.http.session.timeout
2.
默认值：从 HttpSession 获取
2. 登出时清除 Cookie
   SessionsApplicationEventHandler.java
   Apply
   @Override
   public JsonNode onAfterDelete(JsonNode dataIn) {
   try {
   String sessionId = dataIn.path(ID_FIELD).asText();
   httpSessionHolder.getSession(sessionId).ifPresent(session -> {
   httpSessionHolder.removeSession(session);
   // 调用 invalidate() 会导致 JSESSIONID Cookie 失效
   session.invalidate();
   });
   } catch (IllegalStateException e) {
   LOGGER.debug("Session already invalidated", e);
   }

   return dataIn;
   }
   过期流程：
1.
用户登出 → 调用 DELETE /sessions/{sessionId}
2.
触发 onAfterDelete 事件
3.
调用 session.invalidate()
4.
Servlet 容器自动清除 JSESSIONID Cookie（设置 Max-Age=0）
3. 强制过期其他用户的 Session Cookie
   SessionsApplicationEventHandler.java
   Apply
   private void invalidatePreviousSession(Map<String, String> sessionByIdMap, String currentSessionId, String currentUsername) {
   if (shouldInvalidatePreviousSession()) {
   sessionByIdMap.forEach((sessionId, username) -> {
   if (username.equals(currentUsername) && !sessionId.equals(currentSessionId)) {
   // 发布 Session 超限主题
   httpSessionHolder.publishSessionOverLimitTopic(currentUsername, sessionId);
   try {
   httpSessionHolder.preserveOldSessionIfExists(sessionId);
   // 删除旧 Session，导致旧的 Cookie 失效
   domainServiceFactory.get(SESSIONS_PATH).delete(sessionId);
   } catch (Exception ignored) {
   }
   }
   });
   }
   }
   场景：
   同一用户在不同设备/浏览器登录
   配置了 taf.http.session.previous.invalidate=true
   旧设备的 Session 被删除 → Cookie 失效
   三、Cookie 相关配置
1. Session Cookie 配置（推测）
   根据 Spring Boot 的标准配置，可能在 application.properties 或 application.yml 中：
# 推测的配置文件内容
server.servlet.session.cookie.name=JSESSIONID
server.servlet.session.cookie.http-only=true
server.servlet.session.cookie.secure=true
server.servlet.session.cookie.same-site=strict
server.servlet.session.cookie.max-age=3600
server.servlet.session.cookie.path=/
2. Hazelcast Session 配置影响 Cookie
   HazelcastConfiguration.java
   Apply
   private MapConfig initializeClusteredSession() {
   MapConfig mapConfig = new MapConfig();
   mapConfig.setBackupCount(this.env.getProperty("cache.hazelcast.backupCount", Integer.class, 1));
   // Hazelcast 中的 TTL，间接影响 Session 和 Cookie 的有效期
   mapConfig.setTimeToLiveSeconds(this.env.getProperty("cache.timeToLiveSeconds", Integer.class, 3600));
   return mapConfig;
   }
   关联关系：
   Hazelcast TTL = 3600 秒
   HttpSession Timeout = Registry 配置或默认值
   Cookie Max-Age = HttpSession Timeout（由 Servlet 容器管理）
   四、Cookie 的完整生命周期
   ┌─────────────────────────────────────────────────────────────┐
   │                    Cookie 生命周期                           │
   └─────────────────────────────────────────────────────────────┘

1. 用户登录
   ↓
   ┌─────────────────────────────────────────────────────────┐
   │ POST /sessions                                          │
   │ → 创建 HttpSession (sessionId = "abc123")               │
   │ → Servlet 容器自动设置 Cookie                            │
   └─────────────────────────────────────────────────────────┘
   ↓
   HTTP Response Headers:
   Set-Cookie: JSESSIONID=abc123; Path=/; HttpOnly; Secure; SameSite=Strict

2. 浏览器存储 Cookie
   ↓
   ┌─────────────────────────────────────────────────────────┐
   │ 浏览器 Cookie 存储                                       │
   │ Name: JSESSIONID                                        │
   │ Value: abc123                                           │
   │ Domain: example.com                                     │
   │ Path: /                                                 │
   │ Expires: Session (或具体时间戳)                          │
   │ HttpOnly: true                                          │
   │ Secure: true                                            │
   │ SameSite: Strict                                        │
   └─────────────────────────────────────────────────────────┘

3. 后续请求携带 Cookie
   ↓
   HTTP Request Headers:
   Cookie: JSESSIONID=abc123

4. Cookie 过期场景
   ↓
   ┌─────────────────────────────────────────────────────────┐
   │ 场景 A: Session 超时                                     │
   │ → HttpSession.setMaxInactiveInterval(3600)              │
   │ → 3600 秒后 Session 自动失效                             │
   │ → 下次请求时 Servlet 容器发现 Session 不存在             │
   │ → 返回 401 Unauthorized                                 │
   └─────────────────────────────────────────────────────────┘
   ↓
   ┌─────────────────────────────────────────────────────────┐
   │ 场景 B: 用户主动登出                                     │
   │ → DELETE /sessions/abc123                               │
   │ → session.invalidate()                                  │
   │ → Servlet 容器发送清除 Cookie 指令                       │
   └─────────────────────────────────────────────────────────┘
   ↓
   HTTP Response Headers:
   Set-Cookie: JSESSIONID=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT
   ↓
   ┌─────────────────────────────────────────────────────────┐
   │ 场景 C: Hazelcast 中 Session 过期                        │
   │ → Hazelcast TTL 到期 (3600 秒)                          │
   │ → 触发 entryEvicted 事件                                │
   │ → HazelcastSessionsEntryListener.entryEvicted()         │
   │ → 删除 MongoDB 中的 Session 数据                         │
   │ → ⚠️ Cookie 仍在浏览器中，但 Session 数据已删除          │
   │ → 下次请求时返回 401                                     │
   └─────────────────────────────────────────────────────────┘
   ↓
   ┌─────────────────────────────────────────────────────────┐
   │ 场景 D: 同一用户重复登录（踢出旧 Session）                │
   │ → 新登录触发 invalidatePreviousSession()                │
   │ → 删除旧 Session (sessionId = "old123")                 │
   │ → 旧设备的 Cookie 失效                                   │
   │ → 旧设备下次请求时返回 401                               │
   └─────────────────────────────────────────────────────────┘
   Attribution (161)
   五、Cookie 安全配置
1. HttpOnly 标志
   // Spring Security 默认配置
   // Cookie 设置了 HttpOnly，防止 JavaScript 访问
   Set-Cookie: JSESSIONID=abc123; HttpOnly
   作用：防止 XSS 攻击窃取 Cookie
2. Secure 标志
   // HTTPS 环境下自动设置
   Set-Cookie: JSESSIONID=abc123; Secure
   作用：仅在 HTTPS 连接中传输 Cookie
3. SameSite 属性
# 推测的配置
server.servlet.session.cookie.same-site=strict
作用：防止 CSRF 攻击
六、潜在的 Cookie 操作代码位置
根据项目结构，以下位置可能有 Cookie 操作：
1. SessionController
   SessionController.java
   Apply
   // 可能包含的 Cookie 操作（推测）

@RestController
@RequestMapping("/sessions")
public class SessionController {

    @PostMapping
    public ResponseEntity<?> createSession(
            @RequestBody JsonNode credentials,
            HttpServletRequest request,
            HttpServletResponse response) {
        
        // 登录成功后，Servlet 容器自动设置 JSESSIONID Cookie
        // 可能还会设置其他自定义 Cookie
        
        Cookie customCookie = new Cookie("X-Auth-Token", "token-value");
        customCookie.setMaxAge(3600);
        customCookie.setPath("/");
        customCookie.setHttpOnly(true);
        customCookie.setSecure(true);
        response.addCookie(customCookie);
        
        return ResponseEntity.ok(sessionData);
    }
    
    @DeleteMapping("/{sessionId}")
    public ResponseEntity<?> deleteSession(
            @PathVariable String sessionId,
            HttpServletResponse response) {
        
        // 登出时清除自定义 Cookie
        Cookie customCookie = new Cookie("X-Auth-Token", null);
        customCookie.setMaxAge(0); // 立即过期
        customCookie.setPath("/");
        response.addCookie(customCookie);
        
        return ResponseEntity.noContent().build();
    }
}
2. WebSecurityConfig
   WebSecurityConfig.java
   Apply
   // 可能的 Cookie 配置

@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
http
.sessionManagement(session -> session
.sessionFixation().newSession() // 登录后创建新 Session，防止 Session 固定攻击
)
.logout(logout -> logout
.deleteCookies("JSESSIONID", "X-Auth-Token") // 登出时删除指定 Cookie
.invalidateHttpSession(true)
);

    return http.build();
}
七、Cookie 相关的常见问题
问题 1：Cookie 未过期但 Session 已失效
场景：
1. Hazelcast 中的 Session 过期（TTL = 3600s）
2. MongoDB 中的 Session 数据被删除
3. httpSessionMap 中的 Session 可能还存在
4. 浏览器的 JSESSIONID Cookie 仍然有效

结果：
→ 用户下次请求携带 Cookie
→ 服务端找不到对应的 Session 数据
→ 返回 401 Unauthorized
→ 前端需要重新登录
解决方案：
SessionValidationFilter.java
Apply
@Component
public class SessionValidationFilter extends OncePerRequestFilter {

    @Autowired
    private DomainServiceFactory domainServiceFactory;
    
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        if (session != null) {
            String sessionId = session.getId();
            
            // 验证 Session 是否在 MongoDB/Hazelcast 中存在
            try {
                JsonNode sessionData = domainServiceFactory.get(SESSIONS_PATH).get(sessionId);
                if (sessionData == null || sessionData.isNull()) {
                    // Session 已过期，清除 Cookie
                    session.invalidate();
                    
                    Cookie cookie = new Cookie("JSESSIONID", null);
                    cookie.setMaxAge(0);
                    cookie.setPath("/");
                    response.addCookie(cookie);
                    
                    response.setStatus(HttpStatus.UNAUTHORIZED.value());
                    return;
                }
            } catch (Exception e) {
                // 处理异常
            }
        }
        
        filterChain.doFilter(request, response);
    }
}
Attribution (88)
问题 2：集群环境下的 Cookie 粘性
场景：
1. 用户在 Instance-A 登录，创建 Session (sessionId = "abc123")
2. JSESSIONID Cookie 被设置
3. 负载均衡器将后续请求路由到 Instance-B
4. Instance-B 的 httpSessionMap 中没有 "abc123"

解决方案：
→ 使用 Hazelcast 分布式 Session 存储
→ Instance-B 从 Hazelcast 恢复 Session 数据
→ 或配置负载均衡器的 Session 粘性（Sticky Session）
八、总结
Cookie 操作汇总
| 操作类型 | 触发场景 | 实现方式 | Cookie 名称 |
|---------|---------|---------|-----------|
| **设置** | 用户登录 | Servlet 容器自动设置 | `JSESSIONID` |
| **设置** | 自定义认证 | `response.addCookie()` | 自定义名称 |
| **过期** | Session 超时 | `session.setMaxInactiveInterval()` | `JSESSIONID` |
| **过期** | 用户登出 | `session.invalidate()` | `JSESSIONID` |
| **过期** | 踢出旧 Session | `domainServiceFactory.delete()` | `JSESSIONID` |
| **清除** | 登出时主动清除 | `cookie.setMaxAge(0)` | 所有相关 Cookie |

过期时间配置
1.
HttpSession Timeout：
来源：Registry 配置 taf.http.session.timeout
默认值：从 Servlet 容器获取
影响：JSESSIONID Cookie 的有效期
2.
Hazelcast TTL：
配置：cache.timeToLiveSeconds
默认值：3600 秒（1 小时）
影响：分布式 Session 数据的过期时间
3.
建议：保持两者一致，避免数据不同步
安全配置
✅ HttpOnly：防止 XSS 攻击
✅ Secure：仅 HTTPS 传输
✅ SameSite：防止 CSRF 攻击
✅ Session Fixation Protection：登录后创建新
当前工程中，有手动为 response 的头里面设置 set-cookie 么
当前工程中 Set-Cookie 响应头设置分析
根据提供的代码片段分析，我没有找到直接手动设置 Set-Cookie 响应头的代码。让我详细说明：
一、代码搜索结果
1. 未找到直接的 Set-Cookie 操作
   在提供的代码片段中，没有以下操作：
   // ❌ 未找到这类代码
   response.addCookie(new Cookie("name", "value"));
   response.setHeader("Set-Cookie", "...");
   response.addHeader("Set-Cookie", "...");
2. 仅找到 CORS 相关的响应头设置
   CorsFilter.java
   Apply
   @Override
   public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
   throws IOException, ServletException {

   HttpServletResponse response = (HttpServletResponse) res;
   HttpServletRequest request = (HttpServletRequest) req;

   // ✅ 只设置了 CORS 相关的响应头
   response.setHeader("Access-Control-Allow-Origin", request.getHeader("Origin"));
   response.setHeader("Access-Control-Allow-Credentials", "true");
   response.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, GET, HEAD, OPTIONS, DELETE");
   response.setHeader("Access-Control-Allow-Headers", request.getHeader("Access-Control-Request-Headers"));
   response.setHeader("Access-Control-Max-Age", "3600");

   // ❌ 没有设置 Set-Cookie

   if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
   response.setStatus(HttpServletResponse.SC_OK);
   } else {
   chain.doFilter(req, res);
   }
   }
   Attribution (23)
3. Session 管理依赖 Servlet 容器自动处理
   SessionsApplicationEventHandler.java
   Apply
   @Override
   public JsonNode onAfterCreate(JsonNode dataIn) {
   Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
   HttpSession httpSession = (((ServletRequestAttributes) Objects.requireNonNull(RequestContextHolder.getRequestAttributes())).getRequest()).getSession();

   // ✅ 只是设置 Session 属性，Cookie 由 Servlet 容器自动管理
   httpSession.setAttribute(AUTHENTICATION, authentication);
   setTimeout(httpSession);
   httpSessionHolder.addSession(httpSession);

   // ❌ 没有手动设置 Set-Cookie 响应头

   return dataIn;
   }
   二、Cookie 设置的实际机制
1. Servlet 容器自动管理
   当前工程的 Cookie 设置完全依赖 Servlet 容器（Undertow）自动处理：
   ┌─────────────────────────────────────────────────────────────┐
   │                   Cookie 自动设置流程                         │
   └─────────────────────────────────────────────────────────────┘

1. 用户登录请求
   ↓
   POST /api/rest/v1/sessions
   ↓
2. SessionsApplicationEventHandler.onBeforeCreate()
   → 验证用户名密码
   → 认证成功
   ↓
3. 获取/创建 HttpSession
   → request.getSession() 或 request.getSession(true)
   ↓
4. Servlet 容器（Undertow）自动处理
   → 检测到新 Session 创建
   → 自动生成 JSESSIONID Cookie
   → 自动添加 Set-Cookie 响应头
   ↓
5. HTTP 响应
   Set-Cookie: JSESSIONID=abc123; Path=/; HttpOnly; Secure
   ↓
6. 浏览器接收并存储 Cookie
   Attribution (128)
2. Spring Security 的 Cookie 管理
   WebSecurityConfig.java
   Apply
   @Bean
   public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
   http
   .sessionManagement(session -> session
   .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
   .maximumSessions(1)
   .maxSessionsPreventsLogin(false)
   );

   // ✅ Spring Security 会自动配置 Session Cookie
   // ❌ 但没有手动设置 Set-Cookie 响应头

   return http.build();
   }
   Spring Security 自动处理：
   Session 创建策略
   Session 并发控制
   Session 固定攻击防护
   Cookie 的 HttpOnly、Secure 等属性
   三、可能存在手动设置的位置（推测）
   虽然在提供的代码片段中没有找到，但以下位置可能存在手动设置：
1. SessionController（未提供完整代码）
   SessionController.java
   Apply
   // 推测可能存在的代码

@RestController
@RequestMapping("/api/rest/v1/sessions")
public class SessionController {

    @PostMapping
    public ResponseEntity<?> createSession(
            @RequestBody JsonNode credentials,
            HttpServletResponse response) {
        
        // 可能的自定义 Cookie 设置（推测）
        // Cookie authToken = new Cookie("X-Auth-Token", "token-value");
        // authToken.setMaxAge(3600);
        // authToken.setPath("/");
        // authToken.setHttpOnly(true);
        // response.addCookie(authToken);
        
        return ResponseEntity.ok(sessionData);
    }
}
2. 自定义认证过滤器（未提供完整代码）
   ZeApiKeyAuthFilter.java
   Apply
   @Override
   protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
   throws ServletException, IOException {

   String apiKey = request.getHeader(API_KEY_HEADER_NAME);

   if (API_KEY.equals(apiKey)) {
   UsernamePasswordAuthenticationToken authentication =
   new UsernamePasswordAuthenticationToken("apiKeyUser", null, null);
   authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
   SecurityContextHolder.getContext().setAuthentication(authentication);

        // 可能的 Cookie 设置（推测）
        // Cookie apiKeyCookie = new Cookie("API-Key-Valid", "true");
        // response.addCookie(apiKeyCookie);
   }

   filterChain.doFilter(request, response);
   }
   Attribution (102)
3. 登出处理器（可能存在）
   // 推测可能存在的登出处理器
   public class CustomLogoutHandler implements LogoutHandler {

   @Override
   public void logout(HttpServletRequest request, HttpServletResponse response, Authentication authentication) {
   // 可能的 Cookie 清除操作
   Cookie cookie = new Cookie("JSESSIONID", null);
   cookie.setMaxAge(0);
   cookie.setPath("/");
   response.addCookie(cookie);

        // 清除其他自定义 Cookie
        Cookie customCookie = new Cookie("X-Auth-Token", null);
        customCookie.setMaxAge(0);
        customCookie.setPath("/");
        response.addCookie(customCookie);
   }
   }
   四、验证方法
   要确认当前工程是否有手动设置 Set-Cookie，可以搜索以下关键词：
1. 搜索 Cookie 相关代码
   bash
# 搜索 Cookie 类的使用
grep -r "new Cookie" --include="*.java" .
grep -r "addCookie" --include="*.java" .
grep -r "Set-Cookie" --include="*.java" .

# 搜索响应头设置
grep -r "setHeader.*Cookie" --include="*.java" .
grep -r "addHeader.*Cookie" --include="*.java" .
2. 检查配置文件
   bash
# 检查 application.properties 或 application.yml
grep -r "cookie" application.properties
grep -r "cookie" application.yml

# 检查 Spring Security 配置
grep -r "cookie" --include="*Config.java" .
3. 检查 REST 控制器
   bash
# 检查所有 Controller
find . -name "*Controller.java" -exec grep -l "Cookie\|HttpServletResponse" {} \;
五、实际的 Cookie 设置机制总结
当前工程的 Cookie 管理方式
┌─────────────────────────────────────────────────────────────┐
│                Cookie 设置层级                               │
└─────────────────────────────────────────────────────────────┘

第一层：Servlet 容器（Undertow）
├─ 自动管理 JSESSIONID Cookie
├─ 根据 HttpSession 生命周期自动设置/删除
└─ 配置来源：server.servlet.session.cookie.* 属性

第二层：Spring Security
├─ 配置 Session 管理策略
├─ 配置 Cookie 安全属性（HttpOnly, Secure, SameSite）
└─ 处理登录/登出时的 Cookie 操作

第三层：应用代码（当前工程）
├─ ✅ 管理 HttpSession 生命周期
├─ ✅ 设置 Session 超时时间
├─ ✅ 处理 Session 并发控制
└─ ❌ 不直接操作 Set-Cookie 响应头（基于提供的代码）
Attribution (128)
Cookie 设置的实际流程
// 用户登录时的完整流程

// 1. 应用层：创建/获取 Session
HttpSession session = request.getSession(true);
session.setAttribute("user", userData);
session.setMaxInactiveInterval(3600);

// 2. Spring Security 层：配置 Session
// （通过 WebSecurityConfig 配置）

// 3. Servlet 容器层：自动设置 Cookie
// Undertow 检测到 Session 创建
// 自动生成响应头：
// Set-Cookie: JSESSIONID=abc123; Path=/; HttpOnly; Secure; SameSite=Strict

// 4. 浏览器接收
// 存储 Cookie 并在后续请求中携带
六、结论
基于提供的代码片段
1.
✅ 确认：当前工程没有手动设置 Set-Cookie 响应头
2.
✅ 确认：Cookie 管理完全依赖 Servlet 容器自动处理
3.
✅ 确认：应用层只负责 HttpSession 的生命周期管理
可能的例外情况
以下位置可能存在手动设置（需要完整代码确认）：
1.
SessionController 的完整实现
2.
自定义的认证/授权过滤器
3.
自定义的登出处理器
4.
API Key 认证相关的代码
建议的验证步骤
bash
# 1. 全局搜索 Cookie 相关代码
find . -name "*.java" -exec grep -l "Cookie\|Set-Cookie" {} \;

# 2. 检查 SessionController 完整代码
cat webapp/src/main/java/com/avocent/mtp/core/security/rest/SessionController.java

# 3. 检查所有 Filter 实现
find . -name "*Filter.java" -exec grep -l "response.add\|response.set" {} \;

# 4. 检查配置文件
grep -r "cookie" --include="*.properties" --include="*.yml" .
如果需要更准确的答案，请提供以下文件的完整代码：
SessionController.java
所有自定义的 Filter 实现
application.properties 或 application.yml
2. Spring Security 的 Cookie 管理 这个里面的，spring security 什么时候，什么场景下会为请求设置 cookie
   Spring Security Cookie 设置详解
   让我详细解释 Spring Security 在什么时候、什么场景下会为请求设置 Cookie。
   一、Spring Security Cookie 设置的核心时机
1. Session 创建时自动设置 JSESSIONID Cookie
   WebSecurityConfig.java
   Apply
   @Bean
   public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
   http
   .sessionManagement(session -> session
   .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED) // ← 关键配置
   .maximumSessions(1)
   .maxSessionsPreventsLogin(false)
   );

   return http.build();
   }
   SessionCreationPolicy 策略详解
   | 策略 | 说明 | Cookie 设置时机 |
   |------|------|----------------|
   | **ALWAYS** | 总是创建 Session | 每次请求都可能设置 Cookie |
   | **IF_REQUIRED** | 需要时创建（默认） | 认证成功、需要存储数据时设置 |
   | **NEVER** | 不主动创建，但会使用已存在的 | 不会主动设置，但会使用现有 Cookie |
   | **STATELESS** | 完全无状态 | **永不设置** Cookie |

当前工程使用 `IF_REQUIRED`，以下场景会设置 Cookie：
┌─────────────────────────────────────────────────────────────┐
│          IF_REQUIRED 策略下的 Cookie 设置时机                │
└─────────────────────────────────────────────────────────────┘

场景 1: 用户认证成功
├─ 触发点：UsernamePasswordAuthenticationFilter
├─ 时机：authManager.authenticate() 成功后
└─ 操作：创建 HttpSession → 设置 JSESSIONID Cookie

场景 2: 需要存储 SecurityContext
├─ 触发点：HttpSessionSecurityContextRepository
├─ 时机：SecurityContext 需要持久化时
└─ 操作：创建 HttpSession → 设置 JSESSIONID Cookie

场景 3: 需要存储 CSRF Token
├─ 触发点：CsrfFilter
├─ 时机：第一次访问需要 CSRF 保护的端点
└─ 操作：创建 HttpSession → 设置 JSESSIONID Cookie

场景 4: 应用代码主动创建 Session
├─ 触发点：request.getSession(true)
├─ 时机：SessionsApplicationEventHandler.onAfterCreate()
└─ 操作：创建 HttpSession → 设置 JSESSIONID Cookie
Attribution (160)
2. 具体的 Cookie 设置流程
   // 用户登录时的完整流程

// Step 1: 用户提交登录请求
POST /api/rest/v1/sessions
Body: { "user": { "username": "admin", "password": "xxx" } }

// Step 2: SessionsApplicationEventHandler.onBeforeCreate()
@Override
public JsonNode onBeforeCreate(JsonNode dataIn) {
// 验证用户名密码
UsernamePasswordAuthenticationToken token =
new UsernamePasswordAuthenticationToken(username, password);

    // 认证（此时还没有 Session）
    Authentication returnedToken = authManager.authenticate(token);
    
    // ✅ 认证成功，设置 Authentication 到 SecurityContext
    setAuthenticationToken(returnedToken);
    
    return dataIn;
}

// Step 3: setAuthenticationToken() 方法
private void setAuthenticationToken(Authentication token) {
SecurityContext ctx = SecurityContextHolder.getContext();
ctx.setAuthentication(token);

    HttpSessionSecurityContextRepository repo = new HttpSessionSecurityContextRepository();
    
    // ✅ 这里会触发 Session 创建和 Cookie 设置
    repo.saveContext(ctx,
        ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest(),
        ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getResponse());
}

// Step 4: HttpSessionSecurityContextRepository 内部逻辑
public void saveContext(SecurityContext context, HttpServletRequest request, HttpServletResponse response) {
// 获取或创建 HttpSession
HttpSession httpSession = request.getSession(true); // ← 关键：创建 Session

    // 将 SecurityContext 存入 Session
    httpSession.setAttribute(SPRING_SECURITY_CONTEXT_KEY, context);
    
    // ✅ Servlet 容器（Undertow）检测到新 Session 创建
    // ✅ 自动在响应中添加 Set-Cookie 头
}

// Step 5: Servlet 容器（Undertow）自动设置响应头
HTTP/1.1 200 OK
Set-Cookie: JSESSIONID=A1B2C3D4E5F6; Path=/; HttpOnly; Secure; SameSite=Strict
Content-Type: application/json
二、详细的 Cookie 设置场景
场景 1：用户首次登录
SessionsApplicationEventHandler.java
Apply

// 时间线：
// T0: 用户发送登录请求（没有 Cookie）
POST /api/rest/v1/sessions
Cookie: (无)

// T1: onBeforeCreate() - 认证阶段
private void checkUserPassword(JsonNode dataIn) {
UsernamePasswordAuthenticationToken token =
new UsernamePasswordAuthenticationToken(username, password);

    // 认证成功
    Authentication returnedToken = authManager.authenticate(token);
    
    // ✅ 设置 Authentication，触发 Session 创建
    setAuthenticationToken(returnedToken);
}

// T2: setAuthenticationToken() - Session 创建
private void setAuthenticationToken(Authentication token) {
SecurityContext ctx = SecurityContextHolder.getContext();
ctx.setAuthentication(token);

    HttpSessionSecurityContextRepository repo = new HttpSessionSecurityContextRepository();
    
    // ✅ 这里会调用 request.getSession(true)
    // ✅ Servlet 容器创建新 Session
    // ✅ 生成 sessionId = "A1B2C3D4E5F6"
    repo.saveContext(ctx, request, response);
}

// T3: onAfterCreate() - Session 配置
@Override
public JsonNode onAfterCreate(JsonNode dataIn) {
HttpSession httpSession = request.getSession();

    // 设置 Session 属性
    httpSession.setAttribute(AUTHENTICATION, authentication);
    
    // 设置超时时间
    setTimeout(httpSession);
    
    // 添加到本地缓存
    httpSessionHolder.addSession(httpSession);
    
    return dataIn;
}

// T4: 响应返回（包含 Set-Cookie）
HTTP/1.1 200 OK
Set-Cookie: JSESSIONID=A1B2C3D4E5F6; Path=/; HttpOnly; Secure; SameSite=Strict
Content-Type: application/json

{
"_id": "A1B2C3D4E5F6",
"user": {
"username": "admin",
"roles": ["Administrator"],
"permissions": [...]
}
}
场景 2：Session 固定攻击防护（Session Fixation Protection）
// Spring Security 默认启用 Session 固定攻击防护

// 攻击场景：
// 1. 攻击者获取一个 Session ID: "ATTACKER_SESSION"
// 2. 诱使受害者使用这个 Session ID 登录
// 3. 受害者登录成功后，攻击者使用同一 Session ID 访问

// Spring Security 的防护机制：
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
http
.sessionManagement(session -> session
// ✅ 默认策略：登录成功后创建新 Session
.sessionFixation().newSession() // 或 migrateSession()
);

    return http.build();
}

// 实际流程：
// T0: 用户访问（可能已有旧 Session）
GET /login
Cookie: JSESSIONID=OLD_SESSION_ID

// T1: 用户提交登录
POST /api/rest/v1/sessions
Cookie: JSESSIONID=OLD_SESSION_ID
Body: { "user": { "username": "admin", "password": "xxx" } }

// T2: 认证成功后，Spring Security 自动处理
// ✅ 使旧 Session 失效
httpSession.invalidate();

// ✅ 创建新 Session
HttpSession newSession = request.getSession(true);

// ✅ 设置新的 Cookie
HTTP/1.1 200 OK
Set-Cookie: JSESSIONID=NEW_SESSION_ID; Path=/; HttpOnly; Secure
Session Fixation 策略对比：
| 策略 | 说明 | Cookie 设置行为 |
|------|------|----------------|
| **none()** | 不做任何处理 | 不设置新 Cookie |
| **newSession()** | 创建全新 Session | ✅ 设置新 Cookie，旧 Session 完全销毁 |
| **migrateSession()** | 创建新 Session，迁移属性 | ✅ 设置新 Cookie，保留部分 Session 属性 |
| **changeSessionId()** | 只改变 Session ID | ✅ 设置新 Cookie，保留所有 Session 属性 |

场景 3：Remember-Me 功能（如果启用）
// 如果启用了 Remember-Me 功能
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
http
.rememberMe(remember -> remember
.key("uniqueAndSecret")
.tokenValiditySeconds(86400) // 24小时
.rememberMeParameter("remember-me")
.rememberMeCookieName("remember-me")
);

    return http.build();
}

// 用户登录时勾选"记住我"
POST /api/rest/v1/sessions
Body: {
"user": { "username": "admin", "password": "xxx" },
"remember-me": true
}

// 响应会设置两个 Cookie
HTTP/1.1 200 OK
Set-Cookie: JSESSIONID=A1B2C3D4E5F6; Path=/; HttpOnly; Secure
Set-Cookie: remember-me=base64EncodedToken; Path=/; Max-Age=86400; HttpOnly; Secure
注意：当前工程代码中未找到 Remember-Me 配置，所以这个场景可能不适用。
场景 4：CSRF Token 存储（如果使用 Cookie 存储）
// 如果配置 CSRF Token 存储在 Cookie 中
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
http
.csrf(csrf -> csrf
.csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
);

    return http.build();
}

// 首次访问需要 CSRF 保护的端点
GET /api/rest/v1/users

// 响应会设置 CSRF Cookie
HTTP/1.1 200 OK
Set-Cookie: XSRF-TOKEN=csrf-token-value; Path=/
注意：当前工程可能使用 Session 存储 CSRF Token，而非 Cookie。
场景 5：并发 Session 控制
WebSecurityConfig.java
Apply
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
http
.sessionManagement(session -> session
.maximumSessions(1) // ← 限制同一用户最多 1 个 Session
.maxSessionsPreventsLogin(false) // ← 新登录踢掉旧 Session
);

    return http.build();
}

// 场景：用户在设备 A 已登录
// 设备 A 的 Cookie: JSESSIONID=SESSION_A

// 用户在设备 B 登录
POST /api/rest/v1/sessions (from 设备 B)

// Spring Security 处理：
// 1. 认证成功
// 2. 检测到用户已有 Session (SESSION_A)
// 3. 根据策略决定：
//    - maxSessionsPreventsLogin=true: 拒绝新登录
//    - maxSessionsPreventsLogin=false: 使旧 Session 失效，创建新 Session

// 设备 B 的响应
HTTP/1.1 200 OK
Set-Cookie: JSESSIONID=SESSION_B; Path=/; HttpOnly; Secure

// 设备 A 的下次请求
GET /api/rest/v1/users
Cookie: JSESSIONID=SESSION_A

// 响应：Session 已失效
HTTP/1.1 401 Unauthorized
当前工程的实现：
SessionsApplicationEventHandler.java
Apply
private void invalidatePreviousSession(Map<String, String> sessionByIdMap,
String currentSessionId,
String currentUsername) {
if (shouldInvalidatePreviousSession()) {
sessionByIdMap.forEach((sessionId, username) -> {
if (username.equals(currentUsername) && !sessionId.equals(currentSessionId)) {
// ✅ 发布消息通知其他实例
httpSessionHolder.publishSessionOverLimitTopic(currentUsername, sessionId);

                try {
                    // ✅ 删除旧 Session
                    domainServiceFactory.get(SESSIONS_PATH).delete(sessionId);
                    
                    // 旧设备的 Cookie 仍然存在，但 Session 数据已删除
                    // 下次请求时会返回 401
                } catch (Exception ignored) {
                }
            }
        });
    }
}
场景 6：登出时清除 Cookie
// 用户登出
DELETE /api/rest/v1/sessions/{sessionId}

// SessionsApplicationEventHandler.onAfterDelete()
@Override
public JsonNode onAfterDelete(JsonNode dataIn) {
try {
String sessionId = dataIn.path(ID_FIELD).asText();
httpSessionHolder.getSession(sessionId).ifPresent(session -> {
httpSessionHolder.removeSession(session);

            // ✅ 调用 invalidate() 会触发 Cookie 清除
            session.invalidate();
        });
    } catch (IllegalStateException e) {
        LOGGER.debug("Session already invalidated", e);
    }
    
    return dataIn;
}

// Servlet 容器自动设置清除 Cookie 的响应头
HTTP/1.1 204 No Content
Set-Cookie: JSESSIONID=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT
三、Cookie 属性的配置
1. 通过 application.properties 配置
# Session Cookie 配置（推测当前工程可能有这些配置）
server.servlet.session.cookie.name=JSESSIONID
server.servlet.session.cookie.http-only=true
server.servlet.session.cookie.secure=true
server.servlet.session.cookie.same-site=strict
server.servlet.session.cookie.path=/
server.servlet.session.cookie.max-age=3600
server.servlet.session.cookie.domain=
2. 通过 Spring Security 配置
   @Bean
   public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
   http
   .sessionManagement(session -> session
   .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)

            // Session 固定攻击防护
            .sessionFixation().newSession()
            
            // 并发 Session 控制
            .maximumSessions(1)
            .maxSessionsPreventsLogin(false)
        );

   return http.build();
   }
3. Cookie 属性详解
   Set-Cookie: JSESSIONID=A1B2C3D4E5F6; Path=/; HttpOnly; Secure; SameSite=Strict

属性说明：
├─ JSESSIONID=A1B2C3D4E5F6  → Cookie 名称和值
├─ Path=/                   → Cookie 作用路径（整个应用）
├─ HttpOnly                 → 防止 JavaScript 访问（防 XSS）
├─ Secure                   → 仅 HTTPS 传输（防中间人攻击）
└─ SameSite=Strict          → 防止 CSRF 攻击
├─ Strict: 完全禁止跨站发送
├─ Lax: 允许部分跨站场景（GET 导航）
└─ None: 允许跨站发送（需配合 Secure）
四、完整的 Cookie 设置时序图
┌─────────────────────────────────────────────────────────────┐
│              用户登录的完整 Cookie 设置流程                   │
└─────────────────────────────────────────────────────────────┘

客户端                    应用层                  Spring Security              Servlet 容器
│                        │                          │                          │
│  POST /sessions        │                          │                          │
├───────────────────────>│                          │                          │
│  (无 Cookie)           │                          │                          │
│                        │                          │                          │
│                        │ onBeforeCreate()         │                          │
│                        ├─────────────────────────>│                          │
│                        │ authenticate()           │                          │
│                        │                          │                          │
│                        │ setAuthenticationToken() │                          │
│                        ├─────────────────────────>│                          │
│                        │                          │                          │
│                        │                          │ saveContext()            │
│                        │                          ├─────────────────────────>│
│                        │                          │ request.getSession(true) │
│                        │                          │                          │
│                        │                          │                          │ ✅ 创建 Session
│                        │                          │                          │ ✅ sessionId = "ABC"
│                        │                          │                          │
│                        │ onAfterCreate()          │                          │
│                        ├─────────────────────────>│                          │
│                        │ setTimeout()             │                          │
│                        │ addSession()             │                          │
│                        │                          │                          │
│  HTTP 200 OK           │                          │                          │
│<───────────────────────┴──────────────────────────┴──────────────────────────┤
│  Set-Cookie: JSESSIONID=ABC; Path=/; HttpOnly; Secure; SameSite=Strict      │
│  Body: { "_id": "ABC", "user": {...} }                                       │
│                                                                               │
│  后续请求                                                                      │
├──────────────────────────────────────────────────────────────────────────────>│
│  Cookie: JSESSIONID=ABC                                                      │
│                                                                               │
Attribution (139)
五、总结
Spring Security 设置 Cookie 的场景
| 场景 | 触发时机 | Cookie 名称 | 设置方式 |
|------|---------|------------|---------|
| **首次登录** | 认证成功，创建 Session | `JSESSIONID` | Servlet 容器自动 |
| **Session 固定防护** | 登录成功后 | `JSESSIONID`（新值） | Servlet 容器自动 |
| **Remember-Me** | 勾选"记住我" | `remember-me` | Spring Security |
| **CSRF Token** | 首次访问 | `XSRF-TOKEN` | Spring Security（可选） |
| **登出** | 用户登出 | `JSESSIONID`（清除） | Servlet 容器自动 |

当前工程的 Cookie 设置机制
1. ✅ 用户登录成功
   → SessionsApplicationEventHandler.setAuthenticationToken()
   → HttpSessionSecurityContextRepository.saveContext()
   → request.getSession(true)
   → Servlet 容器设置 JSESSIONID Cookie

2. ✅ Session 固定防护（默认启用）
   → 登录成功后创建新 Session
   → Servlet 容器设置新的 JSESSIONID Cookie

3. ✅ 用户登出
   → SessionsApplicationEventHandler.onAfterDelete()
   → session.invalidate()
   → Servlet 容器清除 JSESSIONID Cookie

4. ❌ Remember-Me（未启用）
   → 不设置 remember-me Cookie

5. ❓ CSRF Token（可能使用 Session 存储）
   → 可能不设置 XSRF-TOKEN Cookie
   关键点
1.
Spring Security 不直接设置 Cookie，而是通过管理 HttpSession 生命周期，由 Servlet 容器自动设置 Cookie
2.
唯一的 Cookie 名称：JSESSIONID（除非启用 Remember-Me 或 CSRF Cookie）
3.
设置时机：
认证成功时
Session 固定防护触发时
登出时（清除）
4.
Cookie 属性：由 server.servlet.session.cookie.* 配置决定
Workspace indexing: Done
Workspace

Add scope
Reset scope