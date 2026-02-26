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


