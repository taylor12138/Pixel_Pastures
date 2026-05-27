## Context

项目当前已经完成项目骨架、数据加载、作物状态机、库存与经济商店等基础能力。`GameManager` 持有玩家 `xp` 与 `level`，并已有基础 `add_xp()` / `_check_level_up()` / `get_xp_progress()` 逻辑；`CropManager` 与 `EconomyManager` 已能在种植、收获、出售和购买流程中访问玩家状态或预留经验入口。

PRD5 将成长系统从分散逻辑收敛为纯数据层能力：新增 `LevelManager` Autoload，统一处理 XP 获取、等级重算、连续升级、解锁查询与等级系统存档导入导出。等级配置仍以 `data/levels.json` 为唯一权威来源，作物兼容 `data/crops.json` 的 `unlock_level` 字段。该设计必须保持现有 `GameManager.xp`、`GameManager.level`、`EventBus.xp_gained` 与 `EventBus.level_up` 的兼容性，避免破坏 PRD1-PRD4 已实现功能。

## Goals / Non-Goals

**Goals:**

- 新增 `LevelManager`，作为 XP、等级与内容解锁的统一业务入口。
- 支持按累计 XP 阈值连续升级、满级后继续累计 XP、统一结果 Dictionary 与错误码。
- 提供等级数据、XP 进度、作物解锁、功能解锁、农田格数与累计解锁查询接口。
- 通过 `EventBus` 广播 XP、升级与解锁变化，不直接依赖 UI 或场景节点。
- 将 `GameManager`、`CropManager`、`EconomyManager`、`DataManager` 的相关职责调整到清晰边界。
- 为后续 PRD6 存档系统和 UI/田园/商店功能提供稳定接口。
- 新增自动化测试场景，验证经验、升级、解锁、信号和导入导出流程。

**Non-Goals:**

- 不实现经验条 HUD、等级显示、升级弹窗、解锁提示 UI 或视觉特效。
- 不实现偷菜、装饰、动物伙伴、公共广场等后续功能的实际玩法。
- 不修改 `levels.json` 的内容结构，除非发现现有数据缺失导致无法满足已定义接口。
- 不引入外部依赖或复杂缓存；等级表规模较小，运行时按需遍历即可。

## Decisions

### 1. `GameManager` 保留数值权威，`LevelManager` 作为操作权威

`GameManager.xp` 与 `GameManager.level` 继续作为玩家核心状态字段，`LevelManager` 不另建重复状态，而是读写 `GameManager` 中的数值并提供统一操作接口。

- 理由：现有存档、测试和其他系统已依赖 `GameManager` 字段，保留字段可降低迁移风险。
- 替代方案：将 XP/Level 完全迁移到 `LevelManager`。该方案会造成更大兼容成本，并需要立即重写存档根字段。
- 结果：`GameManager.add_xp()` 委托 `LevelManager.add_xp()`，同时保留 legacy fallback，避免 Autoload 注册顺序或测试场景缺少 `LevelManager` 时失效。

### 2. 等级判定使用累计 XP 阈值

`levels.json` 中的 `xp_required` 表示达到该等级所需累计 XP，而非本级增量。`check_level_up()` 每次读取下一等级阈值，只要 `GameManager.xp >= xp_required` 就提升一级，直到不足或达到最高等级。

- 理由：符合 PRD5 中的等级表与示例，便于读档后通过总 XP 重算等级。
- 替代方案：将 `xp_required` 视为等级间增量。该方案与既有数据含义不一致，会导致升级曲线错误。
- 结果：`recalculate_level()` 可从等级表扫描出 XP 对应的最高等级，用于读档或调试修正。

### 3. 解锁内容按等级累计计算，不缓存为独立状态

`get_accumulated_unlocks(level)` 每次从 1 级遍历到目标等级，合并 `crops`、`features`，并以当前等级的 `farm_slots` 为准；对外返回数组副本。

- 理由：等级数量少，按需计算简单可靠，且避免缓存失效与存档冗余。
- 替代方案：在 `LevelManager` 中维护 `unlocked_crops` / `unlocked_features` 缓存。该方案增加状态同步复杂度，读档与重算时更容易不一致。
- 结果：存档导出可包含累计解锁快照用于调试或后续扩展，但导入时仍以 XP/Level 和等级表重算为准。

### 4. 作物解锁优先等级表，兼容作物表

`is_crop_unlocked(crop_id)` 优先检查 `levels.json.unlocks.crops` 的累计结果；如果等级表未包含该作物，则读取 `DataManager.get_crop(crop_id)` 并使用 `unlock_level` 兼容判断。

- 理由：PRD5 要求 `levels.json` 是解锁权威，同时现有 `crops.json` 可能已有 `unlock_level` 被 PRD4 商店使用。
- 替代方案：只使用 `levels.json`。该方案会使未纳入等级表但仍有作物配置的数据无法兼容。
- 结果：商店和种植逻辑统一调用 `LevelManager.is_crop_unlocked()`，避免直接读取 `GameManager.level`。

### 5. XP 来源采用 `calculate_xp()` + `grant_xp()` 双层接口

`calculate_xp(source, context)` 负责将来源和上下文转换为 XP 数量，`grant_xp(source, context)` 负责调用 `add_xp()` 并返回统一结果。

- 理由：测试和业务接入可分别验证 XP 规则与实际升级副作用。
- 替代方案：各业务系统自行计算 XP 后调用 `add_xp()`。该方案会让经验规则重新分散到多个 Manager 中。
- 结果：种植、收获、出售、偷菜预留和测试手动发放都通过同一规则入口处理。

### 6. 信号仍由 `EventBus` 统一广播

`LevelManager` 在 XP 成功增加后发射 `xp_gained`；每升一级发射一次 `level_up`；当升级带来解锁变化时发射 `unlocks_changed`，并按作物、功能、地块变化发射对应细粒度信号。

- 理由：项目已使用 `EventBus` 做全局事件解耦，数据层不应直接引用 UI 或场景节点。
- 替代方案：`LevelManager` 自身定义信号。该方案会让监听方需要同时订阅多个总线，降低一致性。
- 结果：后续 HUD、商店 UI、田园网格可以监听统一事件，不影响数据层测试。

### 7. Autoload 顺序追加在经济系统之后

`LevelManager` 注册在 `EventBus`、`DataManager`、`GameManager`、`CropManager`、`InventoryManager`、`EconomyManager` 之后，`SceneManager` 和 `AudioManager` 之前。

- 理由：`LevelManager` 依赖前三者读取配置和玩家状态，同时经济/作物系统可通过运行时 `has_node("/root/LevelManager")` 兼容访问。
- 替代方案：将 `LevelManager` 放到 `GameManager` 前。该方案会使其初始化时访问玩家状态更复杂。
- 结果：实现时需要更新 `project.godot` 的 `[autoload]` 配置。

## Risks / Trade-offs

- `GameManager.add_xp()` 委托 `LevelManager` 后可能出现递归调用 → `LevelManager.add_xp()` 必须直接修改 `GameManager.xp`，不能再调用 `GameManager.add_xp()`。
- 现有 `CropManager` 或 `EconomyManager` 已有 XP 发放逻辑可能与新逻辑重复 → 接入时逐处替换为 `LevelManager.grant_xp()`，并通过测试确认单次操作只发放一次 XP。
- `levels.json` 或 `crops.json` 字段缺失可能导致查询异常 → 所有读取使用 `get()` 默认值和类型校验，缺失解锁按空内容处理，缺失等级数据时返回失败结果并 `push_warning`。
- 读档时 XP/Level 不一致可能重复触发升级奖励 → `import_save_data()` 调用 `recalculate_level()` 修正状态，但不发放升级奖励或解锁信号。
- `LevelManager` 注册顺序或测试场景未加载时可能影响 legacy 系统 → `GameManager.add_xp()` 保留 fallback，其他 Manager 使用 `has_node("/root/LevelManager")` 后再调用。
- 未来等级数量增加后按需遍历可能性能下降 → 当前等级仅 7 项无需缓存；若后续显著增长，再引入可失效的累计解锁缓存。

## Migration Plan

1. 新增 `scripts/autoload/level_manager.gd`，实现 XP、等级、解锁查询、导入导出与调试接口。
2. 扩展 `DataManager` 等级表只读查询接口，确保 `get_level_data()`、`get_max_level()`、`get_all_levels()`、`get_all_crops()` 可用。
3. 扩展 `EventBus` 等级解锁信号，并保留既有 XP/升级信号签名。
4. 修改 `GameManager.add_xp()` 委托 `LevelManager`，保留 legacy fallback，并在存档结构预留 `level_system`。
5. 修改 `CropManager`，在种植/收获成功后通过 `LevelManager.grant_xp()` 发放 XP。
6. 修改 `EconomyManager`，出售成功后按总价发放 XP，商店作物锁定检查改为 `LevelManager.is_crop_unlocked()`。
7. 在 `project.godot` 注册 `LevelManager` Autoload。
8. 新增并运行 `test_level_manager` 测试场景，验证 PRD5 验收标准。

Rollback 策略：如果 `LevelManager` 接入出现阻断问题，可先从 `project.godot` 移除 Autoload 注册，并依赖 `GameManager` legacy fallback 保持基础 XP/Level 行为；随后逐项回滚作物与经济系统的委托调用。

## Open Questions

- `plant` 来源是否在当前 PRD5 实现中立即接入真实种植流程，还是仅在 `LevelManager` 规则和测试中覆盖；本设计按 PRD5 要求默认接入成功种植。
- 若 `levels.json` 与 `crops.json.unlock_level` 对同一作物配置冲突，当前设计以 `levels.json` 为准；后续如需数据校验，可在数据加载或测试中增加警告。
