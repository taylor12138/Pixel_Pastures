## 1. GameManager 扩展

- [x] 1.1 添加 `farm_data: Dictionary = {}` 属性
- [x] 1.2 添加 `stats: Dictionary = {"total_water_count": 0, "total_harvests": 0}` 属性
- [x] 1.3 实现 `add_item(item_id: String, amount: int)` 方法
- [x] 1.4 实现 `has_item(item_id: String) -> bool` 方法
- [x] 1.5 实现 `remove_item(item_id: String, amount: int) -> bool` 方法
- [x] 1.6 实现 `add_xp(amount: int, source: String)` 方法（增加 player_xp 并发射 xp_gained 信号）

## 2. EventBus 信号修正

- [x] 2.1 修正 `crop_watered` 信号参数为 `(tile_pos: Vector2i, crop_id: String)`
- [x] 2.2 修正 `crop_grown` 信号参数为 `(tile_pos: Vector2i, crop_id: String, new_stage: int)`
- [x] 2.3 修正 `crop_withered` 信号参数为 `(tile_pos: Vector2i, crop_id: String)`

## 3. CropManager 核心结构

- [ ] 3.1 创建 `scripts/autoload/crop_manager.gd`，定义 `class_name CropManager`
- [x] 3.2 定义 `CropStage` 枚举（SEED=0, SPROUT=1, GROWING=2, MATURE=3, WITHERED=4）
- [x] 3.3 实现内部数据结构 `_crops: Dictionary`（Vector2i → crop_data）
- [x] 3.4 实现 `_sync_to_game_manager()` 同步方法
- [x] 3.5 实现 `_load_from_game_manager()` 加载方法
- [x] 3.6 在 `_ready()` 中调用 `_load_from_game_manager()` 初始化

## 4. CropManager 核心操作

- [x] 4.1 实现 `plant_crop(tile_pos, crop_id) -> bool`（含前置校验、扣种子、创建数据、发信号）
- [x] 4.2 实现 `water_crop(tile_pos) -> bool`（含前置校验、设置 watered/timestamp、发信号）
- [x] 4.3 实现 `harvest_crop(tile_pos) -> String`（含前置校验、加物品/XP/统计、清除、发信号）
- [x] 4.4 实现 `clear_crop(tile_pos) -> bool`（清除数据、发信号）

## 5. CropManager 生长计时

- [x] 5.1 实现 `_process(delta)` 中每秒轮询逻辑（检查 GameState.PLAYING）
- [x] 5.2 实现 `_update_all_crops()` 遍历所有地块检查阶段推进
- [x] 5.3 实现阶段推进逻辑（时间判定、stage += 1、watered 重置、发信号）
- [x] 5.4 实现枯萎判定逻辑（MATURE 阶段跨日期零点判定）
- [x] 5.5 实现日期工具方法 `_get_current_date()`、`_timestamp_to_date()`、`_is_different_day()`

## 6. CropManager 离线补偿

- [x] 6.1 实现 `process_offline_time(last_online_timestamp)` 方法
- [x] 6.2 实现 `check_wither_all()` 批量枯萎检查方法

## 7. CropManager 查询接口

- [x] 7.1 实现 `get_crop_data(tile_pos) -> Dictionary`
- [x] 7.2 实现 `has_crop(tile_pos) -> bool`
- [x] 7.3 实现 `is_harvestable(tile_pos) -> bool`
- [x] 7.4 实现 `needs_water(tile_pos) -> bool`
- [x] 7.5 实现 `get_growth_progress(tile_pos) -> float`
- [x] 7.6 实现 `get_all_crops() -> Dictionary`
- [x] 7.7 实现 `get_mature_crops() -> Array[Vector2i]`
- [x] 7.8 实现 `get_crops_needing_water() -> Array[Vector2i]`

## 8. CropManager 存档接口

- [x] 8.1 实现 `export_save_data() -> Dictionary`
- [x] 8.2 实现 `import_save_data(data: Dictionary) -> void`

## 9. CropManager 调试接口

- [x] 9.1 实现 `debug_advance_time(tile_pos, seconds)`（仅 debug build）
- [x] 9.2 实现 `debug_force_wither_check()`
- [x] 9.3 实现 `debug_print_all()`

## 10. Autoload 注册

- [x] 10.1 在 `project.godot` 中注册 CropManager（位于 GameManager 之后、SaveManager 之前）

## 11. 测试

- [x] 11.1 创建 `scenes/test/test_crop_manager.tscn` 测试场景
- [x] 11.2 编写 `test_crop_manager.gd` 自动化测试脚本（覆盖种植/浇水/收获/清除/查询用例）
- [x] 11.3 运行测试场景验证全部用例通过
