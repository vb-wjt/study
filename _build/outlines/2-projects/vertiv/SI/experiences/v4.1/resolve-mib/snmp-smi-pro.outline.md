<!-- auto-generated from 2-projects\vertiv\SI\experiences\v4.1\resolve-mib\snmp-smi-pro.drawio by _build/extract-drawio.ps1, do NOT edit -->

## [Page 1] 第 1 页

### Nodes (32)
  - fileId#1
  - fileId#2
  - fileId#3
  - 入参
  - nameInputStream#1
      (include name + fileInputstream)
  - nameInputStream#2
      (include name + fileInputstream)
  - nameInputStream#3
      (include name + fileInputstream)
  - 转化
  - base mib info
  - mibObjectTypes
  - mibObjects
  - mibSyntaxs
  - ....
  - resolve process
  - 1. 解析MIB文件为 ModuleInfo
  - 2.检查模块依赖关系并排序
  - 3. 语法检查和语义验证
  - 4. 持久化到仓库目录或直接加载到内存
  - 3.1 识别模块前缀和对象名称
  - SmiManager: 核心处理类
  - 3.2 查找对应 MIB对象定义
  - 3.3 如果是表索引，进行索引值解码
  - 3.4 组合生成完整数字OID
  - 多线程并行编译 MIB 模块
  - 线程安全的模块加载和访问
  - OID解析流程
  - points
  - alarms
  - 解析结果

### Edges (12)
  - fileId#1  ->  nameInputStream#1
  - fileId#2  ->  nameInputStream#2
  - fileId#3  ->  nameInputStream#3
  - nameInputStream#1  ->  ?
  - nameInputStream#2  ->  ?
  - nameInputStream#3  ->  ?
  - 1. 解析MIB文件为 ModuleInfo  ->  2.检查模块依赖关系并排序
  - 2.检查模块依赖关系并排序  ->  3. 语法检查和语义验证
  - 3. 语法检查和语义验证  ->  4. 持久化到仓库目录或直接加载到内存
  - 3.1 识别模块前缀和对象名称  ->  3.2 查找对应 MIB对象定义
  - 3.2 查找对应 MIB对象定义  ->  3.3 如果是表索引，进行索引值解码
  - 3.3 如果是表索引，进行索引值解码  ->  3.4 组合生成完整数字OID

