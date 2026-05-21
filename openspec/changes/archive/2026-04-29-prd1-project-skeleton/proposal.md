## Why

《像素田园》项目需要一个坚实的 Godot 4 项目骨架作为所有后续开发（28 个 PRD）的基础。当前只有一个空的 `project.godot` 文件，缺少像素风必需的渲染配置、输入系统、全局管理器和游戏数据加载系统。PRD1 是 P0 优先级，所有后续系统（作物状态机、背包、经济、存档等）都依赖它，必须首先完成。

## What Changes

- 配置 `project.godot` 像素风必需设置（480×320 视口、Nearest 纹理过滤、viewport 缩放模式）
- 配置完整 InputMap 输入映射（WASD 移动、E 交互、Tab 背包、1-9 快捷栏等 20+ 个 Action）
- 创建完整项目目录结构（scenes/、scripts/、assets/、data/ 等）
- 实现 5 个全局单例 Autoload（EventBus、DataManager、GameManager、SaveManager 占位、AudioManager 占位）
- 创建 4 个游戏数据表 JSON 文件（crops.json 10 种作物、levels.json 7 级、items.json 道具、achievements.json 成就）
- 创建入口场景 `main.tscn`，验证项目可运行

## Capabilities

### New Capabilities
- `project-config`: Godot 项目基础配置（像素风渲染设置、窗口分辨率、InputMap）
- `data-loading`: 游戏数据表加载系统（JSON → GDScript 字典，提供按 ID/季节/等级查询接口）
- `event-bus`: 全局信号总线（跨系统解耦通信，定义作物/经济/背包/等级/时间等信号）
- `game-state`: 全局游戏状态管理（游戏状态枚举、玩家核心属性：金币/等级/经验/精力）

### Modified Capabilities
<!-- 无已有 capability 需要修改，这是全新项目 -->

## Impact

- **代码**: 创建 5 个 autoload 脚本 + 入口场景，注册到 project.godot
- **数据**: 创建 4 个 JSON 数据文件（crops/levels/items/achievements）
- **目录**: 建立 20+ 个目录的标准项目结构
- **依赖**: 无外部依赖（GodotSteam 等在后续 PRD 中引入）
- **后续影响**: PRD2-7 全部依赖本变更的 EventBus 和 DataManager
