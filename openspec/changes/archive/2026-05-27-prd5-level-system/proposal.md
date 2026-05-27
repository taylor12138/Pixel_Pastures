## Why

当前项目已经具备作物、生长、库存与商店经济等基础系统，但玩家经验、等级与内容解锁仍分散在 `GameManager`、作物与商店逻辑中，缺少统一的数据层入口。PRD5 需要建立稳定的等级/经验/解锁系统，让后续田园网格、HUD、商店 UI、存档与偷菜等功能可以复用同一套成长规则。

## What Changes

- 新增 `LevelManager` 全局单例，作为经验增加、升级判定、等级查询与解锁查询的统一入口。
- 根据 `levels.json` 支持累计 XP 阈值、连续升级、满级后继续累计 XP，以及升级奖励/解锁内容的结构化返回。
- 新增作物、功能与农田格数的累计解锁查询能力，并兼容 `crops.json.unlock_level` 的作物解锁判断。
- 扩展 `EventBus` 等级成长相关信号，广播 XP、升级、作物解锁、功能解锁与地块数量变化。
- 调整 `GameManager`、`CropManager`、`EconomyManager` 与 `DataManager` 的等级/经验/解锁职责边界，使作物种植/收获、出售、商店锁定统一接入 `LevelManager`。
- 新增等级系统导出/导入接口，为存档系统预留一致的数据结构。
- 新增 `test_level_manager` 自动化测试场景，覆盖经验、升级、解锁、信号与存档导入导出流程。

## Capabilities

### New Capabilities
- `level-progression`: 覆盖玩家 XP 获取、等级判定、连续升级、满级处理、经验进度查询、等级系统导出/导入与升级结果结构。
- `content-unlocks`: 覆盖按等级累计解锁作物、功能与农田格数，并提供作物/功能/地块解锁查询能力。

### Modified Capabilities
- `event-bus`: 增加解锁变化、作物解锁、功能解锁与农田格数变化信号，并明确经验/升级/解锁信号的发射时机。
- `game-state`: 收敛 XP/Level 的存储与操作职责，允许 `GameManager.add_xp()` 委托 `LevelManager`，并在存档数据中预留 `level_system`。
- `crop-state-machine`: 种植与收获成功后通过等级系统发放对应 XP，并避免作物系统自行实现升级判定。
- `shop-economy`: 出售成功后按交易金额发放 XP，种子购买/展示的锁定校验改用等级系统的作物解锁查询。
- `data-loading`: 补充等级表只读查询能力，确保等级系统可稳定读取等级、作物与配置数据。

## Impact

- 受影响代码：`pixel-farm/scripts/autoload/level_manager.gd`、`event_bus.gd`、`game_manager.gd`、`crop_manager.gd`、`economy_manager.gd`、`data_manager.gd`、`pixel-farm/project.godot`。
- 新增测试：`pixel-farm/scenes/test/test_level_manager.gd` 与 `pixel-farm/scenes/test/test_level_manager.tscn`。
- 数据依赖：继续以 `pixel-farm/data/levels.json` 作为等级阈值与解锁内容唯一来源，并兼容 `pixel-farm/data/crops.json` 中的 `unlock_level`。
- API 影响：新增 `LevelManager` 公共接口；保留 `GameManager.xp`、`GameManager.level` 与 `EventBus.xp_gained`、`EventBus.level_up` 的兼容签名。
