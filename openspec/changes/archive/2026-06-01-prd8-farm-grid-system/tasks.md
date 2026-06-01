## 1. 目录与基础文件

- [x] 1.1 创建 `pixel-farm/scripts/farm/` 目录并新增 `farm_grid_manager.gd`
- [x] 1.2 创建 `pixel-farm/scenes/farm/farm.gd` 田园场景脚本
- [x] 1.3 创建 `pixel-farm/scenes/farm/farm.tscn` 个人田园场景
- [x] 1.4 创建 `pixel-farm/scenes/test/test_farm_grid_manager.gd` 自动化测试脚本
- [x] 1.5 创建 `pixel-farm/scenes/test/test_farm_grid_manager.tscn` 自动化测试场景

## 2. EventBus 信号扩展

- [x] 2.1 在 `pixel-farm/scripts/autoload/event_bus.gd` 中新增 `farm_grid_initialized(width: int, height: int)` 信号
- [x] 2.2 新增 `farm_tile_hovered(tile_pos: Vector2i, tile_data: Dictionary)` 与 `farm_tile_selected(tile_pos: Vector2i, tile_data: Dictionary)` 信号
- [x] 2.3 新增 `farm_tile_state_changed(tile_pos: Vector2i, old_state: String, new_state: String)` 信号
- [x] 2.4 新增 `farm_tile_unlocked(tile_pos: Vector2i)` 信号
- [x] 2.5 新增 `farm_tile_occupied_changed(tile_pos: Vector2i, occupied: bool)` 信号
- [x] 2.6 新增 `farm_grid_changed()` 信号并确认既有 crop、inventory、economy、level、time、save 信号签名不变

## 3. FarmGridManager 常量与初始化

- [x] 3.1 在 `farm_grid_manager.gd` 中定义地图、可耕区、初始解锁区、最大可解锁区常量
- [x] 3.2 定义地形类型常量 `grass`、`path`、`farm_plot`、`blocked`
- [x] 3.3 定义地块状态常量 `unavailable`、`locked`、`empty`、`dry_soil`、`wet_soil`、`occupied`
- [x] 3.4 实现 `tiles`、`unlocked_plot_count`、`hovered_tile`、`selected_tile`、`debug_mode` 核心属性
- [x] 3.5 实现 `_create_default_tile_data(tile_pos)`，按地图布局生成默认地块 Dictionary
- [x] 3.6 实现 `initialize_grid()`，生成 600 个 tile 并发射 `farm_grid_initialized` 与 `farm_grid_changed`
- [x] 3.7 实现 `initialize_unlocked_plots(plot_count)`，按 row-major 顺序设置已解锁地块
- [x] 3.8 实现 `reset_to_default()`，恢复 PRD8 默认 12 格初始田园

## 4. 地块查询接口

- [x] 4.1 实现 `is_in_map_bounds(tile_pos)` 地图边界判断
- [x] 4.2 实现 `is_in_farm_area(tile_pos)` 20×12 可耕区域判断
- [x] 4.3 实现 `is_in_unlockable_plot_area(tile_pos)` 8×10 最大可解锁区域判断
- [x] 4.4 实现 `get_tile_data(tile_pos)`，地图外返回空 Dictionary
- [x] 4.5 实现 `get_terrain_type(tile_pos)` 与 `get_plot_state(tile_pos)`
- [x] 4.6 实现 `is_plot_unlocked(tile_pos)`
- [x] 4.7 实现 `can_plant_on_tile(tile_pos)`
- [x] 4.8 实现 `can_water_tile(tile_pos)`
- [x] 4.9 实现 `can_clear_tile(tile_pos)`
- [x] 4.10 实现 `get_unlocked_plot_positions()` 与 `get_plantable_positions()`

## 5. 地块修改与解锁接口

- [x] 5.1 实现合法状态集合校验，非法状态返回 `false` 并 `push_warning`
- [x] 5.2 实现 `set_plot_state(tile_pos, new_state)`，校验坐标、地形、解锁状态并避免重复发射未变化事件
- [x] 5.3 实现 `set_plot_unlocked(tile_pos, unlocked)`，支持锁定到解锁并发射 `farm_tile_unlocked`
- [x] 5.4 实现 `set_tile_occupied(tile_pos, occupied, crop_tile_ref)`，同步 `occupied`、`crop_tile_ref`、`plot_state` 与占用事件
- [x] 5.5 实现 `clear_tile(tile_pos)`，恢复 `empty`、`occupied=false`、`crop_tile_ref=""`
- [x] 5.6 实现 `mark_tile_watered(tile_pos)`，将合法地块标记为 `wet_soil` 或合法湿润占用表现
- [x] 5.7 实现 `unlock_plots_by_count(target_count)`，按 row-major 顺序最多解锁 80 格
- [x] 5.8 确保所有影响视觉或网格状态的修改发射 `farm_grid_changed`

## 6. 坐标转换与 key 规范

- [x] 6.1 实现 `grid_to_world(tile_pos)`，返回 tile 左上角世界坐标
- [x] 6.2 实现 `grid_to_world_center(tile_pos)`，返回 tile 中心世界坐标
- [x] 6.3 实现 `world_to_grid(world_pos)`，正确处理 0、15、16 与负坐标边界
- [x] 6.4 实现 `screen_to_grid(screen_pos, camera)`，支持无 Camera2D 与可选 Camera2D 场景
- [x] 6.5 实现 `tile_pos_to_key(tile_pos)`，输出 `"x,y"` 字符串
- [x] 6.6 实现 `key_to_tile_pos(key)`，解析合法 key 并为非法 key 提供安全处理路径

## 7. 存档导入导出

- [x] 7.1 实现 `export_save_data()`，输出 `schema_version`、地图尺寸、`tile_size`、`farm_origin`、`unlocked_plot_count`、`tiles`
- [x] 7.2 确保导出数据只包含 JSON 可序列化值，不包含 Node、Resource、Signal、Callable 或原始 Vector2i
- [x] 7.3 实现 `import_save_data(data)`，空数据或缺失必要字段时回退默认田园
- [x] 7.4 实现导入时跳过非法坐标 key 和地图外 tile，并通过 warning 暴露问题
- [x] 7.5 实现导入时缺失字段使用默认地块数据补齐
- [x] 7.6 确保导入完成后刷新视觉状态并发射 `farm_grid_changed`

## 8. 田园场景视觉与调试交互

- [x] 8.1 在 `farm.tscn` 中搭建 Farm 根节点、GridRoot、可绘制地图节点、DebugLayer、CoordinateLabel、TileStateLabel、FarmGridManager 节点
- [x] 8.2 在 `farm.gd` 中初始化 FarmGridManager 并连接网格变化到视觉刷新
- [x] 8.3 实现 Node2D `_draw()` 或等价程序化色块绘制，显示 30×20、16×16 对齐地图
- [x] 8.4 实现草地、锁定、空闲、干土、湿土、占用、悬停、选中的颜色映射
- [x] 8.5 实现鼠标移动更新 hovered_tile、调试 Label 和 `farm_tile_hovered` 信号
- [x] 8.6 实现左键点击地图内地块更新 selected_tile 和 `farm_tile_selected` 信号
- [x] 8.7 实现 Debug 模式下已解锁地块按 `empty → dry_soil → wet_soil → occupied → empty` 循环
- [x] 8.8 确保锁定、不可用或地图外点击只显示状态，不修改地块状态

## 9. 自动化测试

- [x] 9.1 在 `test_farm_grid_manager.gd` 中实现统一测试运行入口与断言统计输出
- [x] 9.2 添加网格初始化、地图边界、可耕区域边界、最大可解锁区域边界测试
- [x] 9.3 添加初始解锁数量、锁定地块、不可用地块和地形状态测试
- [x] 9.4 添加 `grid_to_world`、`grid_to_world_center`、`world_to_grid`、key 转换测试
- [x] 9.5 添加地块查询、合法状态修改、非法状态拒绝测试
- [x] 9.6 添加 `can_plant_on_tile`、`can_water_tile`、占用、清理、浇水测试
- [x] 9.7 添加 `unlock_plots_by_count` 数量上限和 row-major 顺序测试
- [x] 9.8 添加 `export_save_data()` 与 `import_save_data()` 恢复状态、缺失字段和非法坐标测试
- [x] 9.9 添加 EventBus 初始化、状态变化、解锁、占用变化和整体网格变化信号测试
- [x] 9.10 配置 `test_farm_grid_manager.tscn`，包含 FarmGridManager 节点和结果 Label

## 10. 验证与收尾

- [x] 10.1 使用 Godot 或命令行运行 FarmGridManager 测试场景，确认无脚本错误且测试通过
- [x] 10.2 打开或运行 `farm.tscn`，确认 30×20 色块地图、调试 Label、悬停和点击行为正常
- [x] 10.3 检查新增/修改文件符合 GDScript snake_case、常量 UPPER_SNAKE_CASE 和公开方法注释要求
- [x] 10.4 确认本变更没有引入正式美术资源、角色移动或完整种植闭环等非目标内容
- [x] 10.5 更新任务完成状态并准备进入归档或后续 PRD9/PRD10 实现
