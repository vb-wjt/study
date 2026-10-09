<!-- 标签:[摘] —— 用户摘录稿(从 PDF/网络/课程摘抄) -->

# FreeMarker 模板对不同类型数据的使用方法

## 1. 字符串 (String)

```
<#-- 定义字符串 -->
<#assign name = "John Doe">

<#-- 输出字符串 -->
Hello, ${name}!

<#-- 字符串连接 -->
Your username is: ${"user_" + name?lower_case?replace(" ", "_")}

<#-- 字符串操作 -->
Length of name: ${name?length}
First 4 characters: ${name[0..3]}
Uppercase: ${name?upper_case}
Lowercase: ${name?lower_case}
Contains "Doe": ${name?contains("Doe")?c}
```

## 2. 数字 (Number)

```ftl
<#-- 定义数字 -->
<#assign age = 30>
<#assign price = 19.99>

<#-- 基本输出 -->
Age: ${age}
Price: ${price}

<#-- 数字格式化 -->
Price: ${price?string.currency}
Price: ${price?string["0.##"]}
Large number: ${1000000?string["#,###"]}

<#-- 数学运算 -->
Next year age: ${age + 1}
Total price: ${price * 1.2}
Is adult: ${(age >= 18)?string("yes", "no")}
```

## 3. 布尔值 (Boolean)

```ftl
<#-- 定义布尔值 -->
<#assign isActive = true>
<#assign hasPermission = false>

<#-- 直接输出 -->
Status: ${isActive?c}

<#-- 条件输出 -->
<#if isActive>
    Account is active
<#else>
    Account is inactive
</#if>

<#-- 布尔运算 -->
<#if hasPermission && isActive>
    You can perform this action
</#if>
```

## 4. 日期和时间 (Date/Time)

```ftl
<#-- 定义日期 -->
<#assign now = .now>
<#assign someDate = someJavaDateObject>

<#-- 日期格式化 -->
Current date: ${now?date}
Current time: ${now?time}
Current datetime: ${now?datetime}
Formatted: ${now?string("yyyy-MM-dd HH:mm:ss")}

<#-- 日期操作 -->
<#assign nextWeek = now + 7?days>
Next week: ${nextWeek?date}

<#-- 日期比较 -->
<#if now < someDate>
    The date is in the future
</#if>
```

## 5. 列表/序列 (List/Sequence)

```ftl
<#-- 定义列表 -->
<#assign colors = ["red", "green", "blue"]>
<#assign numbers = [1, 2, 3, 4, 5]>

<#-- 遍历列表 -->
<#if (colors?has_content)>
    <#list colors as color>
        - ${color}
    </#list>
<#else>
    列表为空或不存在
</#if>

<#-- 访问元素 -->
First color: ${colors[0]}
Last number: ${numbers?last}

<#-- 列表操作 -->
List size: ${colors?size}
Joined list: ${colors?join(", ")}
First three: ${numbers[0..2]}

<#-- 条件判断 -->
<#if colors?seq_contains("green")>
    Green is in the list
</#if>
```

## 6. 哈希/Map (Hash/Map)

```ftl
<#-- 定义哈希 -->
<#assign user = {"name": "Alice", "age": 25, "active": true}>

<#-- 访问属性 -->
Name: ${user.name}
Age: ${user["age"]}

<#-- 遍历哈希 -->
<#list user?keys as key>
    ${key}: ${user[key]}
</#list>

<#-- 哈希操作 -->
Has 'name' key: ${user?keys?seq_contains("name")?c}
Values: ${user?values?join(", ")}
```

## 7. 空值处理 (null)

```ftl
<#-- 安全处理null值 -->
${possiblyNull!}
${possiblyNull!"default"}

<#-- 检查null -->
<#if possiblyNull??>
    Value exists: ${possiblyNull}
<#else>
    Value is null or missing
</#if>
```

## 8. 自定义对象 (Java Beans)

```ftl
<#-- 假设有一个User对象传入模板 -->
User: ${user.name} (${user.age} years old)

<#-- 调用方法 -->
<#if user.isAdmin()>
    Welcome, administrator!
</#if>

<#-- 访问属性 -->
Joined on: ${user.joinDate?date}

<#-- 基本用法 -->
${user.name!}              <#-- 如果name为null则输出空字符串 -->
${user.name!"匿名用户"}    <#-- 如果name为null则输出默认值 -->

<#-- 嵌套属性安全访问 -->
${(user.address.city)!'未知地区'}
```

## 9. 宏 (Macros)

```ftl
<#-- 定义宏 -->
<#macro greet name>
    Hello, ${name}!
</#macro>

<#-- 使用宏 -->
<@greet name="Bob"/>

<#-- 带默认值的宏 -->
<#macro welcome user="Guest">
    Welcome, ${user}!
</#macro>

<@welcome/>
<@welcome user="Admin"/>
```

## 10. 包含其他模板

```ftl
<#include "header.ftl">

<#-- 动态包含 -->
<#assign templateName = "footer_${locale}.ftl">
<#include templateName>
```

## 11. 特殊变量

```ftl
<#list items as item>
    ${item?counter}. ${item}
    ${item?index}
    <#if item?is_first>First item</#if>
    <#if item?is_last>Last item</#if>
</#list>

${.main_template_name}
${.now}
${.locale}
```

## 12. 常用方法

### 1.  ?has_content

检查变量 不是 null, 不是空字符串(""), 不是空集合/数组, 不是空Map

2.

## 13. 实战范式：模板驱动的可扩展导出（Template Method + 数据/表现分离）

> 场景：**一份数据模型要导出成多种格式、还要随版本演进**（如 `json` / `sql` / `md` 多产物，且格式会迭代）。
> 若用 Java 硬拼字符串，格式一变就改代码、易错、多版本难维护。FreeMarker 适合把"输出格式"从代码里剥离出去。

### 13.1 核心思想：数据与表现分离

- **Java 只建数据模型**（`Map<String,Object>` 或 JavaBean），不关心最终长什么样。
- **表现（格式）全部在 `.ftl` 模板里**，加格式 / 改排版不动 Java。

### 13.2 四个落地要点

1. **抽象基类封装 `Configuration`，子类只定制"选哪个模板"（Template Method）**

   ```java
   public abstract class TemplateGenerator {
       protected Configuration cfg;
       public void init() throws Exception {
           cfg = new Configuration(Configuration.VERSION_2_3_32);
           cfg.setDefaultEncoding("UTF-8");
           cfg.setCacheStorage(new NullCacheStorage());        // 关缓存，便于热更新模板
           cfg.setDirectoryForTemplateLoading(new File(path)); // 按目录加载
       }
       // 渲染骨架固定，子类只决定模板名
       protected String doGenerate(String templateName, Object data) throws Exception {
           StringWriter w = new StringWriter();
           cfg.getTemplate(templateName).process(data, w);
           return w.toString();
       }
   }
   ```

2. **按版本组织模板目录**：`templates/<version>/report.ftl`，运行时按 `version` 选目录——**新增版本 = 加目录，代码零改动**。

3. **一个数据模型复用于多种产物**：同一份 DTO 用标志位 / 不同模板渲染出多份输出（如 `report.json.ftl`、`report.sql.ftl`、`report.md.ftl`）。

4. **用静态工厂把源数据组装成干净 DTO**，再丢给模板，保持数据层与渲染层解耦。

### 13.3 去业务化最小示例

```java
// 数据模型（中性示例：订单报表）
Map<String, Object> data = Map.of(
    "title", "Monthly Report",
    "orders", List.of(
        Map.of("id", "A001", "amount", 120),
        Map.of("id", "A002", "amount", 80)
    )
);
String md = generator.doGenerate("v2/report.md.ftl", data);
```

```ftl
<#-- v2/report.md.ftl -->
# ${title}

| Order | Amount |
|---|---:|
<#list orders as o>
| ${o.id} | ${o.amount?string["#,##0"]} |
</#list>

Total: ${orders?map(o -> o.amount)?sum}
```

### 13.4 取舍（面试可讲）

- ✅ 扩展成本从「改代码」降为「加/改模板」，接近开闭原则。
- ⚠️ 模板**没有编译期校验**——需要测试样例兜底；空值用 `!` / `??` 防御（见本文 §7）。
- ⚠️ 避免在数据对象里反向依赖 Spring 容器（Service Locator），把生成器以参数注入，保持可测。

> 📎 **真实工程落地与完整设计 / 面试经历**见：[DriverHub 导出模块 §3.4](../../origin/2-projects/vertiv/Tool/DriverHub.md)


