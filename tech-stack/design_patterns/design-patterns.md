<!-- 标签:[整] —— 用户整理稿(自己梳理过,可作简历/面试素材) -->

# 设计模式笔记

> 用途：从实际工程中归纳出的设计模式运用，去业务化记录，便于复用与面试复盘。
> 真实案例多数附有工程落地链接。

---

## 一、组合案例：静态工厂 + 模板方法 + 模板驱动的可扩展导出

> 一个高频且好讲的真实组合：把「一份数据 → 多格式 / 多版本输出」做成**加格式只改模板、不动代码**。

### 1. 各模式一句话

| 模式 | 一句话 | 在本案例中的角色 |
|---|---|---|
| **静态工厂方法 Static Factory** | 用具名静态方法替代构造器创建对象，封装复杂装配 | 把源实体组装成干净 DTO（`getInstance`） |
| **模板方法 Template Method** | 父类定义算法骨架，子类只定制可变步骤 | 抽象基类封装渲染流程，子类只选模板 |
| **模板驱动 / 数据与表现分离** | 数据用代码建模，格式交给模板引擎 | FreeMarker 模板承载输出格式，按版本组织 |

### 2. 组合解决的问题

```text
源数据(实体)
   │  静态工厂 getInstance()  —— 封装装配，产出干净 DTO
   ▼
分层 DTO (Data → Component → Mapping)
   │  模板方法 doGenerate()   —— 渲染骨架固定在基类
   ▼
按版本选模板 (templates/<version>/*.ftl)
   │  数据与表现分离          —— 加格式/版本只改模板
   ▼
多种产物 (json / sql / md ...) → 打包
```

### 3. 去业务化最小示例（订单报表）

```java
// 静态工厂：实体 → DTO
public static ReportData of(Order order) {
    ReportData d = new ReportData();
    d.title = order.getMonth() + " Report";
    d.rows  = order.getItems().stream().map(RowDTO::of).toList();
    return d;
}

// 模板方法：基类定骨架，子类只决定模板名
abstract class Generator {
    protected final Configuration cfg; // UTF-8 / 关缓存 / 目录加载
    protected String render(String tpl, Object data) throws Exception {
        StringWriter w = new StringWriter();
        cfg.getTemplate(tpl).process(data, w);
        return w.toString();
    }
    abstract String pickTemplate(String version, String name);
}
```

### 4. 取舍（面试可讲）

- ✅ 扩展成本从「改代码」降为「加模板」，接近开闭原则；构造逻辑收敛在工厂，调用方清爽。
- ⚠️ 模板无编译期校验 → 测试样例兜底；空值防御。
- ⚠️ 别在数据对象（DTO）里反向 `getBean(...)` 取容器 Bean（Service Locator），应参数注入，保持可测。

> 📎 真实工程落地见：[DriverHub 导出模块 §3.4](../../origin/2-projects/vertiv/Tool/DriverHub.md)
> 📎 FreeMarker 侧的通用范式见：[freemarker.md §13](../template/freemarker.md)

---

## 二、待补充

- 从已有的 `设计模式相关.xmind`（6 大设计原则 + UML 关系）、`策略模式.drawio` 归纳整理成文。
- 其他实战案例（策略、责任链等）陆续补充，尽量附工程链接。
