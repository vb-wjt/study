# SOAP 1.1 与 SOAP 1.2 的区别及相关内容

## 核心概念回顾：SOAP (Simple Object Access Protocol)

* **定义：** SOAP 是一种基于 XML 的协议规范，用于在分散的分布式环境中交换结构化信息。它是 Web 服务（Web Services）的核心通信协议之一。
* **目的：** 实现应用程序之间跨平台、跨语言、跨网络的互操作性。
* **核心：** 定义了一个简单的、可扩展的 XML 信封格式，用于封装消息内容、消息处理指令（如路由、安全、可靠性等）以及错误信息。
* **传输：** SOAP 消息本身是独立于传输协议的，但最常见的是通过 HTTP(S) 传输，也可以使用 SMTP、JMS、TCP 等。

## SOAP 1.1 与 SOAP 1.2 的主要区别

### 1. 规范命名空间 (Namespace)

- **SOAP 1.1:** `http://schemas.xmlsoap.org/soap/envelope/`
- **SOAP 1.2:** `http://www.w3.org/2003/05/soap-envelope`
- **意义：** 这是最根本的区别。SOAP 处理器通过识别信封的命名空间来确定消息版本。使用错误的命名空间会导致解析失败。SOAP 1.2 的命名空间反映了其 W3C 标准身份。

### 2. HTTP 绑定 (HTTP Binding) - 媒体类型 (Content-Type)

- **SOAP 1.1:** 使用 `text/xml` 作为 HTTP `Content-Type` 头
- **SOAP 1.2:** 使用 `application/soap+xml` 作为 HTTP `Content-Type` 头
- **意义：**
  - `text/xml` 是通用的 XML 媒体类型，不够精确, 可能导致中间件（如代理、防火墙）或服务器进行不必要的处理（如内容嗅探）。
  - `application/soap+xml` 明确标识了消息是 SOAP 消息，提高了互操作性和处理效率

### 3. HTTP 绑定 - SOAP Action

- **SOAP 1.1:** 强制使用 `SOAPAction` HTTP 请求头。它的值通常是一个 URI（或空字符串/引号），指示消息的意图或目标操作。规范对其格式要求比较宽松。

- **SOAP 1.2:** 
  
  - 使用 `action` 参数作为媒体类型的一部分（例：`Content-Type: application/soap+xml; action="http://example.org/ProcessOrder"`）
  - 为向后兼容允许（但不要求）支持 `SOAPAction` 头

- **意义：** 
  
  * SOAP 1.2 的方式更符合 HTTP 标准（使用媒体类型参数），更清晰。
  
  * 移除了对 `SOAPAction` 的依赖提高了灵活性。
  
  * 向后兼容性处理允许 SOAP 1.2 端点与期望 `SOAPAction` 的旧客户端（SOAP 1.1）交互。

### 4. 错误处理 (Fault Handling)

| 组件   | SOAP 1.1              | SOAP 1.2                     |
| ---- | --------------------- | ---------------------------- |
| 错误代码 | `<faultcode>` (预定义枚举) | `<Code>` + 可嵌套的 `<Subcode>`  |
| 错误描述 | `<faultstring>`       | `<Reason>` + 多语言 `<Text>`    |
| 错误节点 | `<faultactor>`        | `<Node>` + `<Role>` (节点角色信息) |
| 详情   | `<detail>`            | `<Detail>` (作用相同)            |

* **SOAP 1.1:** 使用 `<faultcode>`, `<faultstring>`, `<faultactor>`, `<detail>` 元素。
  
  * `<faultcode>` 是预定义的枚举值（如 `VersionMismatch`, `MustUnderstand`, `Client`, `Server`）。
  
  * `<faultstring>` 是人类可读的错误描述。

* **SOAP 1.2:** 重构为更结构化和灵活的错误模型：
  
  * `<Code>` 元素：包含一个主错误代码（`Value`，类似 1.1 的顶级分类，如 `env:Sender`, `env:Receiver`）和一个可选的 `<Subcode>` 元素。`<Subcode>` 可以递归嵌套，提供更精细的错误分类。
  
  * `<Reason>` 元素：包含一个或多个 `<Text>` 元素，每个 `<Text>` 可以指定 `xml:lang` 属性，提供多语言的人类可读错误描述。取代了 `<faultstring>`。
  
  * `<Node>` 元素 (可选)：指示在处理路径上哪个节点产生了错误。取代并扩展了 `<faultactor>`。
  
  * `<Role>` 元素 (可选)：指示在消息路径中发生错误的节点所扮演的角色（如 `http://www.w3.org/2003/05/soap-envelope/role/next`）。
  
  * `<Detail>` 元素 (可选)：包含与 Body 块相关的、应用程序特定的错误信息。作用与 1.1 相同。

* **意义：** SOAP 1.2 的错误信息更丰富、结构化、可扩展，支持国际化，更容易诊断问题。

### 5. 处理模型与 `MustUnderstand` 属性

- **SOAP 1.1:** `mustUnderstand="0"` 或 `"1"` (数字)
- **SOAP 1.2:** `mustUnderstand="true"` 或 `"false"` (布尔值)
- **增强：** 引入 `env:Upgrade` 头部块处理版本协商

### 6. 数据模型与编码 (Data Model & Encoding)

| 方面   | SOAP 1.1                                    | SOAP 1.2                                                     |
| ---- | ------------------------------------------- | ------------------------------------------------------------ |
| 编码规则 | 包含在核心规范中 (SOAP-ENC)                         | 移出核心规范成为独立可选模块                                               |
| 推荐做法 | 常用但互操作性差                                    | **强烈推荐**使用基于 XML Schema 的 Literal 编码 (`document/literal` 样式) |
| 命名空间 | `http://schemas.xmlsoap.org/soap/encoding/` | `http://www.w3.org/2003/05/soap-encoding` (但不推荐使用)           |

* **意义：**
  
  * 分离核心和编码提高了模块化。
  
  * 明确鼓励使用标准 XML Schema 进行数据定义和验证（`document/literal` 或 `rpc/literal` 样式），这极大地提高了互操作性和与 XML 生态系统的兼容性。避免专有编码是 SOAP 1.2 实践中的一个关键点。
    
    

### 7. 规范结构与模块化

- **SOAP 1.1:** 单一规范文档
- **SOAP 1.2:** 拆分为多部分：
  - Part 0: Primer 
  - Part 1: Messaging Framework 
  - Part 2: Adjuncts
- **意义：** 更清晰、模块化，易于理解和扩展

### 8. HTTP 状态码的使用

- **SOAP 1.1:** 未明确规定，错误时常用 `200 OK + Fault`
- **SOAP 1.2:** 明确建议：
  - 协议级错误 → 使用 `4xx/5xx` HTTP 状态码
  - 应用逻辑错误 → `200 OK + SOAP Fault`
- **意义：** 更符合 HTTP 语义，利于中间件处理

### 9. 兼容性

- **设计意图：** SOAP 1.2 支持有限向后兼容（如允许 `SOAPAction`）
- **现实情况：**  由于核心命名空间不同，SOAP 1.1 和 SOAP 1.2 端点通常**不能直接互操作**。一个期望 `http://schemas.xmlsoap.org/soap/envelope/` 的 SOAP 1.1 处理器会拒绝带有 `http://www.w3.org/2003/05/soap-envelope` 的消息，反之亦然。
- **解决方案：** 现代工具包（如 Apache CXF, WCF）可同时支持双版本

## 总结对比表

| 特性                    | SOAP 1.1                                    | SOAP 1.2                                   | 意义/改进                  |
|:--------------------- |:------------------------------------------- |:------------------------------------------ |:---------------------- |
| **命名空间**              | `http://schemas.xmlsoap.org/soap/envelope/` | `http://www.w3.org/2003/05/soap-envelope`  | 根本区别，SOAP 1.2 是 W3C 标准 |
| **HTTP Content-Type** | `text/xml`                                  | `application/soap+xml`                     | 更精确，避免内容嗅探             |
| **SOAP Action**       | `SOAPAction` 头 (必需)                         | `action` 媒体类型参数 (推荐) + `SOAPAction` 头 (可选) | 符合 HTTP 标准，支持向后兼容      |
| **错误处理**              | 简单结构                                        | 结构化代码体系 + 多语言支持                            | 更精细的错误分类和诊断            |
| **`mustUnderstand`**  | `"0"` / `"1"`                               | `"true"` / `"false"`                       | 布尔值更直观                 |
| **数据编码**              | 包含在规范中 (互操作性差)                              | **强烈推荐** XML Schema Literal 编码             | 提高与 XML 生态兼容性          |
| **规范结构**              | 单一文档                                        | 模块化 (Part 0/1/2)                           | 更易理解和扩展                |
| **HTTP 状态码**          | 常为 `200 OK` + SOAP Fault                    | 建议协议错误用 `4xx/5xx`                          | 符合 HTTP 语义             |
| **互操作性**              | 存在模糊性问题                                     | 解决 1.1 的模糊性                                | 提高不同实现的兼容性             |
| **W3C 状态**            | W3C Note                                    | W3C Recommendation                         | 官方成熟标准                 |

## 结论与建议

1. **首选 SOAP 1.2：** 新项目应使用 SOAP 1.2，它解决了 1.1 的主要缺陷
2. **编码规范：** 无论版本都**强烈推荐** `document/literal` 或 `rpc/literal` 样式
3. **数据标准：** 避免使用 SOAP 专有编码，采用 XML Schema (XSD)
4. **兼容策略：**
   - 新系统 → 纯 SOAP 1.2
   - 旧系统维护 → SOAP 1.1
   - 混合环境 → 使用支持双版本的工具包（如 Apache CXF, .NET WCF）
5. **错误处理：** 在 SOAP 1.2 中充分利用结构化错误代码体系

> **关键实践提示：** 调试 SOAP 服务时，首先检查命名空间和 Content-Type 头，90% 的版本兼容问题由此引起。
