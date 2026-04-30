<!-- auto-generated from business\PI\迁移 mongodb.xmind by _build/extract-xmind.ps1, do NOT edit -->

# 迁移 mongodb

- Postgresql
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
    - 3. 其他
      - 1. 函数和操作符重载
        > note: -- 自定义复数类型 CREATE TYPE complex AS (r float8, i float8);  -- 自定义加法操作符 CREATE FUNCTION complex_add(complex, complex) RETURNS complex AS $$     SELECT ($1.r + $2.r, $1.i + $2.i)::complex; $$ LANGUAGE SQL;  CREATE OPERATOR + (     leftarg = complex,     rightarg = complex,     procedure = complex_add );  -- 使用自定义操作符 SELECT (1.0,1.0)::complex + (2.0,3.0)::complex;
      - 2. 复杂对象处理
        - 比如：存储和查询整个JSON文档(JSON类型)
          > note: -- 存储整个JSON文档(JSONB类型) CREATE TABLE products (     id serial PRIMARY KEY,     attributes jsonb  -- 支持索引和深度查询 );  -- 查询JSON内部字段 SELECT attributes->>'color' FROM products  WHERE attributes @> '{"category":"electronics"}';
  - 2. 数据类型
    - JSONB: 二进制格式 JSON
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
- PI
  - 1. mtp-core
    - 架构
      - 去掉 mongodb 配置, mongotemplate 使用等
      - 把 postgresql 能力完整融入到 TAF 架构
    - 设计
      - 基于 postgresql 关系型数据库特性，结合 TAF 的 schema 使用，进行设计
        - 集合
          - 表属性的数据类型选择
            - "_id"
              - a. BIGSERIAL,  自动递增整型
              - b. gen_random_uuid()::text, 随机字符串
              - c. 自定义存储过程
            - array
              - 基本类型数组
                - a. int[] ...
                - b. VARCHAR
                - c. JSONB
              - 对象数组
                - JSONB
            - object -> JSONB
              - a. 对指定属性/路径建 GIN 类型索引
                > note: -- 为 preferences 列创建默认的 GIN 索引（支持 @>, ?, ?|, ?& 操作符） CREATE INDEX idx_user_profiles_preferences ON user_profiles USING GIN (preferences);  -- 创建更精细的 JSON 路径表达式索引 CREATE INDEX idx_user_profiles_theme ON user_preferences USING GIN ((preferences->'theme'));
              - b. 单独把索引字段抽取出来作为一列？
              - c. 用 CHECK 定义有哪些属性，和限制嵌套在里面的属性校验(必填, 枚举，值类型等) ?
                > note: -- 1. 创建带约束的表 CREATE TABLE products (     id SERIAL PRIMARY KEY,     product JSONB NOT NULL,     CONSTRAINT chk_product_structure CHECK (         jsonb_typeof(product) = 'object' AND         product ? 'sku' AND          product ? 'name' AND (product->>'name') <> '' AND         product ? 'size' AND          product ? 'date'     ) );  -- 2. 创建唯一索引 CREATE UNIQUE INDEX idx_unique_sku ON products ((product->>'sku'));  -- 3. 测试：插入一条合法数据 INSERT INTO products (product) VALUES  ('{"sku": "A1001", "name": "机械键盘", "size": 87, "date": "2023-10-01"}'::jsonb); -- 成功！  -- 4. 测试：缺少 date 字段 INSERT INTO products (product) VALUES  ('{"sku": "A1002", "name": "鼠标", "size": 50}'::jsonb); -- 失败！报错：new row for relation "products" violates check constraint "chk_product_structure"  -- 5. 测试：name 为空字符串 INSERT INTO products (product) VALUES  ('{"sku": "A1003", "name": "", "size": 50, "date": "2023-10-01"}'::jsonb); -- 失败！报错：同上  -- 6. 测试：插入重复的 sku INSERT INTO products (product) VALUES  ('{"sku": "A1001", "name": "另一个键盘", "size": 60, "date": "2023-10-02"}'::jsonb); -- 失败！报错：duplicate key value violates unique constraint "idx_unique_sku"
          - 索引
            - 选型
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
            - 场景/优化
              - 部分索引partialFilterExpression
                > note: "options": {"unique": true, "partialFilterExpression": {"programmaticName": {"$exists": true}} }
                - 转化成带 where 的索引语句
                  > note: CREATE INDEX idx_xx ON table (yy) WHERE zz > 18
              - ...
        - 专用集合定制
          - 文件集合(fs.files, fs.chunks)
            - A. 照搬表结构和设计到 Postgresql 中
              - 技术可行, 但不是最优解，且会遗留成为历史原因
            - B. 重新设计
              - a. 二进制值存储到一个字段, BYTEA类型
                - 单个属性值理论最大1GB
              - b. Large Object(LO)特性, pg_largeobject
                - 但使用和设计有难度, 需熟练
                  > note: PostgreSQL的Large Object功能将二进制数据存储在一个特殊的系统表中（pg_largeobject），并通过一个OID（Object Identifier） 类型的值在用户表中引用 postgresql +1  。它更适合存储非常大的文件（接近或超过1GB），并提供了流式访问接口。但其管理更复杂，且删除引用行时不会自动清理Large Object（易造成“孤儿”数据），权限控制也更特殊 postgresql  。
          - 历史信号表(tsd.datapoint...)
            - 基于数据量大和性能考虑
              - 单独设计表结构, 不冗余继承字段(_type, _hierarchy...)
          - locks, systemsetting, coreschemas
            - 这三个表在 metadefintions 前初始化，需要先加载(旧逻辑也是这样做的)
      - 多层继承
        - 1. 现状: TAF 可以定义有继承关系的 service, 且在操作时可以用某一层级的服务操作，但都是同一数据库集合
          - baseobjects -> assets -> basicdevices -> devices
          - baseobjects -> assets -> engines
          - baseobjects -> containers
        - 2. 改造方向(比如 baseobjects)
          - A. 按照业务划分成 6个表
            - a. 使用 postgresql 的表继承特性
              - 多层继承下难以维护，且性能很差(查询父表会把所有子表都查询出来)
            - b. 每个表都冗余所有公共属性
              - 在当前北向不变的情况下有明显行为不一致问题
              - 之前是放在一个表的， 只要是在层级关系里面的 sercice 都可以查询到
              - 拆成多个表后, 需要考虑和维护: 子表记录是否也需要存储在父表里面? 是否需要冗余数据？增删查改的时候同时处理同系列表的记录等等
          - B. 保留和之前一样, 只创建一个表，但会造成宽表，在 Postgresql 下的查询，传输成本等比 Mongodb 会高很多
            - 先前架构师方案也是这样的
            - metadefinition 表已经有 36 列了
      - 功能性方面
        - schema 校验
        - plugin 热更新
        - 备份恢复
          - 同版本间
            - mongodump, mongorestore 等备份恢复指令用不了
          - 跨版本, 3.0 -> 3.0.1 ?
        - PI 升级
        - Postgresql
          - 事务
            - Postgresql 支持 ACID, 需注意是否出现数据部分成功部分失败，幻读，脏读等... (mongodb3.6.18 和 TAF 使用时不注重事务相关, 可能依赖其最终一致性模型)
          - 调优
            - 数据库连接池
            - 性能调优
              - shared_buffers
              - ...
  - 2. 后端插件
    - 1. 数据插件: 10个
    - 2. 业务功能插件: 36个
    - 3. VSphere Plugin: 1个
    - 4. Automation Agent: 3个
  - 3. 评估
    - 1. 可行性
    - 2. 工作量
    - 3. 测试
      - 1. 对比环境 mongodb
      - 2. 功能
        - 全部功能是否正常
        - 着重验证 排序, 分页, 筛选等的复杂查询
      - 3. 性能
    - 4. 维护
      - 1. 数据模型阻抗适配(核心问题)
        > note: Mongodb: metaDataDefinition 驱动整个系统的数据结构； 每个 Plugin 可以动态注册自己的 Schema； Schema 决定了数据的存储结构；  Postgresql: 动态 Schema -> 动态建表 -> 表结构变更 -> DDL 锁 -> 影响生产 每次 Plugin 注册新 Schema -> 需要 CREATE TABLE / ALTER TABLE
        - 系统核心设计是动态 Schema 驱动的
          - 平台能力边界长期被 JSON 历史模型绑定
        - Mongodb 天然支持任意结构哦的 JSON
          - 直接存储, 无需建表
        - 用 Postgresql 模拟 Mongodb
          - 动态创建/修改表
      - 2. 可预测的会大量使用 JSONB 类型字段
        - 索引效率，查询性能等可能会存在问题
      - 3. 动态 SQL 调试 和 性能问题(动态SQL+JSONB)分析困难
      - 4. 错误日志难以定位
      - ...

