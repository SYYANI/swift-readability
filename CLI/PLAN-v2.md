# Readability CLI v2 重构计划 (Issue Capture & Ground Truth Toolchain)

## 1. 背景与动机

随着 Readability 库在 RSS Reader 应用 Mercury 中的广泛使用，遇到边缘情况或特定站点正文提取不佳的问题成为常态。为了让排查这类问题更加流水线化、避免回归错误，决定对现有的 CLI 工具进行彻底重构。

**目前的 CLI 的局限性与重构决策：**
1. **基本解析功能可被替代**：原有的“输入 HTML，输出处理结果”的基础功能，将被新设计的探测流水线涵盖。
2. **废弃现有 Benchmark**：原有的 Benchmark 工具和 Profiling 流程实际效果不佳且不可靠，本次重构将其彻底清理，未来再基于真实需求重新设计性能诊断工具。
3. **隔离的增量基线**：新捕获的测试用例将被存放在 `Tests/ReadabilityTests/Resources/realworld-ex-pages/`（或 `ex-pages`），以区分于来自 Mozilla Readability 原版的官方基线（`test-pages` 和 `realworld-pages`）。

重构后的 CLI 将演变为一个 **“问题捕获与基准辅助标定流水线”**，由一系列高内聚低耦合的原子子命令构成。其工作区仍设在 `CLI` 目录下（使用独立的缓存/暂存目录），处理定稿后再自动推送到主库的 Tests 阵列中。

---

## 2. 核心架构与暂存区设计

新的 CLI 工具（命令假设为 `ReadabilityCLI` 或缩写词 `probe`）将主要操作一个本地状态目录，即暂存区（Staging Area），例如 `CLI/.staging/<case-name>/`。

在这个目录内，一个处理流程的完整生命周期文件可能包括：
- `source.html` (原始现场)
- `swift-out.html` & `swift-result.json` (Swift的实际输出)
- `mozilla-out.html` & `mozilla-result.json` (原版 JS 的参考输出)
- `draft-expected.html` (生成的建议形态/草稿)
- `expected.html` & `expected-metadata.json` (最终标定的理想态)

---

## 3. 子命令（模块）设计

整个工作流拆分为 5+1 个独立的原子型工具，可以链式调用，也可单独执行。

### 3.1 `fetch` (快照获取)
**目标**：固化出现问题的网页现场，消除动态变动的影响。
- **命令语法**：`ReadabilityCLI fetch <URL> --name <case-name>`
- **处理进程**：
  1. 下载该网页完整的 HTML。
  2. 初始化暂存区目录 `CLI/.staging/<case-name>/`。
  3. 将网页写入 `source.html`，同时在 `meta.json` 中记录抓取时的元数据（Origin URL, Timestamp 等）。
- **输出**：Staging 区基础文件集准备完毕。

### 3.2 `parse` (双引擎对照)
**目标**：用当前 Swift 库和 Mozilla 原版库分别处理 `source.html`，暴露分歧与缺陷。
- **命令语法**：`ReadabilityCLI parse <case-name>`
- **处理进程**：
  1. **Swift 侧**：调用 `Sources/Readability` 执行解析，输出提取 HTML 和 metadata。
  2. **Node/Mozilla 侧**：调用预先写好的 Node.js 桥接脚本，装载 `ref/mozilla-readability` 读取该 HTML，输出官方参考 HTML 和 metadata。
- **输出**：生成 `swift-out.*` 和 `mozilla-out.*` 四个对比文件。

### 3.3 `judge` (理想态生成辅助)
**目标**：帮助开发者解决“什么才算可接受的结果”这一难题，提供打底模板。
- **命令语法**：`ReadabilityCLI judge <case-name> [--strategy <heuristic|ai>]`
- **处理进程**：
  - 读取上一步解析的输出结果。在此阶段，系统可以尝试推荐一个初始的 "Draft"。
  - 初期版本：可以直接复制 `mozilla-out.html` 为 `draft-expected.html`。
  - 进阶版本：通过文本密度、基础标签保留率或者接入某种 AI API 服务（提纯脏 HTML 标签），生成一个过滤掉额外广告、评论但保留主体的基线骨架。
- **输出**：生成待人类审查的草案文件 `draft-expected.html` 与 `draft-expected-metadata.json`。

### 3.4 `review` (人机交互审定)
**目标**：以可视化的形式供开发者定稿，完成从 Draft 向 Final 的转换。
- **命令语法**：`ReadabilityCLI review <case-name>`
- **处理进程**：
  1. 唤起一个本地极简 HTTP Server 或输出一张 Diff 用的 `report.html`。
  2. 通过浏览器左右两栏或者三栏布局呈现：`原始 HTML区` | `Swift当前效果` | `Draft 理想效果区`。
  3. 开发者在确认 Draft 符合“理想态”或手工在代码编辑器中微加修饰（如删除漏掉的广告 Div）后，通过控制台/界面确认。
- **输出**：开发者确认后，将 Draft 转换为正式的 `expected.html` 和 `expected-metadata.json`。

### 3.5 `commit` (测试固化)
**目标**：将定稿后的用例完全纳入项目主库的单元测试闭环。
- **命令语法**：`ReadabilityCLI commit <case-name>`
- **处理进程**：
  1. 校验 Staging 区是否具备核心基石：`source.html`, `expected.html`, `expected-metadata.json`。
  2. 将这三个文件移入主库目录：`Tests/ReadabilityTests/Resources/realworld-ex-pages/<case-name>/`。
  3. 清理该 Case在 `CLI/.staging` 下的临时文件。
- **输出**：一个能够由现有测试框架直接驱动的 Faily (红态) Base Case 就此形成。

---

### 3.6 对症下药的诊断工具：`inspect`
**目标**：在 Case 被化入主线红态测试并且开发者准备去修 Bug 时，提供白盒排查信息，决定是改核心机制还是加 Site Rules。
- **命令语法**：`ReadabilityCLI inspect <case-name> [--trace]`
- **处理进程**：
  执行单次 Swift 解析并输出详细的决策追踪日志 (Decision Trace)，例如：
  - **NodeCleaner 阶段**：打印哪些大区块被当作垃圾节点（广告、隐藏元素）被正则删除了。
  - **Scoring 阶段**：打印候选节点树 (`Top 5 Candidates`) 的打分与惩罚扣分缘由。
  - **降级回退阶段**：记录是否丢弃了所有 Candidate 从而启用了 `body` 提取。
- **排查原则指导**：
  - 如果是因为“某种普遍意义下的大段文本结构”，在常规 Scoring 时因密度参数或特殊标签被淘汰，那么应该审查并**改进公共流程**（Core Algorithms）。
  - 只有确认失败原因来自于某个站点特有的 DOM 结构（如特定业务类名、独特的占位组件）引发了过度清理或错认，才编写**Site Rules** 进行定点治疗。绝不可滥用 Site Rules 掩盖核心流转逻辑的设计缺陷。

---

## 4. 实施阶段计划 (Roadmap)

### Phase 1: 核心通道搭建 (Scaffold & Automation)
1. **清理当前 CLI**：删除旧的 Benchmarking 组件、脚本和冗余的输出模式代码。
2. **引入 ArgumentParser**：基于 `swift-argument-parser` 构建多子命令架构。
3. **实现 `fetch`, `parse`, `commit`**：
   - 编写 Node.js 的桥接脚本对接 Mozilla 原版库，在 `parse` 命令时利用 `Process` 进程调用。
   - 此时可以由人力手动代替 `judge` 和 `review`（直接打开 Finder 和 VSCode 人工看并重命名 HTML），然后调用 `commit` 完成基线写入。
   - 在 `Tests` 中新增注册逻辑，使其扫描并执行 `realworld-ex-pages` 目录。

### Phase 2: 诊断探测能力 (Diagnostics System)
1. 设计 `Instrumentation / Diagnostics` 日志协议。
2. 修改主库的 `ReadabilityOptions` 注入日志回调（默认关闭，不影响性能）。
3. 实现 `inspect` 命令，结构化地打印核心流程在过滤、评分、降级时的决策记录，辅助问题定位。

### Phase 3: 人机辅助标定 (The Judge & Review)
1. 完善 `judge` 模块，根据文本相近度尝试给出 Draft。
2. 完善 `review` 模块，写一个单页网页模板展示差异树。
3. （进阶）实验性质地通过 AI 接口对去噪后的 DOM 进行“理想态”输出测试。
