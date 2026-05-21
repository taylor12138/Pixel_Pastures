## 1. CropManager 实现

- [x] 1.1 创建 scripts/autoload/crop_manager.gd (不使用 class_name)
- [x] 1.2 定义 CropStage 枚举 (SEED=0, SPROUT=1, GROWING=2, MATURE=3, WITHERED=4)
- [x] 1.3 实现 plant_crop(tile_pos, crop_id) 含前置检查和背包扣除
- [x] 1.4 实现 water_crop(tile_pos) 含状态校验
- [x] 1.5 实现 harvest_crop(tile_pos) 含物品/经验发放
- [x] 1.6 实现 clear_crop(tile_pos) 含信号发射
- [x] 1.7 实现 _process 1秒轮询 + _update_all_crops 阶段推进
- [x] 1.8 实现枯萎判定 (_check_wither_single + 日期比较)
- [x] 1.9 实现离线补偿 process_offline_time()
- [x] 1.10 实现 GameManager.farm_data 双向同步

## 2. 查询接口

- [x] 2.1 实现 has_crop() / get_crop_data()
- [x] 2.2 实现 is_harvestable() / needs_water()
- [x] 2.3 实现 get_growth_progress() (0.0~1.0)
- [x] 2.4 实现 get_all_crops() / get_mature_crops() / get_crops_needing_water()

## 3. 存档集成

- [x] 3.1 实现 export_save_data() / import_save_data()
- [x] 3.2 实现 _sync_to_game_manager() / _load_from_game_manager()

## 4. 调试接口

- [x] 4.1 实现 debug_advance_time() (仅 debug build)
- [x] 4.2 实现 debug_force_wither_check()
- [x] 4.3 实现 debug_print_all()

## 5. Autoload 注册

- [x] 5.1 在 project.godot [autoload] 中注册 CropManager
- [x] 5.2 确认加载顺序: EventBus → DataManager → GameManager → CropManager → SceneManager → AudioManager

## 6. 测试场景

- [x] 6.1 创建 scenes/test/test_crop_manager.tscn
- [x] 6.2 创建 test_crop_manager.gd 包含 21 个自动化测试用例
- [x] 6.3 测试覆盖: 种植/浇水/收获/清除/枯萎/离线补偿/查询/导入导出

## 7. Bug 修复

- [x] 7.1 移除 class_name CropManager (Autoload 不能使用 class_name)
