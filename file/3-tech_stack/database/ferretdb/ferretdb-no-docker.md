# Analysis for FerretDB not use docker

## Purpose
1. 不使用 docker 的前提下, 在 windows 和多种 linux 上使用 FerretDB 数据库


## Concept
![](./image/ferretdb-concept.png)

1. 由 FerretDB, Postgresql, Documentdb(作为 Postgresql 扩展) 组成
2. FerretDB 转化 Mongodb 语法去操作数据库
3. Postgresql 起数据存储等作用
4. Documentdb 增强 JSON 类型数据的处理
   1. FerretDB 使用的 Documentdb 是基于微软的 Documentdb (MIT license) 进行 fork 和改造
5. FerretDB 官方提供 docker镜像 和 linux 包(.deb, .rpm), 且目前暂无 windows 下的预编译二进制文件, 仅提供源码供自行编译
   1. ferretdb
   2. postgresql-documentdb
   3. 在 linux 环境中, 无需复杂的编译过程即可安装使用
      1. Red Hat Enterprise Linux 8/9 (64-bit)        --- .rpm
      2. Ubuntu Server 22.04 LTS/ 24.04 LTS (64-bit)  --- .deb


## FerretDB && Postgresql-documentdb build and develop in windows
1. 需要 Go 语言环境 (IDEA 开发工具付费)
2. 需要 C 语言环境(Visual Studio, CMake)
3. 编译 FerretDB, documentdb 源码


## Overall Process
1. 克隆/更新 FerretDB 代码
2. 编译 FerretDB, 输出 exe 文件
   1. 指令: go build -o ferretdb.exe ./cmd/ferretdb
3. 克隆/更新 Documentdb 代码
4. CMake 构建生成 Visual Studio 解决方案文件 documentdb.sln
   1. 指令: mkdir build && cd build && cmake .. -G "Visual Studio 17 2022" -A x64
5. 编译 sln 文件, 输出动态链接库 .dll文件(Dynamic Link Library)
   1. 指令: cmake --build . --config Release
6. 把 .dll 文件放到 Postgresql 安装路径下
7. 配置 FerretDB 数据库, 用户, 密码等内容


## Test
### Test1
1. 编译完 Ferretdb 后, 连接现有数据库 10.243.192.44, 成功运行
```shell
run.bat:
set FERRETDB_POSTGRESQL_URL=postgres://mtpuser:(3fWtenCrw2ze+=+@10.243.192.44:5432/postgres?sslmode=disable
ferretdb.exe
PAUSE
```
![](./image/ferretdb-on-windows.png)

### Test2
1. 尝试编译 Documentdb 扩展, 失败(难以解决, 资料很少)

![](./image/CMake-no-find-config.png)



## Conclusion
1. 理论可行性: 由 Test1 可以看出来, 理论上是完全可行的
2. 实施难度: 但是, 在 Windows 原生环境下, 不使用 Docker 部署完整的 FerretDB + Postgresql + DocumentDB 扩展极其困难
   1. 尽管理论可行, 但缺少官方 Windows编译指南和预编译依赖包, 排错成本很高 (需投入人力和大量时间研究 Test2 及其后续内容);
   2. 自行编译难度和要求很高, 需同时掌握 Go 和 C/C++(Visual Studio, CMake) 两套完全不同的编译工具链, 和 Postgresql, DocumentDB数据库相关知识;
      1. 在 windows 上进行的 DocumentDB 扩展的 C编译很脆弱
         1. Visual Studio版本依赖: 编译后的程序, 依赖微软的 MSVC运行时库; ("DLL 地狱")
            1. 用 VS 2015 编译的程序, 需要目标机器安装 VS 2015 运行时; 且不向前兼容;
            2. 可能把编译好的 DLL 拿去另外一台机器用, 或用户环境不同时, 不可用;
         2. 工具链与 SDK割裂
            1. 不同版本的 Visual Studio使用的 C++ 编译器标准支持程度不同; 
            2. 如果用到比较新版本的 windows SDK 的 API, 可能在其他版本就跑不起来程序
         3. 缺少统一的包管理器
         4. 系统内核与 API存在差异
            1. windows 7,8,10,11 内核实现有细微差异;
            2. 涉及系统底层的代码(如内存管理, 网格栈), 在不同版本的 windows 下行为肯不一致, 触发不同的 Bug
         5. 主流的编译模式为: 
            1. 容器化(docker)
            2. 持续集成/部署(CI/CD)
            3. 统一构建标准(vcpkg/Conan), 强制使用包管理器
            4. 交叉编译, 在 linux 或 macOs 上使用特殊工具链编译出 .exe; 适用于简单 C程序;
   3. 自行编译的组件未经过大量验证, 可能存在未知 bug, 性能瓶颈, 安全漏洞等, 后续升级维护困难;


## Discussion Conclusion(4/15)
1. 高版本的 ferretdb 是否可以不使用 documentdb 扩展
   1. 高版本不可用, 其代码里面有明确的和 documentdb 耦合的逻辑, 不可用
2. 是否使用低版本的 ferretdb (v1.24, 不带 documentdb 扩展)
   1. 生成的表只有一个 JSONB 类型的字段, 性能很差(在 SI 上已经遇到过了)
   2. 部分 mongodb 语法和表不可用, 功能不一定在 PI 上可用
   3. 作为 Ferretdb 早期版本, 官方人员不会投很多精力维护, 导致维护和在 windows等环境上打包只能靠自己, 风险和难度很大
   4. 不建议继续研究和使用
3. 更换成关系型数据库 postgresql?
   1. [planA] 北向和南向都改 (mongodb 语法也改掉, 数据库表更换成关系型数据库表, 不再是文档类型 json);
   2. [planB] 北向不改, 南向改 (mongodb 语法不改,  数据库表更换成关系型数据库表, 不再是文档类型 json);
   3. [planC] 用 AI 工具来评估和分析, 局部/全部推倒和重构 PI 的架构及其业务代码;


### Test solutions
#### 1. 高版本的 ferretdb 不使用 documentdb 扩展
1. 本地编译 ferretdb.exe + 本地 postgresql(无 documentdb 扩展)
2. 结果: 失败, 高版本 ferretdb 有对 documentdb 进行校验

```textmate
D:\goland_workspace\test\latest-ferretdb>set FERRETDB_POSTGRESQL_URL=postgres://postgres:Passw0rd@127.0.0.1:5432/postgres?sslmode=disable

D:\goland_workspace\test\latest-ferretdb>ferretdb.exe
2026-04-20T10:30:57.665+0800    INFO    ferretdb/main.go:372    Starting FerretDB v2.7.0-3-g799235da-dirty      {"branch":"main","buildEnvironment":{"-buildmode":"exe","-compiler":"gc","CGO_ENABLED":"0","GOAMD64":"v1","GOARCH":"amd64","GOOS":"windows","go.runtime":"go1.25.0","go.version":"go1.25.0","vcs":"git","vcs.modified":"true","vcs.revision":"799235dab9e350655e72e65a0b24d849f7d68143","vcs.time":"2026-02-07T11:20:54Z"},"commit":"799235dab9e350655e72e65a0b24d849f7d68143","devBuild":false,"dirty":true,"package":"bin","uuid":"6995e861-8933-43c5-997b-1bd723b7d54c","version":"v2.7.0-3-g799235da-dirty"}
2026-04-20T10:30:57.679+0800    INFO    debug/debug.go:236      Starting debug server on http://127.0.0.1:8088/debug    {"name":"debug"}
2026-04-20T10:30:57.680+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/archive - Zip archive with debugging information    {"name":"debug"}
2026-04-20T10:30:57.680+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/events - /x/net/trace events        {"name":"debug"}
2026-04-20T10:30:57.680+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/graphs - Visualize metrics  {"name":"debug"}
2026-04-20T10:30:57.680+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/livez - Liveness probe      {"name":"debug"}
2026-04-20T10:30:57.681+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/metrics - Metrics in Prometheus format      {"name":"debug"}
2026-04-20T10:30:57.681+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/pprof - Runtime profiling data for pprof    {"name":"debug"}
2026-04-20T10:30:57.681+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/readyz - Readiness probe    {"name":"debug"}
2026-04-20T10:30:57.681+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/requests - /x/net/trace requests    {"name":"debug"}
2026-04-20T10:30:57.681+0800    INFO    debug/debug.go:241      http://127.0.0.1:8088/debug/vars - Expvar package metrics       {"name":"debug"}
2026-04-20T10:30:57.684+0800    INFO    clientconn/listener.go:145      Listening on TCP 127.0.0.1:27017        {"name":"listener"}
2026-04-20T10:30:57.687+0800    INFO    telemetry/reporter.go:171       The telemetry state is undecided; the first report will be sent in 1h0m0s. Read more about FerretDB telemetry and how to opt out at https://beacon.ferretdb.com  {"name":"telemetry"}
2026-04-20T10:30:57.721+0800    INFO    clientconn/listener.go:316      Connection started      {"conn":"127.0.0.1:46878 -> 127.0.0.1:27017","name":"listener"}
2026-04-20T10:30:57.728+0800    INFO    middleware/dispatcher.go:131    Command handled {"command":"isMaster","duration":"0s","handler":"documentdb","name":"middleware","result":"ok"}
2026-04-20T10:30:57.744+0800    INFO    clientconn/listener.go:316      Connection started      {"conn":"127.0.0.1:46879 -> 127.0.0.1:27017","name":"listener"}
2026-04-20T10:30:57.829+0800    INFO    clientconn/listener.go:316      Connection started      {"conn":"127.0.0.1:46881 -> 127.0.0.1:27017","name":"listener"}
2026-04-20T10:30:59.162+0800    ERROR   documentdb/tracer.go:157        Prepare {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":24336,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":103069300}
2026-04-20T10:30:59.162+0800    ERROR   documentdb/tracer.go:157        Prepare {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":38988,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":103729000}
2026-04-20T10:30:59.162+0800    ERROR   documentdb/tracer.go:157        Prepare {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":44216,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":103729000}
2026-04-20T10:30:59.162+0800    ERROR   documentdb/tracer.go:157        Prepare {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":12048,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":100028900}
2026-04-20T10:30:59.162+0800    ERROR   documentdb/tracer.go:157        Prepare {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":26196,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":103069300}
2026-04-20T10:30:59.162+0800    ERROR   documentdb/tracer.go:157        Prepare {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":44692,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":103729000}
2026-04-20T10:30:59.165+0800    ERROR   documentdb/tracer.go:198        Query   {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":44692,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":106925200}
2026-04-20T10:30:59.167+0800    ERROR   documentdb/tracer.go:198        Query   {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":44240,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":107901700}
2026-04-20T10:30:59.167+0800    ERROR   documentdb/tracer.go:198        Query   {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":36008,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":107901700}
2026-04-20T10:30:59.167+0800    ERROR   documentdb/tracer.go:115        Acquire {"error":"pool_new.go:61 (documentdb.newPgxPool.func1): pool_new.go:115 (documentdb.newPgxPoolCheckConn): 错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000) (please check DocumentDB installation)","name":"documentdb","time":1336628000}
2026-04-20T10:30:59.167+0800    ERROR   documentdb/tracer.go:115        Acquire {"error":"pool_new.go:61 (documentdb.newPgxPool.func1): pool_new.go:115 (documentdb.newPgxPoolCheckConn): 错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000) (please check DocumentDB installation)","name":"documentdb","time":1413306100}
2026-04-20T10:30:59.168+0800    INFO    middleware/dispatcher.go:131    Command handled {"command":"isMaster","duration":"1.4149526s","handler":"documentdb","name":"middleware","result":"ok"}
2026-04-20T10:30:59.168+0800    INFO    middleware/dispatcher.go:131    Command handled {"command":"isMaster","duration":"1.3382745s","handler":"documentdb","name":"middleware","result":"ok"}
2026-04-20T10:30:59.245+0800    ERROR   documentdb/tracer.go:157        Prepare {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":5800,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":631300}
2026-04-20T10:30:59.245+0800    ERROR   documentdb/tracer.go:198        Query   {"error":"错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000)","name":"documentdb","pid":5800,"sql":"SELECT version(), documentdb_api.binary_extended_version()","time":631300}
2026-04-20T10:30:59.246+0800    ERROR   documentdb/tracer.go:115        Acquire {"error":"pool_new.go:61 (documentdb.newPgxPool.func1): pool_new.go:115 (documentdb.newPgxPoolCheckConn): 错误: 模式 \"documentdb_api\" 不存在 (SQLSTATE 3F000) (please check DocumentDB installation)","name":"documentdb","time":71205100}
2026-04-20T10:30:59.246+0800    ERROR+1 mongoerrors/mongoerrors.go:154  Unmapped error code     {"arg":"","error":"lazyerror{\"msg_saslstart.go:47 (handler.(*Handler).msgSASLStart): msg_saslstart.go:137 (handler.(*Handler).saslStart): pool.go:101 (documentdb.(*Pool).WithConn): pool.go:90 (documentdb.(*Pool).Acquire): pool_new.go:61 (documentdb.newPgxPool.func1): pool_new.go:115 (documentdb.newPgxPoolCheckConn): 错误: 模式 \\\"documentdb_api\\\" 不存在 (SQLSTATE 3F000) (please check DocumentDB installation)\"}","name":"documentdb"}
2026-04-20T10:30:59.246+0800    WARN    middleware/dispatcher.go:131    Command handled {"command":"saslStart","duration":"71.5353ms","handler":"documentdb","name":"middleware","result":"InternalError"}
2026-04-20T10:30:59.257+0800    INFO    clientconn/listener.go:322      Connection stopped      {"conn":"127.0.0.1:46881 -> 127.0.0.1:27017","name":"listener"}
2026-04-20T10:30:59.306+0800    INFO    clientconn/listener.go:322      Connection stopped      {"conn":"127.0.0.1:46878 -> 127.0.0.1:27017","name":"listener"}
2026-04-20T10:30:59.343+0800    INFO    clientconn/listener.go:316      Connection started      {"conn":"127.0.0.1:46885 -> 127.0.0.1:27017","name":"listener"}
2026-04-20T10:30:59.344+0800    INFO    middleware/dispatcher.go:131    Command handled {"command":"isMaster","duration":"0s","handler":"documentdb","name":"middleware","result":"ok"}
2026-04-20T10:30:59.345+0800    INFO    clientconn/listener.go:316      Connection started      {"conn":"127.0.0.1:46886 -> 127.0.0.1:27017","name":"listener"}
```

#### 2. 低版本的 ferretdb (v1.24, 不带 documentdb 扩展)
1. 本地编译 ferretdb.exe + 本地 postgresql(无 documentdb 扩展)
2. 结果: 失败
   1. mongodb 有些能力未实现
      1. Index option partialFilterExpression
   2. 插件包过大, 超过 mongodb 协议中定的最大值 48M
      1. taf-ui-core 51M
   3. PI 无法初始化成功

![](./image/ferretdb-v1.24-p0.png)

![](./image/ferretdb-v1.24-p1.png)

![](./image/ferretdb-v1.24-p2.png)

```textmate
2026-04-20 09:39:38.378 ERROR [main] com.avocent.mtp.core.generic.data.repository.support.mongo.MongoDataAccessor (MongoDataAccessor.java:523) - Unable to create index
com.mongodb.MongoCommandException: Command failed with error 238 (NotImplemented): 'Index option "partialFilterExpression" is not implemented yet' on server localhost:27017. The full response is {"ok": 0.0, "errmsg": "Index option \"partialFilterExpression\" is not implemented yet", "code": 238, "codeName": "NotImplemented"}
	at com.mongodb.internal.connection.ProtocolHelper.getCommandFailureException(ProtocolHelper.java:198)
	at com.mongodb.internal.connection.InternalStreamConnection.receiveCommandMessageResponse(InternalStreamConnection.java:418)
	at com.mongodb.internal.connection.InternalStreamConnection.sendAndReceive(InternalStreamConnection.java:342)
	at com.mongodb.internal.connection.UsageTrackingInternalConnection.sendAndReceive(UsageTrackingInternalConnection.java:116)
	at com.mongodb.internal.connection.DefaultConnectionPool$PooledConnection.sendAndReceive(DefaultConnectionPool.java:647)
	at com.mongodb.internal.connection.CommandProtocolImpl.execute(CommandProtocolImpl.java:71)
	at com.mongodb.internal.connection.DefaultServer$DefaultServerProtocolExecutor.execute(DefaultServer.java:244)
	at com.mongodb.internal.connection.DefaultServerConnection.executeProtocol(DefaultServerConnection.java:227)
	at com.mongodb.internal.connection.DefaultServerConnection.command(DefaultServerConnection.java:127)
	at com.mongodb.internal.connection.DefaultServerConnection.command(DefaultServerConnection.java:117)
	at com.mongodb.internal.connection.DefaultServer$OperationCountTrackingConnection.command(DefaultServer.java:348)
	at com.mongodb.internal.operation.CommandOperationHelper.executeCommand(CommandOperationHelper.java:248)
	at com.mongodb.internal.operation.CreateIndexesOperation$1.call(CreateIndexesOperation.java:197)
	at com.mongodb.internal.operation.CreateIndexesOperation$1.call(CreateIndexesOperation.java:192)
	at com.mongodb.internal.operation.OperationHelper.withConnectionSource(OperationHelper.java:545)
	at com.mongodb.internal.operation.OperationHelper.withConnection(OperationHelper.java:536)
	at com.mongodb.internal.operation.CreateIndexesOperation.execute(CreateIndexesOperation.java:192)
	at com.mongodb.internal.operation.CreateIndexesOperation.execute(CreateIndexesOperation.java:72)
	at com.mongodb.client.internal.MongoClientDelegate$DelegateOperationExecutor.execute(MongoClientDelegate.java:212)
	at com.mongodb.client.internal.MongoCollectionImpl.executeCreateIndexes(MongoCollectionImpl.java:848)
	at com.mongodb.client.internal.MongoCollectionImpl.createIndexes(MongoCollectionImpl.java:831)
	at com.mongodb.client.internal.MongoCollectionImpl.createIndexes(MongoCollectionImpl.java:826)
	at com.mongodb.client.internal.MongoCollectionImpl.createIndex(MongoCollectionImpl.java:811)
	at com.avocent.mtp.core.generic.data.repository.support.mongo.MongoDataAccessor.createIndex(MongoDataAccessor.java:518)
	at com.avocent.mtp.core.generic.data.repository.support.mongo.MongoDataAccessor$$FastClassBySpringCGLIB$$aae39904.invoke(<generated>)
	at org.springframework.cglib.proxy.MethodProxy.invoke(MethodProxy.java:218)
	...
2026-04-20 09:40:34.036 ERROR [main] com.avocent.mtp.core.module.plugin.support.PluginOperationManager (PluginOperationManager.java:182) - Unable to start plugin:{"_id":"69e583fdd8162e1ea78c463c","name":"taf-ui-core","version":"1.0.0-pi","platformVersion":">=1.12.0","vendor":"Avocent","description":"taf-ui-core","classification":"uiConsole","dependencies":[],"autoupgrade":{"initDataLoaderLocation":"/initData/initDataLoader.json","minimumSupportedVersion":"0.0.1"},"installationOriginator":"SYSTEM","administrationState":"ENABLED","installationState":"PENDING","_type":"Plugin","_hierarchy":["Plugin"],"_createdBy":"admin","_createdDateTime":"2026-04-20T01:40:13.494Z","operationalState":{"state":"STOPPED"}}
com.avocent.mtp.core.model.exception.MtpCoreRuntimeException: mtp.core.error.plugin.load.failed
	at com.avocent.mtp.core.model.exception.MtpCoreRuntimeException.createIfNeeded(MtpCoreRuntimeException.java:156)
	at com.avocent.mtp.core.module.plugin.support.PluginOperationManager.loadPlugin(PluginOperationManager.java:351)
	at com.avocent.mtp.core.module.plugin.support.PluginOperationManager.startPluginLocal(PluginOperationManager.java:207)
	at com.avocent.mtp.core.module.plugin.support.PluginOperationManager.startAllPluginsLocal(PluginOperationManager.java:180)
	at com.avocent.mtp.core.init.lifecycle.CoreLifecycle.startPlugins(CoreLifecycle.java:198)
	at com.avocent.mtp.core.init.lifecycle.CoreLifecycle.start(CoreLifecycle.java:106)
	at com.avocent.mtp.core.init.Initializer.synchronizedInitialization(Initializer.java:172)
	at com.avocent.mtp.core.init.Initializer.initializeSystem(Initializer.java:130)
	at com.avocent.mtp.core.init.Initializer.init(Initializer.java:113)
	at com.avocent.mtp.core.Application.main(Application.java:77)
Caused by: com.mongodb.MongoInternalException: The reply message length 50912595 is greater than the maximum message length 48000000
	at com.mongodb.internal.connection.MessageHeader.<init>(MessageHeader.java:41)
	at com.mongodb.internal.connection.InternalStreamConnection.receiveResponseBuffers(InternalStreamConnection.java:721)
	at com.mongodb.internal.connection.InternalStreamConnection.receiveMessageWithAdditionalTimeout(InternalStreamConnection.java:576)
	at com.mongodb.internal.connection.InternalStreamConnection.receiveCommandMessageResponse(InternalStreamConnection.java:415)
	at com.mongodb.internal.connection.InternalStreamConnection.sendAndReceive(InternalStreamConnection.java:342)
	at com.mongodb.internal.connection.UsageTrackingInternalConnection.sendAndReceive(UsageTrackingInternalConnection.java:116)
	at com.mongodb.internal.connection.DefaultConnectionPool$PooledConnection.sendAndReceive(DefaultConnectionPool.java:647)
	at com.mongodb.internal.connection.CommandProtocolImpl.execute(CommandProtocolImpl.java:71)
	at com.mongodb.internal.connection.DefaultServer$DefaultServerProtocolExecutor.execute(DefaultServer.java:244)
	at com.mongodb.internal.connection.DefaultServerConnection.executeProtocol(DefaultServerConnection.java:227)
	at com.mongodb.internal.connection.DefaultServerConnection.command(DefaultServerConnection.java:127)
	at com.mongodb.internal.connection.DefaultServerConnection.command(DefaultServerConnection.java:117)
	at com.mongodb.internal.connection.DefaultServer$OperationCountTrackingConnection.command(DefaultServer.java:348)
	at com.mongodb.internal.operation.QueryBatchCursor.lambda$getMore$1(QueryBatchCursor.java:284)
	at com.mongodb.internal.operation.QueryBatchCursor$ResourceManager.executeWithConnection(QueryBatchCursor.java:524)
	at com.mongodb.internal.operation.QueryBatchCursor.getMore(QueryBatchCursor.java:280)
	at com.mongodb.internal.operation.QueryBatchCursor.doHasNext(QueryBatchCursor.java:161)
	at com.mongodb.internal.operation.QueryBatchCursor$ResourceManager.execute(QueryBatchCursor.java:409)
	at com.mongodb.internal.operation.QueryBatchCursor.hasNext(QueryBatchCursor.java:148)
	at com.mongodb.client.internal.MongoBatchCursorAdapter.hasNext(MongoBatchCursorAdapter.java:54)
	at com.mongodb.client.gridfs.GridFSDownloadStreamImpl.getChunk(GridFSDownloadStreamImpl.java:218)
	at com.mongodb.client.gridfs.GridFSDownloadStreamImpl.getBuffer(GridFSDownloadStreamImpl.java:277)
	at com.mongodb.client.gridfs.GridFSDownloadStreamImpl.read(GridFSDownloadStreamImpl.java:104)
	at com.mongodb.client.gridfs.GridFSDownloadStreamImpl.read(GridFSDownloadStreamImpl.java:91)
	at org.apache.commons.io.IOUtils.copyLarge(IOUtils.java:1309)
	at org.apache.commons.io.IOUtils.copy(IOUtils.java:978)
	at org.apache.commons.io.IOUtils.copyLarge(IOUtils.java:1282)
	at org.apache.commons.io.IOUtils.copy(IOUtils.java:953)
	at org.apache.commons.io.IOUtils.toByteArray(IOUtils.java:2405)
	at com.avocent.mtp.core.bundle.storage.PackageStorage.findPackage(PackageStorage.java:86)
	at com.avocent.mtp.core.module.plugin.support.loader.PluginLoader.extractPlugin(PluginLoader.java:165)
	at com.avocent.mtp.core.module.plugin.support.loader.PluginLoader.loadPluginContext(PluginLoader.java:160)
	at com.avocent.mtp.core.module.plugin.support.PluginOperationManager.loadPlugin(PluginOperationManager.java:344)
	... 8 common frames omitted
```