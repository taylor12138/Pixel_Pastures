# OpenSpec CN

使用中文版 OpenSpec CLI (`openspec-cn`) 执行 OpenSpec 工作流。

此命令用于在 Roo 聊天框中暴露 `openspec-cn` 入口。常用方式：

- `/openspec-cn:propose <change-name-or-description>`：用中文版 CLI 创建变更并生成 proposal/design/specs/tasks。

如果用户只输入 `/openspec-cn` 且没有明确动作：

1. 说明可用动作：`propose`。
2. 如果用户想创建新变更，请引导使用 `/openspec-cn:propose <描述或 change-name>`。
3. 如果用户只是想查看 CLI 帮助，可以运行：
   ```bash
   openspec-cn --help
   ```

**中文生成规则**

- 生成给用户阅读的正文内容必须使用简体中文。
- OpenSpec 规范格式关键字可以按工具要求保留英文，例如 `ADDED Requirements`、`MODIFIED Requirements`、`Requirement`、`Scenario`、`WHEN`、`THEN`、`SHALL`、`MUST`。
- 文件名、路径、命令、代码标识符、接口名、信号名、字段名保持原文。
