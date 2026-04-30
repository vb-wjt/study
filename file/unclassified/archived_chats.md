# 编译 documentdb
https://chat.z.ai/c/18207b8a-7bb8-4db3-90a4-25247b55aa09

📄 简历项目经历建议（可直接复制使用）
项目经历：开源文档数据库 FerretDB 环境搭建与可行性研究
技术栈：Go, C/C++, PostgreSQL, CMake, Visual Studio, Docker, WSL2, Linux Kernel
项目描述：
在 Windows 环境下调研 MongoDB 的开源替代方案 FerretDB，尝试在不依赖 Docker 的前提下构建基于 PostgreSQL + 微软 DocumentDB 扩展的数据库服务，并评估其在 Windows 原生环境下的落地可行性。

主要职责与产出：

跨平台编译实践：成功在 Windows 环境下从源码编译 FerretDB 核心程序；针对 DocumentDB (C++ 扩展) 进行本地编译尝试，配置了 Visual Studio 与 CMake 工具链，并深入排查了依赖库缺失及环境变量冲突问题。
技术难点根因分析：针对 Windows 下 C/C++ 编译失败的原因进行了深度分析，对比了 Windows NT 内核与 Unix/Darwin (Linux/macOS) 的底层差异。深入研究了 POSIX 标准、DLL 依赖管理 以及不同操作系统的编译器兼容性，明确了 Windows 原生环境在构建此类系统级组件时的局限性。
方案验证与决策：通过连接远程 PostgreSQL 数据库，验证了 FerretDB 在 Windows 上的基础功能可用性。基于“DLL 地狱”及高昂的维护成本分析，输出了一份详尽的技术调研报告，否定了 Windows 原生编译路线，确立了采用 Linux/Docker/WSL2 作为统一开发和运行环境的技术路线。
成果与价值：排除了不稳定的 Windows 原生部署方案，为团队规避了潜在的运行时兼容性风险，推动了容器化标准化部署策略的落地。
💡 简历撰写小贴士（面试官视角）
如果面试官问起这段经历，你可以这样通过 STAR 法则 来讲述，显得非常有逻辑：

Situation (情境)：公司/项目组需要评估 MongoDB 的开源替代品 FerretDB，且最初的需求是在 Windows 服务器上尝试不用 Docker 部署。
Task (任务)：我负责搭建环境，特别是搞定微软的 DocumentDB 扩展（C++ 编写）在 Windows 上的编译和集成。
Action (行动)：我先是尝试了源码编译，虽然 Go 部分成功了，但 C++ 部分遇到了很多依赖和内核兼容问题。我没有死磕，而是去研究了底层原因，发现是 Windows 缺乏 POSIX 支持和 DLL 管理机制导致的。最后我做了完整的测试验证，证明虽然能跑但维护成本太高。
Result (结果)：我提交了一份报告，建议改用 Docker/WSL2 方案，避免了后续踩坑，帮团队节省了大量的维护成本。
这段经历最亮眼的地方在于： 你证明了你不仅仅是一个“写代码的人”，更是一个“懂架构、懂取舍、能从底层原理出发解决问题”的工程师。这对于后端/运维/DevOps 岗位是非常加分的。