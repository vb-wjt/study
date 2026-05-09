# Maven 基础速查

标签:`[就绪]` `[需补充]` `[盲点]`⚠️ `[面试高频]`🎯

> 你的 `file/3-tech_stack/build/maven.md` 只有一行 `todo`,但 Maven 是 Java 后端**最基础的工具**。
>
> 这份文档**不是 Maven 完整教程**,而是聚焦你工程里**真的会用到 / 面试真的会问**的内容。
>
> 用过的内容不会重复你已知,**只补你可能没系统化的部分**。
>
> 看完后请回头**校对 / 补充 / 替换**为你的实际经验,这份文档就成了你的。

---

## 1. Maven 是什么(一句话)

**Maven** 是 Java 项目的**依赖管理 + 构建工具**,核心是 `pom.xml`(项目对象模型)+ 中央仓库。

> 与 Gradle 的区别: Maven 用 XML(声明式),Gradle 用 Groovy/Kotlin(脚本式)。Maven 更稳定,Gradle 更灵活。Vertiv 用的是 Maven。

---

## 2. 核心概念

### 2.1 GAV 坐标

每个依赖(包括你自己的项目)都用 **3 段坐标**唯一标识:

```xml
<groupId>com.avocent.mtp</groupId>      <!-- 组织 / 公司域名倒序 -->
<artifactId>mtp-core</artifactId>        <!-- 项目名 -->
<version>1.31.11-pi</version>            <!-- 版本号 -->
```

**版本号约定**(SemVer):
- `1.0.0` = MAJOR.MINOR.PATCH
- `1.0.0-SNAPSHOT` = 开发版,每次构建会重新拉取
- `1.0.0-RELEASE` 或 `1.0.0` = 正式版,不可变

### 2.2 生命周期 (Lifecycle)

Maven 有 **3 个生命周期**,常用的是 `default`:

```
default 生命周期(简化版):
  validate → compile → test → package → verify → install → deploy
```

| 阶段 | 做什么 |
|---|---|
| `compile` | 编译源码到 target/classes |
| `test` | 跑单元测试 |
| `package` | 打成 jar / war(target/*.jar) |
| `install` | 装到本地 ~/.m2/repository |
| `deploy` | 推到远程仓库(Nexus / Artifactory) |

**常用命令**:

```bash
mvn clean                    # 清掉 target
mvn clean compile            # 清+编译
mvn clean install            # 清+全流程,装到本地
mvn clean install -DskipTests # 跳过测试(开发常用)
mvn dependency:tree          # 查依赖树(看冲突)
mvn versions:display-dependency-updates  # 查可升级依赖
```

### 2.3 依赖管理 (你最常用)

#### A. dependencies vs dependencyManagement

```xml
<!-- dependencyManagement: 父 pom 声明版本,子 pom 引用时不用写版本 -->
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>com.hazelcast</groupId>
      <artifactId>hazelcast</artifactId>
      <version>5.6.0</version>
    </dependency>
  </dependencies>
</dependencyManagement>

<!-- dependencies: 真正引入,版本可省略 -->
<dependencies>
  <dependency>
    <groupId>com.hazelcast</groupId>
    <artifactId>hazelcast</artifactId>
    <!-- 版本省略,用父 pom 的 -->
  </dependency>
</dependencies>
```

> **为什么这么用**:多模块项目里,**统一版本管理**避免子模块各自写不同版本,是大型项目的标准做法。

#### B. scope (依赖作用域)

| scope | 编译 | 测试 | 运行时 | 例 |
|---|:---:|:---:|:---:|---|
| `compile`(默认) | ✓ | ✓ | ✓ | spring-boot-starter |
| `test` | ✗ | ✓ | ✗ | junit, mockito |
| `provided` | ✓ | ✓ | ✗ | servlet-api(由 Tomcat 提供) |
| `runtime` | ✗ | ✓ | ✓ | mysql-connector(编译期不需要) |
| `system` | ✓ | ✓ | ✗ | 本地 jar(已不推荐) |
| `import` | — | — | — | 在 dependencyManagement 中导入其他 BOM |

> **面试常问**: provided 和 runtime 的区别?——provided 是编译要 / 运行时容器有(servlet-api),runtime 是编译不要 / 运行要(JDBC driver)。

#### C. 依赖冲突

Maven 用 **"最近优先"** 原则解决冲突:依赖树中**离根节点最近**的版本胜出。

```bash
mvn dependency:tree            # 看完整树
mvn dependency:tree -Dverbose  # 看冲突过程
```

如果想强制用某个版本,在 dependencyManagement 显式声明,或用 `<exclusions>` 排除冲突来源:

```xml
<dependency>
  <groupId>com.example</groupId>
  <artifactId>some-lib</artifactId>
  <exclusions>
    <exclusion>
      <groupId>org.slf4j</groupId>
      <artifactId>slf4j-log4j12</artifactId>
    </exclusion>
  </exclusions>
</dependency>
```

### 2.4 多模块项目 (Vertiv 在用)

#### 父 pom (聚合 + 继承)

```xml
<!-- pi-server/pom.xml (父) -->
<packaging>pom</packaging>
<modules>
  <module>pi-domain</module>
  <module>pi-application</module>
  <module>pi-infra-persistence</module>
  <!-- ... -->
</modules>
```

#### 子模块

```xml
<!-- pi-domain/pom.xml -->
<parent>
  <groupId>com.vertiv.pi</groupId>
  <artifactId>pi-server</artifactId>
  <version>4.0.0-SNAPSHOT</version>
</parent>
<artifactId>pi-domain</artifactId>
```

> **简历加分**: 你 PI 4.0 重构方案设计了 `pi-bom / pi-parent / pi-domain / pi-application / pi-feature-* / pi-app` 这种 BOM + parent + 多个 feature 模块的结构,这是大型项目的标准实践。

### 2.5 BOM (Bill of Materials)

> Spring Boot 你应该已经在用了:`spring-boot-dependencies` 就是个 BOM。

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-dependencies</artifactId>
      <version>3.5.6</version>
      <type>pom</type>
      <scope>import</scope>  <!-- BOM 用 import scope -->
    </dependency>
  </dependencies>
</dependencyManagement>
```

**好处**: 引入 Spring Boot 全家桶时,所有版本都统一(避免 spring-core 5.x + spring-web 6.x 这种版本错配)。

---

## 3. 配置文件 (settings.xml)

`~/.m2/settings.xml` 是 Maven 的**全局配置**,**不要提交到 Git**。常见用途:

### 3.1 镜像仓库 (国内必备)

```xml
<mirrors>
  <mirror>
    <id>aliyun</id>
    <name>aliyun maven</name>
    <url>https://maven.aliyun.com/repository/public</url>
    <mirrorOf>central</mirrorOf>
  </mirror>
</mirrors>
```

### 3.2 私服认证

```xml
<servers>
  <server>
    <id>nexus-vertiv</id>
    <username>your-username</username>
    <password>{加密后的密码}</password>
  </server>
</servers>
```

> **加密**: 用 `mvn --encrypt-master-password` + `--encrypt-password`,把密文写进 settings-security.xml。

### 3.3 profile

可以定义多套环境配置(dev/test/prod),通过 `-Pdev` 激活。

---

## 4. 常用插件

| 插件 | 用途 |
|---|---|
| `maven-compiler-plugin` | 编译,设置 source/target 版本 |
| `maven-surefire-plugin` | 跑单元测试 |
| `maven-failsafe-plugin` | 跑集成测试 |
| `maven-jar-plugin` / `maven-war-plugin` | 打 jar/war |
| `maven-shade-plugin` | 打 fat-jar(把所有依赖打进一个 jar) |
| `spring-boot-maven-plugin` | Spring Boot 专用,生成可执行 jar |
| `maven-enforcer-plugin` | 强制规则(禁止某依赖、强制 Java 版本等) |
| `versions-maven-plugin` | 升级 / 查看依赖版本 |
| `maven-dependency-plugin` | 依赖分析(`tree` / `analyze`) |
| `flatten-maven-plugin` | 多模块发布时,扁平化 pom |
| `jacoco-maven-plugin` | 代码覆盖率 |
| `pmd-plugin` / `checkstyle-plugin` / `spotbugs-plugin` | 代码质量 |

---

## 5. 实战经验 / 你应该知道的

### 5.1 IDEA 中的 "Reload" / "Reimport"

改 pom.xml 后,IDEA 不会自动同步,需要点 "Reload" 按钮 (右上角 Maven 工具窗口的刷新图标)。

### 5.2 离线模式

`mvn -o ...` 不联网,只用本地仓库。带宽差时常用。

### 5.3 跳过测试的两种方式

```bash
mvn install -DskipTests          # 编译测试代码,不执行
mvn install -Dmaven.test.skip=true  # 不编译也不执行 (更彻底)
```

### 5.4 强制更新 SNAPSHOT

```bash
mvn install -U   # 强制重新拉取所有 SNAPSHOT 依赖
```

### 5.5 看哪个依赖触发了某个传递依赖

```bash
mvn dependency:tree -Dincludes=com.fasterxml.jackson.core:jackson-databind
```

---

## 6. 大版本升级的痛点(你 SI 4.1 已踩过)

> 链接到 [`../projects/dependency-upgrade.md`](../projects/dependency-upgrade.md) §3

**与 Maven 直接相关**的痛点:

- **传递依赖版本冲突**: 升 Spring Boot 3 时,所有 `spring-*` 都要跟着升,但其他第三方库可能还引了老版本 `spring-*`
- **packaging 元素变化**: Spring Boot 3 的可执行 jar 内部结构变了(`BOOT-INF` → `META-INF` 等)
- **maven-shade-plugin** 与 Spring Boot 不兼容: 用 `spring-boot-maven-plugin` 打可执行 jar,不要混用 shade

---

## 7. 你下一步可以补的

> 这些是面试时可能被问、我手上没你实际经验的内容。补上就有谈资:

| 主题 | 你补什么 |
|---|---|
| 多模块结构(以 pi-server / mtp-core 为例) | 画一张你 PI 4.0 模块依赖图 |
| 私服(Nexus / Artifactory)使用 | Vertiv 用的是哪个?上传 jar 流程? |
| Profile 实战 | dev / test / prod 你们怎么分? |
| 自定义 Maven plugin | 有没有写过?如果没,可以写一个简单的(简历加分) |
| Maven 3 → 4 的差异 | (Maven 4 还在 alpha,但可以了解) |
| Maven Wrapper(`mvnw`) | 类似 Gradle Wrapper,锁定 Maven 版本 |

---

## 8. 与你 `file/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| 原始 Maven 笔记 | (本文) | `file/3-tech_stack/build/maven.md` (1 行 todo) |
| 大版本升级中 Maven 的角色 | §6 | [`../projects/dependency-upgrade.md`](../projects/dependency-upgrade.md) |
| PI 多模块设计 | §2.4 | `file/2-projects/vertiv/refactor_pi/docs/rebuild-plan/01-overview.md` §3 |

---

> **下一步**: [`linux-filesystem-and-perms.md`](./linux-filesystem-and-perms.md) (你的 linux-privilege 缺文件系统部分)
