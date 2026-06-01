## 为什么

当前项目已完成项目骨架、核心数据、作物状态机、背包、经济、等级、存档与时间等基础系统，但仍缺少可运行的田园场景与可视化网格承载层。PRD8 需要把项目从纯数据/逻辑层推进到可玩的可视化原型，为后续角色移动、种植、浇水、收获和正式场景美术提供稳定空间基础。

该变更将建立 30×20 的个人田园地图、20×12 的可耕区域、初始 3×4 已解锁地块、最大 8×10 可解锁地块，以及地块状态管理、坐标转换、占位渲染、调试交互、事件广播和测试场景。

## 变更内容

- 新增个人田园场景 `pixel-farm/scenes/farm/farm.tscn`，使用 Godot 内置节点或程序化绘制展示 30×20、单格 16×16 的基础地图。
- 新增田园场景脚本 `pixel-farm/scenes/farm/farm.gd`，负责连接网格管理器、调试 UI、鼠标悬停与点击调试交互。
- 新增核心脚本 `pixel-farm/scripts/farm/farm_grid_manager.gd`，负责网格初始化、地块状态查询/修改、坐标转换、解锁管理、占用管理、存档导入导出与事件发射。
- 在 `pixel-farm/scripts/autoload/event_bus.gd` 中新增 `farm_*` 系列信号，用于广播田园网格初始化、悬停、选中、状态变化、解锁、占用变化和整体网格变化。
- 新增 FarmGridManager 自动化测试场景与脚本，覆盖初始化、边界判断、状态修改、坐标转换、地块解锁、存档导入导出和 EventBus 信号。
- 使用色块、Label、网格线等最小占位视觉区分草地、锁定地块、空闲地块、干土、湿土、占用地块和调试高亮。
- 不引入正式 TileSet、Sprite、美术资源、角色移动、完整种植闭环或商店/背包 UI。

## 功能 (Capabilities)

### 新增功能
- `farm-grid-system`: 覆盖田园地图尺寸、可耕区域、地块状态模型、查询/修改接口、解锁逻辑、坐标转换、占位视觉、调试交互、存档导入导出和测试要求。

### 修改功能
- `event-bus`: 新增田园网格与地块相关信号，包括 `farm_grid_initialized`、`farm_tile_hovered`、`farm_tile_selected`、`farm_tile_state_changed`、`farm_tile_unlocked`、`farm_tile_occupied_changed`、`farm_grid_changed`。
- `save-system`: 扩展存档能力的规范约束，允许后续 SaveManager 持久化 `farm_grid` 根字段；PRD8 必须先由 FarmGridManager 提供 JSON 可序列化的导入/导出接口。

## 影响

- 受影响 Godot 场景：`pixel-farm/scenes/farm/farm.tscn`、`pixel-farm/scenes/test/test_farm_grid_manager.tscn`。
- 受影响 GDScript：`pixel-farm/scenes/farm/farm.gd`、`pixel-farm/scripts/farm/farm_grid_manager.gd`、`pixel-farm/scripts/autoload/event_bus.gd`、`pixel-farm/scenes/test/test_farm_grid_manager.gd`。
- 受影响系统：EventBus 需要暴露新的 `farm_*` 信号；SaveManager 可在后续实现中接入 FarmGridManager 导出的 `farm_grid` 数据。
- 对现有作物、背包、经济、等级、时间系统无破坏性变更；FarmGridManager 仅提供地块容器、坐标与占用状态，不替代 CropManager 的作物生命周期逻辑。
- 不引入新第三方依赖，不要求正式美术资源。
