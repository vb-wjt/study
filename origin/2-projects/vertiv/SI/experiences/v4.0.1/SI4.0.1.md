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
### 性能测试与索引优化

> 详细实验数据和 EXPLAIN 执行计划见 `postgresql.xmind` 第 7 部分"索引优化"

#### 1. 优化目标
`report_tsd` 集合(历史报表数据),机器 10.146.100.57:
- 表总大小: **395G**,**4.04 亿行**记录
- 信号点: 8w+ 信号点,4.8w+ 存储信号点
- 典型查询: 按 `cid` + `triggerType` 过滤 + 按 `timestamp` 范围查询 + 聚合

#### 2. 原索引(共 ~83G)
| 索引名 | 大小 | 说明 |
|---|---|---|
| `deviceId_timestamp` | 3.8G | — |
| `timestamp_cid_triggerType` | 35G | — |
| `cid_timestamp_triggerType` | 36G | — |
| `_id`(主键) | 8.5G | — |

#### 3. 优化方案: Bitmap Scan(B-Tree + BRIN 组合)
将原来的 4 个独立 B-Tree 索引替换为 **2 个索引 + BitmapAnd 位图合并**:

| 新索引 | 类型 | 大小 | 作用 |
|---|---|---|---|
| `cid_triggerType` | B-Tree | 2.9G | 精确匹配 cid + triggerType,返回行级位图 |
| `timestamp`(BRIN) | BRIN(pages_per_range=128) | ~10M | 按时间范围过滤,返回块级位图 |

**原理**: PostgreSQL 对两个索引扫描的位图做 AND 运算,只读取同时满足两个条件的数据页,再 Recheck 精确筛选。

#### 4. BRIN `pages_per_range` 参数实验

| pages_per_range | 索引大小 | BRIN 扫描 | Recheck 移除行 | 总执行时间 | 结论 |
|---|---|---|---|---|---|
| **64** | 20M | 456ms(↑25.6%) | 29 行(↓96%) | **39,520ms**(↑390%) | 精度最高但随机 I/O 暴增,不可用 |
| **128**(默认) | 10M | 363ms | 775 行 | **8,046ms** | 平衡点 |
| **256** | 5.2M | 248ms(↓31.6%) | 107 行(↓86%) | **7,949ms**(↓1.2%) | 略优,物理 I/O ↓9.3% |

**结论**: 默认 128 或略大(256 以内)在当前数据分布下最合适。pages_per_range=64 虽然精度最高(Recheck↓96%),但元数据翻倍导致 BitmapAnd 成为性能黑洞。

#### 5. 服务器参数调优

| 参数 | 原值 | 优化值 | 效果 |
|---|---|---|---|
| `shared_buffers` | 128M | **6G**(25% of 24G) | 更多数据/索引页驻留内存,减少磁盘 I/O |
| `effective_cache_size` | 4G | **12G**(50% of 24G) | 优化器更倾向使用 Index Scan 而非 Seq Scan |
| `work_mem` | 4M | **16M** | **关键**: 消除有损位图(lossy bitmap) |

**`work_mem` 4M→16M 的核心发现**:
- **4M**: 位图退化为有损模式 — `exact=1880` + `lossy=5215` 页,Recheck 移除 **47,374 行**
- **16M**: 全部精确位图 — `exact=7111` 页,Recheck 移除 **775 行**
- 避免扫描 5215 个有损页(~41.72MB I/O),CPU 和缓存效率均显著提升
- 注意: `work_mem` × `max_connections` 是实际峰值内存,需权衡(100 连接 × 16M = 1.6G)

#### 6. 最终效果
| 指标 | 优化前 | 优化后 | 提升 |
|---|---|---|---|
| 索引总大小 | **71G**(2 个 B-Tree) | **~3G** | **↓95.8%** |
| 自定义报表首次查询 | 30s+ | **~8s** | **↓73%**,更稳定 |



### RDU 模拟器

> 代码仓库: `D:\idea_workspace\rdu-simulator`
> 技术栈: Spring Boot + Netty TCP + MongoDB
> 我接手并贡献了 3 个 commit(+1,228 行),覆盖信号生成重构、多站点架构、加密兼容

#### 1. 项目定位
RDU 模拟器是一个内部测试工具,用 Netty 模拟真实的 RDU 硬件设备。当 SI 平台向模拟器发送 TCP 请求(端口 13392)时,模拟器从 MongoDB 读取设备配置,生成模拟的实时信号数据返回,使得开发和测试不依赖实体硬件。

#### 2. 我的贡献

##### (1) 实时信号生成逻辑重构 `f5a9a1d` (+266/-43)
- **问题**: 原实现只支持简单递增值,无法模拟真实信号分布(如温度在 20-30 范围内浮动)
- **方案**: 重构 `LiteDatapointConfig`,支持**三种值类型**的独立生成策略:
  - `Numeric`(浮点): 在 [min, max] 范围内随机生成,保留两位小数
  - `Integer`(整数): 在 [min, max] 范围内随机整数
  - `Enumeration`(枚举): 从配置的枚举索引列表中随机选取
- **配置驱动**: 新增 `pNameValues` 配置项,支持通过配置文件覆盖特定信号点的值范围(如 `val_temp Float 20 30`),无需改代码
- **时间感知**: 新增基于启动时间差的值生成模式(用于模拟累计型信号如 `enrg_accumulated`)

##### (2) 多站点模拟架构 `976afc4` (+424/-178)
- **问题**: 原架构一个模拟器实例只能模拟一个 RDU 站点,测试多站点场景需要启动多个进程
- **方案**: 设计 `SimulatorConfigs` + `SiteConfig` 配置体系,**一个进程模拟多个 RDU 站点**:
  - 每个站点绑定独立 IP(利用机器多网卡/虚拟 IP)
  - 每个 IP 启动独立的 Netty `ServerBootstrap`,监听同一端口 13392
  - 每个站点可配置独立的信号点覆盖规则(`pNameValues`)
  - 新增 YAML 配置(`application-cluster.yaml`)支持多站点声明
- **优雅关闭**: 注册 JVM ShutdownHook,确保所有 Netty Channel 正确关闭

##### (3) SI4.1 兼容升级 `85ef21e` (+538/-72)
- **AES 加密兼容**: 实现 `CryptoManager`(247 行),支持基于 seed 的 AES-256-GCM 加密/解密:
  - PBKDF2WithHmacSHA256 密钥派生(600,000 次迭代)
  - seed 混淆/反混淆(多步异或 + 位移 + 盐值混合)
  - 用于解密 MongoDB 连接密码,使模拟器能连接 SI4.1 加密后的数据库
- **字符串信号协议**: 新增 `RealtimeSignalString` / `RealtimeSignalStringResponse`,兼容 RDU 3.0.2 版本的字符串类型信号协议(原版本只支持数值型)
- **Netty 升级**: 版本升级至 4.1.x,兼容 JDK 21

### 备份恢复

> 详细设计文档见 [`backup-restore/design/`](./backup-restore/design/)
> - `backup-restore#1.md` — 初版设计(2025.3.5): MongoDB→FerretDB 切换后备份方案选型 + 性能基准
> - `backup-restore#2.md` — 增强版(2025.8.26): 支持 Zero Engine 数据同步 + 跨机器恢复
> - `backup-restore-en#1.md` — 初版英文版(用于跨团队评审)

#### 1. 需求背景
SI4.0 将数据库从 MongoDB 切换为 FerretDB(PostgreSQL + DocumentDB 扩展),原有的 `mongodump`/`mongorestore` 不可用,需要重新实现备份恢复功能,保持与原有效果一致。

#### 2. 方案选型(三选一)
| 方案 | 技术 | 备份方式 | 核心指令 | 业务影响 |
|---|---|---|---|---|
| 方案一 | 直接压缩宿主机数据目录 | 物理备份 | docker stop/start + tar | 备份和恢复均需重启,服务不可用 |
| 方案二 | pg_dump / pg_restore | 逻辑备份 | docker exec + pg_dump/pg_restore | 不需重启,但恢复慢 + 索引重建 |
| **方案三(选用)** | **pg_basebackup** | **物理备份** | docker exec + pg_basebackup + tar | 备份不停机,恢复需重启 |

**选择方案三的理由**:
1. 方案二在 1kw 数据量下恢复耗时 10m52s(是方案三的 **16 倍**),且 2kw 数据重建索引还需额外 13 分钟
2. pg_basebackup 是 PostgreSQL 官方提供的工具,比手动压缩数据目录更可靠
3. 方案三可在不关闭容器的情况下备份,业务影响更小

#### 3. 性能基准

**测试环境**: 物理机(4 核 Xeon E-2124 @ 3.30GHz, 15GB 内存, 1.5T 机械硬盘)

| 数据量 | 备份时间 | 恢复时间 | 备份包大小 |
|---|---|---|---|
| 少量(2 RDU) | 22s | 6s + 40s(容器重启) | — |
| 1025w 行 | 1m42s | 1m21s + 40s | 1.3G |
| 2025w 行 | 4m1s | 3m45s + 40s | 1.8G |
| 4167w 行 | 8m23s | 7m58s + 40s | 2.9G |
| **4kw(程序执行)** | **10min** | **10min** | — |
| **1.2 亿(R250)** | **28min** | **20min** | **8.8G** |
| **10 亿(R350)** | **3h32min** | **3h35min** | **56.1G** |

#### 4. 增强版(#2): Zero Engine 数据同步
SI4.0.1 新增需求:恢复时需同步 Zero Engine 端数据 + 支持跨机器恢复。

**核心流程**(si-portal 重启时):
1. 检测临时文件 → 开始同步流程
2. 清除 ZE 端: 设备(DB+缓存)、驱动三元组、活跃告警 + 停止监控插件
3. 从 SI 数据库获取并依次下发: 驱动 → SNMP 设备 → 活跃告警
4. 启动监控插件,删除临时文件
5. 异常全部捕获,不影响 SI 启动

**跨机器恢复新增**: 备份时额外保存 `.ferret_password`,恢复时覆盖目标机器的数据库密码配置。

**设备发现相关数据**: 选用方案 a — 保存客户上传的驱动压缩包,恢复后由客户手动按顺序上传(避免新增接口的复杂度)。