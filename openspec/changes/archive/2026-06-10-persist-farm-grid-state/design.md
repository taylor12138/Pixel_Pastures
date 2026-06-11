## Context

`FarmGridManager` 是 `farm.tscn` 内的场景节点，不是 Autoload。它已经实现 `export_save_data()` 与 `import_save_data()`，但 `SaveManager` 只直接编排全局管理器，因此当前保存根没有真正写入网格数据。

加载通常发生在农场场景创建之前：`SaveManager` 可以先恢复 CropManager 等 Autoload，但当时不存在可调用的 FarmGridManager。之后进入农场时，`farm.gd` 又无条件调用 `initialize_grid()`，只能由 `FarmInteractionController.reconcile_grid_with_crops()` 恢复已有作物对应的 occupied 状态，不能恢复解锁数量或无作物地块的土壤状态。

## Goals / Non-Goals

**Goals:**

- 将场景级 FarmGridManager 纳入统一 SaveManager 存档结构。
- 支持“加载时场景尚不存在”和“保存时当前不在农场”两种生命周期。
- 进入农场时恢复网格后再执行 Crop/Grid 一致性修复。
- 保持缺少 `farm_grid` 的旧存档兼容。
- 通过自动化测试验证解锁、土壤状态、占用状态和旧存档回退。

**Non-Goals:**

- 不把 FarmGridManager 改成 Autoload。
- 不保存 FarmInteractionController 的当前选择、悬停格或选中格。
- 不改变 CropManager 的作物数据结构或离线生长规则。
- 不改变存档槽位、备份、自动保存和 UI 行为。

## Decisions

### 1. FarmGridManager 继续保持场景所有权，通过注册接入 SaveManager

`SaveManager` 增加注册与注销活动 FarmGridManager 的接口。`farm.gd` 在初始化时注册场景节点，在退出树前注销。

选择这一方案是因为网格仍属于具体农场场景，直接改成 Autoload 会扩大生命周期、节点依赖和后续好友农场扩展的影响面。

备选方案是 SaveManager 每次通过固定 NodePath 搜索节点。该方案依赖当前场景结构，切场景和测试场景中不稳定，因此不采用。

### 2. SaveManager 持有 JSON 安全的 farm_grid 缓存

SaveManager 保存最近加载、活动节点导出或节点注销时导出的 farm grid Dictionary。构建存档时：

- 活动 FarmGridManager 存在时，从节点导出并刷新缓存；
- 活动节点不存在时，写入缓存；
- 从未加载且从未注册时，写入空 Dictionary 或默认兼容值。

这样玩家加载存档后尚未进入农场便再次保存，也不会把已有 `farm_grid` 覆盖为空。

### 3. 加载先缓存 farm_grid，场景注册时消费并恢复

`SaveManager.apply_save_data()` 读取可选 `farm_grid` 字段并更新缓存。若活动 FarmGridManager 已注册，则立即调用其 `import_save_data()`；否则等待农场场景注册。

`register_farm_grid_manager(manager)` 返回是否应用了有效缓存，或提供等价查询结果。`farm.gd` 据此选择：

- 已恢复存档网格：不调用 `initialize_grid()`；
- 没有可恢复网格：初始化默认网格。

旧存档缺少 `farm_grid` 时必须走默认初始化。

### 4. 恢复顺序为 Grid import，再 Crop/Grid reconcile

农场初始化顺序固定为：

1. 注册 FarmGridManager 并尝试恢复；
2. 无恢复数据时初始化默认网格；
3. 绑定 Player；
4. setup FarmInteractionController；
5. controller 执行 `reconcile_grid_with_crops()`；
6. 刷新网格与作物视觉。

若加载发生在农场场景已打开时，`game_loaded` 后必须再次 reconcile。网格存档状态优先恢复，CropManager 再作为作物占用关系的最终事实来源：

- 有作物的合法可耕地最终 occupied；
- 没有作物的 stale occupied 最终清空；
- 非 occupied 的 `dry_soil`、`wet_soil` 和解锁状态保持存档值。

### 5. 旧存档中的作物不能因默认锁定状态丢失

旧存档没有 farm_grid，但可能保存了位于默认 12 格之外的作物。reconcile 遇到这种情况时，应把该作物所在的最大可解锁 farm plot 恢复为 unlocked，再标记 occupied，避免作物存在但无法交互。

该兼容修复只针对有作物的合法可解锁地块，不推断或恢复其他历史解锁格。

### 6. `farm_grid` 对新存档稳定写入，对旧存档保持可选

新生成的保存数据包含 `farm_grid`。校验和迁移不得把 `farm_grid` 列为旧存档必填字段；缺失时按默认网格处理。无需仅为新增可选字段强制提升 schema version，除非现有 SaveManager 的迁移策略要求版本递增。

## Risks / Trade-offs

- [场景节点注销遗漏导致悬空引用] → 使用 `is_instance_valid()` 检查，并在 `farm.gd._exit_tree()` 主动注销。
- [加载后立即保存覆盖缓存] → 保存时仅在活动 provider 有效时刷新缓存，否则保留加载缓存。
- [导入网格与 CropManager 占用冲突] → 每次导入后统一执行 reconcile，CropManager 决定作物占用关系。
- [旧存档只能推断有作物地块的解锁状态] → 明确限定兼容范围，不猜测没有作物的历史扩展解锁。
- [测试间全局缓存串状态] → SaveManager 提供测试重置接口，或测试准备阶段显式清空 farm grid provider/cache。

## Migration Plan

1. 增加 SaveManager 的 farm grid provider 注册、缓存、保存和加载逻辑。
2. 调整 `farm.gd` 初始化与退出生命周期。
3. 增强 reconcile 对旧存档锁定作物格的兼容修复。
4. 增加专项与回归测试。
5. 旧存档首次加载时使用默认网格并修复作物占用；下一次保存后自动获得完整 `farm_grid` 字段。

回滚时可停止写入和应用 `farm_grid` 字段；由于该字段为可选扩展，旧代码会忽略它，其余存档数据仍可读取。

## Open Questions

无。实现阶段可根据现有测试习惯决定注册接口的具体命名，但行为必须符合上述生命周期。
