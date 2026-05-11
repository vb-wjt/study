<!-- auto-generated from engineering\OpenAPI 规范.xmind by _build/extract-xmind.ps1, do NOT edit -->

# OpenAPI 规范

- 概述
  - OpenAPI Specification(OAS)，一种用于描述RESTful APIs 的规范，提供一种标准化的方式来定义 API 结构
  - 通常使用 JSON 或 YAML 格式编写， 可以被各种工具解析和处理，来生成文档、代码和测试用例
  - 最初是基于 Swagger 规范的，在2016年被 Linux 基金会托管，并重命名为 OpenAPI
  - 官网：https://openapi.apifox.cn/
- 文档组成
  - openapi
    - 必选，版本号
  - info
    - Info 对象，必选，元数据，基本信息
  - servers
    - Server 数组，可选，请求地址配置
  - tags
    - Tag 数组，可选，标签，可用于分组
    - 导入 postman 等工具，会根据 tag 来放到不同的文件夹层次下
  - paths
    - Paths，必选，定义请求API的地址，出入参引用等
  - components
    - Components 对象，可选，定义paths 中每个请求所需要的出入参model
  - security
    - Security Requirement 数组，可选，声明API使用的安全机制
  - externalDocs
    - External Documentation, 可选，附加文档，可作为扩展
- 使用优势
  - 一致性：使用标准化的描述语言可以让 API 更加一致和明确
  - 可读性
  - 自动化：可以生成API文档，客户端SDK，服务端代码和测试用例等
  - 版本控制：可以与代码一起进行版本控制，确保API 变化是可追踪和管理回溯的
  - 跨团队协作：可以让前后端团队在定义阶段就开始写作，同时各自进行开发

