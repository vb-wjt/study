<!-- auto-generated from 3-tech_stack\server\undertow.xmind by _build/extract-xmind.ps1, do NOT edit -->

# undertow

- 简介
  - 用 Java 编写的灵活的高性能 Web 服务器，提供包括阻塞和基于 NIO 的非堵塞机制
  - SpringBoot提供的三个内置服务器之一（还有 Tomcat, Jetty），在高并发下吞吐量比其他两个要好
  - 完全为嵌入式设计的项目，提供易用的构建器API, 完全向下兼容 Java EE Servlet 3.1 和低级非堵塞的处理器
- 特性，优点
  - HTTP/2 支持
    - 开箱即用，无需覆盖启动类路径
  - HTTP升级
    - 允许多种协议在HTTP端口上复用
  - Web套接字支持，包括 JSR-356支持
  - Servlet 4.0
    - 包括对嵌入式 servlet的支持，还可以在同一部署中混合使用 Servlet 和本机 undertow 非阻塞处理程序
  - 可嵌入
    - 可嵌入到应用程序中，或只需几行代码就可以独立运行
  - 灵活
    - 通过将处理程序链接在一起来配置，可以根据需要添加尽可能多的功能，无需为未使用的功能付费
- 来源
  - https://undertow.io/
  - https://juejin.cn/post/7128787416470519821
- 配置优化
  - worker-threads
    - 阻塞任务线程池，与业务有关，默认为cpu核数的8倍，如2核的可以支持16个线程同时操作
    - 可以增加线程数，同时监控CPU 利用率和内存利用率
  - io-threads
    - 主要执行非阻塞任务。默认每个CPU核心一个线程，不可以设置过大，否则会报错：打开文件数过多
  - buffer-Size
    - 每块buffer的空间大小，越小空间被利用越充分，不要设置太大。可以 1024kb
  - direct-buffers
    - 可以设置为 true， 使用直接内存（堆外内存）来存储缓冲区，减少垃圾回收的开销
  - no-request-timeout
    - 连接在不处理请求的情况下闲置的时间
  - 开启HTTP/2
    - 启用 HTTP2，提高网络传输效率
    - server.undertow.enabled=true
  - 示例：
    - # 增加IO线程数 server.undertow.io-threads=16   # 增加工作线程数 server.undertow.worker-threads=256   # 设置缓冲区大小 server.undertow.buffer-size=1024   # 使用直接内存 server.undertow.direct-buffers=true  # 连接在不处理请求的情况下闲置的时间 server.undertow.no-request-timeout = 60000   # 启用HTTP/2 server.undertow.enabled=true

