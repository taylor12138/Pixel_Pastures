## Why

游戏核心玩法「种植 → 浇水 → 等待 → 成熟 → 收获/枯萎」尚无逻辑实现。PRD1 已搭建好数据层和事件总线基础设施，现在需要实现作物生长状态机作为所有后续玩法系统（田园场景渲染、种植交互、背包系统）的数据驱动核心。

## What Changes

- 新增 `CropManager` 全局单例（Autoload），作为作物逻辑的唯一入口
- 实现作物 5 状态机（SEED → SPROUT → GROWING → MATURE → WITHERED）
- 实现浇水驱动生长机制：每阶段需手动浇水一次，浇水后计时推进
- 实现枯萎判定：成熟后跨越自然日零点未收获则枯萎（软惩罚）
- 实现离线补偿：玩家离线期间已浇水阶段正常推进（最多一个阶段）
- 实现种植/浇水/收获/清除完整操作接口
- 实现查询接口（需要浇水列表、可收获列表、生长进度等）
- 实现存档数据导入/导出，与 GameManager.farm_data 双向同步
- 新增 CropManager 到 Autoload 注册顺序（位于 GameManager 之后）

## Capabilities

### New Capabilities
- `crop-state-machine`: 作物 5 阶段生长状态机，包含浇水驱动计时、阶段推进、枯萎判定和离线补偿
- `crop-operations`: 种植/浇水/收获/清除操作接口及其前置条件校验
- `crop-queries`: 作物状态查询接口（进度、是否可收获、是否需浇水、批量查询）

### Modified Capabilities
- `game-state`: GameManager 需新增 farm_data 字典、背包操作接口（add_item/has_item/remove_item）、stats 统计字段、add_xp 方法
- `event-bus`: 需确认 crop 相关信号已声明（crop_planted/watered/grown/matured/harvested/withered/cleared）

## Impact

- **新增文件**: `scripts/autoload/crop_manager.gd`, `scenes/test/test_crop_manager.tscn`, `scenes/test/test_crop_manager.gd`
- **修改文件**: `project.godot`（Autoload 注册）
- **依赖**: DataManager（读取 crops.json 配置）、GameManager（背包/存档/统计）、EventBus（信号广播）
- **被依赖**: PRD8（田园场景渲染）、PRD10（种植交互）、PRD3（背包系统）
