## Why

《像素田园》需要核心种植玩法的数据层支撑。PRD1 建立了骨架，PRD2 实现作物的完整生命周期状态机，使后续所有视觉/交互 PRD 有稳固的逻辑基础可调用。

## What Changes

- 新增 CropManager Autoload 单例（scripts/autoload/crop_manager.gd）
- 实现 5 状态机：SEED → SPROUT → GROWING → MATURE → WITHERED
- 实现浇水驱动生长（不浇水不推进）
- 实现枯萎判定（成熟后跨自然日零点未收获则枯萎）
- 实现离线补偿（重新上线时追赶已浇水阶段的时间）
- 在 project.godot 注册 CropManager Autoload
- 创建测试场景 scenes/test/test_crop_manager.tscn 验证全部逻辑

## Capabilities

### New Capabilities
- `crop-state-machine`: 作物 5 阶段生长状态机 + 浇水/枯萎/收获/清除全套操作

### Modified Capabilities
- `event-bus`: 使用 crop_matured / crop_cleared 等已定义信号
- `game-state`: 通过 GameManager.farm_data 同步存档数据

## Impact

- **代码**: 新增 crop_manager.gd (376行) + test_crop_manager.gd (测试)
- **配置**: project.godot 新增 CropManager Autoload 注册
- **数据**: 无新增 JSON，使用 PRD1 的 crops.json
- **后续影响**: PRD8(田园场景) / PRD10(种植交互) 直接依赖此系统
