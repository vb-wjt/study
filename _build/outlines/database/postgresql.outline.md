<!-- auto-generated from database\postgresql.xmind by _build/extract-xmind.ps1, do NOT edit -->

# postgresql

- 1. 基本信息
  - 1. 对象-关系型数据库
    - 1. 可以自定义数据类型
      - 1. 分类
        - 1. 复合类型
          > note: -- 创建自定义类型 CREATE TYPE address AS (     street text,     city text,     zipcode varchar(10) );  -- 在表中使用 CREATE TABLE customers (     id serial PRIMARY KEY,     name text,     home_address address,  -- 直接使用自定义类型     shipping_addresses address[]  -- 地址数组 );
          - 将多个固定, 相关的属性作为一个整体管理, 类似于结构体
        - 2. 枚举类型
          > note: CREATE TYPE name AS ENUM('value1', 'value')
          - 存储有限且固定的状态值, 且内部存储为整数的标签,比如订单状态, 0 代表 pending 
        - 3. 基础类型
          - 通过C语言编写输入\输出函数等, 并调用 CREATE TYPE 命令
          - 完全自定义的内部二进制格式，存储在数据页面中
          - 适用于需要极致性能或存储特殊格式数据的场景, 如 GIS 数据，加密数据
        - 4. 域(Domain)
          > note: CREATE DOMAIN name AS data_type[CONSTRAINT ...]
          - 不改变底层存储格式，是在现有类之上增加约束(如 CHECK)
          - 常用于为常用类型添加统一的业务规则约束，如 email 类型, positive_integer
      - 2. 优势
        - 1. 提升模型内聚性
          > note: 将 address(街道, 城市, 邮编) 作为一个整体，比分散成三列更符合业务思路，减少表列数，使主表结构更简洁
        - 2. 确保数据一致性
          > note: 可以为复合类型创建约束，或通过域类型为整个组织定义统一的数据验证规则(如所有电话号码必须是特定格式)
        - 3. 简化查询与传递
          > note: 在函数或应用层之间传递一个复合类型参数，比传递多个独立参数更清晰, 也便于未来扩展 (给复合类型添加新字段，不影响函数签名)
        - 4. 与 JSONB 协作
          > note: 可以将外部 JSON 数据直接转换为预定义的复合类型，既利用了JSON的灵活性，又保证了数据库内部结构的严谨性
      - 3. 弊端
        - 查询粒度变粗
          - 单独查询或更新address中的city，语法会稍显复杂（使用 (列名).字段名 的方式）。如果这类操作非常频繁，可能需要重新考虑是否拆表
        - 索引限制
          - 默认情况下，不能直接为复合类型内的某个字段创建索引。如果需要频繁按城市查询，解决方案是：1）使用表达式索引：CREATE INDEX ON users ((home_address).city);；2）生成列（Generated Column）。
        - 应用层兼容性
          - 并非所有ORM或数据库驱动都对PostgreSQL的复合类型有完美支持，可能需要一些额外配置或使用原生SQL。
        - 过度设计风险
          - 如果一个复合类型的字段未来变化可能性很大，或者需要被大量独立查询，那么直接将其设计为关联的表可能更灵活。
    - 2. 表继承
      > note: -- 父表 CREATE TABLE vehicles (     id serial PRIMARY KEY,     name text,     max_speed integer );  -- 子表继承 CREATE TABLE cars (     fuel_type text ) INHERITS (vehicles);  CREATE TABLE trucks (     load_capacity integer ) INHERITS (vehicles);  -- 查询会包含所有子表数据 SELECT * FROM vehicles;
      - 1. 行为解释
        - 0. 创建新表(子表) 的时候，允许继承一个或多个现有表(父表)的所有列
        - 1. 物理存储
          - 插入数据的时候，会把所有字段都写到子表里面；父表通常是一个没有数据的空壳
        - 2. 查询行为
          - 查询父表时, Postgrsql 会自动执行 UNION ALL 操作, 将所有子表的数据合并返回，"多态查询"
        - 3. 约束与索引
          - 1. 主键/唯一约束
            - 必须在每个子表上单独定义, 无法在父表上定义并让子表继承
          - 2. 索引
            - 每个子表需要为自己创建独立的索引, 父表的索引不会自动应用于子表
      - 2. 优势
        - 1. 实现数据共享与差异化
          > note: 完美适用于“是一个（IS-A）”关系。所有账户共享id和created_at，但用户和商家有各自特有的字段。避免了为公共字段在多个表中重复定义和维护。
        - 2. 简化数据审计
          > note: 所有对accounts表的查询自动覆盖所有类型的账户，便于全局统计和管理
        - 3. 数据分区(旧方式)
          > note: 在PostgreSQL原生声明式分区（PARTITION BY）出现之前，表继承是实现表分区的一种手段。例如，按日期范围创建子表。（现在不推荐，应使用声明式分区）。
      - 3. 弊端
        - 1. 外键约束失效
          - 外键无法引用父表。例如，无法创建一个指向 accounts 的外键，因为物理数据分散在子表中。
            > note: 这是最大的设计限制。 如果子表数据需要被其他表引用，必须在每个子表上分别创建外键，或放弃使用继承，改用组合关系（accounts表加type列）。
        - 2. 唯一性保证复杂
          - 无法在父表account层面保证email在所有账户类型中唯一。users和merchants表可以有相同的email
            > note: 如果需要全局唯一，必须在应用层处理，或使用触发器在所有子表间检查
        - 3. 查询计划可能低效
          - 对父表的查询会扫描所有子表。如果子表很多或数据量巨大，性能可能很差。优化器可能无法生成最优计划
            > note: 确保每个子表都有合适的索引。对于复杂的分析查询，可能需要明确使用UNION ALL结合子查询来替代父表查询。
        - 4. 架构复杂度激增
          - 数据分散存储，理解数据全貌变得更难。备份、恢复、权限管理（需要为每个子表单独授权）都更复杂。
            > note: 仅在模型清晰、收益明确时使用。为所有子表制定统一的维护策略。
        - 5. ORM与工作支持差
          - 大多数ORM对继承映射支持不佳，容易产生混乱的SQL。数据库管理工具对继承关系的展示和操作也不直观。
            > note: 深度依赖ORM的项目应谨慎。需要编写更多原生SQL，或在应用层做好抽象。
        - 6. 数据迁移与演进困难
          - 修改父表结构（如添加列）会级联到所有子表。如果某个子表冲突，操作会失败。迁移脚本更难编写和测试。
            > note: 尽早稳定数据模型。修改父表结构前，必须评估对所有子表的影响。
      - 4. 多层继承
        - 递归使用 INHERITS
        - 弊端
          - 查询性能急剧下降
            > note: 查询最顶端的父表（如 SELECT * FROM a;）时，数据库需要递归扫描整个继承树下的所有表（a, b, c, d）。层级越深、子表越多，执行计划越复杂，性能开销越大。
          - 约束管理近乎瘫痪
            > note: 主键、唯一约束、外键不会自动跨越继承层级传播。若要保证数据完整性，必须在继承链上的每一个表中重复定义并维护这些约束，极易出错且效率低下。
          - 结构演进困难
            > note: 修改顶层父表的结构（如添加列）会级联到所有后代子表。若某个中间子表（如 b）有冲突或需要特殊处理，整个修改将失败，导致架构僵化。
          - 应用层逻辑复杂化
            > note: ORM工具对多层继承的支持普遍不佳。业务代码需要处理多态查询、数据归属判断（使用 tableoid 系统列），极大增加开发复杂度。
          - 数据迁移与归档不便
            > note: 无法方便地将某个中间层级的数据“整体”迁移或归档，因为数据物理分散在各个末端子表中。
        - 主流方案
          - a. 单层继承 + 组合关系(最常用)
            > note: -- 主表，存储公共属性和类型 CREATE TABLE entities (     id SERIAL PRIMARY KEY,     type VARCHAR(20) NOT NULL, -- 'USER', 'ADMIN', 'GUEST'     created_at TIMESTAMP DEFAULT NOW() ); -- 详情表，存储特有属性，通过外键关联 CREATE TABLE user_details (     entity_id INT PRIMARY KEY REFERENCES entities(id),     email VARCHAR(100) UNIQUE,     phone VARCHAR(20) ); CREATE TABLE admin_details (     entity_id INT PRIMARY KEY REFERENCES entities(id),     department VARCHAR(50),     permission_level INT );
            - 创建一个主表存储所有实体的公共属性和类型标识字段, 为不同子类型创建独立的详情表，通过外键与主表关联
              - 数据完整性约束简单有效，查询灵活（可轻松JOIN获取完整信息），扩展性好，ORM支持完美
          - b. 声明式分区
            > note: CREATE TABLE measurement (     city_id INT,     logdate DATE,     peaktemp INT ) PARTITION BY RANGE (logdate); -- 声明为分区父表  CREATE TABLE measurement_2023 PARTITION OF measurement     FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
            - 定义一个分区父表，并按照规则(RANGE,LIST,HASH)创建分区子表。分区子表不继承父表约束和索引，需单独定义
              - 专为数据分片优化，查询时能自动进行约束排除，只扫描相关分区，性能远超继承查询。
          - c. JSON列 + 约束(灵活模式)
            > note: CREATE TABLE products (     id SERIAL PRIMARY KEY,     name TEXT,     type VARCHAR(20) NOT NULL,     attributes JSONB, -- 存储不同类型的特有属性     CONSTRAINT valid_attributes CHECK (         (type = 'book' AND attributes ? 'isbn') OR         (type = 'clothing' AND attributes ? 'size')     ) );
            - 在主表中增加一个 JSONB 字段, 将特有属性存入其中, 可配合 CHECK 约束验证其结构
    - 3. 函数和操作符重载
      > note: -- 自定义复数类型 CREATE TYPE complex AS (r float8, i float8);  -- 自定义加法操作符 CREATE FUNCTION complex_add(complex, complex) RETURNS complex AS $$     SELECT ($1.r + $2.r, $1.i + $2.i)::complex; $$ LANGUAGE SQL;  CREATE OPERATOR + (     leftarg = complex,     rightarg = complex,     procedure = complex_add );  -- 使用自定义操作符 SELECT (1.0,1.0)::complex + (2.0,3.0)::complex;
    - 4. 复杂对象处理
      - 比如：存储和查询整个JSON文档(JSON类型)
        > note: -- 存储整个JSON文档(JSONB类型) CREATE TABLE products (     id serial PRIMARY KEY,     attributes jsonb  -- 支持索引和深度查询 );  -- 查询JSON内部字段 SELECT attributes->>'color' FROM products  WHERE attributes @> '{"category":"electronics"}';
  - 2. 后台机制
    > note: 后台进程一览: SELECT * FROM pg_stat_activity WHERE backend_type NOT LIKE 'client%';
    - autovacuum
      - 功能
        - 回收死元组(Dead Tuples)
          - 删除/更新(先走删除再插入)行并不会立即物理删除，而是打上“删除标记”, autovacuum 会清理这些无效数据，释放空间
        - 防止表膨胀(bloat)
          - 如果长时间不清理死元组，表和索引会变得越来越大，性能急剧下降
        - 更新统计信息(ANALYZE)
          - 自动收集列的分布，频率，null比例，供优化器生成更优的执行计划
        - 防止事务ID wraparound
          - 使用 32-bit 事务ID, 老事务长时间不清理会导致事务ID 回绕，造成数据不可见甚至数据损坏。autovacuum 会自动处理冻结(freeze)旧事务
      - 触发条件
        - 当 表上修改行数 >= vacuum_threshold + vacuum_scale_factor * 表总行数 时就会触发一次 autovacuum
        - 默认参数如下，并且提供表级别的阈值设置autovacuum_vacuum_threshold = 50 autovacuum_vacuum_scale_factor = 0.2
          - 一个有 10w 行的表，只要更新或删除了 20050行，就会触发一次
      - 默认开启
        - 关闭的话, 会
          > note: 查询越来越慢：因为死元组越来越多，扫描代价变高。 表越来越大：死数据不清理，膨胀严重。 事务 ID 溢出：非常致命，会强制关闭数据库防止损坏。 统计信息不准：查询计划变差，性能下降。
      - 监控和调优
        - 查询运行状态
          > note: -- 查看表的最后一次 autovacuum 和 analyze 时间 SELECT relname, last_autovacuum, last_autoanalyze FROM pg_stat_user_tables ORDER BY last_autovacuum DESC NULLS LAST;   -- 观察当前有哪些 autovacuum 正在运行 SELECT * FROM pg_stat_activity WHERE query LIKE '%autovacuum%';
          - pg_stat_user_tables
          - pg_stat_all_tables
          - pg_stat_activity
        - 记录日志
          - log_autovacuum_min_duration = 0 可以记录所有 autovacuum 执行日志，方便分析
        - 大数量表或高频更新表可以把阈值调小，让 autovacuum 更早地介入清理
          > note: 如: ALTER TABLE big_table SET (   autovacuum_vacuum_threshold = 1000,   autovacuum_vacuum_scale_factor = 0.01,   autovacuum_analyze_threshold = 1000,   autovacuum_analyze_scale_factor = 0.01 );
    - bgwriter
      - background writer
        - postgresql 的内存脏页异步刷盘器
      - 把共享缓冲区(shared_buffers) 里面的脏页写入到磁盘的对应物理文件中
      - 若不及时写入磁盘，缓冲区会被脏页占满，导致新查询需要等待写入，卡住整个数据库
      - 通过 postgresql 的 I/O 子系统处理，不是直接交给操作系统
      - 关键参数
        > note: # 每次唤醒时写入的最大脏页数 bgwriter_lru_maxpages = 100      # 默认 100 页（如 800KB/页 → 80MB/次）  # 两次写入的间隔时间（毫秒） bgwriter_delay = 200             # 默认 0.2 秒  # 脏页数量超过缓冲区比例时，强制增大写入量 bgwriter_lru_multiplier = 2.0    # 动态调整因子
  - 3. 参数
    - fillfactor
      - 控制每个页(堆文件中的物理页，默认为 8kb) 在初次写入数据时预留多少空间，为了给将来的更新/扩展留余地，减少行迁移和页分裂
      - 行迁移: 在更新的时候，会先把当前行标记为删除(逻辑删除), 等后台机制auovacuum真正物理删除，然后再插入一条更新后的。这个时候：
        - 如果当前页还有空间，会在当前页插入，不会出现行迁移问题
        - 如果当前页没空间了, postgresql 会把旧行转为一个 行指针，指向新页上的行；同时原页上的主键索引仍然指向旧行；
          > note: 堆表： [Page 1 (8KB)]  ├─ Tuple A  ├─ Tuple B (after update) ─→ 新页 Page 3  └─ TOAST Pointer（行迁移）  SELECT * FROM heap_page_items(get_raw_page('your_table', 0)); 可以查看哪些行有 multiple versions, 哪些位置是 dead tuple
          - 这时，查询需要 索引指向旧位置 + 跨页 + 跳转才能拿到更新后的数据，性能下降
      - 页分裂: 是关于索引结构(尤其是 B-Tree);
        > note: 索引（B-tree）：          [Root Page]            /    \   [Page 1 (满)]  [Page 2]       │   ↑       └────── Page split → 结构变大
        - 当往索引页插入新键时，如果页空间满了， postgresql 会:  1. 创建一个新的页；  2. 把原页中一部分 key 搬到新页;  3. 更新父节点指向两个子页，即分裂
        - 问题:
          - 插入时需要大量的 page copy + update 降低索引局部性（缓存不命中） 树高度变大 → 查询慢 对于**随机写入的索引字段（UUID, hash等）**影响尤为严重
    - shared_buffers
      - 触发加载条件
        - 1. 数据页首次被查询
        - 2. 预读机制 (Sequential Scan)
        - 3. 后台写入器 (BgWriter) 预热
        - 4. 手动 pg_prewarm
      - 缓存淘汰机制
        - 使用 Clock-sweep 算法(改进的 LRU)
          > note: 每个缓冲页有usage_count计数器（0-5） 访问时usage_count增加（上限5） 淘汰时扫描并减少计数，优先淘汰计数为0的页
      - 缓存页, 8k/页
      - 缓存内容
        - 表数据页
          - 表的行数据
            - base/16384/12345
        - 索引页
          - B-Tree/GIN 等索引结构
            - base/16384/12345_idx
        - 特殊文件
          - FSM(空闲空间映射)，VM(可见性)
            - e.g.  12345_fsm
  - 4. 概念
    - 脏页
      - 数据修改操作(添加/删除/更新)、系统操作(索引重建,表优化(vacuum full), 统计信息收集的等)等，实际发生在内存中，磁盘原始数据未变，这种数据页叫脏页
      - 关键特性
        - 异步持久化
          - 修改后不立即写盘，后台批量写入
        - 写放大优化
          - 单页多次修改只需写入一次磁盘
        - 内存效率
          - 支持事务回滚和 MVCC 可见性检查
      - 作用
        - 减少磁盘I/O
          - 将多次修改合并为单次写入
        - 提示并发性能
          - 写操作不阻塞读操作
        - 崩溃恢复基础
          - 结合 WAL 保证数据一致性
    - checkpoint
      - 检查点，即数据库的存档点
        - 强制所有脏页写入磁盘的系统事件，并在 WAL 中创建恢复标记点。确保特点时间点前的所有修改已落盘
      - 触发
        - 定时触发
          - checkpoint_timeout(默认 5min)
        - WAL 满了
          - max_wal_size(默认 1GB)
        - 手动命令
          - checkpoint sql 命令
        - 系统关闭
          - 关闭数据库前自动执行
        - 在线备份
          - pg_start_backup() 时触发
      - 类型
        - Spread Checkpoint
          - I/O 平滑分发(默认)，适用于生产环境
        - Full Checkpoint
          - 立即写入所有脏页，适用于维护操作/低负载时段
        - Restart Checkpoint
          - 服务重启时执行，适用于系统关闭/备份
      - 核心作用
        - 崩溃恢复锚点
          - 确定 WAL 重放起始位置
        - WAL 空间回收
          - 清理不再需要的日志段
        - 数据持久化
          - 确定关键点数据落盘
        - 性能优化
          - 避免重启后长时间恢复
      - 与 bgwriter
        - graph TD     W[写入操作] --> D[产生脏页]     D --> BG[bgwriter 持续写入]     D --> C[检查点强制写入]     C --> R[创建恢复点]     R --> WAL[回收旧WAL文件]
- 2. 数据类型
  - 1. 数值类型
    - 整型: SMALLINT, INTEGER, BIGINT
    - 任意精度: NUMERIC(p, s)
    - 浮点型: REAL, DOUBLE PRECISCION
    - 序列类型: SMALLSERIAL, SERIAL, BIGSERIAL(自动递增整数, 常用于主键)
  - 2. 字符串类型
    - VARCHAR(n), CHAR(n), TEXT
  - 3. 时间/日期类型
    - DATE, TIME, TIMESTAMP,INTERVAL 
  - 4. 布尔类型
    - BOOLEAN
  - 5. 二进制类型
    - BYTEA
  - 6. 枚举类型
    - ENUM
  - 7. 几何类型
    - POINT, LINE,CIRCLE, POLYGON
  - 8. 网络地址类型
    - INET, CIDR, MACADDR
  - 9. JSON/JSONB 类型
    - JSON: 存储 JSON 数据(不优化, 保留格式)
    - JSONB: 二进制格式 JSON(支持索引,推荐使用)
      - 核心能力
        - 1. 数据存储: 自由嵌套(支持所有数据类型)
          > note: JSONB 列可以存储 JSON 标准支持的所有数据类型：字符串、数字、布尔值、null、对象（字典）和数组。这些类型可以任意嵌套。  CREATE TABLE user_profiles (     id SERIAL PRIMARY KEY,     name TEXT,     preferences JSONB -- 用户偏好设置 );  INSERT INTO user_profiles (name, preferences) VALUES ('Alice', '{"theme": "dark", "notifications": {"email": true, "sms": false}, "tags": ["admin", "editor"]}'::jsonb), ('Bob', '{"theme": "light", "settings": {"language": "zh-CN", "timezone": "Asia/Shanghai"}}'::jsonb);
        - 2. 强大查询: 丰富操作符
          - (untitled)
            > image: xap:resources/66a3b67793722150668dae7de00390e6cfad329ff440a53f8f23155ffd40ce3d.png
        - 3. 索引: 创建 GIN 索引, 倒排索引来提升查询性能
          > note: -- 为 preferences 列创建默认的 GIN 索引（支持 @>, ?, ?|, ?& 操作符） CREATE INDEX idx_user_profiles_preferences ON user_profiles USING GIN (preferences);  -- 创建更精细的 JSON 路径表达式索引 CREATE INDEX idx_user_profiles_theme ON user_preferences USING GIN ((preferences->'theme'));
          - 可创建特定路径的 GIN 索引
        - 4. 修改与生成函数
          > note: -- 创建一个 JSONB 对象 SELECT jsonb_build_object('name', 'Alice', 'age', 30);  -- 将多行结果聚合为一个 JSONB 数组 SELECT jsonb_agg(name) FROM user_profiles;  -- 修改 JSONB 数据（PostgreSQL 14+ 支持 jsonb_set） UPDATE user_profiles  SET preferences = jsonb_set(preferences, '{theme}', '"light"') WHERE name = 'Alice';
  - 10. 数组类型
    - 任意基础类型的一维或多维数组(如 INT[], TEXT[][])
  - 11. 范围类型
    - INT4RANGE, TSRANGE
  - 12. UUID类型
    - 存储全局唯一标识符(如a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11 )
  - 13. 全文搜索类型
    - TSVECTOR, TSQUERY
  - 14. 其他特殊类型
    - XML: 存储XML数据, HSTORE: 键值对存储(类似简化JSON), OID: 对象标识符(系统内部使用)
  - 15. 扩展类型支持
    - PostGIS, citext(不区分大小写的文本类型)
- 3. 索引
  - 1. 分类
    - B-Tree
      - 默认索引(create index)
      - 可以处理某种顺序排序的数据的相等和范围查询
        - 操作符: <  <=  = >= >
        - between in 等
        - 在索引字段上 is null    is not null
      - 模糊匹配
        - col like 'foo%'
        - col ~ '^foo'
        - 但不能是 col like '%foo'
    - Hash
      - 从索引列的值生成 32-bit 的 hash 值
      - 当索引列涉及使用相对运算符的比较时，查询规划期都会考虑使用哈希索引
    - GiST
      - 不是单一类型的索引，而是一个可以在其中实现许多不同索引策略的基础结构
      - 支持这些运算符的索引查询:  <<   &<   &>   >>   <<|   &<|    |&>  |>>   @>   <@   ~=   &&
    - SP-GiST
      - 与 GiST 一样，提供了支持各种搜索的基础结构
      - 允许实现各种不同的非平衡磁盘数据结构
      - 支持这些运算符的索引查询:  <<   >>   ~=   <@   <<|    |>>
    - GIN
      - GIN倒排索引。适用于包含多个组件之的数据值，比如数组
      - 包含每个组件值的单独条目，并且可以有效地处理测试特点组件值是否存在的查询
      - 支持这些运算符的索引查询:  <@  @> =   &&
    - BRIN
      - Block Range INindexes, 存储有关存储在表中连续物理块范围中的值的摘要
      - 支持这些运算符的索引查询:  <  <=  =  >= >
  - 2. 复合索引
    - 目前只有 B-tree, GiST, GIN, BRIN 支持多键列索引
    - 一个索引最多有32列
    - 最左匹配原则
      - 在使用复合索引时，postgresql 只能从索引的最左列开始，按照顺序使用索引中的列进行查询优化；查询条件必须包含索引定义中的第一列(最左列)，才能有效利用该复合索引
      - 比如 CREATE INDEX idx_employee ON employees (last_name, first_name, department);
        - 有效使用索引
          > note: 全列匹配(最佳) -- 使用全部索引列（顺序不重要，查询优化器会调整） SELECT * FROM employees  WHERE last_name = 'Smith'    AND first_name = 'John'    AND department = 'IT'; 最左匹配 -- 使用索引前两列 SELECT * FROM employees  WHERE last_name = 'Smith'    AND first_name = 'John';  -- 仅使用索引第一列 SELECT * FROM employees  WHERE last_name = 'Smith'; 列前缀匹配(like) -- 可以使用索引（前缀匹配） SELECT * FROM employees  WHERE last_name LIKE 'Sm%';
        - 无法使用索引
          > note: 缺少最左列 -- 只使用到 last_name 索引（跳过了 first_name） SELECT * FROM employees  WHERE last_name = 'Smith'    AND department = 'IT'; 跳过中间列 -- 不会使用索引（缺少 last_name） SELECT * FROM employees  WHERE first_name = 'John'    AND department = 'IT'; 非前缀 like 查询 -- 不会使用索引（非前缀通配符） SELECT * FROM employees  WHERE last_name LIKE '%ith'; 范围查询后的列 -- 只能使用到 last_name 和 first_name 的索引 -- department 不能使用索引（因为 first_name 是范围查询） SELECT * FROM employees  WHERE last_name = 'Smith'    AND first_name > 'J'    AND department = 'IT';
  - 3. 覆盖索引
    - 把需要经常查询的字段也存储到索引里面，当命中索引的时候，不需要再通过 TID 去堆文件找需要查询的其他属性, 可以直接返回
    - 但是这些字段不参与索引排序，只是存在于索引中。目前只有 B-树类型的索引可以做。
    - 查询会更快(因为不需要回表)，但插入会变慢(因为需要多存储字段)，占用空间也会变大
    - CREATE INDEX idx_name ON table_name(filter_column) INCLUDE (return_column1, return_column2);
      > note: 比如: CREATE TABLE orders (     id SERIAL PRIMARY KEY,     user_id INT,     order_time TIMESTAMP,     total_amount NUMERIC );  经常执行的查询: SELECT order_time, total_amount FROM orders WHERE user_id = 123 ORDER BY order_time DESC LIMIT 10;  所以可以建立索引: CREATE INDEX idx_user_order_time ON orders(user_id, order_time DESC) INCLUDE (total_amount);  user_id, order_time 用来定位和排序(索引) total_amount: 作为返回字段存在于索引中，不参与排序 所以执行上面的查询的时候，可以只走索引，不访问堆文件
- 4. 索引数据结构
  - B-Tree
    - 平衡多路搜索树，实现上更接近于 B+ 树的变体
      - 1.  每个节点可以有多个子节点
      - 2. 每个节点有多个键，且键是有序的
      - 3. 所有叶子节点都在同一层(保证平衡)
        - 所有叶子节点到根节点的距离相同
      - 4. 只有叶子节点存储指向真实数据的指针(TID)
        > note: typedef struct ItemPointerData {     BlockIdData ip_blkid;  // 4字节 - 堆文件中的块号（区号）     OffsetNumber ip_posid; // 2字节 - 块内的元组偏移量（1~32767） } ItemPointerData;  堆文件存储路径 # 典型路径结构 $PGDATA/base/数据库OID/表文件OID # 示例： /var/lib/postgresql/12/main/base/16384/12345  -- 查询语句 SELECT * FROM users WHERE id = 100;  -- 访问流程 1. 在B-Tree索引中找到 TID=(42,3) (堆文件第42块, 第3行) 2. 从共享缓冲池检查块42是否在内存    - 若在内存：直接读取    - 若不在：从磁盘加载到缓冲池 3. 定位块42的第3个元组 4. 检查MVCC可见性
      - 5. 内部节点键值不重复出现
      - 6. 用双向链表连接子节点，便于范围扫描
    - 阶，决定每个节点的最大和最小分支树
      - Knuth定义(以最小度数t定义)
        - 每个内部节点的子节点数范围为  [t, 2t]
        - 每个节点(除了根)的键的数量范围为 [t-1,  2t-1]
        - 更适合数学分析和证明，在算法分析中更有用
      - 以最大子节点数定义(记为 m)
        - 节点最多可以有多少个子节点的数据为 m
        - 每个内部节点的子节点数范围为  [m/2, m]
        - 每个节点(除了根)的键的数量范围为 [1,  m-1]
        - 更能直观反映实际存储限制，工程师更关心"一个节点最多能有多少个子节点"
    - 比如:
      > note: Level 0 (Root):                     [20, 40]                                              /     |     \ Level 1:                      [5, 10] [25, 30] [45, 50, 60]                                    /   |   \         ... Level 2 (Leaf):     [1,2] [6,7,8] ...   [55,58,59,61]
    - 十亿数据
      > note: 数据库每页页大小:  默认为 8kb 每个索引项(key+point) 的大小:  保守估计为 32kb (key: 通常是整数，字符串； pointer: 指向下一个页面的页号(ItemPointer))  (以最大子节点数定义(记为 m)) 一个节点最多容纳  8192(8kb) / 32 约等于 256项 所以 postgresql 的 B- 树阶数大约是 256 个 每个节点最多 256 个键 最多 257 个子节点指针  当有 10亿数据， 深度 = log₂₅₆(1,000,000,000) ≈ log₂(1e9) / log₂(256)      ≈ 30 / 8      ≈ 3.75 层 也就是说，从根节点出发，最多只需要读取 4页磁盘数据，就能查到里面任一条数据
    - B+树，B-树，postgresql B-树
      - (untitled)
        > image: xap:resources/7e18a8f2f7d980439e4a9fd02cb76c19456beaac7747bca05772f817017d124d.png
  - hash
    - 将索引键值通过哈希函数转换为一个固定长度的哈希码，然后将这些哈希码映射到特定的桶(bucket)中
    - 每个桶中会保存指向实际数据行的指针(TID)
    - 组成
      > note: [ Meta Page ]      |      ├── Bucket 1: [HashCode1 | TID] -> [overflow page] -> ...      ├── Bucket 2: [HashCode2 | TID] -> ...      ├── ...      └── Bucket N: ...
      - 1. Meta Page(元信息页)
        - 页面号 = 0
        - 包含整个索引的信息： 哈希桶总数 溢出页信息 索引版本 页面大小、填充因子等参数
      - 2. Bucket Pages(桶页)
        - 每个桶是一个或多个页面(如页 1,2,3...)
        - 每个桶保存多个条目(哈希值(hashcode) + 对应的数据项位置(TID))
      - 3. Overflow Pages(溢出页)
        - 当某个桶空间不够时，会链接一个或多个溢出页组成链表(类似链式哈希)
        - Postgresql 使用链表指针结构维护溢出页
    - 查询流程
      > note: 以 WHERE col = 'abc' 为例： PostgreSQL 计算 hash('abc')，得到一个哈希码 h 根据哈希码 h 映射到某个桶（如桶号 = h % bucket_count） 进入桶页，查找匹配的哈希码和原始键值（需要回表验证原始值，避免哈希冲突误匹配） 找到 TID，访问 heap table 中的 tuple 'abc'     ↓   hash('abc') → h = 0xA1B2C3D4     ↓   bucket_id = h % N = 212     ↓   → 找到 bucket 212     ↓   → 扫描所有哈希码为 h 的条目     ↓   → 取出 TID（如 (5,13)）     ↓   → 回表访问 heap table 页 5 的第 13 条记录     ↓   → 验证 username == 'abc' → 命中
    - (untitled)
      > image: xap:resources/02914b71047e1f211f224248624ba71d73be2ce6ee44ecfdb3233b73af4475b4.png
  - GiST
    - Generalized Search Tree, 通用搜索树，是一种索引结构框架，通过插件定义行为来支持多种复杂数据类型的索引
    - 支持：模糊匹配(like, near),  多维数据(几何/地理)，范围查询(区间，时间)，相似性匹配(全文搜索)
    - N 叉树，多路平衡树
      - 每个节点保存一组 <键盘，指针>对
      - 内部节点保存的是键的 "总结信息" 而不是具体值(如包围盒，区间范围)
      - 叶子节点才保存真正的键(或键的近似值)和TID(指向堆文件的位置)
    - 提供5个接口，供数据类型插件实现
      > image: xap:resources/4a630d28a57f4842d3420c6949c8921750abf3828e2b3136f9cb69a3aff30581.png
    - 执行查询
      > note: 过程如下: 从根节点开始，找到所有可能重叠的内部节点(根据 bounding box) 进入相应子树，重复以上过程，知道叶子节点 在叶子节点执行实际的匹配判断(用 consistent) 返回匹配 TID -> 回表取数据
  - SP-GiST
    - Space-Partitioned Generalized Search Tree, 空间分区的通用搜索树，高级索引框架，专为可空间分割的数据类型涉及
    - 非平衡树，支持多种划分策略
      - 每个节点划分空间/数据范围，叶子节点存储 TID，每条路径是一次数据"判定"结果(如左/右, 子串分裂，坐标比较等)
      - 插件式： 插件决定划分规则，匹配逻辑等
      - 典型结构:  k-d 树(k-dimensional tree), 四叉树(QuadTree), 前缀树(Trie)
    - 提供5个接口，供数据类型插件实现
      > image: xap:resources/5eaa546a9215c1e8d17753aad6d4a5f1254bdc466feb68a326a7603876e12db7.png
    - 使用场景与索引方式
      > image: xap:resources/e8a231ef27ef530a23e7643c30b02fd685f18eb81d69c00eae85b2ad007c2275.png
    - 执行查询
      > note: 从根节点开始，使用 inner_consistent 方法评估查询条件 递归遍历匹配的子节点 达到叶子节点后，用 leaf_consistent 验证最终匹配 收集所有匹配的 TID, 按需从堆中获取数据
    - 与 GiST 的对比
      > image: xap:resources/95a4364f2411c0191bcc9eca22de9e5f5f68144a418c2a0f52e9d4285afe8e90.png
  - GIN
    - Generalized Inverted Index, 通用倒排索引; 专为处理复合值设计(如数组，全文搜索，json等)
    - 组成
      - 主 B+ 树，存储所有的"键"(如每个词，数组元素，json字段名等)
      - Posting List 或 Posting Tree, 每个键指向一个 TID 列表，如果列表过长则用树管理；表示 “键” 在堆文件的第几页第几行出现了(出现了多次)
    - 支持的典型数据类型和操作
      > image: xap:resources/c7bc1b6b568589555bfb1141425e506061272a44d57c1d5607e3c81748764ce7.png
    - 提供供操作类实现的方法
      > image: xap:resources/b7d472843b14286179073bf75737e4c7bd6041af7ef593120e40dbe1dff6d576.png
    - 执行查询
      > note: 数组包含查询： 从查询条件提取搜索键(如数组元素) 在 GIN 的B树中定位每个键(顺序扫描，逐个匹配键是否满足条件) 获取每个键的 posting list 或 posting tree, 即 TIDs 按查询逻辑合并结果 从堆文件获取匹配的行
  - BRIN
    - Block Range Index, 块范围索引
      - 每个索引项存储一个范围的 (min_val, max_val, block_start, block_end)
        - (untitled)
          > image: xap:resources/82d8a63374b864cb4af35f75b024bb2e9bd88af61e4de40828937476b2cae296.png
      - 不是记录 “行在哪”，而是记录 每一段数据页的最大值和最小值
      - 比如，把 id 设置索引字段，0-127 页记录下这几页内的最小id 是1, 最大是 12800等
    - 索引占用的空间非常小(kb级)，相比于 B- Tree的 MB~GB 级别
    - 支持多种摘要策略
      > image: xap:resources/bda6b696791bf78b34e0200bf43eef212964fd85fb015909a696573a187dba96.png
    - 执行查询
      > note: where col = x: 查询某个条件(如 col = 2025) BRIN 判断哪些 page range 的 min-max可能命中 返回命中的 块范围编号 postgresql 顺序扫描堆里面的这些页 筛选真正匹配的行，返回
- 5. 大数量表优化
  - 1. 表设计
    - 整数类型选择适合大小的 interger(4bytes, 最大为21亿), bigint(8bytes)
    - 字符串 text无长度检查开销，灵活，性能略优；varchar(n), 不管值是否达到 n 都会占用满分配的空间n;
  - 2. 存储优化
    - autovacuum 调优, 相关信息见 <1.2 autovacuum>
    - fillfactor = 80  -- 页面只填充80%，留20%空间给更新, 相关信息见 <1.3 fillfactor>
      - 可以为 HOT(Heap-Only Tuple) 更新预留空间；减少页分裂和索引更新开销
      - 设为100%时更新可能导致更多页分裂
  - 3. 索引策略
    - 1. 可以适度使用 BRIN 索引, 相关信息见 <2.1 BRIN> && <3.BRIN>
    - 2. 可以适度使用覆盖索引, 相关信息见 <2.3 覆盖索引>
  - 4. 查询优化
    - 分页
      - 用索引先定位起始点后再分页
        > note: SELECT * FROM large_table ORDER BY id LIMIT 10 OFFSET 1000000; --- 需要先排序前 1,000,010 行 --- 执行计划: Limit  (cost=1000042.64..1000042.84 rows=10 width=36)   ->  Seq Scan on large_table  (cost=0.00..1000042.64 rows=1000000 width=36)  改为: SELECT * FROM large_table WHERE id > last_seen_id ORDER BY id LIMIT 10; --- 利用索引定位起始点 --- 执行计划: Limit  (cost=0.44..1.65 rows=10 width=36)   ->  Index Scan using pk_large_table on large_table  (cost=0.44..4.46 rows=10 width=36)         Index Cond: (id > 1000000)
    - 执行计划
      - EXPLAIN (ANALYZE, BUFFERS, VERBOSE)  SELECT * FROM large_table WHERE created_at > '2023-01-01';
        - 是最完整的调试 SQL 性能的写法
          > note: EXPLAIN： 获取查询的执行计划 ANALYZE:   实际执行查询，并输出真是耗时（不加只显示估算） BUFFERS:    显示磁盘和缓存的访问情况(IO 分析) VERBOSE:   显示更多的列信息，如表字段，Schema 细节等
      - created_at 有索引
        > note: 执行结果示例: Gather     Workers Planned: 2     Workers Launched: 2     -> Parallel Index Scan using idx_created_at on public.large_table          Index Cond: (created_at > '2023-01-01'::date)          Buffers: shared hit=10234 read=12   Planning Time: 0.237 ms   Execution Time: 35.212 ms    Gather：表示使用并行查询，主线程用于合并 worker 结果 Parallel Index Scan:  每个 worker 使用索引扫描执行子计划, 比 Seq  Scan 顺序扫描快很多 Workers Planned / Launched:  计划用 2 个 worker, 实际页都成功启动 Index Cond: 时间用到的索引条件 Buffers: shared hit=10234, read = 12 hit=10234, 这些页已经在内存(shared buffer)中，无需读磁盘 read=12, 读取了12页磁盘  Execution Time: 35.212ms, 从实际启动到执行结束的执行耗时 Planning Time: 0.237ms, postgresql 优化器在计划生成上的时间
      - created_at 无索引
        > note: 输出示例: Seq Scan on public.large_table  (cost=0.00..347362.50 rows=120000000 width=128)   Output: id, name, created_at, ...   Filter: (created_at > '2023-01-01'::date)   Rows Removed by Filter: 80000000   Buffers: shared hit=25000 read=104857 Planning Time: 0.352 ms Execution Time: 4523.132 ms  Seq Scan: 表示全表顺序扫描(没有使用索引) on public.large_table, 扫描对象是 public schema 下的 large_table cost=0.00..347362.50，估算成本区间: 从第一个元组开始扫描的成本(0.00) 到全部处理完的总成本(346362.50) rows=1.2亿, 优化器估算的匹配行数 width=128, 每行数据平均大小为 128字节，用于估算 I/O 体积 Output:id, name, created_at,...   VERBOSE模式下列出将要返回的列 Filter:(create_at > '2023-01-01'), 应用在每行的过滤条件 Rows Removed by Filter: 8kw, 有8kw行不满足条件，被过滤； hit=25000: 有 25000 个数据页已经在内存中 read=104857: 有 104857个数据页需要从磁盘读取  PlanningTime:0.352，优化器生成计划花费的时间(极少) Execution Time: 4523.132 ms, 整个查询实际执行完耗时
      - 当发现 Seq Scan 出现大表上时
        - 检查是否缺少索引
        - 确认统计信息是否最新(ANALYZE)
        - 检查 random_page_cost设置(SSD应设置为 1.1)
  - 5. 批量操作
    - 1. 批量插入
      - psql -c "COPY large_table FROM STDIN WITH (FORMAT csv)" < data.csv
      - 单条insert: 约100-200行/秒
      - 批量insert: 约5,000-20,000行/秒
      - COPY: 约100,000-500,000行/秒
    - 2. 批量更新
      - 通常一次设置为 1,000 - 10,000
        > note: DO $$ DECLARE     batch_size INT := 5000;     total INT := (SELECT count(*) FROM large_table WHERE condition);     batches INT := ceiling(total::float/batch_size); BEGIN     FOR i IN 0..batches-1 LOOP         RAISE NOTICE 'Processing batch % of %', i+1, batches;                  UPDATE large_table          SET column = new_value         WHERE id IN (             SELECT id              FROM large_table              WHERE condition             ORDER BY id             LIMIT batch_size OFFSET (i*batch_size)         );                  COMMIT;     END LOOP; END $$;
  - 6. 分区
    - 可以按照时间范围分区
      > note: 表创建: CREATE TABLE measurement (     id bigserial,     log_time timestamp,     data jsonb ) PARTITION BY RANGE (log_time);  子分区创建: -- 历史分区（每月） CREATE TABLE measurement_202301 PARTITION OF measurement     FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');  -- 当前分区（按周） CREATE TABLE measurement_current PARTITION OF measurement     FOR VALUES FROM ('2023-06-01') TO ('2023-06-08');  索引策略: -- 全局索引（跨分区） CREATE INDEX idx_measurement_id ON measurement (id);  -- 本地索引（每个分区独立） CREATE INDEX idx_measurement_logtime ON measurement (log_time);
  - 7. 关键服务器参数
    - 内存配置
      - shared_buffers = 8GB                # 总内存的25% effective_cache_size = 24GB         # 总内存的75% work_mem = 64MB                     # 每个排序/哈希操作可用内存 maintenance_work_mem = 2GB          # VACUUM等维护操作内存
        > note: 系统总内存为 32GB 的情况下: shared_buffers = 8GB;  postgresql 的主要内存缓冲区池，用于缓存表数据、索引页，减少对磁盘的读取； 默认值为 128MB;  通常建议为系统内存的 25%; 该设置对大数据量表:  有更多表页和索引页可以驻留在内存；减少物理 IO; 提高 select 性能(尤其是频繁访问的热数据)  effective_cache_size = 24GB postgresql 的优化器参考值: 告诉它操作系统层面能缓存多少页(包括 OS 缓存)；这个值不会占用内存，只是个估算值，影响查询计划生成; 默认值为 4GB; 通常建议为系统内存的 60%~75%; 该设置对大数据量表: 优化器会认为更多数据可以被缓存，从而更倾向于使用索引(index scan) 而不是顺序扫描(seq scan)  work_mem = 64MB 每个排序操作, hash join, 聚合阶段能用额内存 默认值为 4MB 或 8MB; 但如果有 100 个并发连接，每个用 64MB, 瞬间就会用到 6.4GB; 可以综合实际情况考虑；  maintenance_work_mem = 2GB 用于执行后台维护任务的内存, 如:  vacuum; create index; alter table; analyze 默认值为 64MB;  通常设置为 1~4GB, 对大表尤其重要； 该设置对大数据量表: vacuum 和 create index 可以用更多的内存构建中间结构; 减少磁盘临时文件写入; 极大加快维护任务的速度(尤其是 autovacuum)
    - 并行查询配置
      - max_worker_processes = 8               # 后台进程总数 max_parallel_workers_per_gather = 4    # 每个查询的并行度 parallel_setup_cost = 100              # 并行启动成本 parallel_tuple_cost = 0.1              # 并行传输成本
        > note: max_worker_processes = 8 postgresql 总共能启用的后台工作进程数量上限，包括并行查询，autovacuum，logic replication等都共享这个限制; 默认值为 8; 一般设置为 CPU 核心数，或略小一点  max_parallel_worker_per_gather = 4 每条查询语句中一个 Gather 或 Gather Merge 节点，最多能分配的并行 worker 数量； 默认值为 2；一般设置为 2~4  postgresql 会根据估算成本判断是否使用并行执行计划； 如果用了，Gather节点最多能拉起 4个 worker 执行子计划；  parallel_setup_cost = 100 启动并行查询的成本(开销)估算值，单位是估算成本 (costs) 默认值为 1000;   postgresql 优化器会比较串行和并行的执行成本 如果 parallel_setup_cost 设置太高，会让优化器放弃并行；调小这个值，让优化器更积极地考虑并行计划，让并行更加容易触发   parallel_tuple_cost = 0.1 每条记录通过并行 worker 传输给主线程的估算开销，单位是 cost; 默认值是 0.1; 如果设置得高，优化器会觉得并行执行中的结果汇总代价太大，从而放弃并行；设置太低，可能会触发不合适的并行(浪费资源)    开启并行的前提: 查询操作需有: Seq Scan, Aggregate, Sortm Join 等能并行的节点； 表统计信息要新(执行过 ANALYZE); 表或查询不能设置 parallel unsafe(如有自定义函数)
  - 8. 维护与监控
    - autovacuum深度配置
      - ALTER TABLE your_big_table SET (   autovacuum_vacuum_cost_limit = 2000(默认200),   autovacuum_vacuum_cost_delay = '2ms'(默认20ms),   autovacuum_vacuum_threshold = 5000,   autovacuum_vacuum_scale_factor = 0.005 );
        > note: 这两个参数组合起来的作用是  autovacuum 每批次的休息时间  比如默认配置，limit=200, delay=20ms 假设每次访问堆文件的页需要消耗 1个成本点。操作 10, 000页 默认配置的效果为: autovacuum 每消费 200 个点会等待 20ms 总共要 sleep:  10,000 / 200 * 20ms = 1000ms(即1s)  改完之后的效果为: autovacuum 每消费 2000 个点会等待 2ms 总共要 sleep:  10,000 / 2000 * 2ms = 10ms  等待时间降低很多。猛干活 但也会对磁盘和缓存带来更高的压力，需要权衡平衡点
    - 手动 autovacuum
      - VACUUM (VERBOSE, ANALYZE, SKIP_LOCKED) large_table;
      - VERBOSE: 显示详细报告;   ANALYZE: 同时更新统计信息；SKIP_LOCKED: 跳过被锁定的行，避免阻塞
      - 当判断值dead_ratio 为 0.2 的时候，就需要考虑手动 VACUUM;
        > note: SELECT n_dead_tup/n_live_tup AS dead_ratio FROM pg_stat_user_tables WHERE relname = 'large_table';   n_dead_tup: 估算的死元组数(已删除/更新旧版本) n_live_tup:  估算的活跃行数(不是精确的 count)  这些值是在 autovacuum 或 ANALYZE 操作后维护的统计信息缓存，不是实时值，但是能够反映一个表当前的膨胀程度了。  dead_ratio 越大，则 死元组越多，说明这个表有很多删除/更新过的行还没被清理； 这些行占用空间，影响性能(比如 : seq scan, 索引扫描性能下降等)； 如果 aurovacuum 没及时触发或处理不快，表则会膨胀
      - 0.2 是经典的经验值，来源于长期性能实践;
        > image: xap:resources/badba426c58dc467a4d91a1e6d70baa8adcf3aeba9b1b499eb47708ab7672a6a.png
    - 关键监控指标
      - 查询性能
        > note: SELECT      query,      calls,      total_exec_time,     mean_exec_time,     rows/calls AS avg_rows FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;
      - 表健康状态
        > note: SELECT     relname,     n_live_tup,     n_dead_tup,     round(n_dead_tup::numeric/n_live_tup::numeric*100,2) AS dead_pct FROM pg_stat_user_tables ORDER BY dead_pct DESC;
    - 自动化警报
      - 阈值
        - 死元组 > 20%;  索引扫描率 < 90%;  缓存命中率 < 95%
      - 实现方式
        - 使用 pg_stat_monitor 扩展
        - 配置 Prometheus + Grafana 监控
        - 设置 cron 定期检查
  - 9. 灾难恢复
    - 逻辑备份: pg_dump -Fc -d dbname -f backup.dump  # 自定义格式
    - 物理备份: pg_basebackup -D /backup -Ft -z -P
  - 10. 性能问题分析与诊断
    - 慢查询
      - 获取正在执行的，并且时间超过 5s 的 sql： SELECT * FROM pg_stat_activity  WHERE state = 'active' AND now() - query_start > interval '5 seconds';
      - 获取所有执行时间超过 5s 的 sql
        > note: 配置插件 配置文件 postgresql.confg 修改配置: shared_preload_libraries = 'pg_stat_statements'  重启数据库 执行初始化 sql： CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  SELECT     query,     calls,     total_time,     mean_time,     max_time,     rows FROM     pg_stat_statements WHERE     mean_time > 5000  -- 单次平均执行时间 > 5秒（单位 ms） ORDER BY     mean_time DESC LIMIT 20;
    - 获取到 慢查询 等情况下的 sql 后，执行计划 EXPLAIN (ANALYZE, BUFFERS) <问题查询>;
    - 对照问题情况，分析并解决
    - 常见问题与修复
      > image: xap:resources/1d856bb6625705038270d82b6d6c1997b0265c903b16178b51764c387ef4fbba.png
- 6. 缓存原理
  - 指令
    - echo 3 > /proc/sys/vm/drop_caches
      - 清除页面缓存(page cache), 目录项缓存(dentries), inode缓存
  - 扩展
    - pg_buffercache
      - 提供对 postgresql 共享缓冲区 (Shared Buffers) 的实时监控能力
      - 可以查看
        - 哪些数据页/索引页在内存中
        - 每个缓冲页的使用状态
        - 缓存命中率分析
        - 内存资源分布
      - 常用 sql
        - 1. 查看整体缓存状态(块，大小)
          > note: SELECT    count(*) AS buffers,   pg_size_pretty(count(*) * 8192) AS size FROM pg_buffercache;
        - 2. 按照对象统计缓存
          > note: SELECT    c.relname AS object,   CASE c.relkind     WHEN 'r' THEN 'TABLE'     WHEN 'i' THEN 'INDEX'     ELSE 'OTHER'   END AS type,   count(*) AS buffers,   round(100.0 * count(*) / (SELECT setting FROM pg_settings WHERE name='shared_buffers')::int, 2) AS cache_ratio FROM pg_buffercache b JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid) GROUP BY c.relname, c.relkind ORDER BY buffers DESC;
        - 3. 识别热数据
          > note: SELECT    c.relname,   b.usagecount,   count(*) AS buffers FROM pg_buffercache b JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid) GROUP BY c.relname, b.usagecount ORDER BY c.relname, b.usagecount;
          - usagecount>=4：热数据（频繁访问） usagecount=1：温数据 usagecount=0：冷数据（待淘汰）
        - 4. 脏页监控
          > note: SELECT    c.relname,   sum(CASE WHEN b.isdirty THEN 1 ELSE 0 END) AS dirty_buffers FROM pg_buffercache b JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid) GROUP BY c.relname HAVING sum(CASE WHEN b.isdirty THEN 1 ELSE 0 END) > 0;
        - 5. 缓存命中率分析
          > note: SELECT    sum(blks_hit) * 100 / nullif(sum(blks_hit + blks_read), 0) AS hit_ratio FROM pg_stat_database;
        - 6. 检查缓存淘汰率
          > note: SELECT    buffers_backend,   buffers_alloc FROM pg_stat_bgwriter;
    - pg_stat_statements
      - 用于跟踪 sql 执行统计信息
      - sql 性能分析
        - 执行统计
          - 记录每条 sql 的执行次数，总耗时，平均耗时，最大/最小耗时，影响行数等
        - 资源1消耗
          - 跟踪 I/O 操作(磁盘读写，缓存命中率)，临时文件使用量，wal 日志生成量等
        - 查询归一化
          - 自动将 sql 中的常量替换成 ?, 合并相同结构的查询，便于分析高频查询模式
      - 核心应用场景
        - 定位高耗时 sql, 优化慢查询
        - 识别高 I/O 或高内存消耗的 sql
        - 分析查询执行稳定性(通过标准差 stddev_exec_time 判断抖动)
        - 长期监控 sql 性能趋势，预防潜在瓶颈
      - 常用 sql
        - 定位高耗时 sql
          > note: -- 按总耗时排序 TOP 10 SELECT query, total_exec_time, calls, mean_exec_time FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
        - 识别高 I/O 操作 sql
          > note: -- 按磁盘 I/O 时间排序 SELECT query, (blk_read_time + blk_write_time) AS io_time FROM pg_stat_statements ORDER BY io_time DESC LIMIT 10;
        - 分析查询稳定性
          > note: -- 执行时间抖动大的 SQL（标准差高） SELECT query, stddev_exec_time, calls FROM pg_stat_statements WHERE calls > 100 ORDER BY stddev_exec_time DESC LIMIT 5;  [8](@ref)
  - 原理
    - 查询
      - 流程
        - 1. 发起查询
        - 2. 检查 shared_buffers
          - 2.1 命中
            - 返回数据
          - 2.2 未命中
            - 2.2.1 检查 OS Cache(内存)
              - 2.2.1.1  命中
                - 加载到 shared_buffers
              - 2.2.1.2 未命中 
                - 2.2.1.2.1 从磁盘读入
                - 2.2.1.2.2 加载到 OS Cache
                - 2.2.1.2.3 加载到 shared_buffers
    - 写入
      - 流程
        - 1. 修改数据
        - 2. 写入 shared_buffers 并标记为脏页
        - 3. 事务提交时 WAL 落盘
        - 4. 后台进程异步刷脏页到 OS Cache(内存)
        - 5. 最终写入磁盘
      - 同步控制
        - LWLock(轻量锁)
          - 保护缓存页并发访问
        - Content Lock
          - 确保数据修改的原子性
- 7. 索引优化
  - 10.146.100.57
    - report_tsd
      - 总大小:  395G
      - 4.04亿记录
        - 8w+信号点
        - 4.8w+存储信号点
      - 原索引
        - deiceId_timestamp
          - 3.8G
        - timestamp_cid_triggerType
          - 35G
        - cid_timestamp_triggerType
          - 36G
        - _id
          - 主键
          - 8.5G
      - 索引优化
        - bitmapscan
          - 索引调整
            - timestamp_cid_triggerType
            - cid_timestamp_triggerType
            - deiceId_timestamp
            - _id
            - cid_triggerType
              - 2.9G
            - timestamp
              > note: CREATE INDEX idx_brin_ts ON report_tsds  USING brin(timestamp) WITH (pages_per_range=256);
              - 10M
            - 其他调整方向
              - #1. BRIN, B-Tree -> BRIN + Bloom ? todo
                > note: -- 创建优化版Bloom索引 CREATE INDEX idx_bloom_cid_trigger ON report_tsds  USING bloom (cid, triggerType) WITH (length=80, col1=4, col2=3);  列|默认值|推荐值|含义 length | 80 | 96 | 降低假阳性率至0.3% col1 | 2 | 4 | cid的哈希函数数量 col2 | 2 | 3 | triggerType的哈希函数数
                - 需要考虑
                  - report.tsds 的使用场景
                    - 是否只有使用 cid, 不用 triggerType 等？
                - 性能收益预测 指标	                 原方案	          新方案	           提升 索引扫描时间	        192 ms	         ​​<20 ms​​	           90%+ 总执行时间	        7949 ms	         ​​<1000 ms​​	   87%+ 索引存储空间	        3GB	                ​​<1GB​​	           66%+ 删除作业维护开销	高	​​                极低​​	          无需重组
              - #2. 使用 timescaledb 扩展？
          - 启用位图扫描 (默认开启)
            > note: 开启前，执行计划 Index Scan using report_tsds_cid_idx on report_tsds r  (cost=0.14..8.17 rows=1 width=481)   Index Cond: (((cid)::text = ''::text) AND (("triggerType")::text = ''::text))     Filter: (("timestamp" >= '2024-09-25 23:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2024-09-25 23:00:00+08'::timestamp with time zone))   开启后，执行计划 Limit  (cost=4714.02..4718.04 rows=1 width=894) (actual time=81.477..81.479 rows=0 loops=1)   ->  Bitmap Heap Scan on report_tsds  (cost=4714.02..4718.04 rows=1 width=894) (actual time=81.475..81.476 rows=0 loops=1)         Recheck Cond: (((cid)::text = '687a19b69f5a7e37293e4018::Base::val_sys_ep_inpRmsPhsAN'::text) AND (("triggerType")::text = 'HOUR'::text) AND ("timestamp" >= '2024-01-01 00:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2024-06-30 00:00:00+08'::timestamp with time zone))         ->  BitmapAnd  (cost=4714.02..4714.02 rows=1 width=0) (actual time=81.428..81.429 rows=0 loops=1)               ->  Bitmap Index Scan on report_tsds_cid_idx  (cost=0.00..123.74 rows=8704 width=0) (actual time=1.538..1.539 rows=8698 loops=1)                     Index Cond: (((cid)::text = '687a19b69f5a7e37293e4018::Base::val_sys_ep_inpRmsPhsAN'::text) AND (("triggerType")::text = 'HOUR'::text))               ->  Bitmap Index Scan on idx_brin_report_tsds_timestamp  (cost=0.00..4590.03 rows=1262 width=0) (actual time=79.563..79.563 rows=0 loops=1)                     Index Cond: (("timestamp" >= '2024-01-01 00:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2024-06-30 00:00:00+08'::timestamp with time zone)) Planning Time: 0.194 ms Execution Time: 81.520 ms
            - (untitled)
              > image: xap:resources/5594a679fb02f3a108cdacf851a12bea7c07eaf8a76323d7fdff942ad8dceb45.png
            - SET enable_bitmapscan = ON;
          - 原理
            - (untitled)
              > image: xap:resources/09b77fb654b6dee74d9e8e40f2168f9f257dfb8868eadd5aab565792357805e1.png
            - 具体分为
              - 索引扫描阶段
                > note: a. 使用B-Tree索引扫描：根据条件cid = 'some_cid' AND triggerType = 'some_type'，扫描B-Tree索引，获取匹配行的TID（行标识符）列表。这个阶段会返回一个TID列表，表示满足cid和triggerType条件的行。 b. 使用BRIN索引扫描：根据条件timestamp BETWEEN 'start_time' AND 'end_time'，扫描BRIN索引。BRIN索引将表分成多个范围（块范围），每个范围存储了该范围内的时间戳的最小值和最大值。通过比较这些最小/最大值与查询条件，可以确定哪些块可能包含满足时间条件的行。然后，它会返回一个位图，标记出这些块（注意：BRIN索引返回的是块级别的位图，而不是精确的行）。
                - B-Tree索引扫描
                  - 输入：查询条件（cid和triggerType的等值条件）。 输出：一个位图，其中每个满足条件的行对应的位被设置。 特点：精确到行，效率高。
                - BRIN索引扫描
                  - 输入：时间范围条件。 输出：一个块级别的位图，标记出所有可能包含满足时间条件的行的块。 特点：快速但不够精确，因为一个块内只要有一个行满足条件，整个块都会被标记。因此，后续需要重新检查块内的每一行。
              - 位图合并阶段
                > note: 将两个索引扫描的结果进行位图AND操作。因为我们需要同时满足两个条件（cid+triggerType条件和时间条件）。这里需要注意： B-Tree索引返回的是精确的行TID位图（每个位代表一个行）。 BRIN索引返回的是块级别的位图（每个位代表一个块，块内所有行都被标记为候选行）。 因此，在合并之前，需要将BRIN的块位图转换为行位图（即块内所有行都设为候选）。然后进行位图AND操作，得到同时满足两个条件的行位图。
                - 输入：两个位图（一个来自B-Tree索引扫描，一个来自BRIN索引扫描）。 操作：对两个位图进行按位与操作。 输出：一个新的位图，其中同时满足两个条件的行被标记。
              - 位图堆扫描阶段
                > note: 根据合并后的位图，访问表中对应的行。 由于位图可能很大，不能一次性放入内存，PostgreSQL会按顺序读取位图对应的数据块，然后检查每一行是否满足条件（因为位图是近似表示，所以需要重新检查条件，特别是对于BRIN索引，因为它只标记了块，块内可能有不满足条件的行）。 这个阶段称为“Bitmap Heap Scan”，它可能包含一个“Recheck”步骤。
                - 输入：合并后的位图。 过程：按照位图指示的顺序（物理顺序）访问数据块，然后对每个候选行重新检查所有条件（包括cid、triggerType和时间范围）。这是因为：     对于B-Tree索引，条件已经精确匹配，但为了确保一致性（特别是如果数据在索引扫描后被修改），仍然需要重新检查。     对于BRIN索引，它只给出了块级别的过滤，所以块内的每一行都需要检查时间条件。 输出：满足所有条件的行。
              - 结果返回
            - 性能考虑
              - 1. 位图大小
                > note: 位图的大小取决于表中行的数量。 如果表非常大，位图可能会占用大量内存。 PostgreSQL使用工作内存（work_mem）来存储位图。 如果位图太大，可能会被写入磁盘，导致性能下降。 因此，适当增加work_mem可以提升性能。
              - 2. BRIN 索引的精度
                > note: BRIN索引的精度取决于参数pages_per_range（默认128页）。 如果范围设置得太大，则一个范围包含的数据块多，那么位图就会更粗糙，导致需要重新检查更多的行。 如果设置得太小，则BRIN索引会更大，扫描索引的时间会增加。因此，需要根据数据分布调整这个参数。
              - 3. 数据分布
                > note: 如果cid和triggerType的条件过滤性很强（即返回的行数很少），那么B-Tree索引扫描会很快，并且生成的位图也很小。 同样，如果时间范围很小，BRIN索引扫描也会很快。 但如果两个条件返回的位图都很大，那么位图合并操作可能会比较重。
              - 4. 重新检查
                > note: 由于BRIN索引的粗糙性，位图堆扫描阶段需要重新检查时间条件，这会增加CPU开销。
          - 相关参数优化
            > note: 相关sql：  EXPLAIN (ANALYZE, BUFFERS, TIMING) SELECT EXTRACT(DAY FROM ("timestamp" AT TIME ZONE INTERVAL '8 hour')) AS day, EXTRACT(MONTH FROM ("timestamp" AT TIME ZONE INTERVAL '8 hour')) AS month, EXTRACT(YEAR FROM ("timestamp" AT TIME ZONE INTERVAL '8 hour')) AS year, "deviceId", "componentIdentifier", "name", AVG((tags -> 'hourSpecs' -> 'avg' ->> 'value')::numeric) AS avg FROM "report_tsds" WHERE "cid" IN (     '687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated',     '687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated',     '687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated',     '687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated',     '687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated',     '687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated',     '687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated',     '687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated' ) and "triggerType" = 'HOUR' AND "timestamp" >= '2025-03-28 16:00' AND "timestamp" <= '2025-04-30 15:59' GROUP BY day, month, year, "deviceId", "componentIdentifier", "name"
            - shared_buffers
              - 由默认的 128M, 改为了机器最大物理内存的 1/4, 6G
              - 当对一个表同时进行插入和查询时(比如整点存储时进行自定义报表查询)，如果 shared_buffers 还有足够的空余空间的话，查询性能不会下降太多
              - 如果这个时候 shared_buffers 空间不足的话，会进行资源竞争，查询一个月，8个信号点的历史报表会由空闲时的 8s 变成 30s 左右
            - pages_per_range
              - 默认为 128, 代表由 128个块生成一个摘要，即 1MB 数据生成一个摘要
                - 设小 → 过滤更精确（但索引变大）
              - 建议：初始值 = ​​（热点数据天数）÷（总块数/128）​​（例如表有100000块，热点7天 → ~90）。
                > note: -- 计算最优pages_per_range： WITH block_stats AS (   SELECT      count(*) AS total_blocks,     max(timestamp) - min(timestamp) AS time_span,     (max(timestamp) - min(timestamp)) / count(*) AS block_time_density   FROM report_tsds ) SELECT    total_blocks,   ceil(EXTRACT(EPOCH FROM time_span) / 86400) AS day_span,   greatest(1, least(128, 1000000 / (EXTRACT(EPOCH FROM block_time_density)))) AS optimal_range FROM block_stats;
              - 计算
                - 可以计算每小时插入多少 buffer(块)，记为 A
                  - 每小时入表记录数 * 表记录数平均宽度 / 8kb/块
                - 如果按照每小时查询历史数据额度业务多，则可以设置 pages_per_range 为 A; 
                  - 如果是其他等比时间查询的比较多，则把 A 按等比放大或缩小后设置
                - 如果希望一个摘要覆盖 15分钟的数据，则可以近似设置为  表大小 / 8(kb/页) /  (60/15)
                - 可以按照修改后，实际效果为准
              - autosummarize = off
                - 打开的状态下，主要适用于需要实时性的场景
              - 默认为 128
                > note: HashAggregate  (cost=32702.42..32880.73 rows=6484 width=179) (actual time=8045.242..8046.006 rows=272 loops=1)   Group Key: EXTRACT(day FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(month FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(year FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), "deviceId", "componentIdentifier", name   Batches: 1  Memory Usage: 337kB   Buffers: shared hit=1807 read=7194   I/O Timings: shared read=7103.997   ->  Bitmap Heap Scan on report_tsds  (cost=6540.27..32507.90 rows=6484 width=713) (actual time=561.697..7985.587 rows=6336 loops=1)         Recheck Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text) AND ("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))         Rows Removed by Index Recheck: 775         Heap Blocks: exact=7111         Buffers: shared hit=1807 read=7194         I/O Timings: shared read=7103.997         ->  BitmapAnd  (cost=6540.27..6540.27 rows=6484 width=0) (actual time=462.625..462.627 rows=0 loops=1)               Buffers: shared hit=1807 read=83               I/O Timings: shared read=72.849               ->  Bitmap Index Scan on report_tsds_cid_idx  (cost=0.00..997.66 rows=70410 width=0) (actual time=91.038..91.038 rows=70296 loops=1)                     Index Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text))                     Buffers: shared hit=21 read=83                     I/O Timings: shared read=72.849               ->  Bitmap Index Scan on idx_brin_report_tsds_timestamp  (cost=0.00..5539.12 rows=37429142 width=0) (actual time=363.234..363.234 rows=41785120 loops=1)                     Index Cond: (("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))                     Buffers: shared hit=1786 Planning:   Buffers: shared hit=115 Planning Time: 0.531 ms Execution Time: 8046.167 ms
              - 改为 256
                > note: HashAggregate  (cost=?..? rows=6379 width=179) (actual time=?..7948.670 rows=272 loops=1)   Group Key: EXTRACT(day FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(month FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(year FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), "deviceId", "componentIdentifier", name   Batches: 1  Memory Usage: 337kB   Buffers: shared hit=924 read=6526   I/O Timings: shared read=7171.035 	->  Bitmap Heap Scan on report_tsds  (cost=4245.64..29794.80 rows=6379 width=713) (actual time=820.125..7886.137 rows=6336 loops=1) 			Recheck Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text) AND ("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone)) 			Rows Removed by Index Recheck: 107 			Heap Blocks: exact=6443 			Buffers: shared hit=924 read=6526 			I/O Timings: shared read=7171.035 			->  BitmapAnd  (cost=4245.64..4245.64 rows=6379 width=0) (actual time=449.101..449.103 rows=0 loops=1) 				Buffers: shared hit=924 read=83 				I/O Timings: shared read=163.184 				->  Bitmap Index Scan on report_tsds_cid_idx  (cost=0.00..986.38 rows=69276 width=0) (actual time=192.152..192.153 rows=70344 loops=1) 						Index Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text)) 						Buffers: shared hit=21 read=83 						I/O Timings: shared read=163.184 				->  Bitmap Index Scan on idx_brin_report_tsds_timestamp  (cost=0.00..3255.82 rows=36826080 width=0) (actual time=248.390..248.391 rows=37736960 loops=1) 						Index Cond: (("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone)) 						Buffers: shared hit=903 Planning:   Buffers: shared hit=352 Planning Time: 3.105 ms Execution Time: 7948.670 ms
                - 索引大小由 10M 缩小到了 5.2M
                - 从执行计划看到的变化
                  - 总执行时间​​	 8046 ms	​​   7949 ms​​	↓1.2%
                  - BRIN扫描用时​​	 363.2 ms   ​​248.4 ms​​	​​↓31.6%​
                  - ​​BRIN预估行数​​	 4178万行   3773万行​​	↓9.7%
                  - CID索引扫描用时​​	91 ms	​​192 ms​​	↑111%
                  - ​​堆扫描实际时间​​	7985 ms	​​7886 ms​​	↓1.2%
                  - ​​物理I/O量​​	  7194 blocks   6526 blocks​​	↓9.3%
                  - ​​Recheck移除行数​​	775 行	​​107 行​​	​​↓86%
                - 结论
                  - BRIN扫描效率大幅提升​​
                    - 扫描时间减少31.6%（363ms → 248ms），证明更大的pages_per_range减少了索引处理量
                  - 物理I/O量减少9.3%​
                    - 堆扫描块数从7194减少到6526，验证更大的范围减少了需要检查的数据块
                  - ​​过滤精度提升
                    - Recheck移除行数减少86%（775 → 107），表明物理存储有序时更大的范围不会降低精度
                  - 但，CID索引扫描成为新瓶颈
                    - 相同数据块（83 blocks）的读取时间​​从91ms增加到192ms​​
                      - 磁盘I/O成为新瓶颈
                      - 数据分布或硬件存在随机访问瓶颈
                      - CID索引未能有效利用缓存
                  - 整体性能未显著提升
                    - CID索引扫描耗时翻倍​​（91ms → 192ms）抵消了BRIN优化的收益
                    - 堆扫描时间基本不变​​：虽然扫描块减少，但磁盘IPS（每秒输入输出操作）受限
              - 改为 64
                > note: HashAggregate  (cost=36882.17..37057.59 rows=6379 width=179) (actual time=39519.274..39519.525 rows=272 loops=1)   Group Key: EXTRACT(day FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(month FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(year FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), "deviceId", "componentIdentifier", name   Batches: 1  Memory Usage: 337kB   Buffers: shared hit=3617 read=6448   I/O Timings: shared read=37958.487   ->  Bitmap Heap Scan on report_tsds  (cost=11141.64..36690.80 rows=6379 width=713) (actual time=1841.768..39397.597 rows=6336 loops=1)         Recheck Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text) AND ("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))         Rows Removed by Index Recheck: 29         Heap Blocks: exact=6365         Buffers: shared hit=3617 read=6448         I/O Timings: shared read=37958.487         ->  BitmapAnd  (cost=11141.64..11141.64 rows=6379 width=0) (actual time=1572.221..1572.223 rows=0 loops=1)               Buffers: shared hit=3617 read=83               I/O Timings: shared read=1082.187               ->  Bitmap Index Scan on report_tsds_cid_idx  (cost=0.00..986.38 rows=69276 width=0) (actual time=1107.803..1107.804 rows=70344 loops=1)                     Index Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text))                     Buffers: shared hit=21 read=83                     I/O Timings: shared read=1082.187               ->  Bitmap Index Scan on idx_brin_report_tsds_timestamp  (cost=0.00..10151.82 rows=36826219 width=0) (actual time=456.474..456.474 rows=36938880 loops=1)                     Index Cond: (("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))                     Buffers: shared hit=3596 Planning:   Buffers: shared hit=350 read=2   I/O Timings: shared read=0.033 Planning Time: 2.843 ms Execution Time: 39520.102 ms
                - 索引大小由 10M 扩大到 20M
                - 从执行计划看到的变化
                  - 总执行时间​​	 8046 ms	​​   39,520 ms	↑ 390.9%
                    - 1. BitmapAnd 时间暴增（462ms → 1,572ms） 2. BRIN扫描I/O效率下降（物理I/O时间7.1s → 37.9s，↑434%）
                  - BRIN扫描用时​​	 363.2 ms   ​​456 ms​​	       ​​↑ 25.6%
                    - 更小的pages_per_range需要扫描更多索引元数据，增加CPU和I/O开销
                  - ​​BRIN预估行数​​	 4178万行   3694万行​​	↓ 11.6%
                    - 范围缩小导致优化器估算的行数减少，但估算仍远高于实际值
                  - CID索引扫描用时​​	91 ms   1108 ms	↑ 1117%
                    - 1. BitmapAnd合并效率降低 2. BRIN小范围扫描拖累整体位图生成效率
                  - ​​堆扫描实际时间​​   7985 ms	​​39398 ms​​   ↑ 393%
                    - 堆块物理I/O时间剧增（7.1s → 37.9s），尽管扫描块数减少但I/O随机性增加
                  - ​​物理I/O量​​	  7194 blocks   6448 blocks	↓ 10.4%
                    - BRIN精度提高减少了误匹配的块数（Recheck移除行数↓86%），但无法弥补随机I/O的代价
                  - ​​Recheck移除行数​​	775 行	​​29 行​​	↓ 96.3%
                    - 更小的pages_per_range显著提升BRIN精度，减少误匹配
                - 结论
                  - 范围覆盖更精细 → Recheck移除行数↓96.3%，物理I/O量↓10.4%
                  - 需处理​​2倍元数据​​ → BRIN扫描时间↑25.7%
                    - 元数据分散导致​​随机I/O暴增​​（I/O时间从7.1s → 37.9s）
                  - BitmapAnd成为性能黑洞
                    - (untitled)
                      > image: xap:resources/540abf38c90fd6df19bc736648a45ab1aa9bc79ef0ca4fa1ca4403c1e629f923.png
                    - code
                      > note: graph LR A[pages_per_range=64] --> B[BRIN元数据量翻倍] B --> C[位图生成更复杂] C --> D[BitmapAnd时间 462ms→1572ms ↑240%] D --> E[CID索引扫描被拖累 91ms→1108ms ↑1117%]
                  - 优化器误判的连锁反应
                    - 行数估计仍严重偏差（估算3773万行 vs 实际6336行）
                    - 小范围使优化器误判“更高精度=更低代价”，​​未预见物理存储的随机性代价
              - 结论
                - 使用默认 128 在当前数据和分布下比较合适
                - 或者往大了调，但在 2倍默认(256)以内，找一个性能更佳的
            - work_mem
              - 默认为 4MB
                > note: HashAggregate  (cost=32693.97..32872.23 rows=6482 width=179) (actual time=8711.519..8711.880 rows=272 loops=1)    	Group Key: EXTRACT(day FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(month FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(year FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), "deviceId", "componentIdentifier", name    	Batches: 1  Memory Usage: 337kB    	Buffers: shared hit=1840 read=7151 dirtied=64    	I/O Timings: shared read=7538.020    		->  Bitmap Heap Scan on report_tsds  (cost=6539.89..32499.51 rows=6482 width=713) (actual time=590.902..8626.786 rows=6336 loops=1)          		    Recheck Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text) AND ("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))          			Rows Removed by Index Recheck: 47374          			Heap Blocks: exact=1880 lossy=5215          			Buffers: shared hit=1840 read=7151 dirtied=64          			I/O Timings: shared read=7538.020          				->  BitmapAnd  (cost=6539.89..6539.89 rows=6482 width=0) (actual time=477.798..477.800 rows=0 loops=1)                				Buffers: shared hit=1816 read=80                				I/O Timings: shared read=48.842                					->  Bitmap Index Scan on report_tsds_cid_idx  (cost=0.00..997.50 rows=70393 width=0) (actual time=80.176..80.177 rows=70280 loops=1)                     、 						Index Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text))                      						Buffers: shared hit=24 read=80                      						I/O Timings: shared read=48.842                					->  Bitmap Index Scan on idx_brin_report_tsds_timestamp  (cost=0.00..5538.90 rows=37420328 width=0) (actual time=387.627..387.627 rows=41682930 loops=1)                      						Index Cond: (("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))                      						Buffers: shared hit=1792  Planning:    Buffers: shared hit=280  Planning Time: 3.773 ms  Execution Time: 8712.349 ms
              - 调整为 16MB
                > note: HashAggregate  (cost=32702.42..32880.73 rows=6484 width=179) (actual time=8045.242..8046.006 rows=272 loops=1)   Group Key: EXTRACT(day FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(month FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), EXTRACT(year FROM ("timestamp" AT TIME ZONE '08:00:00'::interval)), "deviceId", "componentIdentifier", name   Batches: 1  Memory Usage: 337kB   Buffers: shared hit=1807 read=7194   I/O Timings: shared read=7103.997   ->  Bitmap Heap Scan on report_tsds  (cost=6540.27..32507.90 rows=6484 width=713) (actual time=561.697..7985.587 rows=6336 loops=1)         Recheck Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text) AND ("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))         Rows Removed by Index Recheck: 775         Heap Blocks: exact=7111         Buffers: shared hit=1807 read=7194         I/O Timings: shared read=7103.997         ->  BitmapAnd  (cost=6540.27..6540.27 rows=6484 width=0) (actual time=462.625..462.627 rows=0 loops=1)               Buffers: shared hit=1807 read=83               I/O Timings: shared read=72.849               ->  Bitmap Index Scan on report_tsds_cid_idx  (cost=0.00..997.66 rows=70410 width=0) (actual time=91.038..91.038 rows=70296 loops=1)                     Index Cond: (((cid)::text = ANY ('{687adcf79f5a7e37293ef913::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e9c::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1cc2::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e1f::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1e6c::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b90::Base::val_pem_enrg_accumulated,687adcfc9f5a7e37293f1b8e::Base::val_pem_enrg_accumulated,687adcfd9f5a7e37293f1d25::Base::val_pem_enrg_accumulated}'::text[])) AND (("triggerType")::text = 'HOUR'::text))                     Buffers: shared hit=21 read=83                     I/O Timings: shared read=72.849               ->  Bitmap Index Scan on idx_brin_report_tsds_timestamp  (cost=0.00..5539.12 rows=37429142 width=0) (actual time=363.234..363.234 rows=41785120 loops=1)                     Index Cond: (("timestamp" >= '2025-03-28 16:00:00+08'::timestamp with time zone) AND ("timestamp" <= '2025-04-30 15:59:00+08'::timestamp with time zone))                     Buffers: shared hit=1786 Planning:   Buffers: shared hit=115 Planning Time: 0.531 ms Execution Time: 8046.167 ms
              - 调整后,    Heap Blocks: exact=1880(精确) lossy=5215(有损) 优化到了    Heap Blocks: exact=7111
                - 优化前认为 1880个页能命中，并且 5215个页里面可能还有记录，必须再次扫描 5215页里面的每行，recheck
                - 优化后，直接获取到精确 7111 页能命中
                  - 避免扫描 5215 个页，节省 CPU
                  - 减少 I/O放大，精确读取目标行对比读取整页，节省 I/O: 5215页*8kb=41.72MB
                  - 缓存效率提升，精确访问，更高的缓存命中率，减少缓存污染
                - (untitled)
                  > image: xap:resources/ec229e1077da497a3ca248e215cd6bf571e1fa6942dec0e4215ac004fef7d0f3.png
                  - code
                    > note: sequenceDiagram     participant Q as 查询引擎     participant B as 位图生成器     participant H as 堆扫描          Q->>B: 请求生成位图(work_mem=16MB)     B->>B: 创建精确位图(7111块)     B->>H: 传递精确位图     H->>H: 直接定位目标行     H-->>Q: 返回结果          # 对比原始流程     Q->>B: 请求生成位图(work_mem=4MB)     B->>B: 创建有损位图(1880精确+5215有损)     B->>H: 传递混合位图     H->>H: 扫描5215整页+Recheck     H-->>Q: 返回结果
              - 原理
                - 1. 位图生成
                  > note: 当执行位图索引扫描时，索引扫描会返回一系列元组标识（TID），即（页号，页内偏移量）。 位图扫描需要将这些TID转换为位图：每个页对应一个位图项，如果该页中有满足条件的行，则设置该页对应的位。如果内存足够，还会记录页内具体哪些行（通过位图内的偏移位）。
                - 2. 有损位图(lossy)
                  > note: 当需要访问的页数非常多，而work_mem不足以存储所有页的精确信息（每个页需要多个位来记录行偏移）时，PostgreSQL会将位图转换为有损模式。 有损模式下，位图不再记录页内具体的行偏移，而是只记录哪些页需要被访问（每个页只用一个位表示）。这样，位图的内存占用大大减少（一个页只需1位，而精确模式下，一个页可能需要多个位，具体取决于页内行数）。 但是，有损位图会导致在访问堆表时，必须重新检查整个页（Recheck条件），因为不知道具体哪些行满足条件。
                - 3. 精确位图(exact)
                  > note: 当work_mem足够大，能够容纳所有需要访问的页的精确信息时，位图会记录每个页内具体哪些行满足条件（通过设置页内偏移对应的位）。 这样，在访问堆表时，可以直接定位到具体的行，无需重新检查整个页，效率更高
                - 4. work_mem 和 max_connection 有关。
                  - 如果 max_connection 为 100， work_mem=16M, 当同时有 100个连接过来时，内存会直接占有 100*16M = 1.6G
            - effective_cache_size
              - 用于告知查询优化器： "操作系统和 postgresql 共享缓冲区总共能提供多少内存用于缓存磁盘数据"
            - random_page_cost = 1.1         -- SSD优化
          - 最终优化
            - 机器内存为  24G
            - 相关参数
              - #1. shared_buffers(根据机器内存动态处理, 25%)
                - 128M -> 6G
              - #2. effective_cache_size(根据机器内存动态处理, 50%)
                - 4G -> 12G
              - #3. work_mem
                - 4M -> 16M
              - #1，#2 减少 buffers和I/O竞争，当 buffers 随着时间推移，数据/索引空间将会逐渐占满 buffers, 从而更好命中缓存，减少 I/O, 缩短查询时间
              - #3 优化位图/排序/哈希操作，针对 bitmap, 使用精确位图(Exact Bitmap), 而不是近视位图(Lossy Bitmap), 减少 Lossy(模糊)，提高效率
          - 优化完的效果
            - 相对于原 SI4.0.1(不把直接 sql 查询 改为代码直接查询/排序/分页等)
              - 1. 索引合并，由2个索引共71G, 缩小到了 3G
              - 2. 自定义报表，第一次查询由 30s+ 到了 8s 左右，更稳定了
  - 常用 sql
    - 查询创建索引进展
      > note: SELECT     pid,     relid::regclass AS table_name,     index_relid::regclass AS index_name,     phase,     round(100.0 * blocks_done / nullif(blocks_total, 0), 2) AS progress_percent,     current_timestamp - query_start AS duration,     query FROM     pg_stat_progress_create_index JOIN     pg_stat_activity USING (pid);
    - 查询某个索引在缓存中的页数和空间大小
      > note: SELECT      c.relname AS object_name,     count(*) AS buffered_pages,     count(*) * 8 AS approx_kb FROM      pg_buffercache b JOIN      pg_class c ON b.relfilenode = pg_relation_filenode(c.oid) JOIN      pg_database d ON b.reldatabase = d.oid WHERE      c.relname = 'report_tsds_cid_idx'  -- 替换为索引名     AND d.datname = current_database() GROUP BY      c.relname;
    - 查询某个索引在缓存中的详细信息
      > note: SELECT     itemoffset,     ctid,     itemlen,     encode(decode(ltrim(data, '\x'), 'hex'), 'escape') AS readable_data FROM bt_page_items('idx_report_tsds_1', 10);
    - 获取所有缓存在缓冲区的占比
      > note: WITH buffer_stats AS (     SELECT          c.relname,         COUNT(*) AS buffers     FROM          pg_buffercache b     JOIN          pg_class c ON b.relfilenode = pg_relation_filenode(c.oid) --    WHERE  --        c.relname LIKE '%report_tsds%'     GROUP BY          c.relname ), total AS (     SELECT COUNT(*) AS total_buffers FROM pg_buffercache ) SELECT      bs.relname,      ROUND((bs.buffers * 8.0 / 1024), 2) AS total_buffers_MB,     ROUND((bs.buffers * 100.0 / t.total_buffers), 2) AS percent FROM      buffer_stats bs, total t ORDER BY      percent DESC;
    - 查询某个表的死元组
      > note: SELECT   schemaname AS schema,   relname AS table,   n_dead_tup AS dead_tuples,   n_live_tup AS live_tuples,   round(100 * n_dead_tup::numeric / (n_live_tup + n_dead_tup), 2) AS dead_ratio,   last_autovacuum,   last_autoanalyze FROM pg_stat_all_tables WHERE relname = 'report_tsds';
    - 查询死元组的索引
      > note: SELECT   indexrelname AS index,   idx_tup_read,   idx_tup_fetch,   idx_scan,   pg_size_pretty(pg_relation_size(indexrelid)) AS index_size FROM pg_stat_all_indexes WHERE relname = 'report_tsds';
    - 查询表的近似数量
      > note: SELECT c.relname AS table_name,        c.reltuples::BIGINT AS approximate_row_count FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'report_tsds'   AND n.nspname = 'public';
    - 查询某个表是否单独配置了设置参数
      > note: SELECT   n.nspname AS schema_name,   c.relname AS table_name,   c.reloptions FROM   pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE   c.relname = 'report_tsds';

