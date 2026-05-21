## Context

《像素田园》是一个 Godot 4.6 + GDScript 的像素风休闲农场游戏。当前状态：仅有 Godot 创建的空 `project.godot`（默认配置，缺少像素风设置）。

项目工作目录：`/Users/linzizhan/Desktop/coco_project/像素风田园游戏/pixel-farm/`

本变更需要将这个空壳项目变成一个「可运行、可访问数据、可发送信号」的完整骨架，供后续 PRD2-28 在其基础上开发。

**约束条件**:
- 引擎版本: Godot 4.6（兼容 4.4 API）
- 语言: GDScript（不使用 C#）
- 零美术依赖（纯代码+配置+JSON）
- 所有 Autoload 通过 project.godot `[autoload]` 节注册

## Goals / Non-Goals

**Goals:**
- 配置像素风完美渲染（Nearest 过滤、viewport 缩放、480×320 基础分辨率）
- 建立 20+ 目录的标准项目结构
- 实现可工作的 DataManager（加载 JSON、按条件查询）
- 实现 EventBus 信号总线（定义所有跨系统信号）
- 实现 GameManager（游戏状态 + 玩家核心属性）
- 创建 SaveManager 和 AudioManager 的占位框架
- 创建 4 个完整的游戏数据 JSON 文件
- 配置 InputMap（20+ 输入 Action）
- 项目运行后控制台输出初始化日志确认一切正常

**Non-Goals:**
- 不实现任何游戏玩法逻辑（种植/浇水/收获属于 PRD2+）
- 不创建任何视觉场景（TileMap/Sprite 属于 PRD8+）
- 不实现实际的存档读写（PRD6）
- 不实现音频播放（PRD19）
- 不引入 GodotSteam 或任何外部插件
- 不创建 UI 面板

## Decisions

### 1. Autoload 架构 vs 依赖注入

**决定**: 使用 Godot 原生 Autoload 单例模式

**理由**:
- GDScript 无原生 DI 框架，Autoload 是 Godot 官方推荐的全局服务模式
- 通过 project.godot `[autoload]` 注册，任何脚本可直接访问 `GameManager.xxx`
- 对于中小型项目，Autoload 简单高效，无需过度抽象

**加载顺序** (上→下依次加载):
1. `EventBus` — 最先加载，其他系统需要连接它的信号
2. `DataManager` — 第二加载，启动时读取所有 JSON
3. `GameManager` — 依赖 DataManager 的等级数据
4. `SaveManager` — 占位
5. `AudioManager` — 占位

### 2. 数据存储格式: JSON vs Godot Resource (.tres)

**决定**: 使用 JSON 文件存放在 `data/` 目录

**理由**:
- JSON 可被外部工具编辑（Excel → JSON 转换器），策划友好
- 版本控制下 diff 更清晰
- 后续如需热加载/热更新更方便
- 虽然 .tres 在 Godot 中加载更快，但我们的数据量极小（< 50KB），性能无影响

**替代方案被否**: Godot Resource (.tres) — 虽然是引擎原生格式，但编辑需要打开引擎，且 diff 不友好

### 3. 信号总线模式 vs 直接信号连接

**决定**: 使用全局 EventBus 单例作为信号中转

**理由**:
- 解耦各系统（作物系统不需要直接引用背包系统）
- 方便后续添加新的监听者（如成就系统）而不修改发送方
- 调试时可在 EventBus 中统一添加日志

**信号命名规范**: 使用过去时态（`crop_planted` 而非 `plant_crop`），表示"事件已发生"

### 4. InputMap 配置方式: 代码 vs project.godot

**决定**: 直接写入 project.godot 的 `[input]` 节

**理由**:
- Godot 标准做法，引擎启动时自动注册
- 可通过 Godot 编辑器 UI 可视化编辑
- 无需运行时代码注册，减少启动逻辑

### 5. 项目窗口分辨率策略

**决定**: 基础视口 480×320，窗口 1920×1280（4x 放大）

**理由**:
- 480×320 = 30×20 Tile（16px/Tile），正好覆盖田园场景
- 4x 放大在 1080p/1440p 显示器上像素完美
- `stretch/mode = viewport` 确保像素不变形
- `stretch/aspect = keep` 保持 3:2 比例

## Risks / Trade-offs

| 风险 | 说明 | 缓解措施 |
|------|------|---------|
| Autoload 顺序依赖 | EventBus 必须在其他系统之前加载 | project.godot 中严格控制声明顺序；加载时打印日志确认 |
| JSON 加载失败 | 数据文件损坏或路径错误时系统崩溃 | DataManager 中添加 null 检查和 push_error 日志 |
| InputMap 冲突 | ESC 同时映射 `cancel` 和 `open_menu` | 在游戏逻辑中通过状态机区分（有面板打开时 ESC=关闭，无面板时=菜单）|
| Godot 版本差异 | 用户安装的是 4.6，PRD 写的 4.4 | API 向后兼容，4.6 覆盖 4.4 全部 API，无影响 |

## Open Questions

- 无（PRD1 需求已明确，所有设计决策已确定）
