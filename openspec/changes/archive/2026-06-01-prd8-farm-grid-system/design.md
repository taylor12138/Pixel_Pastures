## 上下文

项目当前位于 Godot 4.x 的像素风田园游戏原型阶段，已具备项目骨架、数据加载、事件总线、作物状态机、背包、经济、等级、存档和时间系统。现有系统主要集中在数据和业务逻辑，尚缺少能承载角色、地块交互和作物视觉的个人田园场景。

PRD8 的核心价值是提供稳定的空间层：30×20 地图、16×16 像素网格、20×12 可耕区域、初始 12 格可用土地、最大 80 格可解锁土地，以及可被后续 PRD9/PRD10/PRD16/PRD17 复用的地块状态与坐标接口。

设计约束：

- 使用 Godot 4.4+ / 4.6 兼容的 GDScript。
- 不依赖正式美术资源，优先使用程序化色块与 Label 完成占位表达。
- FarmGridManager 不承担作物生命周期、背包扣除、金币经验、等级升级或文件读写职责。
- 地块数据必须可 JSON 序列化，导出数据不得包含 Node、Resource、Signal、Callable 或原始 Vector2i 对象。
- 地块变化通过 EventBus 广播，后续系统不应直接修改 `tiles` 内部 Dictionary。

## 目标 / 非目标

**目标：**

- 创建可运行的个人田园场景，展示 30×20、单格 16×16 的占位地图。
- 实现 FarmGridManager 作为地块数据与坐标转换的单一入口。
- 初始化 600 个 tile 数据，并正确区分草地、可耕区、最大可解锁区、已解锁地块、锁定地块和不可用预留地块。
- 提供地块查询、状态修改、占用管理、清理、浇水、按数量解锁和可交互判断接口。
- 提供屏幕坐标、世界坐标、网格坐标、JSON key 之间的转换接口。
- 提供 JSON 可序列化的 `export_save_data()` 和健壮的 `import_save_data()`。
- 在 EventBus 中新增田园网格相关信号。
- 提供鼠标悬停、点击选中和状态循环的最低限度调试交互。
- 提供自动化测试场景验证核心行为。

**非目标：**

- 不实现角色移动、碰撞、动画或面对方向。
- 不实现选择种子、种植、浇水、收获的完整交互闭环。
- 不实现作物 Sprite、生长阶段视觉或成熟表现。
- 不制作正式 TileSet、背景、美术装饰、天气、昼夜光照或音频表现。
- 不改写 CropManager、InventoryManager、EconomyManager、LevelManager、TimeManager 的核心行为。
- 不强制 SaveManager 在本变更中完成持久化接入；本变更只要求 FarmGridManager 提供可接入接口。

## 决策

### 1. 使用 FarmGridManager 集中管理地块数据

FarmGridManager 挂载为普通 Node，内部维护 `tiles: Dictionary`，key 使用 `"x,y"` 字符串，value 使用 Dictionary 表示地块数据。

理由：

- 字符串 key 天然适合 JSON 存档，与后续 SaveManager 接入成本低。
- Dictionary 足以表达 PRD8 需要的 `terrain_type`、`plot_state`、`unlocked`、`occupied`、`crop_tile_ref` 等字段。
- 作为单一入口可以避免场景脚本、作物系统或调试逻辑直接修改内部数据。

替代方案：

- 自定义 Resource 或 RefCounted 地块类：类型更强，但序列化和测试成本更高，不适合 PRD8 的最小原型目标。
- 每个地块一个节点：可视化直观，但 600 个节点的状态同步复杂度高，后续替换 TileSet 时迁移成本更高。

### 2. 地形类型与运行状态分离

每个 tile 同时维护 `terrain_type` 和 `plot_state`。

理由：

- `terrain_type` 描述格子本质，如草地、小路、可耕地、阻挡。
- `plot_state` 描述可耕地运行状态，如不可用、锁定、空闲、干土、湿土、占用。
- 后续 PRD9 可用地形判断移动/交互目标，PRD10 可用状态判断种植/浇水/清理。

替代方案：

- 只使用一个状态字段：实现更简单，但会混淆草地、锁定地、湿土、占用等概念，不利于后续扩展。

### 3. 初始化采用固定布局与 row-major 解锁顺序

地图尺寸固定为 30×20，田园起点固定为 `Vector2i(5, 5)`，可耕区域为 20×12，最大可解锁区域为起点开始的 8×10。解锁顺序从左到右、从上到下。

理由：

- 固定布局与基础分辨率 480×320 对齐，便于验证像素对齐。
- row-major 顺序稳定、可测试，能直接匹配等级系统的 `farm_slots` 数量。
- PRD8 不实现土地购买或解锁动画，因此无需复杂空间规划。

替代方案：

- 配置化布局：更灵活，但需要额外配置数据、校验与编辑流程，不适合当前阶段。
- 保持矩形扩展：视觉更规整，但数量映射和局部扩展策略更复杂；PRD8 只要求数量正确且顺序稳定。

### 4. 占位视觉优先采用 Node2D 程序化绘制

田园场景可使用 Node2D `_draw()` 绘制色块、网格线、悬停边框和选中边框，FarmGridManager 负责提供颜色映射和状态数据，场景脚本负责刷新绘制。

理由：

- 无需制作运行时 TileSet 或导入正式素材，最快满足 PRD8 验收。
- 600 个 tile 的全量重绘在当前规模下可接受。
- 后续可平滑替换为 TileMapLayer 或正式 TileSet，而不改变 FarmGridManager 接口。

替代方案：

- 程序化 TileMapLayer + 运行时 TileSet：更贴近正式方案，但初期实现更复杂。
- 大量 ColorRect 实例：简单直观，但节点数量较多，状态刷新和层级管理较冗余。

### 5. EventBus 只广播田园网格事件，不替代作物事件

新增 `farm_grid_initialized`、`farm_tile_hovered`、`farm_tile_selected`、`farm_tile_state_changed`、`farm_tile_unlocked`、`farm_tile_occupied_changed`、`farm_grid_changed`。

理由：

- 明确 FarmGridManager 负责地块空间与占用，CropManager 仍负责作物生命周期。
- 后续 PRD10 可以同时触发作物事件和地块事件，避免职责混淆。
- UI、测试和调试层可通过 EventBus 监听地块变化，而不依赖内部实现。

替代方案：

- 复用现有 crop 信号：会导致地块状态与作物行为耦合，无法表达锁定、解锁、悬停、选中等网格事件。

### 6. 存档接口先由 FarmGridManager 提供，SaveManager 后续可接入

FarmGridManager 提供 `export_save_data()` 和 `import_save_data(data)`，数据包含 schema_version、地图尺寸、tile_size、farm_origin、unlocked_plot_count 和 tiles。

理由：

- PRD8 可独立验证导入导出，不强制改造 SaveManager。
- SaveManager 后续只需把 FarmGridManager 的导出结果挂到根字段 `farm_grid`。
- 导入逻辑集中在 FarmGridManager，可以统一处理缺失字段、非法 key、越界坐标和尺寸不一致。

替代方案：

- 本 PRD 直接改造 SaveManager：端到端更完整，但增加与现有存档系统耦合，影响范围扩大。

## 风险 / 权衡

- [风险] 使用 Dictionary 作为地块数据缺少静态类型约束，字段名拼写错误可能运行时才暴露。→ 通过统一 `_create_default_tile_data()`、字段补齐函数和自动化测试降低风险。
- [风险] 程序化全图绘制在后续地图扩大后可能有性能压力。→ PRD8 只有 600 格，全量 `queue_redraw()` 可接受；后续正式美术阶段可替换为 TileMapLayer 或局部刷新。
- [风险] EventBus 新增信号若遗漏会导致启动或测试报错。→ 在任务中明确修改 `event_bus.gd`，并通过测试场景监听信号验证。
- [风险] 坐标转换涉及屏幕、世界、相机三套坐标，后续加入 Camera2D 后可能出现偏差。→ PRD8 明确基础转换断言，并让 `screen_to_grid()` 支持可选 Camera2D。
- [风险] SaveManager 暂不强制接入会导致真实存档暂时不包含田园数据。→ 该变更仍提供 FarmGridManager 导入导出接口和 `save-system` 规范扩展，后续可低成本接入。
- [风险] 点击调试循环状态可能被误认为正式种植交互。→ 在代码和文档中标记为 debug 行为，锁定/不可用地块只显示状态不修改状态。
