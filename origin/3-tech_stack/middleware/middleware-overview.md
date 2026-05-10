<!-- 标签:[摘] —— 用户摘录稿(从 PDF/网络/课程摘抄) -->

# 中间件全景速查

> 按用途分类的中间件清单,作为"知道有这些东西"的快速对照(每条不展开,需要细节去对应的 `_curated/tech-stack/` 文档查)

| 用途 | 候选 |
|---|---|
| 网关 | Nginx、Kong、Zuul、Spring Cloud Gateway |
| 缓存 | Redis、MemCached、OsCache、EhCache、Caffeine |
| 搜索 | ElasticSearch、Solr |
| 熔断 | Hystrix、resilience4j、Sentinel |
| 负载均衡 | DNS、F5、LVS、Nginx、OpenResty、HAProxy |
| 注册中心 | Eureka、ZooKeeper、Redis、Etcd、Consul、Nacos |
| 认证鉴权 | JWT、Spring Security、OAuth2 |
| 消息队列 | RabbitMQ、Kafka、RocketMQ、ActiveMQ、Redis Stream |
| 系统监控 | Grafana、Prometheus、InfluxDB、Telegraf、Lepus |
| 文件系统 | OSS、NFS、FastDFS、MogileFS、MinIO |
| RPC 框架 | Dubbo、Motan、Thrift、gRPC |
| 构建工具 | Maven、Gradle |
| 集成部署 | Docker、Jenkins、Git、Maven、ArgoCD |
| 分布式配置 | Disconf、Apollo、Spring Cloud Config、Diamond、Nacos Config |
| 压测 | LoadRunner、JMeter、AB、webbench、wrk |
| 数据库 | MySQL、Redis、MongoDB、PostgreSQL、Memcached、HBase、ClickHouse |
| 网络 | 专用网络 VPC、弹性公网 IP、CDN |
| 数据库中间件 | DRDS、Mycat、360 Atlas、Cobar、ShardingSphere |
| 分布式框架 | Dubbo、Motan、Spring Cloud |
| 分布式任务 | XXL-JOB、Elastic-Job、Saturn、Quartz |
| 分布式追踪 | Pinpoint、CAT、Zipkin、SkyWalking、Jaeger |
| 分布式日志 | ElasticSearch、Logstash、Kibana、Redis、Kafka |

## 关联深度文档

- 缓存原理 → [`_curated/tech-stack/redis-deep-dive.md`](../../../_curated/tech-stack/redis-deep-dive.md)
- 消息队列三大问题 → [`_curated/tech-stack/mq-essentials.md`](../../../_curated/tech-stack/mq-essentials.md)
- 注册中心/网关/熔断(项目落地) → [`_curated/projects/asp-platform.md`](../../../_curated/projects/asp-platform.md) §portal-gateway
- 数据库中间件(ShardingSphere/dbproxy) → [`_curated/projects/asp-platform.md`](../../../_curated/projects/asp-platform.md) §SQL 解耦
