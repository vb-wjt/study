## 产品
PowerInsight(PI) 是一款免费的用于 UPS 和 PDU 的监控软件平台

## 背景
1. Mongodb 的 SSPL license 问题对于 PI 的这类分发构建物的产品来说存在法律风险
2. SpringBoot, JAVA 等依赖库的版本过于古老而存在安全问题, 漏洞等
3. 信号采集层所使用的 Ie Engine 为 C++ 语言编写的, 且由其他团队负责, 不由 PI 团队负责和推进, 需使用已有成功使用经验的 Zero Engine 来替代
4. 随着时间的流逝以及历史代码和技术债务等的积累, 其所存在的安全问题等越来约多
5. offering 需求: 支持多款 windows 和 linux 的操作系统

## 架构组成
```text
- 前端: Angular + Lumos(私有组件库)
- 后端:
    - SI: Taf + SpringBoot + SpringSecurity + Hazelcast(分布式缓存)
    - ZE: SpringBoot + Mybatis-Plus + Undertow(服务器) + Caffeine(本地缓存) + ActiveMQ
- 数据库: PostgreSQL + sqlite
```


## 负责的内容
### Ie Engine 替换为 Zero Engine
1. 去除 Ie Engine 的所有内容, 包括代码, 代码引用, 打包二进制等
2. 添加 Zero Engine 的所有内容, 包括代码, 代码使用, Windows 和 Linux 双打包二进制等
3. 引擎切换所带来的添加设备, 信号采集, 告警上送, 控制下发, 心跳机制等的复用与适配


### PostgreSQL 在不同操作系统上的离线安装
1. Windows 上的二进制包安装 Windows(11), windows server(2022, 2025)
2. Linux 上的分操作系统类别的离线包安装, 包括所需依赖等等, 面对 rhel(8.10,9.6,9.7,9.8,10.0,10.1,10.2), ubuntu desktop(24.04,26.04)


### PI 在多个操作系统上的分析与测试范围方法论
1. 主要由 PG 在多个操作系统上的差异引起
2. 分析和采集各个操作系统上的库版本


### 安全问题修复 - 服务权限
1. Windows 上的服务账户管理和隔离
2. Linux 上的服务降权, 目录等的文件权限


### 安全问题修复 - 动态证书
1. TLS 证书 等


### 安全问题修复 - 动态加密体系
1. HKDF 加密体系与实现


### 其他
1. CMD 延迟展开导致删除 C盘事故
2. Linux 的相关学习
