针对网络切换导致的 WebSocket 异常关闭（code=1006），建议实现**心跳检测机制**来确认连接真正断开后再清理。以下是解决方案：

## 方案一：延迟清理 + 心跳检测（推荐）

```java
// File: D:\idea_workspace\mtp-core\webapp\src\main\java\com\avocent\mtp\core\websocket\handler\TafWebSocketHandler.java

import java.util.concurrent.*;

public class TafWebSocketHandler extends TextWebSocketHandler {

    private static final Logger LOGGER = LoggerFactory.getLogger(TafWebSocketHandler.class);
    
    private static final Map<String, WebSocketSession> CLIENTS = new HashMap<>(16);
    private static final int SEND_TIME_LIMIT = 20000;
    private static final int BUFFER_SIZE_LIMIT = 8000;
    
    // 新增：待清理的会话（延迟清理）
    private static final Map<String, ScheduledFuture<?>> PENDING_CLEANUP = new ConcurrentHashMap<>();
    private static final ScheduledExecutorService CLEANUP_SCHEDULER = Executors.newScheduledThreadPool(2);
    
    // 延迟清理时间（毫秒）- 给客户端重连的时间窗口
    private static final long CLEANUP_DELAY_MS = 5000; // 5秒
    
    @Autowired
    private DomainServiceFactory serviceFactory;

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String sessionId = session.getId();
        LOGGER.info("WebSocket Connected. SessionId: {}", sessionId);
        
        // 取消该会话的待清理任务（如果存在）
        ScheduledFuture<?> pendingTask = PENDING_CLEANUP.remove(sessionId);
        if (pendingTask != null) {
            LOGGER.info("WebSocket Reconnected. Cancelled cleanup for SessionId: {}", sessionId);
            pendingTask.cancel(false);
        }
        
        CLIENTS.put(sessionId, new ConcurrentWebSocketSessionDecorator(session, SEND_TIME_LIMIT, BUFFER_SIZE_LIMIT));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus closeStatus) {
        String sessionId = session.getId();
        LOGGER.info("WebSocket Closed. SessionId: {} Status: {}", sessionId, closeStatus.toString());
        
        // 1006 是异常关闭（网络中断、浏览器崩溃等），延迟清理
        if (closeStatus.getCode() == 1006) {
            LOGGER.warn("WebSocket Abnormal Closure (1006). Scheduling delayed cleanup for SessionId: {}", sessionId);
            scheduleDelayedCleanup(session);
        } else {
            // 正常关闭（1000, 1001等），立即清理
            LOGGER.info("WebSocket Normal Closure. Immediate cleanup for SessionId: {}", sessionId);
            cleanupSession(session);
        }
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        String sessionId = session.getId();
        LOGGER.error("WebSocket Transport Error. SessionId: {}", sessionId, exception);
        
        // 传输错误也延迟清理，可能是临时网络问题
        scheduleDelayedCleanup(session);
    }

    /**
     * 延迟清理会话
     */
    private void scheduleDelayedCleanup(WebSocketSession session) {
        String sessionId = session.getId();
        
        // 如果已有待清理任务，先取消
        ScheduledFuture<?> existingTask = PENDING_CLEANUP.get(sessionId);
        if (existingTask != null) {
            existingTask.cancel(false);
        }
        
        // 调度延迟清理任务
        ScheduledFuture<?> cleanupTask = CLEANUP_SCHEDULER.schedule(() -> {
            try {
                // 再次检查该会话是否已重新连接
                WebSocketSession currentSession = CLIENTS.get(sessionId);
                if (currentSession != null && !currentSession.isOpen()) {
                    LOGGER.info("Executing delayed cleanup for SessionId: {}", sessionId);
                    cleanupSession(session);
                } else if (currentSession != null && currentSession.isOpen()) {
                    LOGGER.info("Session {} has reconnected, skipping cleanup", sessionId);
                } else {
                    LOGGER.info("Session {} not found in CLIENTS, executing cleanup", sessionId);
                    cleanupSession(session);
                }
            } finally {
                PENDING_CLEANUP.remove(sessionId);
            }
        }, CLEANUP_DELAY_MS, TimeUnit.MILLISECONDS);
        
        PENDING_CLEANUP.put(sessionId, cleanupTask);
    }

    /**
     * Cleanup a web socket session that was either closed or had an error.
     */
    private void cleanupSession(WebSocketSession session) {
        String sessionId = session.getId();
        LOGGER.info("Cleanup Session. SessionId: {}", sessionId);
        
        // 移除待清理任务（如果存在）
        PENDING_CLEANUP.remove(sessionId);
        
        // 从 CLIENTS Map 中移除
        CLIENTS.remove(sessionId);

        // 删除该会话的所有主题监听器
        DomainService service = serviceFactory.get(WebSocketConstants.WEBSOCKET_TOPIC_LISTENERS_PATH);
        service.forEach(FilterUtils.getStringFilter(WebSocketConstants.WSTOPICLISTENERS_SESSION_ID, sessionId),
                listener -> cleanListener(service, listener));
    }

    private void cleanListener(DomainService service, JsonNode listener) {
        String listenerId = listener.get(WebSocketConstants.WSTOPICLISTENERS_ID).asText();
        LOGGER.info("Deleting WebSocket Listener {}", listenerId);
        service.delete(listenerId);
    }
}
```

## 方案二：客户端心跳 + 服务端验证

如果需要更精确的控制，可以结合客户端心跳：

```java
// File: D:\idea_workspace\mtp-core\webapp\src\main\java\com\avocent\mtp\core\websocket\handler\TafWebSocketHandler.java

public class TafWebSocketHandler extends TextWebSocketHandler {
    
    // 心跳记录：sessionId -> 最后心跳时间
    private static final Map<String, Long> HEARTBEAT_MAP = new ConcurrentHashMap<>();
    private static final long HEARTBEAT_TIMEOUT_MS = 30000; // 30秒无心跳视为断线

    @Override
    public void handleTextMessage(WebSocketSession session, TextMessage message) {
        String payload = message.getPayload();
        
        // 处理心跳消息
        if ("PING".equals(payload) || isPingMessage(payload)) {
            LOGGER.debug("Received heartbeat from SessionId: {}", session.getId());
            HEARTBEAT_MAP.put(session.getId(), System.currentTimeMillis());
            
            // 回复 PONG
            try {
                session.sendMessage(new TextMessage("PONG"));
            } catch (IOException e) {
                LOGGER.error("Failed to send PONG to SessionId: {}", session.getId(), e);
            }
            return;
        }
        
        // 其他消息处理
        LOGGER.error("Invalid Websocket Message Received SocketId: {} Message: {}", 
            session.getId(), message.toString());
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String sessionId = session.getId();
        LOGGER.info("WebSocket Connected. SessionId: {}", sessionId);
        
        // 初始化心跳时间
        HEARTBEAT_MAP.put(sessionId, System.currentTimeMillis());
        
        // 取消待清理任务
        ScheduledFuture<?> pendingTask = PENDING_CLEANUP.remove(sessionId);
        if (pendingTask != null) {
            pendingTask.cancel(false);
        }
        
        CLIENTS.put(sessionId, new ConcurrentWebSocketSessionDecorator(session, SEND_TIME_LIMIT, BUFFER_SIZE_LIMIT));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus closeStatus) {
        String sessionId = session.getId();
        LOGGER.info("WebSocket Closed. SessionId: {} Status: {}", sessionId, closeStatus.toString());
        
        if (closeStatus.getCode() == 1006) {
            // 检查最后心跳时间
            Long lastHeartbeat = HEARTBEAT_MAP.get(sessionId);
            long timeSinceLastHeartbeat = System.currentTimeMillis() - (lastHeartbeat != null ? lastHeartbeat : 0);
            
            if (timeSinceLastHeartbeat < HEARTBEAT_TIMEOUT_MS) {
                // 最近有心跳，可能是临时断线，延迟清理
                LOGGER.warn("Recent heartbeat detected. Scheduling delayed cleanup for SessionId: {}", sessionId);
                scheduleDelayedCleanup(session);
            } else {
                // 长时间无心跳，立即清理
                LOGGER.info("No recent heartbeat. Immediate cleanup for SessionId: {}", sessionId);
                cleanupSession(session);
            }
        } else {
            cleanupSession(session);
        }
    }

    private void cleanupSession(WebSocketSession session) {
        String sessionId = session.getId();
        LOGGER.info("Cleanup Session. SessionId: {}", sessionId);
        
        // 清理心跳记录
        HEARTBEAT_MAP.remove(sessionId);
        PENDING_CLEANUP.remove(sessionId);
        CLIENTS.remove(sessionId);

        DomainService service = serviceFactory.get(WebSocketConstants.WEBSOCKET_TOPIC_LISTENERS_PATH);
        service.forEach(FilterUtils.getStringFilter(WebSocketConstants.WSTOPICLISTENERS_SESSION_ID, sessionId),
                listener -> cleanListener(service, listener));
    }

    /**
     * 判断是否为心跳消息
     */
    private boolean isPingMessage(String payload) {
        try {
            JsonNode node = JsonUtil.parse(payload);
            return "PING".equals(node.path("command").asText());
        } catch (Exception e) {
            return false;
        }
    }
}
```

## 客户端配置（JavaScript）

```javascript
// File: /path/to/your/frontend/websocket-client.js

class WebSocketClient {
    constructor(url) {
        this.url = url;
        this.ws = null;
        this.heartbeatInterval = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
    }

    connect() {
        this.ws = new WebSocket(this.url);
        
        this.ws.onopen = () => {
            console.log('WebSocket Connected');
            this.reconnectAttempts = 0;
            this.startHeartbeat();
        };
        
        this.ws.onclose = (event) => {
            console.log('WebSocket Closed', event.code, event.reason);
            this.stopHeartbeat();
            
            // 网络切换等异常关闭，尝试重连
            if (event.code === 1006 && this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectAttempts++;
                console.log(`Reconnecting... Attempt ${this.reconnectAttempts}`);
                setTimeout(() => this.connect(), 2000);
            }
        };
        
        this.ws.onerror = (error) => {
            console.error('WebSocket Error', error);
        };
        
        this.ws.onmessage = (event) => {
            if (event.data === 'PONG') {
                console.debug('Received PONG');
                return;
            }
            // 处理业务消息
            this.handleMessage(JSON.parse(event.data));
        };
    }

    startHeartbeat() {
        // 每 15 秒发送一次心跳
        this.heartbeatInterval = setInterval(() => {
            if (this.ws.readyState === WebSocket.OPEN) {
                this.ws.send('PING');
            }
        }, 15000);
    }

    stopHeartbeat() {
        if (this.heartbeatInterval) {
            clearInterval(this.heartbeatInterval);
            this.heartbeatInterval = null;
        }
    }

    handleMessage(data) {
        // 处理业务消息
        console.log('Received message:', data);
    }
}
```

## 推荐方案

**方案一（延迟清理）** 更简单，适合大多数场景：
- ✅ 无需修改客户端代码
- ✅ 给客户端 5 秒重连窗口
- ✅ 自动处理网络抖动

**方案二（心跳检测）** 更精确，适合对连接状态要求高的场景：
- ✅ 主动检测连接活性
- ✅ 更快发现僵尸连接
- ⚠️ 需要客户端配合

建议先使用**方案一**，如果需要更精确的控制再升级到**方案二**。