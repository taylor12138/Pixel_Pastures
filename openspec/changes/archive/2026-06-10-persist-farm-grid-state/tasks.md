## 1. SaveManager 农田网格生命周期

- [x] 1.1 在 `SaveManager` 中增加活动 FarmGridManager 注册、注销和有效性检查接口
- [x] 1.2 增加 JSON 安全的 farm grid 缓存，并在 provider 注销或有效导出时刷新缓存
- [x] 1.3 扩展 `build_save_data()`，稳定写入 `farm_grid`，且无活动场景时保留已加载缓存
- [x] 1.4 扩展 `apply_save_data()`，读取可选 `farm_grid` 并在 provider 已注册时立即导入，否则延迟到注册时导入
- [x] 1.5 保持存档校验与迁移兼容，确保旧存档缺少 `farm_grid` 时仍可成功加载

## 2. 农场场景恢复流程

- [x] 2.1 调整 `farm.gd` 初始化顺序，先向 SaveManager 注册 FarmGridManager 并尝试恢复
- [x] 2.2 仅在没有恢复有效 `farm_grid` 时调用默认 `initialize_grid()`
- [x] 2.3 在农场场景退出树前注销 provider，并确保最新网格状态进入 SaveManager 缓存
- [x] 2.4 支持农场场景已打开时读档，在网格导入后重新执行 Crop/Grid 一致性修复与视觉刷新

## 3. Crop/Grid 一致性兼容

- [x] 3.1 增强 `reconcile_grid_with_crops()`，为旧存档中位于合法默认锁定格的作物恢复 unlocked 和 occupied
- [x] 3.2 保持无作物 `empty`、`dry_soil`、`wet_soil` 地块的已恢复状态，仅清理 stale occupied
- [x] 3.3 确认种植、浇水、收获和清除后的 CropManager 与 FarmGridManager 同步行为不变

## 4. 自动化测试

- [x] 4.1 扩展 SaveManager 测试，覆盖 `farm_grid` 写入、加载、无活动 provider 时缓存保留和旧存档兼容
- [x] 4.2 扩展 FarmGridManager 测试，覆盖扩展解锁、干湿土壤和 occupied 状态的导出导入
- [x] 4.3 扩展 FarmInteractionController 测试，覆盖旧存档锁定作物格修复及非 occupied 状态保护
- [x] 4.4 增加或扩展场景集成测试，验证离开并重新进入农场后网格状态仍被恢复
- [x] 4.5 运行 FarmGridManager、FarmInteractionController、SaveManager 专项测试和全量回归，确认 0 失败
