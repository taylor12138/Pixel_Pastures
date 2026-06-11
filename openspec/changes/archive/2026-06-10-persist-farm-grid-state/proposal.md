## Why

`FarmGridManager` 已具备 JSON 可序列化的导入导出接口，但 `SaveManager` 尚未持久化场景内网格数据，且 `farm.tscn` 每次进入都会无条件初始化默认网格。结果是扩展解锁、空地土壤状态以及没有作物支撑的地块状态会在存档加载或重新进入农场后丢失。

## What Changes

- 将活动农场场景中的 `FarmGridManager` 注册为 `SaveManager` 可读写的运行时状态提供者。
- 在存档根结构中加入可选的 `farm_grid` 字段，保存解锁数量、地块解锁状态、土壤状态、占用状态与作物引用。
- 加载存档时先恢复 `farm_grid`，再执行 Crop/Grid 一致性修复，确保作物与地块状态最终一致。
- 调整 `farm.tscn` 初始化流程：无可恢复数据时初始化默认网格，有待应用的存档数据时恢复存档网格，避免无条件覆盖。
- 保持旧存档兼容：缺少 `farm_grid` 时继续使用默认 12 格已解锁农田，并根据已保存作物修复占用状态。
- 增加保存、加载、重进场景和旧存档回退的自动化覆盖。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `save-system`: 存档根结构正式持久化并恢复可选的 `farm_grid` 数据，同时保持旧存档兼容。
- `farm-grid-system`: 农场场景初始化必须选择默认初始化或存档恢复，不能无条件覆盖待恢复网格状态。
- `farm-interaction-loop`: Crop/Grid 一致性修复必须发生在网格恢复之后，并处理旧存档中作物位于默认锁定地块的情况。

## Impact

- 主要影响 `scripts/autoload/save_manager.gd`、`scripts/farm/farm_grid_manager.gd`、`scripts/farm/farm_interaction_controller.gd`、`scenes/farm/farm.gd`。
- 需要为场景级 `FarmGridManager` 增加稳定的注册、待加载数据或等价生命周期协调机制。
- 存档 schema 需要接受可选 `farm_grid` 字段，但无需破坏或拒绝现有存档。
- 需要扩展 `test_save_manager`、`test_farm_grid_manager`、`test_farm_interaction_controller` 或新增集成测试。
