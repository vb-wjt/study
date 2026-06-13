# 项目上下文快照

> **最后更新**：2026-06-13
> **用途**：新对话开始时先读此文件，快速恢复全量上下文。
> **工作空间**：`d:\idea_workspace\study_mine`

---

## 一、项目背景与当前决策

本项目是个人知识库、简历亮点提炼、技术栈沉淀与职业发展规划的文档工程（study_mine）。
当前活跃工作方向：
1. 完善维谛技术（Vertiv）SI/PI 项目与中国移动（ASP）项目的简历量化数据与核心设计细节。
2. 进阶补强 P6+/P7 核心技术栈（本月主攻：Spring 源码、MySQL 锁与 MVCC、Redis 底层）。
3. 将 Leader（L）的第二年谈话反馈转化为日常行动 SOP。

---

## 二、工作空间目录结构

- `origin/`：个人手写的项目/个人源内容（设备发现、告警流、依赖升级、谈话记录等）
- `_curated/`：AI 自动整理的简历段、面试题、盲点清单及成长复盘
- `tech-stack/`：技术深度文档（Java、MySQL、Redis、MQ、网络、系统设计等）
- `_build/`：脚本自动从 xmind/drawio 解析出的 outline 纯文本大纲

---

## 三、关键研究结论

- **数据安全防线**：在执行具有破坏性的批量覆盖/修改脚本前，必须确保 Git 工作区干净，防止文件被误覆盖丢失（如之前丢失的 ASP 原始文件）。
- **技术栈升级方法论**：SI 4.1 成功完成了 JRE 8→21、SpringBoot 2→3、Hazelcast 3→5 的平滑升级，形成了标准升级 SOP。
- **FerretDB 调研结论**：Windows 原生编译 C 组件（DocumentDB）不具备工程可持续性，低版本 v1.24 存在索引和协议限制，最终推动 PI 4.0 采用直接重构为 PostgreSQL 的 Plan C。

---

## 四、关键代码位置速查

- 简历项目段：`_curated/career/resume-projects.md`
- 面试高频问题：`_curated/career/interview-talking-points.md`
- 缺口与盲点清单：`_curated/meta/still-missing.md`
- 进阶补强路线图：`tech-stack/00-skill-roadmap.md`
- 自动化大纲：`_build/outlines/`

---

## 五、下次对话启动方式

1. **读本文件**恢复全量上下文。
2. 读 `_curated/meta/still-missing.md` 查看当前待补充的缺口。
3. 读 `tech-stack/00-skill-roadmap.md` 跟踪技术补强进度。
