---
name: openspec-cn-propose
description: 使用中文版 OpenSpec CLI 提出新变更，并一次性生成中文 proposal、design、specs 和 tasks。Use when the user asks to create a Chinese OpenSpec proposal or uses /openspec-cn:propose.
license: MIT
compatibility: Requires openspec-cn CLI from @studyzy/openspec-cn.
metadata:
  author: local
  version: "1.0"
  generatedBy: "openspec-cn-1.3.1"
---

使用中文版 OpenSpec CLI 创建新变更，并一次性生成所有 artifacts。

会创建：
- `proposal.md`（变更原因与范围）
- `design.md`（技术设计）
- `specs/**/*.md`（需求规范）
- `tasks.md`（实施任务）

---

**Input**: 用户请求中应包含 kebab-case change 名称，或者描述他们想构建/修复的内容。

**核心约束：中文输出**

- 所有生成的 artifact 正文必须使用简体中文。
- OpenSpec 固定规范标题和关键字可按 schema 要求保留英文，例如 `ADDED Requirements`、`MODIFIED Requirements`、`REMOVED Requirements`、`RENAMED Requirements`、`Requirement`、`Scenario`、`WHEN`、`THEN`、`SHALL`、`MUST`。
- 代码标识符、文件路径、API 名、信号名、字段名、命令名保持原文。
- 不要把 instructions JSON 中的 `context`、`rules`、`project_context` 原样复制进输出文件；它们只是写作约束。

**Steps**

1. **如果没有明确输入，询问要做什么**

   使用 **AskUserQuestion tool** 询问：
   > "你想创建什么变更？请描述你想构建或修复的内容。"

   根据描述推导 kebab-case 名称，例如「添加用户认证」→ `add-user-auth`。

   **IMPORTANT**: 不理解用户要构建什么之前，不要继续。

2. **创建 change 目录**
   ```bash
   openspec-cn new change "<name>"
   ```
   这会创建 `openspec/changes/<name>/`，并生成 `.openspec.yaml`。

3. **获取 artifact 构建顺序**
   ```bash
   openspec-cn status --change "<name>" --json
   ```
   解析 JSON：
   - `applyRequires`: 实施前必须完成的 artifact ID 列表，例如 `["tasks"]`
   - `artifacts`: 所有 artifact 的状态和依赖

4. **按依赖顺序创建 artifacts，直到 apply-ready**

   使用 **TodoWrite tool** 跟踪 artifact 进度。

   按依赖顺序循环处理 ready artifact：

   a. **对每个 `ready` artifact**：
      - 获取指令：
        ```bash
        openspec-cn instructions <artifact-id> --change "<name>" --json
        ```
      - instructions JSON 包含：
        - `context`: 项目背景约束，不要复制到输出文件
        - `rules`: artifact 规则约束，不要复制到输出文件
        - `template`: 输出文件结构
        - `instruction`: artifact 类型指导
        - `outputPath`: 写入路径
        - `dependencies`: 需要读取的已完成依赖文件
      - 读取已完成依赖文件作为上下文。
      - 使用 `template` 的结构创建 artifact 文件。
      - 内容使用简体中文；仅保留 schema 要求的英文关键字。
      - 简短展示进度：`Created <artifact-id>`。

   b. **每创建一个 artifact 后重新检查状态**
      ```bash
      openspec-cn status --change "<name>" --json
      ```
      确认 `applyRequires` 中所有 artifact 都是 `done` 后停止。

   c. **如果上下文关键不清楚**
      - 使用 **AskUserQuestion tool** 澄清。
      - 澄清后继续创建。

5. **显示最终状态**
   ```bash
   openspec-cn status --change "<name>"
   ```

**Output**

完成后用简体中文总结：
- Change 名称和位置
- 已创建 artifact 列表与简要说明
- 就绪状态："所有 artifacts 已创建，已准备好进入实现阶段。"
- 提示："运行 `/opsx:apply` 或让我开始实现任务清单。"

**Guardrails**

- 创建 schema 的 `apply.requires` 定义中实施所需的所有 artifacts。
- 创建新 artifact 前必须读取依赖 artifact。
- 如果 change 已存在，询问用户是继续现有 change 还是换新名称。
- 写入后验证 artifact 文件存在，再继续下一个 artifact。
- 全流程优先使用 `openspec-cn`，不要调用英文版 `openspec`。
